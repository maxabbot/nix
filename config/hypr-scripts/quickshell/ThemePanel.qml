// ThemePanel.qml — Theme page (embedded in Settings.qml — no window chrome).
// Drives the optional palette override that Theme.qml reads
// (~/.cache/quickshell/palette.json): pick an accent, or generate a full palette
// from the current wallpaper with matugen. "Reset" removes the override and the
// shell falls back to the fixed Gruvbox Material palette. After any write we call
// Theme.reloadPalette() so the change applies live.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string mode:   "dark"   // matugen generation mode
    property string status: ""

    // ── Actions ─────────────────────────────────────────────────────────────────
    Process {
        id: genProc
        command: []
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim()
                if (s === "OK") root.status = "Palette updated"
                else if (s === "ERRNOWP") root.status = "No wallpaper detected"
                else if (s === "ERRNOMATUGEN") root.status = "matugen not installed"
                else if (s.indexOf("ERR") === 0) root.status = "Generation failed"
            }
        }
    }
    Process { id: accentProc; command: [] }
    Process { id: resetProc;
        command: ["bash", "-c", "rm -f \"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/palette.json\""] }

    function generate() {
        root.status = "Generating from wallpaper…"
        genProc.command = ["bash", "-c",
            "wp=$(awww query 2>/dev/null | grep -oiE '[^ ]*\\.(png|jpg|jpeg)' | head -n1); " +
            "[ -z \"$wp\" ] && { echo ERRNOWP; exit 0; }; " +
            "command -v matugen >/dev/null || { echo ERRNOMATUGEN; exit 0; }; " +
            "d=\"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell\"; mkdir -p \"$d\"; " +
            "matugen image \"$wp\" --json hex -m \"$1\" 2>/dev/null | jq -c --arg m \"$1\" '" +
            "  (.colors[$m] // .colors) as $c | {" +
            "    bg: $c.surface," +
            "    bgAlt: ($c.surface_container // $c.surface_container_high // $c.surface)," +
            "    fg: $c.on_surface," +
            "    accent: $c.primary," +
            "    accentBg: ($c.primary_container // $c.primary)," +
            "    border: ($c.outline_variant // $c.outline)" +
            "  }' > \"$d/palette.json\" && echo OK || echo ERRGEN",
            "bash", root.mode]
        genProc.running = true
    }

    Connections {
        target: genProc
        function onRunningChanged() { if (!genProc.running) Theme.reloadPalette() }
    }

    function setAccent(accent, accentBg) {
        root.status = ""
        accentProc.command = ["bash", "-c",
            "d=\"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell\"; mkdir -p \"$d\"; " +
            "printf '{\"accent\":\"%s\",\"accentBg\":\"%s\"}' \"$1\" \"$2\" > \"$d/palette.json\"",
            "bash", accent, accentBg]
        accentProc.running = true
    }
    Connections {
        target: accentProc
        function onRunningChanged() { if (!accentProc.running) Theme.reloadPalette() }
    }
    Connections {
        target: resetProc
        function onRunningChanged() { if (!resetProc.running) { root.status = ""; Theme.reloadPalette() } }
    }

    readonly property var accents: [
        { name: "Aqua",   accent: "#7daea3", accentBg: "#2d4a52" },
        { name: "Blue",   accent: "#6f8faf", accentBg: "#2b3a4a" },
        { name: "Green",  accent: "#a9b665", accentBg: "#3a4226" },
        { name: "Yellow", accent: "#d8a657", accentBg: "#4a3c1f" },
        { name: "Orange", accent: "#e78a4e", accentBg: "#4a3120" },
        { name: "Red",    accent: "#ea6962", accentBg: "#4c2b2b" },
        { name: "Purple", accent: "#d3869b", accentBg: "#4a2d38" },
    ]

    // ── UI ──────────────────────────────────────────────────────────────────────
    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14

        Text {
            text: "Theme"
            color: Theme.fg
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.font
        }

        // ── Generation mode ───────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 6

            Text {
                text: "Mode"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
            Row {
                spacing: 6
                Repeater {
                    model: ["dark", "light"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 80; height: 28; radius: 7
                        color: root.mode === modelData ? Theme.accentBg
                             : (mArea.containsMouse ? Theme.border : Theme.bgAlt)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData === "dark" ? " Dark" : " Light"
                            color: root.mode === modelData ? Theme.accent : Theme.gray
                            font.pixelSize: 11
                            font.family: Theme.font
                        }
                        MouseArea {
                            id: mArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mode = modelData
                        }
                    }
                }
            }
        }

        // ── Accent ─────────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 6

            Text {
                text: "Accent"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.accents
                    delegate: Rectangle {
                        required property var modelData
                        width: 30; height: 30; radius: 15
                        color: modelData.accent
                        border.width: Qt.colorEqual(Theme.accent, modelData.accent) ? 3 : 0
                        border.color: Theme.fgBright

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setAccent(modelData.accent, modelData.accentBg)
                        }
                    }
                }
            }
        }

        // ── Matugen / reset ─────────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: 180; height: 34; radius: 8
                color: genArea.containsMouse ? Theme.accentBgHover : Theme.accentBg
                Behavior on color { ColorAnimation { duration: 80 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "󰸉"; color: Theme.accent; font.pixelSize: 14; font.family: Theme.font }
                    Text { text: "Generate from wallpaper"; color: Theme.fg; font.pixelSize: 11; font.family: Theme.font }
                }
                MouseArea {
                    id: genArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.generate()
                }
            }

            Rectangle {
                width: 80; height: 34; radius: 8
                color: resetArea.containsMouse ? Theme.border : Theme.bgAlt
                Behavior on color { ColorAnimation { duration: 80 } }
                Text {
                    anchors.centerIn: parent
                    text: "Reset"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.status = ""; resetProc.running = true }
                }
            }
        }

        Text {
            visible: root.status !== ""
            text: root.status
            color: Theme.yellow
            font.pixelSize: 11
            font.family: Theme.font
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Generate runs matugen on the current wallpaper and rewrites the shell palette. "
                + "Accent swatches override just the accent. Reset restores Gruvbox Material."
            color: Theme.grayDim
            font.pixelSize: 10
            font.family: Theme.font
        }
    }
}
