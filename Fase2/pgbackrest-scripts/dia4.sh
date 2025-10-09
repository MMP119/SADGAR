#!/bin/bash
# ===============================================
# DÍA 4: Backup INCREMENTAL
# ===============================================

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

# Verificar Redis
bash "$SCRIPT_DIR/check_redis.sh"

echo "========================================="
echo "  DÍA 4: BACKUP INCREMENTAL"
echo "  $(date +'%A, %d de %B de %Y - %H:%M:%S')"
echo "========================================="

# Ejecutar backup incremental
if execute_pgbackrest_backup "incr"; then
    echo "✓ Backup incremental exitoso"
else
    echo "⚠️  Backup incremental falló o no había cambios"
fi

echo "========================================="
echo "  ✓ DÍA 4 FINALIZADO"
echo "========================================="
