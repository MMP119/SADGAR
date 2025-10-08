#!/bin/bash
set -e
source "$(dirname "$0")/utils/pgbackrest_functions.sh"
bash "$(dirname "$0")/check_redis.sh"

log_message "--- DÍA 4: Backup INCREMENTAL con pgBackRest ---"
pgbackrest_incr_backup
log_message "--- DÍA 4 con pgBackRest finalizado correctamente ---"