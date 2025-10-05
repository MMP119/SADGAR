#!/bin/bash
# ===============================================
# Script para mostrar todos los backups registrados en Redis (ordenados por timestamp legible)
# ===============================================

REDIS_HOST="127.0.0.1"
REDIS_PORT=6379

echo "Conectando a Redis en $REDIS_HOST:$REDIS_PORT..."
echo "Listado de backups registrados:"

# Listar todas las keys de backups
KEYS=$(docker run --rm --network host redis:7-alpine redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" keys "backup:*")

if [ -z "$KEYS" ]; then
  echo "No se encontraron backups registrados en Redis."
  exit 0
fi

# Guardar tipo, timestamp y archivo en un array temporal
declare -a BACKUPS
for key in $KEYS; do
  value=$(docker run --rm --network host redis:7-alpine redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" get "$key")
  tipo=$(echo "$key" | cut -d':' -f2)
  timestamp=$(echo "$key" | cut -d':' -f3)
  BACKUPS+=("$timestamp|$tipo|$value")
done

# Ordenar por timestamp descendente (más reciente primero)
IFS=$'\n' sorted=($(sort -r <<<"${BACKUPS[*]}"))
unset IFS

# Mostrar los backups ordenados con timestamp legible
for entry in "${sorted[@]}"; do
  timestamp=$(echo "$entry" | cut -d'|' -f1)
  tipo=$(echo "$entry" | cut -d'|' -f2)
  archivo=$(echo "$entry" | cut -d'|' -f3)
  
  # Convertir timestamp a formato legible
  # Suponiendo timestamp como YYYY-MM-DD_HH-MM-SS
  timestamp_legible=$(echo "$timestamp" | sed 's/_/ /; s/-/:/g; s/-/:/g; s/-/:/g')
  
  echo "----------------------------------------"
  echo "Tipo de backup : $tipo"
  echo "Fecha/Hora     : $timestamp_legible"
  echo "Archivo        : $archivo"
done

echo "----------------------------------------"
echo "Fin del listado de backups."
