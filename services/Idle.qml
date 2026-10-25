pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Keeps the session awake while enabled, like caffeine. It lasts until the shell restarts.
Singleton {
    id: root
    property bool inhibited: false
    property real since: 0
    function toggle(): void { inhibited = !inhibited; }
    onInhibitedChanged: {
        since = inhibited ? Date.now() : 0;
        Toaster.show(inhibited ? "Manter acordado ligado" : "Manter acordado desligado",
            inhibited ? "A tela não vai apagar nem bloquear sozinha" : "O gerenciamento de energia voltou ao normal", "coffee.svg");
    }

    IdleInhibitor {
        enabled: root.inhibited
        window: PanelWindow {// qmllint disable uncreatable-type
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.namespace: "config-idle"
        }
    }
    IpcHandler {
        target: "idle"
        function toggle(): void { root.toggle(); }
        function status(): bool { return root.inhibited; }
    }
}
