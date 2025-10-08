#!/bin/bash
# =================================================================
# pgBackRest Integration Script
# Reemplaza el sistema actual de backups con pgBackRest
# =================================================================

set -e

STANZA_NAME="imdb-cluster"
LOG_FILE="/var/log/pgbackrest/pgbackrest.log"
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

log_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

redis_log() {
    local tipo="$1"
    local info="$2"
    docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        set "pgbackrest:${tipo}:${TIMESTAMP}" "$info" > /dev/null
}

# Función para backup completo con pgBackRest
pgbackrest_full_backup() {
    log_message "Iniciando backup COMPLETO con pgBackRest"
    
    # Ejecutar backup completo
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        --type=full \
        backup
    
    # Verificar el backup
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        check
    
    # Obtener información del backup
    BACKUP_INFO=$(docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        --output=json \
        info)
    
    redis_log "full" "$BACKUP_INFO"
    log_message "Backup completo finalizado correctamente"
}

# Función para backup incremental con pgBackRest
pgbackrest_incr_backup() {
    log_message "Iniciando backup INCREMENTAL con pgBackRest"
    
    # Ejecutar backup incremental
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        --type=incr \
        backup
    
    # Verificar el backup
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        check
    
    # Obtener información del backup
    BACKUP_INFO=$(docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        --output=json \
        info)
    
    redis_log "incremental" "$BACKUP_INFO"
    log_message "Backup incremental finalizado correctamente"
}

# Función para backup diferencial con pgBackRest
pgbackrest_diff_backup() {
    log_message "Iniciando backup DIFERENCIAL con pgBackRest"
    
    # Ejecutar backup diferencial
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        --type=diff \
        backup
    
    # Verificar el backup
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        check
    
    # Obtener información del backup
    BACKUP_INFO=$(docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        --output=json \
        info)
    
    redis_log "diferencial" "$BACKUP_INFO"
    log_message "Backup diferencial finalizado correctamente"
}

# Función para listar backups
pgbackrest_list_backups() {
    log_message "Listando backups disponibles:"
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        info
}

# Función para restore específico
pgbackrest_restore() {
    local backup_set="$1"
    local target_time="$2"
    
    log_message "Iniciando restore desde backup: $backup_set"
    
    # Detener PostgreSQL
    docker exec postgres_master pg_ctl stop -D /var/lib/postgresql/data
    
    # Ejecutar restore
    if [ -n "$target_time" ]; then
        # Point-in-Time Recovery
        docker exec postgres_master pgbackrest \
            --stanza="$STANZA_NAME" \
            --delta \
            --type=time \
            --target="$target_time" \
            restore
    else
        # Restore completo
        docker exec postgres_master pgbackrest \
            --stanza="$STANZA_NAME" \
            --delta \
            restore
    fi
    
    # Reiniciar PostgreSQL
    docker exec postgres_master pg_ctl start -D /var/lib/postgresql/data
    
    log_message "Restore completado exitosamente"
}

# Función para verificar backups
pgbackrest_verify() {
    log_message "Verificando integridad de backups"
    docker exec postgres_master pgbackrest \
        --stanza="$STANZA_NAME" \
        check
    log_message "Verificación completada"
}

case "$1" in
    "full")
        pgbackrest_full_backup
        ;;
    "incr")
        pgbackrest_incr_backup
        ;;
    "diff")
        pgbackrest_diff_backup
        ;;
    "list")
        pgbackrest_list_backups
        ;;
    "verify")
        pgbackrest_verify
        ;;
    "restore")
        pgbackrest_restore "$2" "$3"
        ;;
    *)
        echo "Uso: $0 {full|incr|diff|list|verify|restore [backup_set] [target_time]}"
        exit 1
        ;;
esac