#!/bin/bash
# ===============================================
# DÍA 1: Backup COMPLETO
# ===============================================

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

# Verificar Redis
bash "$SCRIPT_DIR/check_redis.sh"

echo "========================================="
echo "  DÍA 1: BACKUP COMPLETO"
echo "  $(date +'%A, %d de %B de %Y - %H:%M:%S')"
echo "========================================="

# Ejecutar backup completo
if execute_pgbackrest_backup "full"; then
    echo "✓ Backup completo exitoso"
else
    echo "❌ Backup completo falló"
    exit 1
fi

echo "========================================="
echo "  ✓ DÍA 1 FINALIZADO"
echo "========================================="
