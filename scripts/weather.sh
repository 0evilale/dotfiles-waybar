#!/usr/bin/env bash
# Custom weather script for Waybar using wttr.in
# Shows 3-day forecast with Morning, Noon, Evening, Night

# No location = wttr.in auto-detects via IP
WEATHER=$(curl -s "wttr.in/?format=j1" 2>/dev/null)

if [ -z "$WEATHER" ]; then
    echo '{"text":"--°", "tooltip":"Error fetching weather", "class":"unknown"}'
    exit 0
fi

# Parse current weather
TEMP=$(echo "$WEATHER" | jq -r '.current_condition[0].temp_C')
FEELS=$(echo "$WEATHER" | jq -r '.current_condition[0].FeelsLikeC')
DESC=$(echo "$WEATHER" | jq -r '.current_condition[0].weatherDesc[0].value')
WIND=$(echo "$WEATHER" | jq -r '.current_condition[0].windspeedKmph')
HUMIDITY=$(echo "$WEATHER" | jq -r '.current_condition[0].humidity')
CODE=$(echo "$WEATHER" | jq -r '.current_condition[0].weatherCode')

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
TOOLTIP="<b>${EMOJI} ${DESC}</b>\n"
TOOLTIP+="━━━━━━━━━━━━━━━━━━━━━━━━\n"
TOOLTIP+="🌡️ ${TEMP}°C  💭 Feels ${FEELS}°C\n"
TOOLTIP+="💨 ${WIND} km/h  💧 ${HUMIDITY}%\n"
TOOLTIP+="━━━━━━━━━━━━━━━━━━━━━━━━\n"

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
        DAY_LABEL=$(date -d "+2 days" +"%A")
    fi
    
    DAY_DATE=$(date -d "+${day} days" +"%Y-%m-%d")
    TOOLTIP+="\n<b>${DAY_LABEL}, ${DAY_DATE}</b>\n"
    
    # Check if this day has data
    DAY_COUNT=$(echo "$WEATHER" | jq ".weather[$day].astronomy | length" 2>/dev/null)
    if [ "$DAY_COUNT" -eq 0 ] 2>/dev/null; then
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
            
            if [ -n "$t" ] && [ "$t" != "null" ]; then
                total=$((total + t))
                count=$((count + 1))
                max_desc="$d"
                max_code="$c"
            fi
        done
        
        if [ $count -gt 0 ]; then
            avg=$((total / count))
            p_emoji=$(get_emoji "$max_code")
            TOOLTIP+="${period_name}  ${p_emoji} ${avg}°C ${max_desc}\n"
        fi
    done
    
    # Add high/low for the day
    HIGH=$(echo "$WEATHER" | jq -r ".weather[$day].maxtempC" 2>/dev/null)
    LOW=$(echo "$WEATHER" | jq -r ".weather[$day].mintempC" 2>/dev/null)
    if [ -n "$HIGH" ] && [ "$HIGH" != "null" ]; then
        TOOLTIP+="  ⬆️ ${HIGH}°  ⬇️ ${LOW}°\n"
    fi
done

# Output JSON
printf '{"text":"%s %s°", "tooltip":"%s", "class":"weather-%s"}\n' "$EMOJI" "$TEMP" "$TOOLTIP" "$CODE"
