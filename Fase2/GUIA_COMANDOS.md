# 📋 Guía Rápida de Comandos - Gestión de Backups

## 🎯 Comandos Esenciales

### Ver Información de Backups

```bash
# Información completa (Redis + pgBackRest + tamaños)
bash pgbackrest-scripts/info_backups.sh

# Solo metadatos de Redis (detallado)
bash pgbackrest-scripts/ver_backups.sh

# Solo metadatos de Redis (formato tabla)
bash pgbackrest-scripts/listar_backups.sh

# Ver peso/tamaño de backups
bash pgbackrest-scripts/peso_backups.sh
```

### Gestión de Backups

```bash
# Limpiar backups antiguos (menú interactivo)
bash pgbackrest-scripts/limpiar_backups.sh

# Verificar que Redis está funcionando
bash pgbackrest-scripts/check_redis.sh

# Crear/actualizar stanza de pgBackRest
bash pgbackrest-scripts/stanza_create.sh
```

### Ejecutar Backups

```bash
# Día 1: Backup COMPLETO
bash pgbackrest-scripts/dia1.sh

# Día 2: Backup INCREMENTAL
bash pgbackrest-scripts/dia2.sh

# Día 3: INCREMENTAL + DIFERENCIAL
bash pgbackrest-scripts/dia3.sh

# Día 4: Backup INCREMENTAL
bash pgbackrest-scripts/dia4.sh

# Día 5: INCREMENTAL + DIFERENCIAL
bash pgbackrest-scripts/dia5.sh

# Día 6: DIFERENCIAL + COMPLETO (nuevo ciclo)
bash pgbackrest-scripts/dia6.sh
```

## 🔍 Información Detallada

### Ver Tamaño de Backups

El comando `peso_backups.sh` muestra:
- 💿 Espacio total usado por todos los backups
- 📦 Desglose por directorio
- 📊 Lista de backups con sus tamaños individuales

**Ejemplo de salida:**
```
📊 INFORMACIÓN DEL REPOSITORIO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 Listado de backups con tamaño:

stanza: main
    status: ok
    cipher: none

    db (current)
        wal archive min/max (16): 000000010000000000000001/000000010000000000000010

        full backup: 20251009-040719F
            timestamp start/stop: 2025-10-09 04:07:19 / 2025-10-09 04:08:35
            wal start/stop: 000000010000000000000005 / 000000010000000000000005
            database size: 24.1GB, database backup size: 24.1GB
            repo1: backup set size: 16.8GB, backup size: 16.8GB

        incr backup: 20251009-040719F_20251009-041700I
            timestamp start/stop: 2025-10-09 04:17:00 / 2025-10-09 04:17:05
            wal start/stop: 000000010000000000000008 / 000000010000000000000008
            database size: 24.1GB, database backup size: 45.2MB
            repo1: backup set size: 16.8GB, backup size: 28.5MB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 ESPACIO EN DISCO DEL REPOSITORIO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💾 Espacio total usado: 16.9G
```

### Limpiar Backups

El comando `limpiar_backups.sh` es **interactivo** y ofrece 5 opciones:

#### Opción 1: Eliminar backups antiguos (mantener últimos N)

```bash
bash pgbackrest-scripts/limpiar_backups.sh
# Seleccionar opción 1
# Especificar cuántos backups completos mantener (ej: 3)
```

Esto:
- ✅ Mantiene los últimos N backups **completos**
- ✅ Mantiene todos los incrementales/diferenciales asociados
- ✅ Elimina backups completos más antiguos y sus dependencias

#### Opción 2: Limpiar según retención configurada

```bash
bash pgbackrest-scripts/limpiar_backups.sh
# Seleccionar opción 2
```

Esto:
- ✅ Aplica la retención por defecto (2 backups completos)
- ✅ Limpia registros huérfanos de Redis
- ✅ Sincroniza Redis con pgBackRest

#### Opción 3: Eliminar TODOS los backups (⚠️ PELIGROSO)

```bash
bash pgbackrest-scripts/limpiar_backups.sh
# Seleccionar opción 3
# Confirmar escribiendo "SI"
```

Esto:
- 🗑️ Elimina todos los backups de pgBackRest
- 🗑️ Elimina todos los registros de Redis
- 🔄 Recrea la stanza limpia
- ⚠️ **NO HAY FORMA DE RECUPERAR LOS DATOS**

#### Opción 4: Ver backups antes de eliminar

```bash
bash pgbackrest-scripts/limpiar_backups.sh
# Seleccionar opción 4
```

Muestra:
- 📋 Lista de backups en pgBackRest
- 📋 Lista de registros en Redis
- 💡 Te ayuda a decidir qué eliminar

#### Opción 5: Salir

Sale del programa sin hacer cambios.

## 🎯 Flujo de Trabajo Recomendado

### Revisión Periódica

```bash
# 1. Ver información completa de backups
bash pgbackrest-scripts/info_backups.sh

# 2. Ver cuánto espacio están usando
bash pgbackrest-scripts/peso_backups.sh

# 3. Si hay demasiados backups, limpiar
bash pgbackrest-scripts/limpiar_backups.sh
# Elegir opción 1 o 2
```

### Antes de un Mantenimiento

```bash
# 1. Ver estado actual
bash pgbackrest-scripts/info_backups.sh

# 2. Hacer backup completo
bash pgbackrest-scripts/dia1.sh

# 3. Verificar que se creó correctamente
bash pgbackrest-scripts/info_backups.sh

# 4. Proceder con mantenimiento/cambios
```

### Después de Failover/Failback

```bash
# 1. Ejecutar failover
bash app/scripts/failover.sh

# 2. Hacer backup con nuevo maestro
bash pgbackrest-scripts/dia2.sh

# 3. Verificar que detectó el maestro correcto
bash pgbackrest-scripts/ver_backups.sh
# Debería mostrar el nuevo contenedor maestro

# 4. Ejecutar failback
bash app/scripts/failback.sh

# 5. Hacer otro backup
bash pgbackrest-scripts/dia4.sh

# 6. Verificar que volvió al maestro original
bash pgbackrest-scripts/ver_backups.sh
```

## 📊 Entendiendo los Tamaños

### Backup Completo (Full)
- **Tamaño**: 100% de la base de datos
- **Ejemplo**: 24GB de DB → ~16-18GB comprimido (con lz4)
- **Tiempo**: 8-12 minutos (con optimizaciones)

### Backup Incremental (Incr)
- **Tamaño**: Solo cambios desde último backup (cualquier tipo)
- **Ejemplo**: ~30-100MB típicamente
- **Tiempo**: 10-30 segundos

### Backup Diferencial (Diff)
- **Tamaño**: Solo cambios desde último backup completo
- **Ejemplo**: ~100-500MB típicamente
- **Tiempo**: 1-3 minutos

## 💡 Tips y Mejores Prácticas

### Control de Espacio

```bash
# Ver espacio total usado
bash pgbackrest-scripts/peso_backups.sh

# Si se está quedando sin espacio:
# Opción 1: Reducir retención a 1 backup completo
bash pgbackrest-scripts/limpiar_backups.sh
# Opción 1 → mantener: 1

# Opción 2: Eliminar todo y empezar de cero
bash pgbackrest-scripts/limpiar_backups.sh
# Opción 3 → confirmar: SI
bash pgbackrest-scripts/dia1.sh  # Nuevo backup completo
```

### Optimización de Velocidad vs Espacio

**Actual (Balanceado):**
- Compresión: lz4 nivel 1
- Procesos: 8
- Resultado: 8-12 min, ~16-18GB

**Más Rápido (Sin Compresión):**
```bash
# Editar backup_functions.sh
--compress-type=none
# Resultado: 5-8 min, ~24GB
```

**Más Comprimido (Más Lento):**
```bash
# Editar backup_functions.sh
--compress-type=gzip
--compress-level=6
# Resultado: 25-35 min, ~6-8GB
```

### Sincronización Redis-pgBackRest

Si sospechas que Redis tiene registros viejos que ya no existen en pgBackRest:

```bash
bash pgbackrest-scripts/limpiar_backups.sh
# Opción 2 (limpia registros huérfanos automáticamente)
```

## 🆘 Troubleshooting

### "No hay backups registrados en Redis"

```bash
# Los backups existen en pgBackRest pero no en Redis
# Solución: Los backups nuevos se registrarán automáticamente
bash pgbackrest-scripts/dia1.sh
```

### "Espacio insuficiente"

```bash
# Ver qué está usando espacio
bash pgbackrest-scripts/peso_backups.sh

# Eliminar backups antiguos
bash pgbackrest-scripts/limpiar_backups.sh
# Opción 1 → mantener solo 1 backup completo
```

### "Error al eliminar backups"

```bash
# Verificar que pgBackRest está corriendo
docker ps | grep pgbackrest

# Si no está, reiniciar
docker compose up -d pgbackrest

# Intentar de nuevo
bash pgbackrest-scripts/limpiar_backups.sh
```

---

**Última actualización:** Octubre 2025  
**Proyecto:** Sistemas de Bases de Datos 2 - Fase 2 - Grupo 10
