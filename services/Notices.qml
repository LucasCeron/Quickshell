pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../config" as Config

Singleton {
    id: root
    // Newest first. Entries outlive the sender and are restored on the next start.
    property var items: []
    readonly property int count: items.length
    readonly property var groups: {
        const byApp = new Map();
        for (const item of items) {
            const app = item.appName || "Aplicativo";
            if (!byApp.has(app)) byApp.set(app, { app: app, items: [] });
            byApp.get(app).items.push(item);
        }
        return Array.from(byApp.values());
    }
    property var toasts: []
    readonly property bool doNotDisturb: Config.Settings.doNotDisturb
    // Popups stay out of the way of fullscreen games and videos; critical ones still show.
    readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false
    property real now: Date.now()
    property bool loaded: false
    property int serial: 0
    signal arrived()

    function toggleQuiet(): void { Config.Settings.doNotDisturb = !Config.Settings.doNotDisturb; }
    onDoNotDisturbChanged: {
        if (doNotDisturb) toasts = toasts.filter(toast => toast.data.critical);
        if (Config.Settings.ready)
            Toaster.show(doNotDisturb ? "Não perturbe ligado" : "Não perturbe desligado",
                doNotDisturb ? "Os avisos ficam guardados, sem aparecer na tela" : "Os avisos voltam a aparecer", "bell.svg");
    }
    onItemsChanged: {
        const remaining = toasts.filter(toast => items.includes(toast.data));
        if (remaining.length !== toasts.length) toasts = remaining;
        if (loaded) saveTimer.restart();
    }

    function age(time: real): string {
        const minutes = Math.floor((now - time) / 60000);
        if (minutes < 1) return "agora";
        if (minutes < 60) return minutes + " min";
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return hours + " h";
        return Math.floor(hours / 24) + " d";
    }
    function iconFor(data: var): string {
        const icon = data?.appIcon ?? "";
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.includes(":")) return icon;
        const name = icon || (DesktopEntries.heuristicLookup(data?.appName ?? "")?.icon ?? "");
        return name ? Quickshell.iconPath(name, true) : "";
    }
    function imageFor(data: var): string {
        const image = data?.image ?? "";
        return image.startsWith("/") ? "file://" + image : image;
    }

    function cacheFor(data: var): string { return Quickshell.cachePath("notices/" + data.key + ".png"); }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.cachePath("notices")])
    function remove(data: var): void {
        if (!items.includes(data)) return;
        items = items.filter(item => item !== data);
        discard(data);
    }
    function discard(data: var): void {
        if (data.image === cacheFor(data)) Quickshell.execDetached(["rm", "-f", data.image]);
        data.notification?.dismiss();
        data.destroy();
    }
    function dismiss(data: var): void { remove(data); }
    function clearApp(app: string): void {
        for (const item of items.filter(item => (item.appName || "Aplicativo") === app)) remove(item);
    }
    function clear(): void { for (const item of items.slice()) remove(item); }

    function showToast(data: var): void {
        if ((doNotDisturb || fullscreen) && !data.critical) return;
        const timeout = data.notification?.expireTimeout ?? 0;
        const lifetime = timeout > 0 ? Math.max(2000, Math.min(12000, timeout)) : 5500;
        const toast = { data: data, expires: data.critical ? 0 : Date.now() + lifetime, remaining: lifetime, held: false };
        toasts = [toast].concat(toasts.filter(item => item.data !== data)).slice(0, 3);
    }
    function hideToast(data: var): void { toasts = toasts.filter(item => item.data !== data); }
    // The countdown pauses while the pointer is over a toast or dragging it.
    function holdToast(data: var, held: bool): void {
        const toast = toasts.find(item => item.data === data);
        if (!toast || toast.held === held || toast.data.critical) return;
        toast.held = held;
        if (held) toast.remaining = Math.max(0, toast.expires - Date.now());
        else toast.expires = Date.now() + Math.max(1500, toast.remaining);
    }

    function create(properties: var): var {
        const data = entry.createObject(root, properties);
        data.closedBySender.connect(() => root.remove(data));
        return data;
    }
    function adopt(notification: var): var {
        const data = create({ notification: notification, key: Date.now() + "-" + (serial++), time: Date.now() });
        data.sync();
        return data;
    }
    function bound(list: var): var {
        for (const old of list.slice(100)) discard(old);
        return list.slice(0, 100);
    }

    Component { id: entry; NoticeData {} }
    Timer { interval: 30000; repeat: true; running: root.count > 0; triggeredOnStart: true; onTriggered: root.now = Date.now() }
    Timer {
        interval: 250
        repeat: true
        running: root.toasts.length > 0
        onTriggered: {
            const remaining = root.toasts.filter(item => item.held || !item.expires || item.expires > Date.now());
            if (remaining.length !== root.toasts.length) root.toasts = remaining;
        }
    }
    Timer {
        id: saveTimer
        interval: 800
        onTriggered: storage.setText(JSON.stringify(root.items.map(item => item.serialize()), null, 1) + "\n")
    }

    FileView {
        id: storage
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        atomicWrites: true
        onLoaded: root.restore(storage.text())
        onLoadFailed: root.restore("[]")
    }
    function restore(text: string): void {
        let saved = [];
        try { saved = JSON.parse(text); } catch (error) {}
        if (!Array.isArray(saved)) saved = [];
        const live = server.trackedNotifications.values.slice();
        const restored = [];
        for (const fields of saved) {
            if (typeof fields !== "object" || !fields || typeof fields.summary !== "string") continue;
            if (root.items.some(item => item.key === fields.key)) continue;
            const data = create({ key: String(fields.key ?? Date.now() + "-" + (serial++)), time: Number(fields.time) || Date.now(),
                appName: String(fields.appName ?? ""), appIcon: String(fields.appIcon ?? ""), image: String(fields.image ?? ""),
                summary: fields.summary, body: String(fields.body ?? ""), urgency: Number(fields.urgency) || 0 });
            restored.push(data);
        }
        items = bound(items.concat(restored).sort((a, b) => b.time - a.time));
        for (const notification of live) reattach(notification);
        loaded = true;
    }
    // After a reload the server keeps its notifications; reattach them so actions keep working.
    function reattach(notification: var): void {
        if (items.some(item => item.notification === notification)) return;
        const match = items.find(item => !item.notification && item.summary === notification.summary && item.appName === notification.appName);
        if (match) { match.notification = notification; match.sync(); }
        else items = bound([adopt(notification)].concat(items).sort((a, b) => b.time - a.time));
    }

    IpcHandler {
        target: "notifications"
        function quiet(): void { root.toggleQuiet(); }
        function clear(): void { root.clear(); }
        function status(): string { return JSON.stringify({ count: root.count, toasts: root.toasts.length, quiet: root.doNotDisturb }); }
    }
    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (notification.lastGeneration) { if (root.loaded) root.reattach(notification); return; }
            const data = root.adopt(notification);
            root.items = root.bound([data].concat(root.items));
            root.arrived();
            root.showToast(data);
        }
    }
}
