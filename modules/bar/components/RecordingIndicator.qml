import "../../../common/theme" as Theme
import "../../capture"
import QtQuick

// Shown while a screen recording runs: pulsing dot and elapsed time. Click to stop.
Rectangle {
    id: root

    implicitWidth: 56
    implicitHeight: 56
    radius: 16

    color: mouse.containsMouse
        ? Theme.Colors.alpha(Theme.Colors.danger, 64 / 255)
        : Theme.Colors.alpha(Theme.Colors.danger, 36 / 255)
    border.width: 1
    border.color: Theme.Colors.alpha(Theme.Colors.danger, 128 / 255)
    Behavior on color {
        ColorAnimation { duration: Theme.Motion.fast }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 12
            height: 12
            radius: mouse.containsMouse ? 3 : 6
            color: Theme.Colors.danger

            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite

                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: {
                const seconds = CaptureState.elapsed
                const pad = n => String(n).padStart(2, "0")
                return pad(Math.floor(seconds / 60)) + ":" + pad(seconds % 60)
            }
            color: Theme.Colors.textPrimary

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 11
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: CaptureState.stop()
    }
}
