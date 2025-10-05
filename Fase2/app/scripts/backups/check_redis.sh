#!/bin/bash
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

if docker run --rm --network host redis:7-alpine redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping | grep -q "PONG"; then
  echo "Redis está disponible en $REDIS_HOST:$REDIS_PORT"
else
  echo "Redis no responde. Asegúrate de que esté levantado con:"
  echo "docker compose -f redis-compose.yml up -d"
  exit 1
fi
