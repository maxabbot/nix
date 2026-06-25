// DiskPanel.qml — Removable drives page (embedded in Settings.qml — no window chrome).
// Lists hot-pluggable block devices via `lsblk -J`; mount / unmount / eject via
// udisksctl (polkit grants the active local session access — no root needed).
// Internal disks are excluded so root can never be unmounted here.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    property var disks: []   // [{name, path, label, size, fstype, mounted, mountpoint}]
    property string busyPath: ""

    onVisibleChanged: {
        if (visible) { refresh(); refreshTimer.start() }
        else         refreshTimer.stop()
    }

    function refresh() { lsblkProc.running = true }
    Timer { id: refreshTimer; interval: 5000; repeat: true; onTriggered: root.refresh() }

    function truthy(v) { return v === true || v === 1 || v === "1" }
    function mk(p) {
        return {
            name: p.name, path: p.path,
            label: p.label || p.fstype || p.name,
            size: p.size || "", fstype: p.fstype || "",
            mounted: !!p.mountpoint, mountpoint: p.mountpoint || ""
        }
    }

    Process {
        id: lsblkProc
        command: ["bash", "-c",
            "lsblk -J -o NAME,PATH,TYPE,RM,HOTPLUG,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                try {
                    var data = JSON.parse(text)
                    var devs = data.blockdevices || []
                    for (var i = 0; i < devs.length; i++) {
                        var disk = devs[i]
                        // Only removable / hot-pluggable disks (USB sticks, SD, etc.).
                        if (!root.truthy(disk.hotplug) && !root.truthy(disk.rm)) continue
                        var kids = disk.children || []
                        if (kids.length === 0) {
                            if (disk.fstype) out.push(root.mk(disk))
                        } else {
                            for (var j = 0; j < kids.length; j++)
                                if (kids[j].fstype) out.push(root.mk(kids[j]))
                        }
                    }
                } catch (e) { /* transient/garbled lsblk output — keep last list */ return }
                root.disks = out
            }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────────────────
    Process { id: actProc; command: [] }
    Connections {
        target: actProc
        function onRunningChanged() {
            if (!actProc.running) { root.busyPath = ""; Qt.callLater(root.refresh) }
        }
    }

    function mountDev(path)   { run(["udisksctl", "mount",   "-b", path], path) }
    function unmountDev(path) { run(["udisksctl", "unmount", "-b", path], path) }
    function run(cmd, path) {
        root.busyPath = path
        actProc.command = cmd
        actProc.running = true
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Drives"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }
            Text {
                text: root.disks.length + " removable"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
        }

        Text {
            visible: root.disks.length === 0
            text: "No removable drives connected"
            color: Theme.grayDim
            font.pixelSize: 11
            font.family: Theme.font
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: root.width
                spacing: 4

                Repeater {
                    model: root.disks

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool busy: root.busyPath === modelData.path

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 8
                        color: modelData.mounted ? Theme.accentBg : Theme.bgAlt

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            spacing: 10

                            Text {
                                text: "󰋊"
                                color: modelData.mounted ? Theme.accent : Theme.gray
                                font.pixelSize: 18
                                font.family: Theme.font
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.label
                                    color: Theme.fg
                                    font.pixelSize: 12
                                    font.family: Theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: {
                                        var s = modelData.size
                                        if (modelData.fstype !== "") s += "  ·  " + modelData.fstype
                                        if (modelData.mounted) s += "  ·  " + modelData.mountpoint
                                        return s
                                    }
                                    color: Theme.grayDim
                                    font.pixelSize: 9
                                    font.family: Theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                visible: row.busy
                                text: "…"
                                color: Theme.yellow
                                font.pixelSize: 14
                                font.family: Theme.font
                            }

                            // Mount / unmount
                            Rectangle {
                                visible: !row.busy
                                implicitWidth: actLabel.implicitWidth + 18
                                height: 28
                                radius: 7
                                color: actArea.containsMouse
                                    ? (modelData.mounted ? Theme.redDark : Theme.accentBgHover)
                                    : (modelData.mounted ? Theme.bgHard : Theme.accentBg)
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    id: actLabel
                                    anchors.centerIn: parent
                                    text: modelData.mounted ? "Eject" : "Mount"
                                    color: modelData.mounted ? Theme.red : Theme.fg
                                    font.pixelSize: 11
                                    font.family: Theme.font
                                }
                                MouseArea {
                                    id: actArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.mounted
                                        ? root.unmountDev(modelData.path)
                                        : root.mountDev(modelData.path)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
