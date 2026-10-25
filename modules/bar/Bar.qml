pragma ComponentBehavior: Bound
import "components"
import "../../common/components"
import "../power"
import "../controlcenter"
import "../network"
import "../capture"
import "../overview"
import "../launcher" as Launcher
import "../gadgets"
import "../activity"
import "../wallpapers"
import "../../services" as Services
import "../../config" as Config

import "../../common/theme" as Theme
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {// qmllint disable uncreatable-type
    id: root

    BarState {
        id: state
        // A popup of the bar replaces any open panel instead of opening under it.
        onActivePopupChanged: {
            if (activePopup === "")
                return;
            GadgetsState.open = false;
            WallpapersState.open = false;
            ActivityState.hide();
        }
    }

    Connections {
        target: PowerState

        function onToggleRequested(monitor: string): void {
            if (root.screen && root.screen.name === monitor)
                state.toggle("power");
        }
    }
    readonly property bool drawerHere: GadgetsState.open && GadgetsState.screenName === (screen?.name ?? "")
    function openPage(page: int): void {
        state.close();
        GadgetsState.toggleTab(screen?.name ?? "", page);
    }
    // As tall as a maximized window: the same outer gap on every side.
    function openAppMenu(toplevel: var, button: Item): void {
        appMenu.toplevel = toplevel;
        menuAnchor.y = button.mapToItem(bar, 0, button.height / 2).y;
        state.open("menu");
    }
    // The focused window's menu from the keyboard, like a window manager's window menu.
    IpcHandler {
        target: "appmenu"
        enabled: root.screen?.name === Hyprland.focusedMonitor?.name
        function open(): void {
            const button = runningApps.appButtons.find(item => item?.active);
            if (button) root.openAppMenu(button.toplevel, button);
        }
        function close(): void { if (state.menuOpen) state.close(); }
    }
    IpcHandler {
        target: "network"
        enabled: root.screen?.name === Hyprland.focusedMonitor?.name
        function toggle(): void { state.toggle("network"); }
    }
    IpcHandler {
        target: "audio"
        enabled: root.screen?.name === Hyprland.focusedMonitor?.name
        function toggle(): void { state.toggle("audio"); }
    }
    anchors { top: true; bottom: true; left: true }
    margins { top: Services.Compositor.gaps; bottom: Services.Compositor.gaps; left: Services.Compositor.gaps } // qmllint disable unqualified unresolved-type

    implicitWidth: Config.Settings.barWidth + 16
    // Hyprland adds its gap after this, so windows sit one gap away from the bar.
    exclusiveZone: Config.Settings.barWidth
    color: "transparent"

    mask: Region {
        item: bar
        radius: bar.radius
    }

    // One bar as tall as a maximized window: search and the open apps on top;
    // the controls, the clock and power at the bottom.
    Rectangle {
        id: bar

        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        width: Config.Settings.barWidth
        x: 0

        radius: Config.Settings.barRadius
        color: Theme.Colors.alpha(Theme.Colors.sidebar, Config.Settings.barOpacity)
        border.width: 1
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 36 / 255)

        Button {
            id: searchButton
            y: 20
            anchors.horizontalCenter: parent.horizontalCenter
            // Darker than the bar and outlined like the apps pill below it.
            restColor: Theme.Colors.pill
            outlined: true
            outlineColor: Theme.Colors.alpha(Theme.Colors.accent, 36 / 255)
            width: 48
            height: 48
            radius: 18
            source: Quickshell.shellPath("common/assets/icons/Search.svg")
            onTriggered: Launcher.LauncherState.launch()
        }

        RunningAppsPill {
            id: runningApps
            anchors.horizontalCenter: parent.horizontalCenter
            y: searchButton.y + searchButton.height + 24
            availableHeight: Math.max(56, controlsColumn.y - 24 - y)
            onOverflowTriggered: state.toggle("apps")
            onMenuRequested: (toplevel, button) => root.openAppMenu(toplevel, button)
        }

        CellHighlight {
            anchors.fill: parent

            items: [noticesButton, musicButton, systemButton, toolsButton, wifiButton, audioButton, powerButton]
            restIndex: root.drawerHere ? [0, -1, 1, 3, 2][GadgetsState.tab] : state.networkOpen ? 4 : state.audioOpen ? 5 : state.powerOpen ? 6 : -1
        }

        Column {
            id: controlsColumn
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            RecordingIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: CaptureState.recording
            }

            // Each of these opens its page in the drawer next to the bar.
            Button {
                id: noticesButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                source: Quickshell.shellPath("common/assets/icons/bell.svg")
                onTriggered: root.openPage(0)
                Rectangle {
                    visible: Services.Notices.count > 0
                    anchors { right: parent.right; top: parent.top; rightMargin: 4; topMargin: 4 }
                    width: Math.max(16, countLabel.implicitWidth + 8); height: 16; radius: 8
                    color: Services.Notices.doNotDisturb ? Theme.Colors.surfaceHigh : Theme.Colors.accent
                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: Services.Notices.count > 99 ? "99+" : Services.Notices.count
                        color: Services.Notices.doNotDisturb ? Theme.Colors.textSecondary : Theme.Colors.background
                        font { pixelSize: 9; weight: Font.Bold }
                    }
                }
            }

            Button {
                id: musicButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                source: Quickshell.shellPath("common/assets/icons/music.svg")
                onTriggered: root.openPage(2)
                Rectangle {
                    visible: Services.Media.playing
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
                    width: 4; height: 4; radius: 2
                    color: Theme.Colors.accent
                    SequentialAnimation on opacity {
                        running: Services.Media.playing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
            }

            Button {
                id: systemButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                source: Quickshell.shellPath("common/assets/icons/gauge.svg")
                onTriggered: root.openPage(4)
                Rectangle {
                    visible: Services.Idle.inhibited
                    anchors { right: parent.right; top: parent.top; rightMargin: 6; topMargin: 6 }
                    width: 6; height: 6; radius: 3
                    color: Theme.Colors.accent
                }
            }

            Button {
                id: toolsButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                source: Quickshell.shellPath("common/assets/icons/sliders.svg")
                onTriggered: root.openPage(3)
            }

            Button {
                id: wifiButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                // Cable, Wi-Fi with its signal, or nothing.
                source: Quickshell.shellPath("common/assets/icons/" + Services.Network.iconName)
                active: state.networkOpen
                onTriggered: state.toggle("network")
            }

            Button {
                id: audioButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                source: Quickshell.shellPath("common/assets/icons/volume.svg")
                active: state.audioOpen
                onTriggered: state.toggle("audio")
            }

            Divider {}

            ClockBlock {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Config.Settings.showClock
            }

            Divider {
                visible: Config.Settings.showClock
            }

            Button {
                id: powerButton
                bare: true
                anchors.horizontalCenter: parent.horizontalCenter
                source: Quickshell.shellPath("common/assets/icons/power.svg")
                active: state.powerOpen
                onTriggered: state.toggle("power")
            }
        }
    }

    component Divider: Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 28
        height: 1
        color: Theme.Colors.alpha(Theme.Colors.accent, 64 / 255)
    }

    // Keep the horizontal position outside the rail and follow each trigger's height.
    Item {
        id: audioAnchor
        x: Config.Settings.barWidth
        y: controlsColumn.y + audioButton.y + audioButton.height / 2
        width: 1
        height: 1
    }

    // The button of the open page, where its popup comes out.
    Item {
        id: pageAnchor
        readonly property Item button: [noticesButton, toolsButton, musicButton, toolsButton, systemButton][GadgetsState.tab]
        x: Config.Settings.barWidth
        y: controlsColumn.y + button.y + button.height / 2
        width: 1
        height: 1
    }

    Gadgets {
        anchorItem: pageAnchor
        screenName: root.screen?.name ?? ""
        screenHeight: root.screen?.height ?? 1080
    }

    Item {
        id: networkAnchor
        x: Config.Settings.barWidth
        y: controlsColumn.y + wifiButton.y + wifiButton.height / 2
        width: 1
        height: 1
    }

    Item {
        id: menuAnchor
        x: Config.Settings.barWidth
        width: 1
        height: 1
    }

    Item {
        id: appsAnchor
        x: Config.Settings.barWidth
        y: runningApps.y + runningApps.overflowButton.mapToItem(runningApps, 0, 0).y + runningApps.overflowButton.height / 2
        width: 1
        height: 1
    }

    ControlCenter {
        id: audioPopup

        anchorItem: audioAnchor

        visible: state.audioOpen

        onVisibleChanged: {
            if (!visible && state.audioOpen)
                state.dismiss("audio");
        }
    }

    NetworkPopup {
        anchorItem: networkAnchor
        visible: state.networkOpen

        onVisibleChanged: {
            if (!visible && state.networkOpen)
                state.dismiss("network");
        }
    }

    AppMenu {
        id: appMenu

        anchorItem: menuAnchor
        visible: state.menuOpen
        onDismissed: state.close()

        onVisibleChanged: {
            if (!visible && state.menuOpen)
                state.dismiss("menu");
        }
    }

    AppsPopup {
        id: appsPopup

        anchorItem: appsAnchor
        windows: runningApps.hiddenWindows
        onDismissed: state.close()

        visible: state.appsOpen

        onVisibleChanged: {
            if (!visible && state.appsOpen)
                state.dismiss("apps");
        }
    }

    Power {
        id: powerPopup

        screen: root.screen
        onDismissed: state.close()

        visible: state.powerOpen

        onVisibleChanged: {
            if (!visible && state.powerOpen)
                state.close();
        }
    }
}
