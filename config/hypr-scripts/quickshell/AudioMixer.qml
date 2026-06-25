// AudioMixer.qml — PipeWire audio page (embedded in Settings.qml — no window chrome).
// Uses Quickshell.Services.Pipewire for native PipeWire access: default sink/source
// volume + mute, device selection (set the default sink/source), per-app stream
// volumes, plus an EasyEffects-backed equalizer section.
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // The default sink/source must be bound before .audio/.ready populate —
    // untracked nodes leave the Volume/Mic sliders stuck at 0 and read-only.
    // (The per-app section already binds its streams via the Repeater model.)
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(n => n)
    }

    // ── EQ state (polled on open) ───────────────────────────────────────────────
    property bool eqEnabled: false
    onVisibleChanged: if (visible) pollEq.running = true

    Process {
        id: pollEq
        command: ["bash", "-c", "pgrep -x easyeffects >/dev/null && echo on || echo off"]
        stdout: SplitParser { onRead: (line) => root.eqEnabled = (line.trim() === "on") }
    }

    Process { id: eqProc;     command: [] }
    Process { id: eqPreset;   command: [] }
    Process { id: eqOpen;     command: ["easyeffects"] }

    function runEq(on) {
        eqProc.command = ["bash", "-c", on
            ? "easyeffects --gapplication-service >/dev/null 2>&1 &"
            : "easyeffects -q >/dev/null 2>&1 || pkill -x easyeffects"]
        eqProc.running = true
        root.eqEnabled = on
    }
    function loadPreset(name) {
        // Best-effort: applies a named EasyEffects output preset if it exists.
        eqPreset.command = ["bash", "-c",
            "pgrep -x easyeffects >/dev/null || (easyeffects --gapplication-service >/dev/null 2>&1 &); "
            + "sleep 0.3; easyeffects -l " + name + " >/dev/null 2>&1 || true"]
        eqPreset.running = true
        root.eqEnabled = true
    }

    // ── Reusable default-device picker ──────────────────────────────────────────
    // `sink: true` lists output devices (Audio/Sink) and rebinds the default sink;
    // `false` lists inputs (Audio/Source) and rebinds the default source.
    component DevicePicker: Column {
        id: picker
        property bool sink: true
        width: parent ? parent.width : 0
        spacing: 4

        // The actual list model — a plain array of matching PipeWire nodes.
        // (A Repeater can't iterate a PwObjectTracker; that only *binds* nodes.)
        readonly property var devices: (Pipewire.nodes?.values ?? []).filter(n =>
            n && n.mediaClass === (picker.sink ? "Audio/Sink" : "Audio/Source"))

        // Keep the listed nodes bound so description/name stay populated.
        PwObjectTracker { objects: picker.devices }

        Repeater {
            model: picker.devices

            delegate: Rectangle {
                id: devRow
                required property var modelData
                readonly property bool isDefault: picker.sink
                    ? (Pipewire.defaultAudioSink?.id === modelData.id)
                    : (Pipewire.defaultAudioSource?.id === modelData.id)

                width: picker.width
                height: 26
                radius: 6
                color: isDefault
                    ? Theme.accentBg
                    : (devArea.containsMouse ? Theme.bgSoft : "transparent")
                Behavior on color { ColorAnimation { duration: 80 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 6

                    Text {
                        text: devRow.isDefault ? "" : ""
                        color: devRow.isDefault ? Theme.accent : Theme.grayDim
                        font.pixelSize: 11
                        font.family: Theme.font
                    }
                    Text {
                        text: modelData.description ?? modelData.nickname ?? modelData.name ?? "?"
                        color: devRow.isDefault ? Theme.fg : Theme.gray
                        font.pixelSize: 11
                        font.family: Theme.font
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: devArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (picker.sink) Pipewire.preferredDefaultAudioSink = modelData
                        else             Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
        }
    }

    Column {
        id: content
        anchors { top: parent.top; left: parent.left; right: parent.right }
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

            DevicePicker { sink: true }
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

            DevicePicker { sink: false }
        }

        // Divider
        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ── Equalizer (EasyEffects) ─────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 8

            RowLayout {
                width: parent.width

                Text {
                    text: "󰓃"
                    color: Theme.yellow
                    font.pixelSize: 14
                    font.family: Theme.font
                }
                Text {
                    text: "Equalizer"
                    color: Theme.fg
                    font.pixelSize: 12
                    font.family: Theme.font
                    Layout.fillWidth: true
                    leftPadding: 8
                }
                // Enable / disable EasyEffects processing
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: root.eqEnabled ? Theme.accentBg : Theme.bgAlt
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        x: root.eqEnabled ? parent.width - width - 3 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.eqEnabled ? Theme.accent : Theme.gray
                        Behavior on x { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runEq(!root.eqEnabled)
                    }
                }
            }

            // Preset chips (best-effort — apply named EasyEffects output presets)
            RowLayout {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["Flat", "Bass", "Vocal"]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 26
                        radius: 6
                        color: presetArea.containsMouse ? Theme.bgSoft : Theme.bgAlt
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.gray
                            font.pixelSize: 11
                            font.family: Theme.font
                        }
                        MouseArea {
                            id: presetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadPreset(modelData)
                        }
                    }
                }

                // Open the full EasyEffects GUI
                Rectangle {
                    Layout.preferredWidth: 36
                    height: 26
                    radius: 6
                    color: openArea.containsMouse ? Theme.bgSoft : Theme.bgAlt
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰍜"
                        color: Theme.gray
                        font.pixelSize: 13
                        font.family: Theme.font
                    }
                    MouseArea {
                        id: openArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: eqOpen.running = true
                    }
                }
            }
        }

        // ── Per-stream volumes ──────────────────────────────────────────────────
        // Shows output streams (apps playing audio)
        Column {
            id: appsCol
            width: parent.width
            spacing: 6
            visible: streamRepeater.count > 0

            // Output streams (apps producing sound). Plain array model; the
            // tracker keeps each stream's audio sub-object live for the slider.
            readonly property var streams: (Pipewire.nodes?.values ?? []).filter(n =>
                n && n.mediaClass === "Stream/Output/Audio")

            PwObjectTracker { objects: appsCol.streams }

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
                model: appsCol.streams

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
