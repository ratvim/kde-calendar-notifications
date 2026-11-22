# 📅 Calendar & Notification Center for KDE Plasma 6

[![KDE Plasma](https://img.shields.io/badge/KDE%20Plasma-6.0%2B-blue.svg)](https://kde.org/plasma-desktop/)
[![Qt](https://img.shields.io/badge/Qt-6-41CD52.svg)](https://www.qt.io/)
[![Platform](https://img.shields.io/badge/Display%20Server-Wayland%20%7C%20X11-orange.svg)]()
[![Release](https://img.shields.io/badge/Release-v1.0.0-success.svg)]()
[![License](https://img.shields.io/badge/License-GPL--3.0-lightgrey.svg)](LICENSE)

A unified, modern **Dual-Page Calendar, Agenda & Notification Center** applet built natively for **KDE Plasma 6 (Plasma 6.0 through 6.9+)**.

---

## ✨ Features

### 1. Compact Panel Representation
- **Real-Time Clock & Date**:
  - 12-hour or 24-hour clock formatting.
  - Optional seconds display.
  - Configurable date formatting string (`ddd, MMM d`).
  - Customizable font family and independent font size scaling for time and date.
- **Unread Notification Indicator**:
  - Visual notification badge counter with pulse animation when new notifications arrive.
  - Automatically clears the unread count when the widget is clicked and expanded.

### 2. Full Side-by-Side Dual-Page View
- **Glassmorphic 20px Curved Popup Card**:
  - Top header displaying the active date, time, and detected timezone.
  - One-click **Layout Swap** button to immediately flip the sides of the Calendar and Notifications.
  - Config button to launch applet preferences.
- **Page A: Calendar & Agenda**:
  - Interactive 42-cell month grid.
  - Month and year navigation (`<`, `>`) and quick **"Today"** shortcut button.
  - Clear visual highlight for **Today** and the **Selected Day**.
  - Small indicator dots under dates that have scheduled events or holidays.
  - Dynamic day agenda listing timed events, milestones, and personal reminders.
  - Quick event addition and deletion controls.
- **Page B: App-Grouped Notifications**:
  - Grouped by application (e.g. `Telegram (2)`, `Google Chrome (2)`, `System (1)`).
  - Expandable / collapsible application cards with item counts.
  - Detailed individual notification cards featuring app icons, timestamps, summaries, message bodies, and interactive action buttons.
  - Dismiss per notification, dismiss per group, or **"Clear All"**.
  - Beautiful empty state when all notifications are cleared.

### 3. Comprehensive Configuration (Right-Click -> Configure)
- **Timezone & Location**:
  - Auto-detection via system `timedatectl` / timezone database.
  - Manual timezone selection dropdown from major world timezones.
- **Side Placement**:
  - Option to set Calendar on Left / Notifications on Right, or vice versa.
- **Date & Time Formatting**:
  - 12h / 24h toggle, seconds toggle, date visibility toggle, custom format strings.
- **Font & Appearance**:
  - Font family override, time/date font size scaling, notification badge counter toggles, and dark style forcing.

---

## 📂 Project Structure

```
kde_calendar_notifications/
├── metadata.json                          # Plasma 6 applet metadata
├── install.sh                             # Automated installation script
├── package.sh                             # Plasmoid packaging script
├── README.md                              # Applet documentation
└── contents/
    ├── config/
    │   ├── main.xml                       # KConfigXT settings schema
    │   └── config.qml                     # Settings categories model
    ├── scripts/
    │   ├── notifications.sh               # Notification manager & D-Bus backend
    │   ├── calendar.sh                    # Agenda and event provider
    │   └── timezone.sh                    # Timezone detection & listing
    └── ui/
        ├── main.qml                       # Root PlasmoidItem
        ├── CompactRepresentation.qml      # Panel clock, date & badge
        ├── FullRepresentation.qml         # Dual-page side-by-side card
        ├── ConfigGeneral.qml              # Preferences settings page
        └── views/
            ├── CalendarView.qml           # Month grid & agenda
            └── NotificationView.qml       # App-grouped notification drawer
```

---

## 🚀 Installation & Usage

### 1. Install Applet
```bash
cd "kde_calendar_notifications"
chmod +x install.sh package.sh
./install.sh
```

### 2. Add to Panel
1. Right-click on your KDE panel and select **"Add Widgets..."**.
2. Search for **"Calendar & Notification Center"**.
3. Drag and drop the widget onto your panel.

### 3. Test Preview
You can preview the applet immediately in a standalone test window:
```bash
plasmoidviewer -a org.kde.plasma.calendarnotifications
```
