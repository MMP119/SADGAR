#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

echo "=========================================="
echo "  BACKUP INCREMENTAL"
echo "  $(date +'%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Ejecutar backup incremental
execute_pgbackrest_backup "incr"

echo ""
echo "=========================================="
echo "  ✓ BACKUP INCREMENTAL FINALIZADO"
echo "=========================================="
