// ControlCenter.qml — Quick-settings page (embedded in Settings.qml — no window chrome).
// Network/Bluetooth/profile state is read/set via nmcli, bluetoothctl, powerprofilesctl
// and friends (Process). Mic mute is native PipeWire. Brightness uses brightnessctl
// (laptop only; silently no-ops on desktop).
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool dndEnabled: false
    signal dndToggled()

    // ── State (polled on open) ──────────────────────────────────────────────────
    property bool   wifiEnabled:   false
    property bool   btEnabled:     false
    property string wifiSsid:      ""
    property real   brightness:    1.0   // 0.0 – 1.0
    property bool   nightActive:   false
    property int    nightTemp:     4000  // K — applied while night light is on
    property string powerProfile:  "balanced"  // power-saver | balanced | performance
    property bool   caffeine:      false // true = hypridle killed (idle inhibited)
    property bool   gameMode:      false
    property bool   tailscaleAvail: false
    property bool   tailscaleUp:   false

    // Airplane mode is derived: both radios down.
    readonly property bool airplane: !wifiEnabled && !btEnabled
    // Mic mute is reactive off PipeWire.
    readonly property bool micMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource].filter(n => n)
    }

    // ── Polling ─────────────────────────────────────────────────────────────────
    onVisibleChanged: if (visible) {
        pollWifi.running = true; pollBt.running = true; pollBright.running = true
        pollNight.running = true; pollProfile.running = true; pollCaffeine.running = true
        pollGame.running = true; pollTailscale.running = true
    }

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

    Process {
        id: pollNight
        // gammastep also runs as an automatic day/night systemd user service, so
        // pgrep can't tell a manual override apart — a runtime flag file marks it.
        command: ["bash", "-c", "d=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell\"; [ -f \"$d/nightlight\" ] && echo on || echo off"]
        stdout: SplitParser {
            onRead: (line) => root.nightActive = (line.trim() === "on")
        }
    }

    Process {
        id: pollProfile
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "") root.powerProfile = line.trim() }
        }
    }

    Process {
        id: pollCaffeine
        // caffeine ON == idle daemon NOT running
        command: ["bash", "-c", "pgrep -x hypridle >/dev/null && echo off || echo on"]
        stdout: SplitParser {
            onRead: (line) => root.caffeine = (line.trim() === "on")
        }
    }

    Process {
        id: pollGame
        command: ["bash", "-c", "hyprctl getoption decoration:blur:enabled -j 2>/dev/null | grep -q '\"int\": 0' && echo on || echo off"]
        stdout: SplitParser {
            onRead: (line) => root.gameMode = (line.trim() === "on")
        }
    }

    Process {
        id: pollTailscale
        command: ["bash", "-c", "command -v tailscale >/dev/null || { echo noavail; exit 0; }; tailscale status --json 2>/dev/null | grep -q '\"BackendState\": \"Running\"' && echo up || echo down"]
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim()
                if (s === "noavail") { root.tailscaleAvail = false; return }
                root.tailscaleAvail = true
                root.tailscaleUp = (s === "up")
            }
        }
    }

    // ── Action processes ────────────────────────────────────────────────────────
    Process { id: setWifi;      command: [] }
    Process { id: setBt;        command: [] }
    Process { id: setBright;    command: [] }
    Process { id: setNight;     command: [] }
    Process { id: setAirplane;  command: [] }
    Process { id: setProfile;   command: [] }
    Process { id: setCaffeine;  command: [] }
    Process { id: setGame;      command: [] }
    Process { id: setTailscale; command: [] }

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
    // Night light is a manual override over the automatic gammastep service:
    //   on  → stop the service, hold a manual temperature (gammastep -P -O <temp>)
    //   off → reset gamma and restart the automatic day/night service
    // A runtime flag file records the override so polling reflects it. Relaunching
    // on every slider change keeps the active temp matched to the slider.
    function runNight(on) {
        setNight.command = ["bash", "-c", on
            ? "d=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell\"; mkdir -p \"$d\"; touch \"$d/nightlight\"; "
              + "systemctl --user stop gammastep 2>/dev/null; pkill -x gammastep 2>/dev/null; sleep 0.2; "
              + "gammastep -P -O " + root.nightTemp + " >/dev/null 2>&1 &"
            : "d=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell\"; rm -f \"$d/nightlight\"; "
              + "pkill -x gammastep 2>/dev/null; gammastep -x >/dev/null 2>&1; "
              + "systemctl --user restart gammastep 2>/dev/null &"]
        setNight.running = true
        root.nightActive = on
    }
    function runAirplane(on) {
        // on → both radios off; off → wifi back on (BT left for the user to re-enable)
        setAirplane.command = ["bash", "-c", on
            ? "nmcli radio all off; bluetoothctl power off"
            : "nmcli radio wifi on"]
        setAirplane.running = true
        root.wifiEnabled = !on
        if (on) root.btEnabled = false
    }
    function runCycleProfile() {
        var order = ["power-saver", "balanced", "performance"]
        var i = order.indexOf(root.powerProfile)
        var next = order[(i + 1) % order.length]
        root.powerProfile = next
        setProfile.command = ["powerprofilesctl", "set", next]
        setProfile.running = true
    }
    function runCaffeine(on) {
        // on → kill hypridle (inhibit idle); off → restart it
        setCaffeine.command = ["bash", "-c", on
            ? "pkill -x hypridle 2>/dev/null || true"
            : "pgrep -x hypridle >/dev/null || (hypridle >/dev/null 2>&1 &)"]
        setCaffeine.running = true
        root.caffeine = on
    }
    function runGameMode(on) {
        setGame.command = ["bash", "-c", on
            ? "hyprctl --batch 'keyword decoration:blur:enabled false ; keyword animations:enabled false'"
            : "hyprctl --batch 'keyword decoration:blur:enabled true ; keyword animations:enabled true'"]
        setGame.running = true
        root.gameMode = on
    }
    function runTailscale(on) {
        setTailscale.command = ["bash", "-c", on ? "tailscale up" : "tailscale down"]
        setTailscale.running = true
        root.tailscaleUp = on
    }

    // ── Tile model ──────────────────────────────────────────────────────────────
    // Built as a binding so the optional Tailscale tile appears only when the CLI
    // is present. Order is stable; the Grid reflows automatically.
    readonly property var tiles: {
        var t = [
            { action: "wifi"     },
            { action: "bt"       },
            { action: "night"    },
            { action: "dnd"      },
            { action: "profile"  },
            { action: "caffeine" },
            { action: "airplane" },
            { action: "mic"      },
            { action: "game"     },
        ]
        if (root.tailscaleAvail) t.push({ action: "tailscale" })
        return t
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    Column {
        id: content
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 12

        Text {
            text: "Control Center"
            color: Theme.fg
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.font
        }

        // ── Toggle tiles ──────────────────────────────────────────────────────
        Grid {
            width: parent.width
            columns: 4
            spacing: 8

            Repeater {
                model: root.tiles

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool tileActive: {
                        switch (modelData.action) {
                            case "wifi":      return root.wifiEnabled
                            case "bt":        return root.btEnabled
                            case "dnd":       return root.dndEnabled
                            case "night":     return root.nightActive
                            case "profile":   return root.powerProfile !== "balanced"
                            case "caffeine":  return root.caffeine
                            case "airplane":  return root.airplane
                            case "mic":       return root.micMuted
                            case "game":      return root.gameMode
                            case "tailscale": return root.tailscaleUp
                            default:          return false
                        }
                    }
                    readonly property string tileIcon: {
                        switch (modelData.action) {
                            case "wifi":      return ""
                            case "bt":        return ""
                            case "night":     return ""
                            case "dnd":       return ""
                            case "profile":   return root.powerProfile === "performance" ? "󰓅"
                                                    : root.powerProfile === "power-saver" ? "󰾆" : "󰾅"
                            case "caffeine":  return ""
                            case "airplane":  return "󰀝"
                            case "mic":       return root.micMuted ? "" : ""
                            case "game":      return "󰊴"
                            case "tailscale": return "󰖟"
                            default:          return ""
                        }
                    }
                    readonly property string tileLabel: {
                        switch (modelData.action) {
                            case "wifi":      return root.wifiEnabled && root.wifiSsid !== "" ? root.wifiSsid : "Wi-Fi"
                            case "bt":        return "Bluetooth"
                            case "night":     return "Night Light"
                            case "dnd":       return "Do Not Disturb"
                            case "profile":   return root.powerProfile === "power-saver" ? "Power Saver"
                                                    : root.powerProfile === "performance" ? "Performance" : "Balanced"
                            case "caffeine":  return "Caffeine"
                            case "airplane":  return "Airplane"
                            case "mic":       return root.micMuted ? "Mic Off" : "Mic"
                            case "game":      return "Game Mode"
                            case "tailscale": return "Tailscale"
                            default:          return ""
                        }
                    }

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
                            text: parent.parent.tileIcon
                            color: parent.parent.tileActive ? Theme.accent : Theme.gray
                            font.pixelSize: 18
                            font.family: Theme.font
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.tileLabel
                            color: parent.parent.tileActive ? Theme.fg : Theme.gray
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
                                    root.runNight(!root.nightActive)
                                    break
                                case "dnd":
                                    root.dndToggled()
                                    break
                                case "profile":
                                    root.runCycleProfile()
                                    break
                                case "caffeine":
                                    root.runCaffeine(!root.caffeine)
                                    break
                                case "airplane":
                                    root.runAirplane(!root.airplane)
                                    break
                                case "mic":
                                    if (Pipewire.defaultAudioSource?.ready && Pipewire.defaultAudioSource?.audio)
                                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                                    break
                                case "game":
                                    root.runGameMode(!root.gameMode)
                                    break
                                case "tailscale":
                                    root.runTailscale(!root.tailscaleUp)
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
            label: "  Brightness"
            value: root.brightness
            onMoved: (v) => {
                root.brightness = v
                root.runSetBright(v)
            }
        }

        // ── Night-light temperature (only relevant while night light is on) ─────
        SliderRow {
            width: parent.width
            label: "  Warmth"
            from: 2500
            to: 6500
            unit: "K"
            value: root.nightTemp
            onMoved: (v) => {
                root.nightTemp = Math.round(v)
                if (root.nightActive) root.runNight(true)
            }
        }
    }
}
