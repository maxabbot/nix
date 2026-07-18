// WallpaperPicker.qml — Wallpaper browser page (embedded in Settings.qml — no window chrome).
//
// Thumbnails are pre-generated into ~/.cache/quickshell/wallpaper_picker/thumbs/ by
// qs_manager.sh (which also starts this panel). On open, this page lists the thumbs
// directory and displays them in a grid. Clicking a thumbnail applies the wallpaper.
//
// Video thumbnails are named 000_<original> — clicking them sets the mpvpaper source.
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    // ── State ──────────────────────────────────────────────────────────────────
    ListModel { id: thumbModel }
    property string thumbDir: ""
    property string srcDir: ""
    property string currentWallpaper: ""

    // Target output for the next apply — "" means every monitor.
    property string targetOutput: ""
    readonly property bool multiMon: (Hyprland.monitors?.values.length ?? 0) > 1
    readonly property var outputs: {
        var l = ["All"]
        if (Hyprland.monitors)
            for (var i = 0; i < Hyprland.monitors.values.length; i++) {
                var m = Hyprland.monitors.values[i]
                if (m) l.push(m.name)
            }
        return l
    }

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
            "awww query 2>/dev/null | grep -oiE '[^ ]*\\.(png|jpg|jpeg|gif|mp4|mkv|mov|webm)' | head -n1 || true"
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
        var out = root.targetOutput
        if (isVideo) {
            // mpvpaper output selector: '*' targets all monitors.
            applyProc.command = ["bash", "-c",
                "pkill mpvpaper 2>/dev/null; mpvpaper -o 'no-audio loop' '" +
                (out !== "" ? out : "*") + "' '" + full + "' &"]
        } else {
            var outs = out !== "" ? "--outputs '" + out + "' " : ""
            applyProc.command = ["bash", "-c",
                "awww img " + outs + "'" + full + "' --resize crop --transition-type wipe --transition-fps 60"]
        }
        applyProc.running = true
        // Only reflect "current" globally when applying to all outputs.
        if (out === "") root.currentWallpaper = srcName
    }

    function applyRandom() {
        if (thumbModel.count === 0) return
        var m = thumbModel.get(Math.floor(Math.random() * thumbModel.count))
        applyWallpaper(m.srcName, m.isVideo)
    }

    // ── Slideshow ────────────────────────────────────────────────────────────
    // Session-scoped rotation (resets to off on Quickshell restart). The Timer
    // keeps firing while Settings is closed because the page stays instantiated
    // in the StackLayout; it applies to whatever `targetOutput` is selected.
    property bool slideshow: false
    readonly property int slideshowInterval: 300000  // 5 min
    Timer {
        interval: root.slideshowInterval
        repeat: true
        running: root.slideshow
        onTriggered: root.applyRandom()
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Wallpapers"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }
            Text {
                text: thumbModel.count + " wallpapers  ·  " + root.srcDir
                color: Theme.borderStrong
                font.pixelSize: 10
                font.family: Theme.font
                elide: Text.ElideLeft
                Layout.maximumWidth: 300
            }
        }

        // Output selector (multi-monitor) + Random
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.multiMon ? root.outputs : []

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel:
                        (modelData === "All" && root.targetOutput === "") || modelData === root.targetOutput

                    implicitWidth: oLabel.implicitWidth + 16
                    height: 26
                    radius: 7
                    color: sel ? Theme.accentBg : (oArea.containsMouse ? Theme.border : Theme.bgAlt)
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        id: oLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.sel ? Theme.accent : Theme.gray
                        font.pixelSize: 10
                        font.family: Theme.font
                    }
                    MouseArea {
                        id: oArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.targetOutput = (modelData === "All" ? "" : modelData)
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Slideshow toggle (rotates every 5 min while active)
            Rectangle {
                implicitWidth: slideLabel.implicitWidth + 34
                height: 26
                radius: 7
                color: root.slideshow ? Theme.accentBg
                     : (slideArea.containsMouse ? Theme.border : Theme.bgAlt)
                Behavior on color { ColorAnimation { duration: 80 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: root.slideshow ? "󰏤" : "󰑖"
                        color: root.slideshow ? Theme.accent : Theme.gray
                        font.pixelSize: 12
                        font.family: Theme.font
                    }
                    Text {
                        id: slideLabel
                        text: "Slideshow"
                        color: root.slideshow ? Theme.fg : Theme.gray
                        font.pixelSize: 11
                        font.family: Theme.font
                    }
                }
                MouseArea {
                    id: slideArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Advance immediately on enable so the toggle gives feedback
                    // instead of waiting a full interval for the first change.
                    onClicked: {
                        root.slideshow = !root.slideshow
                        if (root.slideshow) root.applyRandom()
                    }
                }
            }

            Rectangle {
                implicitWidth: randLabel.implicitWidth + 22
                height: 26
                radius: 7
                color: randArea.containsMouse ? Theme.accentBgHover : Theme.accentBg
                Behavior on color { ColorAnimation { duration: 80 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { text: "󰒲"; color: Theme.accent; font.pixelSize: 12; font.family: Theme.font }
                    Text { id: randLabel; text: "Random"; color: Theme.fg; font.pixelSize: 11; font.family: Theme.font }
                }
                MouseArea {
                    id: randArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyRandom()
                }
            }
        }

        // Thumbnail grid
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                        color: Theme.bgHard
                        clip: true
                        border.color: model.isCurrent ? Theme.accent : "transparent"
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
                                color: Theme.bgAlt
                                Text {
                                    anchors.centerIn: parent
                                    text: model.isVideo ? "" : ""
                                    color: Theme.borderStrong
                                    font.pixelSize: 20
                                    font.family: Theme.font
                                }
                            }
                        }

                        // Video badge
                        Rectangle {
                            visible: model.isVideo
                            anchors { top: parent.top; left: parent.left; margins: 4 }
                            width: 20; height: 14; radius: 3
                            color: Theme.bgFloat
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: Theme.yellow
                                font.pixelSize: 8
                                font.family: Theme.font
                            }
                        }

                        // Active checkmark
                        Rectangle {
                            visible: model.isCurrent
                            anchors { top: parent.top; right: parent.right; margins: 4 }
                            width: 16; height: 16; radius: 8
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: Theme.bgHard
                                font.pixelSize: 8
                                font.family: Theme.font
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
