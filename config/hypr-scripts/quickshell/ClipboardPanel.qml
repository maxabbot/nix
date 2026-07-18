// ClipboardPanel.qml — centred cliphist history modal with hover-to-expand rows.
//
// On open, clipboard-prep.sh emits one JSON line per history entry (images decoded
// to thumbnail files, text decoded in full) which is parsed straight into the model.
// Hovering a row expands it in place: text shows the full wrapped content, images a
// large preview. Clicking a row copies the entry and closes the panel; Escape or a
// click outside the card dismisses it.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"

    // Grab the keyboard while visible so Escape can dismiss the panel
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
    }

    ListModel { id: clipModel }
    property bool loading: false

    onVisibleChanged: reload()
    Component.onCompleted: reload()

    function reload() {
        if (!visible) return
        clipModel.clear()
        loading = true
        loadProc.running = true
    }

    // ── Load history (JSON lines from clipboard-prep.sh) ───────────────────────
    Process {
        id: loadProc
        command: ["bash", Quickshell.shellDir + "/../clipboard-prep.sh"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const e = JSON.parse(line)
                    clipModel.append({
                        entryId: e.id,
                        kind:    e.kind,
                        preview: e.preview,
                        full:    e.full ?? "",
                        thumb:   e.thumb ?? ""
                    })
                } catch (err) { /* skip malformed line */ }
            }
        }
        onExited: root.loading = false
    }

    // ── Copy entry ──────────────────────────────────────────────────────────────
    Process { id: copyProc; command: [] }

    function copyEntry(entryId) {
        // entryId is a numeric cliphist id — safe to inline
        copyProc.command = ["bash", "-c", "printf '%s' '" + entryId + "' | cliphist decode | wl-copy"]
        copyProc.running = true
        root.closeRequested()
    }

    // ── Dimmer — click outside the card to dismiss ──────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // ── Card (centred) ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: 440
        height: 540
        radius: Theme.radiusPanel
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        // Swallow clicks on the card so they don't fall through to the dimmer
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            height: 36

            Text {
                text: "Clipboard"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }

            Text {
                text: root.loading ? "loading…" : clipModel.count + " entries  ·  click to copy"
                color: Theme.grayDim
                font.pixelSize: 10
                font.family: Theme.font
            }
        }

        Rectangle {
            id: divider
            anchors { top: header.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.border
        }

        ScrollView {
            id: scroller
            anchors {
                top: divider.bottom
                left: parent.left; right: parent.right; bottom: parent.bottom
                margins: 8
            }
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                // Sized from the ScrollView itself: parent.width (Flickable content)
                // stays 0 when the window starts hidden, and availableWidth shifts
                // with the scrollbar, looping back into row heights. The -8 keeps
                // rows clear of the overlaid scrollbar.
                width: scroller.width - 8
                spacing: 6

                // Empty state
                Item {
                    visible: clipModel.count === 0 && !root.loading
                    width: parent.width
                    height: 80

                    Text {
                        anchors.centerIn: parent
                        text: "Clipboard history is empty"
                        color: Theme.grayDim
                        font.pixelSize: 13
                        font.family: Theme.font
                    }
                }

                Repeater {
                    model: clipModel

                    delegate: Rectangle {
                        id: row
                        width: parent.width
                        radius: Theme.radiusButton
                        clip: true
                        color: expanded ? Theme.bgSoft : Theme.bgAlt
                        border.color: Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        // Set from the hover event, not bound to containsMouse: the row's
                        // height change moves the row under the cursor, and a binding on
                        // containsMouse would re-enter itself (binding loop).
                        property bool expanded: false
                        height: expanded
                            ? (model.kind === "image"
                                ? 240
                                : Math.min(fullText.implicitHeight + 20, 280))
                            : 36
                        Behavior on height {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        // Collapsed single-line preview
                        RowLayout {
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                            height: 20
                            spacing: 8
                            opacity: row.expanded ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                            Text {
                                text: model.kind === "image" ? "󰋩" : (model.kind === "binary" ? "󰈔" : "󰅍")
                                color: Theme.accent
                                font.pixelSize: 12
                                font.family: Theme.font
                            }

                            Image {
                                visible: model.kind === "image"
                                source: model.thumb ? "file://" + model.thumb : ""
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 20
                            }

                            Text {
                                text: model.preview
                                color: Theme.fgDim
                                font.pixelSize: 11
                                font.family: Theme.font
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Expanded content — full text or large image preview
                        Item {
                            anchors { fill: parent; margins: 10 }
                            opacity: row.expanded ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                            Text {
                                id: fullText
                                visible: model.kind !== "image"
                                // Constant width (panel 440 − paddings/scrollbar). Binding to
                                // parent.width loops: row height → scrollbar → content width
                                // → re-wrap → implicitHeight → row height.
                                width: 384
                                text: model.kind === "binary" ? model.preview : model.full
                                color: Theme.fgDim
                                font.pixelSize: 11
                                font.family: Theme.font
                                // No elide/maximumLineCount: with those set, implicitHeight
                                // feeds back into the row height binding (loop). The row's
                                // 280px height cap + clip bounds the expansion instead.
                                wrapMode: Text.Wrap
                            }

                            Image {
                                visible: model.kind === "image"
                                anchors.fill: parent
                                source: model.thumb ? "file://" + model.thumb : ""
                                sourceSize: Qt.size(800, 480)  // cap decode size for huge images
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: row.expanded = containsMouse
                            onClicked: root.copyEntry(model.entryId)
                        }
                    }
                }
            }
        }
    }
}
