// KeyboardPanel.qml — Keyboard page (embedded in Settings.qml — no window chrome).
// Layout switcher (hyprctl switchxkblayout), repeat rate + delay
// (hyprctl keyword input:repeat_rate/repeat_delay), and keyboard backlight
// (brightnessctl kbd_backlight — laptop only; the row hides when absent).
// hyprctl keyword changes are runtime-only and reset on a Hyprland reload.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string kbName:       ""
    property string activeKeymap: ""
    property var    layouts:      []   // configured kb_layout codes
    property int    repeatRate:   25
    property int    repeatDelay:  600
    property real   kbdBacklight: 0.0
    property bool   kbdAvail:     false

    onVisibleChanged: if (visible) {
        pollKb.running = true; pollLayouts.running = true
        pollRate.running = true; pollDelay.running = true; pollKbd.running = true
    }

    Process {
        id: pollKb
        command: ["bash", "-c",
            "hyprctl devices -j | jq -r '([.keyboards[]|select(.main)][0] // .keyboards[0]) | .name, .active_keymap'"]
        property int idx: 0
        stdout: SplitParser {
            onRead: (line) => {
                if (pollKb.idx === 0) root.kbName = line.trim()
                else root.activeKeymap = line.trim()
                pollKb.idx = (pollKb.idx + 1) % 2
            }
        }
        onRunningChanged: if (running) idx = 0
    }

    Process {
        id: pollLayouts
        command: ["bash", "-c", "hyprctl getoption input:kb_layout -j | jq -r '.str'"]
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim()
                root.layouts = s === "" ? [] : s.split(",")
            }
        }
    }

    Process {
        id: pollRate
        command: ["bash", "-c", "hyprctl getoption input:repeat_rate -j | jq -r '.int'"]
        stdout: SplitParser { onRead: (line) => { var n = parseInt(line.trim()); if (!isNaN(n)) root.repeatRate = n } }
    }
    Process {
        id: pollDelay
        command: ["bash", "-c", "hyprctl getoption input:repeat_delay -j | jq -r '.int'"]
        stdout: SplitParser { onRead: (line) => { var n = parseInt(line.trim()); if (!isNaN(n)) root.repeatDelay = n } }
    }

    Process {
        id: pollKbd
        command: ["bash", "-c",
            "d=$(brightnessctl --list 2>/dev/null | grep -oP \"Device '\\K[^']*kbd_backlight\" | head -n1); " +
            "[ -z \"$d\" ] && { echo NONE; exit 0; }; " +
            "cur=$(brightnessctl -d \"$d\" get); max=$(brightnessctl -d \"$d\" max); " +
            "echo \"$d|$cur|$max\""]
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim()
                if (s === "NONE") { root.kbdAvail = false; return }
                var p = s.split("|")
                if (p.length < 3) return
                root.kbdAvail = true
                root._kbdDev = p[0]
                var mx = parseInt(p[2]) || 1
                root.kbdBacklight = (parseInt(p[1]) || 0) / mx
            }
        }
    }
    property string _kbdDev: ""

    Process { id: setLayout; command: [] }
    Process { id: setRate;   command: [] }
    Process { id: setDelay;  command: [] }
    Process { id: setKbd;    command: [] }

    function cycleLayout() {
        if (root.kbName === "") return
        setLayout.command = ["hyprctl", "switchxkblayout", root.kbName, "next"]
        setLayout.running = true
        Qt.callLater(() => pollKb.running = true)
    }
    function applyRate(v)  { setRate.command  = ["hyprctl", "keyword", "input:repeat_rate", String(Math.round(v))];  setRate.running = true }
    function applyDelay(v) { setDelay.command = ["hyprctl", "keyword", "input:repeat_delay", String(Math.round(v))]; setDelay.running = true }
    function applyKbd(v) {
        if (root._kbdDev === "") return
        setKbd.command = ["brightnessctl", "-d", root._kbdDev, "s", Math.round(v * 100) + "%"]
        setKbd.running = true
    }

    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14

        Text {
            text: "Keyboard"
            color: Theme.fg
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.font
        }

        // ── Layout ─────────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 6

            Text {
                text: "Layout"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
            Rectangle {
                width: parent.width
                height: 40
                radius: 8
                color: layoutArea.containsMouse ? Theme.bgSoft : Theme.bgAlt
                Behavior on color { ColorAnimation { duration: 80 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    Text {
                        text: root.activeKeymap !== "" ? root.activeKeymap : "—"
                        color: Theme.fg
                        font.pixelSize: 12
                        font.family: Theme.font
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: root.layouts.length > 1
                        text: "switch "
                        color: Theme.accent
                        font.pixelSize: 12
                        font.family: Theme.font
                    }
                }
                MouseArea {
                    id: layoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.layouts.length > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.cycleLayout()
                }
            }
            Text {
                visible: root.layouts.length > 0
                text: "Configured: " + root.layouts.join(", ")
                color: Theme.grayDim
                font.pixelSize: 10
                font.family: Theme.font
            }
        }

        // ── Repeat ─────────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 8

            Text {
                text: "Key repeat"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
            SliderRow {
                width: parent.width
                label: "Rate"
                from: 10; to: 60; unit: "/s"
                value: root.repeatRate
                onMoved: (v) => { root.repeatRate = Math.round(v); root.applyRate(v) }
            }
            SliderRow {
                width: parent.width
                label: "Delay"
                from: 150; to: 800; unit: "ms"
                value: root.repeatDelay
                onMoved: (v) => { root.repeatDelay = Math.round(v); root.applyDelay(v) }
            }
        }

        // ── Backlight (laptop only) ──────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 8
            visible: root.kbdAvail

            Text {
                text: "Backlight"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
            SliderRow {
                width: parent.width
                label: "  Brightness"
                value: root.kbdBacklight
                onMoved: (v) => { root.kbdBacklight = v; root.applyKbd(v) }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Repeat and layout changes apply at runtime and reset on a Hyprland reload."
            color: Theme.grayDim
            font.pixelSize: 10
            font.family: Theme.font
        }
    }
}
