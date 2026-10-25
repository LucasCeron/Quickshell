pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Options and the running job of the capture pill. Opened through IPC:
//   qs -c config ipc call capture toggle
Singleton {
    id: root

    readonly property var modes: [
        { key: "screen", label: "Capturar a tela inteira", icon: "common/assets/icons/capture-screen.svg" },
        { key: "window", label: "Capturar a janela selecionada", icon: "common/assets/icons/capture-window.svg" },
        { key: "area", label: "Capturar a área selecionada", icon: "common/assets/icons/capture-area.svg" },
        { key: "rec-screen", label: "Gravar a tela inteira", icon: "common/assets/icons/record-screen.svg" },
        { key: "rec-area", label: "Gravar a área selecionada", icon: "common/assets/icons/record-area.svg" }
    ]

    property bool open: false
    property string screenName: ""

    property string mode: "area"
    property string destination: "both" // both | copy | save
    property int delay: 0
    property string audio: "none" // none | system | mic
    property bool cursor: false

    readonly property bool recordMode: mode.startsWith("rec-")
    readonly property bool busy: job.running
    property bool recording: false
    property int elapsed: 0

    // While recording the pill still opens, offering to stop it.
    function show(monitor: string): void {
        if (busy && !recording)
            return
        screenName = monitor || (Hyprland.focusedMonitor?.name ?? "")
        open = true
    }

    function hide(): void {
        open = false
    }

    function toggle(): void {
        if (open)
            hide()
        else
            show("")
    }

    function capture(): void {
        open = false
        if (recording) {
            stop()
            return
        }
        if (busy)
            return

        const script = Quickshell.shellPath("modules/capture/capture.sh")
        const target = mode.replace("rec-", "")
        job.command = recordMode
            ? [script, "rec", target, screenName, audio, String(delay)]
            : [script, "shot", target, screenName, destination, String(delay), cursor ? "1" : "0"]
        job.running = true
    }

    function stop(): void {
        if (job.running)
            job.signal(2) // SIGINT: the script finishes the file before exiting
    }

    Process {
        id: job

        stdout: SplitParser {
            onRead: line => {
                if (line !== "recording")
                    return
                root.elapsed = 0
                root.recording = true
            }
        }

        onRunningChanged: {
            if (!running)
                root.recording = false
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed++
    }

    IpcHandler {
        target: "capture"

        function toggle(): void { root.toggle() }
        function stop(): void { root.stop() }
    }
}
