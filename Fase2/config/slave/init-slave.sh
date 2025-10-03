#!/bin/bash
set -e
rm -rf /var/lib/postgresql/data/*
echo "Esperando que el maestro esté listo..."
until pg_isready -h db-master -p 5432 -U replicator; do sleep 2; done
echo "Haciendo copia base desde el maestro..."
pg_basebackup -h db-master -p 5432 -D /var/lib/postgresql/data -U replicator -vP -w --slot=replication_slot -R
echo "Configuración de esclavo completada."
