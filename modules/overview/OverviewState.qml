pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Workspace overview, opened from the top bar or through IPC:
//   qs -c config ipc call overview toggle
Singleton {
    id: root

    property bool open: false
    property string screenName: ""

    function show(monitor: string): void {
        screenName = monitor || (Hyprland.focusedMonitor?.name ?? "")
        // Window positions in the previews come from the last IPC snapshot.
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        open = true
    }

    function hide(): void {
        open = false
    }

    function toggle(monitor: string): void {
        if (open)
            hide()
        else
            show(monitor)
    }

    IpcHandler {
        target: "overview"

        function toggle(): void { root.toggle("") }
    }
}
