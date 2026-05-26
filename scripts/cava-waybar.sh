#!/usr/bin/env bash
# Visualizador CAVA para Waybar custom module.
# Imprime JSON line-by-line para que Waybar actualice el módulo en tiempo real.

set -o pipefail

BARS="${CAVA_BARS:-12}"
FRAMERATE="${CAVA_FRAMERATE:-30}"
AUTOSENS="${CAVA_AUTOSENS:-1}"
SENSITIVITY="${CAVA_SENSITIVITY:-100}"
LOW_CUTOFF="${CAVA_LOW_CUTOFF:-50}"
HIGH_CUTOFF="${CAVA_HIGH_CUTOFF:-10000}"

# Iconos de nivel: 0..8. Nivel 0 queda bajo para que se vea vivo sin ocupar mucho.
LEVELS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" "█")

CONFIG_FILE="$(mktemp --tmpdir cava-waybar.XXXXXX)"
cleanup() {
  rm -f "$CONFIG_FILE"
}
trap cleanup EXIT INT TERM

cat > "$CONFIG_FILE" <<EOF
[general]
bars = $BARS
framerate = $FRAMERATE
autosens = $AUTOSENS
sensitivity = $SENSITIVITY
lower_cutoff_freq = $LOW_CUTOFF
higher_cutoff_freq = $HIGH_CUTOFF

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 8
bar_delimiter = 59
EOF

json_line() {
  local text="$1"
  local class="$2"
  # El texto solo usa glyphs seguros; de todos modos escapamos por higiene mínima.
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  printf '{"text":"%s","tooltip":"CAVA audio visualizer","class":"%s"}\n' "$text" "$class"
}

# Mensaje inicial para evitar que Waybar muestre el módulo vacío mientras arranca CAVA.
json_line "♪ ${LEVELS[0]}${LEVELS[0]}${LEVELS[0]}${LEVELS[0]}" "idle"

# CAVA emite líneas tipo: 0;1;3;8;... Convertimos cada número a bloques Unicode.
cava -p "$CONFIG_FILE" 2>/dev/null | while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  visual=""
  peak=0

  IFS=';' read -ra values <<< "$line"
  for raw in "${values[@]}"; do
    [[ -z "$raw" ]] && continue
    # Mantener solo dígitos por si CAVA mete caracteres raros.
    value="${raw//[^0-9]/}"
    [[ -z "$value" ]] && value=0
    (( value > 8 )) && value=8
    (( value > peak )) && peak=$value
    visual+="${LEVELS[$value]}"
  done

  [[ -z "$visual" ]] && visual="${LEVELS[0]}${LEVELS[0]}${LEVELS[0]}${LEVELS[0]}"

  if (( peak <= 1 )); then
    class="idle"
  elif (( peak >= 7 )); then
    class="loud"
  else
    class="active"
  fi

  json_line "$visual" "$class"
done

# Si CAVA falla, deja una pista visible en vez de morir silenciosamente.
json_line "cava?" "error"
exit 1
