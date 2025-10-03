#!/bin/bash
set -e
echo "--- INICIANDO FAILBACK EN CALIENTE CON SLOT ---"

# -----------------------------
# Detectar maestro y slave actuales
# -----------------------------
if docker compose exec -T db-master psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();" | grep -q '^f'; then
    CURRENT_MASTER="db-master"
    CURRENT_SLAVE="db-slave"
else
    CURRENT_MASTER="db-slave"
    CURRENT_SLAVE="db-master"
fi

echo "Roles detectados:"
echo "  Maestro actual: $CURRENT_MASTER"
echo "  Contenedor a sincronizar: $CURRENT_SLAVE"

# -----------------------------
# Paso 1: Detener el slave que se va a resync
# -----------------------------
echo "1. Deteniendo $CURRENT_SLAVE..."
docker compose stop $CURRENT_SLAVE || true

# -----------------------------
# Paso 2: Limpiar data directory del slave
# -----------------------------
echo "2. Limpiando data directory del volumen correspondiente..."
SLAVE_VOL=$(docker volume inspect bases2_"${CURRENT_SLAVE#db-}"_data -f '{{.Mountpoint}}')
rm -rf "$SLAVE_VOL"/*

# -----------------------------
# Paso 3: Verificar/crear replication slot en el maestro
# -----------------------------
echo "3. Verificando/creando slot de replicación en el maestro ($CURRENT_MASTER)..."
SLOT_EXISTS=$(docker compose exec -T $CURRENT_MASTER psql -U replicator -d postgres -tAc "SELECT 1 FROM pg_replication_slots WHERE slot_name='replication_slot';")
if [ "$SLOT_EXISTS" != "1" ]; then
    echo "   Slot 'replication_slot' no existe. Creando..."
    docker compose exec -T $CURRENT_MASTER psql -U replicator -d postgres -c "SELECT pg_create_physical_replication_slot('replication_slot');"
else
    echo "   Slot 'replication_slot' ya existe."
fi

# -----------------------------
# Paso 4: Ejecutar pg_basebackup desde contenedor temporal
# -----------------------------
echo "4. Ejecutando pg_basebackup desde un contenedor temporal..."
PROJECT_NET=$(docker network ls | grep bases2_default | awk '{print $1}')

docker run --rm \
  -v "$SLAVE_VOL":/var/lib/postgresql/data \
  --network "$PROJECT_NET" \
  postgres:16-alpine \
  pg_basebackup -h $CURRENT_MASTER -p 5432 \
  -D /var/lib/postgresql/data \
  -U replicator -vP -w -R -S replication_slot

# -----------------------------
# Paso 5: Levantar slave ya sincronizado
# -----------------------------
echo "5. Levantando $CURRENT_SLAVE ya sincronizado..."
docker compose up -d $CURRENT_SLAVE
sleep 5

echo "--- FAILBACK COMPLETADO ---"
echo "$CURRENT_SLAVE ahora funciona como esclavo de $CURRENT_MASTER."
