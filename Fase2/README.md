# DOCUMENTACIÓN FASE 2

## Descripción General

Sistema de alta disponibilidad con PostgreSQL en modo maestro-esclavo, utilizando replicación streaming y backups automáticos con pgBackRest. El sistema incluye detección dinámica del maestro actual, permitiendo que los backups funcionen correctamente después de operaciones de failover/failback.

## Características Principales

- ✅ Replicación PostgreSQL maestro-esclavo con streaming replication
- ✅ Sistema de backups dinámico con pgBackRest (completos, incrementales y diferenciales)
- ✅ Detección automática del contenedor maestro actual
- ✅ Soporte para failover/failback sin reconfiguración manual de backups
- ✅ Almacenamiento de metadatos de backups en Redis
- ✅ Ciclo automatizado de 6 días de backups

## Organización del Proyecto

```
Fase2/
├── app/
│   ├── scripts/
│   │   ├── failback.sh              # Script para failback manual
│   │   ├── failover.sh              # Script para failover manual
│   │   └── api_control.py           # API REST para control remoto
├── pgbackrest-scripts/              # Scripts de backup (NUEVA UBICACIÓN)
│   ├── backup_functions.sh          # Librería de funciones dinámicas
│   ├── check_redis.sh               # Verificación de conexión Redis
│   ├── stanza_create.sh             # Creación/actualización de stanza
│   ├── ver_backups.sh               # Listado detallado de backups
│   ├── listar_backups.sh            # Listado en formato tabla
│   ├── dia1.sh                      # Día 1: Backup COMPLETO
│   ├── dia2.sh                      # Día 2: Backup INCREMENTAL
│   ├── dia3.sh                      # Día 3: INCREMENTAL + DIFERENCIAL
│   ├── dia4.sh                      # Día 4: Backup INCREMENTAL
│   ├── dia5.sh                      # Día 5: INCREMENTAL + DIFERENCIAL
│   └── dia6.sh                      # Día 6: DIFERENCIAL + COMPLETO (nuevo ciclo)
├── config/
│   ├── master/                      # Configuración PostgreSQL maestro
│   │   ├── init-master.sh
│   │   ├── pg_hba.conf
│   │   └── postgresql.conf
│   └── slave/                       # Configuración PostgreSQL esclavo
│       ├── init-slave.sh
│       ├── pg_hba.conf
│       └── postgresql.conf
├── backups/                         # Directorio de almacenamiento de backups
│   ├── completo/
│   ├── incremental/
│   └── diferencial/
├── docker-compose.yml               # Orquestación de contenedores
├── redis-compose.yml                # Redis standalone (opcional)
├── BaseIMDb.sql                     # Schema de base de datos
├── ProcedimientosAlmacenados.sql    # Stored procedures
└── README.md                        # Esta documentación
```
---

## Comandos de Uso

### 🚀 Inicio del Sistema

#### Flujo Completo desde Cero

> **⚠️ ADVERTENCIA:** Los siguientes comandos borran todos los datos y contenedores existentes. Solo ejecutar si se desea reiniciar completamente el proyecto.

**1. Limpieza Total y Arranque de Contenedores:**

```bash
docker compose down -v
docker compose up -d --build
```

Esto inicia los siguientes servicios:
- `postgres_master` - PostgreSQL maestro (puerto 5432)
- `postgres_slave` - PostgreSQL esclavo (puerto 5433)
- `pgbackrest` - Contenedor de backups
- `redis` - Almacenamiento de metadatos

**2. Carga de Datos (Solo primera vez):**

Se tiene un backup comprimido para restaurar:

```bash
gunzip < mi_backup_completo.sql.gz | docker compose exec -T -e PGPASSWORD=Bases2_G10 db-master psql -U root -d IMDb
```


**3. Crear Stanza de pgBackRest (Obligatorio antes del primer backup):**

```bash
bash pgbackrest-scripts/stanza_create.sh
```

Salida esperada:
```
🔍 Detectando contenedor maestro...
✓ Maestro detectado: postgres_master
✓ Stanza 'main' creada/actualizada correctamente
```

---

### 📦 Sistema de Backups

> **📍 NOTA:** Todos los comandos de backup deben ejecutarse desde el directorio raíz del proyecto Fase2.

#### Verificar Disponibilidad de Redis

Antes de ejecutar cualquier backup, verificar que Redis está funcionando:

```bash
bash pgbackrest-scripts/check_redis.sh
```

Salida esperada:
```
Verificando conexión con Redis en 127.0.0.1:6379...
✓ Redis está disponible y respondiendo correctamente
```

#### Ciclo de Backups de 6 Días

El sistema implementa un ciclo automático de 6 días con diferentes tipos de backup:

| Día | Tipo de Backup | Comando | Descripción |
|-----|----------------|---------|-------------|
| 1 | Completo (Full) | `bash pgbackrest-scripts/dia1.sh` | Backup completo de toda la base de datos |
| 2 | Incremental | `bash pgbackrest-scripts/dia2.sh` | Solo cambios desde último backup |
| 3 | Incremental + Diferencial | `bash pgbackrest-scripts/dia3.sh` | Ambos tipos de backup |
| 4 | Incremental | `bash pgbackrest-scripts/dia4.sh` | Solo cambios desde último backup |
| 5 | Incremental + Diferencial | `bash pgbackrest-scripts/dia5.sh` | Ambos tipos de backup |
| 6 | Diferencial + Completo | `bash pgbackrest-scripts/dia6.sh` | Cierra ciclo e inicia uno nuevo |

**Ejemplo de ejecución:**

```bash
# Día 1 - Backup completo inicial
bash pgbackrest-scripts/dia1.sh

# Día 2 - Backup incremental
bash pgbackrest-scripts/dia2.sh

# Día 3 - Backup incremental + diferencial
bash pgbackrest-scripts/dia3.sh

# ... y así sucesivamente
```

#### Ver Backups Registrados

**Listado detallado con toda la información:**

```bash
bash pgbackrest-scripts/ver_backups.sh
```

Salida ejemplo:
```
=== BACKUPS REGISTRADOS EN REDIS ===

Backup: backup:2025-10-09_04-07-19
  📅 Fecha: 2025-10-09
  🕐 Hora: 04:07:19
  📦 Tipo: completo
  📂 Almacenamiento: /var/lib/pgbackrest/backup/main/20251009-040719F
  🖥️  Maestro: postgres_master
  🔧 Método: pgBackRest
  📊 Stanza: main
```

**Listado en formato tabla:**

```bash
bash pgbackrest-scripts/listar_backups.sh
```

Salida ejemplo:
```
╔════════════════════════════════════════════════════════════════════╗
║           BACKUPS REGISTRADOS EN REDIS                             ║
╠════════════════════════════════════════════════════════════════════╣
║ Fecha       │ Hora     │ Tipo        │ Maestro                     ║
╠════════════════════════════════════════════════════════════════════╣
║ 2025-10-09  │ 04:07:19 │ completo    │ postgres_master            ║
╚════════════════════════════════════════════════════════════════════╝
```

#### Ver Información Completa (Redis + pgBackRest con tamaños)

Para ver información consolidada de ambos sistemas:

```bash
bash pgbackrest-scripts/info_backups.sh
```

Muestra:
- 📊 Información de pgBackRest con tamaños de cada backup
- 💾 Espacio total usado en disco
- 📦 Cantidad de backups por tipo (completos, incrementales, diferenciales)
- 📋 Metadatos almacenados en Redis

#### Ver Peso/Tamaño de los Backups

Para ver el espacio en disco usado por los backups:

```bash
bash pgbackrest-scripts/peso_backups.sh
```

Muestra:
- 💿 Tamaño total del repositorio de backups
- 📦 Desglose detallado por directorio
- 📊 Información de cada backup individual con su tamaño

#### Limpiar/Eliminar Backups Antiguos

Para gestionar y eliminar backups que ya no necesitas:

```bash
bash pgbackrest-scripts/limpiar_backups.sh
```

Este script interactivo ofrece:
1. **Eliminar backups antiguos**: Mantiene solo los últimos N backups completos
2. **Limpiar según retención**: Aplica la retención configurada (default: 2 completos)
3. **Eliminar todos los backups**: Borra todo y reinicia (⚠️ PELIGROSO)
4. **Ver backups actuales**: Lista antes de decidir qué eliminar
5. **Limpiar registros huérfanos**: Elimina metadatos de Redis sin backup correspondiente

**Ejemplo de uso:**

```bash
# Ejecutar el script
bash pgbackrest-scripts/limpiar_backups.sh

# Seleccionar opción 1: Mantener solo últimos 3 backups completos
Opción: 1
¿Cuántos backups COMPLETOS quieres mantener? (default: 2): 3

# O ejecutar limpieza automática según retención actual
Opción: 2
```

---

### 🔄 Operaciones de Failover y Failback

#### Failover (Promover Esclavo a Maestro)

**Usando scripts directamente:**

```bash
bash app/scripts/failover.sh
```

Este script:
1. Detiene el contenedor maestro actual
2. Promueve el esclavo a maestro
3. Reconfigura la replicación
4. Verifica el estado final

**Usando la API REST:**

```bash
curl -X POST http://127.0.0.1:8088/failover
```

#### Failback (Restaurar Maestro Original)

**Usando scripts directamente:**

```bash
bash app/scripts/failback.sh
```

Este script:
1. Sincroniza el maestro original con el esclavo actual
2. Promueve el maestro original nuevamente
3. Reconfigura el esclavo
4. Verifica el estado final

**Usando la API REST:**

```bash
curl -X POST http://127.0.0.1:8088/failback
```

#### 🎯 Prueba Completa de Failover/Failback con Backups

Para validar que el sistema dinámico funciona correctamente:

```bash
# 1. Backup inicial con maestro original
bash pgbackrest-scripts/dia1.sh

# 2. Ejecutar failover
bash app/scripts/failover.sh

# 3. Backup con el nuevo maestro (antes era esclavo)
bash pgbackrest-scripts/dia2.sh

# 4. Ejecutar failback
bash app/scripts/failback.sh

# 5. Backup con el maestro original restaurado
bash pgbackrest-scripts/dia4.sh

# 6. Verificar que todos los backups se registraron
bash pgbackrest-scripts/ver_backups.sh
```

Si todo funciona correctamente, deberías ver 3 backups registrados con diferentes contenedores maestros.

-----

### 🌐 API REST para Control Remoto

La API REST proporciona endpoints para ejecutar failover y failback de forma remota.

#### Iniciar la API

**1. Navegar al directorio de scripts:**

```bash
cd app/scripts
```

**2. Activar entorno virtual (si está configurado):**

```bash
source venv_api/bin/activate
```

**3. Iniciar el servidor FastAPI:**

```bash
uvicorn api_control:app --host 0.0.0.0 --port 8088
```

La API estará disponible en `http://127.0.0.1:8088`

#### Endpoints Disponibles

**Listar comandos disponibles:**

```bash
curl http://127.0.0.1:8088/
```

Respuesta:
```json
{
  "message": "API de Control PostgreSQL HA",
  "endpoints": {
    "failover": "POST /failover",
    "failback": "POST /failback"
  }
}
```

**Ejecutar Failover:**

```bash
curl -X POST http://127.0.0.1:8088/failover
```

Respuesta exitosa:
```json
{
  "status": "success",
  "message": "Failover ejecutado correctamente"
}
```

**Ejecutar Failback:**

```bash
curl -X POST http://127.0.0.1:8088/failback
```

Respuesta exitosa:
```json
{
  "status": "success",
  "message": "Failback ejecutado correctamente"
}
```

---

## 🔧 Componentes Técnicos

### Detección Dinámica del Maestro

El sistema utiliza la función `pg_is_in_recovery()` de PostgreSQL para detectar automáticamente cuál contenedor es el maestro actual:

- **Maestro**: `pg_is_in_recovery() = false`
- **Esclavo**: `pg_is_in_recovery() = true`

Esta detección se ejecuta en **cada backup**, garantizando que siempre se respalda el contenedor correcto sin importar si hubo failover/failback.

### Configuración de pgBackRest

Los backups utilizan pgBackRest con las siguientes características:

- **Modo offline** (`--no-online --force`): Permite backups sin conexión activa a PostgreSQL
- **Procesamiento paralelo** (`--process-max=4`): 4 procesos simultáneos para mayor velocidad
- **Retención**: 2 backups completos se mantienen automáticamente
- **Tipos de backup**:
  - **Full**: Backup completo de toda la base de datos
  - **Incremental**: Solo archivos modificados desde el último backup (cualquier tipo)
  - **Diferencial**: Solo archivos modificados desde el último backup completo

### Almacenamiento de Metadatos en Redis

Cada backup registra la siguiente información en Redis:

```json
{
  "fecha": "2025-10-09",
  "hora": "04:07:19",
  "tipo_backup": "completo|incremental|diferencial",
  "direccion_almacenamiento": "/var/lib/pgbackrest/backup/main/...",
  "maestro_usado": "postgres_master|postgres_slave",
  "metodo": "pgBackRest",
  "stanza": "main"
}
```

Clave Redis: `backup:YYYY-MM-DD_HH-MM-SS`

---

## 📋 Troubleshooting

### Error: "no files have changed since the last backup"

Este error ocurre cuando pgBackRest detecta que no hay cambios entre backups consecutivos.

**Solución 1:** Esperar tiempo entre backups o hacer cambios en la base de datos.

**Solución 2:** Insertar datos de prueba antes del backup:

```bash
docker exec postgres_master psql -U root -d imdb -c "CREATE TABLE IF NOT EXISTS test_backup (id SERIAL, fecha TIMESTAMP DEFAULT NOW()); INSERT INTO test_backup VALUES (DEFAULT);"
```

### Error: "Redis está disponible y respondiendo correctamente"

Si Redis no está disponible, verificar que el contenedor está corriendo:

```bash
docker ps | grep redis
```

Si no está corriendo, reiniciar los contenedores:

```bash
docker compose up -d redis
```

### Error: "No se pudo detectar el maestro"

Verificar que al menos uno de los contenedores PostgreSQL esté corriendo y no en modo recovery:

```bash
docker exec postgres_master psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();"
docker exec postgres_slave psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();"
```

Uno debe retornar `f` (maestro) y el otro `t` (esclavo).

### Verificar Estado de Replicación

**En el maestro:**

```bash
docker exec postgres_master psql -U root -d postgres -c "SELECT * FROM pg_stat_replication;"
```

**En el esclavo:**

```bash
docker exec postgres_slave psql -U root -d postgres -c "SELECT * FROM pg_stat_wal_receiver;"
```

---

## 📚 Documentación Adicional

- **PRUEBAS_SISTEMA_DINAMICO.md**: Guía detallada de pruebas de failover/failback
- **RESUMEN_IMPLEMENTACION.md**: Arquitectura completa y decisiones de diseño
- **README_BACKUPS.md**: Documentación específica del sistema de backups

---

## 👥 Autores

Proyecto desarrollado para el curso de Sistemas de Bases de Datos 2 - Fase 2

**Grupo 10**

---

## 📝 Notas Importantes

1. **Los backups se ejecutan en modo offline**: Esto significa que los backups se realizan mientras PostgreSQL está corriendo, pero sin conexión activa. Son consistentes a nivel de archivos pero pueden no ser point-in-time perfect.

2. **Los scripts manejan errores gracefully**: Si un backup incremental/diferencial falla porque no hay cambios, el script continúa con el siguiente backup programado.

3. **Failover/Failback automático**: Después de cualquier operación de failover/failback, los backups automáticamente detectan el nuevo maestro sin necesidad de reconfiguración manual.

4. **Retención automática**: pgBackRest mantiene automáticamente solo los últimos 2 backups completos más sus incrementales/diferenciales asociados.