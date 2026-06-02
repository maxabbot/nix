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
            case NotificationUrgency.Low:      return "#3c3836"
            case NotificationUrgency.Critical: return "#6b2a2a"
            default:                           return "#2d3b3b"
        }
    }

    radius: 10
    color: urgencyColor
    border.color: notification.urgency === NotificationUrgency.Critical ? "#ea6962" : "#504945"
    border.width: 1
    implicitHeight: body.implicitHeight + 20

    // Auto-dismiss after timeout (or 6 s default for persistent/unspecified notifications)
    Timer {
        interval: notification.expireTimeout > 0 ? notification.expireTimeout : 6000
        running: true
        onTriggered: notification.close(NotificationCloseReason.Expired)
    }

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 10

        Column {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: notification.appName
                color: "#928374"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: notification.summary
                color: "#ebdbb2"
                font.pixelSize: 13
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                visible: notification.body !== ""
                text: notification.body
                color: "#d5c4a1"
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
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
            color: closeArea.containsMouse ? "#504945" : "transparent"
            Layout.alignment: Qt.AlignTop
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: ""
                color: "#928374"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notification.close(NotificationCloseReason.Dismissed)
            }
        }
    }
}
