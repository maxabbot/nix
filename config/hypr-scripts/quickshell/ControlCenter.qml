// ControlCenter.qml — Quick-settings panel (bottom-right).
// Network and Bluetooth state is read/set via nmcli and bluetoothctl (Process).
// Brightness uses brightnessctl (laptop only; silently no-ops on desktop).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    property bool dndEnabled: false
    signal dndToggled()

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    implicitWidth: 360
    implicitHeight: content.implicitHeight + 32
    color: "transparent"

    // ── State (polled on open) ──────────────────────────────────────────────────
    property bool wifiEnabled:  false
    property bool btEnabled:    false
    property string wifiSsid:   ""
    property real brightness:   1.0   // 0.0 – 1.0

    // ── Polling ─────────────────────────────────────────────────────────────────
    onVisibleChanged: if (visible) { pollWifi.running = true; pollBt.running = true; pollBright.running = true }

    Process {
        id: pollWifi
        command: ["bash", "-c", "nmcli -t -f WIFI radio; nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 || true"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line === "enabled" || line === "disabled")
                    root.wifiEnabled = (line === "enabled")
                else if (line && line !== "yes")
                    root.wifiSsid = line
            }
        }
    }

    Process {
        id: pollBt
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: SplitParser {
            onRead: (line) => root.btEnabled = (line.trim() === "on")
        }
    }

    Process {
        id: pollBright
        command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d % 2>/dev/null || echo 100"]
        stdout: SplitParser {
            onRead: (line) => {
                var pct = parseFloat(line.trim())
                if (!isNaN(pct)) root.brightness = pct / 100.0
            }
        }
    }

    Process { id: setWifi;   command: [] }
    Process { id: setBt;     command: [] }
    Process { id: setBright; command: [] }
    Process { id: setNight;  command: [] }

    function runSetWifi(enabled) {
        setWifi.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
        setWifi.running = true
    }
    function runSetBt(enabled) {
        setBt.command = ["bash", "-c", "bluetoothctl power " + (enabled ? "on" : "off")]
        setBt.running = true
    }
    function runSetBright(v) {
        setBright.command = ["brightnessctl", "s", Math.round(v * 100) + "%"]
        setBright.running = true
    }
    function runSetNight() {
        setNight.command = ["bash", "-c", "pgrep gammastep && pkill gammastep || gammastep &"]
        setNight.running = true
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Column {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            spacing: 12

            Text {
                text: "Control Center"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
            }

            // ── Toggle row ────────────────────────────────────────────────────────
            Grid {
                width: parent.width
                columns: 4
                spacing: 8

                Repeater {
                    // Static model — active/label computed in delegate to avoid mid-click delegate teardown
                    model: [
                        { icon: "", label: "Wi-Fi",          action: "wifi"  },
                        { icon: "", label: "Bluetooth",       action: "bt"    },
                        { icon: "", label: "Night Light",     action: "night" },
                        { icon: "", label: "Do Not Disturb",  action: "dnd"   },
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool tileActive: {
                            switch (modelData.action) {
                                case "wifi":  return root.wifiEnabled
                                case "bt":    return root.btEnabled
                                case "dnd":   return root.dndEnabled
                                default:      return false
                            }
                        }
                        readonly property string tileLabel:
                            modelData.action === "wifi" && root.wifiEnabled && root.wifiSsid !== ""
                                ? root.wifiSsid : modelData.label

                        width: (content.width - 24) / 4
                        height: 64
                        radius: 10
                        color: tileActive
                            ? (tileArea.containsMouse ? Theme.accentBgHover : Theme.accentBg)
                            : (tileArea.containsMouse ? Theme.borderStrong : Theme.bgAlt)

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: tileActive ? Theme.accent : Theme.gray
                                font.pixelSize: 18
                                font.family: Theme.font
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tileLabel
                                color: tileActive ? Theme.fg : Theme.gray
                                font.pixelSize: 9
                                font.family: Theme.font
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.parent.width - 8
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switch (modelData.action) {
                                    case "wifi":
                                        root.wifiEnabled = !root.wifiEnabled
                                        root.runSetWifi(root.wifiEnabled)
                                        break
                                    case "bt":
                                        root.btEnabled = !root.btEnabled
                                        root.runSetBt(root.btEnabled)
                                        break
                                    case "night":
                                        root.runSetNight()
                                        break
                                    case "dnd":
                                        root.dndToggled()
                                        break
                                }
                            }
                        }
                    }
                }
            }

            // ── Brightness ────────────────────────────────────────────────────────
            SliderRow {
                width: parent.width
                label: "  Brightness"
                value: root.brightness
                onMoved: (v) => {
                    root.brightness = v
                    root.runSetBright(v)
                }
            }
        }
    }
}
