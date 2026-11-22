#!/usr/bin/env python3
"""
calendar_sync.py - Direct Online Calendar Synchronizer for KDE Plasma 6 Calendar & Notification Center.
Directly syncs Google Calendar, Microsoft Outlook, Nextcloud, Apple iCloud, and any standard iCal/ICS/Webcal feed.
Zero external dependencies (pure Python 3 standard library).
"""

import os
import sys
import json
import time
import re
import base64
import urllib.request
import urllib.error
import ssl
import datetime
from datetime import timedelta

DATA_DIR = os.path.expanduser(os.environ.get("XDG_DATA_HOME", "~/.local/share") + "/plasma_calendar")
ACCOUNTS_FILE = os.path.join(DATA_DIR, "calendar_accounts.json")
SYNC_STATUS_FILE = os.path.join(DATA_DIR, "sync_status.json")
LOG_FILE = os.path.join(DATA_DIR, "calendar_sync.log")

def log(msg):
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8", errors="ignore") as f:
            f.write(f"[{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except Exception:
        pass

def get_accounts():
    os.makedirs(DATA_DIR, exist_ok=True)
    if not os.path.exists(ACCOUNTS_FILE):
        return []
    try:
        with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception as e:
        log(f"Error reading accounts: {e}")
        return []

def save_accounts(accounts):
    os.makedirs(DATA_DIR, exist_ok=True)
    temp_file = ACCOUNTS_FILE + ".tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(accounts, f, indent=2, ensure_ascii=False)
    os.replace(temp_file, ACCOUNTS_FILE)

def sanitize_url(raw_url):
    u = (raw_url or "").strip()
    if u.startswith("webcal://"):
        u = "https://" + u[9:]
    elif u.startswith("webcals://"):
        u = "https://" + u[10:]
    return u

def fetch_ics_data(url, username="", password="", timeout=12):
    clean_url = sanitize_url(url)
    if not clean_url:
        raise ValueError("Calendar URL is empty.")

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; KDE-Plasma-CalendarSync/1.2; +https://kde.org)",
        "Accept": "text/calendar, text/plain, */*"
    }

    if username or password:
        user_pass = f"{username}:{password}".encode("utf-8")
        b64_auth = base64.b64encode(user_pass).decode("ascii")
        headers["Authorization"] = f"Basic {b64_auth}"

    req = urllib.request.Request(clean_url, headers=headers)

    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
        charset = resp.headers.get_content_charset() or "utf-8"
        raw_bytes = resp.read()
        text = raw_bytes.decode(charset, errors="replace")

        # Validate that the response is actually an iCalendar payload, not an HTML page
        if "<html" in text.lower() or "<!doctype html" in text.lower():
            if "google" in clean_url.lower():
                raise ValueError("URL returned a Google web page. In Google Calendar Web, go to Settings > [Calendar] > Integrate calendar > copy 'Secret address in iCal format'.")
            if "outlook" in clean_url.lower():
                raise ValueError("URL returned an Outlook web page. In Outlook Web, go to Settings > Calendar > Shared calendars > Publish a calendar > copy 'ICS' link.")
            raise ValueError("URL returned an HTML web page instead of calendar events (.ics). If using Nextcloud/CalDAV, enter your credentials or verify the private .ics link.")

        if "BEGIN:VCALENDAR" not in text and "BEGIN:VEVENT" not in text:
            raise ValueError("Data does not contain valid iCalendar events (missing BEGIN:VCALENDAR).")

        return text

def unfold_ics(text):
    """Unfold RFC 5545 folded lines (lines starting with space or tab)."""
    return re.sub(r'\r?\n[ \t]', '', text)

def unescape_ics_text(val):
    if not val:
        return ""
    val = val.replace(r'\,', ',').replace(r'\;', ';').replace(r'\\', '\\')
    val = re.sub(r'\\[nN]', ' ', val)
    return val.strip()

def parse_ics_datetime(dt_str):
    """
    Parses ICS DTSTART / DTEND strings:
    - 20261031 (all-day date)
    - 20261031T143000Z (UTC datetime)
    - 20261031T143000 (local datetime)
    Returns: (datetime_obj, is_all_day)
    """
    dt_str = dt_str.strip()
    # Strip any TZID or property parameters before colon
    if ":" in dt_str:
        dt_str = dt_str.split(":")[-1].strip()

    # Match YYYYMMDDTHHMMSSZ or YYYYMMDDTHHMMSS
    m_dt = re.match(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?', dt_str)
    if m_dt:
        y, m, d, hh, mm, ss, is_utc = m_dt.groups()
        dt = datetime.datetime(int(y), int(m), int(d), int(hh), int(mm), int(ss))
        # If UTC, adjust to local timezone
        if is_utc:
            # Convert UTC datetime to local system time
            dt = dt.replace(tzinfo=datetime.timezone.utc).astimezone().replace(tzinfo=None)
        return dt, False

    # Match YYYYMMDD (all day date)
    m_d = re.match(r'^(\d{4})(\d{2})(\d{2})', dt_str)
    if m_d:
        y, m, d = m_d.groups()
        return datetime.datetime(int(y), int(m), int(d), 0, 0, 0), True

    return None, False

def get_nth_weekday_of_month(year, month, weekday, n, ref_time):
    """Calculate the Nth weekday of a given month/year (n > 0 for 1st, 2nd.. or n < 0 for last)."""
    try:
        if n > 0:
            first_day = datetime.datetime(year, month, 1, ref_time.hour, ref_time.minute, ref_time.second)
            days_offset = (weekday - first_day.weekday()) % 7
            target = first_day + timedelta(days=days_offset + (n - 1) * 7)
            if target.month == month:
                return target
        elif n < 0:
            if month == 12:
                last_day = datetime.datetime(year + 1, 1, 1, ref_time.hour, ref_time.minute, ref_time.second) - timedelta(days=1)
            else:
                last_day = datetime.datetime(year, month + 1, 1, ref_time.hour, ref_time.minute, ref_time.second) - timedelta(days=1)
            days_offset = (last_day.weekday() - weekday) % 7
            target = last_day - timedelta(days=days_offset + (abs(n) - 1) * 7)
            if target.month == month:
                return target
    except Exception:
        pass
    return None

def parse_ics_calendar(content, account_id, account_name, provider, color):
    """
    Parses VEVENT items and projects single, multi-day & recurring events within [-3 years, +3 years] window.
    """
    unfolded = unfold_ics(content)
    now = datetime.datetime.now()
    window_start = now - timedelta(days=365 * 3)
    window_end = now + timedelta(days=365 * 3)

    events = []
    vevent_matches = re.findall(r'BEGIN:VEVENT(.*?)END:VEVENT', unfolded, re.DOTALL | re.IGNORECASE)
    log(f"ICS Parser: Total BEGIN:VEVENT blocks found in feed = {len(vevent_matches)}")

    day_map = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}

    for idx, block in enumerate(vevent_matches):
        # Summary / Title
        sum_m = re.search(r'^[ \t]*(?:SUMMARY[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        summary = unescape_ics_text(sum_m.group(1)) if sum_m else "Calendar Event"

        # Skip cancelled events
        status_m = re.search(r'^[ \t]*(?:STATUS[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        if status_m and status_m.group(1).strip().upper() == "CANCELLED":
            log(f"  [Skip CANCELLED] Event #{idx+1}: '{summary}'")
            continue

        # UID
        uid_m = re.search(r'^[ \t]*(?:UID[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        uid = uid_m.group(1).strip() if uid_m else f"ev_{int(time.time()*1000)%1000000}"

        # Location
        loc_m = re.search(r'^[ \t]*(?:LOCATION[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        location = unescape_ics_text(loc_m.group(1)) if loc_m else ""

        # DTSTART
        start_m = re.search(r'^[ \t]*(?:DTSTART[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        if not start_m:
            log(f"  [Skip NO DTSTART] Event #{idx+1}: '{summary}'")
            continue
        start_dt, is_all_day = parse_ics_datetime(start_m.group(1))
        if not start_dt:
            log(f"  [Skip INVALID DTSTART] Event #{idx+1}: '{summary}' (raw: {start_m.group(1)})")
            continue

        # DTEND
        end_m = re.search(r'^[ \t]*(?:DTEND[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        end_dt = None
        if end_m:
            end_dt, _ = parse_ics_datetime(end_m.group(1))

        # Check RRULE (Recurrence Rule)
        rrule_m = re.search(r'^[ \t]*(?:RRULE[^:\r\n]*):([^\r\n]*)', block, re.MULTILINE | re.IGNORECASE)
        rrule_str = rrule_m.group(1).strip() if rrule_m else None

        # Build list of date occurrences for this event
        occurrences = []

        if not rrule_str:
            # Single event
            if window_start <= start_dt <= window_end:
                occurrences.append((start_dt, end_dt))
            else:
                log(f"  [Out of Window] Event #{idx+1}: '{summary}' on {start_dt.strftime('%Y-%m-%d')}")
        else:
            # Parse recurrence rule: FREQ=DAILY, WEEKLY, MONTHLY, YEARLY
            freq_m = re.search(r'FREQ=([A-Z]+)', rrule_str, re.IGNORECASE)
            freq = freq_m.group(1).upper() if freq_m else "WEEKLY"

            until_m = re.search(r'UNTIL=([0-9TZ]+)', rrule_str, re.IGNORECASE)
            if until_m:
                u_dt, _ = parse_ics_datetime(until_m.group(1))
                until_dt = u_dt.replace(hour=23, minute=59, second=59) if u_dt else window_end
            else:
                until_dt = window_end

            count_m = re.search(r'COUNT=([0-9]+)', rrule_str, re.IGNORECASE)
            has_explicit_count = (count_m is not None)
            explicit_count = int(count_m.group(1)) if has_explicit_count else None

            interval_m = re.search(r'INTERVAL=([0-9]+)', rrule_str, re.IGNORECASE)
            interval = max(1, int(interval_m.group(1))) if interval_m else 1

            # Parse BYDAY (e.g. BYDAY=MO,TU,WE,TH,FR or BYDAY=1MO, -1FR)
            byday_m = re.search(r'BYDAY=([A-Z0-9,-]+)', rrule_str, re.IGNORECASE)
            raw_bydays = [d.strip().upper() for d in byday_m.group(1).split(",")] if byday_m else []

            # Extract simple weekdays (MO, TU, etc.)
            target_weekdays = []
            nth_weekdays = []
            for b_str in raw_bydays:
                # Check for Nth weekday (e.g. 1MO, 2TU, -1FR)
                nth_match = re.match(r'^([+-]?\d+)?([A-Z]{2})$', b_str)
                if nth_match:
                    n_prefix, day_code = nth_match.groups()
                    if day_code in day_map:
                        if n_prefix:
                            nth_weekdays.append((int(n_prefix), day_map[day_code]))
                        else:
                            target_weekdays.append(day_map[day_code])

            duration = (end_dt - start_dt) if end_dt else timedelta(hours=1)
            cur_dt = start_dt
            total_iterations = 0
            produced_count = 0

            # If no explicit COUNT, fast-forward cur_dt to window_start so ancient recurring events project properly
            if not has_explicit_count and cur_dt < window_start:
                if freq == "DAILY":
                    days_skip = (window_start - cur_dt).days
                    if days_skip > 0:
                        cur_dt += timedelta(days=(days_skip // interval) * interval)
                elif freq == "WEEKLY":
                    weeks_skip = (window_start - cur_dt).days // 7
                    if weeks_skip > 0:
                        cur_dt += timedelta(weeks=(weeks_skip // interval) * interval)
                elif freq == "MONTHLY":
                    months_skip = (window_start.year - cur_dt.year) * 12 + (window_start.month - cur_dt.month)
                    if months_skip > 0:
                        steps = months_skip // interval
                        target_m = cur_dt.month - 1 + steps * interval
                        y = cur_dt.year + target_m // 12
                        m = target_m % 12 + 1
                        d = min(cur_dt.day, 28)
                        cur_dt = cur_dt.replace(year=y, month=m, day=d)
                elif freq == "YEARLY":
                    years_skip = window_start.year - cur_dt.year
                    if years_skip > 0:
                        steps = years_skip // interval
                        cur_dt = cur_dt.replace(year=cur_dt.year + steps * interval)

            while cur_dt <= until_dt and cur_dt <= window_end and produced_count < 300:
                if has_explicit_count and total_iterations >= explicit_count:
                    break

                if freq == "WEEKLY" and target_weekdays:
                    start_of_week = cur_dt - timedelta(days=cur_dt.weekday())
                    for wd in target_weekdays:
                        occ_dt = start_of_week + timedelta(days=wd)
                        if occ_dt >= start_dt and occ_dt <= until_dt and window_start <= occ_dt <= window_end:
                            occurrences.append((occ_dt, occ_dt + duration if end_dt else None))
                            produced_count += 1
                elif freq == "MONTHLY" and nth_weekdays:
                    for n_pos, wd in nth_weekdays:
                        occ_dt = get_nth_weekday_of_month(cur_dt.year, cur_dt.month, wd, n_pos, cur_dt)
                        if occ_dt and occ_dt >= start_dt and occ_dt <= until_dt and window_start <= occ_dt <= window_end:
                            occurrences.append((occ_dt, occ_dt + duration if end_dt else None))
                            produced_count += 1
                else:
                    if window_start <= cur_dt <= window_end:
                        occurrences.append((cur_dt, cur_dt + duration if end_dt else None))
                        produced_count += 1

                total_iterations += 1

                if freq == "DAILY":
                    cur_dt += timedelta(days=interval)
                elif freq == "WEEKLY":
                    cur_dt += timedelta(weeks=interval)
                elif freq == "MONTHLY":
                    month = cur_dt.month - 1 + interval
                    year = cur_dt.year + month // 12
                    month = month % 12 + 1
                    day = min(cur_dt.day, 28)
                    try:
                        cur_dt = cur_dt.replace(year=year, month=month, day=day)
                    except ValueError:
                        cur_dt += timedelta(days=30 * interval)
                elif freq == "YEARLY":
                    try:
                        cur_dt = cur_dt.replace(year=cur_dt.year + interval)
                    except ValueError:
                        cur_dt += timedelta(days=365 * interval)
                else:
                    break

        log(f"  [Parsed] Event #{idx+1}: '{summary}' -> {len(occurrences)} occurrence(s)")

        # Generate event items for each occurrence (expanding multi-day all-day spans)
        for occ_start, occ_end in occurrences:
            safe_uid = re.sub(r'[^a-zA-Z0-9_-]', '_', uid)[:40]

            if is_all_day and occ_end and (occ_end.date() - occ_start.date()).days > 1:
                cur_span = occ_start
                while cur_span < occ_end and window_start <= cur_span <= window_end:
                    span_id = f"on_{account_id}_{safe_uid}_{cur_span.strftime('%Y%m%d')}"
                    events.append({
                        "id": span_id,
                        "year": cur_span.year,
                        "month": cur_span.month,
                        "day": cur_span.day,
                        "title": summary,
                        "time": "All Day",
                        "category": "online",
                        "color": color or "#3584e4",
                        "location": location or "",
                        "account": account_name,
                        "accountId": account_id,
                        "provider": provider,
                        "isHoliday": False,
                        "isOnline": True
                    })
                    cur_span += timedelta(days=1)
            else:
                if is_all_day:
                    time_str = "All Day"
                else:
                    sh = f"{occ_start.hour:02d}:{occ_start.minute:02d}"
                    if occ_end and (occ_end.hour != occ_start.hour or occ_end.minute != occ_start.minute):
                        eh = f"{occ_end.hour:02d}:{occ_end.minute:02d}"
                        time_str = f"{sh} - {eh}"
                    else:
                        time_str = sh

                occ_id = f"on_{account_id}_{safe_uid}_{occ_start.strftime('%Y%m%d')}"
                events.append({
                    "id": occ_id,
                    "year": occ_start.year,
                    "month": occ_start.month,
                    "day": occ_start.day,
                    "title": summary,
                    "time": time_str,
                    "category": "online",
                    "color": color or "#3584e4",
                    "location": location or "",
                    "account": account_name,
                    "accountId": account_id,
                    "provider": provider,
                    "isHoliday": False,
                    "isOnline": True
                })

    log(f"ICS Parser: Total generated event entries = {len(events)}")
    return events

def sync_single_account(account):
    acc_id = str(account.get("id", ""))
    acc_name = account.get("name", "Online Calendar")
    provider = account.get("provider", "google")
    url = account.get("url", "")
    username = account.get("username", "")
    password = account.get("password", "")
    color = account.get("color", "#3584e4")

    if not url:
        return {"status": "error", "message": "No URL specified."}

    try:
        ics_text = fetch_ics_data(url, username=username, password=password, timeout=12)

        # Cache raw ICS feed for inspection and troubleshooting
        try:
            raw_feed_file = os.path.join(DATA_DIR, f"raw_feed_{acc_id}.ics")
            with open(raw_feed_file, "w", encoding="utf-8", errors="replace") as f:
                f.write(ics_text)
        except Exception as e:
            log(f"Error saving raw feed: {e}")

        events = parse_ics_calendar(ics_text, acc_id, acc_name, provider, color)

        events_file = os.path.join(DATA_DIR, f"online_events_{acc_id}.json")
        with open(events_file, "w", encoding="utf-8") as f:
            json.dump(events, f, indent=2, ensure_ascii=False)

        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        account["lastSynced"] = now_str
        account["eventCount"] = len(events)
        account["status"] = "success"

        log(f"Synced '{acc_name}': {len(events)} events loaded.")
        return {
            "status": "success",
            "accountId": acc_id,
            "accountName": acc_name,
            "eventCount": len(events),
            "lastSynced": now_str
        }
    except urllib.error.HTTPError as e:
        if e.code == 401:
            msg = "Authentication failed (HTTP 401 Unauthorized). Please check your username and password/app token."
        elif e.code == 403:
            msg = "Access forbidden (HTTP 403 Forbidden). Calendar feed is private or restricted."
        elif e.code == 404:
            msg = "Calendar not found (HTTP 404 Not Found). Please verify the calendar URL."
        else:
            msg = f"HTTP {e.code}: {e.reason}"
        account["status"] = msg
        log(f"HTTP error syncing '{acc_name}': {msg}")
        return {"status": "error", "message": msg}
    except urllib.error.URLError as e:
        msg = f"Network connection error: {e.reason}"
        account["status"] = msg
        log(f"Network error syncing '{acc_name}': {msg}")
        return {"status": "error", "message": msg}
    except Exception as e:
        msg = str(e)
        account["status"] = msg
        log(f"Error syncing '{acc_name}': {msg}")
        return {"status": "error", "message": msg}

def cmd_list_accounts():
    accounts = get_accounts()
    print(json.dumps(accounts))

def cmd_add_account(name, provider, url, color="#3584e4", username="", password=""):
    accounts = get_accounts()
    clean_url = sanitize_url(url)
    if not clean_url:
        print(json.dumps({"status": "error", "message": "Invalid URL"}))
        return

    acc_id = f"cal_{int(time.time())}"
    new_acc = {
        "id": acc_id,
        "name": name.strip() or "My Calendar",
        "provider": provider.lower() if provider else "custom",
        "url": clean_url,
        "username": username.strip() if username else "",
        "password": password.strip() if password else "",
        "color": color or "#3584e4",
        "enabled": True,
        "lastSynced": "",
        "eventCount": 0,
        "status": "pending"
    }

    # Initial sync to validate URL
    res = sync_single_account(new_acc)
    if res.get("status") == "success":
        accounts.append(new_acc)
        save_accounts(accounts)
        print(json.dumps({
            "status": "success",
            "account": new_acc,
            "message": f"Successfully added '{new_acc['name']}' with {res.get('eventCount', 0)} events."
        }))
    else:
        accounts.append(new_acc)
        save_accounts(accounts)
        print(json.dumps({
            "status": "warning",
            "account": new_acc,
            "message": f"{res.get('message')}"
        }))

def cmd_update_account(acc_id, name, url, color, enabled_val, username=None, password=None):
    accounts = get_accounts()
    found = None
    for a in accounts:
        if str(a.get("id")) == str(acc_id):
            found = a
            break

    if not found:
        print(json.dumps({"status": "error", "message": "Account not found"}))
        return

    if name:
        found["name"] = name.strip()
    if url:
        found["url"] = sanitize_url(url)
    if color:
        found["color"] = color.strip()
    if username is not None and username != "":
        found["username"] = username.strip()
    if password is not None and password != "":
        found["password"] = password.strip()
    if enabled_val is not None and enabled_val != "":
        found["enabled"] = (str(enabled_val).lower() in ("true", "1", "yes"))

    save_accounts(accounts)

    # Re-sync if enabled
    if found.get("enabled"):
        sync_single_account(found)
        save_accounts(accounts)

    print(json.dumps({"status": "success", "account": found}))

def cmd_delete_account(acc_id):
    accounts = get_accounts()
    new_list = [a for a in accounts if str(a.get("id")) != str(acc_id)]
    save_accounts(new_list)

    # Remove cached events file
    events_file = os.path.join(DATA_DIR, f"online_events_{acc_id}.json")
    if os.path.exists(events_file):
        try:
            os.remove(events_file)
        except Exception:
            pass

    print(json.dumps({"status": "success", "deletedId": acc_id}))

def cmd_sync_all():
    accounts = get_accounts()
    total_events = 0
    synced_count = 0
    errors = []

    for acc in accounts:
        if acc.get("enabled", True):
            res = sync_single_account(acc)
            if res.get("status") == "success":
                synced_count += 1
                total_events += res.get("eventCount", 0)
            else:
                errors.append(f"{acc.get('name')}: {res.get('message')}")

    save_accounts(accounts)

    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    status_data = {
        "status": "success" if not errors else ("partial" if synced_count > 0 else "error"),
        "syncedAccounts": synced_count,
        "totalEvents": total_events,
        "lastSynced": now_str,
        "errors": errors
    }

    try:
        with open(SYNC_STATUS_FILE, "w", encoding="utf-8") as f:
            json.dump(status_data, f, indent=2)
    except Exception:
        pass

    print(json.dumps(status_data))

def cmd_sync_account(acc_id):
    accounts = get_accounts()
    target = None
    for a in accounts:
        if str(a.get("id")) == str(acc_id):
            target = a
            break

    if not target:
        print(json.dumps({"status": "error", "message": "Account not found"}))
        return

    res = sync_single_account(target)
    save_accounts(accounts)
    print(json.dumps(res))

def cmd_test_url(url):
    clean_url = sanitize_url(url)
    try:
        data = fetch_ics_data(clean_url, timeout=10)
        events = parse_ics_calendar(data, "test", "Test Calendar", "custom", "#3584e4")
        cal_name_m = re.search(r'X-WR-CALNAME:(.*)', data, re.IGNORECASE)
        cal_name = unescape_ics_text(cal_name_m.group(1)) if cal_name_m else "Online Calendar"
        print(json.dumps({
            "status": "success",
            "calendarName": cal_name,
            "eventCount": len(events)
        }))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"

    if cmd in ("list", "list_accounts"):
        cmd_list_accounts()
    elif cmd == "add":
        name = sys.argv[2] if len(sys.argv) > 2 else "New Calendar"
        provider = sys.argv[3] if len(sys.argv) > 3 else "google"
        url = sys.argv[4] if len(sys.argv) > 4 else ""
        color = sys.argv[5] if len(sys.argv) > 5 else "#3584e4"
        username = sys.argv[6] if len(sys.argv) > 6 else ""
        password = sys.argv[7] if len(sys.argv) > 7 else ""
        cmd_add_account(name, provider, url, color, username, password)
    elif cmd == "update":
        acc_id = sys.argv[2] if len(sys.argv) > 2 else ""
        name = sys.argv[3] if len(sys.argv) > 3 else ""
        url = sys.argv[4] if len(sys.argv) > 4 else ""
        color = sys.argv[5] if len(sys.argv) > 5 else ""
        enabled = sys.argv[6] if len(sys.argv) > 6 else None
        username = sys.argv[7] if len(sys.argv) > 7 else ""
        password = sys.argv[8] if len(sys.argv) > 8 else ""
        cmd_update_account(acc_id, name, url, color, enabled, username, password)
    elif cmd == "delete":
        acc_id = sys.argv[2] if len(sys.argv) > 2 else ""
        cmd_delete_account(acc_id)
    elif cmd == "sync":
        acc_id = sys.argv[2] if len(sys.argv) > 2 else ""
        if acc_id:
            cmd_sync_account(acc_id)
        else:
            cmd_sync_all()
    elif cmd == "sync_all":
        cmd_sync_all()
    elif cmd == "test_url":
        url = sys.argv[2] if len(sys.argv) > 2 else ""
        cmd_test_url(url)
    elif cmd == "status":
        if os.path.exists(SYNC_STATUS_FILE):
            try:
                with open(SYNC_STATUS_FILE, "r", encoding="utf-8") as f:
                    print(f.read().strip())
                    return
            except Exception:
                pass
        print(json.dumps({"status": "never_synced"}))
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))

if __name__ == "__main__":
    main()
