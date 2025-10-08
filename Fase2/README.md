# DOCUMENTACIÓN

## Organización

```
bases2/
├── app/
│   ├── scripts/
│   │   ├── failback.sh
│   │   ├── api_control.sh
│   │   └── failover.sh
|   ├── backups/
│   │   └── utils/
│   │      └── backup_functions.sh
│   │   ├── check_redis.sh
│   │   ├── ver_backups.sh
│   │   ├── dia1.sh
│   │   ├── dia2.sh
│   │   ├── dia3.sh
│   │   ├── dia4.sh
│   │   ├── dia5.sh
│   │   └── dia6.sh
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

---
# NOTA: ESTOS COMANDOS SOLO DEBEN EJECUTARSE SI SE QUIERE BORRAR TODO Y CARGAR DESDE CERO TODO EL PROYECTO, NO RECOMENDABLE HACER

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

---

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

### NOTA: ASEGURARSE DE EJECUTAR ESTOS SCRITPS EN LA RUTA /bases2

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

## Ejecutar API

### NOTA: Asegurarse de estar dentro de app/scripts e iniciar la API

### Activar entorno virtual

```bash
source venv_api/bin/activate
```

### Poner en marcha la API

```bash
uvicorn api_control:app --host 0.0.0.0 --port 8088
```

### En una nueva terminal podemos ejecutar los siguientes comandos de la API

```bash
curl http://127.0.0.1:8088/                     -> Verificar comandos 
curl -X POST http://127.0.0.1:8088/failover     -> Ejecutar failover
curl -X POST http://127.0.0.1:8088/failback     -> Ejecutar failback
```

