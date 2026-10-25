pragma ComponentBehavior: Bound

import "../../common/components"
import "../../common/theme" as Theme

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Fullscreen overlay on the layer-shell: no compositor-specific window rules needed.
PanelWindow {// qmllint disable uncreatable-type
    id: root

    signal dismissed()

    property int currentIndex: 0

    readonly property var actions: [
        { label: "Desligar", key: "P", icon: "common/assets/icons/power.svg", command: ["systemctl", "poweroff"] },
        { label: "Bloquear", key: "L", icon: "common/assets/icons/lock.svg", command: ["bash", Quickshell.shellPath("scripts/lock.sh")] },
        { label: "Reiniciar", key: "R", icon: "common/assets/icons/restart.svg", command: ["systemctl", "reboot"] },
        { label: "Suspender", key: "S", icon: "common/assets/icons/moon.svg", command: ["systemctl", "suspend"] }
    ]

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "config-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (!visible)
            return

        root.currentIndex = 0
        stage.snap()
        overlay.forceActiveFocus()
        entrance.restart()
        cellReveal.restart()

        for (let i = 0; i < tiles.count; i++)
            (tiles.itemAt(i) as PowerTile).enter()
    }

    function runAction(index) {
        root.dismissed()
        Quickshell.execDetached(root.actions[index].command)
    }

    function select(index) {
        if (index === root.currentIndex)
            return
        root.currentIndex = index
    }

    function move(step) {
        root.select((root.currentIndex + step + root.actions.length) % root.actions.length)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
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
                root.dismissed()
                break
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                root.move(-1)
                break
            case Qt.Key_Right:
            case Qt.Key_Tab:
                root.move(1)
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.runAction(root.currentIndex)
                break
            default: {
                const index = root.actions.findIndex(a => a.key === event.text.toUpperCase())
                if (index < 0)
                    return
                root.runAction(index)
            }
            }
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0; color: Theme.Colors.alpha(Theme.Colors.background, 215 / 255) }
                GradientStop { position: 1; color: Theme.Colors.alpha(Theme.Colors.shadow, 240 / 255) }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: stage.top
            anchors.bottomMargin: 64

            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.Colors.powerLabel

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 84
                    weight: Font.Light
                    letterSpacing: -2
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.locale("pt_BR").toString(clock.date, "dddd, d 'de' MMMM")
                color: Theme.Colors.textSecondary

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 16
                    capitalization: Font.Capitalize
                }
            }
        }

        // The "essence" flows like a dividing cell. One continuous position
        // drives it: on each stretch between two tiles a bud leaves the origin,
        // the membrane stretches and pinches, and the bud becomes the next
        // origin. The tile receiving it rounds up and contracts towards the
        // light, then gets pushed back open when the light arrives. Tiles on
        // the way only fill partially; only the target fills completely.
        Item {
            id: stage

            readonly property real tileSize: 104
            readonly property real tileRadius: 30
            readonly property real gap: 28
            readonly property real step: tileSize + gap
            readonly property real iconSize: 32
            // Room above and below the tiles for the membrane to bulge while it divides.
            readonly property real bleed: 24
            // How full a tile gets when the light only passes through it.
            readonly property real passFill: 0.55
            // Tile corner radius as a fraction of its half size (1 = circle).
            readonly property real squareness: tileRadius / (tileSize / 2)

            property real position: 0
            property int target: 0
            property int origin: 0
            property int direction: 1
            property real originFill: 1
            property bool pressing: false

            readonly property int next: origin + direction
            // How full the bud will be once it lands; eased so retargeting mid-flight never pops.
            property real budFill: fillAt(next)
            Behavior on budFill {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            readonly property real split: Math.max(0, Math.min(1, (position - origin) * direction))
            // The origin's outline compresses to half around the dividing sphere, then
            // relaxes back to full size, turning from a circle into a rounded square.
            readonly property real release: 1 - 0.5 * Math.sin(Math.PI * split)
            // The receiving outline shrinks and rounds off on its way to meet the bud;
            // once they meet, both keep growing together to full size.
            readonly property real reach: smoothstep(0, 0.55, split) * (1 - smoothstep(0.55, 1, split))

            property real pressScale: pressing ? 0.92 : 1
            Behavior on pressScale {
                SpringAnimation { spring: 4.5; damping: 0.28; epsilon: 0.002 }
            }

            function smoothstep(edge0, edge1, x) {
                const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)))
                return t * t * (3 - 2 * t)
            }

            function centerOf(index) {
                return index * step + tileSize / 2
            }

            function fillAt(index) {
                return index === target ? 1 : passFill
            }

            // Outline of each tile: the active one is a circle, the others rounded squares.
            function outlineScale(index) {
                if (index === origin)
                    return release
                if (index === next)
                    return 1 - 0.45 * reach
                return 1
            }

            function outlineRoundness(index) {
                if (index === origin)
                    return 1 - (1 - squareness) * smoothstep(0.5, 1, split)
                if (index === next)
                    return squareness + (1 - squareness) * smoothstep(0, 0.55, split)
                return squareness
            }

            // The receiving outline drifts a little towards the incoming light.
            function outlineShift(index) {
                return index === next ? -direction * 16 * reach : 0
            }

            function snap() {
                travel.stop()
                refill.stop()
                target = origin = root.currentIndex
                direction = 1
                originFill = 1
                position = root.currentIndex
            }

            function moveTo(index) {
                target = index
                if (origin === target) {
                    refill.stop()
                    refill.to = 1
                    refill.start()
                }

                const distance = Math.abs(index - position)
                travel.stop()
                if (distance === 0)
                    return

                travel.from = position
                travel.to = index
                travel.duration = 220 + 150 * distance
                travel.easing.type = distance > 1.5 ? Easing.InOutQuad : Easing.InOutCubic
                travel.start()
            }

            // Keeps origin/direction in step with the position: crossing a whole
            // tile hands the origin over to the bud, and moving back past the
            // origin just makes the bud bloom the other way.
            onPositionChanged: {
                let progress = (position - origin) * direction
                while (progress >= 1) {
                    refill.stop()
                    originFill = budFill
                    origin += direction
                    progress -= 1
                }
                if (progress < 0)
                    direction = -direction
            }

            anchors.centerIn: parent
            width: tileRow.width
            height: tileRow.height

            NumberAnimation {
                id: travel

                target: stage
                property: "position"
            }

            // The light resting on a pass-through tile that just became the target fills it up.
            NumberAnimation {
                id: refill

                target: stage
                property: "originFill"
                duration: 220
                easing.type: Easing.OutCubic
            }

            Connections {
                target: root
                function onCurrentIndexChanged() {
                    stage.moveTo(root.currentIndex)
                }
            }

            Row {
                id: tileRow

                spacing: stage.gap

                Repeater {
                    id: tiles

                    model: root.actions

                    PowerTile {
                        required property var modelData
                        required property int index

                        label: modelData.label
                        iconPath: modelData.icon
                        order: index
                        active: root.currentIndex === index

                        onHovered: root.select(index)
                        onActivated: root.runAction(index)
                        onPressedChanged: stage.pressing = pressed
                    }
                }
            }

            Item {
                id: cell

                y: -stage.bleed
                width: stage.width
                height: stage.tileSize + 2 * stage.bleed
                opacity: 0

                ShaderEffect {
                    id: membrane

                    readonly property real t: stage.split
                    readonly property real moved: 0.5 * t + 0.5 * stage.smoothstep(0, 1, t)
                    readonly property real grow: 1 - Math.pow(1 - t, 3)
                    // The sphere compresses with its outline, then sinks under the surface.
                    readonly property real shrink: Math.pow(Math.max(0, (t - 0.5) / 0.5), 2)

                    readonly property real motherX: stage.centerOf(stage.origin)
                    readonly property real daughterX: motherX + (stage.centerOf(stage.next) - motherX) * moved

                    anchors.fill: parent
                    visible: false

                    property size size: Qt.size(width, height)
                    property vector4d cells: Qt.vector4d(motherX, height / 2, daughterX, height / 2)
                    property vector2d scales: Qt.vector2d(
                        stage.originFill * stage.release * (1 - shrink) * stage.pressScale,
                        stage.budFill * grow)
                    // The light is always a sphere.
                    property vector2d corners: Qt.vector2d(1, 1)
                    property vector2d fade: Qt.vector2d(18 * shrink, 18 * (1 - grow))
                    property real extent: stage.tileSize / 2
                    property real goo: stage.tileSize * 0.8
                    property color tint: Theme.Colors.accent

                    fragmentShader: Quickshell.shellPath("common/assets/shaders/mitosis.frag.qsb")
                }

                ShaderEffectSource {
                    id: membraneTexture

                    anchors.fill: membrane
                    sourceItem: membrane
                    hideSource: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: membraneTexture
                    source: membraneTexture

                    shadowEnabled: true
                    shadowColor: Theme.Colors.accent
                    shadowBlur: 1
                    shadowVerticalOffset: 6
                    shadowOpacity: 0.5
                }

                // Inverted copies of every icon, masked by the membrane: whatever
                // tile the cell is passing over shows its icon "filled".
                Item {
                    id: filledIcons

                    anchors.fill: parent
                    visible: false

                    Repeater {
                        model: root.actions

                        Icon {
                            required property var modelData
                            required property int index

                            x: index * stage.step + (stage.tileSize - width) / 2
                            y: stage.bleed + (stage.tileSize - height) / 2

                            width: stage.iconSize
                            height: stage.iconSize

                            source: Quickshell.shellPath(modelData.icon)
                            color: Theme.Colors.background
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: filledIcons
                    source: filledIcons

                    maskEnabled: true
                    maskSource: membraneTexture
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }

            SequentialAnimation {
                id: cellReveal

                PropertyAction { target: cell; property: "opacity"; value: 0 }
                PauseAnimation { duration: 220 }
                NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56

            text: "←  →  navegar     ⏎  confirmar     esc  fechar"
            color: Theme.Colors.textMuted

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 13
            }
        }
    }

    component PowerTile: Item {
        id: tile

        property string label
        property string iconPath
        property int order
        property bool active

        readonly property bool pressed: mouse.pressed
        readonly property real size: stage.tileSize

        signal hovered()
        signal activated()

        function enter() {
            reveal.restart()
        }

        width: size
        height: size + 44
        opacity: 0

        SequentialAnimation {
            id: reveal

            PropertyAction { target: tile; property: "opacity"; value: 0 }
            PropertyAction { target: body; property: "y"; value: 28 }
            PauseAnimation { duration: 40 + tile.order * 55 }

            ParallelAnimation {
                NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: body; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            }
        }

        Item {
            id: body

            width: tile.size
            height: tile.height

            Item {
                id: shape

                width: tile.size
                height: tile.size

                scale: tile.pressed ? 0.92 : 1
                Behavior on scale {
                    SpringAnimation { spring: 4.5; damping: 0.28; epsilon: 0.002 }
                }

                Rectangle {
                    x: stage.outlineShift(tile.order)
                    width: parent.width
                    height: parent.height

                    scale: stage.outlineScale(tile.order)
                    radius: width / 2 * stage.outlineRoundness(tile.order)
                    color: Theme.Colors.alpha(Theme.Colors.surface, 150 / 255)
                    border.width: 1
                    border.color: Theme.Colors.alpha(Theme.Colors.accent, 55 / 255)
                }

                Icon {
                    anchors.centerIn: parent

                    width: stage.iconSize
                    height: stage.iconSize

                    source: Quickshell.shellPath(tile.iconPath)
                    color: Theme.Colors.accent
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: tile.hovered()
                    onClicked: tile.activated()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: shape.bottom
                anchors.topMargin: 18

                text: tile.label
                color: tile.active ? Theme.Colors.powerLabel : Theme.Colors.textSecondary
                opacity: tile.active ? 1 : 0.55
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 14
                    bold: tile.active
                }
            }
        }
    }
}
