#!/bin/bash
# Genera ~/.config/waybar/colors.css desde el colors.toml del tema Omarchy activo.
# Recibe el nombre del tema como $1 (snake-cased, ej: "aamis", "catppuccin").

THEME_NAME="${1:-aamis}"
WAYBAR_DIR="${HOME}/.config/waybar"
THEME_DIR="${HOME}/.config/omarchy/themes/${THEME_NAME}"
COLORS_TOML="${THEME_DIR}/colors.toml"
OUT_CSS="${WAYBAR_DIR}/colors.css"

# Fallback a ~/.local/share/omarchy/themes/<theme>/colors.toml
if [[ ! -f "$COLORS_TOML" ]]; then
    THEME_DIR="${HOME}/.local/share/omarchy/themes/${THEME_NAME}"
    COLORS_TOML="${THEME_DIR}/colors.toml"
fi

if [[ ! -f "$COLORS_TOML" ]]; then
    echo "No colors.toml found for theme '${THEME_NAME}'" >&2
    exit 1
fi

# Lee un valor del TOML simple: key = "#rrggbb"
get_color() {
    local key="$1"
    grep -E "^${key}\s*=" "$COLORS_TOML" 2>/dev/null | head -1 | sed -E 's/^[^"]*"([^"]*)".*/\1/'
}

hex_to_rgba() {
    local hex="$1" alpha="${2:-1.0}"
    hex="${hex#\#}"
    printf 'rgba(%d, %d, %d, %s)' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}" "$alpha"
}

accent=$(get_color accent)
cursor=$(get_color cursor)
foreground=$(get_color foreground)
background=$(get_color background)
selection_fg=$(get_color selection_foreground)
selection_bg=$(get_color selection_background)

c0=$(get_color color0);  c1=$(get_color color1);  c2=$(get_color color2);  c3=$(get_color color3)
c4=$(get_color color4);  c5=$(get_color color5);  c6=$(get_color color6);  c7=$(get_color color7)
c8=$(get_color color8);  c9=$(get_color color9); c10=$(get_color color10); c11=$(get_color color11)
c12=$(get_color color12); c13=$(get_color color13); c14=$(get_color color14); c15=$(get_color color15)

# Fallbacks
: "${accent:=${c4}}" "${foreground:=${c7}}" "${background:=${c0}}"
: "${selection_bg:=${accent}}" "${selection_fg:=${background}}"

# Transparencia de la barra y los módulos. Ajusta estos valores si quieres más/menos transparente.
BAR_ALPHA="0.55"
MODULE_ALPHA="0.70"

bg_panel=$(hex_to_rgba "${c0}" "$MODULE_ALPHA")
bg_bar=$(hex_to_rgba "${c0}" "$BAR_ALPHA")

cat > "$OUT_CSS" <<EOF
/* Auto-generated from ${COLORS_TOML} */
/* Do not edit manually — it will be overwritten on theme change. */

@define-color background ${background};
@define-color foreground ${foreground};
@define-color accent ${accent};
@define-color selection-bg ${selection_bg};
@define-color selection-fg ${selection_fg};

/* Legacy aliases used by ~/.config/waybar/style.css */
@define-color background1 ${bg_panel};
@define-color background2 ${bg_bar};
@define-color sepepator ${c8};
@define-color sepepator-transparent transparent;

/* Semantic aliases for modules */
@define-color bg-dark ${c0};
@define-color bg-mid ${c8};
@define-color bg-panel ${bg_panel};
@define-color text ${foreground};
@define-color text-muted ${c8};
@define-color warning ${c1};
@define-color caution ${c8};
@define-color performance ${c4};
@define-color audio ${c6};
@define-color misc ${c5};
@define-color date ${c3};
@define-color work ${c5};
@define-color window ${c5};
@define-color resize ${c1};
@define-color process ${c4};
@define-color separator ${c8};
@define-color arch-blue #1793d1;
EOF

echo "Generated ${OUT_CSS} from ${THEME_NAME}"
