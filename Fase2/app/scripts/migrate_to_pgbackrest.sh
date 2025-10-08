#!/bin/bash
# =================================================================
# Script de migración a pgBackRest
# Convierte el sistema actual de backups a pgBackRest
# =================================================================

set -e

echo "--- MIGRACIÓN A PGBACKREST ---"

# 1. Configurar pgBackRest en el contenedor master
echo "1. Configurando pgBackRest..."
docker exec postgres_master sh -c "
    apk add --no-cache pgbackrest
    mkdir -p /etc/pgbackrest /var/lib/pgbackrest /var/log/pgbackrest
    chown postgres:postgres /var/lib/pgbackrest /var/log/pgbackrest
"

# 2. Copiar configuración
echo "2. Copiando configuración..."
docker cp ./config/pgbackrest/pgbackrest.conf postgres_master:/etc/pgbackrest/

# 3. Crear stanza
echo "3. Creando stanza..."
docker exec postgres_master pgbackrest --stanza=imdb-cluster stanza-create

# 4. Verificar configuración
echo "4. Verificando configuración..."
docker exec postgres_master pgbackrest --stanza=imdb-cluster check

# 5. Primer backup completo
echo "5. Ejecutando primer backup completo..."
docker exec postgres_master pgbackrest --stanza=imdb-cluster --type=full backup

# 6. Configurar archivado WAL en PostgreSQL
echo "6. Configurando archivado WAL..."
docker exec postgres_master psql -U root -d postgres -c "
    ALTER SYSTEM SET archive_mode = 'on';
    ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=imdb-cluster archive-push %p';
    SELECT pg_reload_conf();
"

echo "--- MIGRACIÓN COMPLETADA ---"
echo "pgBackRest está configurado y listo para usar"

# Mostrar información de backups
echo "--- INFORMACIÓN DE BACKUPS ---"
docker exec postgres_master pgbackrest --stanza=imdb-cluster info