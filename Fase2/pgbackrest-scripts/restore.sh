#!/bin/bash
# ===============================================
# Script para restaurar desde un backup de pgBackRest
# ===============================================
set -e

echo "========================================="
echo "  RESTAURACIÓN DE BACKUP - pgBackRest"
echo "========================================="
echo ""

# Función para mostrar uso
usage() {
  echo "Uso: $0 [opciones]"
  echo ""
  echo "Opciones:"
  echo "  --set <backup-set>    Especificar el set de backup a restaurar"
  echo "  --latest              Restaurar el backup más reciente (por defecto)"
  echo "  --type <tipo>         Tipo de restauración: default, immediate, time"
  echo "  --target <target>     Target específico para restauración point-in-time"
  echo "  --help                Mostrar esta ayuda"
  echo ""
  echo "Ejemplos:"
  echo "  $0 --latest"
  echo "  $0 --set 20251008-120000F"
  echo "  $0 --type time --target '2025-10-08 12:00:00'"
  exit 1
}

# Valores por defecto
RESTORE_TYPE="default"
BACKUP_SET="latest"
TARGET=""

# Procesar argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --set)
      BACKUP_SET="$2"
      shift 2
      ;;
    --latest)
      BACKUP_SET="latest"
      shift
      ;;
    --type)
      RESTORE_TYPE="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "Opción desconocida: $1"
      usage
      ;;
  esac
done

echo "Configuración de restauración:"
echo "  Backup Set: $BACKUP_SET"
echo "  Tipo: $RESTORE_TYPE"
[ -n "$TARGET" ] && echo "  Target: $TARGET"
echo ""

# Confirmar
read -p "¿Deseas continuar con la restauración? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  echo "Restauración cancelada."
  exit 0
fi

echo ""
echo "PASO 1: Detener PostgreSQL Master..."
docker compose stop db-master

echo "PASO 2: Limpiar directorio de datos..."
docker run --rm -v postgres_master_data:/data alpine sh -c "rm -rf /data/*"

echo "PASO 3: Ejecutar restauración con pgBackRest..."

if [ "$BACKUP_SET" = "latest" ]; then
  docker exec pgbackrest pgbackrest --stanza=main --delta restore
else
  docker exec pgbackrest pgbackrest --stanza=main --set="$BACKUP_SET" --delta restore
fi

echo "PASO 4: Reiniciar PostgreSQL Master..."
docker compose start db-master

echo ""
echo "========================================="
echo "  ✓ RESTAURACIÓN COMPLETADA"
echo "========================================="
echo ""
echo "Verifica el estado del servidor:"
echo "  docker logs postgres_master"
echo "  docker exec -it postgres_master psql -U root -d IMDb -c 'SELECT version();'"
