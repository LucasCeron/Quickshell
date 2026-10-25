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
    property int tab: 2
    property int latestTab: 2
    readonly property int drawerWidth: 440
    // When a click outside closed the popup; a click on its own button right then
    // must not open it again.
    property real dismissedAt: 0
    property int dismissedTab: -1
    function dismiss(): void {
        dismissedAt = Date.now();
        dismissedTab = tab;
        open = false;
    }
    // Where windows docked to the sidebar start, clearing the drawer when it is open there.
    function dockLeft(monitor: string, barWidth: int): int {
        const gaps = Services.Compositor.gaps;
        return 2 * gaps + barWidth + (open && screenName === monitor ? drawerWidth + gaps : 0);
    }
    // System events update the compact pill, but never replace a page being used.
    function noteActivity(page: int): void {
        latestTab = page;
        if (!open) tab = page;
    }
    onOpenChanged: if (!open) tab = latestTab
    Connections {
        target: Services.Notices
        function onArrived(): void { root.noteActivity(0); }
    }
    Connections {
        target: Services.Media
        function onActivity(): void { root.noteActivity(2); }
    }
    // Pages: 0 notifications, 2 music, 3 tools (with themes and wallpapers), 4 system.
    // Themes (1) now live inside tools.
    function page(index: int): int {
        const clamped = Math.max(0, Math.min(4, index));
        return clamped === 1 ? 3 : clamped;
    }
    function show(monitor: string, page: int): void {
        screenName = monitor || (Hyprland.focusedMonitor?.name ?? "");
        tab = root.page(page);
        latestTab = tab;
        open = true;
    }
    // Sidebar buttons: open a page, or close the drawer when that page is already showing there.
    function toggleTab(monitor: string, page: int): void {
        if (open && tab === root.page(page) && monitor === screenName) open = false;
        else if (!open && dismissedTab === root.page(page) && Date.now() - dismissedAt < 300) return;
        else show(monitor, page);
    }
    function toggle(monitor: string): void {
        if (open && (!monitor || monitor === screenName)) open = false;
        else show(monitor, tab);
    }
    IpcHandler {
        target: "gadgets"
        function status(): string { return JSON.stringify({ open: root.open, tab: root.tab, screen: root.screenName }); }
        function toggle(): void { root.toggle(""); }
        function show(page: int): void { root.show("", page); }
        function notifications(): void { root.show("", 0); }
        function music(): void { root.show("", 2); }
        function themes(): void { root.show("", 3); }
        function bar(): void { root.show("", 3); }
        function tools(): void { root.show("", 3); }
        function system(): void { root.show("", 4); }
        function close(): void { root.open = false; }
    }
}
