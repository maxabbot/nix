// MediaPlayer.qml — Compact MPRIS media controls for the bar.
// Rendered inline in Bar.qml's RowLayout (not a PanelWindow).
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 34

    // Use the first available MPRIS player
    readonly property var player: Mpris.players.count > 0 ? Mpris.players.values[0] : null
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing ?? false

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 2

        // Previous
        Rectangle {
            width: 26; height: 26; radius: 6
            color: prevArea.containsMouse ? Theme.border : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
            Text {
                anchors.centerIn: parent
                text: ""
                color: root.player?.canGoPrevious ? Theme.fg : Theme.borderStrong
                font.pixelSize: 12
                font.family: Theme.font
            }
            MouseArea {
                id: prevArea; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.previous()
            }
        }

        // Play / Pause
        Rectangle {
            width: 26; height: 26; radius: 6
            color: playArea.containsMouse ? Theme.border : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
            Text {
                anchors.centerIn: parent
                text: root.playing ? "" : ""
                color: Theme.accent
                font.pixelSize: 12
                font.family: Theme.font
            }
            MouseArea {
                id: playArea; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.playPause()
            }
        }

        // Next
        Rectangle {
            width: 26; height: 26; radius: 6
            color: nextArea.containsMouse ? Theme.border : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
            Text {
                anchors.centerIn: parent
                text: ""
                color: root.player?.canGoNext ? Theme.fg : Theme.borderStrong
                font.pixelSize: 12
                font.family: Theme.font
            }
            MouseArea {
                id: nextArea; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.next()
            }
        }

        // Track info
        Column {
            spacing: 0
            Layout.maximumWidth: 200
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.player?.trackTitle ?? ""
                color: Theme.fg
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.font
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.player?.trackArtist ?? ""
                color: Theme.gray
                font.pixelSize: 10
                font.family: Theme.font
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
