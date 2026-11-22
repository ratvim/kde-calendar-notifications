#!/usr/bin/env bash
# ==============================================================================
# Helper script to fetch cached weather/temperature data
# ==============================================================================

set -o pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kde_calendar_notifications"
CACHE_FILE="${CACHE_DIR}/weather_cache.json"
CACHE_TTL=900 # 15 minutes
mkdir -p "${CACHE_DIR}"

now=$(date +%s)

if [ -f "$CACHE_FILE" ]; then
    file_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    age=$((now - file_time))
    if [ "$age" -lt "$CACHE_TTL" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Fetch from wttr.in format: "%t|%C|%l" (e.g. "+24°C|Overcast|New Delhi, India")
raw_data=$(curl -s --max-time 3 "https://wttr.in/?format=%t|%C|%l" 2>/dev/null || true)

if [ -n "$raw_data" ] && [[ "$raw_data" == *"|"* ]]; then
    IFS='|' read -r temp cond loc <<< "$raw_data"
    temp=$(echo "$temp" | xargs)
    cond=$(echo "$cond" | xargs)
    loc=$(echo "$loc" | cut -d',' -f1 | xargs)
    
    # Save JSON cache atomically
    TMP_FILE="${CACHE_FILE}.tmp.$$"
    cat <<EOF > "$TMP_FILE"
{
  "temp": "${temp}",
  "condition": "${cond}",
  "location": "${loc}",
  "status": "ok"
}
EOF
    mv -f "$TMP_FILE" "$CACHE_FILE" 2>/dev/null || true
    cat "$CACHE_FILE"
    exit 0
fi

# Fallback if cache exists even if old
if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

# Default fallback
cat <<EOF
{
  "temp": "--°C",
  "condition": "Offline",
  "location": "",
  "status": "offline"
}
EOF
