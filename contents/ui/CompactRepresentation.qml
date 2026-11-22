import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

/**
 * CompactRepresentation.qml - Panel representation with Clock, Date, and Unread Notification Badge
 * Designed with a protective capsule pill to ensure full visibility and clickability on KDE Plasma 6 panels.
 */
Item {
    id: compactRoot

    // Reference to mainItem backend
    property var backend: (typeof mainItem !== "undefined") ? mainItem : null

    // Dynamically follows global desktop theme (Complementary in Dark mode, Window in Light mode)
    // Ensures text and symbolic icons render in crisp contrast matching the system theme.
    Kirigami.Theme.colorSet: compactRoot.isDarkTheme ? Kirigami.Theme.Complementary : Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    // Dynamic detection of attached panel background, opacity, and blur
    function detectPanelProperties() {
        var hasCustomColor = false
        var detectedColor = Qt.rgba(0, 0, 0, 0)
        var detectedOpacity = 0.70
        var detectedBlur = true
        var detectedTextColor = Qt.rgba(0, 0, 0, 0)

        // 1. Inspect sibling applets in the panel containment for panel.colorizer
        try {
            if (typeof plasmoid !== "undefined" && plasmoid.containment && plasmoid.containment.applets) {
                var applets = plasmoid.containment.applets
                for (var i = 0; i < applets.length; ++i) {
                    var app = applets[i]
                    if (app && app.plugin === "luisbocanegra.panel.colorizer") {
                        var cfg = app.configuration
                        if (cfg) {
                            var gSettings = (typeof cfg.globalSettings === "string") ? JSON.parse(cfg.globalSettings) : cfg.globalSettings
                            if (gSettings) {
                                if (gSettings.nativePanel && gSettings.nativePanel.background && gSettings.nativePanel.background.opacity !== undefined) {
                                    var nop = parseFloat(gSettings.nativePanel.background.opacity)
                                    if (!isNaN(nop) && nop >= 0.05 && nop <= 1.0) {
                                        detectedOpacity = nop
                                    }
                                }
                                if (gSettings.panel && gSettings.panel.enabled) {
                                    if (gSettings.panel.opacity !== undefined) {
                                        var pop = parseFloat(gSettings.panel.opacity)
                                        if (!isNaN(pop) && pop >= 0.05 && pop <= 1.0) {
                                            detectedOpacity = pop
                                        }
                                    }
                                    if (gSettings.panel.backgroundColor && gSettings.panel.backgroundColor.enabled && gSettings.panel.backgroundColor.custom) {
                                        var customHex = gSettings.panel.backgroundColor.custom
                                        if (customHex && typeof customHex === "string" && customHex.length >= 4) {
                                            detectedColor = Qt.color(customHex)
                                            hasCustomColor = true
                                        }
                                    }
                                    if (gSettings.panel.blurBehind !== undefined) {
                                        detectedBlur = Boolean(gSettings.panel.blurBehind)
                                    }
                                    if (gSettings.panel.foregroundColor && gSettings.panel.foregroundColor.enabled && gSettings.panel.foregroundColor.custom) {
                                        var fgHex = gSettings.panel.foregroundColor.custom
                                        if (fgHex && typeof fgHex === "string" && fgHex.length >= 4) {
                                            detectedTextColor = Qt.color(fgHex)
                                        }
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }
        } catch (e1) {}

        // 2. Check native PanelView window and parent hierarchy
        try {
            var win = compactRoot.Window.window
            if (win) {
                if (win.opacityMode !== undefined) {
                    if (win.opacityMode === 1) { // Opaque
                        detectedOpacity = 1.0
                    } else if (win.opacityMode === 2) { // Translucent
                        detectedOpacity = 0.65
                    }
                }

                if (win.panelOpacity !== undefined && win.panelOpacity > 0.05) {
                    detectedOpacity = Math.max(0.35, Math.min(1.0, win.panelOpacity))
                } else if (win.contentItem && win.contentItem.children) {
                    for (var j = 0; j < win.contentItem.children.length; ++j) {
                        var ch = win.contentItem.children[j]
                        if (ch && ch.panelOpacity !== undefined && ch.panelOpacity > 0.05) {
                            detectedOpacity = Math.max(0.35, Math.min(1.0, ch.panelOpacity))
                            break
                        }
                    }
                }
            }
        } catch (e2) {}

        // 3. Walk up parent hierarchy for panelOpacity
        try {
            var p = compactRoot.parent
            while (p) {
                if (p.panelOpacity !== undefined && p.panelOpacity > 0.05) {
                    detectedOpacity = Math.max(0.35, Math.min(1.0, p.panelOpacity))
                    break
                }
                p = p.parent
            }
        } catch (e3) {}

        if (compactRoot.backend) {
            compactRoot.backend.hasCustomPanelColor = hasCustomColor
            compactRoot.backend.detectedPanelColor = hasCustomColor ? detectedColor : Qt.rgba(0, 0, 0, 0)
            compactRoot.backend.detectedPanelOpacity = detectedOpacity
            compactRoot.backend.detectedPanelBlur = detectedBlur
            compactRoot.backend.detectedPanelTextColor = detectedTextColor
        }
    }

    Timer {
        id: panelDetectTimer
        interval: 300
        running: true
        repeat: false
        onTriggered: compactRoot.detectPanelProperties()
    }

    onWindowChanged: {
        compactRoot.detectPanelProperties()
    }

    Component.onCompleted: {
        compactRoot.detectPanelProperties()
    }

    readonly property bool inVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Dynamic Theme Detection
    readonly property bool systemIsDark: (backend && backend.systemIsDark !== undefined) ? backend.systemIsDark : false
    readonly property bool isDarkTheme: backend ? backend.isDarkTheme : systemIsDark

    // Active icons & text on the panel use high-contrast panel foreground adapting dynamically to dark/light theme
    readonly property color activeIndicatorColor: {
        if (backend && backend.detectedPanelTextColor && backend.detectedPanelTextColor.a > 0) {
            return backend.detectedPanelTextColor
        }
        if (backend && backend.hasCustomPanelColor) {
            return backend.effectiveIsDark ? "#f6f8fa" : "#1a1a1a"
        }
        return compactRoot.isDarkTheme ? "#f6f8fa" : "#1a1a1a"
    }

    readonly property color panelTextColor: activeIndicatorColor
    readonly property color panelSecondaryColor: compactRoot.isDarkTheme ? "#9aa0a6" : "#606770"

    // Custom configuration bindings
    readonly property bool use24h: Plasmoid.configuration.use24Hour
    readonly property bool showSec: Plasmoid.configuration.showSeconds
    readonly property bool showDate: Plasmoid.configuration.showDateOnPanel
    readonly property string customDateFormat: Plasmoid.configuration.dateFormat || "ddd, MMM d"
    readonly property string customFontFamily: Plasmoid.configuration.fontFamily || ""
    readonly property int timeSize: Plasmoid.configuration.timeFontSize || 14
    readonly property int dateSize: Plasmoid.configuration.dateFontSize || 12
    readonly property bool showBadge: Plasmoid.configuration.showNotificationBadge
    readonly property bool showCount: Plasmoid.configuration.showNotificationCount

    property var currentTime: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: compactRoot.currentTime = new Date()
    }

    // Formatted time string
    readonly property string formattedTime: {
        var fmt = ""
        if (Plasmoid.configuration.timeFormat && Plasmoid.configuration.timeFormat.length > 0) {
            fmt = Plasmoid.configuration.timeFormat
        } else if (use24h) {
            fmt = showSec ? "hh:mm:ss" : "hh:mm"
        } else {
            fmt = showSec ? "h:mm:ss AP" : "h:mm AP"
        }
        return Qt.formatDateTime(currentTime, fmt)
    }

    // Formatted date string
    readonly property string formattedDate: {
        return Qt.formatDateTime(currentTime, customDateFormat)
    }

    // Plasma Panel Layout sizing & safety margins (prevents collapsing or clipping behind other panel items)
    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.minimumWidth: inVerticalPanel ? 48 : pillRect.implicitWidth + 12
    Layout.preferredWidth: inVerticalPanel ? 48 : pillRect.implicitWidth + 12
    Layout.maximumWidth: inVerticalPanel ? 64 : pillRect.implicitWidth + 16
    Layout.minimumHeight: inVerticalPanel ? 48 : pillRect.implicitHeight
    Layout.preferredHeight: inVerticalPanel ? 56 : pillRect.implicitHeight
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: 2
    Layout.rightMargin: 8

    implicitWidth: inVerticalPanel ? 48 : pillRect.implicitWidth + 12
    implicitHeight: inVerticalPanel ? 56 : pillRect.implicitHeight

    // Capsule pill container matching kde_gnome_quicksetting
    Rectangle {
        id: pillRect
        anchors.centerIn: parent
        implicitWidth: inVerticalPanel ? 44 : (contentRow.implicitWidth + 24)
        implicitHeight: inVerticalPanel ? (contentCol.implicitHeight + 10) : 32
        width: implicitWidth
        height: implicitHeight
        radius: height / 2

        color: panelMouse.containsMouse ?
            Qt.rgba(compactRoot.activeIndicatorColor.r, compactRoot.activeIndicatorColor.g, compactRoot.activeIndicatorColor.b, 0.16) :
            Qt.rgba(compactRoot.activeIndicatorColor.r, compactRoot.activeIndicatorColor.g, compactRoot.activeIndicatorColor.b, 0.08)
        border.color: Qt.rgba(compactRoot.activeIndicatorColor.r, compactRoot.activeIndicatorColor.g, compactRoot.activeIndicatorColor.b, 0.12)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        // Horizontal Panel Content
        RowLayout {
            id: contentRow
            visible: !compactRoot.inVerticalPanel
            anchors.centerIn: parent
            spacing: 6

            // Time and Date — single line, high-contrast, fully visible
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: timeLabel
                    text: compactRoot.formattedTime
                    color: compactRoot.panelTextColor
                    font.family: compactRoot.customFontFamily ? compactRoot.customFontFamily : ""
                    font.pixelSize: compactRoot.timeSize
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // High-visibility separator bullet
                Text {
                    visible: compactRoot.showDate
                    text: "·"
                    color: compactRoot.panelTextColor
                    opacity: 0.6
                    font.pixelSize: compactRoot.timeSize
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: dateLabel
                    visible: compactRoot.showDate
                    text: compactRoot.formattedDate
                    color: compactRoot.panelTextColor
                    font.family: compactRoot.customFontFamily ? compactRoot.customFontFamily : ""
                    font.pixelSize: compactRoot.dateSize > 0 ? Math.max(compactRoot.dateSize, compactRoot.timeSize) : compactRoot.timeSize
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Unread Notification Indicator
            Rectangle {
                id: unreadBadge
                readonly property int uCount: (compactRoot.backend ? compactRoot.backend.unreadCount : 0)
                readonly property bool hasU: uCount > 0
                visible: compactRoot.showBadge && hasU
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: compactRoot.showCount ? 18 : 10
                implicitWidth: compactRoot.showCount ? Math.max(18, badgeText.implicitWidth + 8) : 10
                radius: height / 2
                color: (compactRoot.backend ? compactRoot.backend.badgeColor : "#e01b24")

                border.color: compactRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.25)
                border.width: 1

                Text {
                    id: badgeText
                    visible: compactRoot.showCount
                    anchors.centerIn: parent
                    text: unreadBadge.uCount > 99 ? "99+" : unreadBadge.uCount.toString()
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.bold: true
                }

                SequentialAnimation {
                    id: pulseAnim
                    loops: 3
                    NumberAnimation { target: unreadBadge; property: "scale"; from: 1.0; to: 1.25; duration: 250; easing.type: Easing.OutQuad }
                    NumberAnimation { target: unreadBadge; property: "scale"; from: 1.25; to: 1.0; duration: 250; easing.type: Easing.InQuad }
                }

                Connections {
                    target: compactRoot.backend
                    ignoreUnknownSignals: true
                    function onUnreadCountChanged() {
                        if (compactRoot.backend && compactRoot.backend.unreadCount > 0) {
                            pulseAnim.restart()
                        }
                    }
                }
            }
        }

        // Vertical Panel Content
        ColumnLayout {
            id: contentCol
            visible: compactRoot.inVerticalPanel
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: Qt.formatDateTime(compactRoot.currentTime, compactRoot.use24h ? "hh:mm" : "h:mm")
                color: compactRoot.panelTextColor
                font.pixelSize: compactRoot.timeSize
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                visible: compactRoot.showBadge && (compactRoot.backend ? compactRoot.backend.hasUnread : false)
                Layout.alignment: Qt.AlignHCenter
                width: 8
                height: 8
                radius: 4
                color: (compactRoot.backend ? compactRoot.backend.badgeColor : "#e01b24")
            }
        }

        // Full-coverage MouseArea for clicks
        MouseArea {
            id: panelMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: {
                compactRoot.detectPanelProperties()
                if (compactRoot.backend && typeof compactRoot.backend.expanded !== "undefined") {
                    compactRoot.backend.expanded = !compactRoot.backend.expanded
                } else if (typeof mainItem !== "undefined" && typeof mainItem.expanded !== "undefined") {
                    mainItem.expanded = !mainItem.expanded
                } else if (typeof plasmoid !== "undefined" && typeof plasmoid.expanded !== "undefined") {
                    plasmoid.expanded = !plasmoid.expanded
                } else if (typeof Plasmoid !== "undefined" && typeof Plasmoid.expanded !== "undefined") {
                    Plasmoid.expanded = !Plasmoid.expanded
                }
            }
        }
    }
}
