import "../../../common/theme" as Theme
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../services" as Services

Item {
    id: root

    required property var toplevel

    readonly property var desktopEntry:
        root.toplevel ? DesktopEntries.heuristicLookup(root.toplevel.appId) : null

    readonly property string iconName: {
        if (desktopEntry && desktopEntry.icon !== "")
            return desktopEntry.icon

        return root.toplevel ? root.toplevel.appId : ""
    }

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property bool active: root.toplevel !== null && root.toplevel.activated
    signal menuRequested()

    // Hover and the focus ring are drawn by the pill's CellHighlights.
    implicitWidth: 40
    implicitHeight: 40

    IconImage {
        anchors.centerIn: parent
        visible: root.toplevel !== null

        implicitSize: 23

        source: root.toplevel ? Quickshell.iconPath(
            root.iconName,
            "application-x-executable"
        ) : ""
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.toplevel === null
        width: 5
        height: 5
        radius: 2.5
        color: Theme.Colors.indicator
    }

    MouseArea {
        id: mouse

        anchors.fill: parent

        enabled: root.toplevel !== null
        hoverEnabled: true

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.menuRequested()
            else
                Services.Compositor.activate(root.toplevel)
        }
    }
}
