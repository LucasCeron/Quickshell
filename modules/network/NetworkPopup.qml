pragma ComponentBehavior: Bound
import "../../common/theme" as Theme
import "../../common/components"
import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Networking
import "../../services" as Services
import "../gadgets/components"

// Network: the current connection, then the Wi-Fi networks around. A secured
// network asks for its password inline; known and open ones connect at once.
PopupWindow {
    id: root

    required property Item anchorItem
    // The network whose password field is open.
    property var asking: null

    onVisibleChanged: if (!visible) asking = null

    implicitWidth: 380
    implicitHeight: Math.min(680, layout.implicitHeight + 36)

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

    // Look for networks only while the list is on screen.
    Binding {
        target: Services.Network.wifi
        property: "scannerEnabled"
        value: root.visible
        when: !!Services.Network.wifi
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
                        text: "Rede"
                        color: Theme.Colors.textPrimary
                        font { pixelSize: 20; weight: Font.DemiBold }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "Configurações avançadas"
                        color: settingsMouse.containsMouse ? Theme.Colors.accentHover : Theme.Colors.accent
                        font { pixelSize: 12; weight: Font.DemiBold; underline: true }
                        MouseArea {
                            id: settingsMouse
                            anchors { fill: parent; margins: -6 }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Network.openSettings()
                        }
                        Accessible.role: Accessible.Link
                        Accessible.name: "Configurações avançadas de rede"
                    }
                }

                // The connection in use.
                Rectangle {
                    width: parent.width; height: 68
                    radius: 18
                    color: Theme.Colors.surface
                    Rectangle {
                        id: statusBubble
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40; radius: 20
                        color: Services.Network.kind === "offline" ? Theme.Colors.alpha(Theme.Colors.textMuted, 0.15) : Theme.Colors.accent
                        Icon {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            source: Quickshell.shellPath("common/assets/icons/" + Services.Network.iconName)
                            color: Services.Network.kind === "offline" ? Theme.Colors.textMuted : Theme.Colors.background
                        }
                    }
                    Column {
                        x: statusBubble.x + statusBubble.width + 12
                        width: parent.width - x - 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: Services.Network.title
                            elide: Text.ElideRight
                            color: Theme.Colors.textPrimary
                            font { pixelSize: 14; weight: Font.DemiBold }
                        }
                        Text {
                            width: parent.width
                            text: Services.Network.detail
                            elide: Text.ElideRight
                            color: Services.Network.online || Services.Network.kind === "offline" ? Theme.Colors.textMuted : Theme.Colors.danger
                            font.pixelSize: 11
                        }
                    }
                }

                // Wi-Fi: switch and the networks around.
                Rectangle {
                    width: parent.width
                    height: wifiColumn.implicitHeight + 28
                    radius: 18
                    color: Theme.Colors.surface
                    Column {
                        id: wifiColumn
                        x: 14; y: 14
                        width: parent.width - 28
                        spacing: 6

                        Item {
                            width: parent.width; height: 26
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "WI-FI"
                                color: Theme.Colors.textSecondary
                                font { pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.4 }
                            }
                            Switch {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                visible: !!Services.Network.wifi
                                checked: Networking.wifiEnabled
                                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                        }

                        Text {
                            width: parent.width
                            visible: !Services.Network.wifi
                            text: "Nenhum adaptador Wi-Fi neste computador. Conecte um para ver as redes por perto."
                            wrapMode: Text.Wrap
                            color: Theme.Colors.textMuted
                            font.pixelSize: 12
                            bottomPadding: 4
                        }
                        Text {
                            width: parent.width
                            visible: !!Services.Network.wifi && !Networking.wifiEnabled
                            text: "O Wi-Fi está desligado."
                            color: Theme.Colors.textMuted
                            font.pixelSize: 12
                            bottomPadding: 4
                        }
                        Text {
                            width: parent.width
                            visible: !!Services.Network.wifi && Networking.wifiEnabled && Services.Network.networks.length === 0
                            text: "Procurando redes…"
                            color: Theme.Colors.textMuted
                            font.pixelSize: 12
                            bottomPadding: 4
                        }

                        Repeater {
                            model: ScriptModel { values: Networking.wifiEnabled ? Services.Network.networks : [] }
                            delegate: NetworkRow {}
                        }
                    }
                }
            }
        }
    }

    // One network: signal, name, lock; a click connects or asks for the password.
    component NetworkRow: Rectangle {
        id: row
        required property var modelData
        readonly property bool asking: root.asking === modelData
        property string error: ""
        width: wifiColumn.width
        height: rowColumn.implicitHeight + 12
        radius: 12
        color: rowMouse.containsMouse || asking ? Theme.Colors.surfaceHigh : "transparent"

        Connections {
            target: row.modelData
            function onConnectionFailed(reason: int): void {
                row.error = Services.Network.failure(reason);
                if (Services.Network.secured(row.modelData)) root.asking = row.modelData;
            }
            function onConnectedChanged(): void {
                if (row.modelData.connected) { row.error = ""; if (root.asking === row.modelData) root.asking = null; }
            }
        }

        function activate(): void {
            error = "";
            if (modelData.connected) return;
            if (modelData.known || !Services.Network.secured(modelData)) modelData.connect();
            else root.asking = asking ? null : modelData;
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activate()
        }

        Column {
            id: rowColumn
            x: 8; y: 6
            width: parent.width - 16
            spacing: 8

            Item {
                width: parent.width; height: 32
                Icon {
                    id: signal
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    source: Quickshell.shellPath("common/assets/icons/" + Services.Network.signalIcon(Services.Network.strength(row.modelData)))
                    color: row.modelData.connected ? Theme.Colors.accent : Theme.Colors.textSecondary
                }
                Column {
                    x: signal.width + 12
                    width: parent.width - x - actions.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.modelData.name || "Rede oculta"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.textPrimary
                        font { pixelSize: 13; weight: row.modelData.connected ? Font.DemiBold : Font.Normal }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.error !== "" ? row.error
                            : row.modelData.stateChanging ? (row.modelData.connected ? "Desconectando…" : "Conectando…")
                            : row.modelData.connected ? "Conectado"
                            : row.modelData.known ? "Salva" : ""
                        color: row.error !== "" ? Theme.Colors.danger : row.modelData.connected ? Theme.Colors.accent : Theme.Colors.textMuted
                        font.pixelSize: 11
                    }
                }
                Row {
                    id: actions
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Services.Network.secured(row.modelData) && !row.modelData.connected && !rowMouse.containsMouse
                        width: 14; height: 14
                        source: Quickshell.shellPath("common/assets/icons/lock-small.svg")
                        color: Theme.Colors.textMuted
                    }
                    ActionButton {
                        visible: row.modelData.connected && (rowMouse.containsMouse || hovered)
                        implicitHeight: 28
                        text: "Desconectar"
                        onClicked: row.modelData.disconnect()
                    }
                    ActionButton {
                        visible: row.modelData.known && (rowMouse.containsMouse || hovered)
                        implicitHeight: 28
                        text: "Esquecer"
                        onClicked: row.modelData.forget()
                    }
                }
            }

            // Password, inline.
            Row {
                visible: row.asking
                width: parent.width
                spacing: 8
                Controls.TextField {
                    id: password
                    width: parent.width - join.width - 8
                    height: 36
                    placeholderText: "Senha da rede"
                    echoMode: TextInput.Password
                    color: Theme.Colors.textPrimary
                    placeholderTextColor: Theme.Colors.textMuted
                    font.pixelSize: 13
                    leftPadding: 12
                    background: Rectangle {
                        radius: 10
                        color: Theme.Colors.popup
                        border { width: 1; color: password.activeFocus ? Theme.Colors.accent : Theme.Colors.alpha(Theme.Colors.accent, 0.25) }
                    }
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: join.clicked()
                    Keys.onEscapePressed: root.asking = null
                }
                ActionButton {
                    id: join
                    prominent: true
                    implicitHeight: 36
                    text: "Conectar"
                    enabled: password.text.length >= 8 || password.text.length === 5 || password.text.length === 13
                    onClicked: {
                        row.error = "";
                        row.modelData.connectWithPsk(password.text);
                    }
                }
            }
        }
    }

    component Switch: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled()
        width: 36; height: 20; radius: 10
        color: checked ? Theme.Colors.accent : Theme.Colors.switchTrack
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            x: toggle.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: toggle.checked ? Theme.Colors.background : Theme.Colors.switchThumb
            Behavior on x { NumberAnimation { duration: 140 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
        Accessible.role: Accessible.CheckBox
        Accessible.name: "Wi-Fi"
    }
}
