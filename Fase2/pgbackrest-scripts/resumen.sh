#!/bin/bash
# ===============================================
# Script para mostrar resumen ejecutivo rápido
# ===============================================

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              RESUMEN EJECUTIVO DEL SISTEMA DE BACKUPS              ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Estado de contenedores
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 ESTADO DE CONTENEDORES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar contenedores PostgreSQL
MASTER_STATUS=$(docker ps --filter "name=postgres_master" --format "{{.Status}}" 2>/dev/null | head -n1)
SLAVE_STATUS=$(docker ps --filter "name=postgres_slave" --format "{{.Status}}" 2>/dev/null | head -n1)
PGBACKREST_STATUS=$(docker ps --filter "name=pgbackrest" --format "{{.Status}}" 2>/dev/null | head -n1)
REDIS_STATUS=$(docker ps --filter "name=redis" --format "{{.Status}}" 2>/dev/null | head -n1)

if [ -n "$MASTER_STATUS" ]; then
    echo "  ✅ postgres_master: $MASTER_STATUS"
else
    echo "  ❌ postgres_master: NO ESTÁ CORRIENDO"
fi

if [ -n "$SLAVE_STATUS" ]; then
    echo "  ✅ postgres_slave:  $SLAVE_STATUS"
else
    echo "  ❌ postgres_slave:  NO ESTÁ CORRIENDO"
fi

if [ -n "$PGBACKREST_STATUS" ]; then
    echo "  ✅ pgbackrest:      $PGBACKREST_STATUS"
else
    echo "  ❌ pgbackrest:      NO ESTÁ CORRIENDO"
fi

if [ -n "$REDIS_STATUS" ]; then
    echo "  ✅ redis:           $REDIS_STATUS"
else
    echo "  ❌ redis:           NO ESTÁ CORRIENDO"
fi

echo ""

# Detectar maestro actual
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 MAESTRO ACTUAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CONTAINERS=($(docker ps --format "{{.Names}}" | grep -E 'postgres_(master|slave)'))
CURRENT_MASTER=""

for container in "${CONTAINERS[@]}"; do
    IS_RECOVERY=$(docker exec "$container" psql -U root -d postgres -tAc "SELECT pg_is_in_recovery();" 2>/dev/null || echo "t")
    if [[ "$IS_RECOVERY" =~ ^f ]]; then
        CURRENT_MASTER="$container"
        echo "  🟢 Maestro activo: $CURRENT_MASTER"
        break
    fi
done

if [ -z "$CURRENT_MASTER" ]; then
    echo "  ❌ No se pudo detectar el maestro actual"
fi

echo ""

# Estado de replicación
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 ESTADO DE REPLICACIÓN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$CURRENT_MASTER" ]; then
    REPLICAS=$(docker exec "$CURRENT_MASTER" psql -U root -d postgres -tAc "SELECT count(*) FROM pg_stat_replication;" 2>/dev/null || echo "0")
    
    if [ "$REPLICAS" -gt 0 ]; then
        echo "  ✅ Réplicas conectadas: $REPLICAS"
        
        # Estado detallado
        docker exec "$CURRENT_MASTER" psql -U root -d postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;" 2>/dev/null | grep -v "row" | head -n -1
    else
        echo "  ⚠️  No hay réplicas conectadas"
    fi
else
    echo "  ⚠️  No se puede verificar (maestro no detectado)"
fi

echo ""

# Información de backups
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 BACKUPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Contar backups en pgBackRest
if [ -n "$PGBACKREST_STATUS" ]; then
    BACKUP_INFO=$(docker exec pgbackrest pgbackrest --stanza=main info --output=text 2>/dev/null)
    
    if [ -n "$BACKUP_INFO" ]; then
        FULL_COUNT=$(echo "$BACKUP_INFO" | grep -c "full backup:" || echo "0")
        INCR_COUNT=$(echo "$BACKUP_INFO" | grep -c "incr backup:" || echo "0")
        DIFF_COUNT=$(echo "$BACKUP_INFO" | grep -c "diff backup:" || echo "0")
        TOTAL_BACKUPS=$((FULL_COUNT + INCR_COUNT + DIFF_COUNT))
        
        echo "  📦 Total de backups:     $TOTAL_BACKUPS"
        echo "     • Completos:          $FULL_COUNT"
        echo "     • Incrementales:      $INCR_COUNT"
        echo "     • Diferenciales:      $DIFF_COUNT"
        
        # Espacio usado
        TOTAL_SIZE=$(docker exec pgbackrest du -sh /var/lib/pgbackrest 2>/dev/null | awk '{print $1}')
        echo "  💿 Espacio usado:        $TOTAL_SIZE"
        
        # Último backup
        LAST_BACKUP=$(echo "$BACKUP_INFO" | grep "timestamp start/stop:" | tail -n1 | awk -F': ' '{print $2}' | awk -F' / ' '{print $1}')
        if [ -n "$LAST_BACKUP" ]; then
            echo "  🕐 Último backup:        $LAST_BACKUP"
        fi
    else
        echo "  ⚠️  No hay backups disponibles"
    fi
else
    echo "  ❌ Contenedor pgbackrest no está corriendo"
fi

echo ""

# Registros en Redis
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 REGISTROS EN REDIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$REDIS_STATUS" ]; then
    REDIS_BACKUPS=$(docker run --rm --network host redis:7-alpine \
        redis-cli -h 127.0.0.1 -p 6379 \
        KEYS "backup:*" 2>/dev/null | wc -l)
    
    if [ "$REDIS_BACKUPS" -gt 0 ]; then
        echo "  ✅ Backups registrados:  $REDIS_BACKUPS"
        
        # Último registro
        LAST_KEY=$(docker run --rm --network host redis:7-alpine \
            redis-cli -h 127.0.0.1 -p 6379 \
            KEYS "backup:*" 2>/dev/null | sort | tail -n1)
        
        if [ -n "$LAST_KEY" ]; then
            LAST_DATA=$(docker run --rm --network host redis:7-alpine \
                redis-cli -h 127.0.0.1 -p 6379 \
                HGETALL "$LAST_KEY" 2>/dev/null)
            
            LAST_FECHA=$(echo "$LAST_DATA" | grep -A1 "^fecha$" | tail -n1)
            LAST_HORA=$(echo "$LAST_DATA" | grep -A1 "^hora$" | tail -n1)
            LAST_TIPO=$(echo "$LAST_DATA" | grep -A1 "^tipo_backup$" | tail -n1)
            
            echo "  🕐 Último registro:      $LAST_FECHA $LAST_HORA ($LAST_TIPO)"
        fi
    else
        echo "  ⚠️  No hay registros en Redis"
    fi
else
    echo "  ❌ Redis no está corriendo"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 COMANDOS ÚTILES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📊 Ver información completa:"
echo "     bash pgbackrest-scripts/info_backups.sh"
echo ""
echo "  💾 Ver peso de backups:"
echo "     bash pgbackrest-scripts/peso_backups.sh"
echo ""
echo "  🗑️  Limpiar backups antiguos:"
echo "     bash pgbackrest-scripts/limpiar_backups.sh"
echo ""
echo "  📦 Hacer nuevo backup:"
echo "     bash pgbackrest-scripts/dia1.sh     # Completo"
echo "     bash pgbackrest-scripts/dia2.sh     # Incremental"
echo ""
echo "  🔄 Operaciones de HA:"
echo "     bash app/scripts/failover.sh        # Promover esclavo"
echo "     bash app/scripts/failback.sh        # Restaurar maestro"
echo ""
echo "╚════════════════════════════════════════════════════════════════════╝"
