// QuickCapturePicker.qml — quickCapture's bar menu as a floating, centred
// window: what Print opens under DMS, with no bar pill and no Control Center.
//
// Installed into the quickCapture plugin directory by
// modules/home/wm/dms-plugins.nix, which also gives QuickCaptureDaemon.qml a
// `picker` instance and a `showPicker` IPC command
// (`dms ipc call quickCapture showPicker`, see config/hypr-scripts/shell-ipc.sh).
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
        readonly property int popoutWidth: 260
        readonly property int popoutHeight: widgetMode === "video" ? (isRecording ? 320 : 290) : 445 + Math.min((daemon.outputs ?? []).length, 5) * 32

        property var pendingAction: null

        CaptureConfig {
            id: captureConfig
            pluginData: host.pluginData
        }

        // The menu hands a capture over through this so it starts after the
        // window has gone, as it does after the bar popout closes.
        Timer {
            id: closeTimer
            interval: Math.max(50, Theme.modalAnimationDuration + 50)
            onTriggered: {
                const action = host.pendingAction;
                host.pendingAction = null;
                if (action)
                    action();
            }
        }

        function setWidgetMode(mode) {
            daemon.widgetMode = mode;
        }

        function closePopout() {
            root.close();
        }

        function runAfterPopoutClosed(action) {
            pendingAction = action;
            root.close();
            closeTimer.restart();
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
