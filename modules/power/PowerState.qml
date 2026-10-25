pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Opens the power menu from outside the shell, on the focused monitor:
//   qs -c config ipc call power toggle
Singleton {
    id: root

    // Each bar listens and toggles its own menu when the monitor is its screen.
    signal toggleRequested(string monitor)

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggleRequested(Hyprland.focusedMonitor?.name ?? "")
        }
    }
}
