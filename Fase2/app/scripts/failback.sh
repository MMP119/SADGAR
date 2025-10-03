#!/bin/bash
set -e

echo "--- INICIANDO FAILBACK EN CALIENTE ---"

# Paso 1: Detener db-master
echo "1. Deteniendo db-master..."
docker compose stop db-master || true

# Paso 2: Limpiar data directory del master
echo "2. Limpiando data directory del volumen master_data..."
MASTER_VOL=$(docker volume inspect bases2_master_data -f '{{.Mountpoint}}')
rm -rf "$MASTER_VOL"/*

# Paso 3: Verificar que db-slave (nuevo maestro) esté listo
echo "3. Verificando que db-slave (nuevo maestro) esté listo..."
until docker compose exec -T db-slave pg_isready -U replicator -h localhost -p 5432; do
  echo "   -> Esperando..."
  sleep 2
done

# Paso 4: Ejecutar pg_basebackup desde un contenedor temporal (sin slot)
echo "4. Ejecutando pg_basebackup desde un contenedor temporal..."
PROJECT_NET=$(docker network ls | grep bases2_default | awk '{print $1}')

docker run --rm \
  -v bases2_master_data:/var/lib/postgresql/data \
  --network "$PROJECT_NET" \
  postgres:16-alpine \
  pg_basebackup -h postgres_slave -p 5432 \
  -D /var/lib/postgresql/data \
  -U replicator -vP -w -R

# Paso 5: Levantar db-master normalmente
echo "5. Levantando db-master ya sincronizado..."
docker compose up -d db-master
sleep 10

echo "--- FAILBACK COMPLETADO ---"
echo "db-master ahora funciona como esclavo del db-slave."