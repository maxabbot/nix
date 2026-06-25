// SysInfoPanel.qml — System stats page (embedded in Settings.qml — no window chrome).
// CPU / memory / temperature / disk via /proc and df; GPU via nvidia-smi
// (row hidden when nvidia-smi is absent — VM and work-laptop).
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // ── State (polled while visible) ────────────────────────────────────────────
    property real cpu:      0     // 0.0 – 1.0
    property int  cpuTemp:  0
    property real mem:      0
    property string memText: ""
    property real disk:     0
    property string diskText: ""
    property bool hasGpu:   false
    property real gpu:      0
    property int  gpuTemp:  0
    property var  fans:     []   // [{label, rpm}] from lm_sensors

    onVisibleChanged: if (visible) { poll.running = true; pollSensors.running = true }
    Timer {
        interval: 2000; repeat: true
        running: root.visible
        onTriggered: {
            if (!poll.running) poll.running = true
            if (!pollSensors.running) pollSensors.running = true
        }
    }

    // Fan RPMs via lm_sensors. `sensors -u` is line-based (no jq needed); skip
    // headers reading 0 so disconnected fan connectors don't clutter the list.
    Process {
        id: pollSensors
        command: ["bash", "-c",
            "command -v sensors >/dev/null 2>&1 && sensors -u 2>/dev/null | " +
            "awk '/fan[0-9]+_input:/{name=$1; sub(/_input:/,\"\",name); rpm=int($2); if(rpm>0) print name, rpm}'"]
        property var accum: []
        stdout: SplitParser {
            onRead: (line) => {
                var p = line.trim().split(/\s+/)
                if (p.length < 2) return
                var rpm = parseInt(p[1])
                if (isNaN(rpm)) return
                pollSensors.accum.push({ label: p[0], rpm: rpm })
            }
        }
        onRunningChanged: { if (running) accum = []; else { root.fans = accum; accum = [] } }
    }

    Process {
        id: poll
        // One line per stat: "<key> <values...>". CPU% from two /proc/stat
        // samples; thermal zone found by type, not index (see waybar-sysinfo).
        command: ["bash", "-c", `
read -r a1 t1 < <(awk '/^cpu /{print $2+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
sleep 0.3
read -r a2 t2 < <(awk '/^cpu /{print $2+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
echo "cpu $(( (a2-a1)*100/(t2-t1) ))"
for z in /sys/class/thermal/thermal_zone*; do
  case "$(cat "$z/type" 2>/dev/null)" in
    x86_pkg_temp|k10temp|coretemp) echo "temp $(( $(cat "$z/temp" 2>/dev/null || echo 0) / 1000 ))"; break ;;
  esac
done
free -h | awk '/^Mem:/{print "memtext", $3, $2}'
awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print "mem", int(100*(t-a)/t)}' /proc/meminfo
df -h --output=pcent,used,size / | awk 'NR==2{gsub("%",""); print "disk", $1, $2, $3}'
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null |
    awk -F', *' '{print "gpu", $1, $2}'
fi
`]
        stdout: SplitParser {
            onRead: (line) => {
                var p = line.trim().split(/\s+/)
                switch (p[0]) {
                    case "cpu":     root.cpu = parseInt(p[1]) / 100; break
                    case "temp":    root.cpuTemp = parseInt(p[1]); break
                    case "mem":     root.mem = parseInt(p[1]) / 100; break
                    case "memtext": root.memText = p[1] + " / " + p[2]; break
                    case "disk":    root.disk = parseInt(p[1]) / 100; root.diskText = p[2] + " / " + p[3]; break
                    case "gpu":     root.hasGpu = true; root.gpu = parseInt(p[1]) / 100; root.gpuTemp = parseInt(p[2]); break
                }
            }
        }
    }

    // ── Shared stat row: label + value text over a thin progress bar ────────────
    component StatRow: Column {
        property string label
        property string valueText
        property real frac: 0
        property color barColor: Theme.accent

        width: parent.width
        spacing: 5

        RowLayout {
            width: parent.width
            Text {
                text: label
                color: Theme.fg
                font.pixelSize: 12
                font.family: Theme.font
                Layout.fillWidth: true
            }
            Text {
                text: valueText
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
        }
        Rectangle {
            width: parent.width; height: 6; radius: 3
            color: Theme.bgAlt
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, frac))
                height: parent.height; radius: 3
                color: frac > 0.9 ? Theme.red : barColor
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    Column {
        id: content
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14

        RowLayout {
            width: parent.width

            Text {
                text: "System"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }

            // btop shortcut for the deep dive
            Rectangle {
                width: btopLabel.implicitWidth + 16; height: 24; radius: 7
                color: btopArea.containsMouse ? Theme.borderStrong : Theme.bgAlt
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    id: btopLabel
                    anchors.centerIn: parent
                    text: "btop"
                    color: Theme.fgDim
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                MouseArea {
                    id: btopArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { launchBtop.running = true }
                }
                Process { id: launchBtop; command: ["kitty", "-e", "btop"] }
            }
        }

        StatRow {
            label: " CPU"
            valueText: Math.round(root.cpu * 100) + "%   " + root.cpuTemp + "°C"
            frac: root.cpu
            barColor: Theme.purple
        }

        StatRow {
            label: " Memory"
            valueText: Math.round(root.mem * 100) + "%   " + root.memText
            frac: root.mem
            barColor: Theme.yellow
        }

        StatRow {
            label: "󰋊 Disk /"
            valueText: Math.round(root.disk * 100) + "%   " + root.diskText
            frac: root.disk
            barColor: Theme.accent
        }

        StatRow {
            visible: root.hasGpu
            label: "󰢮 GPU"
            valueText: Math.round(root.gpu * 100) + "%   " + root.gpuTemp + "°C"
            frac: root.gpu
            barColor: Theme.green
        }

        // ── Fans ──────────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 6
            visible: root.fans.length > 0

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Text {
                text: "Fans"
                color: Theme.gray
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.font
            }

            Repeater {
                model: root.fans

                delegate: RowLayout {
                    required property var modelData
                    width: content.width
                    Text {
                        text: "󰈐 " + modelData.label
                        color: Theme.fg
                        font.pixelSize: 12
                        font.family: Theme.font
                        Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.rpm + " RPM"
                        color: Theme.gray
                        font.pixelSize: 11
                        font.family: Theme.font
                    }
                }
            }
        }
    }
}
