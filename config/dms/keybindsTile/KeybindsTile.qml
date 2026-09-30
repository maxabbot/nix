// KeybindsTile.qml — a Control Center tile that opens DMS's keybind overlay,
// the same one Super+/ toggles. No bar pill: the bar's right side is full.
//
// Installed as a local plugin by modules/home/wm/dms-plugins.nix and added to
// the Control Center by modules/home/wm/dms.nix (controlCenterAdd).
//
// It goes through `dms ipc` rather than reaching for the modal: DMS only
// creates that on first use, inside its IPC handler.
import QtQuick
import Quickshell
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    ccWidgetIcon: "keyboard"
    ccWidgetPrimaryText: "Keybinds"
    ccWidgetSecondaryText: "Super + /"
    ccWidgetIsActive: false
    ccWidgetIsToggle: true

    onCcWidgetToggled: {
        PopoutService.closeControlCenter();
        Quickshell.execDetached(["dms", "ipc", "hypr", "toggleBinds"]);
    }
}
