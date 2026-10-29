# 1 - Solución: Reparar el Instalador de GitHub

## Requisitos previos
```bash
sudo pacman -S --needed git base-devel gum
```

## Paso 1: Clonar la versión CORRECTA de Omarchy (v3.8.4)
```bash
rm -rf ~/omarchy
git clone --branch v3.8.4 --depth 1 https://github.com/basecamp/omarchy.git ~/omarchy
```

**IMPORTANTE:** NO usar `main` ni v4.x — no tienen `install.sh`.

## Paso 2: Aplicar los patches de CachyOS
El script `install-omarchy-on-cachyos.sh` aplica 14 patches. Verificar que cada uno
corra en el archivo correcto.

## Paso 3: Aplicar los 5 patches adicionales (bugs del repo)

### Fix Bug #1 — Ruta relativa
En `install-omarchy-on-cachyos.sh`, reemplazar:
```bash
cd ../omarchy
```
por:
```bash
cd "$OMARCHY_DIR"
```

### Fix Bug #3 — Nombre del paquete walker
```bash
sed -i 's/^omarchy-walker$/walker/' ~/omarchy/install/omarchy-base.packages
```

### Fix Bug #4 — guard.sh limine
```bash
sed -i 's/^check_limine/#check_limine/' ~/omarchy/install/preflight/guard.sh
# O comentar la verificación de limine
```

### Fix Bug #6 — DNS en network.sh
Agregar al final de `install/config/hardware/network.sh`:
```bash
# Esperar a que el DNS se restablezca
for i in {1..10}; do
  systemd-resolve --status &>/dev/null && break
  sleep 1
done
```

### Fix Bug #8 — vpl-gpu-rt
En `install/config/hardware/intel/video-acceleration.sh`, remover `vpl-gpu-rt`
de la lista de paquetes.

## Paso 4: Copiar a la ubicación final
```bash
rm -rf ~/.local/share/omarchy
cp -r ~/omarchy ~/.local/share/omarchy
```

## Paso 5: Ejecutar la instalación
```bash
cd ~/.local/share/omarchy
./install.sh
```

## Verificación
```bash
cat /var/log/omarchy-install.log | tail -5
# Debe decir: "Omarchy Installation Completed: <hora>"

which hyprland
ls ~/.local/share/omarchy/bin/ | head
```
