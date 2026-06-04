// KeybindCheatSheet.qml — Searchable Hyprland keybind overlay (bottom-right).
// Reads live bindings from `hyprctl binds -j` on first open; cached in-memory.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

PanelWindow {
    id: root

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    implicitWidth: 480
    implicitHeight: 560
    color: "transparent"

    ListModel { id: allBinds }
    ListModel { id: filteredBinds }
    property bool loaded: false

    function modStr(mod) {
        var parts = []
        if (mod & 64) parts.push("Super")
        if (mod & 4)  parts.push("Ctrl")
        if (mod & 1)  parts.push("Shift")
        if (mod & 8)  parts.push("Alt")
        return parts.join("+")
    }

    function filter(query) {
        filteredBinds.clear()
        var q = query.toLowerCase().trim()
        for (var i = 0; i < allBinds.count; i++) {
            var b = allBinds.get(i)
            var combo = ((b.mod ? b.mod + "+" : "") + b.key).toLowerCase()
            if (!q || combo.includes(q) || b.action.toLowerCase().includes(q)
                    || b.arg.toLowerCase().includes(q) || b.desc.toLowerCase().includes(q))
                filteredBinds.append(b)
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchField.forceActiveFocus()
            if (!root.loaded) { fetchBinds.buf = ""; fetchBinds.running = true }
            else filter(searchField.text)
        }
    }

    Process {
        id: fetchBinds
        command: ["hyprctl", "binds", "-j"]
        property string buf: ""
        stdout: SplitParser { onRead: (line) => fetchBinds.buf += line + "\n" }
        onExited: {
            try {
                var binds = JSON.parse(fetchBinds.buf)
                allBinds.clear()
                for (var i = 0; i < binds.length; i++) {
                    var b = binds[i]
                    if (!b.key && !b.catchAll) continue
                    allBinds.append({
                        mod:    root.modStr(b.mod),
                        key:    b.key || "catch-all",
                        action: b.handler || "",
                        arg:    b.arg || "",
                        desc:   b.description || ""
                    })
                }
            } catch(e) {}
            root.loaded = true
            root.filter(searchField.text)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12; color: "#282828"
        border.color: "#3c3836"; border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true; height: 28; spacing: 8

                Text {
                    text: "󰌌  Keybinds"
                    color: "#d4be98"; font.pixelSize: 14; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                }

                Text {
                    text: filteredBinds.count + " / " + allBinds.count
                    color: "#665c54"; font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                }

                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: refreshArea.containsMouse ? "#3c3836" : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: ""; color: "#928374"; font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.loaded = false; fetchBinds.buf = ""; fetchBinds.running = true }
                    }
                }
            }

            // Search
            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8
                color: "#32302f"
                border.color: searchField.activeFocus ? "#7daea3" : "#504945"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 8
                    Text { text: ""; color: "#928374"; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search keybinds…"
                        background: null
                        color: "#ebdbb2"; placeholderTextColor: "#665c54"
                        font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                        onTextChanged: root.filter(text)
                        Keys.onEscapePressed: root.visible = false
                    }
                }
            }

            // List
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: parent.width; spacing: 4

                    Item {
                        visible: filteredBinds.count === 0
                        width: parent.width; height: 80
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loaded ? "󰌌" : ""
                                color: "#504945"; font.pixelSize: 28
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loaded ? "No binds match" : "Loading…"
                                color: "#665c54"; font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }
                    }

                    Repeater {
                        model: filteredBinds
                        delegate: Rectangle {
                            width: parent.width
                            height: bindRow.implicitHeight + 14
                            radius: 6; color: "#32302f"
                            border.color: "#3c3836"; border.width: 1

                            RowLayout {
                                id: bindRow
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter; margins: 8
                                }
                                spacing: 8

                                Rectangle {
                                    radius: 4; color: "#1d2021"
                                    border.color: "#504945"; border.width: 1
                                    implicitWidth: kbdText.implicitWidth + 12
                                    implicitHeight: kbdText.implicitHeight + 6
                                    Text {
                                        id: kbdText
                                        anchors.centerIn: parent
                                        text: (model.mod ? model.mod + "+" : "") + model.key.toUpperCase()
                                        color: "#7daea3"; font.pixelSize: 10
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: model.desc !== "" ? model.desc
                                            : (model.action + (model.arg !== "" ? "  " + model.arg : ""))
                                        color: "#d4be98"; font.pixelSize: 11
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight; width: parent.width
                                    }
                                    Text {
                                        visible: model.desc !== "" && (model.arg !== "" || model.action !== "")
                                        text: model.action + (model.arg !== "" ? "  " + model.arg : "")
                                        color: "#665c54"; font.pixelSize: 10
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight; width: parent.width
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
