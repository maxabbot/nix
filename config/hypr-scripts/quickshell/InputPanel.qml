// InputPanel.qml — Input page (embedded in Settings.qml — no window chrome).
// Touchpad tap-to-click + natural scroll and pointer sensitivity via
// hyprctl keyword input:*. Runtime-only — resets on a Hyprland reload.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool tapToClick:   false
    property bool naturalScroll: false
    property real sensitivity:  0.0   // -1.0 … 1.0

    onVisibleChanged: if (visible) { pollTap.running = true; pollScroll.running = true; pollSens.running = true }

    Process {
        id: pollTap
        command: ["bash", "-c", "hyprctl getoption input:touchpad:tap-to-click -j | jq -r '.int'"]
        stdout: SplitParser { onRead: (line) => root.tapToClick = (line.trim() === "1") }
    }
    Process {
        id: pollScroll
        command: ["bash", "-c", "hyprctl getoption input:touchpad:natural_scroll -j | jq -r '.int'"]
        stdout: SplitParser { onRead: (line) => root.naturalScroll = (line.trim() === "1") }
    }
    Process {
        id: pollSens
        command: ["bash", "-c", "hyprctl getoption input:sensitivity -j | jq -r '.float'"]
        stdout: SplitParser { onRead: (line) => { var f = parseFloat(line.trim()); if (!isNaN(f)) root.sensitivity = f } }
    }

    Process { id: setOpt; command: [] }
    function applyOpt(key, value) {
        setOpt.command = ["hyprctl", "keyword", key, String(value)]
        setOpt.running = true
    }

    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14

        Text {
            text: "Input"
            color: Theme.fg
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.font
        }

        Text {
            text: "Touchpad"
            color: Theme.gray
            font.pixelSize: 11
            font.bold: true
            font.family: Theme.font
        }

        ToggleRow {
            width: parent.width
            label: "Tap to click"
            checked: root.tapToClick
            onToggled: (v) => { root.tapToClick = v; root.applyOpt("input:touchpad:tap-to-click", v ? 1 : 0) }
        }
        ToggleRow {
            width: parent.width
            label: "Natural scroll"
            checked: root.naturalScroll
            onToggled: (v) => { root.naturalScroll = v; root.applyOpt("input:touchpad:natural_scroll", v ? 1 : 0) }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Text {
            text: "Pointer"
            color: Theme.gray
            font.pixelSize: 11
            font.bold: true
            font.family: Theme.font
        }

        SliderRow {
            width: parent.width
            label: "Sensitivity"
            from: -100; to: 100; unit: ""
            value: root.sensitivity * 100
            onMoved: (v) => {
                root.sensitivity = v / 100
                root.applyOpt("input:sensitivity", (v / 100).toFixed(2))
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Changes apply at runtime and reset on a Hyprland reload. Touchpad options have no effect without a touchpad."
            color: Theme.grayDim
            font.pixelSize: 10
            font.family: Theme.font
        }
    }

    // ── Label + toggle switch ───────────────────────────────────────────────────
    component ToggleRow: RowLayout {
        property string label: ""
        property bool checked: false
        signal toggled(bool value)

        spacing: 8

        Text {
            text: parent.label
            color: Theme.fgDim
            font.pixelSize: 12
            font.family: Theme.font
            Layout.fillWidth: true
        }
        Rectangle {
            width: 44; height: 24; radius: 12
            color: parent.checked ? Theme.accentBg : Theme.bgAlt
            Behavior on color { ColorAnimation { duration: 100 } }
            Rectangle {
                width: 18; height: 18; radius: 9
                x: parent.parent.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: parent.parent.checked ? Theme.accent : Theme.gray
                Behavior on x { NumberAnimation { duration: 100 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.toggled(!parent.parent.checked)
            }
        }
    }
}
