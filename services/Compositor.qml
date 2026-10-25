pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
Singleton {
    id: root
    readonly property var windows: ToplevelManager.toplevels.values.filter(window => window.title !== "Config Power Menu")
    // Hyprland's outer gap, so the bar and everything docked to it line up with the windows.
    property int gaps: 14
    // Emitted when the shell itself focuses a window, so focus indicators can skip their animation.
    signal activationRequested(var window)
    function activate(window: var): void { if (window) { activationRequested(window); window.activate(); } }
    Process {
        running: true
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const option = JSON.parse(this.text);
                    const value = parseInt(String(option.css ?? option.int ?? "").trim().split(/\s+/)[0]);
                    if (value >= 0) root.gaps = value;
                } catch (error) {}
            }
        }
    }
}
