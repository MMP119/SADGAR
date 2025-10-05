# DOCUMENTACIÓN

## Organización

```
bases2/
├── app/
│   ├── scripts/
│   │   ├── failback.sh
│   │   └── failover.sh
├── config/
│   ├── master/
│   │   ├── init-master.sh
│   │   ├── pg_hba.conf
│   │   └── postgresql.conf
│   └── slave/
│       ├── init-slave.sh
│       ├── pg_hba.conf
│       └── postgresql.conf
├── docker-compose.yml
└── BaseIMDb.sql
└── ProcedimientosAlmacenados.sql
└── mi_backup_completo.sql.gz
```
---

## Comandos

### Flujo

Esta es la secuencia que se debe ejecutar desde un estado limpio.

**1. Limpieza Total y Arranque:**

```bash
docker compose down -v
docker compose up -d --build
```

**2. Carga de Datos:**
Restaura el backup original en el maestro..

```bash
gunzip < mi_backup_completo.sql.gz | docker compose exec -T -e PGPASSWORD=Bases2_G10 db-master psql -U root -d IMDb
```

**3. Ejecutar Failover:**

```bash
bash app/scripts/failover.sh
```

**4. Ejecutar Failback:**

```bash
bash app/scripts/failback.sh
```

-----

## Ejecutar Backups

### Checar si redis está funcionando

```bash
bash app/scripts/backups/check_redis.sh
```

### Ejecutar Script Backup día 1

```bash
bash app/scripts/backups/dia1.sh 
```

### Ejecución de Scripts Backup día específico (1-6)

```bash
bash app/scripts/backups/dia#.sh 
```

### Ver Backups en Redis:

```bash
bash app/scripts/backups/ver_backups.sh
```
---