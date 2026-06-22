#!/usr/bin/env bash
# Custom weather script for Waybar using wttr.in
# Shows 3-day forecast with Morning, Noon, Evening, Night
# Hardened: always emits valid JSON, never propagates errors

trap 'exit 0' PIPE

# fallback: waybar exige JSON válido en stdout ante cualquier fallo
fallback() {
    printf '{"text":"--°","tooltip":"%s","class":"unknown"}\n' "${1:-Weather unavailable}" 2>/dev/null
    exit 0
}

# Dependencias
command -v curl >/dev/null 2>&1 || fallback "curl not installed"
command -v jq   >/dev/null 2>&1 || fallback "jq not installed"

# -f falla en HTTP 4xx/5xx (cubre 429 rate-limit); timeouts evitan colgar waybar
WEATHER=$(curl -s -f --connect-timeout 5 --max-time 10 "wttr.in/?format=j1" 2>/dev/null) || fallback "fetch failed"
[ -n "$WEATHER" ] || fallback "empty response"
# Validar que es JSON parseable y con la estructura esperada
echo "$WEATHER" | jq -e '.current_condition[0].temp_C' >/dev/null 2>&1 || fallback "invalid JSON"

# Escapa " y \ para que campos externos no inyecten/rompan el JSON
json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

# Parse current weather
TEMP=$(echo "$WEATHER" | jq -r '.current_condition[0].temp_C' 2>/dev/null)
FEELS=$(echo "$WEATHER" | jq -r '.current_condition[0].FeelsLikeC' 2>/dev/null)
DESC=$(echo "$WEATHER" | jq -r '.current_condition[0].weatherDesc[0].value' 2>/dev/null)
WIND=$(echo "$WEATHER" | jq -r '.current_condition[0].windspeedKmph' 2>/dev/null)
HUMIDITY=$(echo "$WEATHER" | jq -r '.current_condition[0].humidity' 2>/dev/null)
CODE=$(echo "$WEATHER" | jq -r '.current_condition[0].weatherCode' 2>/dev/null)

# Sanitizar: TEMP/FEELS a "N/A" si no son enteros; CODE numérico para class
[[ "$TEMP"     =~ ^-?[0-9]+$ ]] || TEMP="N/A"
[[ "$FEELS"    =~ ^-?[0-9]+$ ]] || FEELS="N/A"
[[ "$WIND"     =~ ^-?[0-9]+$ ]] || WIND="N/A"
[[ "$HUMIDITY" =~ ^-?[0-9]+$ ]] || HUMIDITY="N/A"
[[ "$CODE"     =~ ^[0-9]+$    ]] || CODE="0"
[ -n "$DESC" ] && [ "$DESC" != "null" ] || DESC="Unknown"
DESC=$(json_escape "$DESC")

# Weather emoji mapping
get_emoji() {
    local code=$1
    case $code in
        113) echo "☀️" ;;
        116) echo "🌤️" ;;
        119|122) echo "☁️" ;;
        143|248|260) echo "🌫️" ;;
        176|263|266|293|296|299|302|305|308|353|356|359) echo "🌧️" ;;
        179|182|185|281|284|311|314|317|350|362|365|368|371|374|377) echo "🌨️" ;;
        200|386|389) echo "⛈️" ;;
        392|395) echo "🌩️" ;;
        *) echo "🌡️" ;;
    esac
}

EMOJI=$(get_emoji "$CODE")

# Build tooltip
TOOLTIP="<b>${EMOJI} ${DESC}</b>\r"
TOOLTIP+="━━━━━━━━━━━━━━━━━━━━━━━━\r"
TOOLTIP+="🌡️ ${TEMP}°C  💭 Feels ${FEELS}°C\r"
TOOLTIP+="💨 ${WIND} km/h  💧 ${HUMIDITY}%\r"
TOOLTIP+="━━━━━━━━━━━━━━━━━━━━━━━━\r"

# Periods: Night (0,1), Morning (2,3), Noon (4,5), Evening (6,7)
PERIODS=("🌙 Night" "🌅 Morning" "☀️ Noon" "🌆 Evening")
PERIOD_INDICES=("0 1" "2 3" "4 5" "6 7")

for day in 0 1 2; do
    # Get day label
    if [ $day -eq 0 ]; then
        DAY_LABEL="Today"
    elif [ $day -eq 1 ]; then
        DAY_LABEL="Tomorrow"
    else
        DAY_LABEL=$(date -d "+2 days" +"%A" 2>/dev/null)
        [ -n "$DAY_LABEL" ] || DAY_LABEL="Day"
    fi

    DAY_DATE=$(date -d "+${day} days" +"%Y-%m-%d" 2>/dev/null)
    [ -n "$DAY_DATE" ] || DAY_DATE=""

    TOOLTIP+="\r<b>${DAY_LABEL}, ${DAY_DATE}</b>\r"

    # Check if this day has data
    DAY_COUNT=$(echo "$WEATHER" | jq ".weather[$day].astronomy | length" 2>/dev/null)
    if ! [[ "$DAY_COUNT" =~ ^[0-9]+$ ]] || [ "$DAY_COUNT" -eq 0 ]; then
        continue
    fi

    for p in 0 1 2 3; do
        period_name="${PERIODS[$p]}"
        indices="${PERIOD_INDICES[$p]}"

        # Get average temp for this period
        total=0
        count=0
        max_desc=""
        max_code=""

        for idx in $indices; do
            t=$(echo "$WEATHER" | jq -r ".weather[$day].hourly[$idx].tempC" 2>/dev/null)
            c=$(echo "$WEATHER" | jq -r ".weather[$day].hourly[$idx].weatherCode" 2>/dev/null)
            d=$(echo "$WEATHER" | jq -r ".weather[$day].hourly[$idx].weatherDesc[0].value" 2>/dev/null)

            # Solo sumar si t es entero válido (evita error aritmético con null/float)
            if [[ "$t" =~ ^-?[0-9]+$ ]]; then
                total=$((total + t))
                count=$((count + 1))
                max_desc="$d"
                max_code="$c"
            fi
        done

        if [ $count -gt 0 ]; then
            avg=$((total / count))
            [ -n "$max_desc" ] && [ "$max_desc" != "null" ] || max_desc="—"
            [ -n "$max_code" ] && [ "$max_code" != "null" ] || max_code="0"
            max_desc=$(json_escape "$max_desc")
            p_emoji=$(get_emoji "$max_code")
            TOOLTIP+="${period_name}  ${p_emoji} ${avg}°C ${max_desc}\r"
        fi
    done

    # Add high/low for the day
    HIGH=$(echo "$WEATHER" | jq -r ".weather[$day].maxtempC" 2>/dev/null)
    LOW=$(echo "$WEATHER" | jq -r ".weather[$day].mintempC" 2>/dev/null)
    if [[ "$HIGH" =~ ^-?[0-9]+$ ]] && [[ "$LOW" =~ ^-?[0-9]+$ ]]; then
        TOOLTIP+="  ⬆️ ${HIGH}°  ⬇️ ${LOW}°\r"
    fi
done

# Output JSON
printf '{"text":"%s %s°", "tooltip":"%s", "class":"weather-%s"}\n' "$EMOJI" "$TEMP" "$TOOLTIP" "$CODE" 2>/dev/null || fallback "output failed"
exit 0
