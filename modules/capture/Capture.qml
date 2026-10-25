pragma ComponentBehavior: Bound

import "../../common/components"
import "../../common/theme" as Theme

import QtQuick
import Quickshell
import Quickshell.Wayland

// Screenshot and recording pill at the bottom of the screen, in the spirit of
// macOS' ⇧⌘5. The overlay catches clicks outside the pill to dismiss it.
PanelWindow {// qmllint disable uncreatable-type
    id: root

    property string hoveredLabel: ""
    property bool optionsOpen: false

    readonly property int modeIndex: CaptureState.modes.findIndex(m => m.key === CaptureState.mode)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: CaptureState.open

    WlrLayershell.namespace: "config-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (!visible)
            return

        root.optionsOpen = false
        root.hoveredLabel = ""
        overlay.forceActiveFocus()
        entrance.restart()
    }

    function selectMode(index) {
        CaptureState.mode = CaptureState.modes[index].key
    }

    function dismiss() {
        if (root.optionsOpen)
            root.optionsOpen = false
        else
            CaptureState.hide()
    }

    Item {
        id: overlay

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const count = CaptureState.modes.length
            switch (event.key) {
            case Qt.Key_Escape:
                root.dismiss()
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                CaptureState.capture()
                break
            case Qt.Key_Left:
            case Qt.Key_Backtab:
                root.selectMode((root.modeIndex - 1 + count) % count)
                break
            case Qt.Key_Right:
            case Qt.Key_Tab:
                root.selectMode((root.modeIndex + 1) % count)
                break
            case Qt.Key_O:
                root.optionsOpen = !root.optionsOpen
                break
            default: {
                const index = parseInt(event.text) - 1
                if (!(index >= 0 && index < count))
                    return
                root.selectMode(index)
            }
            }
            event.accepted = true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Rectangle {
            anchors.horizontalCenter: pill.horizontalCenter
            anchors.bottom: pill.top
            anchors.bottomMargin: 12

            visible: !root.optionsOpen
            opacity: pill.opacity
            width: hint.implicitWidth + 24
            height: 28
            radius: height / 2
            color: Theme.Colors.alpha(Theme.Colors.popup, 230 / 255)

            Text {
                id: hint

                anchors.centerIn: parent
                text: root.hoveredLabel
                || (CaptureState.recording ? "Gravando…" : CaptureState.modes[root.modeIndex].label)
                color: Theme.Colors.textSecondary

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 12
                }
            }
        }

        Rectangle {
            id: pill

            // Slides in through a translation: animating `y` itself would replace its
            // binding with whatever the window's height was on the first opening.
            property real rise: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: overlay.height - height - 40
            transform: Translate { y: pill.rise }

            width: content.width + 16
            height: 60
            radius: height / 2

            color: Theme.Colors.alpha(Theme.Colors.popup, 245 / 255)
            border.width: 1
            border.color: Theme.Colors.alpha(Theme.Colors.accent, 48 / 255)

            ParallelAnimation {
                id: entrance

                NumberAnimation { target: pill; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: pill; property: "rise"; from: 24; to: 0; duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }

            // Swallow clicks on the pill's background.
            MouseArea {
                anchors.fill: parent
            }

            CellHighlight {
                anchors.fill: parent

                items: {
                    const modes = []
                    for (let i = 0; i < modeRepeater.count; i++)
                        modes.push((modeRepeater.itemAt(i) as ModeEntry)?.button)
                    // Options joins the hover but is never a resting place.
                    return [closeButton].concat(modes, [optionsButton])
                }
                // The selected mode keeps its own ring and stays out of the cell's way.
                ignoredIndex: root.modeIndex + 1
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: 4

                PillButton {
                    id: closeButton

                    cellRadius: width / 2

                    iconPath: "common/assets/icons/close.svg"
                    label: "Fechar"
                    onClicked: CaptureState.hide()
                }

                Divider {}

                Repeater {
                    id: modeRepeater

                    model: CaptureState.modes

                    ModeEntry {}
                }

                Divider {}

                Item {
                    id: optionsButton

                    readonly property bool hovered: optionsMouse.containsMouse
                    readonly property bool pressed: optionsMouse.pressed

                    anchors.verticalCenter: parent.verticalCenter
                    width: optionsRow.implicitWidth + 28
                    height: 44

                    Row {
                        id: optionsRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Opções"
                            color: Theme.Colors.accent

                            font {
                                family: Theme.Typography.monoFamily
                                pixelSize: 14
                            }
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: Quickshell.shellPath("common/assets/icons/chevron-down.svg")

                            rotation: root.optionsOpen ? 180 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: optionsMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.optionsOpen = !root.optionsOpen
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: captureText.implicitWidth + 36
                    height: 44
                    radius: 22

                    color: CaptureState.recording
                        ? (captureMouse.containsMouse ? Qt.lighter(Theme.Colors.danger, 1.15) : Theme.Colors.danger)
                        : captureMouse.pressed ? Theme.Colors.pressed
                        : captureMouse.containsMouse ? Theme.Colors.hover
                        : Theme.Colors.primary
                    Behavior on color {
                        ColorAnimation { duration: Theme.Motion.fast }
                    }

                    scale: captureMouse.pressed ? 0.95 : 1
                    Behavior on scale {
                        SpringAnimation { spring: 4.5; damping: 0.28; epsilon: 0.002 }
                    }

                    Text {
                        id: captureText

                        anchors.centerIn: parent
                        text: CaptureState.recording ? "Parar gravação"
                            : CaptureState.recordMode ? "Gravar" : "Capturar"
                        color: Theme.Colors.background

                        font {
                            family: Theme.Typography.monoFamily
                            pixelSize: 14
                            bold: true
                        }
                    }

                    MouseArea {
                        id: captureMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: CaptureState.capture()
                    }
                }
            }
        }

        Rectangle {
            id: optionsMenu

            visible: root.optionsOpen

            x: Math.min(pill.x + optionsButton.mapToItem(pill, 0, 0).x, overlay.width - width - 16)
            anchors.bottom: pill.top
            anchors.bottomMargin: 12

            width: 300
            height: menuColumn.implicitHeight + 20
            radius: 18

            color: Theme.Colors.alpha(Theme.Colors.popup, 250 / 255)
            border.width: 1
            border.color: Theme.Colors.alpha(Theme.Colors.accent, 48 / 255)

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: menuColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 2

                OptionSection {
                    title: "Salvar em"
                    visible: !CaptureState.recordMode
                    current: CaptureState.destination
                    choices: [
                        { label: "Área de transferência e Imagens", value: "both" },
                        { label: "Área de transferência", value: "copy" },
                        { label: "Imagens", value: "save" }
                    ]
                    onPicked: value => CaptureState.destination = value
                }

                OptionSection {
                    title: "Áudio"
                    visible: CaptureState.recordMode
                    current: CaptureState.audio
                    choices: [
                        { label: "Sem áudio", value: "none" },
                        { label: "Áudio do sistema", value: "system" },
                        { label: "Microfone", value: "mic" }
                    ]
                    onPicked: value => CaptureState.audio = value
                }

                OptionSection {
                    title: "Timer"
                    current: CaptureState.delay
                    choices: [
                        { label: "Nenhum", value: 0 },
                        { label: "5 segundos", value: 5 },
                        { label: "10 segundos", value: 10 }
                    ]
                    onPicked: value => CaptureState.delay = value
                }

                OptionSection {
                    title: "Opções"
                    visible: !CaptureState.recordMode
                    current: CaptureState.cursor
                    choices: [
                        { label: "Mostrar o cursor", value: !CaptureState.cursor }
                    ]
                    onPicked: value => CaptureState.cursor = value
                }
            }
        }
    }

    // A mode button, preceded by a divider where screenshots give way to recordings.
    component ModeEntry: Row {
        id: modeEntry

        required property var modelData
        required property int index

        readonly property alias button: modeButton

        spacing: 4

        Divider {
            visible: modeEntry.index > 0
                && CaptureState.modes[modeEntry.index - 1].key.startsWith("rec-") !== modeEntry.modelData.key.startsWith("rec-")
        }

        PillButton {
            id: modeButton

            iconPath: modeEntry.modelData.icon
            label: modeEntry.modelData.label
            active: CaptureState.mode === modeEntry.modelData.key
            onClicked: CaptureState.mode = modeEntry.modelData.key
        }
    }

    component Divider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: 28
        color: Theme.Colors.alpha(Theme.Colors.accent, 48 / 255)
    }

    // Square icon button: the pill's CellHighlight shows the hover, the selection is a ring.
    component PillButton: Item {
        id: button

        property string iconPath
        property string label
        property bool active: false
        // Shape the hover cell settles into.
        property real cellRadius: 14

        readonly property bool hovered: buttonMouse.containsMouse
        readonly property bool pressed: buttonMouse.pressed

        signal clicked()

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 44
        height: 44

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.width: 1.5
            border.color: Theme.Colors.primary
            visible: button.active
        }

        Icon {
            anchors.centerIn: parent
            width: 24
            height: 24
            source: Quickshell.shellPath(button.iconPath)
            color: button.active ? Theme.Colors.primary : Theme.Colors.accent
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onContainsMouseChanged: {
                if (containsMouse)
                    root.hoveredLabel = button.label
                else if (root.hoveredLabel === button.label)
                    root.hoveredLabel = ""
            }
            onClicked: button.clicked()
        }
    }

    // A titled list of choices; `current` is checked. A single choice acts as a toggle:
    // its value is what picking it sets, and it shows checked while `current` is true.
    component OptionSection: Column {
        id: section

        property string title
        property var choices: []
        property var current

        signal picked(var value)

        width: parent ? parent.width : 0
        spacing: 0

        Text {
            leftPadding: 10
            topPadding: 6
            bottomPadding: 4

            text: section.title
            color: Theme.Colors.textMuted

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 11
                bold: true
                capitalization: Font.AllUppercase
            }
        }

        Repeater {
            model: section.choices

            Rectangle {
                id: choice

                required property var modelData

                readonly property bool checked: section.choices.length === 1
                    ? section.current === true
                    : section.current === modelData.value

                width: section.width
                height: 32
                radius: 10
                color: choiceMouse.containsMouse ? Theme.Colors.itemHover : "transparent"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: 16

                    text: choice.checked ? "✓" : ""
                    color: Theme.Colors.accent

                    font {
                        family: Theme.Typography.monoFamily
                        pixelSize: 13
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 30

                    text: choice.modelData.label
                    color: choice.checked ? Theme.Colors.textPrimary : Theme.Colors.textSecondary

                    font {
                        family: Theme.Typography.monoFamily
                        pixelSize: 13
                    }
                }

                MouseArea {
                    id: choiceMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.picked(choice.modelData.value)
                }
            }
        }
    }
}
