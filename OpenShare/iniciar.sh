#!/bin/bash
set -euo pipefail

COMPOSE_DIR="/home/eynor/Documents/2_Proyect_Private/8_Opencode/OpenShare"
FANTASMA_DIR="/home/eynor/.opencode_fantasma_global"
LOCAL_DIR="$(pwd)"

echo "==> Limpiando rastros de sesión anteriores..."
sudo rm -rf "$FANTASMA_DIR" "$LOCAL_DIR/.opencode" "$LOCAL_DIR/.opencode-agent"

mkdir -p "$FANTASMA_DIR/.config" "$FANTASMA_DIR/.local/share" \
         "$FANTASMA_DIR/.cache" "$FANTASMA_DIR/.opencode"

# Generación del Machine ID dinámico
openssl rand -hex 16 > "$FANTASMA_DIR/machine-id"

echo "==> Verificando IP pública activa en ProtonVPN..."
curl -4 -s https://ifconfig.me || true
echo -e "\n"

echo "==> Desplegando entorno con Docker Compose..."
docker compose -f "$COMPOSE_DIR/compose.yaml" run --rm opencode