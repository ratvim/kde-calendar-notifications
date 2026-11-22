import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "views"

/**
 * FullRepresentation.qml - GNOME Quick Settings Styled Dual-Page Popup Representation
 * Features:
 *   - Glassmorphic card with rounded outer corners (radius: 24px) matching kde_gnome_quicksetting
 *   - Clean removal of native Plasma dialog borders/shadows for floating GNOME card look
 *   - Top bar: Live clock/date pill, Timezone pill, Layout swap button, Settings launcher
 *   - Side-by-Side Dual-Card layout (Calendar & Events + Live App-Grouped Notifications)
 */
Rectangle {
    id: fullRoot

    // Reference to mainItem backend
    property var backend: (typeof mainItem !== "undefined") ? mainItem : null

    readonly property bool calendarOnLeft: Plasmoid.configuration.calendarOnLeft
    readonly property bool isDarkTheme: backend ? backend.isDarkTheme : true

    // GNOME glassmorphic palette matching kde_gnome_quicksetting
    readonly property color cardBackground: backend ? backend.effectiveCardColor : (isDarkTheme ? "#1e1e24" : "#f0f2f5")
    readonly property color surfaceBackground: isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color tileBackground: isDarkTheme ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color hoverBackground: isDarkTheme ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color cardBorder: isDarkTheme ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color rootBorder: {
        var op = backend ? backend.effectiveBackgroundOpacity : 0.8
        var alpha = Math.min(0.12, Math.max(0.04, 0.08 * op))
        return isDarkTheme ? Qt.rgba(1, 1, 1, alpha) : Qt.rgba(0, 0, 0, alpha)
    }
    readonly property color primaryText: isDarkTheme ? "#ffffff" : "#1a1a1a"
    readonly property color secondaryText: isDarkTheme ? "#9aa0a6" : "#606770"
    readonly property color accentColor: (Kirigami.Theme.highlightColor !== undefined && Kirigami.Theme.highlightColor.a > 0) ? Kirigami.Theme.highlightColor : "#3584e4"
    readonly property color accentTextColor: (Kirigami.Theme.highlightedTextColor !== undefined && Kirigami.Theme.highlightedTextColor.a > 0) ? Kirigami.Theme.highlightedTextColor : "#ffffff"

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.userBackgroundHints: PlasmaCore.Types.NoBackground

    property var _winHelperInstance: null

    function getWinHelper() {
        if (fullRoot._winHelperInstance) return fullRoot._winHelperInstance
        try {
            fullRoot._winHelperInstance = Qt.createQmlObject('import GnomeQuickSettingsPlugin 1.0; WindowHelper {}', fullRoot, "winHelperInstance")
        } catch (e1) {
            try {
                fullRoot._winHelperInstance = Qt.createQmlObject('import GnomeQuickSettingsPlugin; WindowHelper {}', fullRoot, "winHelperInstance")
            } catch (e2) {}
        }
        return fullRoot._winHelperInstance
    }

    function applyWindowMaskAndBlur() {
        var helper = getWinHelper()
        if (helper) {
            var shouldBlur = backend ? backend.effectiveBlurEnabled : true
            try {
                helper.applyMask(fullRoot, 24, shouldBlur)
            } catch (e) {}
        }
    }

    // =========================================================================
    // RESOLUTION & DPI RESPONSIVE SCALING ENGINE
    // Automatically adapts dimensions and layout across any screen resolution
    // (720p, 1080p, 2K/QHD, 4K/UHD, and Ultrawide displays)
    // =========================================================================
    readonly property real screenWidth: (Screen.width > 0) ? Screen.width : 1920
    readonly property real screenHeight: (Screen.height > 0) ? Screen.height : 1080
    readonly property real baseGridUnit: (Kirigami.Units && Kirigami.Units.gridUnit > 0) ? Kirigami.Units.gridUnit : 18

    // Multi-factor responsive resolution scale:
    // Normalizes geometry against standard 1080p reference with 1.15 baseline boost
    // to guarantee comfortable, spacious calendar & notification views on 1080p laptop/desktop screens.
    readonly property real resolutionScale: {
        var hScale = screenHeight / 1080.0
        var wEquiv = Math.min(screenWidth, screenHeight * (16.0 / 9.0))
        var wScale = wEquiv / 1920.0
        var geomScale = (hScale * 0.65) + (wScale * 0.35)
        var unitScale = baseGridUnit / 18.0
        var effective = Math.max(unitScale, geomScale) * 1.15
        return Math.max(0.88, Math.min(1.85, effective))
    }

    // Responsive dimensions:
    // Base 760x510 scaled by resolution (yields ~874x587 on 1080p)
    readonly property int responsiveWidth: {
        var targetW = Math.round(760 * resolutionScale)
        var maxAllowedW = Math.round(screenWidth * 0.88)
        var minAllowedW = Math.min(Math.round(screenWidth * 0.90), 620)
        return Math.max(minAllowedW, Math.min(maxAllowedW, targetW))
    }

    readonly property int responsiveHeight: {
        var targetH = Math.round(510 * resolutionScale)
        var maxAllowedH = Math.max(380, screenHeight - 64)
        var minAllowedH = Math.min(Math.round(screenHeight * 0.85), 440)
        return Math.max(minAllowedH, Math.min(maxAllowedH, targetH))
    }

    readonly property int contentMargin: Math.round(14 * resolutionScale)
    readonly property int cardSpacing: Math.round(12 * resolutionScale)
    readonly property int innerCardRadius: Math.round(18 * resolutionScale)

    onResponsiveWidthChanged: {
        syncWindowGeometry()
        restartBackgroundFixTimers()
    }
    onResponsiveHeightChanged: {
        syncWindowGeometry()
        restartBackgroundFixTimers()
    }

    width: responsiveWidth
    height: responsiveHeight
    implicitWidth: responsiveWidth
    implicitHeight: responsiveHeight

    Layout.minimumWidth: Math.round(620 * resolutionScale)
    Layout.minimumHeight: Math.round(420 * resolutionScale)
    Layout.preferredWidth: responsiveWidth
    Layout.preferredHeight: responsiveHeight

    radius: 24
    antialiasing: true
    smooth: true
    clip: true

    color: cardBackground
    border.color: rootBorder
    border.width: 1

    // Registry for hooks to prevent duplicate signal connections
    property var _hookedItemsRegistry: []

    function isHooked(obj, key) {
        if (!obj) return true
        for (var i = 0; i < fullRoot._hookedItemsRegistry.length; ++i) {
            var item = fullRoot._hookedItemsRegistry[i]
            if (item.obj === obj && item.key === key) return true
        }
        return false
    }

    function recordHook(obj, key) {
        if (!obj) return
        fullRoot._hookedItemsRegistry.push({ obj: obj, key: key })
    }

    function makeItemFullyTransparent(item) {
        if (!item) return
        try {
            item.visible = false
            item.opacity = 0
            if (item.imagePath !== undefined) item.imagePath = ""
            if (item.prefix !== undefined) item.prefix = ""
            if (item.elementId !== undefined) item.elementId = ""
            if (!isHooked(item, "transparency")) {
                recordHook(item, "transparency")
                if (item.visibleChanged) {
                    item.visibleChanged.connect(function() {
                        if (item.visible) item.visible = false
                    })
                }
                if (item.opacityChanged) {
                    item.opacityChanged.connect(function() {
                        if (item.opacity !== 0) item.opacity = 0
                    })
                }
                if (item.imagePathChanged) {
                    item.imagePathChanged.connect(function() {
                        if (item.imagePath !== "") item.imagePath = ""
                    })
                }
                if (item.prefixChanged) {
                    item.prefixChanged.connect(function() {
                        if (item.prefix !== "") item.prefix = ""
                    })
                }
            }
            if (item.children) {
                for (var i = 0; i < item.children.length; ++i) {
                    makeItemFullyTransparent(item.children[i])
                }
            }
        } catch (e) {}
    }

    // Completely eliminate native Plasma dialog background, borders, and shadows
    function removePlasmaBackground() {
        var win = null
        try {
            if (Window.window) win = Window.window
        } catch (e) {}
        if (!win && fullRoot.Window && fullRoot.Window.window) {
            win = fullRoot.Window.window
        }

        var topItem = null
        var p = fullRoot.parent
        while (p) {
            topItem = p
            if (!win && p.Window && p.Window.window) {
                win = p.Window.window
            }
            try {
                if (p !== fullRoot && p.parent && p.parent.children) {
                    for (var k = 0; k < p.parent.children.length; ++k) {
                        var sib = p.parent.children[k]
                        if (sib !== p && sib !== fullRoot) {
                            makeItemFullyTransparent(sib)
                        }
                    }
                }
            } catch (e) {}
            p = p.parent
        }

        try {
            if (topItem && !isHooked(topItem, "children")) {
                recordHook(topItem, "children")
                if (topItem.childrenChanged) {
                    topItem.childrenChanged.connect(function() {
                        if (fullRoot && typeof fullRoot.removePlasmaBackground === "function") {
                            fullRoot.removePlasmaBackground()
                            fullRoot.restartBackgroundFixTimers()
                        }
                    })
                }
            }
        } catch (e) {}

        if (win) {
            try {
                win.borders = 0
                if (win.backgroundHints !== undefined && win.backgroundHints !== 0) {
                    win.backgroundHints = 0
                }
                if (win.color !== undefined) {
                    win.color = "transparent"
                }
            } catch (e) {}

            try {
                if (win.contentItem && !isHooked(win.contentItem, "children")) {
                    recordHook(win.contentItem, "children")
                    if (win.contentItem.childrenChanged) {
                        win.contentItem.childrenChanged.connect(function() {
                            if (fullRoot && typeof fullRoot.removePlasmaBackground === "function") {
                                fullRoot.removePlasmaBackground()
                                fullRoot.restartBackgroundFixTimers()
                            }
                        })
                    }
                }
                if (win.contentItem && win.contentItem.children) {
                    for (var m = win.contentItem.children.length - 1; m >= 0; --m) {
                        var wChild = win.contentItem.children[m]
                        if (wChild !== fullRoot.parent && wChild !== fullRoot && wChild !== topItem) {
                            var wcName = wChild.toString()
                            if (wcName.indexOf("Overlay") === -1) {
                                makeItemFullyTransparent(wChild)
                            }
                        }
                    }
                }
            } catch (err) {}

            try {
                if (!isHooked(win, "winSignals")) {
                    recordHook(win, "winSignals")
                    if (win.bordersChanged) {
                        win.bordersChanged.connect(function() {
                            if (win.borders !== 0) win.borders = 0
                        })
                    }
                    if (win.backgroundHintsChanged) {
                        win.backgroundHintsChanged.connect(function() {
                            if (win.backgroundHints !== 0) win.backgroundHints = 0
                        })
                    }
                    if (win.colorChanged) {
                        win.colorChanged.connect(function() {
                            if (win.color.toString() !== "#00000000") win.color = "transparent"
                        })
                    }
                    if (win.widthChanged) {
                        win.widthChanged.connect(function() {
                            if (fullRoot && typeof fullRoot.removePlasmaBackground === "function") {
                                fullRoot.removePlasmaBackground()
                                fullRoot.applyWindowMaskAndBlur()
                            }
                        })
                    }
                    if (win.heightChanged) {
                        win.heightChanged.connect(function() {
                            if (fullRoot && typeof fullRoot.removePlasmaBackground === "function") {
                                fullRoot.removePlasmaBackground()
                                fullRoot.applyWindowMaskAndBlur()
                            }
                        })
                    }
                }
            } catch (e) {}
        }

        // Make DialogBackground and all underlying FrameSvgItems 100% transparent
        try {
            if (topItem && topItem.children) {
                for (var i = topItem.children.length - 1; i >= 0; --i) {
                    var child = topItem.children[i]
                    if (child !== fullRoot.parent && child !== fullRoot) {
                        var cName = child.toString()
                        if (cName.indexOf("Overlay") === -1) {
                            makeItemFullyTransparent(child)
                        }
                    }
                }
            }
        } catch (e) {}

        // Align appletParent at (0, 0) and remove extra dimensions with persistent hooks
        if (fullRoot.parent) {
            try {
                fullRoot.parent.x = 0
                fullRoot.parent.y = 0
                fullRoot.parent.extraHeight = 0
                fullRoot.parent.extraWidth = 0
                if (!isHooked(fullRoot.parent, "dims")) {
                    recordHook(fullRoot.parent, "dims")
                    if (fullRoot.parent.extraHeightChanged) {
                        fullRoot.parent.extraHeightChanged.connect(function() {
                            if (fullRoot && fullRoot.parent && fullRoot.parent.extraHeight !== 0) fullRoot.parent.extraHeight = 0
                        })
                    }
                    if (fullRoot.parent.extraWidthChanged) {
                        fullRoot.parent.extraWidthChanged.connect(function() {
                            if (fullRoot && fullRoot.parent && fullRoot.parent.extraWidth !== 0) fullRoot.parent.extraWidth = 0
                        })
                    }
                    if (fullRoot.parent.xChanged) {
                        fullRoot.parent.xChanged.connect(function() {
                            if (fullRoot && fullRoot.parent && fullRoot.parent.x !== 0) fullRoot.parent.x = 0
                        })
                    }
                    if (fullRoot.parent.yChanged) {
                        fullRoot.parent.yChanged.connect(function() {
                            if (fullRoot && fullRoot.parent && fullRoot.parent.y !== 0) fullRoot.parent.y = 0
                        })
                    }
                }
            } catch (e) {}

            try {
                if (fullRoot.parent.children) {
                    for (var j = 0; j < fullRoot.parent.children.length; ++j) {
                        var pChild = fullRoot.parent.children[j]
                        if (pChild !== fullRoot) {
                            makeItemFullyTransparent(pChild)
                        }
                    }
                }
                if (!isHooked(fullRoot.parent, "children")) {
                    recordHook(fullRoot.parent, "children")
                    if (fullRoot.parent.childrenChanged) {
                        fullRoot.parent.childrenChanged.connect(function() {
                            if (fullRoot && typeof fullRoot.removePlasmaBackground === "function") {
                                fullRoot.removePlasmaBackground()
                                fullRoot.restartBackgroundFixTimers()
                            }
                        })
                    }
                }
            } catch (e) {}
        }

        fullRoot.applyWindowMaskAndBlur()
    }

    function syncWindowGeometry() {
        var win = null
        try {
            if (Window.window) win = Window.window
        } catch (e) {}
        if (!win && fullRoot.Window && fullRoot.Window.window) {
            win = fullRoot.Window.window
        }
        if (win) {
            try {
                win.width = fullRoot.responsiveWidth
                win.height = fullRoot.responsiveHeight
            } catch (e) {
                console.warn("Could not sync popup window geometry:", e)
            }
        }
        removePlasmaBackground()
        fullRoot.applyWindowMaskAndBlur()
    }

    function restartBackgroundFixTimers() {
        bgFixTimer.restart()
        bgMidFixTimer.restart()
        bgAnimFixTimer.restart()
        bgFinalFixTimer.restart()
        bgThemeFixTimer1.restart()
        bgThemeFixTimer2.restart()
    }

    Timer {
        id: bgFixTimer
        interval: 30
        repeat: false
        onTriggered: {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
        }
    }

    Timer {
        id: bgMidFixTimer
        interval: 100
        repeat: false
        onTriggered: {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
        }
    }

    Timer {
        id: bgAnimFixTimer
        interval: 250
        repeat: false
        onTriggered: {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
        }
    }

    Timer {
        id: bgFinalFixTimer
        interval: 500
        repeat: false
        onTriggered: {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
        }
    }

    Timer {
        id: bgThemeFixTimer1
        interval: 850
        repeat: false
        onTriggered: {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
        }
    }

    Timer {
        id: bgThemeFixTimer2
        interval: 1500
        repeat: false
        onTriggered: {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
        }
    }

    Component.onCompleted: {
        syncWindowGeometry()
        removePlasmaBackground()
        restartBackgroundFixTimers()
    }
    onWindowChanged: {
        syncWindowGeometry()
        removePlasmaBackground()
        restartBackgroundFixTimers()
    }
    onParentChanged: {
        syncWindowGeometry()
        removePlasmaBackground()
        restartBackgroundFixTimers()
    }
    onVisibleChanged: {
        if (visible) {
            if (backend && typeof backend.updatePanelDetection === "function") {
                backend.updatePanelDetection()
            }
            if (backend && typeof backend.resetToToday === "function") {
                backend.resetToToday()
            }
            syncWindowGeometry()
            removePlasmaBackground()
            applyWindowMaskAndBlur()
            restartBackgroundFixTimers()
        }
    }

    Connections {
        target: backend
        ignoreUnknownSignals: true
        function onExpandedChanged() {
            if (backend && backend.expanded) {
                if (typeof backend.resetToToday === "function") {
                    backend.resetToToday()
                }
                fullRoot.syncWindowGeometry()
                fullRoot.removePlasmaBackground()
                fullRoot.applyWindowMaskAndBlur()
                fullRoot.restartBackgroundFixTimers()
            }
        }
        function onEffectiveBlurEnabledChanged() {
            fullRoot.applyWindowMaskAndBlur()
        }
        function onEffectiveBackgroundOpacityChanged() {
            fullRoot.applyWindowMaskAndBlur()
        }
        function onEffectiveCardColorChanged() {
            fullRoot.applyWindowMaskAndBlur()
        }
    }

    Connections {
        target: Kirigami.Theme
        function onColorsChanged() {
            fullRoot.syncWindowGeometry()
            fullRoot.removePlasmaBackground()
            fullRoot.restartBackgroundFixTimers()
        }
    }

    // Side-by-Side Dual-Card Container
    RowLayout {
        anchors.fill: parent
        anchors.margins: fullRoot.contentMargin
        spacing: fullRoot.cardSpacing

        // Card Pane 1 (Calendar if calendarOnLeft, else Notifications)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: fullRoot.innerCardRadius
            color: fullRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03)
            border.color: fullRoot.cardBorder
            border.width: 1
            clip: true

            Loader {
                anchors.fill: parent
                anchors.margins: Math.round(12 * fullRoot.resolutionScale)
                sourceComponent: fullRoot.calendarOnLeft ? calendarComponent : notificationsComponent
            }
        }

        // Card Pane 2 (Notifications if calendarOnLeft, else Calendar)
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: fullRoot.innerCardRadius
            color: fullRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03)
            border.color: fullRoot.cardBorder
            border.width: 1
            clip: true

            Loader {
                anchors.fill: parent
                anchors.margins: Math.round(12 * fullRoot.resolutionScale)
                sourceComponent: fullRoot.calendarOnLeft ? notificationsComponent : calendarComponent
            }
        }
    }

    Component {
        id: calendarComponent
        CalendarView {
            backend: fullRoot.backend
        }
    }

    Component {
        id: notificationsComponent
        NotificationView {
            backend: fullRoot.backend
        }
    }
}
