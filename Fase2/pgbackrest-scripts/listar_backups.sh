#!/bin/bash
# ===============================================
# Script simple para listar backups en formato tabla
# ===============================================

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║                               LISTADO DE BACKUPS REGISTRADOS                                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar si hay backups
BACKUP_COUNT=$(docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    KEYS "backup:*" | wc -l)

if [ "$BACKUP_COUNT" -eq 0 ]; then
    echo "  ⚠️  No hay backups registrados en Redis"
    echo ""
    exit 0
fi

printf "  %-4s %-12s %-10s %-15s %-20s %-20s\n" "#" "FECHA" "HORA" "TIPO" "MAESTRO" "UBICACIÓN"
echo "  ────────────────────────────────────────────────────────────────────────────────────────────────────"

# Obtener todas las claves de backups y ordenarlas
BACKUPS=$(docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    KEYS "backup:*" | sort)

contador=1
for backup_key in $BACKUPS; do
    # Obtener datos del backup
    BACKUP_DATA=$(docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        HGETALL "$backup_key")
    
    fecha=$(echo "$BACKUP_DATA" | grep -A1 "^fecha$" | tail -n1)
    hora=$(echo "$BACKUP_DATA" | grep -A1 "^hora$" | tail -n1)
    tipo=$(echo "$BACKUP_DATA" | grep -A1 "^tipo_backup$" | tail -n1)
    maestro=$(echo "$BACKUP_DATA" | grep -A1 "^maestro_usado$" | tail -n1)
    direccion=$(echo "$BACKUP_DATA" | grep -A1 "^direccion_almacenamiento$" | tail -n1)
    
    # Acortar la dirección para que quepa
    direccion_corta="...${direccion: -17}"
    
    printf "  %-4s %-12s %-10s %-15s %-20s %-20s\n" \
        "$contador" "$fecha" "$hora" "$tipo" "$maestro" "$direccion_corta"
    
    ((contador++))
done

echo ""
echo "  Total de backups: $BACKUP_COUNT"
echo ""
