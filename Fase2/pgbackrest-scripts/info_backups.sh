#!/bin/bash
# ===============================================
# Script para ver información completa de backups
# Incluye: Redis metadata + pgBackRest info con tamaños
# ===============================================

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                  INFORMACIÓN COMPLETA DE BACKUPS                   ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Sección 1: Información de pgBackRest
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 INFORMACIÓN DE pgBackRest (con tamaños)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

docker exec pgbackrest pgbackrest --stanza=main info --output=text

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 ESPACIO EN DISCO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL_SIZE=$(docker exec pgbackrest du -sh /var/lib/pgbackrest 2>/dev/null | awk '{print $1}')
echo "  💿 Espacio total usado por backups: $TOTAL_SIZE"

# Contar backups por tipo
FULL_COUNT=$(docker exec pgbackrest pgbackrest --stanza=main info --output=text 2>/dev/null | grep -c "full backup:" || echo "0")
INCR_COUNT=$(docker exec pgbackrest pgbackrest --stanza=main info --output=text 2>/dev/null | grep -c "incr backup:" || echo "0")
DIFF_COUNT=$(docker exec pgbackrest pgbackrest --stanza=main info --output=text 2>/dev/null | grep -c "diff backup:" || echo "0")

echo "  📦 Backups completos:      $FULL_COUNT"
echo "  📦 Backups incrementales:  $INCR_COUNT"
echo "  📦 Backups diferenciales:  $DIFF_COUNT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 METADATOS DE REDIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar si hay backups en Redis
BACKUP_COUNT=$(docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    KEYS "backup:*" | wc -l)

if [ "$BACKUP_COUNT" -eq 0 ]; then
    echo "  ⚠️  No hay backups registrados en Redis"
else
    echo "  📊 Total de registros: $BACKUP_COUNT"
    echo ""
    
    # Obtener todas las claves de backups y ordenarlas
    BACKUPS=$(docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        KEYS "backup:*" | sort)
    
    # Formato tabla
    printf "  %-20s %-10s %-15s %-20s\n" "FECHA" "HORA" "TIPO" "MAESTRO"
    printf "  %-20s %-10s %-15s %-20s\n" "--------------------" "----------" "---------------" "--------------------"
    
    for backup_key in $BACKUPS; do
        # Obtener datos del backup
        BACKUP_DATA=$(docker run --rm --network host redis:7-alpine \
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            HGETALL "$backup_key")
        
        fecha=$(echo "$BACKUP_DATA" | grep -A1 "^fecha$" | tail -n1)
        hora=$(echo "$BACKUP_DATA" | grep -A1 "^hora$" | tail -n1)
        tipo=$(echo "$BACKUP_DATA" | grep -A1 "^tipo_backup$" | tail -n1)
        maestro=$(echo "$BACKUP_DATA" | grep -A1 "^maestro_usado$" | tail -n1)
        
        printf "  %-20s %-10s %-15s %-20s\n" "$fecha" "$hora" "$tipo" "$maestro"
    done
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  💡 COMANDOS ÚTILES                                                ║"
echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║  • Ver peso detallado:   bash pgbackrest-scripts/peso_backups.sh  ║"
echo "║  • Limpiar backups:      bash pgbackrest-scripts/limpiar_backups.sh║"
echo "║  • Ver solo metadatos:   bash pgbackrest-scripts/ver_backups.sh   ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
