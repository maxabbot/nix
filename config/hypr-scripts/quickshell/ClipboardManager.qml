// ClipboardManager.qml — Persistent, searchable clipboard history panel (bottom-right).
// Requires cliphist + wl-clipboard (already in productivity.nix).
// Clipboard daemon must be running: wl-paste --watch cliphist store
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

PanelWindow {
    id: root

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    implicitWidth: 420
    implicitHeight: 560
    color: "transparent"

    property string clipScript: Qt.resolvedUrl("qs_clipboard.sh").toString().replace(/^file:\/\//, "")

    ListModel { id: allEntries }
    ListModel { id: filteredEntries }

    onVisibleChanged: {
        if (visible) {
            searchField.forceActiveFocus()
            allEntries.clear()
            filteredEntries.clear()
            loadHistory.running = true
        }
    }

    function filter(query) {
        filteredEntries.clear()
        var q = query.toLowerCase().trim()
        for (var i = 0; i < allEntries.count; i++) {
            var e = allEntries.get(i)
            if (!q || e.preview.toLowerCase().includes(q))
                filteredEntries.append(e)
        }
    }

    function removeById(eid) {
        for (var i = allEntries.count - 1; i >= 0; i--) {
            if (allEntries.get(i).entryId === eid) { allEntries.remove(i); break }
        }
        for (var j = filteredEntries.count - 1; j >= 0; j--) {
            if (filteredEntries.get(j).entryId === eid) { filteredEntries.remove(j); break }
        }
    }

    function detectLang(text) {
        var t = text.trim()
        if (/^(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|WITH|EXPLAIN)\s/i.test(t)) return "sql"
        if (/^(def |class |import |from |print\(|#!.*python)/.test(t))               return "python"
        if (/^(#!.*bash|#!.*sh)/.test(t) || /\$\{[A-Za-z_]/.test(t))               return "bash"
        if (/^\s*[{\[]/.test(t)) { try { JSON.parse(t); return "json" } catch(e) {} }
        if (/\b(const |let |var |function |=>|import |export )\b/.test(t))           return "js"
        return "text"
    }

    function highlight(text, lang) {
        var s = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        switch (lang) {
            case "sql":
                s = s.replace(/\b(SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|GROUP BY|ORDER BY|HAVING|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|DROP|ALTER|AS|WITH|LIMIT|OFFSET|UNION|AND|OR|NOT|NULL|DISTINCT)\b/gi,
                    '<font color="#7daea3"><b>$1</b></font>')
                s = s.replace(/('[^']*')/g, '<font color="#a9b665">$1</font>')
                s = s.replace(/\b(\d+\.?\d*)\b/g, '<font color="#d3869b">$1</font>')
                break
            case "python":
                s = s.replace(/\b(def|class|import|from|return|if|elif|else|for|while|in|not|and|or|None|True|False|lambda|with|as|try|except|finally|raise|pass|break|continue|yield|async|await)\b/g,
                    '<font color="#ea6962">$1</font>')
                s = s.replace(/(#[^\n]*)/g, '<font color="#928374">$1</font>')
                s = s.replace(/("([^"\\]|\\.)*"|'([^'\\]|\\.)*')/g, '<font color="#a9b665">$1</font>')
                s = s.replace(/\b(\d+\.?\d*)\b/g, '<font color="#d3869b">$1</font>')
                break
            case "bash":
                s = s.replace(/\b(if|then|else|elif|fi|for|do|done|while|case|esac|function|return|exit|echo|export|source|local|readonly|trap)\b/g,
                    '<font color="#ea6962">$1</font>')
                s = s.replace(/(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)/g, '<font color="#d3869b">$1</font>')
                s = s.replace(/(#[^\n]*)/g, '<font color="#928374">$1</font>')
                s = s.replace(/("([^"\\]|\\.)*"|'([^'\\]|\\.)*')/g, '<font color="#a9b665">$1</font>')
                break
            case "json":
                s = s.replace(/("([^"\\]|\\.)*"\s*:)/g, '<font color="#7daea3">$1</font>')
                s = s.replace(/:\s*("([^"\\]|\\.)*")/g, ': <font color="#a9b665">$1</font>')
                s = s.replace(/\b(true|false|null)\b/g, '<font color="#d3869b">$1</font>')
                break
            case "js":
                s = s.replace(/\b(const|let|var|function|return|if|else|for|while|class|import|export|new|null|undefined|true|false|async|await|typeof)\b/g,
                    '<font color="#ea6962">$1</font>')
                s = s.replace(/(\/\/[^\n]*)/g, '<font color="#928374">$1</font>')
                s = s.replace(/("([^"\\]|\\.)*"|'([^'\\]|\\.)*')/g, '<font color="#a9b665">$1</font>')
                break
        }
        return s
    }

    Process {
        id: loadHistory
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line.trim()) return
                var tab = line.indexOf("\t")
                if (tab < 0) return
                var eid = line.substring(0, tab)
                var preview = line.substring(tab + 1).substring(0, 300)
                var lang = root.detectLang(preview)
                allEntries.append({ entryId: eid, preview: preview, lang: lang })
            }
        }
        onExited: root.filter(searchField.text)
    }

    Process { id: clipboardAction; command: [] }

    Rectangle {
        anchors.fill: parent
        radius: 12; color: Theme.bg
        border.color: Theme.border; border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true; height: 28; spacing: 8

                Text {
                    text: "󰅇  Clipboard"
                    color: Theme.fg; font.pixelSize: 14; font.bold: true
                    font.family: Theme.font
                    Layout.fillWidth: true
                }

                Text {
                    text: filteredEntries.count + " items"
                    color: Theme.grayDim; font.pixelSize: 10
                    font.family: Theme.font
                }

                Rectangle {
                    width: 48; height: 24; radius: 6
                    color: wipeArea.containsMouse ? Theme.redDark : Theme.border
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: "Wipe"
                        color: Theme.red; font.pixelSize: 10
                        font.family: Theme.font
                    }
                    MouseArea {
                        id: wipeArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clipboardAction.command = ["bash", root.clipScript, "wipe"]
                            clipboardAction.running = true
                            allEntries.clear()
                            filteredEntries.clear()
                        }
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
                        placeholderText: "Search clipboard…"
                        background: null
                        color: Theme.fgBright; placeholderTextColor: Theme.grayDim
                        font.pixelSize: 13; font.family: Theme.font
                        onTextChanged: root.filter(text)
                        Keys.onEscapePressed: root.visible = false
                    }
                }
            }

            // Entry list
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: parent.width; spacing: 4

                    Item {
                        visible: filteredEntries.count === 0
                        width: parent.width; height: 80
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰅇"; color: Theme.borderStrong; font.pixelSize: 28
                                font.family: Theme.font
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Clipboard is empty"
                                color: Theme.grayDim; font.pixelSize: 13
                                font.family: Theme.font
                            }
                        }
                    }

                    Repeater {
                        model: filteredEntries

                        delegate: Rectangle {
                            id: entryRect
                            required property string entryId
                            required property string preview
                            required property string lang

                            width: parent.width
                            height: entryCol.implicitHeight + 16
                            radius: 6
                            color: entryArea.containsMouse ? Theme.bgSoft : Theme.bgAlt
                            border.color: lang !== "text" ? Theme.borderStrong : Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Column {
                                id: entryCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                spacing: 4

                                RowLayout {
                                    width: parent.width; spacing: 4

                                    Rectangle {
                                        visible: entryRect.lang !== "text"
                                        radius: 3; color: Theme.bgHard
                                        border.color: Theme.borderStrong; border.width: 1
                                        implicitWidth: langLabel.implicitWidth + 8
                                        implicitHeight: langLabel.implicitHeight + 4
                                        Text {
                                            id: langLabel
                                            anchors.centerIn: parent
                                            text: entryRect.lang.toUpperCase()
                                            color: Theme.accent; font.pixelSize: 9
                                            font.family: Theme.font
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        color: delArea.containsMouse ? Theme.borderStrong : "transparent"
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: ""; color: Theme.gray; font.pixelSize: 9
                                            font.family: Theme.font
                                        }
                                        MouseArea {
                                            id: delArea
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                clipboardAction.command = ["bash", root.clipScript, "delete", entryRect.entryId]
                                                clipboardAction.running = true
                                                root.removeById(entryRect.entryId)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: root.highlight(entryRect.preview, entryRect.lang)
                                    textFormat: Text.RichText
                                    color: Theme.fgDim; font.pixelSize: 11
                                    font.family: Theme.font
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 3
                                }
                            }

                            MouseArea {
                                id: entryArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Intercept clicks not consumed by child areas
                                onClicked: (mouse) => {
                                    clipboardAction.command = ["bash", root.clipScript, "copy", entryRect.entryId]
                                    clipboardAction.running = true
                                    root.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
