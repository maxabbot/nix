// NotificationToast.qml — Transient popup card for incoming notifications.
// Placed by Shell.qml in a top-right PanelWindow via Repeater over NotificationServer.notifications.
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var notification  // Notification from NotificationServer

    readonly property color urgencyColor: {
        switch (notification.urgency) {
            case NotificationUrgency.Low:      return Theme.border
            case NotificationUrgency.Critical: return Theme.redDark
            default:                           return Theme.toastBg
        }
    }

    radius: 10
    color: urgencyColor
    border.color: notification.urgency === NotificationUrgency.Critical ? Theme.red : Theme.borderStrong
    border.width: 1
    implicitHeight: body.implicitHeight + 20

    // Auto-dismiss after timeout (or 6 s default). Critical notifications never
    // auto-expire per the freedesktop spec — they stay until explicitly dismissed.
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical

    Timer {
        interval: notification.expireTimeout > 0 ? notification.expireTimeout : 6000
        running: !root.critical
        onTriggered: notification.expire()
    }

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 10

        // Preview thumbnail — screenshots set the image-path hint, which
        // Quickshell exposes via notification.image as a ready-to-use
        // image://icon/<path> URL. Hidden when the notification has no image.
        Rectangle {
            visible: root.notification.image !== ""
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            Layout.alignment: Qt.AlignTop
            radius: 6
            color: "transparent"
            clip: true

            Image {
                anchors.fill: parent
                source: root.notification.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: 104
                sourceSize.height: 104
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: notification.appName
                color: Theme.gray
                font.pixelSize: 10
                font.family: Theme.font
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: notification.summary
                color: Theme.fgBright
                font.pixelSize: 13
                font.bold: true
                font.family: Theme.font
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                visible: notification.body !== ""
                text: notification.body
                color: Theme.fgSoft
                font.pixelSize: 12
                font.family: Theme.font
                wrapMode: Text.WordWrap
                width: parent.width
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        // Dismiss button
        Rectangle {
            width: 22
            height: 22
            radius: 11
            color: closeArea.containsMouse ? Theme.borderStrong : "transparent"
            Layout.alignment: Qt.AlignTop
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: ""
                color: Theme.gray
                font.pixelSize: 10
                font.family: Theme.font
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notification.dismiss()
            }
        }
    }
}
