// BarButton.qml — Reusable icon button for the bottom bar.
import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root

    property string icon: ""
    property string tooltip: ""
    property bool active: false
    property int badge: 0          // badge count (0 = hidden)

    signal clicked()

    implicitWidth: 34
    implicitHeight: 34
    radius: 8
    color: area.containsMouse ? Theme.border : (active ? Theme.accentBg : "transparent")

    Behavior on color { ColorAnimation { duration: 80 } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active ? Theme.accent : Theme.fg
        font.pixelSize: 15
        font.family: Theme.font
        renderType: Text.NativeRendering
    }

    // Notification badge
    Rectangle {
        visible: root.badge > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
        width: Math.max(14, badgeTxt.implicitWidth + 6)
        height: 14
        radius: 7
        color: Theme.red

        Text {
            id: badgeTxt
            anchors.centerIn: parent
            text: root.badge > 99 ? "99+" : root.badge
            color: Theme.bgHard
            font.pixelSize: 8
            font.bold: true
            font.family: Theme.font
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ToolTip.visible: area.containsMouse && root.tooltip !== ""
    ToolTip.text: root.tooltip
    ToolTip.delay: 600
}
