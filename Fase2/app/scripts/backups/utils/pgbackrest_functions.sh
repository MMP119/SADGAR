#!/bin/bash
# ===============================================
# Funciones pgBackRest para respaldos PostgreSQL + Redis
# ===============================================

STANZA_NAME="imdb-cluster"
LOG_FILE="/root/bases2/app/scripts/logs/pgbackrest.log"
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p "$(dirname "$LOG_FILE")"

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

detect_master() {
  # Buscar contenedores que tengan postgres levantado
  CONTAINERS=($(docker ps --format "{{.Names}}" | grep -E 'db-(master|slave)|postgres_(master|slave)'))
  if [ ${#CONTAINERS[@]} -eq 0 ]; then
    log_message "ERROR: No se encontró ningún contenedor PostgreSQL levantado."
    exit 1
  fi

  # Comprobar cuál es maestro
  for c in "${CONTAINERS[@]}"; do
    IS_RECOVERY=$(docker exec "$c" psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "f")
    if [[ "$IS_RECOVERY" =~ f ]]; then
      CONTAINER_DB="$c"
      break
    fi
  done

  if [ -z "$CONTAINER_DB" ]; then
    log_message "ERROR: No se pudo detectar contenedor maestro."
    exit 1
  fi

  log_message "Contenedor maestro detectado: $CONTAINER_DB"
}

pgbackrest_full_backup() {
  detect_master
  log_message "Iniciando backup COMPLETO con pgBackRest"
  
  # Ejecutar backup completo
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --type=full \
    backup
  
  # Verificar el backup
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    check
  
  # Obtener información del backup en formato JSON
  BACKUP_INFO=$(docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --output=json \
    info)
  
  # Almacenar en Redis
  redis_log "full" "$BACKUP_INFO"
  
  log_message "Backup completo con pgBackRest finalizado correctamente"
  return 0
}

pgbackrest_incr_backup() {
  detect_master
  log_message "Iniciando backup INCREMENTAL con pgBackRest"
  
  # Ejecutar backup incremental
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --type=incr \
    backup
  
  # Verificar el backup
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    check
  
  # Obtener información del backup
  BACKUP_INFO=$(docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --output=json \
    info)
  
  # Almacenar en Redis
  redis_log "incremental" "$BACKUP_INFO"
  
  log_message "Backup incremental con pgBackRest finalizado correctamente"
  return 0
}

pgbackrest_diff_backup() {
  detect_master
  log_message "Iniciando backup DIFERENCIAL con pgBackRest"
  
  # Ejecutar backup diferencial
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --type=diff \
    backup
  
  # Verificar el backup
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    check
  
  # Obtener información del backup
  BACKUP_INFO=$(docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --output=json \
    info)
  
  # Almacenar en Redis
  redis_log "diferencial" "$BACKUP_INFO"
  
  log_message "Backup diferencial con pgBackRest finalizado correctamente"
  return 0
}

pgbackrest_list_backups() {
  detect_master
  log_message "Listando backups con pgBackRest:"
  
  # Listar backups en formato legible
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    info
  
  # También obtener en formato JSON para Redis
  BACKUP_INFO=$(docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    --output=json \
    info)
  
  redis_log "list" "$BACKUP_INFO"
  return 0
}

pgbackrest_verify() {
  detect_master
  log_message "Verificando integridad de backups con pgBackRest"
  
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    check
  
  log_message "Verificación con pgBackRest completada exitosamente"
  return 0
}

pgbackrest_restore() {
  local backup_set="$1"
  local target_time="$2"
  
  detect_master
  log_message "Iniciando restore con pgBackRest desde backup: $backup_set"
  
  # Detener PostgreSQL
  docker exec "$CONTAINER_DB" pg_ctl stop -D /var/lib/postgresql/data -m fast
  
  # Construir comando de restore
  local restore_cmd="pgbackrest --stanza=$STANZA_NAME --delta"
  
  if [ -n "$target_time" ]; then
    # Point-in-Time Recovery
    restore_cmd="$restore_cmd --type=time --target=$target_time"
    log_message "Ejecutando Point-in-Time Recovery hasta: $target_time"
  fi
  
  restore_cmd="$restore_cmd restore"
  
  # Ejecutar restore
  docker exec "$CONTAINER_DB" bash -c "$restore_cmd"
  
  # Reiniciar PostgreSQL
  docker exec "$CONTAINER_DB" pg_ctl start -D /var/lib/postgresql/data
  
  log_message "Restore con pgBackRest completado exitosamente"
  
  # Registrar restore en Redis
  redis_log "restore" "backup_set:$backup_set,target_time:$target_time,timestamp:$TIMESTAMP"
  
  return 0
}

pgbackrest_archive_status() {
  detect_master
  log_message "Verificando estado de archivado WAL"
  
  # Verificar estado del archivado
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    info --set=current
  
  return 0
}

pgbackrest_cleanup() {
  detect_master
  log_message "Ejecutando limpieza automática de backups antiguos"
  
  # pgBackRest maneja automáticamente la retención según la configuración
  # Pero podemos forzar una limpieza manual si es necesario
  docker exec "$CONTAINER_DB" pgbackrest \
    --stanza="$STANZA_NAME" \
    expire
  
  log_message "Limpieza de backups completada"
  return 0
}