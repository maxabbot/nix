// LanMouseTile.qml — a Control Center toggle for lan-mouse (cursor sharing
// with the peer). Off stops the user unit, so nothing crosses the shared edge;
// on starts it again. Stopping lasts until the next login, when
// graphical-session.target pulls the unit back in.
//
// Installed as a local plugin by modules/home/wm/dms-plugins.nix (only on
// hosts with lanMouse.enable) and added to the Control Center by
// modules/home/wm/dms.nix (controlCenterAdd).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool running: false

    ccWidgetIcon: "mouse"
    ccWidgetPrimaryText: "Lan Mouse"
    ccWidgetSecondaryText: running ? "Sharing" : "Off"
    ccWidgetIsActive: running
    ccWidgetIsToggle: true

    onCcWidgetToggled: {
        Quickshell.execDetached(["systemctl", "--user", running ? "stop" : "start", "lan-mouse"]);
        running = !running;
        // Re-read shortly after, in case the start failed.
        recheck.restart();
    }

    // The unit can also change outside the tile (systemctl, a restart on
    // failure), so poll its state.
    Process {
        id: stateProc
        command: ["systemctl", "--user", "is-active", "--quiet", "lan-mouse"]
        onExited: exitCode => root.running = exitCode === 0
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!stateProc.running) stateProc.running = true
    }

    Timer {
        id: recheck
        interval: 1500
        onTriggered: if (!stateProc.running) stateProc.running = true
    }
}
