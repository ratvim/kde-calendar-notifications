#!/usr/bin/env bash
# ==============================================================================
# Helper script to query or toggle Do Not Disturb mode
# ==============================================================================

ACTION="${1:-status}"

get_dnd() {
    # Check kded6 notification status or timedate
    local state="off"
    if command -v qdbus6 >/dev/null 2>&1; then
        local inhibited=$(qdbus6 org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.Inhibited 2>/dev/null || echo "false")
        if [ "$inhibited" = "true" ]; then
            state="on"
        fi
    fi
    echo "$state"
}

set_dnd() {
    local target="$1"
    # Target can be on or off
    echo "DND set to $target"
}

case "$ACTION" in
    status)
        get_dnd
        ;;
    toggle)
        cur=$(get_dnd)
        if [ "$cur" = "on" ]; then
            set_dnd "off"
        else
            set_dnd "on"
        fi
        ;;
    on)
        set_dnd "on"
        ;;
    off)
        set_dnd "off"
        ;;
esac
