import QtQuick
import QtQuick.Controls
import "../../../common/theme" as Theme

Slider {
    id: root
    implicitHeight: 28
    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 5
        radius: 3
        color: Theme.Colors.surfaceHigh
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: Theme.Colors.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: root.pressed ? Theme.Colors.accentHover : Theme.Colors.accent
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.Colors.textPrimary
    }
}
