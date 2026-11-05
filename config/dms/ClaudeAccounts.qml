// ClaudeAccounts.qml — the account switcher at the foot of the claudeUsage
// popout: one segment per login saved with `claude-account save <name>`, the
// active one selected; a tap swaps Claude Code (and so this widget) to it.
//
// Installed into the claudeUsage plugin directory by
// modules/home/wm/dms-plugins.nix, which substitutes @claudeAccount@ with the
// pkgs/claude-account binary and emits `switched` into a usage refresh.
import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    signal switched

    readonly property string exe: "@claudeAccount@"
    property var accounts: []       // [{name, email, org, active}]
    property string message: ""
    property bool busy: false

    readonly property int activeIndex: accounts.findIndex(a => a.active)

    spacing: Theme.spacingS

    function reload() {
        Proc.runCommand("claudeUsage.accounts", [exe, "list", "--json"], function (stdout, exitCode) {
            if (exitCode !== 0)
                return;
            try {
                root.accounts = JSON.parse(stdout);
            } catch (e) {
                console.warn("claudeUsage: bad account list:", e);
            }
        }, 0);
    }

    function use(name) {
        busy = true;
        // stderr folded in: it carries the error, or the running-sessions warning
        Proc.runCommand("claudeUsage.use", ["sh", "-c", '"$0" use "$1" 2>&1', exe, name], function (stdout, exitCode) {
            root.busy = false;
            root.message = stdout.trim().split("\n").slice(1).join("\n") || (exitCode === 0 ? "" : stdout.trim());
            root.reload();
            if (exitCode === 0)
                root.switched();
        }, 0);
    }

    Component.onCompleted: reload()

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineLight
    }

    StyledText {
        visible: root.accounts.length > 0
        text: root.activeIndex >= 0
            ? root.accounts[root.activeIndex].email
            : "Current login isn't saved"
        color: Theme.surfaceTextMedium
        font.pixelSize: Theme.fontSizeSmall
    }

    DankButtonGroup {
        visible: root.accounts.length > 0
        size: "small"
        model: root.accounts.map(a => a.name)
        currentIndex: root.activeIndex
        checkEnabled: true
        onSelectionChanged: (index, selected) => {
            if (selected && index !== root.activeIndex && !root.busy)
                root.use(root.accounts[index].name);
        }
    }

    StyledText {
        width: parent.width
        visible: root.accounts.length === 0
        text: "Keep several logins: claude-account save <name>, /login to the next, save again."
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        visible: root.message !== ""
        text: root.message
        wrapMode: Text.WordWrap
        color: Theme.warning
        font.pixelSize: Theme.fontSizeSmall
    }
}
