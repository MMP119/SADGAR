#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

echo "=========================================="
echo "  BACKUP COMPLETO (FULL)"
echo "  $(date +'%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Ejecutar backup completo
execute_pgbackrest_backup "full"

echo ""
echo "=========================================="
echo "  ✓ BACKUP COMPLETO FINALIZADO"
echo "=========================================="
