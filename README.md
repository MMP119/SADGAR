# Sistema de Alta Disponibilidad con Gestión Automatizada de Respaldos

Sistema distribuido de bases de datos PostgreSQL implementando replicación maestro-esclavo, gestión automatizada de respaldos, y pipeline de migración de datos

## Descripción General

Este es un proyecto académico que implementa un sistema de base de datos PostgreSQL de grado producción con alta disponibilidad. El proyecto se desarrolla en tres fases progresivas que cubren desde la carga inicial de datos hasta la implementación de replicación y migración a bases de datos NoSQL.

El sistema está diseñado para demostrar capacidades de administración de bases de datos a nivel empresarial, incluyendo tolerancia a fallos, recuperación ante desastres, y operaciones de mantenimiento sin tiempo de inactividad.

## SECCIÓN: KEY FEATURES (Características Principales)

### Alta Disponibilidad y Replicación

- Replicación streaming de PostgreSQL en arquitectura maestro-esclavo
- Detección automática del nodo maestro utilizando la función pg_is_in_recovery()
- Operaciones de failover y failback con cero tiempo de inactividad
- API REST para gestión remota del clúster


### Gestión de Respaldos

- Ciclo automatizado de backups de 6 días usando pgBackRest
- Múltiples tipos de respaldo: Completo (Full), Incremental y Diferencial
- Almacenamiento de metadatos en Redis para seguimiento de backups
- Políticas de retención y utilidades de limpieza automática
- Respaldos dinámicos que funcionan después de operaciones de failover


### Pipeline de Datos

- Proceso ETL para ingesta de datos desde archivos CSV
- Transformación y normalización de datos
- Scripts de migración de bases de datos relacionales a NoSQL
- Optimización de índices para mejorar el rendimiento de consultas


## SECCIÓN: ARCHITECTURE (Arquitectura del Sistema)

El sistema está organizado en una arquitectura de contenedores Docker que incluye:

Contenedor PostgreSQL Maestro (puerto 5432) - Servidor principal de base de datos que acepta operaciones de lectura y escritura. Configurado con replicación streaming activa.

Contenedor PostgreSQL Esclavo (puerto 5433) - Réplica en modo hot standby que recibe cambios del maestro mediante streaming replication. Puede ser promovido a maestro en caso de failover.

Contenedor pgBackRest - Servidor dedicado para ejecutar operaciones de backup. Detecta automáticamente cuál contenedor PostgreSQL es el maestro actual y ejecuta respaldos contra ese nodo.

Contenedor Redis - Almacena metadatos de cada backup realizado, incluyendo fecha, hora, tipo de backup, ubicación en disco, y cuál contenedor era el maestro al momento del respaldo.

API REST (FastAPI) - Expone endpoints HTTP para ejecutar operaciones de failover y failback de forma remota, facilitando la automatización y el monitoreo.

## SECCIÓN: PROJECT STRUCTURE (Estructura del Proyecto)

El repositorio está organizado en tres fases:

### Fase 1 - ETL y Carga de Datos

Contiene la carpeta app con scripts Python para el proceso ETL (etl.py, loader.py, indices_postgres.py). La carpeta data almacena los archivos CSV del dataset de IMDb. Los archivos BaseIMDb.sql y ProcedimientosAlmacenados.sql definen el esquema de la base de datos y los stored procedures respectivamente.

### Fase 2 - Alta Disponibilidad y Respaldos

Incluye la carpeta app/scripts con failover.sh, failback.sh y api_control.py para gestión del clúster. La carpeta config contiene configuraciones separadas para PostgreSQL maestro y esclavo (postgresql.conf, pg_hba.conf, init scripts). La carpeta pgbackrest-scripts contiene todos los scripts de automatización de backups (dia1.sh a dia6.sh para el ciclo de 6 días, ver_backups.sh, listar_backups.sh, limpiar_backups.sh, etc.). El archivo docker-compose.yml orquesta los 4 contenedores (postgres_master, postgres_slave, pgbackrest, redis).

### Fase 3 - Migración a NoSQL

Contiene la carpeta app con el Dockerfile y loader.py para migración de datos. La carpeta scripts tiene utilidades para MongoDB. La carpeta data almacena archivos de datos para la migración. El docker-compose.yml configura MongoDB. La carpeta Doc contiene la documentación específica de esta fase.

## SECCIÓN: TECHNOLOGIES (Tecnologías Utilizadas)

Base de Datos: PostgreSQL 15, MongoDB

Backup y Recuperación: pgBackRest

Almacenamiento de Metadatos: Redis

Contenedorización: Docker, Docker Compose

Lenguajes de Programación: Python 3.9+, Bash scripting

Framework Web: FastAPI (para API REST)

Bibliotecas ETL: Pandas, psycopg2

Sistema Operativo: Linux (dentro de contenedores)


## SECCIÓN: DETAILED USAGE (Uso Detallado)

### Ciclo de Backups de 6 Días

El sistema implementa un ciclo automático de respaldos que se repite cada 6 días:

Día 1 - Ejecutar backup completo
Comando: bash pgbackrest-scripts/dia1.sh
Descripción: Realiza un backup completo de toda la base de datos. Este es el punto de partida del ciclo.

Día 2 - Ejecutar backup incremental
Comando: bash pgbackrest-scripts/dia2.sh
Descripción: Respalda solo los archivos modificados desde el último backup de cualquier tipo.

Día 3 - Ejecutar backup incremental más diferencial
Comando: bash pgbackrest-scripts/dia3.sh
Descripción: Realiza primero un backup incremental y luego uno diferencial (cambios desde el último backup completo).

Día 4 - Ejecutar backup incremental
Comando: bash pgbackrest-scripts/dia4.sh
Descripción: Backup incremental de cambios recientes.

Día 5 - Ejecutar backup incremental más diferencial
Comando: bash pgbackrest-scripts/dia5.sh
Descripción: Combina backup incremental y diferencial.

Día 6 - Ejecutar backup diferencial más completo
Comando: bash pgbackrest-scripts/dia6.sh
Descripción: Cierra el ciclo actual con un diferencial y luego inicia un nuevo ciclo con un backup completo.

### Gestión de Backups

Ver backups con información detallada:
bash pgbackrest-scripts/ver_backups.sh
Muestra fecha, hora, tipo, ubicación en disco, y contenedor maestro usado para cada backup.

Ver backups en formato tabla:
bash pgbackrest-scripts/listar_backups.sh
Presenta la información en un formato tabular más compacto.

Ver tamaño de los backups en disco:
bash pgbackrest-scripts/peso_backups.sh
Muestra el espacio usado por el repositorio de backups y el tamaño de cada backup individual.

Limpiar backups antiguos:
bash pgbackrest-scripts/limpiar_backups.sh
Script interactivo que ofrece opciones para eliminar backups antiguos, aplicar políticas de retención, o limpiar registros huérfanos en Redis.

### Operaciones de Failover y Failback

Ejecutar Failover (promover esclavo a maestro):
Usando script directo: bash app/scripts/failover.sh
Usando API REST: curl -X POST http://127.0.0.1:8088/failover

El proceso de failover detiene el contenedor maestro actual, promueve el esclavo a maestro, reconfigura la replicación, y verifica el estado final del clúster.

Ejecutar Failback (restaurar maestro original):
Usando script directo: bash app/scripts/failback.sh
Usando API REST: curl -X POST http://127.0.0.1:8088/failback

El proceso de failback sincroniza el maestro original con el esclavo actual, promueve el maestro original nuevamente, reconfigura el esclavo, y verifica el estado final.

### API REST

Iniciar el servidor de la API:
Navegar al directorio: cd Fase2/app/scripts
Activar entorno virtual si existe: source venv_api/bin/activate
Iniciar servidor: uvicorn api_control:app --host 0.0.0.0 --port 8088

La API estará disponible en http://127.0.0.1:8088

Endpoints disponibles:
GET / - Listar comandos disponibles
POST /failover - Ejecutar operación de failover
POST /failback - Ejecutar operación de failback

## SECCIÓN: DATABASE SCHEMA (Esquema de Base de Datos)

El proyecto utiliza el dataset de IMDb con las siguientes entidades principales:

Tabla Movies/Titles: Almacena información de películas y series incluyendo título, año de lanzamiento, duración, y género.

Tabla Actors/Actresses: Contiene información de actores y actrices con su nombre y datos biográficos.

Tabla Directors: Almacena información de directores de cine.

Tabla Ratings: Contiene las calificaciones de cada título con puntuación promedio y número de votos.

Tabla Genres: Define los géneros cinematográficos disponibles.

Tablas de relación: Conectan películas con actores, directores y géneros mediante relaciones muchos-a-muchos.

El esquema completo está definido en el archivo BaseIMDb.sql ubicado en las carpetas de Fase1 y Fase2.

## SECCIÓN: TESTING (Pruebas del Sistema)

### Prueba Completa de Failover/Failback con Backups

Esta prueba valida que el sistema de detección dinámica del maestro funciona correctamente:

1. Realizar backup inicial con maestro original
bash pgbackrest-scripts/dia1.sh
2. Ejecutar operación de failover
bash app/scripts/failover.sh
3. Realizar backup con el nuevo maestro (el que antes era esclavo)
bash pgbackrest-scripts/dia2.sh
4. Ejecutar operación de failback para restaurar el maestro original
bash app/scripts/failback.sh
5. Realizar otro backup con el maestro original restaurado
bash pgbackrest-scripts/dia4.sh
6. Verificar que todos los backups se registraron correctamente
bash pgbackrest-scripts/ver_backups.sh

Resultado esperado: Deberías ver 3 backups registrados, cada uno indicando correctamente cuál contenedor era el maestro al momento del respaldo.

### Prueba de Carga de Datos (Fase 1)

Ejecutar el proceso ETL completo:
cd Fase1
python app/etl.py

Verificar que los datos se cargaron correctamente:
docker exec postgres_master psql -U root -d imdb -c "SELECT COUNT(asterisco) FROM movies;"

Ejecutar pruebas de índices:
python app/indices_postgres.py

## SECCIÓN: TROUBLESHOOTING (Solución de Problemas)

### Problema: Error "no files have changed since the last backup"

Causa: pgBackRest detecta que no hay cambios entre backups consecutivos.

Solución 1: Esperar tiempo entre backups o hacer modificaciones en la base de datos.

Solución 2: Insertar datos de prueba antes del backup:
docker exec postgres_master psql -U root -d imdb -c "CREATE TABLE IF NOT EXISTS test_backup (id SERIAL, fecha TIMESTAMP DEFAULT NOW()); INSERT INTO test_backup VALUES (DEFAULT);"

### Problema: Redis no está disponible

Verificar que el contenedor de Redis está corriendo:
docker ps | grep redis

Si no está corriendo, reiniciar el servicio:
docker compose up -d redis

Verificar conectividad:
bash pgbackrest-scripts/check_redis.sh

### Problema: No se puede detectar el maestro

Verificar que al menos un contenedor PostgreSQL esté en modo maestro (no recovery):
docker exec postgres_master psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();"
docker exec postgres_slave psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();"

Uno debe retornar 'f' (false, es maestro) y el otro 't' (true, es esclavo).

Si ambos están en recovery, promover uno manualmente:
docker exec postgres_master touch /tmp/promote_trigger

### Problema: Replicación no funciona

Verificar estado de replicación en el maestro:
docker exec postgres_master psql -U root -d postgres -c "SELECT asterisco FROM pg_stat_replication;"

Debería mostrar una fila con el esclavo conectado.

Verificar estado en el esclavo:
docker exec postgres_slave psql -U root -d postgres -c "SELECT asterisco FROM pg_stat_wal_receiver;"

Si no hay conexión, revisar los logs:
docker logs postgres_slave

### Problema: Los contenedores no inician

Verificar logs de Docker Compose:
docker compose logs

Verificar puertos en uso:
netstat -tulpn | grep 5432
netstat -tulpn | grep 5433

Si los puertos están ocupados, detener los servicios que los usan o cambiar los puertos en docker-compose.yml.

## SECCIÓN: DOCUMENTATION (Documentación Adicional)

El proyecto incluye documentación detallada en cada fase:

Fase 1:

- README.md en Fase1/: Documentación del proceso ETL
- README.md en Fase1/app/: Guía de uso de scripts Python

Fase 2:

- README.md: Documentación completa del sistema de alta disponibilidad
- GUIA_COMANDOS.md: Referencia rápida de todos los comandos
- ManualTecnico.md: Manual técnico detallado con arquitectura y configuraciones
- Manual de usuario.md: Guía para usuarios finales
- Proyecto_Fase2.pdf: Documentación académica completa

Fase 3:

- Carpeta Doc/: Documentación de migración a MongoDB
- DocumentaciónFase3.pdf: Documentación académica de la fase 3


## SECCIÓN: TECHNICAL DETAILS (Detalles Técnicos)

### Detección Dinámica del Maestro

El sistema utiliza la función pg_is_in_recovery() de PostgreSQL para identificar dinámicamente cuál contenedor es el maestro:

Cuando pg_is_in_recovery() retorna false: El contenedor es el maestro actual y acepta escrituras.
Cuando pg_is_in_recovery() retorna true: El contenedor es esclavo y está en modo recovery.

Esta detección se ejecuta automáticamente antes de cada backup, garantizando que siempre se respalda el contenedor correcto sin importar si hubo operaciones de failover o failback.

### Configuración de pgBackRest

Los backups utilizan pgBackRest con los siguientes parámetros:

Modo offline con flag --no-online --force: Permite backups sin conexión activa a PostgreSQL pero mientras el servidor está corriendo.

Procesamiento paralelo con --process-max=4: Utiliza 4 procesos simultáneos para acelerar las operaciones de backup y restore.

Retención automática: Mantiene los últimos 2 backups completos más todos sus incrementales y diferenciales asociados.

Tipos de backup:

- Full (Completo): Backup de todos los archivos de la base de datos
- Incremental: Solo archivos modificados desde el último backup de cualquier tipo
- Diferencial: Solo archivos modificados desde el último backup completo


### Almacenamiento de Metadatos en Redis

Cada backup registra un hash en Redis con la siguiente estructura:

Clave: backup:YYYY-MM-DD_HH-MM-SS

Campos del hash:

- fecha: Fecha del backup en formato YYYY-MM-DD
- hora: Hora del backup en formato HH:MM:SS
- tipo_backup: completo, incremental o diferencial
- direccion_almacenamiento: Ruta absoluta en disco del backup
- maestro_usado: Nombre del contenedor que era maestro (postgres_master o postgres_slave)
- metodo: Siempre "pgBackRest"
- stanza: Nombre de la stanza de pgBackRest (generalmente "main")

Esta información permite auditar backups, rastrear cambios de maestro, y facilitar operaciones de restore.

### Configuración de Replicación

PostgreSQL maestro configurado con:

- wal_level = replica
- max_wal_senders = 10
- wal_keep_size = 64MB
- hot_standby = on

PostgreSQL esclavo configurado con:

- hot_standby = on
- primary_conninfo apuntando al maestro
- restore_command para recuperar WAL files

La replicación es asíncrona por defecto pero puede configurarse como síncrona modificando synchronous_commit.

## SECCIÓN: BEST PRACTICES (Mejores Prácticas)

Realizar backup completo al menos una vez por semana para mantener un punto de restauración reciente.

Verificar periódicamente el estado de la replicación para detectar problemas tempranamente.

Probar operaciones de failover y restore en un ambiente de prueba antes de ejecutarlas en producción.

Monitorear el espacio en disco del repositorio de backups y ejecutar limpiezas periódicas.

Documentar todas las operaciones de failover/failback con fecha, hora y motivo.

Mantener al menos 2 backups completos en todo momento para mayor seguridad.

Validar la integridad de los backups ejecutando restores de prueba periódicamente.

## SECCIÓN: CONTRIBUTING (Contribuciones)

Este es un proyecto académico pero las sugerencias son bienvenidas. Para contribuir:

1. Hacer fork del repositorio
2. Crear una rama para tu feature: git checkout -b feature/NuevaCaracteristica
3. Hacer commit de tus cambios: git commit -m 'Agregar nueva característica'
4. Hacer push a la rama: git push origin feature/NuevaCaracteristica
5. Abrir un Pull Request

## SECCIÓN: LICENSE (Licencia)

Este proyecto está bajo la Licencia MIT. Ver el archivo LICENSE para más detalles.

***


