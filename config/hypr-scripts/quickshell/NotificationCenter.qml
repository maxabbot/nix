// NotificationCenter.qml — Scrollable notification history panel (bottom-right).
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

PanelWindow {
    id: root

    property var model: null  // ObjectModel<Notification> from Shell.qml

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    width: 390
    height: 500
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#282828"
        border.color: "#3c3836"
        border.width: 1

        // ── Header ─────────────────────────────────────────────────────────────
        RowLayout {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 36

            Text {
                text: "Notifications"
                color: "#d4be98"
                font.pixelSize: 14
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
            }

            // Clear all
            Rectangle {
                width: 64; height: 26; radius: 6
                color: clearArea.containsMouse ? "#3c3836" : "transparent"
                Behavior on color { ColorAnimation { duration: 80 } }
                visible: (root.model?.count ?? 0) > 0

                Text {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: "#928374"
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.model) return
                        // Close all notifications (iterate backwards to avoid index shifting)
                        for (let i = root.model.count - 1; i >= 0; i--) {
                            root.model.values[i]?.close(NotificationCloseReason.Dismissed)
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
            color: "#3c3836"
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
                    visible: (root.model?.count ?? 0) === 0
                    width: parent.width
                    height: 80

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ""
                            color: "#504945"
                            font.pixelSize: 28
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            color: "#665c54"
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
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
                        color: "#32302f"
                        border.color: modelData.urgency === NotificationUrgency.Critical ? "#ea6962" : "#3c3836"
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
                                    color: "#928374"
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                Text {
                                    text: modelData.summary
                                    color: "#ebdbb2"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    visible: modelData.body !== ""
                                    text: modelData.body
                                    color: "#bdae93"
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono Nerd Font"
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: dismissArea.containsMouse ? "#504945" : "transparent"
                                Layout.alignment: Qt.AlignTop
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#928374"
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                MouseArea {
                                    id: dismissArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.close(NotificationCloseReason.Dismissed)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
