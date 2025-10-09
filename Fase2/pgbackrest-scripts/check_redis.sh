#!/bin/bash
# ===============================================
# Script para verificar la disponibilidad de Redis
# ===============================================
set -e

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo "Verificando conexión con Redis en $REDIS_HOST:$REDIS_PORT..."

if docker run --rm --network host redis:7-alpine \
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>/dev/null | grep -q "PONG"; then
  echo "✓ Redis está disponible y respondiendo correctamente"
  exit 0
else
  echo "✗ ERROR: Redis no responde."
  echo "  Asegúrate de que Redis esté levantado con:"
  echo "  docker compose up -d redis"
  exit 1
fi
