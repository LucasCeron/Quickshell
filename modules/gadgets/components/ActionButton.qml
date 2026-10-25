import QtQuick
import QtQuick.Controls
import "../../../common/theme" as Theme
import "../../../common/components" as Common

Button {
    id: root
    property bool selected: false
    property bool prominent: false
    property string hint: ""
    // An svg from common/assets/icons, shown before the text (or alone when there is none).
    property url iconSource: ""
    property int iconSize: 16
    property real radius: 12
    readonly property bool hasIcon: iconSource.toString() !== ""
    readonly property real iconSpace: hasIcon ? iconSize + (text !== "" ? content.spacing : 0) : 0
    readonly property color foreground: root.prominent ? Theme.Colors.background : root.selected ? Theme.Colors.accent : Theme.Colors.textPrimary
    implicitHeight: 40
    implicitWidth: Math.max(implicitHeight, iconSpace + (text !== "" ? label.implicitWidth : 0) + 24)
    padding: 12
    hoverEnabled: true
    opacity: enabled ? 1 : 0.38
    contentItem: Item {
        implicitWidth: root.iconSpace + (root.text !== "" ? label.implicitWidth : 0)
        implicitHeight: content.implicitHeight
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8
            Common.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconSize; height: root.iconSize
                visible: root.hasIcon
                source: root.iconSource
                color: root.foreground
            }
            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.availableWidth - root.iconSpace)
                visible: text !== ""
                text: root.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: root.foreground
                elide: Text.ElideRight
            }
        }
    }
    background: Rectangle {
        radius: root.radius
        color: root.prominent ? (root.hovered ? Theme.Colors.accentHover : Theme.Colors.accent)
            : root.selected ? Theme.Colors.alpha(Theme.Colors.accent, 0.15)
            : root.hovered ? Theme.Colors.surfaceHigh : Theme.Colors.surface
        border.width: root.selected || root.activeFocus ? 1 : 0
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 0.6)
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    ToolTip.visible: hovered && hint !== ""
    ToolTip.text: hint
    ToolTip.delay: 600
    Accessible.name: hint || text
}
