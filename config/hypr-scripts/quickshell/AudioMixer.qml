// AudioMixer.qml — PipeWire volume panel (bottom-right).
// Uses Quickshell.Services.Pipewire for native PipeWire access.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    implicitWidth: 360
    implicitHeight: content.implicitHeight + 32
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Column {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            spacing: 14

            // ── Header ───────────────────────────────────────────────────────────
            Text {
                text: "Audio"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
            }

            // ── Output (default sink) ─────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8

                RowLayout {
                    width: parent.width

                    Text {
                        text: ""
                        color: Theme.accent
                        font.pixelSize: 14
                        font.family: Theme.font
                    }

                    Text {
                        text: "Output"
                        color: Theme.fg
                        font.pixelSize: 12
                        font.family: Theme.font
                        Layout.fillWidth: true
                        leftPadding: 8
                    }

                    // Mute toggle
                    Rectangle {
                        width: 28; height: 28; radius: 7
                        color: muteOutArea.containsMouse ? Theme.border : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: (Pipewire.defaultAudioSink?.audio?.muted ?? false) ? "" : ""
                            color: (Pipewire.defaultAudioSink?.audio?.muted ?? false) ? Theme.red : Theme.gray
                            font.pixelSize: 13
                            font.family: Theme.font
                        }

                        MouseArea {
                            id: muteOutArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Pipewire.defaultAudioSink?.ready && Pipewire.defaultAudioSink?.audio)
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                            }
                        }
                    }
                }

                SliderRow {
                    width: parent.width
                    label: "Volume"
                    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                    onMoved: (v) => {
                        if (Pipewire.defaultAudioSink?.ready && Pipewire.defaultAudioSink?.audio)
                            Pipewire.defaultAudioSink.audio.volume = v
                    }
                }
            }

            // Divider
            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ── Input (default source) ─────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8

                RowLayout {
                    width: parent.width

                    Text {
                        text: ""
                        color: Theme.purple
                        font.pixelSize: 14
                        font.family: Theme.font
                    }

                    Text {
                        text: "Input"
                        color: Theme.fg
                        font.pixelSize: 12
                        font.family: Theme.font
                        Layout.fillWidth: true
                        leftPadding: 8
                    }

                    // Mute microphone toggle
                    Rectangle {
                        width: 28; height: 28; radius: 7
                        color: muteInArea.containsMouse ? Theme.border : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: (Pipewire.defaultAudioSource?.audio?.muted ?? false) ? "" : ""
                            color: (Pipewire.defaultAudioSource?.audio?.muted ?? false) ? Theme.red : Theme.gray
                            font.pixelSize: 13
                            font.family: Theme.font
                        }

                        MouseArea {
                            id: muteInArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Pipewire.defaultAudioSource?.ready && Pipewire.defaultAudioSource?.audio)
                                    Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                            }
                        }
                    }
                }

                SliderRow {
                    width: parent.width
                    label: "Mic"
                    value: Pipewire.defaultAudioSource?.audio?.volume ?? 0
                    onMoved: (v) => {
                        if (Pipewire.defaultAudioSource?.ready && Pipewire.defaultAudioSource?.audio)
                            Pipewire.defaultAudioSource.audio.volume = v
                    }
                }
            }

            // ── Per-stream volumes ──────────────────────────────────────────────────
            // Shows output streams (apps playing audio)
            Column {
                width: parent.width
                spacing: 6
                visible: streamRepeater.count > 0

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                Text {
                    text: "Apps"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.font
                }

                Repeater {
                    id: streamRepeater
                    // Filter to output audio streams (apps producing sound)
                    model: PwObjectTracker {
                        objects: (Pipewire.nodes?.values ?? []).filter(n =>
                            n.mediaClass === "Stream/Output/Audio" && n.isSink
                        )
                    }

                    delegate: SliderRow {
                        required property var modelData
                        width: content.width
                        label: (modelData.name?.length ?? 0) > 12 ? modelData.name.slice(0, 12) + "…" : (modelData.name ?? "")
                        value: modelData.audio?.volume ?? 0
                        onMoved: (v) => { if (modelData.ready && modelData.audio) modelData.audio.volume = v }
                    }
                }
            }
        }
    }
}
