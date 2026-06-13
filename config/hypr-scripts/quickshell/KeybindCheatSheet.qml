// KeybindCheatSheet.qml — Searchable Hyprland keybind overlay (top-right,
// drops from Waybar). Esc closes; click-off handled by Shell.qml's focus grab.
// Reads live bindings from `hyprctl binds -j` on first open; cached in-memory.
// Descriptions must follow "Section | Name" format (set in hyprland.lua).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

PanelWindow {
    id: root

    signal closeRequested()

    screen: Theme.focusedScreen()

    anchors { top: true; right: true }
    margins { top: Theme.panelGapTop; right: 12 }
    implicitWidth: 480
    implicitHeight: 560
    color: "transparent"

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    ListModel { id: allBinds }
    ListModel { id: filteredBinds }
    property bool loaded: false

    function modStr(mask) {
        var parts = []
        if (mask & 64) parts.push("Super")
        if (mask & 4)  parts.push("Ctrl")
        if (mask & 1)  parts.push("Shift")
        if (mask & 8)  parts.push("Alt")
        return parts.join("+")
    }

    function parseDesc(desc) {
        var sep = desc.indexOf(" | ")
        if (sep >= 0) return { section: desc.slice(0, sep), name: desc.slice(sep + 3) }
        return { section: "", name: desc }
    }

    function filter(query) {
        filteredBinds.clear()
        var q = query.toLowerCase().trim()
        var lastSection = null
        for (var i = 0; i < allBinds.count; i++) {
            var b = allBinds.get(i)
            var combo = ((b.mod ? b.mod + "+" : "") + b.key).toLowerCase()
            if (!q || combo.includes(q) || b.name.toLowerCase().includes(q)
                    || b.section.toLowerCase().includes(q)) {
                if (b.section !== lastSection) {
                    filteredBinds.append({ isHeader: true, section: b.section,
                        mod: "", key: "", action: "", arg: "", name: "" })
                    lastSection = b.section
                }
                filteredBinds.append({ isHeader: false, section: b.section,
                    mod: b.mod, key: b.key, action: b.action, arg: b.arg, name: b.name })
            }
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
                    if (!b.key && !b.catch_all) continue
                    if (b.mouse) continue
                    var parsed = root.parseDesc(b.description || "")
                    allBinds.append({
                        mod:     root.modStr(b.modmask),
                        key:     b.key || "catch-all",
                        action:  b.dispatcher || "",
                        arg:     b.arg || "",
                        name:    parsed.name || (b.dispatcher !== "__lua" ? (b.dispatcher + (b.arg ? "  " + b.arg : "")) : ""),
                        section: parsed.section
                    })
                }
            } catch(e) {}
            root.loaded = true
            root.filter(searchField.text)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12; color: Theme.bg
        border.color: Theme.border; border.width: 1

        // Fallback when the search field doesn't have focus (its own Esc
        // handler bubbles here otherwise)
        focus: true
        Keys.onEscapePressed: root.closeRequested()

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true; height: 28; spacing: 8

                Text {
                    text: "󰌌  Keybinds"
                    color: Theme.fg; font.pixelSize: 14; font.bold: true
                    font.family: Theme.font
                    Layout.fillWidth: true
                }

                Text {
                    text: filteredBinds.count + " / " + allBinds.count
                    color: Theme.grayDim; font.pixelSize: 10
                    font.family: Theme.font
                }

                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: refreshArea.containsMouse ? Theme.border : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: ""; color: Theme.gray; font.pixelSize: 12
                        font.family: Theme.font
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
                color: Theme.bgAlt
                border.color: searchField.activeFocus ? Theme.accent : Theme.borderStrong
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 8
                    Text { text: ""; color: Theme.gray; font.pixelSize: 13; font.family: Theme.font }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search keybinds…"
                        background: null
                        color: Theme.fgBright; placeholderTextColor: Theme.grayDim
                        font.pixelSize: 13; font.family: Theme.font
                        onTextChanged: root.filter(text)
                        Keys.onEscapePressed: root.closeRequested()
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
                    width: parent.width; spacing: 2

                    Item {
                        visible: filteredBinds.count === 0
                        width: parent.width; height: 80
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loaded ? "󰌌" : ""
                                color: Theme.borderStrong; font.pixelSize: 28
                                font.family: Theme.font
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loaded ? "No binds match" : "Loading…"
                                color: Theme.grayDim; font.pixelSize: 13
                                font.family: Theme.font
                            }
                        }
                    }

                    Repeater {
                        model: filteredBinds

                        delegate: Item {
                            width: parent.width
                            height: model.isHeader ? sectionLabel.implicitHeight + 14 : bindRow.implicitHeight + 12

                            // Section header
                            Text {
                                id: sectionLabel
                                visible: model.isHeader
                                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                text: model.isHeader ? model.section.toUpperCase() : ""
                                color: Theme.gray; font.pixelSize: 9; font.bold: true
                                font.family: Theme.font
                                font.letterSpacing: 1.2
                            }
                            Rectangle {
                                visible: model.isHeader
                                anchors { left: sectionLabel.right; leftMargin: 6; right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                height: 1; color: Theme.border
                            }

                            // Bind row
                            Rectangle {
                                visible: !model.isHeader
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: bindRow.implicitHeight + 12
                                radius: 6; color: Theme.bgAlt
                                border.color: Theme.border; border.width: 1

                                RowLayout {
                                    id: bindRow
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter; margins: 8
                                    }
                                    spacing: 8

                                    Rectangle {
                                        radius: 4; color: Theme.bgHard
                                        border.color: Theme.borderStrong; border.width: 1
                                        implicitWidth: kbdText.implicitWidth + 12
                                        implicitHeight: kbdText.implicitHeight + 6
                                        Text {
                                            id: kbdText
                                            anchors.centerIn: parent
                                            text: (model.mod ? model.mod + "+" : "") + model.key.toUpperCase()
                                            color: Theme.accent; font.pixelSize: 10
                                            font.family: Theme.font
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.name
                                        color: Theme.fg; font.pixelSize: 11
                                        font.family: Theme.font
                                        elide: Text.ElideRight
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
