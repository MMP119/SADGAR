#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

echo "=========================================="
echo "  BACKUP DIFERENCIAL"
echo "  $(date +'%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Ejecutar backup diferencial
execute_pgbackrest_backup "diff"

echo ""
echo "=========================================="
echo "  ✓ BACKUP DIFERENCIAL FINALIZADO"
echo "=========================================="
