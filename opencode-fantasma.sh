#!/bin/bash
set -euo pipefail

# Solicitar elevación de privilegios al inicio (una sola vez)
if [ "$EUID" -ne 0 ]; then
    echo "==> Solicitando permisos sudo para aislar el entorno..."
    exec sudo bash "$0" "$@"
fi

# Obtener el usuario real que invocó sudo (no root)
REAL_USER="${SUDO_USER:-$USER}"
USER_ID=$(id -u "$REAL_USER")
GROUP_ID=$(id -g "$REAL_USER")

LOCAL_DIR="$(pwd)"
FANTASMA_DIR="/tmp/opencode_fantasma_${REAL_USER}_$(date +%s)"
NET_MODE="${1:-ipv4}"

echo "==> [Identidad Efímera] Generando entorno 100% aislado para $REAL_USER ($USER_ID:$GROUP_ID)..."

# 1. Crear la estructura fantasma directamente en RAM (/tmp)
mkdir -p "$FANTASMA_DIR/.config" \
         "$FANTASMA_DIR/.local/share" \
         "$FANTASMA_DIR/.cache" \
         "$FANTASMA_DIR/.opencode" \
         "$FANTASMA_DIR/tmp"

# 2. Asignar la propiedad al usuario real
chown -R "$USER_ID:$GROUP_ID" "$FANTASMA_DIR"

# 3. Limpieza profunda de cualquier caché/sesión anterior en la carpeta del proyecto
rm -rf "$LOCAL_DIR/.opencode" "$LOCAL_DIR/.opencode-agent"

# 4. Generación del Machine ID aleatorio de 32 caracteres hexadecimales
openssl rand -hex 16 > "$FANTASMA_DIR/machine-id"
chown "$USER_ID:$GROUP_ID" "$FANTASMA_DIR/machine-id"

# 5. Opciones de Red
NODE_NET_FLAGS="--no-warnings"
DOCKER_NET_ARGS="--network host"

case "$NET_MODE" in
  ipv4)
    NODE_NET_FLAGS="--dns-result-order=ipv4first --no-warnings"
    ;;
  ipv6)
    NODE_NET_FLAGS="--dns-result-order=verbatim --no-warnings"
    ;;
  bridge)
    DOCKER_NET_ARGS="--network bridge"
    ;;
esac

# 6. Función de autodestrucción al finalizar la sesión de OpenCode
cleanup() {
    echo -e "\n==> Destruyendo huellas y liberando memoria RAM en /tmp..."
    rm -rf "$FANTASMA_DIR"
    rm -rf "$LOCAL_DIR/.opencode" "$LOCAL_DIR/.opencode-agent"
}
trap cleanup EXIT

echo "==> Lanzando OpenCode..."
echo "=========================================================================="

# 7. Ejecutar Docker con tu usuario real
docker run -it --rm \
  --name "opencode_efimero_$(date +%s)" \
  --user "$USER_ID:$GROUP_ID" \
  $DOCKER_NET_ARGS \
  --hostname "arch-node-$RANDOM" \
  -e "HOME=/tmp/userhome" \
  -e "DBUS_SESSION_BUS_ADDRESS=/dev/null" \
  -e "OPENCODE_DISABLE_TELEMETRY=1" \
  -e "NODE_OPTIONS=$NODE_NET_FLAGS" \
  -v "$FANTASMA_DIR/machine-id:/etc/machine-id:ro" \
  -v "$FANTASMA_DIR/machine-id:/var/lib/dbus/machine-id:ro" \
  -v "$FANTASMA_DIR:/tmp/userhome" \
  -v "$LOCAL_DIR:/workspace" \
  -w /workspace \
  ghcr.io/anomalyco/opencode:latest