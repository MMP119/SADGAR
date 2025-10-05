#!/bin/bash
# ===============================================
# Funciones comunes para respaldos PostgreSQL + Redis externo
# ===============================================

BACKUP_DIR="/root/bases2/backups"
LOG_FILE="/root/bases2/app/scripts/logs/backups.log"
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p "$BACKUP_DIR/completo" "$BACKUP_DIR/diferencial" "$BACKUP_DIR/incremental" "$BACKUP_DIR/logs"

log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

redis_log() {
  local tipo="$1"
  local archivo="$2"
  docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    set "backup:${tipo}:${TIMESTAMP}" "$archivo" > /dev/null
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

backup_completo() {
  detect_master
  local archivo="$BACKUP_DIR/completo/backup_completo_${TIMESTAMP}.sql.gz"
  log_message "Iniciando backup completo → $archivo"
  docker exec "$CONTAINER_DB" pg_dumpall -U root | gzip > "$archivo"
  redis_log "completo" "$archivo"
  log_message "Backup completo finalizado correctamente."
}

backup_incremental() {
  detect_master
  local archivo="$BACKUP_DIR/incremental/backup_incremental_${TIMESTAMP}.sql.gz"
  log_message "Iniciando backup incremental → $archivo"
  docker exec "$CONTAINER_DB" pg_dump -U root --data-only postgres | gzip > "$archivo"
  redis_log "incremental" "$archivo"
  log_message "Backup incremental finalizado correctamente."
}

backup_diferencial() {
  detect_master
  local archivo="$BACKUP_DIR/diferencial/backup_diferencial_${TIMESTAMP}.tar"
  log_message "Iniciando backup diferencial → $archivo"
  docker exec "$CONTAINER_DB" tar -cf /tmp/pg_wal_backup.tar /var/lib/postgresql/data/pg_wal
  docker cp "$CONTAINER_DB":/tmp/pg_wal_backup.tar "$archivo"
  docker exec "$CONTAINER_DB" rm /tmp/pg_wal_backup.tar
  redis_log "diferencial" "$archivo"
  log_message "Backup diferencial finalizado correctamente."
}
