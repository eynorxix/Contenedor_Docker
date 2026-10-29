# Bug Report: Instalación fallida de Omarchy sobre CachyOS

**Fecha:** 17 de octubre de 2026
**Repositorio:** `https://github.com/mroboff/omarchy-on-cachyos.git`
**Commit analizado:** `23e7565` (Merge PR #47, 2026-06-01)
**Sistema:** CachyOS (x86_64), Shell: Fish, Sesión: TTY
**Hardware GPU:** Intel UHD Graphics 620 (Kaby Lake-R)

---

## 1. Resumen del problema

La instalación de Omarchy sobre CachyOS mediante `install-omarchy-on-cachyos.sh`
falla silenciosamente sin instalar nada. El usuario ejecuta el script, este
imprime mensajes de progreso, pero al final Hyprland no está instalado,
`~/.local/share/omarchy/` no contiene el código de Omarchy, y `install.sh`
nunca se ejecuta.

---

## 2. Estado del sistema tras ejecutar el script

| Componente | Estado | Detalle |
|---|---|---|
| Repo `[omarchy]` en pacman.conf | ✅ Agregado | Línea agregada correctamente por el script |
| `/etc/sddm.conf` eliminado | ✅ | |
| `wpa_supplicant` deshabilitado | ✅ | |
| `~/omarchy/` (fuente Omarchy) | ⚠️ Clonada pero sin parchar | Versión `4.0.0.alpha` (main/dev branch) |
| `~/.local/share/omarchy/` | ❌ Contenido incorrecto | Solo contiene los 3 scripts de `bin/`, no el código de Omarchy |
| Patches de CachyOS aplicados | ❌ | Los `sed` corrieron en archivos equivocados |
| `install.sh` ejecutado | ❌ | El archivo no existe en la versión clonada |
| Hyprland instalado | ❌ | `pacman -Q hyprland` → no encontrado |
| SDDM / display manager | ❌ | `systemctl is-enabled sddm` → not-found |

---

## 3. Bug #1 — Ruta relativa incorrecta (`cd ../omarchy`)

### Archivo afectado
`bin/install-omarchy-on-cachyos.sh`, línea 91

### Código con el bug
```bash
# Líneas 11-12: Calculan la ruta ABSOLUTA correcta
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_DIR="$SCRIPT_DIR/../../omarchy"
# → Resuelve a: /home/<usuario>/omarchy

# Línea 14-16: fetch-omarchy.sh clona en $SCRIPT_DIR/../../omarchy = ~/omarchy ✅

# LÍNEA 91: Usa una ruta RELATIVA equivocada
cd ../omarchy
# → Desde ~/omarchy-on-cachyos/bin resuelve a ~/omarchy-on-cachyos/omarchy
# → ¡ESTE DIRECTORIO NO EXISTE!
```

### ¿Por qué falla?

Cuando el usuario ejecuta el script desde `~/omarchy-on-cachyos/bin`:

| Expresión | Resuelve a | ¿Existe? |
|---|---|---|
| `$SCRIPT_DIR/../../omarchy` (fetch-omarchy.sh) | `~/omarchy` | ✅ Sí (ahí clonó) |
| `cd ../omarchy` (install-omarchy-on-cachyos.sh:91) | `~/omarchy-on-cachyos/omarchy` | ❌ No |

`fetch-omarchy.sh` clona correctamente en `~/omarchy`, pero el script principal
nunca llega ahí porque usa `cd ../omarchy` (relativo al CWD) en lugar de
`cd "$OMARCHY_DIR"` (la variable absoluta que ya calculó en la línea 12).

### Consecuencias en cadena

1. `cd ../omarchy` falla → el script **continúa ejecutándose** en `~/omarchy-on-cachyos/bin`
   (no hay `set -e` en el script principal, así que el error de `cd` se ignora).
2. Los ~15 comandos `sed` (líneas 94-155) intentan modificar archivos de Omarchy
   que no existen en el directorio actual → **todos fallan silenciosamente**.
3. `cp -r . ~/.local/share/omarchy` (línea 159) copia el contenido de `bin/`
   en vez del código de Omarchy → `~/.local/share/omarchy/` queda con solo
   3 scripts en lugar del árbol completo.
4. `./install.sh` (línea 187) no existe en ese directorio → **la instalación nunca corre**.

### Cómo se introdujo el bug

El commit `f7f8c82` ("fix: synchronize paths and clean up debug logs",
2026-05-20) introdujo las variables `SCRIPT_DIR` y `OMARCHY_DIR` para
corregir rutas, pero solo las usó parcialmente:

- ✅ Las usó en el fallback de clonado (línea 20)
- ✅ Las usó en el check de directorio (línea 23)
- ❌ **NO** reemplazó el `cd ../omarchy` de la línea 91

El `cd ../omarchy` es un residuo del código anterior al commit `f7f8c82`.

### Fix sugerido

```bash
# Línea 91: reemplazar
cd ../omarchy
# por
cd "$OMARCHY_DIR"
```

---

## 4. Bug #2 — Incompatibilidad con Omarchy 4.x (no existe `install.sh`)

### Archivo afectado
`bin/install-omarchy-on-cachyos.sh`, línea 187 y `bin/fetch-omarchy.sh`

### Descripción

El script asume que Omarchy tiene un `install.sh` en la raíz del repositorio.
Esto era cierto para **Omarchy 3.x**, pero **Omarchy 4.x eliminó `install.sh`**
al migrar a un modelo de instalación basado en ISO.

### Verificación

```
$ git -C ~/omarchy show v3.8.4:install.sh   → ✅ Existe
$ git -C ~/omarchy show v4.0.4:install.sh   → ❌ No existe (exit 128)
$ git -C ~/omarchy show origin/main:install.sh → ❌ No existe (exit 128)
```

### Versión clonada por el usuario

El usuario eligió "Bleeding Edge" (main branch), que corresponde a
`4.0.0.alpha`. Este branch **no tiene `install.sh`**.

### Versión de Omarchy que SÍ funciona

Cualquier tag **3.x** (ej. `v3.8.4`, la última versión 3.x estable).

### Fix sugerido

En `fetch-omarchy.sh`, filtrar los tags para excluir versiones 4.x,
o verificar la existencia de `install.sh` antes de continuar:

```bash
# Opción A: Filtrar solo 3.x
RELEASES=($(git ls-remote --tags --refs $REPO_URL 2>/dev/null \
  | awk -F/ '{print $3}' \
  | grep '^v3\.' \
  | sort -rV | head -n 5))

# Opción B: En install-omarchy-on-cachyos.sh, agregar check antes de la línea 186
if [ ! -f "$OMARCHY_DIR/install.sh" ]; then
    echo "Error: install.sh not found. Omarchy 4.x is not supported by this script."
    echo "Please select a 3.x stable release when prompted by fetch-omarchy.sh."
    exit 1
fi
```

---

## 5. Bug menor — Variable `OMARCHY_BASE` vs `OMARCHY_BARE`

### Observación

En el historial de comandos del usuario se ve confusión entre:
- `OMARCHY_BASE=true` (incorrecto)
- `OMARCHY_BARE=true` (correcto, usado por Omarchy 3.x)

Esto no es un bug del script de cachyos sino confusión del usuario, pero
señala que la documentación podría aclarar la variable correcta.

---

## 6. Sequencia de comandos fallidos (historial del usuario)

```bash
# 1. Clonó omarchy-on-cachyos ✅
git clone https://github.com/mroboff/omarchy-on-cachyos.git

# 2. Ejecutó el script (falló silenciosamente por Bug #1 y #2)
cd omarchy-on-cachyos/bin
./install-omarchy-on-cachyos.sh

# 3. Intentó clonar Omarchy manualmente (con errores de sintaxis)
git clone https://github.com/omarchy/omarchy.git  ~/.local/share/omarchy  # espacios mal
git clone "https://github.com/omarchy/omarchy.git ~/.local/share/omarchy" # comillas mal

# 4. Nota: usó omarchy/omarchy.git, pero el repo oficial es basecamp/omarchy.git
#    (aunque omarchy/omarchy puede ser un mirror válido)

# 5. Intentó ejecutar install.sh con variables incorrectas
env OMARCHY_BASE=true ./install.sh   # debería ser OMARCHY_BARE
env OMARCHY_BARE=true ./install.sh   # correcto pero no había install.sh (Bug #2)

# 6. Volvió a correr el script de cachyos (mismo resultado fallido)
cd ~/omarchy-on-cachyos/bin
./install-omarchy-on-cachyos.sh
```

---

## 7. ⚠️ Seguridad — Token de GitHub expuesto

En el historial de Fish shell quedó registrado un **GitHub Personal Access Token**:

```
ghp_Z6gpcZWueEtCQBpK8sUEzBqvJE9984GwmMO
```

**Acción requerida:** Revocar inmediatamente en
[GitHub → Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
y generar uno nuevo. Si el token sigue activo, cualquier persona con acceso
a la máquina o al historial puede usarlo para acceder a repositorios,
gists, y otros recursos de la cuenta.

---

## 8. Plan de reparación

### Paso 1 — Revocar el token de GitHub (URGENTE)
Ir a GitHub y revocar el token expuesto.

### Paso 2 — Limpiar el estado parcial
```bash
rm -rf ~/.local/share/omarchy   # Contiene contenido incorrecto
rm -rf ~/omarchy                # Clonado sin parchar, se re-clonará con versión correcta
```

### Paso 3 — Clonar versión compatible (3.x)
```bash
git clone --depth 1 -b v3.8.4 https://github.com/basecamp/omarchy ~/omarchy
```

### Paso 4 — Aplicar patches de CachyOS manualmente
Aplicar cada sed del script `install-omarchy-on-cachyos.sh` (líneas 94-155)
sobre `~/omarchy/` correctamente.

### Paso 5 — Copiar a ubicación final
```bash
mkdir -p ~/.local/share/omarchy
cp -r ~/omarchy/* ~/.local/share/omarchy/
```

### Paso 6 — Ejecutar la instalación
```bash
cd ~/.local/share/omarchy
OMARCHY_BARE=true ./install.sh
```

---

## 9. Bugs adicionales encontrados durante la reparación

### Bug #3 — Paquete `omarchy-walker` no existe en el repo (línea 96 de omarchy-base.packages)

**Archivo:** `install/omarchy-base.packages`, línea 96

`omarchy-base.packages` lista `omarchy-walker`, pero el paquete se llama `washer` en el repo omarchy de pkgs.omarchy.org. Esto causó que `base.sh` fallara con `error: target not found: omarchy-walker` y la instalación se detuviera antes de instalar Hyprland.

**Fix:** Cambiar `omarchy-walker` → `walker` en `omarchy-base.packages`.

**Nota:** El cachyos repo tiene `walker 2.17.2-1` y el omarchy repo tiene `walker 2.17.0-1`. pacman elige la versión más nueva (cachyos), lo cual funciona correctamente.

---

### Bug #4 — `guard.sh` no fue parchado para CachyOS (limine)

**Archivo:** `install/preflight/guard.sh`, línea 40

El script `install-omarchy-on-cachyos.sh` remueve `limine-snapper.sh`, `alt-bootloaders.sh` y `plymouth.sh` de `login/all.sh`, pero **olvidó parchear `guard.sh`**, que verifica `command -v limine` y aborta si no está instalado. CachyOS usa systemd-boot, no limine.

**Fix:** Comentar la línea del check de limine en `guard.sh`:
```bash
# command -v limine &>/dev/null || abort "Limine bootloader"
```

---

### Bug #5 — `gum` no se instala antes de correr install.sh

El script `install-omarchy-on-cachyos.sh` no instala `gum`, pero `install.sh` y muchos scripts de Omarchy lo necesitan (el `abort()` de `guard.sh` usa `gum confirm`, entre otros).

**Fix:** Instalar `gum` antes de ejecutar `install.sh`:
```bash
sudo pacman -S --needed --noconfirm gum
```

---

### Bug #6 — `network.sh` rompe DNS temporalmente

**Archivo:** `install/config/hardware/network.sh` (patch de cachyos)

El patch de cachyos deshabilita `wpa_supplicant` y cambia NetworkManager al backend `iwd` DURANTE la instalación. Esto reinicia el stack de red y causa que DNS deje de resolver temporalmente. Si algún script de instalación intenta descargar paquetes inmediatamente después, falla con `Could not resolve host`.

**Evidencia:** `hardware/network.sh` completó a las 16:29:15, y `hardware/intel/video-acceleration.sh` falló a las 16:29:19 intentando descargar `vpl-gpu-rt` de mirrors de CachyOS con DNS caído.

**Impacto:** La instalación se detiene en `video-acceleration.sh` (o el siguiente script que necesite red). Al re-ejecutar con la red restaurada, continúa correctamente.

**Fix sugerido:** Agregar un `sleep 5` y un retry de DNS al final de `network.sh`, o mover el patch de network al final del stage de config:
```bash
# Al final de network.sh, después del cambio a iwd:
sleep 5
for i in {1..10}; do
  if ping -c1 -W2 cachyos.org &>/dev/null; then break; fi
  echo "Waiting for network... ($i)"
  sleep 2
done
```

---

### Bug #7 — `OMARCHY_BARE` no se necesita en v3.8.4

El historial del usuario muestra intentos con `OMARCHY_BASE=true` y `OMARCHY_BARE=true`. En v3.8.4, ninguna variable de entorno es necesaria — `install.sh` funciona directamente. Estas variables son de versiones anteriores o del ISO installer de Omarchy 4.x.

---

### Bug #8 — `video-acceleration.sh` instala `vpl-gpu-rt` innecesariamente en GPUs anteriores a Tiger Lake

**Archivo:** `install/config/hardware/intel/video-acceleration.sh`, línea 6

El script instala `intel-media-driver libvpl vpl-gpu-rt` para cualquier GPU Intel que coincida con `hd graphics|uhd graphics|xe|iris|arc|panther lake`. Pero `vpl-gpu-rt` es solo para **Tiger Lake y más nuevo** (según su descripción: "Intel VPL runtime implementation for Intel GPUs (Tiger Lake and newer)"). En GPUs anteriores como Kaby Lake-R (UHD Graphics 620), el paquete no es necesario y solo causa errores de descarga.

**Fix:** Remover `vpl-gpu-rt` de la lista de paquetes:
```bash
omarchy-pkg-add intel-media-driver libvpl
```

**Fix adicional en `network.sh`:** Agregar espera de restauración de DNS después del cambio a iwd, para que scripts posteriores que necesiten red no fallen:
```bash
for i in $(seq 1 15); do
  if getent hosts cachyos.org &>/dev/null || ping -c1 -W2 1.1.1.1 &>/dev/null; then
    break
  fi
  sleep 2
done
```

---

## 10. Cronología de la reparación (2026-10-17)

| Hora | Acción | Resultado |
|---|---|---|
| ~15:40 | Limpieza de estado parcial | ✅ |
| ~15:41 | Clonar Omarchy v3.8.4 | ✅ |
| ~15:42-15:48 | Aplicar 14 patches de CachyOS | ✅ |
| ~15:48 | Copiar a ~/.local/share/omarchy | ✅ |
| ~15:54 | 1er intento de install.sh | ❌ Falló: `omarchy-walker` no encontrado (Bug #3) |
| ~16:00 | Fix: renombrar a `walker` | ✅ |
| ~16:02 | 2do intento de install.sh | ❌ Falló: DNS caído en video-acceleration.sh (Bug #6) |
| ~16:33 | 3er intento de install.sh | ❌ Mismo error DNS + vpl-gpu-rt (Bug #8) |
| ~16:35 | Fix: parchear network.sh (DNS wait) + video-acceleration.sh (quitar vpl-gpu-rt) | ✅ |
| ~16:39 | 4to intento de install.sh | ✅ **COMPLETADO** — `Omarchy Installation Completed: 16:41:23` |
| ~17:07 | Walker crashea: `Please install elephant` (Bug #9) | ❌ |
| ~17:12 | Fix: instalar elephant AUR + `elephant service enable` | ✅ |
| ~17:13 | Walker funciona pero menús "no results" (Bug #11) | ❌ `missing provider=menus` |
| ~17:17 | Fix: compilar menus.so | ✅ Temas funcionan |
| ~17:25 | Apps no aparecen — faltan otros providers (Bug #11) | ❌ |
| ~17:25 | Fix: compilar 8 providers restantes | ✅ **TODO FUNCIONANDO** |

---

## 12. Errores post-instalación

### Error A — `uwsm/env` con sintaxis fish en bash (CRÍTICO)

**Archivo:** `~/.config/uwsm/env`

El cachyos-on-omarchy parche de mise (línea 155 del script original) insertó soporte para fish en `config/uwsm/env`:
```bash
elif [ "$SHELL" = "/bin/fish" ] && command -v mise &> /dev/null; then
  mise activate fish | source
fi
```

Pero `~/.config/uwsm/env` lo ejecuta **bash** (UWSM env preloader), no fish. Bash no puede hacer `source` desde un pipe, causando:
```
uwsm_env-preloader: /home/eynor/.config/uwsm/env: line 14: source: filename argument required
```

**Fix:** Remover la rama fish de `uwsm/env` y crear `~/.config/fish/conf.d/mise.fish`:
```bash
# ~/.config/fish/conf.d/mise.fish
if type -q mise
    mise activate fish | source
end
```

---

### Error B — `gpgconf: error running gpg-connect-agent` (TRANSITORIO)

Durante la instalación, `gpg.sh` ejecuta `sudo gpgconf --kill dirmngr` y `sudo gpgconf --launch dirmngr`. El `sudo` cambia el socket GPG a root, causando conflicto con el GPG del usuario. El script tiene `|| true` así que no aborta. GPG funciona correctamente después del primer uso.

---

### Error C — `gkr-pam: couldn't unlock the login keyring` (TRANSITORIO)

Aparece en el primer login via SDDM. El keyring GNOME no se desbloquea automáticamente porque no hay sesión previa. Se resuelve al primer unlock manual o al configurar auto-unlock. `gnome-keyring-daemon` queda activo después.

---

### Error D — Errores de kernel (NORMALES para Kaby Lake)

```
ACPI BIOS Error: Field [CAP1] exceeds size of target Buffer
Bluetooth: hci0: Reading supported features failed (-16)
SGX disabled or unsupported by BIOS
```

Son warnings de hardware específicos de Kaby Lake-R. No afectan el funcionamiento.

---

## 13. Estado final del sistema

| Componente | Estado |
|---|---|
| Hyprland 0.56.2 | ✅ Corriendo (Wayland) |
| SDDM 0.21.0 | ✅ Activo |
| Omarchy v3.8.4 | ✅ Instalado en ~/.local/share/omarchy |
| Alacritty | ✅ |
| Walker 2.17.2 | ✅ Corriendo con 9 providers |
| Elephant 2.22.1 | ✅ Servicio activo con 9 providers compilados |
| mise | ✅ (configurado en bash + fish) |
| gnome-keyring | ✅ Activo |
| opencode | ✅ Funcionando |
| Intel video acceleration | ✅ (intel-media-driver + libvpl) |
| vpl-gpu-rt | ❌ No instalado (innecesario para Kaby Lake) |
| Monitor scale | ✅ 1.25x (1080p laptop, antes 1.5x + GDK_SCALE=2) |

---

## 14. Bug #9 — Walker crashea sin elephant (post-instalación)

**Archivo:** `install/first-run/elephant.sh`

Walker 2.17.2+ (versión de CachyOS) requiere **elephant** como backend. Sin él, walker crashea con `Please install elephant` y el servicio `app-walker@autostart.service` entra en loop de reinicios, generando notificaciones "app failure".

El script `install/first-run/elephant.sh` ejecuta `elephant service enable` pero:
1. No instala elephant (asume que ya está)
2. El `first-run` no corrió porque la instalación fue interrumpida múltiples veces
3. `elephant` no está en `omarchy-base.packages` — viene del AUR

**Fix:**
```bash
yay -S --noconfirm elephant
elephant service enable
systemctl --user start elephant.service
systemctl --user restart app-walker@autostart.service
```

**Nota:** `elephant service enable` usa su propio CLI, NO `systemctl enable`. Genera el symlink del servicio user manualmente.

---

## 15. Bug #10 — Patch de mise con sintaxis fish en uwsm/env

Ver sección 12 Error A. El patch de cachyos insertó `mise activate fish | source` en `~/.config/uwsm/env` que lo ejecuta bash. Causa `source: filename argument required` en cada login.

**Fix:** Remover rama fish de uwsm/env, crear `~/.config/fish/conf.d/mise.fish`.

---

## 16. Bug #11 — Elephant AUR no incluye providers (menús y apps no funcionan)

**Paquete:** `elephant` (AUR 2.22.1)

El paquete AUR de elephant solo compila el binario principal (`/usr/bin/elephant`). Los providers son **plugins Go** que deben compilarse por separado con `-buildmode=plugin` y colocarse en `~/.config/elephant/providers/`. Sin ellos:

- Sin `menus.so`: walker muestra "no results" al cambiar temas/fondos
- Sin `desktopapplications.so`: walker no muestra apps instaladas
- Sin `files.so`, `clipboard.so`, etc.: no funcionan los prefijos `.` `$` `=` `:` etc.

**Evidencia:** `elephant listproviders` retorna vacío. Log: `ERROR staterequesthandler "missing provider"=menus`. Tras instalar solo menus, faltaban los demás: apps no aparecían en el launcher.

**Fix — compilar los 9 providers que usa Omarchy:**
```bash
SRC=~/.cache/yay/elephant/src/elephant-2.22.1/internal/providers
mkdir -p ~/.config/elephant/providers

for p in menus desktopapplications files clipboard calc symbols websearch providerlist runner; do
  cd "$SRC/$p"
  go build -buildvcs=false -buildmode=plugin -trimpath
  cp "$p.so" ~/.config/elephant/providers/
done

systemctl --user restart elephant.service
systemctl --user restart app-walker@autostart.service
```

**Providers compilados y su función:**

| Plugin | Función | Uso en walker |
|---|---|---|
| `menus.so` | Menús custom (temas, fondos, unlocks) | `SUPER+SPACE` → Style |
| `desktopapplications.so` | Apps instaladas del sistema | Búsqueda principal |
| `files.so` | Navegador de archivos | Prefijo `.` |
| `clipboard.so` | Historial de clipboard | Prefijo `$` |
| `calc.so` | Calculadora | Prefijo `=` |
| `symbols.so` | Emojis y símbolos | Prefijo `:` |
| `websearch.so` | Búsqueda web | Prefijo `@` |
| `providerlist.so` | Lista de providers | Prefijo `/` |
| `runner.so` | Ejecución de comandos | Búsqueda directa |

**Nota:** Los menus de Omarchy (themes, background_selector, unlocks) son archivos Lua en `~/.config/elephant/menus/` que el provider menus carga. Los symlinks ya fueron creados por `walker-elephant.sh` durante la instalación.

**Nota 2:** Los plugins `.so` de Go son sensibles a la versión exacta de Go y de las dependencias. Si se actualiza elephant, hay que recompilar todos los providers.

---

## 17. Bug #12 — aether (v4) sobrescribe colors.toml con formato incompatible

**Paquete:** `aether` (4.32.0-2, preinstalado por Omarchy)

`aether` es un generador de temas de escritorio diseñado para **Omarchy v4**. Al ejecutarse, sobrescribe `~/.config/omarchy/current/theme/colors.toml` con formato v4 (keys: `accent`, `red`, `bright_red`, `muted`, `dark_background`, etc.) en lugar del formato v3 esperado (keys: `cursor`, `color0`-`color15`, `selection_background`).

**Resultado:** TODOS los archivos generados por templates quedan con variables sin resolver:
- `alacritty.toml`: 21 templates sin resolver (`{{ cursor }}`, `{{ color0 }}`, etc.)
- `btop.theme`: 34 templates
- `foot.ini`: 18 templates
- `ghostty.conf`: 18 templates
- `gum.env.conf`: 25 templates
- `helix.toml`: 11 templates
- `kitty.conf`: 18 templates
- `obsidian.css`: 26 templates

**Evidencia:**
```
/tmp/Alacritty-58619.log:
[ERROR] [alacritty_config_derive] Config error: black: failed to parse rgb color {{ color8 }};
[ERROR] [alacritty_config_derive] Config error: cursor: failed to parse color {{ cursor }};
...
```

**Causa raíz:** El script `omarchy-remove-preinstalls` (que elimina aether) no se ejecutó, o aether se ejecutó después de la instalación.

**Fix:**
```bash
omarchy-theme-set miasma          # Regenera desde el tema original v3
sudo pacman -Rns aether           # Eliminar herramienta incompatible
omarchy-restart-terminal          # Reiniciar alacritty
```

**Verificación:**
```bash
grep "color0" ~/.config/omarchy/current/theme/colors.toml  # Debe existir
grep "{{" ~/.config/omarchy/current/theme/alacritty.toml   # Debe estar vacío
```

**Script de fix:** `/home/eynor/fix-theme.sh`

---

## 18. Resumen de bugs encontrados en omarchy-on-cachyos

| # | Bug | Severidad | Archivo/Componente |
|---|---|---|---|
| 1 | `cd ../omarchy` ruta relativa incorrecta | Crítico | install-omarchy-on-cachyos.sh:91 |
| 2 | Incompatible con Omarchy 4.x (sin install.sh) | Crítico | fetch-omarchy.sh |
| 3 | Paquete `omarchy-walker` no existe | Crítico | omarchy-base.packages:96 |
| 4 | `guard.sh` no parcheado para CachyOS (limine) | Alto | install/preflight/guard.sh |
| 5 | `gum` no se instala antes de install.sh | Medio | install-omarchy-on-cachyos.sh |
| 6 | `network.sh` rompe DNS temporalmente | Alto | install/config/hardware/network.sh |
| 7 | `OMARCHY_BARE` innecesario en v3.8.4 | Bajo | Documentación |
| 8 | `vpl-gpu-rt` innecesario para GPUs < Tiger Lake | Medio | install/config/hardware/intel/video-acceleration.sh |
| 9 | Walker crashea sin elephant | Crítico | install/first-run/elephant.sh |
| 10 | Patch mise con sintaxis fish en uwsm/env | Alto | config/uwsm/env |
| 11 | Elephant AUR no incluye providers (.so) | Crítico | Paquete AUR elephant |
| 12 | aether (v4) sobrescribe colors.toml con formato incompatible | Crítico | Paquete aether |

---

## 19. Referencias

- Omarchy oficial: `https://github.com/basecamp/omarchy`
- Omarchy-on-CachyOS: `https://github.com/mroboff/omarchy-on-cachyos`
- Última versión 3.x compatible: `v3.8.4`
- Versión actual main (NO compatible): `4.0.0.alpha` / `v4.0.4`
- Repo omarchy packages: `https://pkgs.omarchy.org/`
- Script de reparación: `/home/eynor/install-omarchy.sh`
