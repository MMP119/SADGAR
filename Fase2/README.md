# COMANDOS A UTILIZAR

1.  **Limpieza e Inicio:**
    ```bash
    docker compose down -v
    docker compose up -d
    ```
2.  **Restauración:** 
    ```bash
    gunzip < mi_backup_completo.sql.gz | docker compose exec -T -e PGPASSWORD=Bases2_G10 db-master psql -U root -d IMDb
    ```
3.  **Failover:**
    ```bash
    docker stop postgres_master
    docker compose exec --user postgres db-slave pg_ctl promote -D /var/lib/postgresql/data
    docker restart postgres_slave
    sleep 15
    nano docker-compose.yml
    docker compose up -d --force-recreate db-master
    ```
4.  **Failback:**
    ```bash
    docker start postgres_master
    sleep 15
    docker compose exec -T --user postgres db-master pg_ctl stop -D /var/lib/postgresql/data -m fast
    docker start postgres_master
    sleep 15
    docker compose exec -T db-master find /var/lib/postgresql/data -mindepth 1 -delete
    docker compose exec -T --user postgres db-master pg_basebackup -h postgres_slave -p 5432 -D /var/lib/postgresql/data -U replicator -vP -w -R
    docker restart db-master
    ```
5.  **Verificación Final:**
    ```bash
    docker compose logs -f db-master
    ```
    `started streaming WAL from primary`.
-----
