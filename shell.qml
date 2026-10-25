//@ pragma IconTheme breeze-dark
// Share the Breeze icon set with the launcher and GTK applications.
import QtQuick
import Quickshell
import "modules/bar"
import "modules/capture"
import "modules/overview"
import "modules/activity"
import "modules/gadgets"
import "modules/wallpapers"
import "modules/power"
import "modules/notifications"
import "modules/osd"
import "services" as Services

ShellRoot {
    id: root
    NotificationToasts {}
    SystemToasts {}
    // Load the services that only answer IPC, so their commands work from the start.
    readonly property var ipcServices: [Services.Idle, Services.Toaster]
    VolumeOsd {}

    // Every entry point (mouse or IPC) shares the same panel lifecycle.
    function closeOtherPanels(active: string): void {
        if (active !== "gadgets") GadgetsState.open = false;
        if (active !== "wallpapers") WallpapersState.open = false;
        if (active !== "capture") CaptureState.open = false;
        if (active !== "overview") OverviewState.open = false;
        if (active !== "activity") ActivityState.open = false;
    }
    Connections {
        target: GadgetsState
        function onOpenChanged(): void { if (GadgetsState.open) root.closeOtherPanels("gadgets"); }
    }
    Connections {
        target: WallpapersState
        function onOpenChanged(): void { if (WallpapersState.open) root.closeOtherPanels("wallpapers"); }
    }
    Connections {
        target: CaptureState
        function onOpenChanged(): void { if (CaptureState.open) root.closeOtherPanels("capture"); }
    }
    Connections {
        target: OverviewState
        function onOpenChanged(): void { if (OverviewState.open) root.closeOtherPanels("overview"); }
    }
    Connections {
        target: ActivityState
        function onOpenChanged(): void { if (ActivityState.open) root.closeOtherPanels("activity"); }
    }
    Connections {
        target: PowerState
        function onToggleRequested(monitor: string): void { root.closeOtherPanels("power"); }
    }

    // Catches clicks outside the open panel, on every screen.
    Variants {
        model: Quickshell.screens

        Scrim {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // A single pill, on the monitor that was focused when it opened.
    Capture {
        screen: Quickshell.screens.find(s => s.name === CaptureState.screenName) ?? Quickshell.screens[0]
    }

    Overview {
        screen: Quickshell.screens.find(s => s.name === OverviewState.screenName) ?? Quickshell.screens[0]
    }

    ActivityMonitor {
        screen: Quickshell.screens.find(s => s.name === ActivityState.screenName) ?? Quickshell.screens[0]
    }

    WallpaperDrawer {
        screen: Quickshell.screens.find(s => s.name === WallpapersState.screenName) ?? Quickshell.screens[0]
    }
}
