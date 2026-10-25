pragma ComponentBehavior: Bound
import "../../common/theme" as Theme
import "../../common/components"
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "components"
import "../../services" as Services

// Sound: output and input, each with its device and a live level, then every app
// playing with its own volume. The full mixer stays one link away.
PopupWindow {
    id: root

    required property Item anchorItem
    // Which device list is unfolded: "output", "input" or none.
    property string picking: ""

    onVisibleChanged: if (!visible) picking = ""

    implicitWidth: 380
    implicitHeight: Math.min(720, layout.implicitHeight + 36)

    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem
        // qmllint disable missing-type
        edges: Edges.Right
        gravity: Edges.Right
        adjustment: PopupAdjustment.SlideY
        // qmllint enable missing-type
        margins.left: 16
    }

    // Volume and levels of everything shown here.
    PwObjectTracker {
        objects: Services.Audio.outputs.concat(Services.Audio.inputs, Services.Audio.streams)
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Theme.Colors.alpha(Theme.Colors.popup, 250 / 255)
        border { width: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 56 / 255) }

        Flickable {
            anchors { fill: parent; margins: 18 }
            contentWidth: width
            contentHeight: layout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: layout
                width: parent.width
                spacing: 12

                Item {
                    width: parent.width; height: 32
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Som"
                        color: Theme.Colors.textPrimary
                        font { pixelSize: 20; weight: Font.DemiBold }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "Mixer avançado"
                        color: mixerMouse.containsMouse ? Theme.Colors.accentHover : Theme.Colors.accent
                        font { pixelSize: 12; weight: Font.DemiBold; underline: true }
                        MouseArea {
                            id: mixerMouse
                            anchors { fill: parent; margins: -6 }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Audio.openMixer()
                        }
                        Accessible.role: Accessible.Link
                        Accessible.name: "Mixer avançado"
                    }
                }

                DeviceCard {
                    kind: "output"
                    title: "Saída"
                    node: Services.Audio.defaultSink
                    devices: Services.Audio.outputs
                    iconName: "volume.svg"
                    mutedIconName: "volume-mute.svg"
                    isSelected: node => Services.Audio.defaultSink === node
                    onPicked: node => Services.Audio.selectSink(node)
                }

                DeviceCard {
                    kind: "input"
                    title: "Entrada"
                    node: Services.Audio.defaultSource
                    devices: Services.Audio.inputs
                    iconName: "mic.svg"
                    mutedIconName: "mic-off.svg"
                    isSelected: node => Services.Audio.defaultSource === node
                    onPicked: node => Services.Audio.selectSource(node)
                }

                // Every app playing, each with its own volume.
                Rectangle {
                    width: parent.width
                    height: apps.implicitHeight + 28
                    radius: 18
                    color: Theme.Colors.surface
                    Column {
                        id: apps
                        x: 14; y: 14
                        width: parent.width - 28
                        spacing: 12
                        Text {
                            text: "APLICATIVOS"
                            color: Theme.Colors.textSecondary
                            font { pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.4 }
                        }
                        Text {
                            visible: Services.Audio.streams.length === 0
                            text: "Nenhum aplicativo tocando agora."
                            color: Theme.Colors.textMuted
                            font.pixelSize: 12
                        }
                        Repeater {
                            model: ScriptModel { values: Services.Audio.streams }
                            delegate: Column {
                                id: app
                                required property var modelData
                                width: apps.width
                                spacing: 6
                                Item {
                                    width: parent.width; height: 20
                                    IconImage {
                                        id: appIcon
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: 18
                                        source: Services.Audio.appIcon(app.modelData)
                                    }
                                    Text {
                                        x: appIcon.width + 8
                                        width: parent.width - x
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            const media = app.modelData.properties?.["media.name"] ?? "";
                                            return Services.Audio.appName(app.modelData) + (media ? "  ·  " + media : "");
                                        }
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: Theme.Colors.textSecondary
                                        font.pixelSize: 11
                                    }
                                }
                                VolumeSlider {
                                    width: parent.width
                                    node: app.modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The current device with its volume and level; the name unfolds the list of
    // the others to switch to.
    component DeviceCard: Rectangle {
        id: card
        property string kind
        property string title
        property var node
        property var devices: []
        property string iconName
        property string mutedIconName
        property var isSelected: () => false
        readonly property bool open: root.picking === kind
        signal picked(var node)

        width: layout.width
        height: cardColumn.implicitHeight + 28
        radius: 18
        color: Theme.Colors.surface
        clip: true
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Column {
            id: cardColumn
            x: 14; y: 14
            width: parent.width - 28
            spacing: 12

            // Title and current device; a click shows the others.
            Item {
                width: parent.width; height: 34
                Column {
                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: card.title.toUpperCase()
                        color: Theme.Colors.textSecondary
                        font { pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.4 }
                    }
                    Text {
                        width: parent.width
                        text: card.node ? Services.Audio.nodeName(card.node) : "Nenhum dispositivo"
                        elide: Text.ElideRight
                        color: Theme.Colors.textPrimary
                        font { pixelSize: 13; weight: Font.DemiBold }
                    }
                }
                Icon {
                    visible: card.devices.length > 1
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 18; height: 18
                    rotation: card.open ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 180 } }
                    source: Quickshell.shellPath("common/assets/icons/chevron-down.svg")
                    color: pickMouse.containsMouse ? Theme.Colors.accent : Theme.Colors.textMuted
                }
                MouseArea {
                    id: pickMouse
                    anchors.fill: parent
                    enabled: card.devices.length > 1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picking = card.open ? "" : card.kind
                }
            }

            VolumeSlider {
                width: parent.width
                node: card.node
                iconName: card.iconName
                mutedIconName: card.mutedIconName
            }

            // The other devices, as a radio list.
            Column {
                width: parent.width
                visible: card.open
                spacing: 2
                Rectangle { width: parent.width; height: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 0.12) }
                Item { width: 1; height: 6 }
                Repeater {
                    model: ScriptModel { values: card.devices }
                    delegate: Rectangle {
                        id: device
                        required property var modelData
                        readonly property bool selected: card.isSelected(modelData)
                        width: cardColumn.width
                        height: 38
                        radius: 10
                        color: deviceMouse.containsMouse ? Theme.Colors.surfaceHigh : "transparent"
                        Rectangle {
                            id: radio
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: "transparent"
                            border { width: 1.5; color: device.selected ? Theme.Colors.accent : Theme.Colors.textMuted }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: 8; radius: 4
                                visible: device.selected
                                color: Theme.Colors.accent
                            }
                        }
                        Text {
                            x: radio.x + radio.width + 12
                            width: parent.width - x - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Services.Audio.nodeName(device.modelData)
                            elide: Text.ElideRight
                            color: device.selected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
                            font { pixelSize: 12; weight: device.selected ? Font.DemiBold : Font.Normal }
                        }
                        MouseArea {
                            id: deviceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.picked(device.modelData);
                                root.picking = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
