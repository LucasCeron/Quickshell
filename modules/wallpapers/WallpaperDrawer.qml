pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import "../../common/theme" as Theme
import "../../services" as Services
import "../../config" as Config
import "../gadgets/components"

PanelWindow {// qmllint disable uncreatable-type
    id: root
    anchors.bottom: true
    margins.bottom: 16 // qmllint disable unqualified unresolved-type
    implicitWidth: Math.min(1100, (screen?.width ?? 1200) - 112)
    implicitHeight: Math.min(340, (screen?.height ?? 800) - 80)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: WallpapersState.open || reveal > 0
    property real reveal: WallpapersState.open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    WlrLayershell.namespace: "config-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WallpapersState.open && !folderDialog.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: card; radius: card.radius }

    Connections {
        target: WallpapersState
        function onOpenChanged(): void { if (WallpapersState.open) card.forceActiveFocus(); }
    }

    Rectangle {
        id: card
        width: root.width; height: root.height
        y: (1 - root.reveal) * (height + 16)
        opacity: root.reveal
        radius: 24
        color: Theme.Colors.alpha(Theme.Colors.popup, 0.98)
        border.width: 1
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 0.24)
        focus: true
        Keys.onEscapePressed: WallpapersState.open = false
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12
            Item {
                width: parent.width; height: 44
                Column {
                    spacing: 3
                    Text { text: "Wallpapers"; color: Theme.Colors.textPrimary; font.pixelSize: 21; font.weight: Font.DemiBold }
                    Text {
                        width: Math.max(80, card.width - actions.width - 60)
                        text: Config.Settings.wallpaperFolder || "Uma nova vista para o seu dia"
                        elide: Text.ElideMiddle
                        color: Theme.Colors.textMuted; font.pixelSize: 11
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    spacing: 6
                    ActionButton { text: "Pasta"; hint: "Escolher pasta de wallpapers"; onClicked: folderDialog.open() }
                    ActionButton { text: "↻"; hint: "Atualizar imagens"; enabled: !Services.Wallpapers.scanning; onClicked: Services.Wallpapers.scan() }
                    ActionButton { text: "⌂"; hint: "Usar pastas padrão"; onClicked: { Config.Settings.wallpaperFolder = ""; Services.Wallpapers.scan(); } }
                }
            }
            ListView {
                id: gallery
                width: parent.width
                height: Math.max(110, card.height - 132)
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: Services.Wallpapers.items
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true
                highlightMoveDuration: 150
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool selected: Config.Settings.wallpaperPath === modelData.path
                    width: 260; height: gallery.height - 12
                    radius: 16
                    color: Theme.Colors.surface
                    border.width: selected || activeFocus ? 2 : 1
                    border.color: selected || activeFocus ? Theme.Colors.accent : Theme.Colors.surfaceHigh
                    Image {
                        id: thumbnail
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
                        height: parent.height - 44
                        source: tile.modelData.url
                        sourceSize: Qt.size(520, 300)
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                    }
                    Text {
                        anchors.centerIn: thumbnail
                        visible: thumbnail.status === Image.Error
                        text: "Prévia indisponível"
                        color: Theme.Colors.textMuted; font.pixelSize: 11
                    }
                    Text {
                        x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 13
                        width: parent.width - 28
                        text: (tile.selected ? "✓  " : "") + tile.modelData.name
                        color: tile.selected ? Theme.Colors.accent : Theme.Colors.textSecondary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !Services.Wallpapers.applying
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            gallery.currentIndex = tile.index;
                            tile.forceActiveFocus();
                            Services.Wallpapers.apply(tile.modelData.path);
                        }
                    }
                    activeFocusOnTab: true
                    onActiveFocusChanged: if (activeFocus) gallery.positionViewAtIndex(index, ListView.Contain)
                    Keys.onReturnPressed: Services.Wallpapers.apply(modelData.path)
                    Keys.onSpacePressed: Services.Wallpapers.apply(modelData.path)
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: Services.Wallpapers.apply(modelData.path)
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: Services.Wallpapers.scanning || gallery.count === 0
                    text: Services.Wallpapers.scanning ? "Buscando suas imagens…" : "Escolha uma pasta com seus wallpapers para começar."
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.Colors.textSecondary; font.pixelSize: 13
                }
            }
            Text {
                width: parent.width
                text: Services.Wallpapers.message || "Selecione uma imagem para aplicar em todas as telas."
                elide: Text.ElideRight
                color: Services.Wallpapers.failed ? Theme.Colors.danger : Theme.Colors.textMuted
                font.pixelSize: 12
            }
        }
    }
    FolderDialog {
        id: folderDialog
        title: "Escolha sua pasta de wallpapers"
        onAccepted: {
            Config.Settings.wallpaperFolder = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""));
            Services.Wallpapers.scan();
        }
        onVisibleChanged: if (!visible && WallpapersState.open) card.forceActiveFocus()
    }
}
