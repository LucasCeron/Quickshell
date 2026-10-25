pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../../services" as Services
import "../../common/theme" as Theme
import "../gadgets/components"

// One notification, styled like a phone's: app, age and a close button on top,
// the message below and the picture as a thumbnail on the right. Shared by the
// popups and the history. Drag it sideways or middle-click it to get rid of it;
// the countdown of a popup waits while it is held.
Item {
    id: root
    required property var notice
    property bool popup: false
    // Notifications stacked behind this one in a collapsed group.
    property int stacked: 0
    // Lets a stack blank the message of a card tucked behind another one.
    property real contentOpacity: 1
    // Icon themes hand the app icon over as the "image"; that is not a picture.
    readonly property bool iconAsImage: (notice.image ?? "").startsWith("image://icon/")
    readonly property string image: iconAsImage ? "" : Services.Notices.imageFor(notice)
    readonly property string icon: iconAsImage ? notice.image : Services.Notices.iconFor(notice)
    readonly property bool hovered: area.containsMouse
    signal swiped()
    signal closeRequested()
    signal activated()
    signal held(bool held)

    implicitHeight: card.height
    height: implicitHeight

    Rectangle {
        id: card
        width: root.width
        height: content.implicitHeight + 28
        radius: 22
        color: root.popup ? Theme.Colors.alpha(Theme.Colors.popup, 0.97)
            : area.containsMouse ? Theme.Colors.surfaceHigh : Theme.Colors.surface
        border.width: root.popup || root.notice.critical ? 1 : 0
        border.color: Theme.Colors.alpha(root.notice.critical ? Theme.Colors.danger : Theme.Colors.accent, root.popup ? 0.3 : 0.45)
        opacity: 1 - Math.min(0.8, Math.abs(x) / width)
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on x { enabled: !area.drag.active && !fling.running; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        NumberAnimation {
            id: fling
            target: card; property: "x"
            duration: 180; easing.type: Easing.InCubic
            onFinished: root.swiped()
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            drag.target: card
            drag.axis: Drag.XAxis
            drag.threshold: 6
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onContainsMouseChanged: root.held(containsMouse || pressed)
            onPressedChanged: root.held(containsMouse || pressed)
            onReleased: {
                if (Math.abs(card.x) > card.width * 0.3) {
                    fling.to = (card.x > 0 ? 1 : -1) * card.width * 1.1;
                    fling.start();
                } else card.x = 0;
            }
            onClicked: event => {
                if (event.button === Qt.MiddleButton) root.closeRequested();
                else if (Math.abs(card.x) < 4) root.activated();
            }
        }

        Column {
            id: content
            x: 16; y: 14
            opacity: root.contentOpacity
            width: parent.width - 32
            spacing: 8

            // App, age and the close button.
            Item {
                width: parent.width; height: 20
                Rectangle {
                    id: appBadge
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; radius: 6
                    color: appIcon.visible ? "transparent"
                        : root.notice.critical ? Theme.Colors.alpha(Theme.Colors.danger, 0.2) : Theme.Colors.alpha(Theme.Colors.accent, 0.16)
                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        source: root.icon
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: (root.notice.appName || "?").charAt(0).toUpperCase()
                        color: root.notice.critical ? Theme.Colors.danger : Theme.Colors.accent
                        font { pixelSize: 11; weight: Font.Bold }
                    }
                }
                Text {
                    x: appBadge.width + 8
                    width: parent.width - x - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.notice.appName || "Aplicativo") + "  ·  " + Services.Notices.age(root.notice.time)
                        + (root.stacked > 0 ? "  ·  +" + root.stacked : "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.notice.critical ? Theme.Colors.danger : Theme.Colors.textSecondary
                    font { pixelSize: 11; weight: Font.Medium }
                }
                ActionButton {
                    id: closeButton
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; padding: 0
                    implicitHeight: 24
                    opacity: root.popup || root.hovered || closeButton.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    text: "×"
                    hint: root.popup ? "Ocultar aviso" : "Dispensar notificação"
                    onClicked: root.closeRequested()
                }
            }

            // The message, with the picture on the right.
            Item {
                width: parent.width
                height: Math.max(texts.implicitHeight, thumbnail.visible ? thumbnail.height : 0)
                Column {
                    id: texts
                    width: parent.width - (thumbnail.visible ? thumbnail.width + 12 : 0)
                    spacing: 3
                    Text {
                        width: parent.width
                        text: root.notice.summary
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font { pixelSize: 14; weight: Font.DemiBold }
                        color: Theme.Colors.textPrimary
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.notice.body
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: root.popup ? 3 : 5
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: Theme.Colors.textSecondary
                    }
                }
                ClippingRectangle {
                    id: thumbnail
                    anchors.right: parent.right
                    width: 52; height: 52
                    radius: 12
                    color: Theme.Colors.surfaceHigh
                    visible: picture.status === Image.Ready
                    Image {
                        id: picture
                        anchors.fill: parent
                        source: root.image
                        sourceSize: Qt.size(104, 104)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        // Images served for this session only are cached, so the history keeps them.
                        onStatusChanged: {
                            if (status !== Image.Ready || !Window.window || root.notice.persists(root.notice.image)) return;
                            const path = Services.Notices.cacheFor(root.notice);
                            grabToImage(result => { if (result.saveToFile(path)) root.notice.image = path; }, Qt.size(104, 104));
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                visible: root.notice.buttons.length > 0
                Repeater {
                    model: root.notice.buttons
                    delegate: ActionButton {
                        required property var modelData
                        implicitHeight: 32
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
