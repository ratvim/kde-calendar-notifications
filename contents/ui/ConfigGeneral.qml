import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    // Date & Time aliases
    property alias cfg_use24Hour: use24HourCheck.checked
    property alias cfg_showSeconds: showSecondsCheck.checked
    property alias cfg_showDateOnPanel: showDateCheck.checked
    property alias cfg_dateFormat: dateFormatField.text
    property string cfg_timeFormat: ""

    // Timezone properties
    property alias cfg_autoDetectTimezone: autoTzCheck.checked
    property string cfg_selectedTimezone: Plasmoid.configuration.selectedTimezone || "Local"

    // Page Layout alias
    property alias cfg_calendarOnLeft: calendarLeftRadio.checked

    // Font & Appearance aliases
    property string cfg_fontFamily: ""
    property alias cfg_timeFontSize: timeFontSizeSpin.value
    property alias cfg_dateFontSize: dateFontSizeSpin.value
    property alias cfg_showNotificationBadge: showBadgeCheck.checked
    property alias cfg_showNotificationCount: showCountCheck.checked
    property alias cfg_isDarkTheme: darkThemeCheck.checked

    // Panel Background & Blur
    property string cfg_panelBackgroundMode: "follow_panel"
    property real cfg_customOpacity: 0.75
    property alias cfg_panelBlurEnabled: blurCheck.checked

    // Calendar Sync settings
    property alias cfg_autoSyncOnlineAccount: autoSyncOnlineCheck.checked
    property alias cfg_onlineAccountSyncInterval: syncIntervalSpin.value

    property var accountsList: []
    property string statusMsg: ""
    property bool isBusy: false

    function escapeShellArg(arg) {
        if (arg === undefined || arg === null) return "''"
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function getScriptPath(scriptName) {
        var base = Qt.resolvedUrl("../scripts/" + scriptName).toString()
        if (base.indexOf("file://") === 0) {
            base = base.substring(7)
        }
        return base
    }

    function execCmd(scriptName, args) {
        var fullCmd = "bash " + escapeShellArg(getScriptPath(scriptName)) + (args ? " " + args : "")
        root.isBusy = true
        configExec.connectSource(fullCmd)
    }

    function reloadAccounts() {
        execCmd("calendar.sh", "accounts")
    }

    function addAccount(name, provider, url, color, user, pass) {
        root.statusMsg = i18n("Adding & syncing calendar...")
        var n = escapeShellArg(name || "Calendar")
        var p = escapeShellArg(provider || "google")
        var u = escapeShellArg(url || "")
        var c = escapeShellArg(color || "#3584e4")
        var usr = escapeShellArg(user || "")
        var pwd = escapeShellArg(pass || "")
        execCmd("calendar.sh", "add_account " + n + " " + p + " " + u + " " + c + " " + usr + " " + pwd)
    }

    function deleteAccount(id) {
        root.statusMsg = i18n("Deleting calendar...")
        execCmd("calendar.sh", "delete_account " + escapeShellArg(id))
    }

    function syncAll() {
        root.statusMsg = i18n("Syncing all calendars...")
        execCmd("calendar.sh", "sync_all")
    }

    function syncAccount(id) {
        root.statusMsg = i18n("Syncing calendar...")
        execCmd("calendar.sh", "sync " + escapeShellArg(id))
    }

    Plasma5Support.DataSource {
        id: configExec
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var stdout = data["stdout"] ? data["stdout"].trim() : ""
            var stderr = data["stderr"] ? data["stderr"].trim() : ""
            disconnectSource(source)
            root.isBusy = false

            if (!stdout && stderr) {
                root.statusMsg = stderr
                return
            }
            if (!stdout) return

            try {
                if (source.indexOf("calendar.sh") !== -1 && source.indexOf("accounts") !== -1) {
                    var accList = JSON.parse(stdout)
                    if (Array.isArray(accList)) {
                        root.accountsList = accList
                    }
                } else if (source.indexOf("calendar.sh") !== -1) {
                    var res = JSON.parse(stdout)
                    if (res) {
                        if (res.message) {
                            root.statusMsg = res.message
                        } else if (res.status === "success") {
                            root.statusMsg = i18n("Successfully synced %1 events.", res.eventCount || res.totalEvents || 0)
                        } else if (res.status) {
                            root.statusMsg = res.status
                        }
                    }
                    root.reloadAccounts()
                }
            } catch (e) {
                console.warn("[ConfigGeneral] Parse error:", e)
            }
        }
    }

    Component.onCompleted: {
        reloadAccounts()
    }

    readonly property var commonTimezones: [
        "Local", "UTC",
        "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Toronto", "America/Sao_Paulo",
        "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Madrid", "Europe/Rome", "Europe/Moscow",
        "Asia/Dubai", "Asia/Kolkata", "Asia/Bangkok", "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo", "Asia/Seoul",
        "Australia/Sydney", "Pacific/Auckland"
    ]

    Kirigami.FormLayout {
        // ==========================================
        // 1. Date & Time Settings
        // ==========================================
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Date & Time Formatting")
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: use24HourCheck
            Kirigami.FormData.label: i18n("Clock Display:")
            text: i18n("Use 24-hour clock (e.g. 18:30 instead of 6:30 PM)")
        }

        CheckBox {
            id: showSecondsCheck
            text: i18n("Show seconds on panel clock")
        }

        CheckBox {
            id: showDateCheck
            text: i18n("Show date below time on panel")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Date Format:")
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: dateFormatField
                Layout.fillWidth: true
                placeholderText: "ddd, MMM d"
            }

            Button {
                text: i18n("Default")
                icon.name: "edit-undo"
                ToolTip.text: i18n("Reset to default format: ddd, MMM d")
                ToolTip.visible: hovered
                onClicked: {
                    dateFormatField.text = "ddd, MMM d"
                }
            }
        }

        // ==========================================
        // 2. Timezone & Location
        // ==========================================
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Timezone & Location")
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: autoTzCheck
            Kirigami.FormData.label: i18n("Detection:")
            text: i18n("Auto-detect timezone via system / location")
        }

        ComboBox {
            id: tzCombo
            Kirigami.FormData.label: i18n("Manual Timezone:")
            enabled: !autoTzCheck.checked
            model: root.commonTimezones
            Layout.fillWidth: true
            currentIndex: {
                var idx = model.indexOf(root.cfg_selectedTimezone)
                return idx >= 0 ? idx : 0
            }
            onActivated: function(index) {
                root.cfg_selectedTimezone = model[index]
            }
        }

        // ==========================================
        // 3. Dual-Page Layout Ordering
        // ==========================================
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Dual-Page Layout")
            Kirigami.FormData.isSection: true
        }

        ButtonGroup {
            id: layoutGroup
        }

        RadioButton {
            id: calendarLeftRadio
            ButtonGroup.group: layoutGroup
            Kirigami.FormData.label: i18n("Side Placement:")
            text: i18n("Calendar on Left, Notifications on Right (Default)")
            checked: Plasmoid.configuration.calendarOnLeft
        }

        RadioButton {
            id: notifLeftRadio
            ButtonGroup.group: layoutGroup
            text: i18n("Notifications on Left, Calendar on Right")
            checked: !calendarLeftRadio.checked
        }

        // ==========================================
        // 4. Font & Appearance
        // ==========================================
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Font & Appearance")
            Kirigami.FormData.isSection: true
        }

        SpinBox {
            id: timeFontSizeSpin
            Kirigami.FormData.label: i18n("Time Font Size (px):")
            from: 9
            to: 28
            stepSize: 1
        }

        SpinBox {
            id: dateFontSizeSpin
            Kirigami.FormData.label: i18n("Date Font Size (px):")
            from: 8
            to: 22
            stepSize: 1
        }

        CheckBox {
            id: showBadgeCheck
            Kirigami.FormData.label: i18n("Notifications Badge:")
            text: i18n("Show indicator badge on panel for unread notifications")
        }

        CheckBox {
            id: showCountCheck
            enabled: showBadgeCheck.checked
            text: i18n("Show unread count number inside the badge")
        }

        CheckBox {
            id: darkThemeCheck
            Kirigami.FormData.label: i18n("Appearance Mode:")
            text: i18n("Force dark style (glassmorphic dark palette)")
        }

        // ==========================================
        // Panel Background & Blur Sync
        // ==========================================
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Panel Background, Transparency & Blur")
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            id: bgModeCombo
            Kirigami.FormData.label: i18n("Background Appearance:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Follow Attached Panel (Automatic)"), value: "follow_panel" },
                { text: i18n("Frosted Glass Translucent"), value: "translucent" },
                { text: i18n("Solid Opaque"), value: "opaque" }
            ]
            currentIndex: {
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === root.cfg_panelBackgroundMode) return i
                }
                return 0
            }
            onActivated: {
                root.cfg_panelBackgroundMode = currentValue
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Custom Opacity:")
            visible: root.cfg_panelBackgroundMode === "translucent"
            spacing: Kirigami.Units.largeSpacing

            Slider {
                id: opacitySlider
                from: 0.20
                to: 1.00
                stepSize: 0.05
                value: root.cfg_customOpacity
                onMoved: {
                    root.cfg_customOpacity = Math.round(value * 100) / 100
                }
            }

            Label {
                text: Math.round(opacitySlider.value * 100) + "%"
                color: Kirigami.Theme.disabledTextColor
            }
        }

        CheckBox {
            id: blurCheck
            Kirigami.FormData.label: i18n("Compositor Blur:")
            text: i18n("Enable blur behind card (restricted to curved card region via KWin)")
            checked: true
        }

        // ==========================================
        // 5. Calendar Sync
        // ==========================================
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Calendar Sync")
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: autoSyncOnlineCheck
            Kirigami.FormData.label: i18n("Background Sync:")
            text: i18n("Automatically sync calendars in the background")
        }

        SpinBox {
            id: syncIntervalSpin
            enabled: autoSyncOnlineCheck.checked
            Kirigami.FormData.label: i18n("Sync Interval (minutes):")
            from: 5
            to: 1440
            stepSize: 15
        }

        Label {
            visible: !!Plasmoid.configuration.lastOnlineSyncTime
            Kirigami.FormData.label: i18n("Last Synced:")
            text: Plasmoid.configuration.lastOnlineSyncTime || ""
            opacity: 0.8
        }

        // --- Current Connected Accounts ---
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Connected Calendars")
            Kirigami.FormData.isSection: true
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Active Accounts:")
            Layout.fillWidth: true
            spacing: 8

            // Account List
            Repeater {
                model: root.accountsList

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(54, accItemRow.implicitHeight + 16)
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.04)
                    border.color: Qt.rgba(0, 0, 0, 0.12)
                    border.width: 1
                    clip: true

                    RowLayout {
                        id: accItemRow
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 10

                        // Color pill
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData.color || "#3584e4"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 50
                            Layout.preferredWidth: 0
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Label {
                                text: modelData.name || i18n("Calendar")
                                font.bold: true
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: {
                                    var str = (modelData.provider ? String(modelData.provider).toUpperCase() : "ICAL") + " • " + (modelData.eventCount || 0) + " " + i18n("events");
                                    if (modelData.lastSynced) {
                                        str += " • " + i18n("Synced: %1", modelData.lastSynced);
                                    }
                                    if (modelData.status && modelData.status !== "success" && modelData.status !== "pending") {
                                        str += " • " + modelData.status;
                                    }
                                    return str;
                                }
                                font.pixelSize: 10
                                opacity: 0.75
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Sync button
                        Button {
                            icon.name: "view-refresh"
                            text: i18n("Sync")
                            enabled: !root.isBusy
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: {
                                root.syncAccount(modelData.id)
                            }
                        }

                        // Delete button
                        Button {
                            icon.name: "edit-delete"
                            enabled: !root.isBusy
                            Layout.alignment: Qt.AlignVCenter
                            ToolTip.text: i18n("Delete Calendar")
                            ToolTip.visible: hovered
                            onClicked: {
                                root.deleteAccount(modelData.id)
                            }
                        }
                    }
                }
            }

            Label {
                visible: root.accountsList.length === 0
                text: i18n("No calendar accounts added yet.")
                opacity: 0.7
            }

            RowLayout {
                spacing: 8
                visible: root.accountsList.length > 0

                Button {
                    icon.name: "view-refresh"
                    text: i18n("Sync All Calendars Now")
                    enabled: !root.isBusy
                    onClicked: {
                        root.syncAll()
                    }
                }
            }
        }

        // --- Add New Calendar Account ---
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Add Calendar Account")
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            id: providerCombo
            Kirigami.FormData.label: i18n("Provider:")
            model: [
                { id: "google", text: i18n("Google Calendar (Private iCal Address)") },
                { id: "outlook", text: i18n("Microsoft Outlook / 365 (Published ICS Link)") },
                { id: "nextcloud", text: i18n("Nextcloud / CalDAV (URL + Credentials)") },
                { id: "custom", text: i18n("Custom iCal / Webcal Subscription URL") }
            ]
            textRole: "text"
            onCurrentIndexChanged: {
                if (calNameInput.text === "" || calNameInput.text === "Google Calendar" || calNameInput.text === "Outlook Calendar" || calNameInput.text === "Nextcloud Calendar" || calNameInput.text === "Online Calendar") {
                    if (currentIndex === 0) calNameInput.text = "Google Calendar"
                    else if (currentIndex === 1) calNameInput.text = "Outlook Calendar"
                    else if (currentIndex === 2) calNameInput.text = "Nextcloud Calendar"
                    else calNameInput.text = "Online Calendar"
                }
            }
        }

        Label {
            Kirigami.FormData.label: i18n("How to Connect:")
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            font.pixelSize: 11
            opacity: 0.8
            text: {
                if (providerCombo.currentIndex === 0) {
                    return i18n("Google Calendar does not require a password. In Google Calendar Web:\n1. Open Settings > Settings for my calendars > click your calendar.\n2. Scroll down to 'Integrate calendar'.\n3. Copy the 'Secret address in iCal format' and paste it below.")
                } else if (providerCombo.currentIndex === 1) {
                    return i18n("Outlook Web does not require a password. In Outlook Web:\n1. Open Settings > Calendar > Shared calendars.\n2. Under 'Publish a calendar', select calendar and 'Can view all details', then click Publish.\n3. Copy the 'ICS' link and paste it below.")
                } else if (providerCombo.currentIndex === 2) {
                    return i18n("In Nextcloud Calendar, click the 3 dots (...) next to your calendar and click 'Copy subscription link' or 'Copy private link'. If your Nextcloud is password-protected, enter your Username and App Password below.")
                } else {
                    return i18n("Paste any direct .ics link or webcal:// subscription URL from iCloud, Fastmail, Yahoo, or your server. Enter credentials below if required.")
                }
            }
        }

        TextField {
            id: calNameInput
            Kirigami.FormData.label: i18n("Calendar Name:")
            text: "Google Calendar"
            Layout.fillWidth: true
        }

        TextField {
            id: calUrlInput
            Kirigami.FormData.label: i18n("Calendar Feed URL:")
            placeholderText: providerCombo.currentIndex === 0 ?
                             "https://calendar.google.com/calendar/ical/.../basic.ics" :
                             (providerCombo.currentIndex === 1 ?
                              "https://outlook.live.com/owa/calendar/.../reachcalendar.ics" :
                              "https://nextcloud.example.com/remote.php/dav/calendars/...")
            Layout.fillWidth: true
        }

        TextField {
            id: calUserInput
            Kirigami.FormData.label: i18n("Username (Optional):")
            placeholderText: i18n("Required only for protected Nextcloud / CalDAV / servers")
            Layout.fillWidth: true
            visible: providerCombo.currentIndex >= 2
        }

        TextField {
            id: calPassInput
            Kirigami.FormData.label: i18n("Password / App Token:")
            echoMode: TextInput.Password
            placeholderText: i18n("Required only for protected Nextcloud / CalDAV / servers")
            Layout.fillWidth: true
            visible: providerCombo.currentIndex >= 2
        }

        ComboBox {
            id: colorCombo
            Kirigami.FormData.label: i18n("Color:")
            model: [
                { name: i18n("Blue"), hex: "#3584e4" },
                { name: i18n("Outlook Blue"), hex: "#0078d4" },
                { name: i18n("Nextcloud Cyan"), hex: "#0082c9" },
                { name: i18n("Purple"), hex: "#9141ac" },
                { name: i18n("Green"), hex: "#33d17a" },
                { name: i18n("Amber"), hex: "#e5a50a" },
                { name: i18n("Red"), hex: "#e01b24" }
            ]
            textRole: "name"
        }

        RowLayout {
            spacing: 10

            Button {
                text: i18n("Add & Sync Calendar")
                icon.name: "list-add"
                enabled: !root.isBusy && calUrlInput.text.trim().length > 0
                onClicked: {
                    var prov = providerCombo.model[providerCombo.currentIndex].id
                    var col = colorCombo.model[colorCombo.currentIndex].hex
                    root.addAccount(calNameInput.text.trim(), prov, calUrlInput.text.trim(), col, calUserInput.text.trim(), calPassInput.text.trim())
                    calUrlInput.text = ""
                    calPassInput.text = ""
                }
            }

            BusyIndicator {
                running: root.isBusy
                implicitWidth: 20
                implicitHeight: 20
            }
        }

        Label {
            visible: root.statusMsg.length > 0
            text: root.statusMsg
            font.bold: true
            color: root.statusMsg.indexOf("Error") !== -1 || root.statusMsg.indexOf("failed") !== -1 || root.statusMsg.indexOf("forbidden") !== -1 || root.statusMsg.indexOf("HTTP") !== -1 ? "#e74c3c" : "#27ae60"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
