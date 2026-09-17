// Hover tooltip for DankBar pills — not part of upstream DMS.
//
// modules/home/wm/shell-switcher.nix installs this into the package's Widgets/
// directory, adds a `tooltipText` property to Modules/Plugins/BasePill.qml and
// instantiates one of these per pill; individual bar widgets are then patched
// to bind tooltipText. An empty tooltipText means no tooltip.
//
// Upstream's own DankTooltip is single-line and only wired up for vertical
// bars, so this is its own layer-shell window: multi-line, placed just past
// the bar edge on any of the four bar positions, and click-through.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Item {
    id: root

    required property Item pill

    readonly property bool wanted: pill.isMouseHovered && pill.tooltipText !== ""

    onWantedChanged: {
        if (wanted) {
            showDelay.restart();
        } else {
            showDelay.stop();
            loader.active = false;
        }
    }

    Timer {
        id: showDelay
        interval: 400
        onTriggered: loader.active = root.wanted
    }

    Loader {
        id: loader
        active: false

        sourceComponent: PanelWindow {
            id: win

            readonly property var pill: root.pill
            // SettingsData.Position: 0 top, 1 bottom, 2 left, 3 right.
            readonly property int edge: {
                switch (pill.axis?.edge) {
                case "bottom":
                    return 1;
                case "left":
                    return 2;
                case "right":
                    return 3;
                default:
                    return 0;
                }
            }
            // Same helper BasePill uses to place popouts, so the tooltip keeps
            // the popout gap. Evaluated once per hover — the window is created
            // fresh each time.
            readonly property var anchorPoint: SettingsData.getPopupTriggerPosition(pill.visualContent.mapToItem(null, 0, 0), pill.parentScreen, pill.barThickness, pill.visualWidth, pill.barSpacing, edge, pill.barConfig)
            readonly property real screenW: pill.parentScreen?.width ?? 0
            readonly property real screenH: pill.parentScreen?.height ?? 0

            function clamp(v, max) {
                return Math.round(Math.max(Theme.spacingS, Math.min(max - Theme.spacingS, v)));
            }

            WlrLayershell.namespace: "dms:tooltip"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            screen: pill.parentScreen
            color: "transparent"
            mask: Region {}

            implicitWidth: label.implicitWidth + Theme.spacingM * 2
            implicitHeight: label.implicitHeight + Theme.spacingS * 2

            anchors {
                top: true
                left: true
            }

            margins {
                left: {
                    if (edge === 2)
                        return Math.round(anchorPoint.x);
                    if (edge === 3)
                        return Math.round(anchorPoint.x - implicitWidth);
                    return clamp(anchorPoint.x + pill.visualWidth / 2 - implicitWidth / 2, screenW - implicitWidth);
                }
                top: {
                    if (edge === 0)
                        return Math.round(anchorPoint.y);
                    if (edge === 1)
                        return Math.round(anchorPoint.y - implicitHeight);
                    return clamp(anchorPoint.y + pill.visualHeight / 2 - implicitHeight / 2, screenH - implicitHeight);
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: win.pill.tooltipText
                    textFormat: Text.PlainText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    lineHeight: 1.15
                }
            }
        }
    }
}
