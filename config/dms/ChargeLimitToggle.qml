// ChargeLimitToggle.qml — "Charge to 100%" row for the batteryPlus popout and
// Control Center detail. Patched into the plugin's BatteryPanel by
// modules/home/wm/dms-plugins.nix.
//
// On starts battery-charge-full.service (writes 100 to the EC's charge limit);
// off starts battery-charge-limit.service, which writes 80 and Conflicts= the
// other away. Both are system units on framework (hosts/framework/default.nix),
// startable without a password through a polkit rule; nothing starts
// battery-charge-full at boot, so a reboot always returns to 80%.
//
// The switch shows the EC's live threshold rather than the unit's state, so a
// limit set by hand shows up too. The row hides where the attribute doesn't
// exist (no framework_laptop kmod).
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.DCommon.Widgets

Item {
    id: root

    readonly property string thresholdPath: "/sys/class/power_supply/BAT1/charge_control_end_threshold"

    property int threshold: -1
    readonly property bool full: threshold >= 100

    visible: threshold > 0
    height: visible ? Math.max(labels.implicitHeight, toggle.height) : 0

    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            text: "Charge to 100%"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceTextMedium
            font.weight: Font.Medium
        }

        StyledText {
            text: root.full ? "Until reboot" : `Charging stops at ${root.threshold}%`
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    DToggle {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        hideText: true
        checked: root.full
        toggling: setProc.running
        onToggled: on => {
            setProc.command = ["systemctl", "start", on ? "battery-charge-full.service" : "battery-charge-limit.service"];
            setProc.running = true;
        }
    }

    Process {
        id: setProc
        stderr: StdioCollector {
            id: setErr
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                ToastService.showError("Couldn't change the charge limit: " + setErr.text.trim());
            readProc.running = true;
        }
    }

    Process {
        id: readProc
        command: ["cat", root.thresholdPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.threshold = isNaN(v) ? -1 : v;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.threshold = -1;
        }
    }

    // sysfs attributes don't notify, so poll while the panel is open.
    Timer {
        interval: 5000
        repeat: true
        running: root.visible || root.threshold < 0
        triggeredOnStart: true
        onTriggered: if (!readProc.running) readProc.running = true
    }
}
