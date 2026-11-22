#!/usr/bin/env bash
# ==============================================================================
# notifications.sh - Notification backend for KDE Plasma 6 Calendar & Notification Center
# Manages notification state with zero mock/dummy data.
# ==============================================================================

set -o pipefail

# Clean up duplicate plugin directory to prevent protected module collision
rm -rf "${HOME}/.local/share/plasma/plasmoids/org.kde.plasma.calendarnotifications/contents/ui/plugin" 2>/dev/null || true
rm -rf "/mnt/MyApplication/kde_calendar_notifications/contents/ui/plugin" 2>/dev/null || true

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kde_calendar_notifications"
STORE_FILE="${CACHE_DIR}/notifications.json"
mkdir -p "${CACHE_DIR}"
chmod 700 "${CACHE_DIR}" 2>/dev/null || true

# Initialize empty store if file does not exist
if [ ! -f "${STORE_FILE}" ]; then
    echo "[]" > "${STORE_FILE}"
fi

case "$1" in
    list|"")
        if [ ! -s "${STORE_FILE}" ]; then
            echo "[]"
        else
            cat "${STORE_FILE}"
        fi
        ;;

    add)
        # Allows appending a real notification: add <app> <summary> <body> [icon] [id]
        APP="$2"
        SUMMARY="$3"
        BODY="$4"
        ICON="${5:-preferences-system}"
        NID="${6:-$(date +%s)}"
        TIME_STR="$(date +%H:%M)"

        if [ -n "$SUMMARY" ]; then
            python3 -c '
import json, sys, os, tempfile

store_file = sys.argv[1]
app = sys.argv[2]
summary = sys.argv[3]
body = sys.argv[4]
icon = sys.argv[5]
nid = sys.argv[6]
time_str = sys.argv[7]

data = []
if os.path.exists(store_file):
    try:
        with open(store_file, "r", encoding="utf-8") as f:
            data = json.load(f)
            if not isinstance(data, list):
                data = []
    except Exception:
        data = []

new_notif = {
    "id": nid,
    "app": app or "System",
    "appIcon": icon or "preferences-system",
    "desktopEntry": app or "",
    "summary": summary,
    "body": body,
    "time": time_str,
    "actions": ["Dismiss"]
}

data.insert(0, new_notif)

temp_dir = os.path.dirname(store_file)
with tempfile.NamedTemporaryFile("w", dir=temp_dir, delete=False, encoding="utf-8") as tf:
    json.dump(data, tf, indent=2)
    temp_path = tf.name

os.replace(temp_path, store_file)
' "${STORE_FILE}" "$APP" "$SUMMARY" "$BODY" "$ICON" "$NID" "$TIME_STR" 2>/dev/null || true
        fi
        cat "${STORE_FILE}"
        ;;

    dismiss)
        TARGET_ID="$2"
        if [ -n "$TARGET_ID" ] && [ -f "${STORE_FILE}" ]; then
            python3 -c '
import json, sys, os, tempfile

store_file = sys.argv[1]
target_id = str(sys.argv[2]).strip()

try:
    with open(store_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        data = [n for n in data if str(n.get("id", "")).strip() != target_id]
        dir_name = os.path.dirname(store_file)
        with tempfile.NamedTemporaryFile("w", dir=dir_name, delete=False, encoding="utf-8") as tf:
            json.dump(data, tf, indent=2)
            temp_path = tf.name
        os.replace(temp_path, store_file)
except Exception:
    pass
' "${STORE_FILE}" "$TARGET_ID" 2>/dev/null || true
        fi
        cat "${STORE_FILE}"
        ;;

    dismiss_group)
        TARGET_APP="$2"
        if [ -n "$TARGET_APP" ] && [ -f "${STORE_FILE}" ]; then
            python3 -c '
import json, sys, os, tempfile

store_file = sys.argv[1]
target_app = str(sys.argv[2]).strip().lower()

try:
    with open(store_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        data = [n for n in data if str(n.get("app", "")).strip().lower() != target_app]
        dir_name = os.path.dirname(store_file)
        with tempfile.NamedTemporaryFile("w", dir=dir_name, delete=False, encoding="utf-8") as tf:
            json.dump(data, tf, indent=2)
            temp_path = tf.name
        os.replace(temp_path, store_file)
except Exception:
    pass
' "${STORE_FILE}" "$TARGET_APP" 2>/dev/null || true
        fi
        cat "${STORE_FILE}"
        ;;

    clear_all|reset)
        echo "[]" > "${STORE_FILE}"
        echo "[]"
        ;;

    open_app)
        RAW_DESKTOP="${2:-}"
        RAW_APP="${3:-}"

        python3 -c '
import os, sys, glob, re, subprocess, shutil

desktop_raw = sys.argv[1].strip() if len(sys.argv) > 1 else ""
app_name_raw = sys.argv[2].strip() if len(sys.argv) > 2 else ""

GENERIC_TERMS = {
    "app", "apps", "daemon", "service", "helper", "system", "desktop",
    "org", "com", "net", "io", "kde", "wayland", "x11", "bin", "client",
    "gui", "ui", "kcm", "window", "settings", "preferences", "default", "tool"
}

def is_generic(term):
    if not term or len(term) < 3:
        return True
    return term.lower() in GENERIC_TERMS

lower_entry = desktop_raw.lower()
lower_name = app_name_raw.lower()
is_kdeconnect = ("kdeconnect" in lower_entry or "kdeconnect" in lower_name or "kde connect" in lower_name)
is_sms = is_kdeconnect and ("sms" in lower_entry or "sms" in lower_name or "message" in lower_name or "text" in lower_name)

# 1. Try focusing existing window via KWin WindowsRunner (D-Bus)
def try_focus_window(search_terms):
    qdbus = shutil.which("qdbus6") or shutil.which("qdbus")
    if not qdbus:
        return False
    for term in search_terms:
        if not term or len(term) < 3 or is_generic(term):
            continue
        try:
            res = subprocess.run([qdbus, "--literal", "org.kde.KWin", "/WindowsRunner", "org.kde.krunner1.Match", term],
                                 capture_output=True, text=True, timeout=1.2)
            lines = res.stdout
            matches = re.findall(r"\(\s*\"(0_\{[a-zA-Z0-9_\-]+\})\"\s*,\s*\"([^\"]+)\"", lines)
            term_lower = term.lower()
            for win_id, win_title in matches:
                title_lower = win_title.lower()
                if term_lower in title_lower or any(word in title_lower for word in term_lower.split() if len(word) >= 4 and not is_generic(word)):
                    subprocess.run([qdbus, "org.kde.KWin", "/WindowsRunner", "org.kde.krunner1.Run", win_id, ""],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.2)
                    return True
        except Exception:
            pass
    return False

# 2. Resolve displayable .desktop file
def find_desktop_file(entry, name):
    app_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/local/share/applications",
        "/usr/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
    ]

    clean_entry = entry.replace(".desktop", "").strip()
    clean_name = name.strip()
    c_lower_entry = clean_entry.lower()
    c_lower_name = clean_name.lower()

    is_kdc = ("kdeconnect" in c_lower_entry or "kdeconnect" in c_lower_name or "kde connect" in c_lower_name)
    is_kdc_sms = is_kdc and ("sms" in c_lower_entry or "sms" in c_lower_name or "message" in c_lower_name or "text" in c_lower_name)

    if is_kdc:
        if is_kdc_sms:
            for direct_path in [
                "/usr/share/applications/org.kde.kdeconnect.sms.desktop",
                os.path.expanduser("~/.local/share/applications/org.kde.kdeconnect.sms.desktop"),
                "/usr/share/applications/kdeconnect-sms.desktop"
            ]:
                if os.path.isfile(direct_path):
                    return direct_path
        else:
            for direct_path in [
                "/usr/share/applications/org.kde.kdeconnect.app.desktop",
                os.path.expanduser("~/.local/share/applications/org.kde.kdeconnect.app.desktop"),
                "/usr/share/applications/kdeconnect-app.desktop"
            ]:
                if os.path.isfile(direct_path):
                    return direct_path

    # Build targeted candidate names for non-KDE Connect
    candidates = []
    if clean_entry and not is_generic(clean_entry):
        candidates.append(clean_entry)
        short = clean_entry.split(".")[-1]
        if short != clean_entry and not is_generic(short) and len(short) >= 4:
            candidates.append(short)
            candidates.append(f"org.kde.{short}")
        candidates.append(f"org.kde.{clean_entry}")

    if clean_name and not is_generic(clean_name) and len(clean_name) >= 3:
        c_slug = clean_name.lower().replace(" ", "-")
        c_compact = clean_name.lower().replace(" ", "")
        if not is_generic(c_slug):
            candidates.append(c_slug)
        if not is_generic(c_compact):
            candidates.append(c_compact)
            candidates.append(f"org.kde.{c_compact}")

    displayable = []
    no_display = []

    # Direct candidate matching
    for d in app_dirs:
        if not os.path.isdir(d):
            continue
        for c in candidates:
            if not c or is_generic(c):
                continue
            path = os.path.join(d, c if c.endswith(".desktop") else f"{c}.desktop")
            if os.path.isfile(path):
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        txt = f.read()
                        if "NoDisplay=true" not in txt:
                            displayable.append(path)
                        else:
                            no_display.append(path)
                except Exception:
                    pass

    if displayable:
        return displayable[0]

    # Bounded glob ONLY for specific, non-generic candidates with length >= 5
    for d in app_dirs:
        if not os.path.isdir(d):
            continue
        for c in candidates:
            if not c or is_generic(c) or len(c) < 5:
                continue
            for path in glob.glob(os.path.join(d, f"*{c}*.desktop")):
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        txt = f.read()
                        if "NoDisplay=true" not in txt:
                            return path
                except Exception:
                    pass

    if is_kdc:
        fallback_kdc = "/usr/share/applications/org.kde.kdeconnect.app.desktop"
        if os.path.isfile(fallback_kdc):
            return fallback_kdc

    if no_display:
        return no_display[0]

    return None

# 3. Launch the application
def launch_app(desktop_file, fallback_terms):
    if desktop_file and os.path.isfile(desktop_file):
        app_id = os.path.basename(desktop_file)
        if app_id.endswith(".desktop"):
            app_id = app_id[:-8]

        # 1. Try gtk-launch
        if shutil.which("gtk-launch"):
            try:
                subprocess.Popen(["gtk-launch", app_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                return True
            except Exception:
                pass

        # 2. Try gio launch
        if shutil.which("gio"):
            try:
                subprocess.Popen(["gio", "launch", desktop_file], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                return True
            except Exception:
                pass

        # 3. Try kstart6 / kstart5
        kstart = shutil.which("kstart6") or shutil.which("kstart5")
        if kstart:
            try:
                subprocess.Popen([kstart, "--desktop", app_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                return True
            except Exception:
                pass

        # 4. Fallback to parsing Exec= from desktop file
        try:
            with open(desktop_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if line.startswith("Exec="):
                        cmd = line.split("=", 1)[1].strip()
                        cmd = re.sub(r"%[a-zA-Z]", "", cmd).strip()
                        if cmd:
                            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                            return True
        except Exception:
            pass

    # 5. Fallback: try executing matching binary in PATH
    for term in fallback_terms:
        if not term or is_generic(term) or len(term) < 4:
            continue
        bin_path = shutil.which(term)
        if bin_path:
            try:
                subprocess.Popen([bin_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                return True
            except Exception:
                pass

    return False

# Build search terms for window focusing
search_terms = []
if is_kdeconnect:
    if is_sms:
        search_terms = ["KDE Connect SMS", "kdeconnect-sms", "org.kde.kdeconnect.sms"]
    else:
        search_terms = ["KDE Connect", "kdeconnect-app", "org.kde.kdeconnect.app"]
else:
    if app_name_raw and not is_generic(app_name_raw) and len(app_name_raw) >= 3:
        search_terms.append(app_name_raw)
    if desktop_raw:
        clean_d = desktop_raw.replace(".desktop", "").strip()
        if not is_generic(clean_d):
            search_terms.append(clean_d)
        short = clean_d.split(".")[-1]
        if short != clean_d and not is_generic(short) and len(short) >= 4:
            search_terms.append(short)

# Try focusing existing window first
if try_focus_window(search_terms):
    sys.exit(0)

# Resolve and launch desktop application
dt_file = find_desktop_file(desktop_raw, app_name_raw)
fallbacks = []
if is_kdeconnect:
    if is_sms:
        fallbacks = ["kdeconnect-sms"]
    else:
        fallbacks = ["kdeconnect-app"]
else:
    if desktop_raw:
        clean_d = desktop_raw.replace(".desktop", "").strip()
        if not is_generic(clean_d):
            fallbacks.append(clean_d)
    if app_name_raw and not is_generic(app_name_raw):
        fallbacks.append(app_name_raw.lower().replace(" ", "-"))

launch_app(dt_file, fallbacks)
' "$RAW_DESKTOP" "$RAW_APP"
        ;;

    *)
        echo "Usage: $0 [list|add <app> <summary> <body> [icon] [id]|dismiss <id>|dismiss_group <app>|clear_all|open_app <app>|reset]"
        ;;
esac
