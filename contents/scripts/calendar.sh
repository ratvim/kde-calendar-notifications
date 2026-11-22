#!/usr/bin/env bash
# ==============================================================================
# calendar.sh - Real Calendar Events, Agenda & Online Accounts Provider for KDE Plasma 6
# Provides real national holidays, persists actual user agenda appointments,
# and synchronizes with KDE Online Accounts (kaccounts).
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clean up duplicate plugin directory to prevent protected module collision
rm -rf "${HOME}/.local/share/plasma/plasmoids/org.kde.plasma.calendarnotifications/contents/ui/plugin" 2>/dev/null || true
rm -rf "/mnt/MyApplication/kde_calendar_notifications/contents/ui/plugin" 2>/dev/null || true

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma_calendar"
USER_EVENTS_FILE="${DATA_DIR}/user_events.json"
mkdir -p "${DATA_DIR}"

# Initialize user events file if not present
if [ ! -f "${USER_EVENTS_FILE}" ]; then
    echo "[]" > "${USER_EVENTS_FILE}"
fi

case "$1" in
    list|"")
        python3 -c '
import json, os, sys, datetime, glob

data_dir = sys.argv[1]
user_events_file = os.path.join(data_dir, "user_events.json")

# Real Public & National Holidays for Year (Gazetted, National, and Major Observances)
def get_real_holidays(year):
    holidays = [
        {"day": 1, "month": 1, "title": "New Year'\''s Day", "category": "holiday", "color": "#3584e4"},
        {"day": 26, "month": 1, "title": "Republic Day", "category": "national_holiday", "color": "#e01b24"},
        {"day": 15, "month": 2, "title": "Maha Shivratri", "category": "observance", "color": "#e5a50a"},
        {"day": 4, "month": 3, "title": "Holi (Festival of Colours)", "category": "festival", "color": "#9141ac"},
        {"day": 20, "month": 3, "title": "Eid-ul-Fitr", "category": "public_holiday", "color": "#33d17a"},
        {"day": 3, "month": 4, "title": "Good Friday", "category": "public_holiday", "color": "#3584e4"},
        {"day": 14, "month": 4, "title": "Dr. Ambedkar Jayanti / Vaisakhi", "category": "public_holiday", "color": "#3584e4"},
        {"day": 1, "month": 5, "title": "International Labour Day / May Day", "category": "observance", "color": "#e01b24"},
        {"day": 27, "month": 5, "title": "Eid-ul-Adha (Bakrid)", "category": "public_holiday", "color": "#33d17a"},
        {"day": 15, "month": 8, "title": "Independence Day", "category": "national_holiday", "color": "#e01b24"},
        {"day": 28, "month": 8, "title": "Raksha Bandhan", "category": "observance", "color": "#e5a50a"},
        {"day": 4, "month": 9, "title": "Janmashtami", "category": "festival", "color": "#e5a50a"},
        {"day": 2, "month": 10, "title": "Mahatma Gandhi Jayanti", "category": "national_holiday", "color": "#e01b24"},
        {"day": 20, "month": 10, "title": "Dussehra (Vijayadashami)", "category": "national_holiday", "color": "#e5a50a"},
        {"day": 8, "month": 11, "title": "Diwali (Deepavali)", "category": "festival", "color": "#e5a50a"},
        {"day": 10, "month": 11, "title": "Govardhan Puja / Bhai Dooj", "category": "festival", "color": "#e5a50a"},
        {"day": 24, "month": 11, "title": "Guru Nanak Jayanti", "category": "public_holiday", "color": "#3584e4"},
        {"day": 25, "month": 12, "title": "Christmas Day", "category": "public_holiday", "color": "#e01b24"}
    ]
    
    result = []
    for h in holidays:
        m_val = h.get("month", 1)
        d_val = h.get("day", 1)
        result.append({
            "id": "h_" + str(year) + "_" + str(m_val) + "_" + str(d_val),
            "year": int(year),
            "month": int(m_val),
            "day": int(d_val),
            "title": h.get("title", "Holiday"),
            "time": "All Day",
            "category": h.get("category", "holiday"),
            "color": h.get("color", "#3584e4"),
            "location": "Public Holiday",
            "isHoliday": True
        })
    return result

current_year = datetime.datetime.now().year

# Combine holidays for current, previous, and next year with user saved events
all_events = []
for yr in [current_year - 1, current_year, current_year + 1]:
    all_events.extend(get_real_holidays(yr))

# Load actual user appointments & reminders
if os.path.exists(user_events_file):
    try:
        with open(user_events_file, "r") as f:
            user_data = json.load(f)
            if isinstance(user_data, list):
                all_events.extend(user_data)
    except Exception:
        pass

# Load synced events from active online calendar accounts
accounts_file = os.path.join(data_dir, "calendar_accounts.json")
enabled_account_ids = set()
if os.path.exists(accounts_file):
    try:
        with open(accounts_file, "r") as f:
            acc_list = json.load(f)
            if isinstance(acc_list, list):
                for acc in acc_list:
                    if acc.get("enabled", True):
                        enabled_account_ids.add(str(acc.get("id")))
    except Exception:
        pass

pattern = os.path.join(data_dir, "online_events_*.json")
for o_path in glob.glob(pattern):
    filename = os.path.basename(o_path)
    acc_id = filename.replace("online_events_", "").replace(".json", "")
    if acc_id in enabled_account_ids or not os.path.exists(accounts_file):
        try:
            with open(o_path, "r") as f:
                online_data = json.load(f)
                if isinstance(online_data, list):
                    all_events.extend(online_data)
        except Exception:
            pass

print(json.dumps(all_events))
' "${DATA_DIR}"
        ;;

    add)
        TITLE="$2"
        DAY="$3"
        MONTH="$4"
        YEAR="$5"
        TIME="${6:-All Day}"

        if [ -n "$TITLE" ]; then
            python3 -c '
import json, os, sys, time, tempfile

user_events_file = sys.argv[1]
title = sys.argv[2]
day = int(sys.argv[3])
month = int(sys.argv[4])
year = int(sys.argv[5])
time_str = sys.argv[6]

data = []
if os.path.exists(user_events_file):
    try:
        with open(user_events_file, "r") as f:
            data = json.load(f)
            if not isinstance(data, list):
                data = []
    except Exception:
        data = []

new_item = {
    "id": "user_" + str(int(time.time() * 1000)),
    "title": title,
    "day": day,
    "month": month,
    "year": year,
    "time": time_str,
    "category": "personal",
    "color": "#3584e4",
    "location": "User Agenda",
    "isHoliday": False
}

data.append(new_item)

temp_dir = os.path.dirname(user_events_file)
with tempfile.NamedTemporaryFile("w", dir=temp_dir, delete=False) as tf:
    json.dump(data, tf, indent=2)
    temp_path = tf.name

os.replace(temp_path, user_events_file)
' "${USER_EVENTS_FILE}" "$TITLE" "$DAY" "$MONTH" "$YEAR" "$TIME" 2>/dev/null || true
        fi

        "$0" list
        ;;

    delete)
        TARGET_ID="$2"
        if [ -n "$TARGET_ID" ]; then
            python3 -c '
import json, os, sys, tempfile, glob

user_events_file = sys.argv[1]
target_id = sys.argv[2]
data_dir = os.path.dirname(user_events_file)

if os.path.exists(user_events_file):
    try:
        with open(user_events_file, "r") as f:
            data = json.load(f)
        if isinstance(data, list):
            data = [e for e in data if str(e.get("id")) != str(target_id)]
            temp_dir = os.path.dirname(user_events_file)
            with tempfile.NamedTemporaryFile("w", dir=temp_dir, delete=False) as tf:
                json.dump(data, tf, indent=2)
                temp_path = tf.name
            os.replace(temp_path, user_events_file)
    except Exception:
        pass

# Also remove from online events if matching
for o_path in glob.glob(os.path.join(data_dir, "online_events_*.json")):
    try:
        with open(o_path, "r") as f:
            o_data = json.load(f)
        if isinstance(o_data, list):
            new_o = [e for e in o_data if str(e.get("id")) != str(target_id)]
            if len(new_o) != len(o_data):
                with open(o_path, "w") as f:
                    json.dump(new_o, f, indent=2)
    except Exception:
        pass
' "${USER_EVENTS_FILE}" "$TARGET_ID" 2>/dev/null || true
        fi

        "$0" list
        ;;

    clear_user_events)
        echo "[]" > "${USER_EVENTS_FILE}"
        "$0" list
        ;;

    accounts)
        python3 "${SCRIPT_DIR}/calendar_sync.py" list
        ;;

    add_account)
        NAME="$2"
        PROVIDER="$3"
        URL="$4"
        COLOR="$5"
        USERNAME="$6"
        PASSWORD="$7"
        python3 "${SCRIPT_DIR}/calendar_sync.py" add "$NAME" "$PROVIDER" "$URL" "$COLOR" "$USERNAME" "$PASSWORD"
        ;;

    update_account)
        ACC_ID="$2"
        NAME="$3"
        URL="$4"
        COLOR="$5"
        ENABLED="$6"
        USERNAME="$7"
        PASSWORD="$8"
        python3 "${SCRIPT_DIR}/calendar_sync.py" update "$ACC_ID" "$NAME" "$URL" "$COLOR" "$ENABLED" "$USERNAME" "$PASSWORD"
        ;;

    delete_account)
        ACC_ID="$2"
        python3 "${SCRIPT_DIR}/calendar_sync.py" delete "$ACC_ID"
        ;;

    sync)
        ACCOUNT_ID="$2"
        if [ -n "$ACCOUNT_ID" ]; then
            python3 "${SCRIPT_DIR}/calendar_sync.py" sync "${ACCOUNT_ID}"
        else
            python3 "${SCRIPT_DIR}/calendar_sync.py" sync_all
        fi
        ;;

    sync_all)
        python3 "${SCRIPT_DIR}/calendar_sync.py" sync_all
        ;;

    sync_status)
        python3 "${SCRIPT_DIR}/calendar_sync.py" status
        ;;

    *)
        echo "Usage: $0 [list|add <title> <day> <month> <year> [time]|delete <id>|clear_user_events|accounts|add_account|update_account|delete_account|sync [id]|sync_all|sync_status]"
        ;;
esac
