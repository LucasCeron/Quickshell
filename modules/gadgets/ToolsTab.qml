pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland
import "../../common/theme" as Theme
import "../../common/components"
import "../../config" as Config
import "../../services" as Services
import "components"
import "../capture"
import "../activity"
import "../overview"
import "../wallpapers"

Column {
    id: root
    spacing: 16
    readonly property string screenName: GadgetsState.screenName

    // Tools open in their own panels; opening one closes this drawer.
    SectionLabel { text: "FERRAMENTAS" }
    Grid {
        id: tools
        width: parent.width
        columns: 2
        spacing: 10
        readonly property real cellWidth: (width - spacing) / 2
        ToolTile {
            iconName: "camera.svg"; label: "Captura de tela"; detail: "Área, janela ou tela · Print"
            onClicked: { CaptureState.mode = "area"; CaptureState.show(root.screenName); }
        }
        ToolTile {
            iconName: "record-screen.svg"
            label: CaptureState.recording ? "Parar gravação" : "Gravar a tela"
            detail: CaptureState.recording ? "Gravando agora" : "Tela inteira ou área"
            onClicked: {
                if (CaptureState.recording) { CaptureState.stop(); return; }
                CaptureState.mode = "rec-screen";
                CaptureState.show(root.screenName);
            }
        }
        ToolTile {
            iconName: "monitor.svg"; label: "Visão geral"; detail: "Todas as áreas · Super+Tab"
            onClicked: OverviewState.show(root.screenName)
        }
        ToolTile {
            iconName: "activity.svg"; label: "Atividade"; detail: "CPU, memória e processos"
            onClicked: ActivityState.show(root.screenName)
        }
    }

    SectionLabel { text: "ÁREAS DE TRABALHO" }
    // The first three workspaces in miniature, then the full overview.
    Row {
        id: workspaces
        width: parent.width
        spacing: 8
        readonly property int current: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
        readonly property var monitor: Hyprland.focusedMonitor
        readonly property real moreWidth: 64
        readonly property real cardWidth: (width - moreWidth - 3 * spacing) / 3
        readonly property real cardHeight: Math.round(cardWidth * (monitor?.height ?? 9) / Math.max(1, monitor?.width ?? 16))
        Component.onCompleted: Hyprland.refreshToplevels()

        Repeater {
            model: [1, 2, 3]
            delegate: Column {
                id: mini
                required property int modelData
                readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
                readonly property bool selected: workspaces.current === modelData
                spacing: 6
                Rectangle {
                    width: workspaces.cardWidth
                    height: workspaces.cardHeight
                    radius: 12
                    color: "transparent"
                    border.width: mini.selected ? 2 : miniMouse.containsMouse ? 1 : 0
                    border.color: mini.selected ? Theme.Colors.accent : Theme.Colors.alpha(Theme.Colors.accent, 0.5)
                    ClippingRectangle {
                        anchors { fill: parent; margins: mini.selected ? 3 : 0 }
                        radius: mini.selected ? 9 : 12
                        color: Theme.Colors.surface
                        Image {
                            anchors.fill: parent
                            source: Config.Settings.wallpaperPath ? "file://" + Config.Settings.wallpaperPath : ""
                            sourceSize: Qt.size(240, 140)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.85
                        }
                        // Each window where it sits, with its live contents.
                        Item {
                            id: windows
                            anchors.fill: parent
                            readonly property real ratio: width / Math.max(1, workspaces.monitor?.width ?? 1)
                            Repeater {
                                model: mini.workspace?.toplevels?.values ?? []
                                delegate: ClippingRectangle {
                                    id: windowThumb
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject
                                    visible: !!ipc && ipc.at !== undefined && ipc.size !== undefined
                                    x: visible ? (ipc.at[0] - (workspaces.monitor?.x ?? 0)) * windows.ratio : 0
                                    y: visible ? (ipc.at[1] - (workspaces.monitor?.y ?? 0)) * windows.ratio : 0
                                    width: visible ? ipc.size[0] * windows.ratio : 0
                                    height: visible ? ipc.size[1] * windows.ratio : 0
                                    radius: 3
                                    color: Theme.Colors.surfaceHigh
                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: windowThumb.modelData.wayland
                                        live: true
                                    }
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: miniMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${mini.modelData} })`)
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(mini.modelData)
                    color: mini.selected ? Theme.Colors.accent : Theme.Colors.textMuted
                    font { pixelSize: 11; weight: mini.selected ? Font.DemiBold : Font.Normal }
                }
            }
        }

        // "See more": opens the full overview (Super+Tab).
        Column {
            spacing: 6
            Rectangle {
                width: workspaces.moreWidth
                height: workspaces.cardHeight
                radius: 12
                color: moreMouse.containsMouse ? Theme.Colors.surfaceHigh : Theme.Colors.surface
                Behavior on color { ColorAnimation { duration: 140 } }
                Icon {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    source: Quickshell.shellPath("common/assets/icons/monitor.svg")
                }
                MouseArea {
                    id: moreMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: OverviewState.show(root.screenName)
                }
                Accessible.role: Accessible.Button
                Accessible.name: "Ver todas as áreas de trabalho"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ver todas"
                color: moreMouse.containsMouse ? Theme.Colors.accent : Theme.Colors.textMuted
                font.pixelSize: 11
            }
        }
    }

    // Wallpaper and colours side by side: the look of the desktop in one place.
    Item {
        width: parent.width; height: 40
        SectionLabel { anchors.verticalCenter: parent.verticalCenter; text: "APARÊNCIA" }
        Text {
            id: allWallpapers
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "Todos os wallpapers"
            color: linkMouse.containsMouse ? Theme.Colors.accentHover : Theme.Colors.accent
            font { pixelSize: 12; weight: Font.DemiBold; underline: true }
            MouseArea {
                id: linkMouse
                anchors { fill: parent; margins: -6 }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WallpapersState.show(root.screenName)
            }
            Accessible.role: Accessible.Link
            Accessible.name: "Todos os wallpapers"
        }
    }
    ListView {
        id: gallery
        width: parent.width
        height: 92
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Services.Wallpapers.items
        Component.onCompleted: if (Services.Wallpapers.items.length === 0) Services.Wallpapers.scan()
        delegate: Rectangle {
            id: thumb
            required property var modelData
            readonly property bool selected: Config.Settings.wallpaperPath === modelData.path
            width: 148; height: 92
            radius: 14
            color: Theme.Colors.surface
            border.width: selected ? 2 : 0
            border.color: Theme.Colors.accent
            ClippingRectangle {
                anchors { fill: parent; margins: thumb.selected ? 3 : 0 }
                radius: thumb.selected ? 11 : 14
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: thumb.modelData.url
                    sourceSize: Qt.size(296, 184)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Wallpapers.apply(thumb.modelData.path)
            }
        }
    }
    Flow {
        width: parent.width
        spacing: 8
        Repeater {
            model: Theme.Presets.entries
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool selected: Config.Settings.themeName === modelData.key
                width: chipRow.implicitWidth + 24; height: 36
                radius: 18
                color: chipMouse.containsMouse ? Theme.Colors.surfaceHigh : Theme.Colors.surface
                border.width: selected ? 1 : 0
                border.color: modelData.accent
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8
                        color: chip.modelData.bg
                        border { width: 4; color: chip.modelData.accent }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.name
                        color: chip.selected ? chip.modelData.accent : Theme.Colors.textPrimary
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.Settings.themeName = chip.modelData.key
                }
            }
        }
    }
    Text {
        width: parent.width
        visible: text !== ""
        text: Services.Wallpapers.failed || Services.Wallpapers.applying ? Services.Wallpapers.message : ""
        wrapMode: Text.Wrap
        color: Services.Wallpapers.failed ? Theme.Colors.danger : Theme.Colors.textMuted
        font.pixelSize: 11
    }

    component ToolTile: Rectangle {
        id: tile
        property string iconName
        property string label
        property string detail
        signal clicked()
        width: tools.cellWidth
        height: 64
        radius: 18
        color: tileMouse.containsMouse ? Theme.Colors.surfaceHigh : Theme.Colors.surface
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            id: bubble
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: Theme.Colors.alpha(Theme.Colors.accent, 0.12)
            Icon {
                anchors.centerIn: parent
                width: 20; height: 20
                source: Quickshell.shellPath("common/assets/icons/" + tile.iconName)
            }
        }
        Column {
            x: bubble.x + bubble.width + 12
            width: parent.width - x - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { width: parent.width; text: tile.label; elide: Text.ElideRight; color: Theme.Colors.textPrimary; font { pixelSize: 13; weight: Font.DemiBold } }
            Text { width: parent.width; text: tile.detail; elide: Text.ElideRight; color: Theme.Colors.textMuted; font.pixelSize: 11 }
        }
        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
        Accessible.role: Accessible.Button
        Accessible.name: label
    }
}
