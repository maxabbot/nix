// AppLauncher.qml — Searchable application launcher panel (full-width, bottom).
// Desktop files are enumerated by list-apps.sh on first open; results are cached in-memory.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

PanelWindow {
    id: root

    anchors { bottom: true; left: true; right: true }
    margins.bottom: 44
    implicitHeight: 420
    color: "transparent"

    // ── App model ──────────────────────────────────────────────────────────────
    ListModel { id: allApps }
    ListModel { id: filteredApps }

    property bool loaded: false

    function filterApps(query) {
        filteredApps.clear()
        var q = query.toLowerCase().trim()
        for (var i = 0; i < allApps.count; i++) {
            var app = allApps.get(i)
            if (!q || app.name.toLowerCase().includes(q)) {
                filteredApps.append(app)
                if (filteredApps.count >= 48) break  // cap visible results
            }
        }
    }

    function launch(exec) {
        Hyprland.dispatch("exec " + exec)
        searchField.text = ""
        root.visible = false
    }

    onVisibleChanged: {
        if (visible) {
            searchField.forceActiveFocus()
            filterApps(searchField.text)
            if (!root.loaded) appFinder.running = true
        }
    }

    // ── App enumeration ────────────────────────────────────────────────────────
    Process {
        id: appFinder
        command: ["bash", Qt.resolvedUrl("list-apps.sh").toString().replace(/^file:\/\//, "")]
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.split("\t")
                if (parts.length >= 2 && parts[0].trim()) {
                    allApps.append({ name: parts[0].trim(), exec: parts[1].trim() })
                }
            }
        }
        onExited: {
            root.loaded = true
            root.filterApps(searchField.text)
        }
    }

    // ── UI ─────────────────────────────────────────────────────────────────────
    // Centred container (not full-width content)
    Item {
        anchors.fill: parent

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.min(parent.width - 32, 760)
            radius: 12
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            Column {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                spacing: 12

                // Search field
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 8
                    color: Theme.bgAlt
                    border.color: searchField.activeFocus ? Theme.accent : Theme.borderStrong
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 8

                        Text {
                            text: ""
                            color: Theme.gray
                            font.pixelSize: 14
                            font.family: Theme.font
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Search applications…"
                            background: null
                            color: Theme.fgBright
                            placeholderTextColor: Theme.grayDim
                            font.pixelSize: 14
                            font.family: Theme.font
                            onTextChanged: root.filterApps(text)
                            Keys.onEscapePressed: root.visible = false
                            Keys.onReturnPressed: {
                                if (filteredApps.count > 0)
                                    root.launch(filteredApps.get(0).exec)
                            }
                        }
                    }
                }

                // App grid
                ScrollView {
                    width: parent.width
                    height: parent.parent.height - 84
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    GridView {
                        width: parent.width
                        model: filteredApps
                        cellWidth: Math.floor(width / 6)
                        cellHeight: 80
                        clip: true

                        delegate: Item {
                            width: GridView.view.cellWidth
                            height: 80

                            Rectangle {
                                anchors { fill: parent; margins: 4 }
                                radius: 8
                                color: appArea.containsMouse ? Theme.border : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    width: parent.width - 8

                                    // App initial icon (placeholder until icon loading is added)
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 32; height: 32; radius: 8
                                        color: Theme.bgAlt
                                        Text {
                                            anchors.centerIn: parent
                                            text: model.name.charAt(0).toUpperCase()
                                            color: Theme.accent
                                            font.pixelSize: 16
                                            font.bold: true
                                            font.family: Theme.font
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: model.name
                                        color: Theme.fg
                                        font.pixelSize: 10
                                        font.family: Theme.font
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: appArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launch(model.exec)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
