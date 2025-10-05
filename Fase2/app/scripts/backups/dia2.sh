#!/bin/bash
set -e
source "$(dirname "$0")/utils/backup_functions.sh"
bash "$(dirname "$0")/check_redis.sh"

log_message "--- DÍA 2: Backup INCREMENTAL ---"
backup_incremental
log_message "--- DÍA 2 finalizado correctamente ---"
