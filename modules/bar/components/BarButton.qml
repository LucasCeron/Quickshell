import "../../../common/theme" as Theme
import QtQuick
import Quickshell

Rectangle {
    id: root

    property string icon: ""
    property var command: []
    property bool active: false

    signal triggered()

    width: 48
    height: 48

    radius: 16

    color: {
        if (root.active)
            return Theme.Colors.alpha(Theme.Colors.primary, 56/255)

        if (mouse.containsMouse)
            return Theme.Colors.alpha(Theme.Colors.surface, 56/255)

        return "transparent"
    }

    Text {
        anchors.centerIn: parent

        text: root.icon
        color: Theme.Colors.primary

        font {
            family: Theme.Typography.monoFamily
            pixelSize: 22
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.triggered()

            if (root.command.length > 0) {
                Quickshell.execDetached(root.command)
            }
        }
    }
}
