#!/usr/bin/env bash
# Visualizador CAVA para Waybar custom module.
# Imprime JSON line-by-line para que Waybar actualice el módulo en tiempo real.
#
# Diseño robusto:
# - cava corre en background con su PID trackeado (vía $!).
# - Su stdout se redirige a un FIFO que el shell principal lee directamente,
#   evitando subshells de pipe (donde exit/trap no afectan al padre).
# - trap cleanup en EXIT/INT/TERM/PIPE/HUP mata cava y limpia archivos.
# - printf stderr -> /dev/null para no spammear "Broken pipe".
# - Si printf falla (waybar cerró el pipe), salimos limpio vía cleanup.
# - Ante cualquier fallo se emite JSON de fallback (idle/error) y se sale 0.

# Emite JSON de fallback a stdout y sale 0. Para usar en cualquier camino de error.
emit_fallback() {
  printf '{"text":"%s","tooltip":"CAVA audio visualizer","class":"%s"}\n' \
    "$1" "${2:-error}" 2>/dev/null
  exit 0
}

# Devuelve $1 si es entero >0, si no $2. Sanitiza vars de entorno inválidas.
sanitize_uint() {
  if [[ "$1" =~ ^[0-9]+$ ]] && (( $1 > 0 )); then
    printf '%s' "$1"
  else
    printf '%s' "$2"
  fi
}

BARS="$(sanitize_uint "${CAVA_BARS:-12}" 12)"
FRAMERATE="$(sanitize_uint "${CAVA_FRAMERATE:-30}" 30)"
AUTOSENS="$(sanitize_uint "${CAVA_AUTOSENS:-1}" 1)"
SENSITIVITY="$(sanitize_uint "${CAVA_SENSITIVITY:-100}" 100)"
LOW_CUTOFF="$(sanitize_uint "${CAVA_LOW_CUTOFF:-50}" 50)"
HIGH_CUTOFF="$(sanitize_uint "${CAVA_HIGH_CUTOFF:-10000}" 10000)"

LEVELS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" "█")

CONFIG_FILE=""
FIFO_FILE=""
CAVA_PID=""

cleanup() {
  # Prevenir reentrada si otra señal llega durante la limpieza.
  trap '' EXIT INT TERM PIPE HUP USR1 USR2
  if [[ -n "$CAVA_PID" ]]; then
    kill "$CAVA_PID" 2>/dev/null
    wait "$CAVA_PID" 2>/dev/null
  fi
  exec 3>&- 2>/dev/null
  [[ -n "$FIFO_FILE" ]] && rm -f "$FIFO_FILE"
  [[ -n "$CONFIG_FILE" ]] && rm -f "$CONFIG_FILE"
  exit 0
}
trap cleanup EXIT INT TERM PIPE HUP
# Señales raras: ignorar para no corromper estado del script.
trap '' USR1 USR2

# 1. cava debe estar instalado y en PATH.
command -v cava >/dev/null 2>&1 || emit_fallback "♪ sin cava" "idle"

# 2. mktemp para config debe funcionar.
CONFIG_FILE="$(mktemp --tmpdir cava-waybar.XXXXXX 2>/dev/null)" || emit_fallback "mktemp?" "error"

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
  local text="${1//\\/\\\\}"
  text="${text//\"/\\\"}"
  # stderr a /dev/null: si waybar cerró el pipe, no spameamos "Broken pipe".
  printf '{"text":"%s","tooltip":"CAVA audio visualizer","class":"%s"}\n' "$text" "$2" 2>/dev/null
}

# Frame inicial idle (si falla, waybar ya cerró el pipe -> salir limpio).
json_line "♪ ${LEVELS[0]}${LEVELS[0]}${LEVELS[0]}${LEVELS[0]}" "idle" || exit 0

# 2b. FIFO: mktemp -u + mkfifo. Cualquier fallo -> fallback (cleanup vía EXIT trap).
FIFO_FILE="$(mktemp -u --tmpdir cava-waybar.fifo.XXXXXX 2>/dev/null)" || emit_fallback "mktemp?" "error"
mkfifo "$FIFO_FILE" 2>/dev/null || emit_fallback "mkfifo?" "error"

# Pre-abrir el FIFO en RDWR: el open de lectura nunca bloquea, incluso si cava
# muere antes de abrirlo para escritura (race condition evitada).
exec 3<>"$FIFO_FILE" || emit_fallback "fifo?" "error"

# cava escribe al FIFO vía fd 3 en background; capturamos su PID.
cava -p "$CONFIG_FILE" >&3 2>/dev/null &
CAVA_PID=$!

# 3. Si cava muere al arrancar (bin roto, config inválida, audio inaccesible),
# detectarlo tras un breve grace period y salir limpio en vez de colgarse.
# No se consumen datos del FIFO: solo verificamos que el proceso siga vivo.
sleep 0.2
if [[ -n "$CAVA_PID" ]] && ! kill -0 "$CAVA_PID" 2>/dev/null; then
  wait "$CAVA_PID" 2>/dev/null
  CAVA_PID=""
  emit_fallback "cava dead" "error"
fi

# Loop principal: read con timeout. Si cava muere, read timeout retorna !=0;
# verificamos PID para distinguir timeout por cava muerto vs. frame lento.
while :; do
  if ! IFS= read -t 10 -r line <&3; then
    # timeout o EOF: si cava murió, salir; si vive, era frame lento, seguir.
    [[ -n "$CAVA_PID" ]] && kill -0 "$CAVA_PID" 2>/dev/null || break
    continue
  fi
  [[ -z "$line" ]] && continue

  visual=""
  peak=0

  IFS=';' read -ra values <<< "$line"
  for raw in "${values[@]}"; do
    [[ -z "$raw" ]] && continue
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

  # Si printf falla (pipe roto), salir del loop y dejar que cleanup haga el resto.
  json_line "$visual" "$class" || break
done

# cava terminó o el pipe se rompió. Solo reportar error si aún podemos escribir.
json_line "cava?" "error" 2>/dev/null

# cleanup se ejecuta vía trap EXIT al salir.
exit 0
