pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../services" as Services

Singleton {
    id: root
    property bool open: false
    property string screenName: ""
    function show(monitor: string): void {
        screenName = monitor || (Hyprland.focusedMonitor?.name ?? "");
        Services.Wallpapers.scan();
        open = true;
    }
    function toggle(monitor: string): void {
        if (open && (!monitor || monitor === screenName)) open = false;
        else show(monitor);
    }
    IpcHandler {
        target: "wallpapers"
        function status(): string { return JSON.stringify({ open: root.open, screen: root.screenName, count: Services.Wallpapers.items.length, message: Services.Wallpapers.message }); }
        function toggle(): void { root.toggle(""); }
        function close(): void { root.open = false; }
    }
}
