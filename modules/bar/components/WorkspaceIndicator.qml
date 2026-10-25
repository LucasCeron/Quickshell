import "../../../common/theme" as Theme
import QtQuick
import Quickshell.Hyprland

// Number of the workspace shown on this bar's monitor, drawn inside a small
// screen. The number rolls in the direction of the change; scrolling over it
// moves to the next or previous workspace, clicking emits `clicked`.
Item {
    id: root

    required property var screen
    // Width of the little screen; its height and the number follow.
    property real displayWidth: 30

    readonly property int current: Hyprland.monitorFor(root.screen)?.activeWorkspace?.id ?? 1
    property int shown: current
    // 1 when moving to a higher workspace, -1 to a lower one.
    property int direction: 1

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked()

    implicitWidth: 44
    implicitHeight: 44

    onCurrentChanged: {
        direction = current > shown ? 1 : -1
        roll.restart()
    }

    SequentialAnimation {
        id: roll

        ParallelAnimation {
            NumberAnimation { target: label; property: "offset"; to: -10 * root.direction; duration: 110; easing.type: Easing.InCubic }
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: 110 }
        }
        ScriptAction { script: root.shown = root.current }
        PropertyAction { target: label; property: "offset"; value: 10 * root.direction }
        ParallelAnimation {
            NumberAnimation { target: label; property: "offset"; to: 0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: label; property: "opacity"; to: 1; duration: 160 }
        }
    }

    // The screen and its stand, centred together.
    Item {
        id: glyph

        anchors.centerIn: parent
        width: display.width
        height: display.height + 3 + 1.6
    }

    Rectangle {
        id: display

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: glyph.top

        width: root.displayWidth
        height: Math.round(root.displayWidth * 0.73)
        radius: root.displayWidth / 6
        color: "transparent"
        border.width: 1.6
        border.color: Theme.Colors.accent
        // The number rolls out of sight at the screen's edge.
        clip: true

        Text {
            id: label

            property real offset: 0

            anchors.centerIn: parent
            anchors.verticalCenterOffset: offset

            text: root.shown
            color: Theme.Colors.accent

            font {
                family: Theme.Typography.monoFamily
                pixelSize: Math.round(root.displayWidth * 0.43)
                weight: Font.DemiBold
            }
        }
    }

    // The stand.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: display.bottom
        anchors.topMargin: 3

        width: root.displayWidth * 0.4
        height: 1.6
        radius: height / 2
        color: Theme.Colors.accent
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
        onWheel: wheel => {
            const step = wheel.angleDelta.y < 0 ? "e+1" : "e-1"
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${step}" })`)
        }
    }
}
