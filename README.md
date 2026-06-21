# Waybar Config

Configuración de Waybar para Hyprland, estilo minimalista con íconos Nerd Font y paleta Catppuccin Mocha.

## Estructura

```
~/.config/waybar/
├── config.jsonc       # Configuración principal de módulos
├── style.css          # Estilos y paleta Catppuccin Mocha con gradientes powerline
├── scripts/
│   ├── cava-waybar.sh # Visualizador de audio (cava → JSON para Waybar)
│   └── weather.sh     # Script de clima (3 días, emojis)
└── screenshot/
    └── screenshot-waybar.png
```

## Módulos

### Izquierda
- `custom/arch` — Logo de Arch Linux (ícono Nerd Font)
- `hyprland/workspaces` — Workspaces con íconos
- `hyprland/submap` — Indicador de submapa activo
- `hyprland/window` — Ventana activa con ícono

### Derecha
- CPU | Temperatura | RAM | Red | Audio In | Audio Out | Cava | Tray | Clima | Reloj

### Screenshots

![Screenshot](screenshot/screenshot-waybar.png)

## Características

- **Visualizador de audio**: módulo `custom/cava` que ejecuta `scripts/cava-waybar.sh`; usa `cava` con captura PulseAudio y emite JSON en tiempo real
- **Clima**: Script custom con pronóstico de 3 días (Night, Morning, Noon, Evening) y emojis
- **Reloj**: Calendario mensual en tooltip con semanas, zona horaria `America/Monterrey`
- **Fuente**: JetBrainsMono Nerd Font (propo), 9pt
- **Transparencia**: 15% (`rgba(..., 0.85)`)
- **Layout**: Full-width, sin márgenes, pegado arriba
- **Tema**: Catppuccin Mocha con gradientes powerline

## Cava

El script `scripts/cava-waybar.sh` genera un config temporal de `cava` (12 barras, 30 fps, captura PulseAudio) y convierte la salida raw a bloques Unicode (`▁▂▃▄▅▆▇█`). Emite una línea JSON por frame para que Waybar actualice el módulo en tiempo real. Variables de entorno configurables: `CAVA_BARS`, `CAVA_FRAMERATE`, `CAVA_SENSITIVITY`, `CAVA_LOW_CUTOFF`, `CAVA_HIGH_CUTOFF`.

## Clima

El script `scripts/weather.sh` consulta `wttr.in` (auto-detección por IP) y muestra:
- Temperatura actual + sensación térmica
- Viento y humedad
- Pronóstico por períodos: 🌙 Night, 🌅 Morning, ☀️ Noon, 🌆 Evening
- Máximas y mínimas de cada día

## Dependencias

- `cava` — visualizador de audio en consola
- `jq` — procesamiento JSON para el script de clima
- `curl` — consulta a wttr.in
- `wiremix` — mezclador de audio (lanzado desde el módulo pulseaudio en `kitty`)
- Font: `JetBrainsMono Nerd Font`

## Instalación

```bash
# Clonar
git clone https://github.com/0evilale/dotfiles-waybar.git /tmp/repo && cp -rf /tmp/repo/. ~/.config/waybar && rm -rf /tmp/repo && omarchy restart waybar

# Instalar dependencias (AUR)
yay -S cava wiremix

# Reiniciar Waybar
omarchy restart waybar
```
