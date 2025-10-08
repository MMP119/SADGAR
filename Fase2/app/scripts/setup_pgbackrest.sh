#!/bin/bash
# =================================================================
# Inicialización completa de pgBackRest en el proyecto
# Este script configura pgBackRest desde cero
# =================================================================

set -e

echo "🚀 === INICIALIZACIÓN DE pgBackRest ==="
echo

STANZA_NAME="imdb-cluster"
PROJECT_ROOT="/root/bases2"  # Ajustar según tu ruta

# 1. Verificar que los contenedores estén corriendo
echo "1️⃣ Verificando contenedores..."
if ! docker ps | grep -q postgres_master; then
    echo "❌ ERROR: Contenedor postgres_master no está corriendo"
    echo "   Ejecuta: docker compose up -d"
    exit 1
fi
echo "✅ Contenedores verificados"

# 2. Instalar pgBackRest en el contenedor master
echo
echo "2️⃣ Instalando pgBackRest en contenedor master..."
docker exec postgres_master sh -c "
    if ! command -v pgbackrest &> /dev/null; then
        apk add --no-cache pgbackrest
    fi
"
echo "✅ pgBackRest instalado"

# 3. Crear directorios necesarios
echo
echo "3️⃣ Creando estructura de directorios..."
docker exec postgres_master sh -c "
    mkdir -p /etc/pgbackrest /var/lib/pgbackrest /var/log/pgbackrest
    chown -R postgres:postgres /var/lib/pgbackrest /var/log/pgbackrest
    chmod 750 /var/lib/pgbackrest /var/log/pgbackrest
"
echo "✅ Directorios creados"

# 4. Configurar pgBackRest
echo
echo "4️⃣ Configurando pgBackRest..."
docker exec postgres_master sh -c "cat > /etc/pgbackrest/pgbackrest.conf << 'EOF'
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=7
repo1-retention-diff=4
repo1-retention-incr=14
log-level-console=info
log-level-file=debug
log-path=/var/log/pgbackrest
compress-type=lz4
compress-level=3

[${STANZA_NAME}]
pg1-path=/var/lib/postgresql/data
pg1-port=5432
pg1-socket-path=/var/run/postgresql
EOF"
echo "✅ Configuración creada"

# 5. Configurar PostgreSQL para archivado WAL
echo
echo "5️⃣ Configurando PostgreSQL para archivado WAL..."
docker exec postgres_master psql -U root -d postgres -c "
    ALTER SYSTEM SET archive_mode = 'on';
    ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=${STANZA_NAME} archive-push %p';
    ALTER SYSTEM SET max_wal_senders = 10;
    ALTER SYSTEM SET wal_level = 'replica';
    SELECT pg_reload_conf();
"
echo "✅ PostgreSQL configurado para archivado"

# 6. Crear stanza
echo
echo "6️⃣ Creando stanza de pgBackRest..."
if docker exec postgres_master pgbackrest --stanza="$STANZA_NAME" stanza-create 2>/dev/null; then
    echo "✅ Stanza creada exitosamente"
else
    echo "⚠️  Stanza ya existe o error en creación, continuando..."
fi

# 7. Verificar configuración
echo
echo "7️⃣ Verificando configuración..."
if docker exec postgres_master pgbackrest --stanza="$STANZA_NAME" check; then
    echo "✅ Configuración verificada exitosamente"
else
    echo "❌ ERROR en verificación de configuración"
    exit 1
fi

# 8. Ejecutar primer backup completo
echo
echo "8️⃣ Ejecutando primer backup completo..."
if docker exec postgres_master pgbackrest --stanza="$STANZA_NAME" --type=full backup; then
    echo "✅ Primer backup completo exitoso"
else
    echo "❌ ERROR en primer backup"
    exit 1
fi

# 9. Mostrar información del backup
echo
echo "9️⃣ Información de backups:"
docker exec postgres_master pgbackrest --stanza="$STANZA_NAME" info

# 10. Hacer los scripts ejecutables
echo
echo "🔧 Configurando permisos de scripts..."
chmod +x app/scripts/backups/dia*_pgbackrest.sh
chmod +x app/scripts/backups/ver_backups_pgbackrest.sh
chmod +x app/scripts/backups/utils/pgbackrest_functions.sh

echo
echo "🎉 === INICIALIZACIÓN COMPLETADA ==="
echo
echo "📋 PRÓXIMOS PASOS:"
echo "1️⃣ Probar los scripts de backup:"
echo "   bash app/scripts/backups/dia1_pgbackrest.sh"
echo "   bash app/scripts/backups/dia2_pgbackrest.sh"
echo "   ... etc ..."
echo
echo "2️⃣ Ver backups:"
echo "   bash app/scripts/backups/ver_backups_pgbackrest.sh"
echo
echo "3️⃣ Usar la API extendida:"
echo "   uvicorn api_control_pgbackrest:app --host 0.0.0.0 --port 8088"
echo
echo "✨ pgBackRest está listo para usar!"