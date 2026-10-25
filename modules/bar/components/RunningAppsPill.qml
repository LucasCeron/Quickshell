pragma ComponentBehavior: Bound
import "../../../common/theme" as Theme
import "../../../common/components"
import QtQuick
import "../../../services" as Services
import "../../../config" as Config

Rectangle {
    id: root

    property real availableHeight: 1000
    readonly property int maxVisible: Math.max(1, Math.min(Config.Settings.maxVisibleApps,
        Math.floor((availableHeight - 56) / 44)))

    readonly property var windows: Services.Compositor.windows

    readonly property var visibleWindows: {
        const visible = windows.slice(0, maxVisible);
        const focused = windows.find(window => window.activated);
        if (focused && !visible.includes(focused))
            visible[maxVisible - 1] = focused;
        return visible;
    }

    readonly property int windowCount:
        windows.length

    readonly property var hiddenWindows: windows.filter(window => !visibleWindows.includes(window))

    readonly property int overflowCount:
        Math.max(0, windowCount - maxVisible)

    signal overflowTriggered()
    // Right click on an app: the window and its button, to anchor the menu.
    signal menuRequested(var toplevel, Item button)
    readonly property alias overflowButton: overflowButton

    implicitWidth: 52

    implicitHeight:
        appsColumn.implicitHeight + 12

    radius: 26

    color: Theme.Colors.pill

    border {
        width: 1
        color: Theme.Colors.alpha(Theme.Colors.accent, 36/255)
    }

    readonly property int focusedIndex: {
        for (let i = 0; i < appsRepeater.count; i++) {
            if ((appsRepeater.itemAt(i) as RunningAppButton)?.active)
                return i
        }
        return -1
    }

    readonly property var appButtons: {
        const apps = []
        for (let i = 0; i < appsRepeater.count; i++)
            apps.push(appsRepeater.itemAt(i))
        return apps
    }

    // Hover: skips the focused app, which has its own ring.
    CellHighlight {
        anchors.fill: parent

        items: root.appButtons.concat([overflowButton])
        ignoredIndex: root.focusedIndex
        tileRadius: 20
    }

    // The focused app's ring. It divides its way to the next focused window when
    // focus moves elsewhere, and jumps straight there when it moves from here.
    CellHighlight {
        id: focusRing

        anchors.fill: parent

        items: root.appButtons
        restIndex: root.focusedIndex
        followsHover: false
        // A smaller sphere would hide the ring behind the app icon while it travels.
        sphereScale: 1
        tileRadius: 20
        color: Theme.Colors.alpha(Theme.Colors.accent, 56 / 255)
        outlineColor: Theme.Colors.primary
        outlineWidth: 1.5
    }

    Connections {
        target: Services.Compositor

        function onActivationRequested(): void {
            focusRing.jumpNext()
        }
    }

    Column {
        id: appsColumn

        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }

        spacing: 4

        Repeater {
            id: appsRepeater

            model: root.maxVisible

            delegate: RunningAppButton {
                id: appButton
                required property int index
                toplevel: root.visibleWindows[index] || null
                onMenuRequested: root.menuRequested(appButton.toplevel, appButton)
            }
        }

        Item {
            id: overflowButton

            readonly property bool hovered: overflowMouse.containsMouse
            readonly property bool pressed: overflowMouse.pressed

            visible: root.overflowCount > 0

            width: 40
            height: 40

            Text {
                anchors.centerIn: parent

                text: "+" + root.overflowCount

                color: Theme.Colors.accent

                font {
                    pixelSize: 11
                    weight: Font.DemiBold
                }
            }

            MouseArea {
                id: overflowMouse

                anchors.fill: parent

                hoverEnabled: true

                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.overflowTriggered()
                }
            }
        }
    }
}
