import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

/**
 * CalendarView.qml - Interactive Calendar & Day Agenda for KDE Plasma 6
 * Supporting interactive month grid, today highlight, day selection, and dynamic events.
 */
Rectangle {
    id: calRoot

    color: "transparent"
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Reference to mainItem backend passed from FullRepresentation
    property var backend: (typeof mainItem !== "undefined") ? mainItem : null

    readonly property bool isDarkTheme: backend ? backend.isDarkTheme : true
    readonly property color cardBackground: backend ? backend.cardBackground : (isDarkTheme ? "#1e1e24" : "#f0f2f5")
    readonly property color surfaceBackground: backend ? backend.surfaceBackground : (isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04))
    readonly property color tileBackground: backend ? backend.tileBackground : (isDarkTheme ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06))
    readonly property color hoverBackground: backend ? backend.hoverBackground : (isDarkTheme ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09))
    readonly property color cardBorder: backend ? backend.cardBorder : (isDarkTheme ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(0, 0, 0, 0.08))
    readonly property color primaryText: backend ? backend.primaryText : (isDarkTheme ? "#ffffff" : "#1a1a1a")
    readonly property color secondaryText: backend ? backend.secondaryText : (isDarkTheme ? "#9aa0a6" : "#606770")
    readonly property color accentColor: backend ? backend.accentColor : "#3584e4"
    readonly property color accentTextColor: backend ? backend.accentTextColor : "#ffffff"
    readonly property color dangerColor: backend ? backend.dangerColor : "#e01b24"

    readonly property real resolutionScale: (typeof fullRoot !== "undefined" && fullRoot && fullRoot.resolutionScale) ? fullRoot.resolutionScale : 1.15

    property var currentSystemDate: (backend && backend.currentSystemDate) ? backend.currentSystemDate : new Date()
    property int todayDay: (backend && backend.todayDay !== undefined) ? backend.todayDay : new Date().getDate()
    property int todayMonth: (backend && backend.todayMonth !== undefined) ? backend.todayMonth : new Date().getMonth()
    property int todayYear: (backend && backend.todayYear !== undefined) ? backend.todayYear : new Date().getFullYear()

    property int selectedDay: (backend && backend.selectedDay !== undefined) ? backend.selectedDay : todayDay
    property int selectedMonth: (backend && backend.selectedMonth !== undefined) ? backend.selectedMonth : todayMonth
    property int selectedYear: (backend && backend.selectedYear !== undefined) ? backend.selectedYear : todayYear
    property var selectedDate: (backend && backend.selectedDate) ? backend.selectedDate : new Date()

    property int displayMonth: (backend && backend.currentMonth !== undefined) ? backend.currentMonth : todayMonth
    property int displayYear: (backend && backend.currentYear !== undefined) ? backend.currentYear : todayYear
    property bool showAddEventBar: false

    readonly property var monthNames: [
        i18n("January"), i18n("February"), i18n("March"), i18n("April"),
        i18n("May"), i18n("June"), i18n("July"), i18n("August"),
        i18n("September"), i18n("October"), i18n("November"), i18n("December")
    ]
    readonly property var dayHeaders: [
        i18n("Mo"), i18n("Tu"), i18n("We"), i18n("Th"),
        i18n("Fr"), i18n("Sa"), i18n("Su")
    ]

    function isToday(d, m, y) {
        return d === todayDay && m === todayMonth && y === todayYear
    }

    function isSelected(d, m, y) {
        return d === selectedDay && m === selectedMonth && y === selectedYear
    }

    function selectDate(d, m, y) {
        selectedDay = d
        selectedMonth = m
        selectedYear = y
        selectedDate = new Date(y, m, d)
        if (backend) {
            backend.selectedDay = d
            backend.selectedMonth = m
            backend.selectedYear = y
            backend.selectedDate = selectedDate
            backend.currentMonth = m
            backend.currentYear = y
        }
        if (m !== displayMonth || y !== displayYear) {
            displayMonth = m
            displayYear = y
        }
    }

    function goToToday() {
        var now = new Date()
        calRoot.currentSystemDate = now
        calRoot.todayDay = now.getDate()
        calRoot.todayMonth = now.getMonth()
        calRoot.todayYear = now.getFullYear()

        calRoot.selectDate(now.getDate(), now.getMonth(), now.getFullYear())
        calRoot.displayMonth = now.getMonth()
        calRoot.displayYear = now.getFullYear()

        if (backend && typeof backend.resetToToday === "function") {
            backend.resetToToday()
        }
        calRoot.daysList = calRoot.generateDays()
    }

    function hasEvent(d, m, y) {
        var events = (backend && backend.agendaEvents) ? backend.agendaEvents : []
        for (var i = 0; i < events.length; i++) {
            var ev = events[i]
            if (parseInt(ev.day, 10) === parseInt(d, 10) &&
                parseInt(ev.month, 10) === parseInt(m + 1, 10) &&
                parseInt(ev.year, 10) === parseInt(y, 10)) {
                return true
            }
        }
        return false
    }

    function nextMonth() {
        if (displayMonth === 11) {
            displayMonth = 0
            displayYear++
        } else {
            displayMonth++
        }
    }

    function prevMonth() {
        if (displayMonth === 0) {
            displayMonth = 11
            displayYear--
        } else {
            displayMonth--
        }
    }

    Connections {
        target: backend
        ignoreUnknownSignals: true
        function onTodayDayChanged() {
            if (backend) {
                calRoot.todayDay = backend.todayDay
                calRoot.todayMonth = backend.todayMonth
                calRoot.todayYear = backend.todayYear
                calRoot.daysList = calRoot.generateDays()
            }
        }
        function onSelectedDayChanged() {
            if (backend) {
                calRoot.selectedDay = backend.selectedDay
                calRoot.selectedMonth = backend.selectedMonth
                calRoot.selectedYear = backend.selectedYear
                if (backend.selectedDate) calRoot.selectedDate = backend.selectedDate
            }
        }
        function onSelectedDateChanged() {
            if (backend && backend.selectedDate) {
                calRoot.selectedDate = backend.selectedDate
                if (backend.selectedDay !== undefined) calRoot.selectedDay = backend.selectedDay
                if (backend.selectedMonth !== undefined) calRoot.selectedMonth = backend.selectedMonth
                if (backend.selectedYear !== undefined) calRoot.selectedYear = backend.selectedYear
                if (backend.currentMonth !== undefined) calRoot.displayMonth = backend.currentMonth
                if (backend.currentYear !== undefined) calRoot.displayYear = backend.currentYear
            }
        }
        function onCurrentMonthChanged() {
            if (backend && backend.currentMonth !== undefined) {
                calRoot.displayMonth = backend.currentMonth
                calRoot.daysList = calRoot.generateDays()
            }
        }
        function onCurrentYearChanged() {
            if (backend && backend.currentYear !== undefined) {
                calRoot.displayYear = backend.currentYear
                calRoot.daysList = calRoot.generateDays()
            }
        }
        function onExpandedChanged() {
            if (backend && backend.expanded) {
                calRoot.goToToday()
            }
        }
        function onAgendaEventsChanged() {
            calRoot.daysList = calRoot.generateDays()
        }
    }

    onVisibleChanged: {
        if (visible) {
            calRoot.goToToday()
        }
    }

    Component.onCompleted: {
        calRoot.goToToday()
    }

    // Calculate calendar grid days for month (6 rows of 7 days = 42 cells)
    function generateDays() {
        var firstDayOfWeek = new Date(displayYear, displayMonth, 1).getDay()
        // Convert JS Sunday=0 to Monday=0
        var startIndex = (firstDayOfWeek === 0) ? 6 : (firstDayOfWeek - 1)
        var daysInCurrentMonth = new Date(displayYear, displayMonth + 1, 0).getDate()
        var daysInPrevMonth = new Date(displayYear, displayMonth, 0).getDate()

        var days = []

        // Previous month filler days
        for (var p = startIndex - 1; p >= 0; p--) {
            var pDay = daysInPrevMonth - p
            var pMonth = (displayMonth === 0) ? 11 : (displayMonth - 1)
            var pYear = (displayMonth === 0) ? (displayYear - 1) : displayYear
            days.push({ day: pDay, month: pMonth, year: pYear, isCurrentMonth: false })
        }

        // Current month days
        for (var c = 1; c <= daysInCurrentMonth; c++) {
            days.push({ day: c, month: displayMonth, year: displayYear, isCurrentMonth: true })
        }

        // Next month filler days to complete 42 cells
        var nextDay = 1
        var nMonth = (displayMonth === 11) ? 0 : (displayMonth + 1)
        var nYear = (displayMonth === 11) ? (displayYear + 1) : displayYear
        while (days.length < 42) {
            days.push({ day: nextDay, month: nMonth, year: nYear, isCurrentMonth: false })
            nextDay++
        }

        return days
    }

    property var daysList: generateDays()

    onDisplayMonthChanged: daysList = generateDays()
    onDisplayYearChanged: daysList = generateDays()

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // --- 1. Month / Year Header & Navigation Bar ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                spacing: 0
                Text {
                    text: calRoot.monthNames[calRoot.displayMonth] + " " + calRoot.displayYear
                    color: calRoot.primaryText
                    font.pixelSize: Math.max(16, Math.round(18 * calRoot.resolutionScale))
                    font.bold: true
                }
                Text {
                    text: Qt.formatDate(calRoot.selectedDate, "dddd, MMMM d, yyyy")
                    color: calRoot.secondaryText
                    font.pixelSize: Math.max(10, Math.round(11 * calRoot.resolutionScale))
                }
            }

            Item { Layout.fillWidth: true }

            // "Today" Button
            Rectangle {
                implicitWidth: todayText.implicitWidth + Math.round(16 * calRoot.resolutionScale)
                implicitHeight: Math.round(28 * calRoot.resolutionScale)
                radius: implicitHeight / 2
                color: todayMouse.containsMouse ? (calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)) : (calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07))
                border.color: calRoot.cardBorder
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    id: todayText
                    anchors.centerIn: parent
                    text: i18n("Today")
                    color: calRoot.accentColor
                    font.pixelSize: Math.max(10, Math.round(11 * calRoot.resolutionScale))
                    font.bold: true
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calRoot.goToToday()
                }
            }

            // Previous Month Button
            Rectangle {
                width: Math.round(32 * calRoot.resolutionScale)
                height: Math.round(32 * calRoot.resolutionScale)
                radius: width / 2
                color: prevMouse.containsMouse ? (calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.1)) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.max(14, Math.round(16 * calRoot.resolutionScale))
                    height: Math.max(14, Math.round(16 * calRoot.resolutionScale))
                    source: "go-previous-symbolic"
                    isMask: true
                    color: calRoot.primaryText
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calRoot.prevMonth()
                }
            }

            // Next Month Button
            Rectangle {
                width: Math.round(32 * calRoot.resolutionScale)
                height: Math.round(32 * calRoot.resolutionScale)
                radius: width / 2
                color: nextMouse.containsMouse ? (calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.1)) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.max(14, Math.round(16 * calRoot.resolutionScale))
                    height: Math.max(14, Math.round(16 * calRoot.resolutionScale))
                    source: "go-next-symbolic"
                    isMask: true
                    color: calRoot.primaryText
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calRoot.nextMonth()
                }
            }
        }

        // --- 2. Days of the Week Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: calRoot.dayHeaders
                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(24 * calRoot.resolutionScale)

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: (index >= 5) ? calRoot.accentColor : calRoot.secondaryText
                        font.pixelSize: Math.max(10, Math.round(11 * calRoot.resolutionScale))
                        font.bold: true
                    }
                }
            }
        }

        // --- 3. Interactive Month Grid (6x7 = 42 cells) ---
        GridLayout {
            id: monthGrid
            Layout.fillWidth: true
            columns: 7
            rowSpacing: Math.round(4 * calRoot.resolutionScale)
            columnSpacing: Math.round(4 * calRoot.resolutionScale)

            Repeater {
                model: calRoot.daysList

                Rectangle {
                    id: cellRect
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * calRoot.resolutionScale)
                    radius: implicitHeight / 2

                    readonly property var dItem: modelData
                    readonly property bool isCurrent: dItem.isCurrentMonth
                    readonly property bool todayMatch: calRoot.isToday(dItem.day, dItem.month, dItem.year)
                    readonly property bool selectedMatch: calRoot.isSelected(dItem.day, dItem.month, dItem.year)
                    readonly property bool eventMatch: calRoot.hasEvent(dItem.day, dItem.month, dItem.year)

                    color: {
                        if (todayMatch && selectedMatch) {
                            return calRoot.accentColor
                        }
                        if (selectedMatch) {
                            return calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
                        }
                        if (todayMatch) {
                            return calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
                        }
                        if (cellMouse.containsMouse) {
                            return calRoot.hoverBackground
                        }
                        return "transparent"
                    }

                    border.color: {
                        if (todayMatch && !selectedMatch) {
                            return calRoot.accentColor
                        }
                        if (selectedMatch && !todayMatch) {
                            return calRoot.isDarkTheme ? Qt.rgba(255, 255, 255, 0.28) : Qt.rgba(0, 0, 0, 0.22)
                        }
                        return "transparent"
                    }
                    border.width: (todayMatch && !selectedMatch) ? 1.5 : 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            text: dItem.day.toString()
                            color: {
                                if (todayMatch && selectedMatch) return calRoot.accentTextColor
                                if (todayMatch) return calRoot.accentColor
                                if (selectedMatch) return calRoot.primaryText
                                if (!isCurrent) return calRoot.secondaryText
                                return calRoot.primaryText
                            }
                            opacity: isCurrent ? 1.0 : 0.35
                            font.pixelSize: 12
                            font.bold: (todayMatch || selectedMatch)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Event Indicator Dot
                        Rectangle {
                            visible: eventMatch
                            width: 4
                            height: 4
                            radius: 2
                            color: (todayMatch && selectedMatch) ? calRoot.accentTextColor : calRoot.accentColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calRoot.selectDate(dItem.day, dItem.month, dItem.year)
                        }
                    }
                }
            }
        }

        // --- 4. Agenda / Selected Day Events Section ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: calRoot.surfaceBackground
            border.color: calRoot.cardBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Agenda Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Kirigami.Icon {
                        width: 14
                        height: 14
                        source: "view-calendar-upcoming-events"
                        isMask: true
                        color: calRoot.accentColor
                    }

                    Text {
                        text: i18n("Agenda")
                        color: calRoot.primaryText
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: "(" + Qt.formatDate(calRoot.selectedDate, "MMM d") + ")"
                        color: calRoot.secondaryText
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    // Sync with Online Accounts button
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: syncMouse.containsMouse ? calRoot.hoverBackground : "transparent"

                        Kirigami.Icon {
                            id: syncIcon
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: (calRoot.backend && (calRoot.backend.isSyncingOnline || calRoot.backend.isSyncingOnlineAccount)) ? "view-refresh" : "cloud-download-symbolic"
                            isMask: true
                            color: (calRoot.backend && calRoot.backend.syncAccountsList && calRoot.backend.syncAccountsList.length > 0) ? calRoot.accentColor : calRoot.secondaryText

                            RotationAnimator on rotation {
                                running: calRoot.backend && (calRoot.backend.isSyncingOnline || calRoot.backend.isSyncingOnlineAccount)
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1000
                            }
                        }

                        MouseArea {
                            id: syncMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calRoot.daysList = calRoot.generateDays()
                                if (calRoot.backend) {
                                    calRoot.backend.refreshAgenda()
                                    if (calRoot.backend.syncAccountsList && calRoot.backend.syncAccountsList.length > 0) {
                                        calRoot.backend.syncAllAccounts()
                                    }
                                }
                            }
                        }
                    }

                    // Add Quick Reminder / Event button
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: addMouse.containsMouse ? calRoot.hoverBackground : "transparent"

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: calRoot.showAddEventBar ? "window-close-symbolic" : "list-add-symbolic"
                            isMask: true
                            color: calRoot.accentColor
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calRoot.showAddEventBar = !calRoot.showAddEventBar
                            }
                        }
                    }
                }

                // Inline Event Creation Input Bar
                Rectangle {
                    visible: calRoot.showAddEventBar
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 12
                    color: calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
                    border.color: calRoot.cardBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        TextField {
                            id: newEventInput
                            Layout.fillWidth: true
                            placeholderText: i18n("New event or reminder...")
                            font.pixelSize: 11
                            color: calRoot.primaryText
                            background: Rectangle {
                                color: "transparent"
                            }
                            onAccepted: {
                                var txt = newEventInput.text.trim()
                                if (txt.length > 0 && calRoot.backend && typeof calRoot.backend.addEvent === "function") {
                                    calRoot.backend.addEvent(txt, calRoot.selectedDate.getDate(), calRoot.selectedDate.getMonth() + 1, calRoot.selectedDate.getFullYear(), "All Day")
                                    newEventInput.text = ""
                                    calRoot.showAddEventBar = false
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: addBtnText.implicitWidth + 14
                            implicitHeight: 26
                            radius: 8
                            color: calRoot.accentColor

                            Text {
                                id: addBtnText
                                anchors.centerIn: parent
                                text: i18n("Add")
                                color: calRoot.accentTextColor
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var txt = newEventInput.text.trim()
                                    if (txt.length > 0 && calRoot.backend && typeof calRoot.backend.addEvent === "function") {
                                        calRoot.backend.addEvent(txt, calRoot.selectedDate.getDate(), calRoot.selectedDate.getMonth() + 1, calRoot.selectedDate.getFullYear(), "All Day")
                                        newEventInput.text = ""
                                        calRoot.showAddEventBar = false
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: cancelMouse.containsMouse ? calRoot.hoverBackground : "transparent"

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: "window-close-symbolic"
                                isMask: true
                                color: calRoot.secondaryText
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    calRoot.showAddEventBar = false
                                }
                            }
                        }
                    }
                }

                // Agenda Items List
                ListView {
                    id: agendaList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6

                    model: {
                        var filtered = []
                        var selDay = calRoot.selectedDay
                        var selMonth = calRoot.selectedMonth + 1
                        var selYear = calRoot.selectedYear
                        var events = (calRoot.backend && calRoot.backend.agendaEvents) ? calRoot.backend.agendaEvents : []

                        for (var i = 0; i < events.length; i++) {
                            var ev = events[i]
                            if (parseInt(ev.day, 10) === selDay &&
                                parseInt(ev.month, 10) === selMonth &&
                                parseInt(ev.year, 10) === selYear) {
                                filtered.push(ev)
                            }
                        }

                        return filtered
                    }

                    delegate: Rectangle {
                        width: agendaList.width
                        implicitHeight: eventCol.implicitHeight + 14
                        radius: 12
                        color: calRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.04)
                        border.color: calRoot.cardBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 4
                                Layout.fillHeight: true
                                radius: 2
                                color: modelData.color || calRoot.accentColor
                            }

                            ColumnLayout {
                                id: eventCol
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.title
                                    color: calRoot.primaryText
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: modelData.time || "All Day"
                                        color: calRoot.secondaryText
                                        font.pixelSize: 10
                                    }
                                    Text {
                                        visible: !!modelData.location && String(modelData.location).trim() !== "" && modelData.location !== modelData.account
                                        text: "• " + modelData.location
                                        color: calRoot.secondaryText
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        visible: !!modelData.isOnline
                                        implicitWidth: onlineLbl.implicitWidth + 12
                                        implicitHeight: 16
                                        radius: 8
                                        color: calRoot.isDarkTheme ? Qt.rgba(53/255, 132/255, 228/255, 0.25) : Qt.rgba(53/255, 132/255, 228/255, 0.15)
                                        border.color: Qt.rgba(53/255, 132/255, 228/255, 0.4)
                                        border.width: 1

                                        Text {
                                            id: onlineLbl
                                            anchors.centerIn: parent
                                            text: modelData.account ? String(modelData.account).split("@")[0] : i18n("Online")
                                            color: calRoot.isDarkTheme ? "#62a0ea" : "#1c71d8"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            // Delete event button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                visible: !modelData.isHoliday && modelData.category !== "internal"
                                color: delMouse.containsMouse ? calRoot.dangerColor : "transparent"

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 11
                                    height: 11
                                    source: "edit-delete-symbolic"
                                    isMask: true
                                    color: delMouse.containsMouse ? "#ffffff" : calRoot.secondaryText
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (calRoot.backend && typeof calRoot.backend.deleteEvent === "function") {
                                            calRoot.backend.deleteEvent(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty State for Agenda
                    Item {
                        anchors.fill: parent
                        visible: agendaList.count === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                width: 24
                                height: 24
                                source: "appointment-recurring"
                                isMask: true
                                color: calRoot.secondaryText
                                opacity: 0.5
                            }

                            Text {
                                text: i18n("No events scheduled")
                                color: calRoot.secondaryText
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
