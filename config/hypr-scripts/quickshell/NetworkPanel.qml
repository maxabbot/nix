// NetworkPanel.qml — Wi-Fi panel (right edge; drops from Waybar when edge is
// "top", rises from the Quickshell bar when "bottom").
// Network list and connect/disconnect via nmcli (Process — no shell quoting).
// Known networks connect directly; new secured networks get an inline
// password prompt. qs_manager.sh triggers `nmcli dev wifi rescan` on open.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

PanelWindow {
    id: root

    property string edge: "bottom"

    anchors { top: root.edge === "top"; bottom: root.edge === "bottom"; right: true }
    margins {
        top: root.edge === "top" ? Theme.panelGapTop : 0
        bottom: root.edge === "bottom" ? Theme.panelGap : 0
        right: 4
    }
    implicitWidth: 380
    implicitHeight: content.implicitHeight + 32
    color: "transparent"

    // Keyboard only while the password prompt is up, so the panel doesn't
    // steal focus from tiled windows the rest of the time.
    WlrLayershell.keyboardFocus: (visible && promptSsid !== "")
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── State ───────────────────────────────────────────────────────────────────
    property bool wifiEnabled: false
    property var networks: []          // { inUse, ssid, signal, secured }
    property var knownConns: ({})      // saved connection names → true
    property string connectingSsid: ""
    property string promptSsid: ""     // SSID awaiting a password
    property string statusMsg: ""
    property bool statusError: false

    onVisibleChanged: {
        if (visible) refresh()
        else { promptSsid = ""; statusMsg = "" }
    }

    function refresh() {
        pollRadio.running = true
        pollKnown.running = true
        rescan()
    }
    function rescan() {
        scan.buf = []
        scan.running = true
    }

    // Scan results refresh while open (qs_manager kicks a hardware rescan on open)
    Timer {
        interval: 8000; repeat: true
        running: root.visible && root.wifiEnabled
        onTriggered: if (!scan.running) root.rescan()
    }

    // ── Polling ─────────────────────────────────────────────────────────────────
    Process {
        id: pollRadio
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: SplitParser {
            onRead: (line) => root.wifiEnabled = (line.trim() === "enabled")
        }
    }

    Process {
        id: pollKnown
        property var buf: []
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: SplitParser { onRead: (line) => pollKnown.buf.push(line.trim()) }
        onExited: {
            var k = {}
            for (var i = 0; i < buf.length; i++) if (buf[i]) k[buf[i]] = true
            root.knownConns = k
            buf = []
        }
    }

    Process {
        id: scan
        property var buf: []
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        stdout: SplitParser { onRead: (line) => scan.buf.push(line) }
        onExited: root.networks = root.parseNetworks(scan.buf)
    }

    // nmcli -t escapes ':' inside fields as '\:' — swap to a placeholder before
    // splitting. One row per SSID, keeping the strongest AP / the in-use flag.
    function parseNetworks(lines) {
        var seen = {}
        var nets = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var parts = line.replace(/\\:/g, "\x01").split(":")
            if (parts.length < 4) continue
            var inUse = parts[0] === "*"
            var security = parts[parts.length - 1].replace(/\x01/g, ":")
            var signal = parseInt(parts[parts.length - 2])
            if (isNaN(signal)) signal = 0
            var ssid = parts.slice(1, parts.length - 2).join(":").replace(/\x01/g, ":")
            if (!ssid) continue  // hidden networks
            if (seen[ssid] !== undefined) {
                var e = nets[seen[ssid]]
                e.inUse = e.inUse || inUse
                e.signal = Math.max(e.signal, signal)
                continue
            }
            seen[ssid] = nets.length
            nets.push({
                inUse: inUse, ssid: ssid, signal: signal,
                secured: security !== "" && security !== "--"
            })
        }
        nets.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
        return nets
    }

    // ── Actions ─────────────────────────────────────────────────────────────────
    Process {
        id: setRadio
        command: []
        onExited: { pollRadio.running = true; root.rescan() }
    }
    function toggleRadio() {
        wifiEnabled = !wifiEnabled  // optimistic
        setRadio.command = ["nmcli", "radio", "wifi", wifiEnabled ? "on" : "off"]
        setRadio.running = true
    }

    Process {
        id: connectProc
        property string ssid: ""
        property bool wasPwAttempt: false
        property var errBuf: []
        command: []
        stderr: SplitParser { onRead: (line) => connectProc.errBuf.push(line) }
        onExited: (code) => {
            root.connectingSsid = ""
            var err = errBuf.join(" ")
            errBuf = []
            if (code === 0) {
                root.statusMsg = ""
                root.promptSsid = ""
            } else if (wasPwAttempt) {
                // Bad password leaves a half-made profile behind — delete it so
                // the retry doesn't trip over it.
                cleanupProc.command = ["nmcli", "connection", "delete", "id", ssid]
                cleanupProc.running = true
                root.promptSsid = ssid
                root.setStatus("Wrong password — try again", true)
            } else if (/[Ss]ecrets|[Pp]assword/.test(err)) {
                root.promptSsid = ssid
                root.setStatus("Password required", false)
            } else {
                root.setStatus(err.replace(/^Error: */, "").slice(0, 90) || "Failed", true)
            }
            root.refresh()
        }
    }
    Process { id: cleanupProc; command: [] }

    function setStatus(msg, isErr) { statusMsg = msg; statusError = isErr }

    function runConnect(cmd, ssid, pwAttempt) {
        connectProc.ssid = ssid
        connectProc.wasPwAttempt = pwAttempt
        connectProc.errBuf = []
        connectProc.command = cmd
        connectingSsid = ssid
        setStatus("", false)
        connectProc.running = true
    }

    function connectTo(net) {
        if (connectingSsid !== "") return
        promptSsid = ""
        if (net.inUse)
            runConnect(["nmcli", "connection", "down", "id", net.ssid], net.ssid, false)
        else if (knownConns[net.ssid])
            runConnect(["nmcli", "-w", "15", "connection", "up", "id", net.ssid], net.ssid, false)
        else if (!net.secured)
            runConnect(["nmcli", "-w", "15", "device", "wifi", "connect", net.ssid], net.ssid, false)
        else {
            promptSsid = net.ssid  // secured + unknown → ask first
            setStatus("", false)
        }
    }

    function connectWithPw(ssid, pw) {
        if (pw === "") return
        runConnect(["nmcli", "-w", "20", "device", "wifi", "connect", ssid, "password", pw], ssid, true)
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

            // Header: title + rescan + radio toggle
            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    text: "Wi-Fi"
                    color: Theme.fg
                    font.pixelSize: 14
                    font.bold: true
                    font.family: Theme.font
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 26; height: 26; radius: 7
                    color: rescanArea.containsMouse ? Theme.borderStrong : Theme.bgAlt
                    visible: root.wifiEnabled
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: Theme.fgDim
                        font.pixelSize: 13
                        font.family: Theme.font
                    }
                    MouseArea {
                        id: rescanArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }

                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: root.wifiEnabled ? Theme.accentBg : Theme.bgAlt
                    border.color: root.wifiEnabled ? Theme.accent : Theme.borderStrong
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.wifiEnabled ? parent.width - width - 4 : 4
                        color: root.wifiEnabled ? Theme.accent : Theme.gray
                        Behavior on x { NumberAnimation { duration: 100 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleRadio()
                    }
                }
            }

            Text {
                visible: !root.wifiEnabled
                text: "Wi-Fi is off"
                color: Theme.gray
                font.pixelSize: 12
                font.family: Theme.font
            }

            // ── Network list ──────────────────────────────────────────────────────
            ListView {
                id: netList
                visible: root.wifiEnabled
                width: parent.width
                height: Math.min(contentHeight, 340)
                clip: true
                model: root.networks
                spacing: 2

                delegate: Column {
                    required property var modelData
                    width: netList.width

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: rowArea.containsMouse ? Theme.bgSoft
                             : modelData.inUse ? Theme.bgAlt : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                text: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(modelData.signal / 20))]
                                color: modelData.inUse ? Theme.accent : Theme.fgDim
                                font.pixelSize: 14
                                font.family: Theme.font
                            }
                            Text {
                                text: modelData.ssid
                                color: modelData.inUse ? Theme.fgBright : Theme.fg
                                font.pixelSize: 12
                                font.family: Theme.font
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: root.connectingSsid === modelData.ssid
                                text: "…"
                                color: Theme.yellow
                                font.pixelSize: 12
                                font.family: Theme.font
                            }
                            Text {
                                visible: modelData.secured
                                text: "󰌾"
                                color: Theme.gray
                                font.pixelSize: 12
                                font.family: Theme.font
                            }
                            Text {
                                visible: modelData.inUse
                                text: "󰄬"
                                color: Theme.green
                                font.pixelSize: 12
                                font.family: Theme.font
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.connectTo(modelData)
                        }
                    }

                    // Inline password prompt for this SSID
                    RowLayout {
                        visible: root.promptSsid === modelData.ssid
                        width: parent.width
                        spacing: 6

                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            echoMode: TextInput.Password
                            placeholderText: "Password"
                            placeholderTextColor: Theme.grayDim
                            color: Theme.fg
                            font.pixelSize: 12
                            font.family: Theme.font
                            background: Rectangle {
                                radius: 7
                                color: Theme.bgAlt
                                border.color: pwField.activeFocus ? Theme.accent : Theme.borderStrong
                                border.width: 1
                            }
                            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                            onAccepted: root.connectWithPw(modelData.ssid, text)
                            Keys.onEscapePressed: root.promptSsid = ""
                        }

                        Rectangle {
                            width: 60; height: 30; radius: 7
                            color: pwGoArea.containsMouse ? Theme.accentBgHover : Theme.accentBg
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent
                                text: "Join"
                                color: Theme.accent
                                font.pixelSize: 12
                                font.family: Theme.font
                            }
                            MouseArea {
                                id: pwGoArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectWithPw(modelData.ssid, pwField.text)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.statusMsg !== ""
                width: parent.width
                text: root.statusMsg
                color: root.statusError ? Theme.red : Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
                wrapMode: Text.Wrap
            }
        }
    }
}
