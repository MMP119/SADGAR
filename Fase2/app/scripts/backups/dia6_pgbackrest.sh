#!/bin/bash
set -e
source "$(dirname "$0")/utils/pgbackrest_functions.sh"
bash "$(dirname "$0")/check_redis.sh"

log_message "--- DÍA 6: Backup DIFERENCIAL + COMPLETO con pgBackRest ---"
pgbackrest_diff_backup
pgbackrest_full_backup
log_message "--- DÍA 6 con pgBackRest finalizado correctamente ---"