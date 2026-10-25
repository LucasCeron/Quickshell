pragma ComponentBehavior: Bound

import "../../common/theme" as Theme

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Live previews of the workspaces across the top of the screen, over a dimmed
// overlay like the power menu. There is nothing to confirm: the arrows, the
// wheel and the number keys switch workspace right away, and the selected
// preview is always the active one (strong ring). Hovering shows a faint ring.
PanelWindow {// qmllint disable uncreatable-type
    id: root

    readonly property var monitor: Hyprland.monitorFor(root.screen)
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(workspace => workspace.id > 0)
        .sort((a, b) => a.id - b.id)
    readonly property int currentIndex: workspaces.indexOf(monitor?.activeWorkspace ?? null)

    // Window positions are in layout coordinates; the monitor size is in pixels.
    readonly property real monitorX: monitor?.x ?? 0
    readonly property real monitorY: monitor?.y ?? 0
    readonly property real monitorWidth: monitor ? monitor.width / monitor.scale : 1920
    readonly property real monitorHeight: monitor ? monitor.height / monitor.scale : 1080

    readonly property real cardWidth: 300
    readonly property real cardHeight: Math.round(cardWidth * monitorHeight / monitorWidth)
    readonly property real thumbScale: cardWidth / monitorWidth
    readonly property real gap: 28
    // Room around the cards for the rings and the press bounce.
    readonly property real bleed: 8

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: OverviewState.open

    WlrLayershell.namespace: "config-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (!visible)
            return

        overlay.forceActiveFocus()
        entrance.restart()

        for (let i = 0; i < cards.count; i++)
            (cards.itemAt(i) as WorkspaceCard)?.enter()
    }

    function move(step) {
        const count = root.workspaces.length
        if (count > 0)
            root.workspaces[(Math.max(0, root.currentIndex) + step + count) % count].activate()
    }

    // Keeps the selected preview in view when there are more than fit.
    onCurrentIndexChanged: {
        const card = cards.itemAt(root.currentIndex)
        if (!card)
            return

        const left = card.x
        const right = card.x + card.width + 2 * root.bleed
        let target = strip.contentX
        if (left < strip.contentX)
            target = left
        else if (right > strip.contentX + strip.width)
            target = right - strip.width

        scroll.to = Math.max(0, Math.min(target, strip.contentWidth - strip.width))
        scroll.restart()
    }

    Item {
        id: overlay

        anchors.fill: parent
        focus: true
        opacity: 0

        NumberAnimation {
            id: entrance

            target: overlay
            property: "opacity"
            from: 0
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                OverviewState.hide()
                break
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                root.move(-1)
                break
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Tab:
                root.move(1)
                break
            default: {
                const workspace = root.workspaces.find(workspace => String(workspace.id) === event.text)
                if (!workspace)
                    return
                workspace.activate()
            }
            }
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0; color: Theme.Colors.alpha(Theme.Colors.background, 235 / 255) }
                GradientStop { position: 1; color: Theme.Colors.alpha(Theme.Colors.shadow, 215 / 255) }
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: OverviewState.hide()
            onWheel: wheel => root.move(wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0 ? 1 : -1)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 48

            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: "Áreas de trabalho"
                color: Theme.Colors.textSecondary

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 13
                }
            }

            Flickable {
                id: strip

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(contentWidth, overlay.width - 96)
                height: contentHeight

                contentWidth: stage.width
                contentHeight: stage.height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                NumberAnimation {
                    id: scroll

                    target: strip
                    property: "contentX"
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                Item {
                    id: stage

                    width: cardRow.width + 2 * root.bleed
                    height: root.cardHeight + 2 * root.bleed + 34

                    Row {
                        id: cardRow

                        x: root.bleed
                        y: root.bleed
                        spacing: root.gap

                        Repeater {
                            id: cards

                            model: root.workspaces

                            WorkspaceCard {}
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56

            text: "←  →  trocar     1–9  ir direto     ⏎ / esc  fechar"
            color: Theme.Colors.textMuted

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 13
            }
        }
    }

    // A workspace in miniature: each window where it sits, showing its live contents.
    component WorkspaceCard: Item {
        id: card

        required property var modelData
        required property int index

        readonly property bool hovered: mouse.containsMouse
        readonly property bool pressed: mouse.pressed
        readonly property bool selected: root.currentIndex === index

        function enter() {
            reveal.restart()
        }

        width: root.cardWidth
        height: root.cardHeight

        SequentialAnimation {
            id: reveal

            PropertyAction { target: body; property: "opacity"; value: 0 }
            PropertyAction { target: body; property: "y"; value: -24 }
            PauseAnimation { duration: 30 + card.index * 45 }

            ParallelAnimation {
                NumberAnimation { target: body; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
                NumberAnimation { target: body; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }
        }

        Item {
            id: body

            width: card.width
            height: card.height

            scale: card.pressed ? 0.96 : 1
            Behavior on scale {
                SpringAnimation { spring: 4.5; damping: 0.28; epsilon: 0.002 }
            }

            // Faint while hovered, strong on the active workspace.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5

                radius: 18
                color: card.selected ? Theme.Colors.alpha(Theme.Colors.accent, 22 / 255) : "transparent"
                border.width: card.selected ? 2.5 : 1.5
                border.color: card.selected ? Theme.Colors.primary : Theme.Colors.alpha(Theme.Colors.primary, 90 / 255)
                opacity: card.selected || card.hovered ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }
            }

            ClippingRectangle {
                anchors.fill: parent

                radius: 13
                color: Theme.Colors.alpha(Theme.Colors.surface, 220 / 255)

                Repeater {
                    model: card.modelData.toplevels.values

                    WindowThumb {}
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 12

                text: card.modelData.id
                color: card.selected ? Theme.Colors.powerLabel : Theme.Colors.textSecondary
                opacity: card.selected ? 1 : 0.6
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 14
                    bold: card.selected
                }
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                card.modelData.activate()
                OverviewState.hide()
            }
        }
    }

    component WindowThumb: Item {
        id: thumb

        required property var modelData

        readonly property var ipc: modelData.lastIpcObject
        readonly property var appId: modelData.wayland?.appId ?? ""
        readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null

        visible: ipc && ipc.at !== undefined && ipc.size !== undefined
        x: visible ? (ipc.at[0] - root.monitorX) * root.thumbScale : 0
        y: visible ? (ipc.at[1] - root.monitorY) * root.thumbScale : 0
        width: visible ? ipc.size[0] * root.thumbScale : 0
        height: visible ? ipc.size[1] * root.thumbScale : 0

        ClippingRectangle {
            anchors.fill: parent
            radius: 4
            color: Theme.Colors.surfaceHigh

            ScreencopyView {
                id: capture

                anchors.fill: parent
                captureSource: OverviewState.open ? thumb.modelData.wayland : null
                live: true
            }

            // Until a frame arrives, or for windows that cannot be captured.
            IconImage {
                anchors.centerIn: parent
                visible: !capture.hasContent
                implicitSize: Math.min(28, thumb.width * 0.5, thumb.height * 0.5)
                source: Quickshell.iconPath(thumb.entry?.icon ?? thumb.appId, "application-x-executable")
            }
        }
    }
}
