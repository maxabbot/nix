// WallpaperPicker.qml — Wallpaper browser using thumbnails from qs_manager.sh cache.
//
// Thumbnails are pre-generated into ~/.cache/quickshell/wallpaper_picker/thumbs/ by
// qs_manager.sh (which also starts this panel). On open, this panel lists the thumbs
// directory and displays them in a grid. Clicking a thumbnail applies the wallpaper.
//
// Video thumbnails are named 000_<original> — clicking them sets the mpvpaper source.
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
    height: 460
    color: "transparent"

    // ── State ──────────────────────────────────────────────────────────────────
    ListModel { id: thumbModel }
    property string thumbDir: ""
    property string srcDir: ""
    property string currentWallpaper: ""

    onVisibleChanged: {
        if (visible) {
            thumbModel.clear()
            getDirs.running = true
        }
    }

    // ── Get directories from environment / defaults ─────────────────────────────
    Process {
        id: getDirs
        command: ["bash", "-c",
            "echo \"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallpaper_picker/thumbs\";" +
            "echo \"${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}\";" +
            "awww query 2>/dev/null | grep -o '[^ ]*\\.(png\\|jpg\\|jpeg\\|gif\\|mp4\\|mkv\\|mov\\|webm)' | head -n1 || true"
        ]
        stdout: SplitParser {
            property int lineNo: 0
            onRead: (line) => {
                switch (lineNo++) {
                    case 0: root.thumbDir = line.trim(); break
                    case 1: root.srcDir   = line.trim(); break
                    case 2: root.currentWallpaper = line.trim().split("/").pop(); break
                }
            }
        }
        onExited: listThumbs.running = true
    }

    // ── List thumbnail files ────────────────────────────────────────────────────
    Process {
        id: listThumbs
        command: ["bash", "-c",
            "find \"" + root.thumbDir + "\" -maxdepth 1 -type f " +
            "! -name '.manifest' ! -name '.source_dir' 2>/dev/null | sort"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                var thumb = line.trim()
                if (!thumb) return
                var base = thumb.split("/").pop()
                var isVideo = base.startsWith("000_")
                var srcName = isVideo ? base.slice(4) : base
                thumbModel.append({
                    thumbPath: thumb,
                    srcName:   srcName,
                    isVideo:   isVideo,
                    isCurrent: srcName === root.currentWallpaper
                })
            }
        }
    }

    // ── Apply wallpaper ─────────────────────────────────────────────────────────
    Process { id: applyProc; command: [] }

    function applyWallpaper(srcName, isVideo) {
        var full = root.srcDir + "/" + srcName
        if (isVideo) {
            applyProc.command = ["bash", "-c",
                "pkill mpvpaper 2>/dev/null; mpvpaper -o 'no-audio loop' '*' '" + full + "' &"]
        } else {
            applyProc.command = ["bash", "-c",
                "awww img '" + full + "' --resize crop --transition-type wipe --transition-fps 60"]
        }
        applyProc.running = true
        root.currentWallpaper = srcName
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#282828"
        border.color: "#3c3836"
        border.width: 1

        Column {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            spacing: 10

            RowLayout {
                width: parent.width
                Text {
                    text: "Wallpapers"
                    color: "#d4be98"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                }
                Text {
                    text: thumbModel.count + " wallpapers  ·  " + root.srcDir
                    color: "#504945"
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideLeft
                    Layout.maximumWidth: 300
                }
            }

            // Thumbnail grid
            ScrollView {
                width: parent.width
                height: root.height - 70
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                GridView {
                    width: parent.width
                    model: thumbModel
                    cellWidth: 140
                    cellHeight: 100
                    clip: true

                    delegate: Item {
                        width: 140
                        height: 100

                        Rectangle {
                            anchors { fill: parent; margins: 4 }
                            radius: 8
                            color: "#1d2021"
                            clip: true
                            border.color: model.isCurrent ? "#7daea3" : "transparent"
                            border.width: 2

                            Image {
                                anchors.fill: parent
                                source: "file://" + model.thumbPath
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true

                                // Loading placeholder
                                Rectangle {
                                    visible: parent.status !== Image.Ready
                                    anchors.fill: parent
                                    color: "#32302f"
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.isVideo ? "" : ""
                                        color: "#504945"
                                        font.pixelSize: 20
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }

                            // Video badge
                            Rectangle {
                                visible: model.isVideo
                                anchors { top: parent.top; left: parent.left; margins: 4 }
                                width: 20; height: 14; radius: 3
                                color: "#282828cc"
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#d8a657"
                                    font.pixelSize: 8
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }

                            // Active checkmark
                            Rectangle {
                                visible: model.isCurrent
                                anchors { top: parent.top; right: parent.right; margins: 4 }
                                width: 16; height: 16; radius: 8
                                color: "#7daea3"
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#1d2021"
                                    font.pixelSize: 8
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyWallpaper(model.srcName, model.isVideo)
                            }
                        }
                    }
                }
            }
        }
    }
}
