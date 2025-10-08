#!/bin/bash
set -e
source "$(dirname "$0")/utils/pgbackrest_functions.sh"
bash "$(dirname "$0")/check_redis.sh"

log_message "--- DÍA 5: Backup INCREMENTAL + DIFERENCIAL con pgBackRest ---"
pgbackrest_incr_backup
pgbackrest_diff_backup
log_message "--- DÍA 5 con pgBackRest finalizado correctamente ---"