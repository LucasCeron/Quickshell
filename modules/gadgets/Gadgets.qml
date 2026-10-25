pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../../common/theme" as Theme
import "../../config" as Config
import "components"

// The page of a sidebar button (notifications, music, system, tools), as a popup
// of the bar like sound and network: next to its button, closed by a click
// outside or Esc.
PopupWindow {
    id: root

    required property Item anchorItem
    required property string screenName
    property real screenHeight: 1080
    readonly property var titles: ["", "Ferramentas", "Música", "Ferramentas", "Sistema"]
    readonly property var subtitles: ["", "Captura, áreas de trabalho e aparência", "Sua trilha sonora, por inteiro", "Captura, áreas de trabalho e aparência", "Atalhos rápidos e recursos"]
    readonly property real maxHeight: Math.round(screenHeight * 0.8)

    visible: GadgetsState.open && GadgetsState.screenName === screenName
    // A click outside dismisses the popup; keep the shared state in step.
    onVisibleChanged: {
        if (visible) card.forceActiveFocus();
        else if (GadgetsState.open && GadgetsState.screenName === screenName) GadgetsState.dismiss();
    }

    implicitWidth: GadgetsState.drawerWidth
    implicitHeight: Math.min(maxHeight, 40 + (header.visible ? header.height + 16 : 0) + content.contentHeight + (saveError.visible ? 32 : 0))
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
        id: card
        anchors.fill: parent
        radius: 24
        color: Theme.Colors.alpha(Theme.Colors.popup, 250 / 255)
        border { width: 1; color: Theme.Colors.alpha(Theme.Colors.accent, 56 / 255) }
        focus: true
        Keys.onEscapePressed: GadgetsState.open = false

        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 16
            // The notifications page draws its own phone-like header.
            Column {
                id: header
                visible: GadgetsState.tab !== 0
                width: parent.width
                spacing: 4
                Text { text: root.titles[GadgetsState.tab]; color: Theme.Colors.textPrimary; font.pixelSize: 20; font.weight: Font.DemiBold }
                Text { text: root.subtitles[GadgetsState.tab]; color: Theme.Colors.textMuted; font.pixelSize: 12 }
            }
            Flickable {
                id: content
                width: parent.width
                height: parent.height - (header.visible ? header.height + 16 : 0) - (saveError.visible ? 32 : 0)
                contentWidth: width
                contentHeight: (pageLoader.item as Item)?.implicitHeight ?? 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Loader {
                    id: pageLoader
                    width: content.width
                    // Pages stop their timers and samplers once the popup is gone.
                    active: root.visible
                    sourceComponent: [notificationsPage, toolsPage, mediaPage, toolsPage, systemPage][GadgetsState.tab]
                    onLoaded: content.contentY = 0
                }
            }
            Text {
                id: saveError
                visible: text !== ""
                text: Config.Settings.saveError
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.Colors.danger
                font.pixelSize: 11
            }
        }
    }
    Component { id: mediaPage; MediaTab {} }
    Component { id: notificationsPage; NotificationsTab {} }
    Component { id: toolsPage; ToolsTab {} }
    Component { id: systemPage; SystemTab {} }
}
