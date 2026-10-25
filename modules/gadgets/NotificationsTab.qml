pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../services" as Services
import "../../common/theme" as Theme
import "../../common/components"
import "../notifications"
import "components"

// A phone's notification shade: time and date on top, do not disturb, then the
// notifications stacked by app. A stack opens with a click; "Limpar tudo" at the end.
Column {
    id: root
    spacing: 14
    // Apps whose stack is open.
    property var expanded: ({})
    function toggleGroup(app: string): void {
        const next = Object.assign({}, expanded);
        next[app] = !next[app];
        expanded = next;
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Item {
        width: parent.width; height: 74
        Column {
            spacing: 0
            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.Colors.textPrimary
                font { pixelSize: 44; weight: Font.Light }
            }
            Text {
                text: {
                    const day = Qt.locale("pt_BR").toString(clock.date, "dddd, d 'de' MMMM");
                    return day.charAt(0).toUpperCase() + day.slice(1);
                }
                color: Theme.Colors.textMuted
                font.pixelSize: 13
            }
        }
    }

    // Do not disturb, as a phone's quick toggle.
    Rectangle {
        width: parent.width; height: 52
        radius: 26
        color: Services.Notices.doNotDisturb ? Theme.Colors.alpha(Theme.Colors.accent, quietMouse.containsMouse ? 0.22 : 0.15)
            : quietMouse.containsMouse ? Theme.Colors.surfaceHigh : Theme.Colors.surface
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            id: quietBubble
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            color: Services.Notices.doNotDisturb ? Theme.Colors.accent : Theme.Colors.alpha(Theme.Colors.accent, 0.12)
            Icon {
                anchors.centerIn: parent
                width: 18; height: 18
                source: Quickshell.shellPath("common/assets/icons/bell.svg")
                color: Services.Notices.doNotDisturb ? Theme.Colors.background : Theme.Colors.accent
            }
        }
        Column {
            x: quietBubble.x + quietBubble.width + 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { text: "Não perturbe"; color: Theme.Colors.textPrimary; font { pixelSize: 13; weight: Font.DemiBold } }
            Text {
                text: Services.Notices.doNotDisturb ? "Avisos guardados aqui, em silêncio" : "Avisos aparecem na tela"
                color: Theme.Colors.textMuted; font.pixelSize: 11
            }
        }
        Text {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            text: Services.Notices.count === 0 ? "" : Services.Notices.count === 1 ? "1 aviso" : Services.Notices.count + " avisos"
            color: Theme.Colors.textMuted; font.pixelSize: 11
        }
        MouseArea {
            id: quietMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Services.Notices.toggleQuiet()
        }
    }

    Item {
        width: parent.width; height: 240
        visible: Services.Notices.count === 0
        Column {
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56; height: 56; radius: 28
                color: Theme.Colors.alpha(Theme.Colors.accent, 0.12)
                Icon {
                    anchors.centerIn: parent
                    width: 26; height: 26
                    source: Quickshell.shellPath("common/assets/icons/bell.svg")
                }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sem notificações"; color: Theme.Colors.textPrimary; font { pixelSize: 16; weight: Font.DemiBold } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Tudo em dia por aqui."; color: Theme.Colors.textMuted; font.pixelSize: 12 }
        }
    }

    Repeater {
        model: ScriptModel { values: Services.Notices.groups; objectProp: "app" }
        delegate: Column {
            id: group
            required property var modelData
            readonly property var notices: Services.Notices.groups.find(g => g.app === modelData.app)?.items ?? []
            readonly property bool open: notices.length < 2 || !!root.expanded[modelData.app]
            width: root.width
            spacing: 8

            // An open stack gets a header to fold it back or clear it.
            Item {
                visible: group.notices.length > 1 && group.open
                width: parent.width; height: visible ? 30 : 0
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    text: group.modelData.app
                    color: Theme.Colors.textPrimary
                    font { pixelSize: 13; weight: Font.DemiBold }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    ActionButton { implicitHeight: 30; text: "Mostrar menos"; onClicked: root.toggleGroup(group.modelData.app) }
                    ActionButton { implicitHeight: 30; text: "×"; hint: "Limpar " + group.modelData.app; onClicked: Services.Notices.clearApp(group.modelData.app) }
                }
            }

            Repeater {
                model: ScriptModel { values: group.open ? group.notices : group.notices.slice(0, 1) }
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    // A closed stack shows the cards behind the newest one peeking out.
                    readonly property int behind: group.open ? 0 : Math.min(2, group.notices.length - 1)
                    width: group.width
                    height: card.height + behind * 7
                    Repeater {
                        model: slot.behind
                        delegate: Rectangle {
                            required property int index
                            readonly property int depth: slot.behind - index
                            x: depth * 10
                            y: card.height - 22 + depth * 7
                            width: slot.width - depth * 20
                            height: 22
                            radius: 14
                            color: Theme.Colors.alpha(Theme.Colors.surface, 1 - depth * 0.3)
                        }
                    }
                    NoticeCard {
                        id: card
                        notice: slot.modelData
                        width: slot.width
                        stacked: group.open ? 0 : group.notices.length - 1
                        onActivated: {
                            if (!group.open) root.toggleGroup(group.modelData.app);
                            else if (card.notice.defaultAction) { card.notice.defaultAction.invoke(); GadgetsState.open = false; }
                        }
                        onSwiped: Services.Notices.dismiss(card.notice)
                        onCloseRequested: Services.Notices.dismiss(card.notice)
                    }
                }
            }
        }
    }

    Item {
        width: parent.width; height: 56
        visible: Services.Notices.count > 0
        ActionButton {
            anchors.centerIn: parent
            text: "Limpar tudo"
            onClicked: Services.Notices.clear()
        }
    }
}
