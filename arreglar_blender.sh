#!/usr/bin/env bash
# Arregla Blender en Arch/Omarchy: cierra procesos, borra el portable e instala el paquete oficial.
set -uo pipefail

PORTABLE="$HOME/Aplicacion/blender-4.2.0-linux-x64"
LOG="$HOME/blender-fix.log"
EJEC="$HOME/blender-ejecucion.log"

exec > >(tee -a "$LOG") 2>&1
echo "===== Arreglo de Blender: $(date) ====="

if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: ejecuta este script como tu usuario normal, NO con sudo."
    echo "Uso: bash \"$0\""
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: no se encontró pacman. Este script es para Arch/Omarchy."
    exit 1
fi

echo
echo "== 1) Cerrando Blender y procesos del portable =="
pkill -f "$PORTABLE" 2>/dev/null || true
pkill -x blender 2>/dev/null || true
sleep 2
pkill -9 -f "$PORTABLE" 2>/dev/null || true
pkill -9 -x blender 2>/dev/null || true
if pgrep -x blender >/dev/null 2>&1 || pgrep -f "$PORTABLE" >/dev/null 2>&1; then
    echo "Procesos que siguen activos:"
    pgrep -a -x blender || true
    pgrep -a -f "$PORTABLE" || true
else
    echo "Sin procesos Blender activos."
fi

echo
echo "== 2) Eliminando Blender portable =="
if [ -d "$PORTABLE" ]; then
    rm -rf -- "$PORTABLE"
    echo "Eliminado: $PORTABLE"
else
    echo "No existe esa carpeta: $PORTABLE"
    echo "Buscando otras copias portables en $HOME (solo informativo):"
    find "$HOME" -maxdepth 4 -type d -name 'blender-*-linux-x64' -print 2>/dev/null || true
fi

echo
echo "== 3) Respaldando la configuración vieja de Blender =="
if [ -d "$HOME/.config/blender" ]; then
    BAK="$HOME/.config/blender.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$HOME/.config/blender" "$BAK"
    echo "Configuración respaldada en: $BAK"
    echo "Si quieres recuperar tus preferencias: mv \"$BAK\" \"$HOME/.config/blender\""
else
    echo "No hay configuración vieja que respaldar."
fi

echo
echo "== 4) Actualizando el sistema e instalando Blender oficial =="
echo "Se pedirá tu contraseña de sudo."
sudo -v || { echo "ERROR: no se pudo obtener sudo."; exit 1; }
sudo pacman -Syu --needed --noconfirm blender
if ! command -v blender >/dev/null 2>&1; then
    echo "ERROR: Blender no quedó instalado."
    exit 1
fi
echo "Instalado correctamente:"
blender --version | head -n 1

echo
echo "== 5) Comprobando GPU y drivers =="
lspci -nnk 2>/dev/null | grep -EA3 -i 'vga|3d|display' || true
if lspci 2>/dev/null | grep -qi nvidia; then
    if ! pacman -Q nvidia-utils >/dev/null 2>&1; then
        echo "AVISO: GPU NVIDIA detectada pero falta nvidia-utils."
        echo "Instala el driver adecuado para tu kernel (por ejemplo nvidia-open-dkms) y reinicia."
    fi
fi

echo
echo "== 6) Probando Blender =="
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    echo "Abriendo Blender..."
    blender >"$EJEC" 2>&1 &
    BPID=$!
    sleep 8
    if kill -0 "$BPID" 2>/dev/null; then
        echo "Blender está abierto correctamente (PID $BPID)."
        echo "Log de ejecución: $EJEC"
    else
        wait "$BPID"
        RC=$?
        echo "Blender falló al abrir (código $RC). Últimas líneas del error:"
        tail -n 40 "$EJEC" || true
        echo
        echo "Prueba manualmente con: blender --debug-gpu"
        exit 1
    fi
else
    echo "No se detectó sesión gráfica (Wayland/X11)."
    echo "Abre Blender desde tu escritorio o desde una terminal gráfica con: blender"
fi

echo
echo "===== Listo. Log completo: $LOG ====="
