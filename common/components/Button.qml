import "../theme" as Theme
import QtQuick

Item {
    id: root

    property url source: ""
    property bool active: false
    property bool outlined: false
    // Draws no background of its own: a CellHighlight behind it shows hover and active.
    property bool bare: false
    property real radius: 14
    // Background while neither hovered nor active.
    property color restColor: "transparent"
    property color outlineColor: Theme.Colors.alpha(Theme.Colors.accent, 96/255)

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal triggered()

    implicitWidth: 44
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        visible: !root.bare

        radius: root.radius
        border.width: root.outlined || root.active ? 1 : 0
        border.color: root.active ? Theme.Colors.alpha(Theme.Colors.accent, 128/255) : root.outlineColor

        color: {
            if (root.active)
                return Theme.Colors.alpha(Theme.Colors.accent, 40/255)

            if (mouse.containsMouse)
                return Theme.Colors.alpha(Theme.Colors.accent, 36/255)

            return root.restColor
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.Motion.fast
            }
        }
    }

    Icon {
        anchors.centerIn: parent

        width: 22
        height: 22

        source: root.source

    }

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.triggered()
    }
}
