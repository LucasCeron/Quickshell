pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config

Singleton {
    id: root
    property var items: []
    property string message: ""
    property bool failed: false
    readonly property bool scanning: scanner.running
    readonly property bool applying: setter.running
    property int restoreAttempts: 0
    property bool scanPending: false

    function scan(): void {
        if (scanner.running) { scanPending = true; return; }
        scanPending = false;
        scanner.command = ["python3", Quickshell.shellPath("scripts/wallpapers.py"), "scan", Config.Settings.wallpaperFolder];
        scanner.running = true;
    }
    function apply(path: string): void {
        if (setter.running) return;
        message = "Aplicando wallpaper…";
        failed = false;
        setter.command = ["python3", Quickshell.shellPath("scripts/wallpapers.py"), "apply", path];
        setter.running = true;
    }
    Process {
        id: scanner
        onRunningChanged: if (!running && root.scanPending) Qt.callLater(root.scan)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.items = result.items || [];
                    root.message = result.error || "";
                    root.failed = !!result.error;
                } catch (error) { root.message = "Não foi possível ler a pasta."; root.failed = true; }
            }
        }
    }
    Process {
        id: setter
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.failed = !!result.error;
                    root.message = result.error || "Wallpaper aplicado em todas as telas.";
                    if (!result.error) Config.Settings.wallpaperPath = result.path;
                } catch (error) { root.message = "Não foi possível aplicar o wallpaper."; root.failed = true; }
                if (root.failed && root.restoreAttempts > 0 && root.restoreAttempts < 3) restore.restart();
                else root.restoreAttempts = 0;
            }
        }
    }
    // Give Hyprpaper time to start at login before restoring the last selection.
    Timer {
        id: restore
        interval: 2000
        onTriggered: {
            root.restoreAttempts++;
            root.apply(Config.Settings.wallpaperPath);
        }
    }
    function initialize(): void {
        scan();
        if (Config.Settings.wallpaperPath) restore.restart();
    }
    Component.onCompleted: { if (Config.Settings.ready) initialize(); }
    Connections {
        target: Config.Settings
        function onReadyChanged(): void { if (Config.Settings.ready) root.initialize(); }
    }
}
