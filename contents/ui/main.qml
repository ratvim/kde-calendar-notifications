import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager

/**
 * main.qml - Unified Calendar, Agenda & Notification Center for KDE Plasma 6
 * Supporting Plasma 6.0 through 6.9+
 */
PlasmoidItem {
    id: mainItem

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.userBackgroundHints: PlasmaCore.Types.NoBackground

    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.preferredWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth : -1
    Layout.minimumWidth: compactRepresentationItem ? compactRepresentationItem.Layout.minimumWidth : 90
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: 2
    Layout.rightMargin: 6

    compactRepresentation: CompactRepresentation {
        backend: mainItem
    }
    fullRepresentation: FullRepresentation {
        backend: mainItem
        Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
        Plasmoid.userBackgroundHints: PlasmaCore.Types.NoBackground
    }

    // Scoped Kirigami Item bound to Window colorSet to accurately read the global desktop theme (BreezeLight vs BreezeDark)
    // without being overridden by Plasma's panel Complementary colorSet.
    Item {
        id: systemWindowScope
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
    }

    // Dynamic Authoritative System Theme Detection
    readonly property bool systemIsDark: {
        var bg = systemWindowScope.Kirigami.Theme.backgroundColor
        var fg = systemWindowScope.Kirigami.Theme.textColor
        if (bg && bg.a > 0 && fg && fg.a > 0 && (bg.r !== 0 || bg.g !== 0 || bg.b !== 0 || fg.r !== 0 || fg.g !== 0 || fg.b !== 0)) {
            var bgLum = bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114
            var fgLum = fg.r * 0.299 + fg.g * 0.587 + fg.b * 0.114
            return (bgLum < 0.5) || (fgLum > 0.6)
        }
        return false
    }

    // Dynamic attributes detected from the attached panel
    property bool hasCustomPanelColor: false
    property color detectedPanelColor: Qt.rgba(0, 0, 0, 0)
    property real detectedPanelOpacity: 0.70
    property bool detectedPanelBlur: true
    property color detectedPanelTextColor: Qt.rgba(0, 0, 0, 0)

    function updatePanelDetection() {
        if (compactRepresentationItem && typeof compactRepresentationItem.detectPanelProperties === "function") {
            compactRepresentationItem.detectPanelProperties()
        }
    }

    // Effective background appearance honoring attached panel or user overrides
    readonly property real effectiveBackgroundOpacity: {
        if (panelBackgroundMode === "opaque") return 1.0
        if (panelBackgroundMode === "translucent") return Math.max(0.20, Math.min(1.0, customOpacity))
        // "follow_panel": dynamically follows the attached panel
        return Math.max(0.35, Math.min(1.0, detectedPanelOpacity))
    }

    readonly property color effectivePanelColor: {
        if (panelBackgroundMode === "follow_panel" && hasCustomPanelColor && detectedPanelColor && detectedPanelColor.a > 0) {
            return detectedPanelColor
        }
        return systemIsDark ? Qt.color("#1e1e24") : Qt.color("#f6f8fa")
    }

    readonly property color effectiveCardColor: {
        var c = effectivePanelColor
        return Qt.rgba(c.r, c.g, c.b, effectiveBackgroundOpacity)
    }

    readonly property bool effectiveBlurEnabled: {
        if (!panelBlurEnabled) return false
        if (panelBackgroundMode === "opaque") return false
        if (effectiveBackgroundOpacity >= 0.98) return false
        return true
    }

    readonly property bool effectiveIsDark: {
        var c = effectivePanelColor
        var lum = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
        return lum < 0.55
    }

    property bool manualThemeOverride: false
    property bool manualDark: false
    property bool isDarkTheme: manualThemeOverride ? manualDark : (hasCustomPanelColor ? effectiveIsDark : systemIsDark)

    // Configuration Properties (persisted via KConfigXT)
    property string panelBackgroundMode: (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration.panelBackgroundMode !== undefined)
                                         ? plasmoid.configuration.panelBackgroundMode : (Plasmoid.configuration.panelBackgroundMode || "follow_panel")
    property real customOpacity: (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration.customOpacity !== undefined)
                                 ? plasmoid.configuration.customOpacity : (Plasmoid.configuration.customOpacity || 0.75)
    property bool panelBlurEnabled: (typeof plasmoid !== "undefined" && plasmoid.configuration && plasmoid.configuration.panelBlurEnabled !== undefined)
                                    ? plasmoid.configuration.panelBlurEnabled : (Plasmoid.configuration.panelBlurEnabled !== undefined ? Plasmoid.configuration.panelBlurEnabled : true)

    Connections {
        target: Kirigami.Theme
        function onColorsChanged() {
            mainItem.manualThemeOverride = false
            mainItem.updatePanelDetection()
            if (mainItem.fullRepresentationItem && typeof mainItem.fullRepresentationItem.removePlasmaBackground === "function") {
                mainItem.fullRepresentationItem.removePlasmaBackground()
                mainItem.fullRepresentationItem.syncWindowGeometry()
            }
        }
    }

    // GNOME glassmorphic theme palette matching kde_gnome_quicksetting exactly:
    readonly property color cardBackground: effectiveCardColor
    readonly property color surfaceBackground: isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color tileBackground: isDarkTheme ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color hoverBackground: isDarkTheme ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color cardBorder: isDarkTheme ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color rootBorder: {
        var alpha = Math.min(0.12, Math.max(0.04, 0.08 * effectiveBackgroundOpacity))
        return isDarkTheme ? Qt.rgba(1, 1, 1, alpha) : Qt.rgba(0, 0, 0, alpha)
    }
    readonly property color primaryText: isDarkTheme ? "#ffffff" : "#1a1a1a"
    readonly property color secondaryText: isDarkTheme ? "#9aa0a6" : "#606770"
    readonly property color accentColor: (Kirigami.Theme.highlightColor !== undefined && Kirigami.Theme.highlightColor.a > 0) ? Kirigami.Theme.highlightColor : "#3584e4"
    readonly property color accentTextColor: (Kirigami.Theme.highlightedTextColor !== undefined && Kirigami.Theme.highlightedTextColor.a > 0) ? Kirigami.Theme.highlightedTextColor : "#ffffff"
    readonly property color activeIconBg: Qt.rgba(1, 1, 1, 0.22)
    readonly property color inactiveIconBg: isDarkTheme ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color dangerColor: "#e01b24"
    readonly property color badgeColor: "#e01b24"

    // Notifications state
    property var rawNotifications: []
    property var groupedNotifications: []
    property int totalNotificationCount: rawNotifications.length
    property int unreadCount: 0
    property bool hasUnread: unreadCount > 0

    // Calendar & Agenda state
    property var agendaEvents: []
    property var currentSystemDate: new Date()
    property int todayDay: currentSystemDate.getDate()
    property int todayMonth: currentSystemDate.getMonth()
    property int todayYear: currentSystemDate.getFullYear()

    property var selectedDate: new Date()
    property int selectedDay: selectedDate.getDate()
    property int selectedMonth: selectedDate.getMonth()
    property int selectedYear: selectedDate.getFullYear()
    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()

    // Timezone state
    property string activeTimezone: "Local"
    property string timezoneOffset: ""
    property var timezoneList: []

    // Built-in Online Calendar Sync state
    property var syncAccountsList: []
    property var onlineAccountsList: syncAccountsList
    property bool isSyncingOnline: false
    property bool isSyncingOnlineAccount: isSyncingOnline
    property string lastSyncTime: Plasmoid.configuration.lastOnlineSyncTime || ""
    property string syncStatusMessage: ""

    // Helper: Safely escape arguments for POSIX shell
    function escapeShellArg(arg) {
        if (arg === undefined || arg === null) return "''"
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    // Helper: Resolve script path
    function getScriptPath(scriptName) {
        var base = Qt.resolvedUrl("../scripts/" + scriptName).toString()
        if (base.indexOf("file://") === 0) {
            base = base.substring(7)
        }
        return base
    }

    // Live native KDE Plasma notification model
    NotificationManager.Notifications {
        id: liveNotifs
        showExpired: true
        showDismissed: false
        showNotifications: true
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate

        onCountChanged: mainItem.syncLiveNotifications()
        onUnreadNotificationsCountChanged: {
            if (!mainItem.expanded && liveNotifs.unreadNotificationsCount !== undefined) {
                mainItem.unreadCount = liveNotifs.unreadNotificationsCount
            }
        }
        onRowsInserted: mainItem.syncLiveNotifications()
        onRowsRemoved: mainItem.syncLiveNotifications()
        onModelReset: mainItem.syncLiveNotifications()
        onDataChanged: mainItem.syncLiveNotifications()
    }

    // Native KDE TaskManager model for window detection, activation and maximization
    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        filterHidden: false
        filterMinimized: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    // Synchronize live Plasma notifications into unified UI model
    function syncLiveNotifications() {
        if (!liveNotifs) return
        var list = []
        var cnt = liveNotifs.count
        for (var i = 0; i < cnt; i++) {
            var idx = liveNotifs.index(i, 0)
            var nid = liveNotifs.data(idx, NotificationManager.Notifications.IdRole)
            var summary = liveNotifs.data(idx, NotificationManager.Notifications.SummaryRole) || ""
            var body = liveNotifs.data(idx, NotificationManager.Notifications.BodyRole) || ""
            var app = liveNotifs.data(idx, NotificationManager.Notifications.ApplicationNameRole) || "System"
            var appIcon = liveNotifs.data(idx, NotificationManager.Notifications.ApplicationIconNameRole) ||
                          liveNotifs.data(idx, NotificationManager.Notifications.IconNameRole) || "preferences-system"
            var created = liveNotifs.data(idx, NotificationManager.Notifications.CreatedRole)
            var timeStr = ""
            if (created) {
                try {
                    var dt = new Date(created)
                    if (!isNaN(dt.getTime())) {
                        timeStr = Qt.formatTime(dt, "HH:mm")
                    }
                } catch(e) {}
            }
            if (!timeStr) {
                timeStr = Qt.formatTime(new Date(), "HH:mm")
            }

            var actLabels = liveNotifs.data(idx, NotificationManager.Notifications.ActionLabelsRole) || []
            var actNames = liveNotifs.data(idx, NotificationManager.Notifications.ActionNamesRole) || []
            var actions = []
            if (Array.isArray(actLabels) && actLabels.length > 0) {
                actions = actLabels
            }

            var dEntry = liveNotifs.data(idx, NotificationManager.Notifications.DesktopEntryRole) || ""

            list.push({
                id: nid,
                app: app,
                appIcon: appIcon,
                desktopEntry: dEntry,
                summary: summary,
                body: body,
                time: timeStr,
                actions: actions,
                actionNames: actNames,
                modelIndex: i
            })
        }

        if (cnt > 0) {
            mainItem.rawNotifications = list
            mainItem.updateGroupedNotifications()
            if (liveNotifs.unreadNotificationsCount !== undefined) {
                mainItem.unreadCount = liveNotifs.unreadNotificationsCount
            } else {
                mainItem.unreadCount = list.length
            }
        } else {
            // Check fallback from notifications.sh
            execScript("notifications.sh", "list")
        }
    }

    // Executable DataEngine to run system scripts natively in Plasma 6
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var stdout = data["stdout"] ? data["stdout"].trim() : ""
            var stderr = data["stderr"] ? data["stderr"].trim() : ""
            disconnectSource(source)

            if (source.indexOf("calendar.sh") !== -1 && (source.indexOf("sync") !== -1 || source.indexOf("add_account") !== -1 || source.indexOf("update_account") !== -1 || source.indexOf("delete_account") !== -1)) {
                mainItem.isSyncingOnline = false
                mainItem.isSyncingOnlineAccount = false
                if (stderr && !stdout) {
                    mainItem.syncStatusMessage = stderr
                }
            }

            if (!stdout) return

            try {
                if (source.indexOf("notifications.sh") !== -1) {
                    var nList = JSON.parse(stdout)
                    if (Array.isArray(nList)) {
                        if (!liveNotifs || liveNotifs.count === 0) {
                            mainItem.rawNotifications = nList
                            mainItem.updateGroupedNotifications()
                            mainItem.unreadCount = nList.length
                        }
                    }
                } else if (source.indexOf("calendar.sh") !== -1 && source.indexOf("accounts") !== -1) {
                    var accList = JSON.parse(stdout)
                    if (Array.isArray(accList)) {
                        mainItem.syncAccountsList = accList
                        mainItem.onlineAccountsList = accList
                    }
                } else if (source.indexOf("calendar.sh") !== -1 && (source.indexOf("sync") !== -1 || source.indexOf("add_account") !== -1 || source.indexOf("update_account") !== -1 || source.indexOf("delete_account") !== -1)) {
                    var sRes = JSON.parse(stdout)
                    mainItem.isSyncingOnline = false
                    mainItem.isSyncingOnlineAccount = false
                    if (sRes) {
                        if (sRes.status === "success" || sRes.lastSynced) {
                            mainItem.lastSyncTime = sRes.lastSynced || Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")
                            Plasmoid.configuration.lastOnlineSyncTime = mainItem.lastSyncTime
                            if (sRes.syncedAccounts !== undefined) {
                                mainItem.syncStatusMessage = i18n("Synced %1 accounts (%2 events)", sRes.syncedAccounts, sRes.totalEvents || 0)
                            } else if (sRes.eventCount !== undefined) {
                                mainItem.syncStatusMessage = i18n("Synced %1 events", sRes.eventCount)
                            } else {
                                mainItem.syncStatusMessage = i18n("Calendar updated")
                            }
                        } else if (sRes.message) {
                            mainItem.syncStatusMessage = sRes.message
                        }
                    }
                    mainItem.fetchSyncAccounts()
                    mainItem.refreshAgenda()
                } else if (source.indexOf("calendar.sh") !== -1) {
                    var aList = JSON.parse(stdout)
                    if (Array.isArray(aList)) {
                        mainItem.agendaEvents = aList
                    }
                } else if (source.indexOf("timezone.sh") !== -1 && source.indexOf("detect") !== -1) {
                    var tz = JSON.parse(stdout)
                    if (tz.timezone) {
                        mainItem.activeTimezone = tz.timezone
                        mainItem.timezoneOffset = tz.offset || ""
                    }
                } else if (source.indexOf("timezone.sh") !== -1 && source.indexOf("list") !== -1) {
                    var tzList = JSON.parse(stdout)
                    if (Array.isArray(tzList)) {
                        mainItem.timezoneList = tzList
                    }
                }
            } catch (err) {
                console.warn("[CalendarNotifications] JSON parse error from source:", source, err)
            }
        }
    }

    // Helper: Execute a script command with robust shell argument escaping
    function execScript(scriptName, args) {
        var fullCmd = "bash " + escapeShellArg(getScriptPath(scriptName)) + (args ? " " + args : "")
        executable.connectSource(fullCmd)
    }

    // Group raw notifications by app dynamically
    function updateGroupedNotifications() {
        var map = {}
        var groups = []

        for (var i = 0; i < rawNotifications.length; i++) {
            var notif = rawNotifications[i]
            var appKey = notif.app || "System"
            if (!map[appKey]) {
                map[appKey] = {
                    appName: appKey,
                    appIcon: notif.appIcon || "preferences-system",
                    items: [],
                    count: 0
                }
                groups.push(map[appKey])
            }
            map[appKey].items.push(notif)
            map[appKey].count++
        }

        mainItem.groupedNotifications = groups
    }

    // Notification actions
    function refreshNotifications() {
        syncLiveNotifications()
        execScript("notifications.sh", "list")
    }

    function dismissNotification(id) {
        if (liveNotifs && liveNotifs.count > 0) {
            for (var i = 0; i < liveNotifs.count; i++) {
                var idx = liveNotifs.index(i, 0)
                var itemNid = liveNotifs.data(idx, NotificationManager.Notifications.IdRole)
                if (String(itemNid) === String(id)) {
                    liveNotifs.close(idx)
                    break
                }
            }
        }
        if (id !== undefined && id !== null) {
            execScript("notifications.sh", "dismiss " + escapeShellArg(id))
        }
    }

    function dismissGroup(appName) {
        if (liveNotifs && liveNotifs.count > 0) {
            for (var i = liveNotifs.count - 1; i >= 0; i--) {
                var idx = liveNotifs.index(i, 0)
                var itemApp = liveNotifs.data(idx, NotificationManager.Notifications.ApplicationNameRole) || "System"
                if (itemApp.toLowerCase() === String(appName).toLowerCase()) {
                    liveNotifs.close(idx)
                }
            }
        }
        if (appName) {
            execScript("notifications.sh", "dismiss_group " + escapeShellArg(appName))
        }
    }

    function clearAllNotifications() {
        if (liveNotifs && liveNotifs.count > 0) {
            try {
                liveNotifs.clear(NotificationManager.Notifications.ClearExpired)
            } catch (e) {}
            for (var i = liveNotifs.count - 1; i >= 0; i--) {
                var idx = liveNotifs.index(i, 0)
                liveNotifs.close(idx)
            }
        }
        execScript("notifications.sh", "clear_all")
        mainItem.unreadCount = 0
        mainItem.rawNotifications = []
        mainItem.groupedNotifications = []
    }

    // Reset calendar selection to today
    function resetToToday() {
        var now = new Date()
        mainItem.currentSystemDate = now
        mainItem.todayDay = now.getDate()
        mainItem.todayMonth = now.getMonth()
        mainItem.todayYear = now.getFullYear()
        mainItem.selectedDay = now.getDate()
        mainItem.selectedMonth = now.getMonth()
        mainItem.selectedYear = now.getFullYear()
        mainItem.selectedDate = now
        mainItem.currentMonth = now.getMonth()
        mainItem.currentYear = now.getFullYear()
    }

    function openDesktopApp(desktopEntry, appName) {
        var d = escapeShellArg(desktopEntry || "")
        var a = escapeShellArg(appName || "")
        execScript("notifications.sh", "open_app " + d + " " + a)
    }

    // Unminimize, maximize, and activate existing application window natively
    function activateOrMaximizeApp(desktopEntry, appName) {
        function normStr(s) {
            if (!s) return ""
            return String(s).toLowerCase().replace(/\.desktop$/, "").trim()
        }
        function getBase(s) {
            var n = normStr(s)
            if (!n) return ""
            var parts = n.split(".")
            return parts[parts.length - 1]
        }

        var dEntry = normStr(desktopEntry)
        var aName = normStr(appName)
        var dBase = getBase(desktopEntry)

        var genericBlacklist = [
            "app", "apps", "daemon", "service", "helper", "system", "desktop",
            "org", "com", "net", "io", "kde", "wayland", "x11", "bin", "client",
            "gui", "ui", "kcm", "window", "settings", "preferences", "default", "tool"
        ]
        function isGeneric(term) {
            if (!term || term.length < 3) return true
            return genericBlacklist.indexOf(term.toLowerCase()) !== -1
        }

        var isKdeConnectSearch = (dEntry.indexOf("kdeconnect") !== -1 || aName.indexOf("kdeconnect") !== -1 || aName.indexOf("kde connect") !== -1)
        var isKdeConnectSms = isKdeConnectSearch && (dEntry.indexOf("sms") !== -1 || aName.indexOf("sms") !== -1)

        if (typeof tasksModel !== "undefined" && tasksModel && tasksModel.count > 0) {
            for (var i = 0; i < tasksModel.count; ++i) {
                var modelIdx = tasksModel.makeModelIndex(i)
                var rawAppId = String(tasksModel.data(modelIdx, TaskManager.AbstractTasksModel.AppId) || "")
                var appId = normStr(rawAppId)
                var rawAppName = String(tasksModel.data(modelIdx, TaskManager.AbstractTasksModel.AppName) || "")
                var tAppName = normStr(rawAppName)
                var appBase = getBase(rawAppId)

                var match = false

                if (isKdeConnectSearch) {
                    if (isKdeConnectSms) {
                        // Strict matching for KDE Connect SMS
                        if (appId === "org.kde.kdeconnect.sms" || appId === "kdeconnect-sms" || appId === "kdeconnect.sms" ||
                            tAppName.indexOf("kde connect sms") !== -1 || tAppName.indexOf("sms messages") !== -1) {
                            match = true
                        }
                    } else {
                        // Strict matching for KDE Connect general/app
                        var isSmsWin = (appId.indexOf("sms") !== -1 || tAppName.indexOf("sms") !== -1)
                        if (!isSmsWin && (appId === "org.kde.kdeconnect.app" || appId === "kdeconnect-app" || appId === "kdeconnect.app" ||
                            tAppName === "kde connect" || tAppName === "kdeconnect")) {
                            match = true
                        }
                    }
                    if (!match) {
                        continue
                    }
                } else {
                    // General Applications matching:
                    // 1. Exact AppId match
                    if (dEntry && appId && (dEntry === appId || dEntry + ".desktop" === rawAppId.toLowerCase() || appId + ".desktop" === dEntry)) {
                        match = true
                    }
                    // 2. Exact AppName match
                    else if (aName && tAppName && (aName === tAppName)) {
                        match = true
                    }
                    // 3. Basename match ONLY IF non-generic and length >= 4
                    else if (!isGeneric(dBase) && !isGeneric(appBase) && dBase.length >= 4 && appBase.length >= 4 && dBase === appBase) {
                        match = true
                    }
                    // 4. Substring in AppId ONLY IF non-generic and length >= 4
                    else if (!isGeneric(dBase) && dBase.length >= 4 && (appId.indexOf("." + dBase) !== -1 || appId.indexOf(dBase + ".") !== -1 || appId === dBase)) {
                        match = true
                    }
                    // 5. Delimited match in AppName ONLY IF non-generic and length >= 4
                    else if (!isGeneric(aName) && aName.length >= 4 && (tAppName.indexOf(aName) !== -1 || aName.indexOf(tAppName) !== -1)) {
                        match = true
                    }
                }

                if (match) {
                    // Application is ALREADY open!
                    // 1. Unminimize if minimized
                    var isMin = tasksModel.data(modelIdx, TaskManager.AbstractTasksModel.IsMinimized)
                    if (isMin) {
                        tasksModel.requestToggleMinimized(modelIdx)
                    }

                    // 2. Maximize window if not already maximized
                    var isMax = tasksModel.data(modelIdx, TaskManager.AbstractTasksModel.IsMaximized)
                    var canMax = tasksModel.data(modelIdx, TaskManager.AbstractTasksModel.IsMaximizable)
                    if (!isMax && canMax) {
                        tasksModel.requestToggleMaximized(modelIdx)
                    }

                    // 3. Raise and activate window to top
                    tasksModel.requestActivate(modelIdx)
                    return true
                }
            }
        }
        return false
    }

    function closePopup() {
        if (typeof mainItem !== "undefined" && typeof mainItem.expanded !== "undefined") {
            mainItem.expanded = false
        }
    }

    property var delayedMaximizeTarget: null
    Timer {
        id: delayedMaximizeTimer
        interval: 650
        repeat: false
        onTriggered: {
            if (mainItem.delayedMaximizeTarget) {
                mainItem.activateOrMaximizeApp(mainItem.delayedMaximizeTarget.entry, mainItem.delayedMaximizeTarget.name)
                mainItem.delayedMaximizeTarget = null
            }
        }
    }

    // Handles application presentation without opening duplicate sessions
    function activateOrOpenApp(desktopEntry, appName) {
        // 1. If application is already open, unminimize, maximize, and raise it
        if (activateOrMaximizeApp(desktopEntry, appName)) {
            closePopup()
            return
        }

        // 2. If no window exists, only then launch the application
        openDesktopApp(desktopEntry, appName)
        closePopup()

        // 3. Schedule maximize for newly created window once ready
        delayedMaximizeTarget = { entry: desktopEntry, name: appName }
        delayedMaximizeTimer.restart()
    }

    function invokeNotificationAction(id, actionIndex) {
        var targetEntry = ""
        var targetApp = ""
        var targetSummary = ""
        var targetBody = ""
        var targetUrls = []
        var targetActNames = []
        var hasDefault = false
        var foundModelIdx = null

        if (liveNotifs && liveNotifs.count > 0) {
            for (var i = 0; i < liveNotifs.count; i++) {
                var idx = liveNotifs.index(i, 0)
                var itemNid = liveNotifs.data(idx, NotificationManager.Notifications.IdRole)
                if (String(itemNid) === String(id)) {
                    foundModelIdx = idx
                    targetEntry = liveNotifs.data(idx, NotificationManager.Notifications.DesktopEntryRole) || ""
                    targetApp = liveNotifs.data(idx, NotificationManager.Notifications.ApplicationNameRole) || ""
                    targetSummary = liveNotifs.data(idx, NotificationManager.Notifications.SummaryRole) || ""
                    targetBody = liveNotifs.data(idx, NotificationManager.Notifications.BodyRole) || ""
                    targetUrls = liveNotifs.data(idx, NotificationManager.Notifications.UrlsRole) || []
                    targetActNames = liveNotifs.data(idx, NotificationManager.Notifications.ActionNamesRole) || []
                    hasDefault = !!liveNotifs.data(idx, NotificationManager.Notifications.HasDefaultActionRole)
                    break
                }
            }
        }

        // Fallback for raw / stored notifications if not in liveNotifs
        if (foundModelIdx === null) {
            for (var r = 0; r < rawNotifications.length; r++) {
                if (String(rawNotifications[r].id) === String(id)) {
                    targetEntry = rawNotifications[r].desktopEntry || ""
                    targetApp = rawNotifications[r].app || ""
                    targetSummary = rawNotifications[r].summary || ""
                    targetBody = rawNotifications[r].body || ""
                    targetActNames = rawNotifications[r].actionNames || []
                    break
                }
            }
        }

        var normEntry = String(targetEntry || "").toLowerCase()
        var normAppName = String(targetApp || "").toLowerCase()
        var normSumm = String(targetSummary || "").toLowerCase()
        var normBody = String(targetBody || "").toLowerCase()

        var isKdc = (normEntry.indexOf("kdeconnect") !== -1 || normAppName.indexOf("kdeconnect") !== -1 || normAppName.indexOf("kde connect") !== -1)
        var isKdcSms = isKdc && (
            normEntry.indexOf("sms") !== -1 ||
            normAppName.indexOf("sms") !== -1 ||
            normAppName.indexOf("message") !== -1 ||
            normSumm.indexOf("sms") !== -1 ||
            normSumm.indexOf("message") !== -1 ||
            normBody.indexOf("sms") !== -1 ||
            (Array.isArray(targetActNames) && (targetActNames.indexOf("reply") !== -1 || targetActNames.indexOf("Reply") !== -1 || targetActNames.indexOf("send-sms") !== -1))
        )

        // Route KDE Connect notifications accurately
        if (isKdc) {
            if (isKdcSms) {
                targetEntry = "org.kde.kdeconnect.sms"
                targetApp = "KDE Connect SMS"
            } else if (normAppName && normAppName !== "kde connect" && normAppName !== "kdeconnect" && normAppName !== "system") {
                // Forwarded notification from a phone app (e.g., WhatsApp, Telegram)
                // Keep targetApp as the phone app name, but clear targetEntry so we don't open kdeconnect-app
                targetEntry = ""
            } else {
                targetEntry = "org.kde.kdeconnect.app"
                targetApp = "KDE Connect"
            }
        }

        // 1. Invoke native notification action via NotificationManager if live
        if (foundModelIdx !== null) {
            var closeBehavior = (NotificationManager.Notifications && NotificationManager.Notifications.Close !== undefined) ? NotificationManager.Notifications.Close : 1

            if (actionIndex >= 0) {
                var actNames = liveNotifs.data(foundModelIdx, NotificationManager.Notifications.ActionNamesRole)
                if (actNames && actNames[actionIndex]) {
                    liveNotifs.invokeAction(foundModelIdx, actNames[actionIndex], closeBehavior)
                }
            } else if (hasDefault || (Array.isArray(targetActNames) && targetActNames.indexOf("default") !== -1)) {
                liveNotifs.invokeDefaultAction(foundModelIdx, closeBehavior)
            } else if (Array.isArray(targetActNames) && targetActNames.length > 0) {
                var targetAct = targetActNames[0]
                for (var a = 0; a < targetActNames.length; a++) {
                    var lowerAct = String(targetActNames[a]).toLowerCase()
                    if (lowerAct === "open" || lowerAct === "show" || lowerAct === "view" || lowerAct === "activate") {
                        targetAct = targetActNames[a]
                        break
                    }
                }
                liveNotifs.invokeAction(foundModelIdx, targetAct, closeBehavior)
            } else {
                liveNotifs.invokeDefaultAction(foundModelIdx, closeBehavior)
            }
        }

        // 2. Open associated URLs if any (e.g. downloaded files, photos, transfers)
        if (targetUrls && targetUrls.length > 0) {
            for (var u = 0; u < targetUrls.length; u++) {
                Qt.openUrlExternally(targetUrls[u])
            }
            closePopup()
            return
        }

        // 3. For app presentation:
        // If an existing window for this application is already open, unminimize, maximize, and raise it
        // If not already open, launch the intended desktop application
        if (targetEntry || targetApp) {
            activateOrOpenApp(targetEntry, targetApp)
        } else {
            closePopup()
        }
    }

    function openNotification(id) {
        invokeNotificationAction(id, -1)
    }

    // Calendar actions
    function refreshAgenda() {
        execScript("calendar.sh", "list")
    }

    function addEvent(title, day, month, year, time) {
        var safeTitle = escapeShellArg(title || "Event")
        var safeDay = parseInt(day, 10) || 1
        var safeMonth = parseInt(month, 10) || 1
        var safeYear = parseInt(year, 10) || new Date().getFullYear()
        var safeTime = escapeShellArg(time || "All Day")
        execScript("calendar.sh", "add " + safeTitle + " " + safeDay + " " + safeMonth + " " + safeYear + " " + safeTime)
    }

    function deleteEvent(id) {
        if (id !== undefined && id !== null) {
            execScript("calendar.sh", "delete " + escapeShellArg(id))
        }
    }

    // Built-in Online Calendar Sync actions
    function fetchSyncAccounts() {
        execScript("calendar.sh", "accounts")
    }

    function addSyncAccount(name, provider, url, color, username, password) {
        mainItem.isSyncingOnline = true
        mainItem.syncStatusMessage = i18n("Adding & syncing...")
        var n = escapeShellArg(name || "Calendar")
        var p = escapeShellArg(provider || "google")
        var u = escapeShellArg(url || "")
        var c = escapeShellArg(color || "#3584e4")
        var user = escapeShellArg(username || "")
        var pass = escapeShellArg(password || "")
        execScript("calendar.sh", "add_account " + n + " " + p + " " + u + " " + c + " " + user + " " + pass)
    }

    function updateSyncAccount(accountId, name, url, color, enabled, username, password) {
        var idArg = escapeShellArg(accountId || "")
        var nArg = escapeShellArg(name || "")
        var uArg = escapeShellArg(url || "")
        var cArg = escapeShellArg(color || "")
        var eArg = (enabled !== undefined && enabled !== null) ? (enabled ? "true" : "false") : "true"
        var user = escapeShellArg(username || "")
        var pass = escapeShellArg(password || "")
        execScript("calendar.sh", "update_account " + idArg + " " + nArg + " " + uArg + " " + cArg + " " + eArg + " " + user + " " + pass)
    }

    function deleteSyncAccount(accountId) {
        if (accountId !== undefined && accountId !== null) {
            execScript("calendar.sh", "delete_account " + escapeShellArg(accountId))
        }
    }

    function syncAllAccounts() {
        mainItem.isSyncingOnline = true
        mainItem.syncStatusMessage = i18n("Syncing calendars...")
        execScript("calendar.sh", "sync_all")
    }

    function syncSingleAccount(accountId) {
        mainItem.isSyncingOnline = true
        mainItem.syncStatusMessage = i18n("Syncing...")
        execScript("calendar.sh", "sync " + escapeShellArg(accountId))
    }

    // Backwards-compatibility aliases
    function fetchOnlineAccounts() { fetchSyncAccounts() }
    function syncOnlineAccount(accountId) {
        if (accountId) syncSingleAccount(accountId)
        else syncAllAccounts()
    }
    function openOnlineAccountsSettings() {
        Qt.openUrlExternally("kcm:kcm_konlineaccounts")
    }

    // Timezone actions
    function detectTimezone() {
        if (!Plasmoid.configuration.autoDetectTimezone && Plasmoid.configuration.selectedTimezone && Plasmoid.configuration.selectedTimezone !== "Local") {
            execScript("timezone.sh", "detect " + escapeShellArg(Plasmoid.configuration.selectedTimezone))
        } else {
            execScript("timezone.sh", "detect")
        }
    }

    function refreshTimezones() {
        execScript("timezone.sh", "list")
    }

    // Reactive listener for configuration changes
    Connections {
        target: Plasmoid.configuration
        function onSelectedTimezoneChanged() {
            mainItem.detectTimezone()
        }
        function onAutoDetectTimezoneChanged() {
            mainItem.detectTimezone()
        }
        function onPanelBackgroundModeChanged() {
            mainItem.panelBackgroundMode = Plasmoid.configuration.panelBackgroundMode
        }
        function onCustomOpacityChanged() {
            mainItem.customOpacity = Plasmoid.configuration.customOpacity
        }
        function onPanelBlurEnabledChanged() {
            mainItem.panelBlurEnabled = Plasmoid.configuration.panelBlurEnabled
        }
    }

    // Clear unread count and reset calendar to today when widget is opened by user
    onExpandedChanged: {
        if (mainItem.expanded) {
            mainItem.resetToToday()
            mainItem.unreadCount = 0
            mainItem.refreshNotifications()
            mainItem.refreshAgenda()
            mainItem.fetchSyncAccounts()
            if (Plasmoid.configuration.autoSyncOnlineAccount) {
                mainItem.syncAllAccounts()
            }
        }
    }

    // Periodic poll timer (every 15s to check for new notifications & update time)
    Timer {
        id: pollTimer
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            mainItem.refreshNotifications()
        }
    }

    // Safety timer to prevent stuck syncing animation
    Timer {
        id: syncTimeoutTimer
        interval: 12000
        running: mainItem.isSyncingOnline
        repeat: false
        onTriggered: {
            mainItem.isSyncingOnline = false
            mainItem.isSyncingOnlineAccount = false
        }
    }

    // Periodic Online Calendar Sync Timer (every 30 minutes if enabled)
    Timer {
        id: onlineSyncTimer
        interval: (Plasmoid.configuration.onlineAccountSyncInterval > 0 ? Plasmoid.configuration.onlineAccountSyncInterval : 30) * 60 * 1000
        running: Plasmoid.configuration.autoSyncOnlineAccount
        repeat: true
        onTriggered: {
            mainItem.syncAllAccounts()
        }
    }

    // Exact second timer for system clock, midnight rollover, and calendar date sync
    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            mainItem.currentSystemDate = now
            var nDay = now.getDate()
            var nMonth = now.getMonth()
            var nYear = now.getFullYear()

            if (nDay !== mainItem.todayDay || nMonth !== mainItem.todayMonth || nYear !== mainItem.todayYear) {
                // Midnight passed! Automatically advance today and reset calendar to the new day
                mainItem.todayDay = nDay
                mainItem.todayMonth = nMonth
                mainItem.todayYear = nYear
                mainItem.resetToToday()
            }
        }
    }

    Component.onCompleted: {
        syncLiveNotifications()
        refreshAgenda()
        detectTimezone()
        refreshTimezones()
        fetchSyncAccounts()
        if (Plasmoid.configuration.autoSyncOnlineAccount) {
            syncAllAccounts()
        }
        mainItem.unreadCount = (liveNotifs && liveNotifs.unreadNotificationsCount !== undefined) ? liveNotifs.unreadNotificationsCount : rawNotifications.length
    }
}
