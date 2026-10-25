pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Services.Pipewire
import "../../../common/theme" as Theme
import "../../../common/components"

// Mute button, volume slider with a live level meter under it, and the percentage.
// Works for any PipeWire node: an output, an input or an app's stream.
Item {
    id: root
    property var node: null
    property string iconName: "volume.svg"
    property string mutedIconName: "volume-mute.svg"
    property bool metering: true
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property real volume: node?.audio?.volume ?? 0

    implicitHeight: 36
    opacity: node ? 1 : 0.4

    PwNodePeakMonitor {
        id: peaks
        node: root.node
        enabled: root.metering && root.visible && !!root.node
    }

    Rectangle {
        id: muteButton
        width: 36; height: 36; radius: 18
        anchors.verticalCenter: parent.verticalCenter
        color: root.muted ? Theme.Colors.alpha(Theme.Colors.danger, muteMouse.containsMouse ? 0.24 : 0.16)
            : muteMouse.containsMouse ? Theme.Colors.alpha(Theme.Colors.accent, 0.2) : Theme.Colors.alpha(Theme.Colors.accent, 0.12)
        Behavior on color { ColorAnimation { duration: 140 } }
        Icon {
            anchors.centerIn: parent
            width: 18; height: 18
            source: Quickshell.shellPath("common/assets/icons/" + (root.muted ? root.mutedIconName : root.iconName))
            color: root.muted ? Theme.Colors.danger : Theme.Colors.accent
        }
        MouseArea {
            id: muteMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !!root.node?.audio
            cursorShape: Qt.PointingHandCursor
            onClicked: root.node.audio.muted = !root.node.audio.muted
        }
        Controls.ToolTip.visible: muteMouse.containsMouse
        Controls.ToolTip.text: root.muted ? "Ativar som" : "Silenciar"
        Controls.ToolTip.delay: 600
    }

    Controls.Slider {
        id: slider
        anchors { left: muteButton.right; leftMargin: 12; right: percent.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: 28
        from: 0; to: 1; stepSize: 0.01
        value: root.volume
        enabled: !!root.node?.audio
        onMoved: if (root.node?.audio) root.node.audio.volume = value
        // Scrolling over it nudges the volume by 5%.
        WheelHandler {
            onWheel: event => {
                if (!root.node?.audio) return;
                const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
                root.node.audio.volume = Math.max(0, Math.min(1, root.volume + step));
            }
        }
        background: Item {
            x: slider.leftPadding
            width: slider.availableWidth
            height: slider.height
            Rectangle {
                id: track
                y: (parent.height - height) / 2 - 2
                width: parent.width; height: 6; radius: 3
                color: Theme.Colors.surfaceHigh
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height; radius: 3
                    color: root.muted ? Theme.Colors.textMuted : Theme.Colors.accent
                }
            }
            // Live level: how loud it is right now, under the volume.
            Rectangle {
                visible: root.metering
                anchors { top: track.bottom; topMargin: 4 }
                width: parent.width; height: 2; radius: 1
                color: Theme.Colors.alpha(Theme.Colors.textPrimary, 0.06)
                Rectangle {
                    height: parent.height; radius: 1
                    width: parent.width * Math.min(1, root.muted ? 0 : peaks.peak)
                    color: peaks.peak > 0.9 ? Theme.Colors.danger : Theme.Colors.alpha(Theme.Colors.accent, 0.7)
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2 - 2
            width: 16; height: 16; radius: 8
            color: slider.pressed ? Theme.Colors.accentHover : Theme.Colors.textPrimary
            border { width: 3; color: root.muted ? Theme.Colors.textMuted : Theme.Colors.accent }
            scale: slider.hovered || slider.pressed ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
        Accessible.name: "Volume"
    }

    Text {
        id: percent
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 38
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.volume * 100) + "%"
        color: root.muted ? Theme.Colors.textMuted : Theme.Colors.textPrimary
        font { pixelSize: 12; weight: Font.DemiBold; features: { "tnum": 1 } }
    }
}
