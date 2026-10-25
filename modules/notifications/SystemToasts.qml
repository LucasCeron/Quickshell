pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services" as Services
import "../../common/theme" as Theme
import "../../common/components"
import "../../config" as Config
import "../gadgets"

// Messages from the shell itself, docked beside the bottom of the sidebar.
PanelWindow {// qmllint disable uncreatable-type
    id: root
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { bottom: true; left: true }
    margins { bottom: Services.Compositor.gaps; left: GadgetsState.dockLeft(screen?.name ?? "", Config.Settings.barWidth) } // qmllint disable unqualified unresolved-type
    implicitWidth: 320
    implicitHeight: Math.max(1, stack.implicitHeight)
    visible: Services.Toaster.toasts.length > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "config-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: stack
        width: parent.width
        spacing: 8
        // Newest at the bottom, next to the corner.
        Repeater {
            model: ScriptModel { values: Services.Toaster.toasts.slice().reverse() }
            delegate: Rectangle {
                id: toast
                required property var modelData
                width: stack.width
                height: 60
                radius: 18
                color: Theme.Colors.alpha(Theme.Colors.popup, 0.97)
                border { width: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 0.25) }
                opacity: 0
                transform: Translate { id: shift; x: -16 }
                Component.onCompleted: entrance.start()
                ParallelAnimation {
                    id: entrance
                    NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 180 }
                    NumberAnimation { target: shift; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }
                MouseArea { anchors.fill: parent; onClicked: Services.Toaster.hide(toast.modelData.id) }
                Rectangle {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 18
                    color: Theme.Colors.alpha(Theme.Colors.accent, 0.14)
                    Icon {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: Quickshell.shellPath("common/assets/icons/" + toast.modelData.icon)
                    }
                }
                Column {
                    x: 60; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 74
                    spacing: 2
                    Text {
                        width: parent.width
                        text: toast.modelData.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.textPrimary
                        font { pixelSize: 13; weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.modelData.body
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.textMuted
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
