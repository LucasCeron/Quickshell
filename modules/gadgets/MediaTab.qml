pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../common/theme" as Theme
import "../../services" as Services
import "../../common/components"
import "components"

Column {
    id: root
    spacing: 18
    readonly property var player: Services.Media.player
    readonly property bool hasDuration: (player?.lengthSupported ?? false) && isFinite(player.length) && player.length > 0
    property real position: 0

    function updatePosition(): void { position = player?.positionSupported ? player.position : 0; }
    onPlayerChanged: updatePosition()
    Timer {
        interval: 500
        running: root.visible && !!root.player
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updatePosition()
    }

    Row {
        spacing: 8
        Rectangle {
            width: 7; height: 7; radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: Services.Media.playing ? Theme.Colors.accent : Theme.Colors.textMuted
        }
        SectionLabel { text: Services.Media.playing ? "TOCANDO AGORA" : "NO SEU RITMO" }
    }

    Rectangle {
        width: parent.width
        height: 224
        radius: 20
        color: Theme.Colors.surface
        border.width: 1
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 0.12)

        Rectangle {
            id: cover
            x: 18; y: 18
            width: 142; height: 142
            radius: 16
            color: Theme.Colors.alpha(Theme.Colors.accent, 0.12)
            Icon {
                anchors.centerIn: parent
                width: 56; height: 56
                source: Quickshell.shellPath("common/assets/icons/music.svg")
                visible: artwork.status !== Image.Ready
            }
            Image {
                id: artwork
                anchors.fill: parent
                anchors.margins: 4
                source: Services.Media.artUrl
                sourceSize: Qt.size(284, 284)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
        }
        Column {
            x: 180; y: 22
            width: parent.width - x - 18
            spacing: 8
            Text {
                width: parent.width
                text: root.player?.identity || "SEU PLAYER, AQUI"
                color: Theme.Colors.accent
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Services.Media.title
                color: Theme.Colors.textPrimary
                font.pixelSize: 22
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Services.Media.artist
                color: Theme.Colors.textSecondary
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.player?.trackAlbum || (root.player ? "" : "A música aparece automaticamente.")
                color: Theme.Colors.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            spacing: 14
            ActionButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 40; radius: 20
                iconSize: 18
                iconSource: Quickshell.shellPath("common/assets/icons/skip-back.svg")
                hint: "Faixa anterior"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player?.previous()
            }
            ActionButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 48; radius: 24
                iconSize: 22
                prominent: true
                iconSource: Quickshell.shellPath("common/assets/icons/" + (Services.Media.playing ? "pause.svg" : "play.svg"))
                hint: Services.Media.playing ? "Pausar" : "Tocar"
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player?.togglePlaying()
            }
            ActionButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 40; radius: 20
                iconSize: 18
                iconSource: Quickshell.shellPath("common/assets/icons/skip-forward.svg")
                hint: "Próxima faixa"
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player?.next()
            }
        }
    }
    Column {
        width: parent.width
        spacing: 0
        ValueSlider {
            id: seek
            width: parent.width
            from: 0
            to: root.hasDuration ? root.player.length : 1
            value: root.hasDuration ? root.position : 0
            enabled: (root.player?.canSeek ?? false) && root.hasDuration && (root.player?.positionSupported ?? false)
            opacity: enabled ? 1 : 0.4
            onMoved: if (root.player) root.player.position = value
            Accessible.name: "Posição da faixa"
        }
        Item {
            width: parent.width; height: 18
            Text {
                text: Services.Media.time(seek.pressed ? seek.value : root.position)
                color: Theme.Colors.textMuted; font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                text: root.hasDuration ? Services.Media.time(root.player.length) : "Duração indisponível"
                color: Theme.Colors.textMuted; font.pixelSize: 11
            }
        }
    }
    SectionLabel { text: "SEUS PLAYERS" }
    Flow {
        width: parent.width
        spacing: 8
        ActionButton {
            text: "Automático"
            selected: Services.Media.selectedName === ""
            onClicked: Services.Media.selectedName = ""
        }
        Repeater {
            model: ScriptModel { values: Services.Media.players }
            delegate: ActionButton {
                required property var modelData
                text: modelData.identity
                iconSource: modelData.isPlaying ? Quickshell.shellPath("common/assets/icons/music.svg") : ""
                selected: Services.Media.selectedName === modelData.dbusName
                onClicked: Services.Media.selectedName = modelData.dbusName
            }
        }
    }
    Text {
        width: parent.width
        text: root.player ? "No modo automático, quem está tocando ganha a vez."
            : "Dê play no Spotify, VLC ou em um navegador compatível para ver a faixa e controlar a reprodução por aqui."
        wrapMode: Text.Wrap
        color: Theme.Colors.textMuted
        font.pixelSize: 12
    }
}
