#!/bin/bash
set -e
echo "--- INICIANDO FAILOVER ---"

# Paso 1: Detener el maestro
echo "1. Deteniendo db-master..."
docker compose stop db-master || true

# Paso 2: Promover el esclavo a maestro
echo "2. Promoviendo db-slave a maestro..."
docker compose exec -T --user postgres db-slave pg_ctl promote -D /var/lib/postgresql/data

# Paso 3: Limpiar datos obsoletos del antiguo master
echo "3. Limpiando datos del db-master (para futuro failback)..."
docker run --rm -v bases2_master_data:/var/lib/postgresql/data alpine rm -rf /var/lib/postgresql/data/*

# Paso 4: Reiniciar db-slave como nuevo maestro
echo "4. Reiniciando db-slave..."
docker compose restart db-slave
sleep 10

echo "--- FAILOVER COMPLETADO ---"
echo "db-slave ahora es el maestro activo."