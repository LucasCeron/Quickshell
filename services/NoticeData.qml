import QtQuick
import Quickshell.Services.Notifications

// One entry of the notification history. It follows the live notification while
// the sender keeps it, and keeps a copy of its fields so it survives restarts.
QtObject {
    id: data
    property Notification notification: null
    property string key
    property real time: Date.now()
    property string appName
    property string appIcon
    property string image
    property string summary
    property string body
    property int urgency: NotificationUrgency.Normal
    property var actions: []
    readonly property bool critical: urgency === NotificationUrgency.Critical
    // "default" is what the app does when the notification itself is clicked.
    readonly property var defaultAction: actions.find(action => action.identifier === "default") ?? null
    readonly property var buttons: actions.filter(action => action.identifier !== "default" && action.text !== "")
    signal closedBySender()

    function sync(): void {
        appName = notification.appName;
        appIcon = notification.appIcon;
        image = notification.image;
        summary = notification.summary;
        body = notification.body;
        urgency = notification.urgency;
        copyActions();
    }
    function copyActions(): void {
        actions = Array.from(notification?.actions ?? []).map(action => ({ identifier: action.identifier, text: action.text, invoke: () => action.invoke() }));
    }
    // Images served by the notification server only exist during this session.
    function persistent(source: string): string {
        return persists(source) ? source : "";
    }
    function persists(source: string): bool {
        return source.startsWith("/") || source.startsWith("file://") || source.startsWith("image://icon/") || (source !== "" && !source.includes(":"));
    }
    function serialize(): var {
        return { key: key, time: time, appName: appName, appIcon: persistent(appIcon), image: persistent(image),
            summary: summary, body: body, urgency: urgency };
    }

    readonly property Connections link: Connections {
        target: data.notification
        function onAppNameChanged(): void { data.appName = data.notification.appName; }
        function onAppIconChanged(): void { data.appIcon = data.notification.appIcon; }
        function onImageChanged(): void { data.image = data.notification.image; }
        function onSummaryChanged(): void { data.summary = data.notification.summary; }
        function onBodyChanged(): void { data.body = data.notification.body; }
        function onUrgencyChanged(): void { data.urgency = data.notification.urgency; }
        function onActionsChanged(): void { data.copyActions(); }
        function onClosed(): void { data.notification = null; data.actions = []; data.closedBySender(); }
    }
}
