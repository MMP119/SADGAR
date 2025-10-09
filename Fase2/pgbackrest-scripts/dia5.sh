#!/bin/bash
# ===============================================
# DÍA 5: Backup INCREMENTAL + DIFERENCIAL
# ===============================================

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

# Verificar Redis
bash "$SCRIPT_DIR/check_redis.sh"

echo "========================================="
echo "  DÍA 5: BACKUP INCREMENTAL + DIFERENCIAL"
echo "  $(date +'%A, %d de %B de %Y - %H:%M:%S')"
echo "========================================="

# Ejecutar backup incremental
echo "--- Ejecutando INCREMENTAL ---"
if execute_pgbackrest_backup "incr"; then
    echo "✓ Backup incremental completado"
else
    echo "⚠️  Backup incremental falló o no había cambios, continuando..."
fi

echo ""
echo "--- Ejecutando DIFERENCIAL ---"
if execute_pgbackrest_backup "diff"; then
    echo "✓ Backup diferencial completado"
else
    echo "⚠️  Backup diferencial falló o no había cambios"
fi

echo "========================================="
echo "  ✓ DÍA 5 FINALIZADO"
echo "========================================="
