#!/bin/bash
set -e
source "$(dirname "$0")/utils/backup_functions.sh"
bash "$(dirname "$0")/check_redis.sh"

log_message "--- DÍA 3: Backup INCREMENTAL + DIFERENCIAL ---"
backup_incremental
backup_diferencial
log_message "--- DÍA 3 finalizado correctamente ---"
