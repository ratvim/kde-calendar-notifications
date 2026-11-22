import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

/**
 * NotificationView.qml - App-Grouped Notifications Drawer for KDE Plasma 6
 * Groups notifications by application, with expandable cards, individual actions,
 * dismiss-per-item, dismiss-per-group, and "Clear All".
 */
Rectangle {
    id: notifRoot

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

    readonly property int totalCount: backend ? backend.totalNotificationCount : 0
    readonly property var groupedList: backend ? backend.groupedNotifications : []

    property var expandedGroups: ({})

    function toggleGroup(appName) {
        var copy = Object.assign({}, expandedGroups)
        copy[appName] = !copy[appName]
        expandedGroups = copy
    }

    function isExpanded(appName) {
        // Expand first group by default if undefined
        if (expandedGroups[appName] === undefined) {
            return true
        }
        return !!expandedGroups[appName]
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // --- 1. Notification Header & Action Controls ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                spacing: 0
                RowLayout {
                    spacing: 6
                    Text {
                        text: i18n("Notifications")
                        color: notifRoot.primaryText
                        font.pixelSize: 18
                        font.bold: true
                    }

                    // Count Badge
                    Rectangle {
                        visible: notifRoot.totalCount > 0
                        implicitHeight: 20
                        implicitWidth: Math.max(20, badgeCountText.implicitWidth + 10)
                        radius: 10
                        color: notifRoot.accentColor

                        Text {
                            id: badgeCountText
                            anchors.centerIn: parent
                            text: notifRoot.totalCount.toString()
                            color: notifRoot.accentTextColor
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: notifRoot.totalCount > 0 ?
                          i18n("%1 active from %2 apps", notifRoot.totalCount, notifRoot.groupedList.length) :
                          i18n("All notifications cleared")
                    color: notifRoot.secondaryText
                    font.pixelSize: 11
                }
            }

            Item { Layout.fillWidth: true }

            // "Clear all" Button — compact 22px pill
            Rectangle {
                visible: notifRoot.totalCount > 0
                implicitWidth: 22
                implicitHeight: 22
                radius: 11
                color: clearMouse.containsMouse ?
                    (notifRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)) :
                    (notifRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
                border.color: clearMouse.containsMouse ? notifRoot.dangerColor : notifRoot.cardBorder
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 11
                    height: 11
                    source: "edit-clear-all-symbolic"
                    isMask: true
                    color: clearMouse.containsMouse ? notifRoot.dangerColor : notifRoot.secondaryText
                }

                ToolTip.visible: clearMouse.containsMouse
                ToolTip.delay: 500
                ToolTip.text: i18n("Clear all notifications")

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (notifRoot.backend && typeof notifRoot.backend.clearAllNotifications === "function") {
                            notifRoot.backend.clearAllNotifications()
                        }
                    }
                }
            }
        }

        // --- 2. App-Grouped Notifications List ---
        ListView {
            id: groupsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            model: notifRoot.groupedList

            delegate: Rectangle {
                id: groupCard
                width: groupsList.width
                implicitHeight: groupContentCol.implicitHeight + 16
                radius: 16
                color: notifRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.04)
                border.color: notifRoot.cardBorder
                border.width: 1

                readonly property var grp: modelData
                readonly property bool expanded: notifRoot.isExpanded(grp.appName)

                ColumnLayout {
                    id: groupContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8

                    // Group Header Row (App Icon, Name, Count badge, Dismiss group, Expand Chevron)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Kirigami.Icon {
                            width: 20
                            height: 20
                            source: grp.appIcon || "preferences-system"
                        }

                        Text {
                            text: grp.appName
                            color: notifRoot.primaryText
                            font.pixelSize: 13
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Group Badge Count
                        Rectangle {
                            implicitWidth: Math.max(18, groupCountText.implicitWidth + 8)
                            implicitHeight: 18
                            radius: 9
                            color: notifRoot.hoverBackground
                            border.color: notifRoot.cardBorder
                            border.width: 1

                            Text {
                                id: groupCountText
                                anchors.centerIn: parent
                                text: grp.count.toString()
                                color: notifRoot.secondaryText
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        // Dismiss Entire Group Button
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: dismissGroupMouse.containsMouse ? notifRoot.hoverBackground : "transparent"

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: "edit-delete-symbolic"
                                isMask: true
                                color: dismissGroupMouse.containsMouse ? notifRoot.dangerColor : notifRoot.secondaryText
                            }

                            MouseArea {
                                id: dismissGroupMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (notifRoot.backend && typeof notifRoot.backend.dismissGroup === "function") {
                                        notifRoot.backend.dismissGroup(grp.appName)
                                    }
                                }
                            }
                        }

                        // Expand / Collapse Chevron Button
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: chevronMouse.containsMouse ? notifRoot.hoverBackground : "transparent"

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: groupCard.expanded ? "go-up-symbolic" : "go-down-symbolic"
                                isMask: true
                                color: notifRoot.secondaryText
                            }

                            MouseArea {
                                id: chevronMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifRoot.toggleGroup(grp.appName)
                            }
                        }
                    }

                    // Individual Notifications inside this group (Visible when group is expanded)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: groupCard.expanded
                        spacing: 6

                        Repeater {
                            model: grp.items

                            Rectangle {
                                id: notifItemCard
                                readonly property var notifItemData: modelData
                                Layout.fillWidth: true
                                implicitHeight: notifItemCol.implicitHeight + 14
                                radius: 12
                                color: notifItemMouse.containsMouse ?
                                    (notifRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) :
                                    (notifRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03))
                                border.color: notifRoot.isDarkTheme ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(0, 0, 0, 0.06)
                                border.width: 1

                                // Card-wide click handler to activate/open the notification
                                MouseArea {
                                    id: notifItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Invoke the default action (opens the app to the notification)
                                        if (notifRoot.backend && typeof notifRoot.backend.invokeNotificationAction === "function") {
                                            notifRoot.backend.invokeNotificationAction(notifItemCard.notifItemData.id, -1)
                                        }
                                        // Close the widget popup so user lands in the app
                                        if (notifRoot.backend && typeof notifRoot.backend.expanded !== "undefined") {
                                            notifRoot.backend.expanded = false
                                        }
                                    }
                                }

                                ColumnLayout {
                                    id: notifItemCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 4

                                    // Title & Time & Dismiss Single
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: notifItemCard.notifItemData.summary || "Notification"
                                            color: notifRoot.primaryText
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: notifItemCard.notifItemData.time || ""
                                            color: notifRoot.secondaryText
                                            font.pixelSize: 10
                                        }

                                        // Dismiss Single Item
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: dismissItemMouse.containsMouse ? notifRoot.dangerColor : "transparent"

                                            Kirigami.Icon {
                                                anchors.centerIn: parent
                                                width: 10
                                                height: 10
                                                source: "window-close-symbolic"
                                                isMask: true
                                                color: dismissItemMouse.containsMouse ? "#ffffff" : notifRoot.secondaryText
                                            }

                                            MouseArea {
                                                id: dismissItemMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (notifRoot.backend && typeof notifRoot.backend.dismissNotification === "function") {
                                                        notifRoot.backend.dismissNotification(notifItemCard.notifItemData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Notification Body Text
                                    Text {
                                        text: notifItemCard.notifItemData.body || ""
                                        color: notifRoot.secondaryText
                                        font.pixelSize: 11
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                        maximumLineCount: 6
                                        elide: Text.ElideRight
                                    }

                                    // Action Buttons Flow (Wrapping, bounded width, no overflow)
                                    Flow {
                                        visible: notifItemCard.notifItemData.actions && notifItemCard.notifItemData.actions.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: notifItemCard.notifItemData.actions || []

                                            Rectangle {
                                                implicitWidth: Math.min(notifItemCard.width - 20, actionBtnText.implicitWidth + 16)
                                                implicitHeight: 24
                                                radius: 12
                                                color: actionMouse.containsMouse ? notifRoot.accentColor : (notifRoot.isDarkTheme ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))
                                                border.color: notifRoot.cardBorder
                                                border.width: 1

                                                Text {
                                                    id: actionBtnText
                                                    anchors.centerIn: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    width: Math.min(implicitWidth, parent.width - 16)
                                                    text: modelData
                                                    color: actionMouse.containsMouse ? notifRoot.accentTextColor : notifRoot.primaryText
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    horizontalAlignment: Text.AlignHCenter
                                                }

                                                MouseArea {
                                                    id: actionMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (notifRoot.backend && typeof notifRoot.backend.invokeNotificationAction === "function") {
                                                            notifRoot.backend.invokeNotificationAction(notifItemCard.notifItemData.id, index)
                                                        } else if (notifRoot.backend && typeof notifRoot.backend.dismissNotification === "function") {
                                                            notifRoot.backend.dismissNotification(notifItemCard.notifItemData.id)
                                                        }
                                                        // Close widget so user is taken to the app
                                                        if (notifRoot.backend && typeof notifRoot.backend.expanded !== "undefined") {
                                                            notifRoot.backend.expanded = false
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- 3. Clean Empty State (When 0 notifications) ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: notifRoot.totalCount === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    width: 48
                    height: 48
                    source: "notifications-disabled-symbolic"
                    isMask: true
                    color: notifRoot.secondaryText
                    opacity: 0.6
                }

                Text {
                    text: i18n("You're all caught up!")
                    color: notifRoot.primaryText
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: i18n("No new notifications right now.")
                    color: notifRoot.secondaryText
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
