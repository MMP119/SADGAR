#!/bin/bash
# ===============================================
# DÍA 6: Backup DIFERENCIAL + COMPLETO (cierre de ciclo)
# ===============================================

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

# Verificar Redis
bash "$SCRIPT_DIR/check_redis.sh"

echo "========================================="
echo "  DÍA 6: BACKUP DIFERENCIAL + COMPLETO"
echo "  $(date +'%A, %d de %B de %Y - %H:%M:%S')"
echo "========================================="

# Ejecutar backup diferencial
echo "--- Ejecutando DIFERENCIAL ---"
if execute_pgbackrest_backup "diff"; then
    echo "✓ Backup diferencial completado"
else
    echo "⚠️  Backup diferencial falló o no había cambios, continuando..."
fi

echo ""
echo "--- Ejecutando COMPLETO (nuevo ciclo) ---"
if execute_pgbackrest_backup "full"; then
    echo "✓ Backup completo completado - nuevo ciclo iniciado"
else
    echo "❌ Backup completo falló"
    exit 1
fi

echo "========================================="
echo "  ✓ DÍA 6 FINALIZADO - NUEVO CICLO INICIADO"
echo "========================================="
