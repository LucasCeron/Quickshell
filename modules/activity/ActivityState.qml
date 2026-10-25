pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../config" as Config

// The activity monitor panel, opened from the top bar or through IPC:
//   qs -c config ipc call activity toggle
// It can also hand over to btop in a terminal, which a Hyprland window rule
// floats along the right side of the screen.
Singleton {
    id: root

    property bool open: false
    property string screenName: ""

    function show(monitor: string): void {
        screenName = monitor || (Hyprland.focusedMonitor?.name ?? "")
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

    function openBtop(): void {
        open = false
        // Ghostty takes the Wayland app id from --class, which must look like a GTK application id.
        Quickshell.execDetached([Config.Settings.terminalCommand, "--class=config.activity", "-e", "btop"])
    }

    IpcHandler {
        target: "activity"

        function toggle(): void { root.toggle("") }
    }
}
