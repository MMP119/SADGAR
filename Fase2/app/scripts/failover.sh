#!/bin/bash
set -e
echo "--- INICIANDO FAILOVER ---"

# -----------------------------
# Paso 0: Detectar maestro/esclavo actual
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
echo "  Contenedor a promover: $CURRENT_SLAVE"

# -----------------------------
# Paso 1: Detener el maestro actual
# -----------------------------
echo "1. Deteniendo $CURRENT_MASTER..."
docker compose stop $CURRENT_MASTER || true

# -----------------------------
# Paso 2: Promover el esclavo a maestro
# -----------------------------
echo "2. Promoviendo $CURRENT_SLAVE a maestro..."
docker compose exec -T --user postgres $CURRENT_SLAVE pg_ctl promote -D /var/lib/postgresql/data

# -----------------------------
# Paso 3: Limpiar datos del antiguo maestro (para futuro failback)
# -----------------------------
echo "3. Limpiando data directory del antiguo maestro ($CURRENT_MASTER)..."
VOLUME_NAME="bases2_${CURRENT_MASTER#db-}_data"
docker run --rm -v $VOLUME_NAME:/var/lib/postgresql/data alpine sh -c "rm -rf /var/lib/postgresql/data/*"

# -----------------------------
# Paso 4: Reiniciar el nuevo maestro
# -----------------------------
echo "4. Reiniciando $CURRENT_SLAVE..."
docker compose restart $CURRENT_SLAVE
sleep 5

echo "--- FAILOVER COMPLETADO ---"
echo "$CURRENT_SLAVE ahora es el maestro activo."
