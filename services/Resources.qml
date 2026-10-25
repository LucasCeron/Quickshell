pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// A light system sample for the System tab. It only runs while something uses it:
// call acquire() when shown and release() when hidden.
Singleton {
    id: root
    property int users: 0
    property var lastCpu: []
    property real cpu: 0
    property real memUsed: 0
    property real memTotal: 1
    property real diskUsed: 0
    property real diskTotal: 1
    property real cpuTemp: -1
    property bool hasGpu: false
    property real gpu: 0
    property real gpuTemp: -1

    function acquire(): void { users++; }
    function release(): void { users = Math.max(0, users - 1); }
    onUsersChanged: if (users === 0) lastCpu = []

    function formatBytes(bytes: real): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let value = bytes, unit = 0;
        while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++; }
        return value.toFixed(value >= 100 || unit === 0 ? 0 : 1) + " " + units[unit];
    }
    function parse(text: string): void {
        for (const line of text.trim().split("\n")) {
            const fields = line.trim().split(/\s+/);
            const values = fields.slice(1).map(Number);
            if (fields[0] === "cpu") {
                const idle = values[3] + values[4];
                const total = values.reduce((sum, value) => sum + value, 0);
                if (lastCpu.length === 2 && total > lastCpu[1])
                    cpu = 1 - (idle - lastCpu[0]) / (total - lastCpu[1]);
                lastCpu = [idle, total];
            } else if (fields[0] === "mem") {
                memUsed = values[0] * 1024; memTotal = Math.max(1, values[1] * 1024);
            } else if (fields[0] === "disk") {
                diskUsed = values[0]; diskTotal = Math.max(1, values[1]);
            } else if (fields[0] === "temp") {
                cpuTemp = values[0] / 1000;
            } else if (fields[0] === "gpu" && isFinite(values[0])) {
                hasGpu = true; gpu = values[0] / 100; gpuTemp = values[1];
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.users > 0
        onTriggered: sampler.running = true
    }
    Process {
        id: sampler
        command: ["sh", Quickshell.shellPath("services/resources.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }
}
