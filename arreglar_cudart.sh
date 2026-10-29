#!/usr/bin/env bash
# Arregla el error "libcudart.so.13: cannot open shared object file" de Blender en Arch.
# Causa: opensubdiv 3.8.0-1 se compiló con CUDA 13 y quedó enlazado a libcudart,
# pero Arch no declara el paquete cuda como dependencia (fallo de empaquetado temporal).
# Este script instala SOLO el runtime de CUDA 13 exacto que usó Arch (1.7 MB), no los 5 GB del toolkit.
set -uo pipefail

VER="13.4.92"
URL="https://developer.download.nvidia.com/compute/cuda/redist/cuda_cudart/linux-x86_64/cuda_cudart-linux-x86_64-${VER}-archive.tar.xz"
SHA="0ac5dbc538d04e9983bc493b410cce4b459e1ee9f5f6654b6464ef7b3e14a8b5"
DEST="/usr/local/lib/cuda-13.4"
CONF="/etc/ld.so.conf.d/zz-blender-cudart.conf"
LOG="$HOME/blender-cudart.log"
EJEC="$HOME/blender-ejecucion.log"

exec > >(tee -a "$LOG") 2>&1
echo "===== Fix libcudart para Blender: $(date) ====="

if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: ejecuta este script como tu usuario normal, NO con sudo."
    echo "Uso: bash \"$0\""
    exit 1
fi

for cmd in curl tar xz sha256sum blender ldconfig; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: falta el comando '$cmd'."
        exit 1
    fi
done

tiene_cudart() {
    local cache
    cache="$(ldconfig -p 2>/dev/null || true)"
    case "$cache" in
        *libcudart.so.13*) return 0 ;;
        *) return 1 ;;
    esac
}

if tiene_cudart; then
    echo "libcudart.so.13 ya está disponible en el sistema. No hace falta descargar nada."
else
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    echo "== Descargando runtime CUDA ${VER} (1.7 MB) =="
    if ! curl -fL --retry 3 --max-time 180 -o "$TMP/cudart.tar.xz" "$URL"; then
        echo "ERROR: no se pudo descargar el runtime de NVIDIA."
        exit 1
    fi

    echo "== Verificando checksum =="
    if ! echo "$SHA  $TMP/cudart.tar.xz" | sha256sum -c -; then
        echo "ERROR: checksum incorrecto. No se instala nada."
        exit 1
    fi

    echo "== Extrayendo =="
    if ! tar -xJf "$TMP/cudart.tar.xz" -C "$TMP"; then
        echo "ERROR: no se pudo extraer el archivo."
        exit 1
    fi
    SRC="$TMP/cuda_cudart-linux-x86_64-${VER}-archive"

    echo "== Instalando en $DEST =="
    sudo -v || { echo "ERROR: no se pudo obtener sudo."; exit 1; }
    sudo install -d "$DEST" || exit 1
    sudo install -m 755 "$SRC/lib/libcudart.so.${VER}" "$DEST/" || exit 1
    sudo ln -sf "libcudart.so.${VER}" "$DEST/libcudart.so.13"
    sudo ln -sf "libcudart.so.13" "$DEST/libcudart.so"
    echo "$DEST" | sudo tee "$CONF" >/dev/null
    sudo ldconfig

    if ! tiene_cudart; then
        echo "ERROR: ldconfig no registró libcudart.so.13."
        exit 1
    fi
    echo "Runtime instalado y registrado."
fi

echo
echo "== Comprobando Blender =="
if ! blender --version >"$HOME/blender-version.txt" 2>&1; then
    echo "Blender sigue fallando:"
    cat "$HOME/blender-version.txt"
    echo
    echo "Revisa si falta otra librería con:"
    echo "  ldd /usr/bin/blender | grep 'not found'"
    exit 1
fi
head -n 1 "$HOME/blender-version.txt"

echo
echo "== Abriendo Blender =="
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    blender >"$EJEC" 2>&1 &
    BPID=$!
    sleep 8
    if kill -0 "$BPID" 2>/dev/null; then
        echo "Blender está abierto correctamente (PID $BPID)."
        echo "Log: $EJEC"
    else
        wait "$BPID"
        RC=$?
        echo "Blender falló al abrir (código $RC). Últimas líneas:"
        tail -n 40 "$EJEC" || true
        exit 1
    fi
else
    echo "No se detectó sesión gráfica. Abre Blender con: blender"
fi

echo
echo "== Notas =="
echo "Este arreglo solo aporta el runtime que exige opensubdiv; no es el toolkit CUDA completo."
echo "Si tienes NVIDIA y quieres renderizar con Cycles por GPU, instala el paquete oficial:"
echo "  sudo pacman -S cuda"
echo "Antes de instalarlo, puedes quitar este arreglo con:"
echo "  sudo rm -f $CONF && sudo rm -rf $DEST && sudo ldconfig"
echo "Cuando Arch corrija opensubdiv, también puedes quitarlo."
echo
echo "===== Listo. Log: $LOG ====="
