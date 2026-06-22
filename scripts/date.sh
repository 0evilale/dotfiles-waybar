#!/usr/bin/env bash
# Date module for waybar drawer - shows full date
# Hardened: always emits valid JSON, never propagates errors

trap 'exit 0' PIPE
FALLBACK='{"text":" --","tooltip":false}'

# LC_ALL=C fuerza ASCII y evita sorpresas con locales rotos
if ! DATE=$(LC_ALL=C date +"%a %b %d %Y" 2>/dev/null) || [ -z "$DATE" ]; then
    printf '%s\n' "$FALLBACK" 2>/dev/null
    exit 0
fi

printf '{"text":" %s","tooltip":false}\n' "$DATE" 2>/dev/null || printf '%s\n' "$FALLBACK" 2>/dev/null
exit 0
