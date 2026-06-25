// Osd.qml — Transient on-screen display for volume / brightness (bottom-centre).
// Presentational only: Shell.qml drives `kind`/`level`/`muted` and the auto-hide
// timer. Volume changes are observed passively from PipeWire; brightness is
// push-triggered via the `osd` IPC call (no passive signal exists for it).
import Quickshell
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: osd

    property string kind:  ""     // "volume" | "brightness" | ""
    property real   level: 0      // 0..1
    property bool   muted: false

    screen: Theme.focusedScreen()
    visible: kind !== ""

    anchors { bottom: true }
    margins { bottom: 120 }
    exclusiveZone: 0
    implicitWidth: 300
    implicitHeight: 64
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 14

            Text {
                text: osd.kind === "brightness" ? "󰃟"
                    : osd.muted                 ? "󰝟"
                    : osd.level > 0.5           ? "󰕾"
                    : osd.level > 0.0           ? "󰖀" : "󰕿"
                color: osd.muted ? Theme.red : Theme.accent
                font.pixelSize: 24
                font.family: Theme.font
            }

            // Level track + fill
            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.bgAlt

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, osd.level))
                    height: parent.height
                    radius: 3
                    color: osd.muted ? Theme.gray : Theme.accent
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            Text {
                text: Math.round(osd.level * 100)
                color: Theme.fg
                font.pixelSize: 13
                font.family: Theme.font
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
