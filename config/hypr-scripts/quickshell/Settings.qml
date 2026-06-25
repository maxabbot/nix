// Settings.qml — Tabbed settings panel (top-right, drops from Waybar).
// Hosts the former standalone panels as pages: Control, Audio, Monitors,
// Wallpaper, System, Nix. Waybar module clicks deep-link to a tab via
// `qs_manager.sh toggle settings <tab>` (see Shell.qml's IPC handler).
// Esc closes; click-off handled by Shell.qml's focus grab.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    // Drop onto whichever monitor currently has focus, not a fixed default —
    // otherwise the panel always lands on one screen no matter where you are.
    screen: Theme.focusedScreen()

    anchors { top: true; right: true }
    margins { top: Theme.panelGapTop; right: 12 }
    implicitWidth: 780
    implicitHeight: 620
    color: "transparent"

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property string currentTab: "control"
    property bool dndEnabled: false

    // Laptop-only tabs are hidden on desktops with no battery. Detected at
    // startup so the Battery tab never shows on home-desktop / vm.
    property bool hasBattery: false
    Process {
        id: detectBattery
        command: ["bash", "-c", "ls -d /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo yes || echo no"]
        stdout: SplitParser { onRead: (line) => root.hasBattery = (line.trim() === "yes") }
    }
    Component.onCompleted: detectBattery.running = true

    signal closeRequested()
    signal dndToggled()
    signal rebuildStarted()
    signal rebuildFinished(bool ok)

    readonly property var tabs: [
        { id: "control",   icon: "",  label: "Control"   },
        { id: "network",   icon: "",  label: "Wi-Fi"     },
        { id: "bluetooth", icon: "",  label: "Bluetooth" },
        { id: "kdeconnect",icon: "󰄜",  label: "KDE Connect" },
        { id: "audio",     icon: "",  label: "Audio"     },
        { id: "monitors",  icon: "󰍹",  label: "Monitors"  },
        { id: "wallpaper", icon: "󰸉",  label: "Wallpaper" },
        { id: "theme",     icon: "󰏘",  label: "Theme"     },
        { id: "keyboard",  icon: "",  label: "Keyboard"  },
        { id: "input",     icon: "󰍽",  label: "Input"     },
        { id: "battery",   icon: "󰁹",  label: "Battery",   laptopOnly: true },
        { id: "disks",     icon: "󰋊",  label: "Drives"    },
        { id: "sysinfo",   icon: "󰍛",  label: "System"    },
        { id: "nix",       icon: "󱄅",  label: "Nix"       },
    ]
    readonly property int tabIndex: {
        for (var i = 0; i < tabs.length; i++)
            if (tabs[i].id === currentTab) return i
        return 0
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        focus: true
        Keys.onEscapePressed: root.closeRequested()

        RowLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 12

            // ── Sidebar tabs ──────────────────────────────────────────────────
            ColumnLayout {
                // Layouts nested in layouts default to fillWidth: true — must
                // opt out or the sidebar swallows the page area.
                Layout.fillWidth: false
                Layout.preferredWidth: 150
                Layout.fillHeight: true
                spacing: 4

                Repeater {
                    model: root.tabs

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool tabActive: root.currentTab === modelData.id
                        // Collapse laptop-only tabs (e.g. Battery) on desktops.
                        readonly property bool tabAvail: !(modelData.laptopOnly === true) || root.hasBattery

                        visible: tabAvail
                        Layout.fillWidth: true
                        Layout.preferredHeight: tabAvail ? 36 : 0
                        radius: Theme.radiusButton
                        color: tabActive ? Theme.accentBg
                             : tabArea.containsMouse ? Theme.border : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 8

                            Text {
                                text: modelData.icon
                                color: tabActive ? Theme.accent : Theme.gray
                                font.pixelSize: 14
                                font.family: Theme.font
                            }
                            Text {
                                text: modelData.label
                                color: tabActive ? Theme.fg : Theme.gray
                                font.pixelSize: 12
                                font.family: Theme.font
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = modelData.id
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle { implicitWidth: 1; Layout.fillHeight: true; color: Theme.border }

            // ── Pages — order must match `tabs` ───────────────────────────────
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.tabIndex

                ControlCenter {
                    dndEnabled: root.dndEnabled
                    onDndToggled: root.dndToggled()
                }
                NetworkPanel { }
                BluetoothPanel { }
                KDEConnectPanel { }
                AudioMixer { }
                MonitorManager { }
                WallpaperPicker { }
                ThemePanel { }
                KeyboardPanel { }
                InputPanel { }
                BatteryPanel { }
                DiskPanel { }
                SysInfoPanel { }
                NixPanel {
                    onRebuildStarted: root.rebuildStarted()
                    onRebuildFinished: (ok) => root.rebuildFinished(ok)
                }
            }
        }
    }
}
