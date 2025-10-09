#!/bin/bash
# ===============================================
# Funciones comunes para detección dinámica del maestro
# y ejecución de backups con pgBackRest
# ===============================================

# Función para detectar cuál contenedor es el maestro actual
detect_master_container() {
    CONTAINERS=($(docker ps --format "{{.Names}}" | grep -E 'postgres_(master|slave)'))
    
    if [ ${#CONTAINERS[@]} -eq 0 ]; then
        echo "❌ ERROR: No se encontraron contenedores PostgreSQL" >&2
        return 1
    fi
    
    for container in "${CONTAINERS[@]}"; do
        IS_RECOVERY=$(docker exec "$container" psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "t")
        if [[ "$IS_RECOVERY" =~ ^f ]]; then
            # Solo retornar el nombre del contenedor (sin mensajes)
            echo "$container"
            return 0
        fi
    done
    
    echo "❌ ERROR: No se pudo detectar el contenedor maestro" >&2
    return 1
}

# Función para obtener la ruta del volumen según el contenedor
get_data_path() {
    local container=$1
    
    if [[ "$container" == "postgres_master" ]]; then
        echo "/var/lib/postgresql/master"
    elif [[ "$container" == "postgres_slave" ]]; then
        echo "/var/lib/postgresql/slave"
    else
        echo ""
        return 1
    fi
}

# Función para obtener el host del contenedor maestro
get_master_host() {
    local container=$1
    
    if [[ "$container" == "postgres_master" ]]; then
        echo "db-master"
    elif [[ "$container" == "postgres_slave" ]]; then
        echo "db-slave"
    else
        echo ""
        return 1
    fi
}

# Función para ejecutar backup con pgBackRest
execute_pgbackrest_backup() {
    local backup_type=$1  # full, incr, diff
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    
    echo "🔍 Detectando contenedor maestro..."
    MASTER_CONTAINER=$(detect_master_container)
    
    if [ -z "$MASTER_CONTAINER" ]; then
        echo "❌ ERROR: No se pudo detectar el maestro"
        return 1
    fi
    
    echo "✓ Maestro detectado: $MASTER_CONTAINER"
    
    DATA_PATH=$(get_data_path "$MASTER_CONTAINER")
    MASTER_HOST=$(get_master_host "$MASTER_CONTAINER")
    
    echo "📁 Ruta de datos: $DATA_PATH"
    echo "🌐 Host maestro: $MASTER_HOST"
    echo ""
    echo "🔄 Ejecutando backup tipo: $backup_type"
    
    # Ejecutar backup con pgBackRest en modo offline optimizado
    # --no-online: no requiere conexión a PostgreSQL, lee archivos directamente
    # --force: permite backup aunque PostgreSQL esté corriendo
    # --process-max=8: 8 procesos paralelos (aumenta velocidad significativamente)
    # --compress-type=lz4: compresión rápida (mucho más rápida que gzip, comprime ~30%)
    # --compress-level=1: nivel mínimo de compresión (prioriza velocidad)
    # --buffer-size=16384: buffer de 16MB para I/O más eficiente
    if docker exec pgbackrest pgbackrest \
        --stanza=main \
        --type=$backup_type \
        --no-online \
        --force \
        --process-max=4 \
        --compress-type=lz4 \
        --compress-level=1 \
        --buffer-size=32768 \
        backup; then
        
        echo "✓ Backup $backup_type completado exitosamente"
        
        # Registrar en Redis
        register_backup_in_redis "$backup_type" "$timestamp" "$MASTER_CONTAINER"
        
        return 0
    else
        echo "❌ ERROR: Falló el backup $backup_type"
        return 1
    fi
}

# Función para registrar backup en Redis
register_backup_in_redis() {
    local tipo=$1
    local timestamp=$2
    local maestro=$3
    
    REDIS_HOST="127.0.0.1"
    REDIS_PORT=6379
    
    # Separar fecha y hora del timestamp
    local fecha=$(echo "$timestamp" | cut -d'_' -f1)  # YYYY-MM-DD
    local hora=$(echo "$timestamp" | cut -d'_' -f2 | tr '-' ':')  # HH:MM:SS
    
    # Determinar la dirección de almacenamiento según el tipo
    local backup_label=""
    case "$tipo" in
        "full")
            backup_label="completo"
            ;;
        "incr")
            backup_label="incremental"
            ;;
        "diff")
            backup_label="diferencial"
            ;;
    esac
    
    # Dirección de almacenamiento en el servidor
    local storage_path="/var/lib/pgbackrest/backup/main/${timestamp}F"
    
    # Registrar en Redis con formato estructurado
    docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        HSET "backup:${timestamp}" \
        "fecha" "$fecha" \
        "hora" "$hora" \
        "tipo_backup" "$backup_label" \
        "direccion_almacenamiento" "$storage_path" \
        "maestro_usado" "$maestro" \
        "metodo" "pgBackRest" \
        "stanza" "main" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ Backup registrado en Redis: backup:${timestamp}"
        echo "  📅 Fecha: $fecha"
        echo "  🕐 Hora: $hora"
        echo "  📦 Tipo: $backup_label"
        echo "  📁 Ubicación: $storage_path"
    else
        echo "⚠️  Advertencia: No se pudo registrar en Redis (backup completado)"
    fi
}

# Función para crear o actualizar la stanza de pgBackRest
create_or_update_stanza() {
    echo "🔧 Configurando pgBackRest stanza..."
    
    # Detectar maestro
    echo "🔍 Detectando contenedor maestro..."
    MASTER_CONTAINER=$(detect_master_container)
    
    if [ -z "$MASTER_CONTAINER" ]; then
        echo "❌ ERROR: No se pudo detectar el maestro"
        return 1
    fi
    
    echo "✓ Maestro detectado: $MASTER_CONTAINER"
    
    DATA_PATH=$(get_data_path "$MASTER_CONTAINER")
    MASTER_HOST=$(get_master_host "$MASTER_CONTAINER")
    
    echo "📋 Configuración detectada:"
    echo "   Maestro: $MASTER_CONTAINER"
    echo "   Host: $MASTER_HOST"
    echo "   Ruta: $DATA_PATH"
    echo ""
    
    # Configurar pgBackRest para acceso directo a archivos (sin conexión a PostgreSQL)
    echo "📝 Configurando pgBackRest.conf..."
    docker exec pgbackrest bash -c "cat > /etc/pgbackrest/pgbackrest.conf <<EOF
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
log-level-console=info
log-level-file=debug
archive-async=y

[main]
pg1-path=$DATA_PATH
EOF"
    
    echo "✓ Configuración creada"
    echo ""
    
    # Limpiar stanza anterior completamente
    echo "🧹 Limpiando stanza anterior (si existe)..."
    docker exec pgbackrest rm -rf /var/lib/pgbackrest/backup/main 2>/dev/null || true
    docker exec pgbackrest rm -rf /var/lib/pgbackrest/archive/main 2>/dev/null || true
    
    echo "📝 Creando nueva stanza 'main'..."
    
    # Crear nueva stanza sin conexión a PostgreSQL
    if docker exec pgbackrest pgbackrest \
        --stanza=main \
        --no-online \
        stanza-create; then
        echo "✓ Stanza creada exitosamente"
        
        # Verificar stanza (sin check porque requiere conexión)
        echo ""
        echo "🔍 Verificando stanza..."
        docker exec pgbackrest pgbackrest --stanza=main info
        
        return 0
    else
        echo "❌ ERROR: No se pudo crear la stanza"
        return 1
    fi
}

# Exportar funciones para uso en otros scripts
export -f detect_master_container
export -f get_data_path
export -f get_master_host
export -f execute_pgbackrest_backup
export -f register_backup_in_redis
export -f create_or_update_stanza
