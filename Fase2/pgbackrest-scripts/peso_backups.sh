#!/bin/bash
# ===============================================
# Script para ver el peso/tamaño de los backups
# ===============================================

echo "=========================================="
echo "  TAMAÑO DE BACKUPS - pgBackRest"
echo "=========================================="
echo ""

# Verificar que el contenedor pgbackrest exista
if ! docker ps -a --format "{{.Names}}" | grep -q "^pgbackrest$"; then
    echo "❌ ERROR: Contenedor pgbackrest no encontrado"
    exit 1
fi

# Mostrar información del repositorio
echo "📊 INFORMACIÓN DEL REPOSITORIO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Obtener información detallada de backups con pgBackRest
echo ""
echo "🔍 Listado de backups con tamaño:"
echo ""

docker exec pgbackrest pgbackrest --stanza=main info --output=text

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 ESPACIO EN DISCO DEL REPOSITORIO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Tamaño total del directorio de backups
TOTAL_SIZE=$(docker exec pgbackrest du -sh /var/lib/pgbackrest 2>/dev/null | awk '{print $1}')
echo "💾 Espacio total usado: $TOTAL_SIZE"

# Desglose por tipo de backup
echo ""
echo "📦 Desglose por directorio:"
docker exec pgbackrest du -h --max-depth=2 /var/lib/pgbackrest 2>/dev/null | sort -h

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 TIPS:"
echo "  • Los backups incrementales/diferenciales son mucho más pequeños"
echo "  • Usa 'bash pgbackrest-scripts/limpiar_backups.sh' para eliminar backups antiguos"
echo "  • La retención actual mantiene los últimos 2 backups completos"
echo "=========================================="
