# Omarchy on CachyOS — Guía Completa de Instalación y Reparación

**Fecha:** 17 de octubre de 2026
**Usuario:** eynor
**Sistema:** CachyOS (Arch-based) + Omarchy v3.8.4
**Repositorio con bugs:** `https://github.com/mroboff/omarchy-on-cachyos.git` (commit `23e7565`)

---

## 1. Información del Hardware

| Componente | Detalle |
|---|---|
| CPU/GPU | Intel Kaby Lake-R GT2 [UHD Graphics 620] |
| Pantalla | Chimei Innolux 1920x1080@60Hz (310x170mm, ~14") |
| RAM | 16 GB |
| Disco | NVMe 473 GB (441 GB libres) |
| Kernel | 6.18.55-2-cachyos-lts |
| Escala monitor | 1.25x (configurada manualmente) |

---

## 2. Software Instalado (Estado Final)

### Componentes principales

| Paquete | Versión | Función |
|---|---|---|
| hyprland | 0.56.2-4.1 | Compositor Wayland |
| sddm | 0.21.0-8 | Display manager (login) |
| walker | 2.17.2-1 | App launcher (CachyOS repo) |
| elephant | 2.22.1-1 | Backend de walker (AUR) |
| alacritty | 0.17.0-1.2 | Terminal |
| waybar | 0.15.0-3.1 | Barra superior |
| mako | 1.11.0-1.1 | Notificaciones |
| fish | 4.9.3-1 | Shell principal |
| gnome-keyring | 1:51.1-1.1 | Gestión de contraseñas |
| networkmanager | 1.58.1-2 | Gestión de red |
| iwd | 3.12-2.1 | Backend WiFi (reemplaza wpa_supplicant) |
| mise | latest | Gestor de versiones de lenguajes |

### Paquetes de video (Intel)

| Paquete | Función |
|---|---|
| intel-media-driver | Driver VAAPI para GPUs Intel Broadwell+ |
| libvpl | Intel Video Processing Library |
| intel-media-sdk | Legacy API para GPUs Broadwell-Rocket Lake |
| libva | API de aceleración de video |
| mesa | Driver OpenGL |

**Nota:** `vpl-gpu-rt` NO se instaló — es solo para Tiger Lake y más nuevo. La GPU Kaby Lake-R no lo necesita.

---

## 3. Archivos Modificados

### Archivos de configuración del usuario

| Archivo | Cambio realizado |
|---|---|
| `~/.config/hypr/monitors.conf` | `GDK_SCALE=1.25`, monitor scale `1.25` |
| `~/.config/hypr/bindings.conf` | Descomentado `SUPER+SPACE` para Omarchy Menu |
| `~/.config/uwsm/env` | Fix: removida rama fish del patch de mise |
| `~/.config/fish/conf.d/mise.fish` | Creado: activación de mise para fish |
| `~/.config/elephant/providers/*.so` | 9 plugins compilados manualmente |

### Archivos de Omarchy parcheados (en `~/.local/share/omarchy/`)

| Archivo | Parche |
|---|---|
| `install/omarchy-base.packages` | `omarchy-walker` → `walker` (Bug #3) |
| `install/preflight/guard.sh` | Check de limine comentado (Bug #4) |
| `install/config/hardware/network.sh` | Agregado wait de DNS después del cambio a iwd (Bug #6) |
| `install/config/hardware/intel/video-acceleration.sh` | Removido `vpl-gpu-rt` (Bug #8) |
| `config/uwsm/env` | Fix de mise para fish (Bug #10) |
| + 9 patches originales de cachyos | Ver sección 5 |

### Archivos creados

| Archivo | Propósito |
|---|---|
| `/home/eynor/omarchy-on-cachyos/BUG-REPORT.md` | Documentación de bugs |
| `/home/eynor/install-omarchy.sh` | Script de instalación/reparación |
| `/home/eynor/fix-walker.sh` | Script para instalar elephant |

---

## 4. Atajos de Teclado Principales

| Atajo | Acción |
|---|---|
| `SUPER + SPACE` | Menú de Omarchy (temas, fondos, etc.) |
| `SUPER + RETURN` | Terminal (Alacritty) |
| `SUPER + SHIFT + RETURN` | Terminal tmux |
| `SUPER + SHIFT + B` | Navegador |
| `SUPER + SHIFT + F` | File manager (Nautilus) |
| `SUPER + SHIFT + N` | Editor (Neovim) |
| `SUPER + SHIFT + M` | Música (Spotify) |
| `SUPER + SHIFT + O` | Obsidian |
| `SUPER + SHIFT + G` | Signal |

### Prefijos de Walker (SUPER+SPACE o SUPER)

| Prefijo | Función |
|---|---|
| (sin prefijo) | Buscar apps instaladas |
| `.` | Navegar archivos |
| `$` | Historial de clipboard |
| `=` | Calculadora |
| `:` | Emojis y símbolos |
| `@` | Búsqueda web |
| `/` | Lista de providers |

---

## 5. Patches de CachyOS Aplicados

Estos patches son los que `install-omarchy-on-cachyos.sh` aplica al código fuente de Omarchy para hacerlo compatible con CachyOS:

| # | Parche | Archivo afectado |
|---|---|---|
| 1 | Remover tldr (conflicto con tealdeer) | `install/omarchy-base.packages` |
| 2-4 | Adaptar omarchy-update-restart para linux-cachyos | `bin/omarchy-update-restart` |
| 5 | Remover preflight/pacman.sh | `install/preflight/all.sh` |
| 6 | Reemplazar nvidia.sh (chwd de CachyOS) | `install/config/hardware/nvidia.sh` |
| 7 | Fix omarchy-ai-skill.sh (ln -sf) | `install/config/omarchy-ai-skill.sh` |
| 8-10 | Remover plymouth/limine/alt-bootloaders | `install/login/all.sh` |
| 11 | Remover post-install/pacman.sh | `install/post-install/all.sh` |
| 12 | Deshabilitar wpa_supplicant + configurar iwd | `install/config/hardware/network.sh` |
| 13 | Piner walker al repo omarchy (IgnorePkg) | `install/config/walker-elephant.sh` |
| 14 | Soporte mise para fish | `config/uwsm/env` |

### Patches adicionales aplicados manualmente (por bugs)

| # | Parche | Razón |
|---|---|---|
| A | `omarchy-walker` → `walker` | Bug #3: paquete renombrado |
| B | Comentar check de limine en guard.sh | Bug #4: CachyOS usa systemd-boot |
| C | DNS wait al final de network.sh | Bug #6: cambio a iwd rompe DNS |
| D | Remover vpl-gpu-rt de video-acceleration.sh | Bug #8: innecesario para Kaby Lake |
| E | Fix mise fish en uwsm/env | Bug #10: bash no puede source desde pipe |

---

## 6. Elephant Providers Compilados

El paquete AUR de elephant no incluye los plugins. Se compilaron con:

```bash
SRC=~/.cache/yay/elephant/src/elephant-2.22.1/internal/providers
mkdir -p ~/.config/elephant/providers

for p in menus desktopapplications files clipboard calc symbols websearch providerlist runner; do
  cd "$SRC/$p"
  go build -buildvcs=false -buildmode=plugin -trimpath
  cp "$p.so" ~/.config/elephant/providers/
done
```

| Plugin | Función | Prefijo en walker |
|---|---|---|
| `menus.so` | Menús Omarchy (temas, fondos) | — |
| `desktopapplications.so` | Apps del sistema | — |
| `files.so` | Navegador de archivos | `.` |
| `clipboard.so` | Historial clipboard | `$` |
| `calc.so` | Calculadora | `=` |
| `symbols.so` | Emojis/símbolos | `:` |
| `websearch.so` | Búsqueda web | `@` |
| `providerlist.so` | Lista providers | `/` |
| `runner.so` | Ejecutar comandos | — |

**Importante:** Si se actualiza elephant, recompilar todos los providers.

---

## 7. Temas Disponibles

```bash
omarchy theme list
```

```
catppuccin        gruvbox           osaka-jade
catppuccin-latte  hackerman         retro-82
ethereal          kanagawa          ristretto
everforest        lumon             rose-pine
flexoki-light     matte-black       tokyo-night
                  miasma            vantablack
                  nord              white
```

Tema actual: **Miasma**

Cambiar tema:
```bash
omarchy theme set <nombre>
```

---

## 8. Red

| Componente | Estado |
|---|---|
| NetworkManager | Activo |
| iwd (WiFi backend) | Activo (reemplaza wpa_supplicant) |
| wpa_supplicant | Deshabilitado |
| DNS | 127.0.0.53 (systemd-resolved via NetworkManager) |
| Repo omarchy | Agregado en /etc/pacman.conf |

---

## 9. Troubleshooting Rápido

| Problema | Solución |
|---|---|
| Walker no abre / "app failure" | `systemctl --user status elephant.service` — verificar que elephant corre |
| Menús "no results" | Verificar `ls ~/.config/elephant/providers/*.so` — recompilar si falta |
| Fuente muy grande | Editar `~/.config/hypr/monitors.conf` — cambiar escala |
| No hay audio | `wpctl status` — verificar PipeWire |
| WiFi no conecta | Verificar `systemctl status iwd` y NetworkManager conf |
| Tema no cambia | `omarchy theme current` — verificar tema aplicado |
| Logs de instalación | `cat /var/log/omarchy-install.log` |
| Logs de elephant | `journalctl --user -u elephant.service -f` |
| Logs de walker | `journalctl --user -u app-walker@autostart.service -f` |
| Recargar Hyprland | `hyprctl reload` |

---

## 10. Comandos Útiles de Omarchy

```bash
omarchy theme current          # Ver tema actual
omarchy theme set <nombre>     # Cambiar tema
omarchy theme list             # Listar temas
omarchy theme bg next          # Siguiente fondo
omarchy-font-current           # Fuente actual
omarchy-font-list              # Fuentes disponibles
omarchy-font-set <nombre>      # Cambiar fuente
omarchy-menu                   # Abrir menú
omarchy-restart-walker         # Reiniciar walker
omarchy-update-restart         # Verificar si necesita reboot
```

---

## 11. Seguridad

⚠️ **Token de GitHub expuesto** en historial de Fish:
```
ghp_Z6gpcZWueEtCQBpK8sUEzBqvJE9984GwmMO
```
**Revocar inmediatamente** en https://github.com/settings/tokens

---

## 12. Estructura de Directorios

```
~/.local/share/omarchy/          # Código fuente de Omarchy v3.8.4
├── bin/                         # Comandos omarchy-*
├── config/                      # Configs por defecto
├── install/                     # Scripts de instalación
├── themes/                      # 19 temas disponibles
├── default/                     # Defaults (walker, elephant, etc.)
└── install.sh                   # Entry point de instalación

~/.config/
├── hypr/                        # Config Hyprland
│   ├── hyprland.conf            # Config principal
│   ├── monitors.conf            # Escala de monitor (1.25x)
│   ├── bindings.conf            # Atajos de teclado
│   └── ...
├── waybar/                      # Barra superior
├── alacritty/                   # Terminal
├── fish/                        # Shell
│   └── conf.d/mise.fish         # Mise para fish
├── elephant/                    # Backend de walker
│   ├── providers/               # 9 plugins .so compilados
│   ├── menus/                   # Menús Lua de Omarchy
│   └── elephant.toml            # Config de elephant
└── walker/                      # App launcher
    └── config.toml              # Config de walker

~/.local/state/omarchy/          # Estado de Omarchy
/var/log/omarchy-install.log     # Log de instalación
```

---

## 13. Resumen de Bugs (Ver BUG-REPORT.md para detalles)

| # | Bug | Severidad |
|---|---|---|
| 1 | `cd ../omarchy` ruta relativa incorrecta | Crítico |
| 2 | Incompatible con Omarchy 4.x (sin install.sh) | Crítico |
| 3 | Paquete `omarchy-walker` no existe | Crítico |
| 4 | `guard.sh` no parcheado para CachyOS (limine) | Alto |
| 5 | `gum` no se instala antes de install.sh | Medio |
| 6 | `network.sh` rompe DNS temporalmente | Alto |
| 7 | `OMARCHY_BARE` innecesario en v3.8.4 | Bajo |
| 8 | `vpl-gpu-rt` innecesario para GPUs < Tiger Lake | Medio |
| 9 | Walker crashea sin elephant | Crítico |
| 10 | Patch mise con sintaxis fish en uwsm/env | Alto |
| 11 | Elephant AUR no incluye providers (.so) | Crítico |
| 12 | aether (v4) sobrescribe colors.toml con formato incompatible | Crítico |

**Conclusión:** El repositorio `omarchy-on-cachyos` tiene bugs significativos que impiden una instalación limpia. Los bugs #1, #3, #9, #11, y #12 son críticos. Se recomienda reportar estos issues al repositorio upstream.

---

## 14. Archivos de Referencia

| Archivo | Contenido |
|---|---|
| `~/omarchy-on-cachyos/BUG-REPORT.md` | Detalle técnico de los 11 bugs |
| `~/omarchy-on-cachyos/ESTA-GUIA.md` | Este archivo — guía completa |
| `~/install-omarchy.sh` | Script de instalación/reparación |
| `~/fix-walker.sh` | Script para instalar elephant |
| `/var/log/omarchy-install.log` | Log completo de instalación |
