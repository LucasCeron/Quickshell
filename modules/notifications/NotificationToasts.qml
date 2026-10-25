pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services" as Services
import "../gadgets"

// Notification popups in the bottom-right corner, stacked like Sonner: the newest
// sits in the corner and older ones peek out above it, smaller. Hovering the
// stack fans it out so every card can be read, and pauses all the countdowns.
PanelWindow {// qmllint disable uncreatable-type
    id: root
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { bottom: true; right: true }
    margins { bottom: Services.Compositor.gaps; right: Services.Compositor.gaps } // qmllint disable unqualified unresolved-type
    implicitWidth: 360
    // Tall enough for the fanned-out stack; the mask keeps the empty part click-through.
    implicitHeight: Math.max(1, heightOf(cards))
    visible: cards.length > 0 && !(GadgetsState.open && GadgetsState.tab === 0)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: hitArea }
    WlrLayershell.namespace: "config-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int gap: 10
    // How much of each older card shows above the one in front while collapsed.
    readonly property int peek: 14
    readonly property int depth: 3
    readonly property bool expanded: hover.hovered
    // Toasts that are up, newest first.
    readonly property var live: Services.Notices.toasts.map(toast => toast.data)
    // What is drawn: the live toasts plus the ones still playing their exit.
    property var cards: []
    // Card heights by notification key, so each card can place itself.
    property var heights: ({})
    readonly property real frontHeight: live.length > 0 ? heights[live[0].key] ?? 0 : 0

    function heightOf(list: var): real {
        return list.length === 0 ? 0 : offsetOf(list, list.length) - gap;
    }
    // Room taken by the first `count` cards of the list, each followed by a gap.
    function offsetOf(list: var, count: int): real {
        return list.slice(0, count).reduce((sum, data) => sum + (heights[data.key] ?? 0) + gap, 0);
    }
    function measure(data: var, height: real): void {
        if (heights[data.key] === height) return;
        const next = Object.assign({}, heights);
        next[data.key] = height;
        heights = next;
    }
    function drop(data: var): void {
        cards = cards.filter(card => card !== data);
        const next = Object.assign({}, heights);
        delete next[data.key];
        heights = next;
    }
    // Entries deleted from the history are destroyed right after, so they leave without an exit.
    function sync(): void {
        const kept = cards.filter(data => Services.Notices.items.includes(data));
        cards = live.filter(data => !kept.includes(data)).concat(kept);
    }
    onLiveChanged: sync()
    Connections {
        target: Services.Notices
        function onItemsChanged(): void { root.sync(); }
    }

    Item {
        id: hitArea
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: root.live.length === 0 ? 0
            : root.expanded ? root.heightOf(root.live)
            : root.frontHeight + root.peek * (Math.min(root.live.length, root.depth) - 1)
    }

    Item {
        anchors.fill: parent
        HoverHandler { id: hover }

        // Cards hang from the bottom edge, so a taller window never moves them.
        Item {
            id: corner
            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                model: ScriptModel { values: root.cards }
                delegate: Item {
                    id: toast
                    required property var modelData
                    readonly property bool leaving: !root.live.includes(modelData)
                    readonly property int liveSlot: root.live.indexOf(modelData)
                    // A leaving card keeps its place while it fades out.
                    property int slot: 0
                    property bool touched: false
                    readonly property bool holding: root.expanded || touched
                    property real rise

                    width: corner.width
                    height: card.implicitHeight
                    // A leaving card stays on top while it slides away.
                    z: leaving ? 1 : -slot
                    y: root.expanded ? -(root.offsetOf(root.live, slot) + height)
                        : -(root.frontHeight + root.peek * slot)
                    scale: root.expanded ? 1 : 1 - 0.05 * slot
                    transformOrigin: Item.Top
                    opacity: leaving || (!root.expanded && slot >= root.depth) ? 0 : 1
                    transform: Translate { y: (1 - toast.rise) * toast.height; x: toast.leaving ? toast.width / 3 : 0 }
                    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    NumberAnimation on rise { from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }

                    onLiveSlotChanged: if (liveSlot >= 0) slot = liveSlot
                    onHeightChanged: root.measure(modelData, height)
                    onHoldingChanged: Services.Notices.holdToast(modelData, holding)
                    Component.onCompleted: {
                        slot = Math.max(0, liveSlot);
                        root.measure(modelData, height);
                        if (holding) Services.Notices.holdToast(modelData, true);
                    }
                    Timer { running: toast.leaving; interval: 220; onTriggered: root.drop(toast.modelData) }

                    NoticeCard {
                        id: card
                        notice: toast.modelData
                        popup: true
                        width: parent.width
                        opacity: toast.rise
                        // Only the front card is readable while collapsed, as in Sonner.
                        contentOpacity: root.expanded || toast.slot === 0 ? 1 : 0
                        Behavior on contentOpacity { NumberAnimation { duration: 200 } }
                        onHeld: held => toast.touched = held
                        onSwiped: Services.Notices.hideToast(toast.modelData)
                        onCloseRequested: Services.Notices.hideToast(toast.modelData)
                        onActivated: {
                            if (toast.modelData.defaultAction) toast.modelData.defaultAction.invoke();
                            else GadgetsState.show(root.screen?.name ?? "", 0);
                            Services.Notices.hideToast(toast.modelData);
                        }
                    }
                }
            }
        }
    }
}
