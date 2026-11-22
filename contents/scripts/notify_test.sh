#!/usr/bin/env bash
# ==============================================================================
# Helper script to send sample notifications for testing the widget
# ==============================================================================

set -o pipefail

TYPE="${1:-all}"

send_chrome() {
    notify-send -a "Google Chrome" -i "google-chrome" \
        "GitHub • Pull Request #42" \
        "Review requested on kde_calendar_notifications: Feature: unified side-by-side popup"
}

send_telegram() {
    notify-send -a "Telegram" -i "telegram" \
        "Plasma Design Team" \
        "Hey! Are we still meeting at 4:30 PM for the Plasma 6 widget demo?"
}

send_system() {
    notify-send -a "System" -i "preferences-system-updates" \
        "System Updates Available" \
        "3 security and package updates are ready to be installed."
}

case "$TYPE" in
    chrome)
        send_chrome
        ;;
    telegram)
        send_telegram
        ;;
    system)
        send_system
        ;;
    all|*)
        send_chrome
        sleep 0.3
        send_telegram
        sleep 0.3
        send_system
        ;;
esac

echo "Sent sample notifications ($TYPE)"
