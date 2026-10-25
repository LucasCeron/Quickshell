import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services" as Services
import "../../common/theme" as Theme
import "../../common/components"
import "../../config" as Config
import "../gadgets"

PanelWindow {// qmllint disable uncreatable-type
    id: root
    // Beside the volume button at the bottom of the sidebar.
    anchors { bottom: true; left: true }
    margins { bottom: Services.Compositor.gaps + Services.Toaster.toasts.length * 68; left: GadgetsState.dockLeft(screen?.name ?? "", Config.Settings.barWidth) } // qmllint disable unqualified unresolved-type
    implicitWidth: 300
    implicitHeight: 68
    color: "transparent"
    property real reveal: hold.running ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
    visible: reveal > 0
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.namespace: "config-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function showVolume(): void {
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        hold.restart();
    }
    Timer { id: hold; interval: 1600 }
    Connections {
        target: Services.Audio
        function onLevelChanged(): void { root.showVolume(); }
    }
    IpcHandler {
        target: "osd"
        function volume(): void { root.showVolume(); }
    }
    Rectangle {
        width: parent.width; height: parent.height
        x: -(1 - root.reveal) * 16
        opacity: root.reveal
        radius: 22
        color: Theme.Colors.alpha(Theme.Colors.popup, 0.97)
        border { width: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 0.25) }
        Icon {
            x: 20; anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            source: Quickshell.shellPath("common/assets/icons/volume.svg")
            color: Services.Audio.muted ? Theme.Colors.textMuted : Theme.Colors.accent
        }
        Column {
            x: 60; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 80
            spacing: 9
            Item {
                width: parent.width; height: 16
                Text { text: Services.Audio.muted ? "Silenciado" : "Volume"; color: Theme.Colors.textPrimary; font.pixelSize: 12 }
                Text {
                    anchors.right: parent.right
                    text: Math.round(Services.Audio.volume * 100) + "%"
                    color: Theme.Colors.accent; font.pixelSize: 12
                }
            }
            Rectangle {
                width: parent.width; height: 5; radius: 3
                color: Theme.Colors.surfaceHigh
                Rectangle {
                    height: parent.height; radius: 3
                    width: parent.width * (Services.Audio.muted ? 0 : Math.min(1, Services.Audio.volume))
                    color: Theme.Colors.accent
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
        }
    }
}
