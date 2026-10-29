# 1 - Bug del Instalador de GitHub (omarchy-on-cachyos)

## Qué pasó

Se intentó instalar Omarchy sobre CachyOS usando el repositorio
`https://github.com/mroboff/omarchy-on-cachyos.git`. El script
`install-omarchy-on-cachyos.sh` falló **silenciosamente**: imprimía mensajes de
progreso, pero al final:

- Hyprland NO estaba instalado
- `~/.local/share/omarchy/` NO contenía el código de Omarchy
- `install.sh` nunca se ejecutaba
- El usuario quedaba en TTY sin entorno gráfico

## Bugs encontrados

### Bug #1 — Ruta relativa incorrecta (Crítico)
El script hace `cd ../omarchy` pero la ruta real de descarga es otra.
El commit `f7f8c82` agregó la variable `OMARCHY_DIR` pero **nunca la usó** en el `cd`.

```
Línea 91: cd ../omarchy    ← ruta incorrecta
```

Resultado: los `sed` de los patches corren en archivos equivocados o fallan.

### Bug #2 — Incompatible con Omarchy 4.x (Crítico)
El script clona la rama `main` de `basecamp/omarchy`, que en v4.x ya NO tiene
`install.sh` (modelo ISO). Sin `install.sh`, la instalación nunca ocurre.

- Versión compatible: **v3.8.4** (la última 3.x con `install.sh`)
- main / 4.0.0.alpha / v4.0.4: NO compatibles

### Bug #3 — Paquete `omarchy-walker` no existe (Crítico)
El archivo `omarchy-base.packages` lista `omarchy-walker`, pero ese paquete fue
renombrado a `walker` en el repo de CachyOS.

```
install/omarchy-base.packages:96: omarchy-walker   ← no existe
```

### Bug #4 — `guard.sh` no parcheado para CachyOS (Alto)
El `guard.sh` de Omarchy verifica el bootloader `limine`, pero CachyOS usa
`systemd-boot`. El check falla y aborta la instalación.

### Bug #5 — `gum` no se instala antes de `install.sh` (Medio)
`install.sh` usa `gum` para la interfaz, pero el script de CachyOS no lo instala
primero. Resultado: `command not found: gum`.

### Bug #6 — `network.sh` rompe DNS (Alto)
Al cambiar de `wpa_supplicant` a `iwd`, el DNS queda roto temporalmente porque
no se espera a que `systemd-resolved` reconecte.

### Bug #7 — `OMARCHY_BARE` innecesario (Bajo)
Variable de entorno que en v3.8.4 no cumple función. Solo confunde.

### Bug #8 — `vpl-gpu-rt` innecesario (Medio)
Se instala `vpl-gpu-rt` en `video-acceleration.sh`, pero ese paquete es solo
para GPUs **Tiger Lake o más nuevas**. La GPU de este equipo es Kaby Lake-R
(UHD 620), así que no aplica.

## Chronología

| Hora | Evento | Resultado |
|---|---|---|
| ~16:00 | 1er intento install.sh | ❌ falla silenciosa |
| ~16:10 | 2do intento | ❌ falla |
| ~16:20 | 3er intento | ❌ falla |
| ~16:39 | 4to intento (con fixes) | ✅ COMPLETADO 16:41:23 |
