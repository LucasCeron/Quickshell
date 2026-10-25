import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config" as Config
import "../../services" as Services
import "../wallpapers"
import "../activity"

// Invisible layer under the wallpapers and activity panels: a click anywhere
// outside closes them. (Sidebar pages are popups and close on their own.)
// It leaves out the sidebar, whose buttons open and close the panels themselves.
PanelWindow {// qmllint disable uncreatable-type
    id: root

    readonly property bool panelOpen: WallpapersState.open || ActivityState.open

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: panelOpen
    WlrLayershell.namespace: "config-scrim"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: everything
        Region {
            item: sidebar
            intersection: Intersection.Subtract
        }
    }

    Item { id: everything; anchors.fill: parent }
    Item {
        id: sidebar
        x: 0; y: 0
        width: Services.Compositor.gaps + Config.Settings.barWidth + 8
        height: parent.height
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: {
            WallpapersState.open = false;
            ActivityState.hide();
        }
    }
}
