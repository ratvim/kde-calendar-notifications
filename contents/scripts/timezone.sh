#!/usr/bin/env bash
# ==============================================================================
# timezone.sh - Timezone detection and provider for KDE Plasma 6
# Detects system timezone via timedatectl / /etc/timezone or target timezone parameter
# ==============================================================================

set -o pipefail

get_system_tz() {
    # 1. timedatectl query
    if command -v timedatectl >/dev/null 2>&1; then
        TZ=$(timedatectl show --property=Timezone --value 2>/dev/null)
        if [ -n "$TZ" ]; then
            echo "$TZ"
            return
        fi
    fi

    # 2. /etc/localtime symlink target
    if [ -L /etc/localtime ]; then
        TZ=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
        if [ -n "$TZ" ]; then
            echo "$TZ"
            return
        fi
    fi

    # 3. /etc/timezone file
    if [ -f /etc/timezone ]; then
        TZ=$(cat /etc/timezone | tr -d '[:space:]')
        if [ -n "$TZ" ]; then
            echo "$TZ"
            return
        fi
    fi

    echo "UTC"
}

case "$1" in
    detect|"")
        TARGET_TZ="$2"
        if [ -n "$TARGET_TZ" ] && [ "$TARGET_TZ" != "Local" ]; then
            TZ="$TARGET_TZ"
            OFFSET=$(TZ="$TARGET_TZ" date +"%:z" 2>/dev/null || date +"%:z")
            ABBR=$(TZ="$TARGET_TZ" date +"%Z" 2>/dev/null || date +"%Z")
        else
            TZ=$(get_system_tz)
            OFFSET=$(date +"%:z")
            ABBR=$(date +"%Z")
        fi
        python3 -c 'import json, sys; print(json.dumps({"timezone": sys.argv[1], "offset": sys.argv[2], "abbr": sys.argv[3]}))' "${TZ}" "${OFFSET}" "${ABBR}" 2>/dev/null || \
            echo "{\"timezone\": \"${TZ}\", \"offset\": \"${OFFSET}\", \"abbr\": \"${ABBR}\"}"
        ;;

    list)
        # Returns a clean JSON array of standard timezones
        cat <<'EOF'
[
  "Local",
  "UTC",
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "America/Toronto",
  "America/Sao_Paulo",
  "Europe/London",
  "Europe/Paris",
  "Europe/Berlin",
  "Europe/Madrid",
  "Europe/Rome",
  "Europe/Moscow",
  "Asia/Dubai",
  "Asia/Kolkata",
  "Asia/Bangkok",
  "Asia/Singapore",
  "Asia/Shanghai",
  "Asia/Tokyo",
  "Asia/Seoul",
  "Australia/Sydney",
  "Pacific/Auckland"
]
EOF
        ;;

    *)
        echo "Usage: $0 [detect [timezone]|list]"
        ;;
esac
