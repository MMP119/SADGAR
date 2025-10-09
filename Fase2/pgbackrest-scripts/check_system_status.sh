#!/bin/bash
# =========================================
# GUÍA DE PROCEDIMIENTO - PROYECTO FASE 2
# =========================================

echo "=========================================="
echo "  ESTADO ACTUAL DEL SISTEMA"
echo "=========================================="
echo ""

# Verificar contenedores
echo "1. Verificando contenedores Docker..."
docker compose ps

echo ""
echo "2. Detectando roles actuales..."
echo ""

# Detectar maestro actual
for container in postgres_master postgres_slave; do
    if docker exec $container psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null | grep -q "f"; then
        echo "   ✓ MAESTRO ACTUAL: $container"
        MAESTRO=$container
    else
        echo "   - Esclavo: $container"
    fi
done

echo ""
echo "=========================================="
echo "  PROCEDIMIENTO RECOMENDADO"
echo "=========================================="
echo ""

if [ "$MAESTRO" != "postgres_master" ]; then
    echo "⚠️  ADVERTENCIA: El maestro lógico NO es postgres_master"
    echo ""
    echo "Opciones:"
    echo "  A) Ejecutar FAILBACK para volver a la configuración original"
    echo "     → bash app/scripts/failback.sh"
    echo ""
    echo "  B) Continuar con la configuración actual (no recomendado para backups)"
    echo ""
else
    echo "✓ Sistema en configuración original (postgres_master es maestro)"
    echo ""
    echo "Pasos a seguir:"
    echo ""
    echo "1. Configurar pgBackRest (SOLO PRIMERA VEZ):"
    echo "   → bash pgbackrest-scripts/stanza_create.sh"
    echo ""
    echo "2. Verificar configuración:"
    echo "   → docker exec pgbackrest pgbackrest --stanza=main info"
    echo ""
    echo "3. Ejecutar primer backup (día 1):"
    echo "   → bash pgbackrest-scripts/check_redis.sh"
    echo "   → bash pgbackrest-scripts/dia1.sh"
    echo ""
    echo "4. Ver backups registrados:"
    echo "   → bash pgbackrest-scripts/ver_backups.sh"
    echo ""
    echo "5. Continuar con ciclo diario (días 2-6):"
    echo "   → bash pgbackrest-scripts/dia2.sh"
    echo "   → bash pgbackrest-scripts/dia3.sh"
    echo "   → etc..."
    echo ""
fi

echo "=========================================="
echo "  NOTAS IMPORTANTES"
echo "=========================================="
echo ""
echo "• Los BACKUPS deben hacerse con postgres_master como maestro lógico"
echo "• Si ejecutas FAILOVER, NO hagas backups hasta hacer FAILBACK"
echo "• Después de FAILBACK, espera a que se sincronice antes de backup"
echo "• Verifica siempre el estado antes de ejecutar backups"
echo ""
echo "Para verificar estado en cualquier momento:"
echo "  → bash pgbackrest-scripts/check_system_status.sh"
echo ""
