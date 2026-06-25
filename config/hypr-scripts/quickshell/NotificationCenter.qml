// NotificationCenter.qml — Scrollable notification history panel (top-right,
// drops from Waybar). Esc closes; click-off handled by Shell.qml's focus grab.
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

PanelWindow {
    id: root

    property var model: null  // ObjectModel<Notification> from Shell.qml
    signal closeRequested()

    screen: Theme.focusedScreen()

    anchors { top: true; right: true }
    margins { top: Theme.panelGapTop; right: 12 }
    implicitWidth: 390
    implicitHeight: 500
    color: "transparent"

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        focus: true
        Keys.onEscapePressed: root.closeRequested()

        // ── Header ─────────────────────────────────────────────────────────────
        RowLayout {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 36

            Text {
                text: "Notifications"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }

            // Clear all
            Rectangle {
                width: 64; height: 26; radius: 6
                color: clearArea.containsMouse ? Theme.border : "transparent"
                Behavior on color { ColorAnimation { duration: 80 } }
                visible: (root.model?.values.length ?? 0) > 0

                Text {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.model) return
                        // Close all notifications (iterate backwards to avoid index shifting)
                        for (let i = root.model.values.length - 1; i >= 0; i--) {
                            root.model.values[i]?.dismiss()
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle {
            id: divider
            anchors { top: header.bottom; left: parent.left; right: parent.right; margins: 0 }
            height: 1
            color: Theme.border
        }

        // ── Notification list ───────────────────────────────────────────────────
        ScrollView {
            anchors {
                top: divider.bottom
                left: parent.left; right: parent.right; bottom: parent.bottom
                margins: 8
            }
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: parent.width
                spacing: 6

                // Empty state
                Item {
                    visible: (root.model?.values.length ?? 0) === 0
                    width: parent.width
                    height: 80

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ""
                            color: Theme.borderStrong
                            font.pixelSize: 28
                            font.family: Theme.font
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            color: Theme.grayDim
                            font.pixelSize: 13
                            font.family: Theme.font
                        }
                    }
                }

                Repeater {
                    model: root.model

                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: itemLayout.implicitHeight + 16
                        radius: 8
                        color: Theme.bgAlt
                        border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.red : Theme.border
                        border.width: 1

                        RowLayout {
                            id: itemLayout
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            spacing: 10

                            Column {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: modelData.appName
                                    color: Theme.gray
                                    font.pixelSize: 10
                                    font.family: Theme.font
                                }
                                Text {
                                    text: modelData.summary
                                    color: Theme.fgBright
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: Theme.font
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    visible: modelData.body !== ""
                                    text: modelData.body
                                    color: Theme.fgDim
                                    font.pixelSize: 11
                                    font.family: Theme.font
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: dismissArea.containsMouse ? Theme.borderStrong : "transparent"
                                Layout.alignment: Qt.AlignTop
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: Theme.gray
                                    font.pixelSize: 9
                                    font.family: Theme.font
                                }

                                MouseArea {
                                    id: dismissArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.dismiss()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
