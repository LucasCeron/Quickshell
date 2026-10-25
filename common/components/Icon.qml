import QtQuick
import QtQuick.Effects
import "../theme" as Theme

Item {
    id: root
    property alias source: image.source
    property color color: Theme.Colors.accent
    implicitWidth: 24
    implicitHeight: 24

    Image {
        id: image
        anchors.fill: parent
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    MultiEffect {
        anchors.fill: image
        source: image
        colorization: 1
        colorizationColor: root.color
    }
}
