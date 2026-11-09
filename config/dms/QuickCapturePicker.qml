// QuickCapturePicker.qml — quickCapture's bar menu as a floating, centred
// window: what Print opens under DMS, with no bar pill.
//
// Installed into the quickCapture plugin directory by
// modules/home/wm/dms-plugins.nix, which also gives QuickCaptureDaemon.qml a
// `picker` instance and a `showPicker` IPC command
// (`dms ipc call quickCapture showPicker`, the Print bind in config/hypr/hyprland.lua).
//
// CaptureMenu (components/bar/) expects to be the plugin's bar popout and reads
// its state from the bar widget, QuickCaptureWidget.qml. `host` below provides
// the same properties and functions, backed by the daemon. Re-check it against
// QuickCaptureWidget.qml when bumping the plugin.
import QtQuick
import qs.Common
import qs.Modals.Common
import "./components/bar"
import "./components/core/Defaults.js" as Defaults

DankModal {
    id: root

    required property var daemon

    // Its own namespace so hyprland.lua can turn off Hyprland's layer fade
    // for it (no_anim): that fade outlives the window, and the capture would
    // catch it.
    layerNamespace: "dms:quick-capture-picker"
    positioning: "center"
    enableShadow: true
    useOverlayLayer: true
    closeOnEscapeKey: true
    closeOnBackgroundClick: true
    onBackgroundClicked: close()

    modalWidth: host.popoutWidth + Theme.spacingL * 2
    modalHeight: host.popoutHeight + Theme.spacingL * 2

    function show() {
        if (shouldBeVisible) {
            close();
            return;
        }
        root.daemon.refreshOutputs();
        shouldBeVisible = true;
        open();
    }

    onDialogClosed: shouldBeVisible = false

    // Stand-in for QuickCaptureWidget: same names, same sizes.
    Item {
        id: host
        visible: false

        readonly property var daemon: root.daemon
        readonly property var recorder: daemon.recordingController
        readonly property bool isRecording: daemon.isRecording
        readonly property bool isPaused: recorder?.isPaused ?? false
        readonly property string widgetMode: daemon.widgetMode
        readonly property var pluginData: daemon.pluginData
        readonly property bool blinkRecordDot: Defaults.get(pluginData, "blinkRecordDot")
        readonly property string durationText: recorder ? recorder.formatDuration(recorder.recordingSeconds) : "00:00"
        readonly property alias config: captureConfig
        readonly property int popoutWidth: 280
        readonly property int popoutHeight: widgetMode === "video" ? (isRecording ? 320 : 310) : 465 + Math.min((daemon.outputs ?? []).length, 5) * 38

        CaptureConfig {
            id: captureConfig
            pluginData: host.pluginData
        }

        function setWidgetMode(mode) {
            daemon.widgetMode = mode;
        }

        function closePopout() {
            root.close();
        }

        // The menu captures through daemon.captureFromMenu, which calls this
        // and then shoots on the next tick, so the window has to be gone at
        // once (without it the daemon fell back to the animated closePopout
        // and the menu landed in the shot). Hyprland's layer fade is off for
        // this namespace (hyprland.lua), so nothing lingers after the unmap.
        function closePopoutImmediately() {
            root.instantClose();
            root.shouldBeVisible = false;
        }

        function runAfterPopoutClosed(action) {
            closePopoutImmediately();
            Qt.callLater(action);
        }
    }

    content: Component {
        Item {
            CaptureMenu {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                widget: host
            }
        }
    }
}
