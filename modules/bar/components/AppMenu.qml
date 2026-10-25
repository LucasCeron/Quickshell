pragma ComponentBehavior: Bound
import "../../../common/theme" as Theme
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../../services" as Services

// Right-click menu of an open app, like a desktop task manager's: the app's own
// actions, a new window, where the window lives and how it behaves, and closing.
PopupWindow {
    id: root

    required property Item anchorItem
    property var toplevel: null
    signal dismissed()

    readonly property var entry: toplevel ? DesktopEntries.heuristicLookup(toplevel.appId) : null
    readonly property var hyprWindow: toplevel ? Hyprland.toplevels.values.find(window => window.wayland === toplevel) ?? null : null
    readonly property var state: hyprWindow?.lastIpcObject ?? ({})
    readonly property string selector: {
        const address = String(state.address ?? hyprWindow?.address ?? "");
        return address ? "address:" + (address.startsWith("0x") ? address : "0x" + address) : "";
    }
    readonly property var siblings: toplevel ? Services.Compositor.windows.filter(window => window.appId === toplevel.appId) : []
    readonly property int workspace: state.workspace?.id ?? -1
    // Many apps already offer their own "new window" action.
    readonly property bool ownNewWindow: (entry?.actions ?? []).some(action => /new.?window|nova.?janela/i.test(action.id + " " + action.name))

    function window(dispatcher: string, args: string): void {
        if (selector) Hyprland.dispatch(`hl.dsp.window.${dispatcher}({ ${args}${args ? ", " : ""}window = "${selector}" })`);
        Qt.callLater(Hyprland.refreshToplevels);
    }
    function run(action: var): void {
        action();
        root.dismissed();
    }

    onVisibleChanged: if (visible) Hyprland.refreshToplevels()

    implicitWidth: 280
    implicitHeight: menu.implicitHeight + 24
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

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.Colors.alpha(Theme.Colors.popup, 250 / 255)
        border { width: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 56 / 255) }

        Column {
            id: menu
            x: 12; y: 12
            width: parent.width - 24
            spacing: 2

            // The app and the window.
            Item {
                width: parent.width; height: 52
                IconImage {
                    id: appIcon
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 28
                    source: Quickshell.iconPath(root.entry?.icon || root.toplevel?.appId || "", "application-x-executable")
                }
                Column {
                    x: appIcon.x + appIcon.width + 12
                    width: parent.width - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: root.entry?.name || root.toplevel?.appId || "Aplicativo"
                        elide: Text.ElideRight
                        color: Theme.Colors.textPrimary
                        font { pixelSize: 13; weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width
                        text: root.toplevel?.title ?? ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Colors.textMuted
                        font.pixelSize: 11
                    }
                }
            }
            Separator {}

            // What the app itself offers in its desktop file.
            Repeater {
                model: root.entry?.actions ?? []
                delegate: MenuRow {
                    required property var modelData
                    text: modelData.name
                    onClicked: root.run(() => modelData.execute())
                }
            }
            MenuRow {
                visible: !!root.entry && !root.ownNewWindow
                text: "Nova janela"
                onClicked: root.run(() => root.entry.execute())
            }
            Separator {}

            Text {
                x: 10
                text: "Mover para a área"
                color: Theme.Colors.textMuted
                font.pixelSize: 11
                height: 24
                verticalAlignment: Text.AlignVCenter
            }
            Row {
                x: 6
                spacing: 4
                Repeater {
                    model: [1, 2, 3, 4, 5]
                    delegate: Chip {
                        required property int modelData
                        text: String(modelData)
                        selected: root.workspace === modelData
                        onClicked: root.run(() => root.window("move", `workspace = ${modelData}, follow = false`))
                    }
                }
                Chip {
                    text: "+"
                    onClicked: root.run(() => root.window("move", `workspace = "empty", follow = false`))
                }
            }
            Item { width: 1; height: 6 }

            MenuRow {
                text: "Flutuante"
                checkable: true
                checked: root.state.floating ?? false
                onClicked: root.run(() => root.window("float", `action = "toggle"`))
            }
            MenuRow {
                text: "Tela cheia"
                checkable: true
                checked: (root.state.fullscreen ?? 0) > 0
                onClicked: root.run(() => {
                    Services.Compositor.activate(root.toplevel);
                    root.window("fullscreen", `mode = "fullscreen", action = "toggle"`);
                })
            }
            MenuRow {
                // Hyprland only pins floating windows.
                visible: root.state.floating ?? false
                text: "Mostrar em todas as áreas"
                checkable: true
                checked: root.state.pinned ?? false
                onClicked: root.run(() => root.window("pin", `action = "toggle"`))
            }
            Separator {}

            MenuRow {
                visible: root.siblings.length > 1
                text: "Fechar todas as " + root.siblings.length + " janelas"
                danger: true
                onClicked: root.run(() => { for (const window of root.siblings) window.close(); })
            }
            MenuRow {
                text: "Fechar janela"
                danger: true
                onClicked: root.run(() => root.toplevel?.close())
            }
        }
    }

    component Separator: Rectangle {
        x: 8
        width: menu.width - 16
        height: 9
        color: "transparent"
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 0.12) }
    }

    component MenuRow: Rectangle {
        id: row
        property string text
        property bool checkable: false
        property bool checked: false
        property bool danger: false
        signal clicked()
        width: menu.width
        height: visible ? 34 : 0
        radius: 10
        color: rowMouse.containsMouse ? (danger ? Theme.Colors.alpha(Theme.Colors.danger, 0.14) : Theme.Colors.surfaceHigh) : "transparent"
        Text {
            x: 10
            width: parent.width - x - 40
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            elide: Text.ElideRight
            color: row.danger ? Theme.Colors.danger : Theme.Colors.textPrimary
            font.pixelSize: 13
        }
        // A small switch for window states.
        Rectangle {
            visible: row.checkable
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            width: 28; height: 16; radius: 8
            color: row.checked ? Theme.Colors.accent : Theme.Colors.switchTrack
            Rectangle {
                x: row.checked ? parent.width - width - 2 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6
                color: row.checked ? Theme.Colors.background : Theme.Colors.switchThumb
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    component Chip: Rectangle {
        id: chip
        property string text
        property bool selected: false
        signal clicked()
        width: (menu.width - 12 - 5 * 4) / 6; height: 32
        radius: 10
        color: selected ? Theme.Colors.alpha(Theme.Colors.accent, 0.18) : chipMouse.containsMouse ? Theme.Colors.surfaceHigh : Theme.Colors.surface
        border.width: selected ? 1 : 0
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 0.6)
        Text {
            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Theme.Colors.accent : Theme.Colors.textPrimary
            font { pixelSize: 12; weight: Font.DemiBold }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
