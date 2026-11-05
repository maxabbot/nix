// GPU usage and temperature for the bar's system monitor pill
// (BarSystemMonitor.qml) — not part of upstream DMS. modules/home/wm/dms.nix
// installs it into DMS's Services/, where `pragma Singleton` makes it one
// instance shared by every bar: with the poll inside the pill, each output's
// bar ran its own nvtop every 2 s.
//
// `nvtop -s` prints a one-shot JSON snapshot (~45 ms of CPU) and reads NVIDIA,
// AMD and Intel alike without root, so laptops get their integrated GPU.
// Polled every 2 s on mains and every 10 s on battery, and only while some
// pill holds a reference (addRef/removeRef, as DgopService does). With several
// GPUs the discrete one (NVIDIA/AMD by name) wins, else the first listed.
// Intel iGPUs report no temperature. If nvtop fails or lists nothing before it
// has ever succeeded, polling stops for the session and the segment stays
// hidden.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    property int refCount: 0
    property bool available: false
    property bool failed: false
    property string name: ""
    property real usage: 0
    property real temp: 0 // 0 = not reported

    readonly property bool onBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn

    function addRef() {
        refCount++;
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
    }

    Process {
        id: proc
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
                    if (!root.available)
                        root.failed = true;
                    return;
                }
                const gpu = gpus.find(g => /NVIDIA|AMD|Radeon/i.test(g.device_name || "")) || gpus[0];
                root.name = gpu.device_name || "";
                root.usage = parseFloat(gpu.gpu_util) || 0;
                root.temp = parseFloat(gpu.temp) || 0;
                root.available = true;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && !root.available)
                root.failed = true;
        }
    }

    Timer {
        interval: root.onBattery ? 10000 : 2000
        running: root.refCount > 0 && !root.failed
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!proc.running)
                proc.running = true;
        }
    }
}
