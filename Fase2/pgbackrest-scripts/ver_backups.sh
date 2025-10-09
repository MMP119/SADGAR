#!/bin/bash
# ===============================================
# Script para visualizar backups registrados en Redis
# ===============================================

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo "=========================================="
echo "  BACKUPS REGISTRADOS EN REDIS"
echo "=========================================="
echo ""

# Verificar si hay backups
BACKUP_COUNT=$(docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    KEYS "backup:*" | wc -l)

if [ "$BACKUP_COUNT" -eq 0 ]; then
    echo "⚠️  No hay backups registrados en Redis"
    exit 0
fi

echo "📊 Total de backups: $BACKUP_COUNT"
echo ""

# Obtener todas las claves de backups y ordenarlas
BACKUPS=$(docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    KEYS "backup:*" | sort)

contador=1
for backup_key in $BACKUPS; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 BACKUP #$contador"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Obtener todos los campos del backup
    BACKUP_DATA=$(docker run --rm --network host redis:7-alpine \
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
        HGETALL "$backup_key")
    
    # Extraer y mostrar cada campo
    fecha=$(echo "$BACKUP_DATA" | grep -A1 "^fecha$" | tail -n1)
    hora=$(echo "$BACKUP_DATA" | grep -A1 "^hora$" | tail -n1)
    tipo=$(echo "$BACKUP_DATA" | grep -A1 "^tipo_backup$" | tail -n1)
    direccion=$(echo "$BACKUP_DATA" | grep -A1 "^direccion_almacenamiento$" | tail -n1)
    maestro=$(echo "$BACKUP_DATA" | grep -A1 "^maestro_usado$" | tail -n1)
    
    echo "  📅 Fecha:       $fecha"
    echo "  🕐 Hora:        $hora"
    echo "  📦 Tipo:        $tipo"
    echo "  📁 Ubicación:   $direccion"
    echo "  🖥️  Maestro:     $maestro"
    echo ""
    
    ((contador++))
done

echo "=========================================="
echo "  ✓ Fin del listado"
echo "=========================================="