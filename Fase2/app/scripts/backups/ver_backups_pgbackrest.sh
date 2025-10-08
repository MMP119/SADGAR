#!/bin/bash
# ===============================================
# Script para visualizar backups de pgBackRest en Redis
# ===============================================

set -e
source "$(dirname "$0")/utils/pgbackrest_functions.sh"

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo "=== BACKUPS pgBackRest EN REDIS ==="
echo

# Verificar conexión a Redis
if ! docker run --rm --network host redis:7-alpine redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
    echo "ERROR: No se puede conectar a Redis en $REDIS_HOST:$REDIS_PORT"
    exit 1
fi

echo "📦 BACKUPS COMPLETOS:"
docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    keys "pgbackrest:full:*" | while read key; do
    if [ -n "$key" ]; then
        echo "  🔵 $key"
        docker run --rm --network host redis:7-alpine \
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            get "$key" | jq -r '.[0].backup[-1] | "     Último backup: \(.label) - \(.timestamp.start)"' 2>/dev/null || echo "     (información no disponible)"
    fi
done

echo
echo "📈 BACKUPS INCREMENTALES:"
docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    keys "pgbackrest:incremental:*" | while read key; do
    if [ -n "$key" ]; then
        echo "  🟡 $key"
        docker run --rm --network host redis:7-alpine \
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            get "$key" | jq -r '.[0].backup[-1] | "     Último backup: \(.label) - \(.timestamp.start)"' 2>/dev/null || echo "     (información no disponible)"
    fi
done

echo
echo "📊 BACKUPS DIFERENCIALES:"
docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    keys "pgbackrest:diferencial:*" | while read key; do
    if [ -n "$key" ]; then
        echo "  🟠 $key"
        docker run --rm --network host redis:7-alpine \
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
            get "$key" | jq -r '.[0].backup[-1] | "     Último backup: \(.label) - \(.timestamp.start)"' 2>/dev/null || echo "     (información no disponible)"
    fi
done

echo
echo "📋 RESUMEN TOTAL:"
TOTAL_KEYS=$(docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
    keys "pgbackrest:*" | wc -l)
echo "  Total de backups registrados: $TOTAL_KEYS"

echo
echo "=== INFORMACIÓN DIRECTA DE pgBackRest ==="
detect_master
if [ -n "$CONTAINER_DB" ]; then
    echo "📊 Estado actual de backups en el contenedor $CONTAINER_DB:"
    docker exec "$CONTAINER_DB" pgbackrest --stanza=imdb-cluster info 2>/dev/null || echo "  (pgBackRest no configurado aún)"
fi

echo
echo "=== FIN DEL REPORTE ==="