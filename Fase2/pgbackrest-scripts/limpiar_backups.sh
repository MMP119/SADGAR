#!/bin/bash
# ===============================================
# Script para limpiar/eliminar backups antiguos
# ===============================================

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo "=========================================="
echo "  LIMPIEZA DE BACKUPS"
echo "=========================================="
echo ""

# Función para mostrar menú
show_menu() {
    echo "Selecciona una opción:"
    echo ""
    echo "  1) 🗑️  Eliminar backups más antiguos (mantener últimos N backups completos)"
    echo "  2) 🧹 Limpiar backups de pgBackRest según retención configurada"
    echo "  3) 🔥 Eliminar TODOS los backups (PELIGROSO)"
    echo "  4) 📋 Ver backups actuales antes de eliminar"
    echo "  5) ❌ Salir"
    echo ""
    read -p "Opción: " opcion
}

# Función para eliminar backups por retención
expire_backups() {
    read -p "¿Cuántos backups COMPLETOS quieres mantener? (default: 2): " retention
    retention=${retention:-2}
    
    echo ""
    echo "🔄 Aplicando retención: mantener últimos $retention backups completos..."
    
    # Ejecutar expire en pgBackRest
    if docker exec pgbackrest pgbackrest \
        --stanza=main \
        --repo1-retention-full=$retention \
        expire; then
        
        echo "✓ Backups antiguos eliminados correctamente"
        echo "📊 Se mantuvieron los últimos $retention backups completos más sus incrementales/diferenciales"
    else
        echo "❌ Error al eliminar backups"
        return 1
    fi
}

# Función para limpiar según retención actual
cleanup_current_retention() {
    echo "🔄 Limpiando backups según retención configurada (2 backups completos)..."
    
    if docker exec pgbackrest pgbackrest --stanza=main expire; then
        echo "✓ Limpieza completada"
    else
        echo "❌ Error en la limpieza"
        return 1
    fi
}

# Función para eliminar TODOS los backups
delete_all_backups() {
    echo ""
    echo "⚠️  ¡ADVERTENCIA! Esto eliminará TODOS los backups."
    read -p "¿Estás seguro? Escribe 'SI' para confirmar: " confirm
    
    if [ "$confirm" != "SI" ]; then
        echo "❌ Operación cancelada"
        return 1
    fi
    
    echo ""
    echo "🗑️  Eliminando todos los backups de pgBackRest..."
    
    # Eliminar stanza (esto elimina todos los backups)
    docker exec pgbackrest pgbackrest --stanza=main --force stanza-delete
    
    # Recrear stanza limpia
    echo "🔄 Recreando stanza limpia..."
    bash "$(dirname "$0")/stanza_create.sh"
    
    # Limpiar Redis
    echo "🧹 Limpiando registros de Redis..."
    BACKUP_KEYS=$(docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        KEYS "backup:*")
    
    if [ -n "$BACKUP_KEYS" ]; then
        for key in $BACKUP_KEYS; do
            docker run --rm --network host redis:7-alpine \
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
                DEL "$key" > /dev/null
        done
        echo "✓ Registros de Redis eliminados"
    fi
    
    echo "✓ Todos los backups han sido eliminados"
}

# Función para mostrar backups actuales
show_current_backups() {
    echo ""
    echo "📋 Backups actuales en pgBackRest:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    docker exec pgbackrest pgbackrest --stanza=main info
    
    echo ""
    echo "📋 Backups registrados en Redis:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$(dirname "$0")/listar_backups.sh"
}

# Función para limpiar solo registros de Redis huérfanos
clean_orphan_redis_keys() {
    echo "🧹 Buscando registros de Redis sin backups correspondientes..."
    
    # Obtener backups de pgBackRest
    PGBACKREST_BACKUPS=$(docker exec pgbackrest pgbackrest --stanza=main info --output=json 2>/dev/null | grep -o '"label":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    # Obtener claves de Redis
    REDIS_KEYS=$(docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        KEYS "backup:*")
    
    deleted_count=0
    for redis_key in $REDIS_KEYS; do
        # Extraer timestamp de la clave de Redis (formato: backup:YYYY-MM-DD_HH-MM-SS)
        timestamp=$(echo "$redis_key" | sed 's/backup://')
        
        # Convertir a formato de label de pgBackRest (YYYYMMDD-HHMMSS)
        label=$(echo "$timestamp" | tr -d '-' | tr -d ':' | sed 's/_/-/')
        
        # Verificar si el backup existe en pgBackRest
        if ! echo "$PGBACKREST_BACKUPS" | grep -q "$label"; then
            echo "  🗑️  Eliminando registro huérfano: $redis_key"
            docker run --rm --network host redis:7-alpine \
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
                DEL "$redis_key" > /dev/null
            ((deleted_count++))
        fi
    done
    
    if [ $deleted_count -eq 0 ]; then
        echo "✓ No se encontraron registros huérfanos"
    else
        echo "✓ Se eliminaron $deleted_count registros huérfanos de Redis"
    fi
}

# Programa principal
while true; do
    show_menu
    
    case $opcion in
        1)
            echo ""
            expire_backups
            echo ""
            read -p "Presiona Enter para continuar..."
            ;;
        2)
            echo ""
            cleanup_current_retention
            echo ""
            clean_orphan_redis_keys
            echo ""
            read -p "Presiona Enter para continuar..."
            ;;
        3)
            delete_all_backups
            echo ""
            read -p "Presiona Enter para continuar..."
            ;;
        4)
            show_current_backups
            echo ""
            read -p "Presiona Enter para continuar..."
            ;;
        5)
            echo ""
            echo "👋 Saliendo..."
            exit 0
            ;;
        *)
            echo ""
            echo "❌ Opción inválida"
            echo ""
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo ""
done
