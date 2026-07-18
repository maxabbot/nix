// NetworkPanel.qml — Wi-Fi page (embedded in Settings.qml — no window chrome).
// Radio toggle + scanned network list via nmcli. Strongest AP per SSID, active
// first. Known networks connect directly; new secured ones get an inline password
// prompt. A failed connect deletes the half-made profile so retries stay clean.
// qs_manager.sh kicks a hardware rescan on open; the list refreshes every 8s while
// visible.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    property bool   wifiEnabled:    false
    property var    networks:       []   // [{ssid, signal, security, active}]
    property var    savedSsids:     []
    property string promptSsid:     ""   // SSID awaiting an inline password
    property string statusMsg:      ""
    property string connectingSsid: ""
    property var    vpns:           []   // [{name, type, active}] — VPN/WireGuard

    property var _scanAccum: []

    // ── Polling ─────────────────────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) { refresh(); refreshTimer.start() }
        else         { refreshTimer.stop(); promptSsid = ""; statusMsg = "" }
    }

    function refresh() {
        pollRadio.running = true
        pollSaved.running = true
        pollVpn.running = true
        root._scanAccum = []
        scanList.running = true
    }

    Timer {
        id: refreshTimer
        interval: 8000
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: pollRadio
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "") root.wifiEnabled = (line.trim() === "enabled") }
        }
    }

    Process {
        id: pollSaved
        command: ["bash", "-c", "nmcli -t -f NAME connection show 2>/dev/null"]
        property var accum: []
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "") pollSaved.accum.push(line.trim()) }
        }
        onRunningChanged: { if (running) accum = []; else { root.savedSsids = accum; accum = [] } }
    }

    // VPN / WireGuard connections. ACTIVE and TYPE never contain ':'; the NAME
    // may, so parse from the right and rejoin the remainder as the name.
    Process {
        id: pollVpn
        command: ["bash", "-c", "nmcli -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null"]
        property var accum: []
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var p = line.split(":")
                if (p.length < 3) return
                var active = p[p.length - 1] === "yes"
                var type   = p[p.length - 2]
                if (type !== "vpn" && type !== "wireguard") return
                var name   = p.slice(0, p.length - 2).join(":").replace(/\\:/g, ":")
                pollVpn.accum.push({ name: name, type: type, active: active })
            }
        }
        onRunningChanged: {
            if (running) accum = []
            else {
                accum.sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name))
                root.vpns = accum; accum = []
            }
        }
    }

    // SSID kept last so SSIDs containing ':' survive — split off the first three
    // fields, the remainder (rejoined) is the SSID.
    Process {
        id: scanList
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var parts = line.split(":")
                if (parts.length < 4) return
                var inUse  = parts[0]
                var signal = parseInt(parts[1]) || 0
                var sec    = parts[2]
                var ssid   = parts.slice(3).join(":").replace(/\\:/g, ":")
                if (ssid === "") return   // hidden network
                root._scanAccum.push({ ssid: ssid, signal: signal, security: sec, active: inUse === "*" })
            }
        }
        onRunningChanged: if (!running) root.rebuildNetworks()
    }

    function rebuildNetworks() {
        // Strongest AP per SSID, then active-first, then by signal desc.
        var byS = ({})
        for (var i = 0; i < root._scanAccum.length; i++) {
            var n = root._scanAccum[i]
            if (!byS[n.ssid] || n.signal > byS[n.ssid].signal || n.active) {
                if (!byS[n.ssid] || n.signal > byS[n.ssid].signal)
                    byS[n.ssid] = n
                if (n.active) byS[n.ssid].active = true
            }
        }
        var list = Object.keys(byS).map(k => byS[k])
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
        root.networks = list
    }

    // ── Actions ─────────────────────────────────────────────────────────────────
    Process { id: setRadio;  command: [] }
    Process { id: connectP;  command: [] }
    Process { id: disconP;   command: [] }
    Process { id: vpnAct;    command: [] }

    function toggleVpn(name, active) {
        vpnAct.command = ["nmcli", "connection", active ? "down" : "up", name]
        vpnAct.running = true
        Qt.callLater(root.refresh)
    }

    function runSetRadio(on) {
        setRadio.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        setRadio.running = true
        root.wifiEnabled = on
        if (on) Qt.callLater(root.refresh)
    }

    function isSaved(ssid)   { return root.savedSsids.indexOf(ssid) >= 0 }
    function isSecured(sec)  { return sec !== "" && sec !== "--" }

    function connect(ssid, security) {
        if (isSecured(security) && !isSaved(ssid)) { root.promptSsid = ssid; return }
        doConnect(ssid, "")
    }

    function doConnect(ssid, password) {
        root.connectingSsid = ssid
        root.statusMsg = "Connecting to " + ssid + "…"
        root.promptSsid = ""
        // SSID/password passed as positional args ($1/$2) — injection-safe. On
        // failure, drop the freshly-created (broken) profile so retries stay clean.
        var script = password !== ""
            ? "nmcli device wifi connect \"$1\" password \"$2\" || nmcli connection delete \"$1\" 2>/dev/null"
            : "nmcli device wifi connect \"$1\" || nmcli connection delete \"$1\" 2>/dev/null"
        connectP.command = ["bash", "-c", script, "bash", ssid, password]
        connectP.running = true
    }

    Connections {
        target: connectP
        function onRunningChanged() {
            if (!connectP.running) { root.connectingSsid = ""; root.statusMsg = ""; root.refresh() }
        }
    }

    function disconnect(ssid) {
        disconP.command = ["nmcli", "connection", "down", ssid]
        disconP.running = true
        Qt.callLater(root.refresh)
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header + radio toggle
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Wi-Fi"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }

            Rectangle {
                width: 44; height: 24; radius: 12
                color: root.wifiEnabled ? Theme.accentBg : Theme.bgAlt
                Behavior on color { ColorAnimation { duration: 100 } }

                Rectangle {
                    width: 18; height: 18; radius: 9
                    x: root.wifiEnabled ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.wifiEnabled ? Theme.accent : Theme.gray
                    Behavior on x { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runSetRadio(!root.wifiEnabled)
                }
            }
        }

        Text {
            visible: root.statusMsg !== ""
            text: root.statusMsg
            color: Theme.yellow
            font.pixelSize: 11
            font.family: Theme.font
            Layout.fillWidth: true
        }

        // Network list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: root.width
                spacing: 4

                Text {
                    visible: root.wifiEnabled && root.networks.length === 0
                    text: "Scanning…"
                    color: Theme.grayDim
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                Text {
                    visible: !root.wifiEnabled
                    text: "Wi-Fi is off"
                    color: Theme.grayDim
                    font.pixelSize: 11
                    font.family: Theme.font
                }

                Repeater {
                    model: root.wifiEnabled ? root.networks : []

                    delegate: Column {
                        required property var modelData
                        Layout.fillWidth: true
                        width: parent.width
                        spacing: 4

                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: 8
                            color: modelData.active ? Theme.accentBg
                                 : (rowArea.containsMouse ? Theme.bgSoft : Theme.bgAlt)
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8

                                Text {
                                    // signal bars
                                    text: modelData.signal >= 70 ? "󰤨"
                                        : modelData.signal >= 45 ? "󰤥"
                                        : modelData.signal >= 20 ? "󰤢" : "󰤟"
                                    color: modelData.active ? Theme.accent : Theme.gray
                                    font.pixelSize: 14
                                    font.family: Theme.font
                                }
                                Text {
                                    text: modelData.ssid
                                    color: modelData.active ? Theme.fg : Theme.fgDim
                                    font.pixelSize: 12
                                    font.family: Theme.font
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: root.isSecured(modelData.security)
                                    text: ""
                                    color: Theme.grayDim
                                    font.pixelSize: 10
                                    font.family: Theme.font
                                }
                                Text {
                                    visible: modelData.active
                                    text: "Connected"
                                    color: Theme.accent
                                    font.pixelSize: 9
                                    font.family: Theme.font
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.active) root.disconnect(modelData.ssid)
                                    else root.connect(modelData.ssid, modelData.security)
                                }
                            }
                        }

                        // Inline password prompt for this network
                        RowLayout {
                            visible: root.promptSsid === modelData.ssid
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 7
                                color: Theme.bgHard
                                border.color: Theme.borderStrong
                                border.width: 1

                                TextField {
                                    id: pwField
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    placeholderText: "Password"
                                    echoMode: TextInput.Password
                                    color: Theme.fg
                                    font.pixelSize: 12
                                    font.family: Theme.font
                                    background: null
                                    onVisibleChanged: if (visible) forceActiveFocus()
                                    onAccepted: root.doConnect(modelData.ssid, text)
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 64
                                height: 32
                                radius: 7
                                color: connBtn.containsMouse ? Theme.accentBgHover : Theme.accentBg
                                Text {
                                    anchors.centerIn: parent
                                    text: "Connect"
                                    color: Theme.fg
                                    font.pixelSize: 11
                                    font.family: Theme.font
                                }
                                MouseArea {
                                    id: connBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.doConnect(modelData.ssid, pwField.text)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── VPN / WireGuard ───────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.vpns.length > 0

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            Text {
                text: "VPN"
                color: Theme.gray
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.font
            }

            Repeater {
                model: root.vpns

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                    color: modelData.active ? Theme.accentBg : Theme.bgAlt

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8

                        Text {
                            text: modelData.type === "wireguard" ? "󰖂" : "󰦝"
                            color: modelData.active ? Theme.accent : Theme.gray
                            font.pixelSize: 14
                            font.family: Theme.font
                        }
                        Text {
                            text: modelData.name
                            color: modelData.active ? Theme.fg : Theme.fgDim
                            font.pixelSize: 12
                            font.family: Theme.font
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: modelData.active
                            text: "On"
                            color: Theme.accent
                            font.pixelSize: 9
                            font.family: Theme.font
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleVpn(modelData.name, modelData.active)
                    }
                }
            }
        }
    }
}
