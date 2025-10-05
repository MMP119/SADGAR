#!/bin/bash
set -e
source "$(dirname "$0")/utils/backup_functions.sh"
bash "$(dirname "$0")/check_redis.sh"

log_message "--- DÍA 6: Backup DIFERENCIAL + COMPLETO ---"
backup_diferencial
backup_completo
log_message "--- DÍA 6 finalizado correctamente ---"
