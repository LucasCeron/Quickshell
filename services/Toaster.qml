pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Short messages from the shell itself (do not disturb, audio devices, keep awake).
// They are not notifications: they never enter the history and ignore do not disturb.
Singleton {
    id: root
    property var toasts: []
    property int serial: 0

    function show(title: string, body: string, icon: string): void {
        const toast = { id: serial++, title: title, body: body, icon: icon, expires: Date.now() + 3200 };
        toasts = [toast].concat(toasts.filter(item => item.title !== title)).slice(0, 3);
    }
    function hide(id: int): void { toasts = toasts.filter(item => item.id !== id); }

    Timer {
        interval: 250
        repeat: true
        running: root.toasts.length > 0
        onTriggered: {
            const remaining = root.toasts.filter(item => item.expires > Date.now());
            if (remaining.length !== root.toasts.length) root.toasts = remaining;
        }
    }
    IpcHandler {
        target: "toast"
        function show(title: string, body: string): void { root.show(title, body, "bell.svg"); }
    }
}
