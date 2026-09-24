// System monitor pill for DankBar — not part of upstream DMS. CPU, memory and
// GPU in one pill, each an icon plus a thin usage gauge that fills from the
// bottom, after Noctalia's SystemMonitor in compact mode. CPU and GPU also
// show their temperature; exact figures, and root filesystem usage, are in
// the tooltip.
//
// modules/home/wm/shell-switcher.nix installs this OVER the package's
// Modules/DankBar/Widgets/CpuMonitor.qml, so it renders wherever the
// "cpuUsage" id is on a bar and DankBarContent's cpuUsageComponent wiring
// (bar geometry, popoutTarget, onCpuClicked → process list) applies
// unchanged. It therefore keeps CpuMonitor's interface: popoutTarget,
// widgetData and the cpuClicked signal. Re-check that component when bumping
// dms-shell.
//
// CPU and memory come from dgop via DgopService. The GPU comes from
// `nvtop -s` (a one-shot JSON snapshot, ~0.2s; nvtop is installed on every
// host by productivity.nix), polled every 2s. It reads NVIDIA, AMD and Intel
// alike and needs no root, so laptops get their integrated GPU. With several
// GPUs the discrete one (NVIDIA/AMD by name) wins, else the first listed.
// Intel iGPUs report no temperature, so there the segment is just the gauge.
// If nvtop fails or lists nothing, polling stops and the segment stays hidden.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var popoutTarget: null
    property var widgetData: null

    signal cpuClicked

    property bool gpuAvailable: false
    property string gpuName: ""
    property real gpuUsage: 0
    property real gpuTemp: 0 // 0 = not reported

    readonly property real iconSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
    readonly property real textSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)

    // Thresholds are upstream's own: CpuMonitor (usage), CpuTemperature
    // (temperature) and RamMonitor (memory).
    function levelColor(value, warning, danger, normal) {
        if (value > danger)
            return Theme.tempDanger;
        if (value > warning)
            return Theme.tempWarning;
        return normal;
    }

    tooltipText: {
        let s = "CPU " + Math.round(DgopService.cpuUsage) + "% · " + (DgopService.cpuFrequency / 1000).toFixed(1) + " GHz";
        if (DgopService.cpuTemperature > 0)
            s += " · " + Math.round(DgopService.cpuTemperature) + "°C";
        s += "\nMemory " + (DgopService.usedMemoryMB / 1024).toFixed(1) + " / " + (DgopService.totalMemoryMB / 1024).toFixed(1) + " GiB (" + Math.round(DgopService.memoryUsage) + "%)";
        if (root.gpuAvailable)
            s += "\nGPU " + Math.round(root.gpuUsage) + "%" + (root.gpuTemp > 0 ? " · " + Math.round(root.gpuTemp) + "°C" : "") + (root.gpuName ? " · " + root.gpuName : "");
        // Root filesystem, in the same words as DMS's own diskUsage tooltip.
        const disk = (DgopService.diskMounts || []).find(m => m.mount === "/");
        if (disk)
            s += "\nDisk " + disk.used + " of " + disk.size + " used (" + disk.percent + ") · " + disk.avail + " free";
        return s;
    }

    Component.onCompleted: DgopService.addRef(["cpu", "memory", "diskmounts"])
    Component.onDestruction: DgopService.removeRef(["cpu", "memory", "diskmounts"])

    Process {
        id: gpuProc
        command: ["nvtop", "-s"]
        stdout: StdioCollector {
            onStreamFinished: {
                let gpus = [];
                try {
                    gpus = JSON.parse(text);
                } catch (e) {
                    return;
                }
                if (!Array.isArray(gpus) || gpus.length === 0) {
                    if (!root.gpuAvailable)
                        gpuTimer.running = false;
                    return;
                }
                const gpu = gpus.find(g => /NVIDIA|AMD|Radeon/i.test(g.device_name || "")) || gpus[0];
                root.gpuName = gpu.device_name || "";
                root.gpuUsage = parseFloat(gpu.gpu_util) || 0;
                root.gpuTemp = parseFloat(gpu.temp) || 0;
                root.gpuAvailable = true;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && !root.gpuAvailable)
                gpuTimer.running = false;
        }
    }

    Timer {
        id: gpuTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: gpuProc.running = true
    }

    // Vertical gauge: a track the height of the icon, filled from the bottom.
    component Gauge: Rectangle {
        property real ratio: 0
        property color fill: Theme.primary

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(3, Math.round(root.iconSize * 0.22))
        height: Math.round(root.iconSize * 0.85)
        radius: width / 2
        color: Theme.withAlpha(Theme.surfaceText, 0.18)

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * Math.max(0, Math.min(1, parent.ratio))
            radius: parent.radius
            color: parent.fill
        }
    }

    // Icons are Nerd Font glyphs, not Material Symbols: Material has no RAM or
    // GPU icon (memory_alt / developer_board were the nearest), Nerd has a
    // RAM stick and an expansion card. DMS bundles FiraCode Nerd Font for its
    // own StyledText; this loads the same file.
    FontLoader {
        id: nerdFont
        source: Qt.resolvedUrl("../../../assets/fonts/nerd-fonts/FiraCodeNerdFont-Regular.ttf")
    }

    component StatIcon: Text {
        font.family: nerdFont.name
        font.pixelSize: root.iconSize
        color: Theme.widgetIconColor
        anchors.verticalCenter: parent.verticalCenter
    }

    component StatText: StyledText {
        font.pixelSize: root.textSize
        anchors.verticalCenter: parent.verticalCenter
    }

    content: Component {
        Item {
            implicitWidth: stats.implicitWidth
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            Row {
                id: stats
                anchors.centerIn: parent
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StatIcon {
                        text: "\uf2db" // nf-fa-microchip
                    }
                    Gauge {
                        ratio: DgopService.cpuUsage / 100
                        fill: root.levelColor(DgopService.cpuUsage, 60, 80, Theme.primary)
                    }
                    StatText {
                        visible: DgopService.cpuTemperature > 0
                        text: Math.round(DgopService.cpuTemperature) + "°"
                        color: root.levelColor(DgopService.cpuTemperature, 69, 85, Theme.widgetTextColor)
                    }
                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StatIcon {
                        text: "\uefc5" // nf-fa-memory
                    }
                    Gauge {
                        ratio: DgopService.memoryUsage / 100
                        fill: root.levelColor(DgopService.memoryUsage, 75, 90, Theme.primary)
                    }
                }

                Row {
                    visible: root.gpuAvailable
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StatIcon {
                        text: "\udb82\udcae" // nf-md-expansion_card (U+F08AE)
                    }
                    Gauge {
                        ratio: root.gpuUsage / 100
                        fill: root.levelColor(root.gpuUsage, 60, 80, Theme.primary)
                    }
                    StatText {
                        visible: root.gpuTemp > 0
                        text: Math.round(root.gpuTemp) + "°"
                        color: root.levelColor(root.gpuTemp, 69, 85, Theme.widgetTextColor)
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
            DgopService.setSortBy("cpu");
            root.cpuClicked();
        }
    }
}
