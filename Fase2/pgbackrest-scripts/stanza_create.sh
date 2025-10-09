#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/backup_functions.sh"

echo "=========================================="
echo "  CONFIGURACIÓN DE pgBackRest"
echo "=========================================="
echo ""

# Crear o actualizar stanza
create_or_update_stanza

echo ""
echo "=========================================="
echo "  ✓ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "Puedes verificar con:"
echo "  docker exec pgbackrest pgbackrest --stanza=main info"
