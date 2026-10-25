pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    property int maxVisibleApps: Defaults.maxVisibleApps
    property string launcherCommand: Defaults.launcherCommand
    property string terminalCommand: Defaults.terminalCommand
    property string networkCommand: Defaults.networkCommand
    property string mixerCommand: Defaults.mixerCommand
    property string monoFamily: Defaults.monoFamily
    property string themeName: "system"
    property int barWidth: 68
    property real barOpacity: 245 / 255
    property int barRadius: 26
    property bool showClock: true
    property bool doNotDisturb: false
    property string wallpaperFolder: ""
    property string wallpaperPath: ""
    property bool ready: false
    property string saveError: ""

    function save(): void { if (ready) saveTimer.restart(); }
    function resetBar(): void {
        maxVisibleApps = Defaults.maxVisibleApps;
        barWidth = 68;
        barOpacity = 245 / 255;
        barRadius = 26;
        showClock = true;
    }
    onThemeNameChanged: save()
    onMaxVisibleAppsChanged: save()
    onBarWidthChanged: save()
    onBarOpacityChanged: save()
    onBarRadiusChanged: save()
    onShowClockChanged: save()
    onDoNotDisturbChanged: save()
    onWallpaperFolderChanged: save()
    onWallpaperPathChanged: save()

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: preferences.setText(JSON.stringify({
            themeName: root.themeName, maxVisibleApps: root.maxVisibleApps,
            barWidth: root.barWidth, barOpacity: root.barOpacity, barRadius: root.barRadius,
            showClock: root.showClock,
            doNotDisturb: root.doNotDisturb,
            wallpaperFolder: root.wallpaperFolder, wallpaperPath: root.wallpaperPath
        }, null, 2) + "\n")
    }

    FileView {
        id: preferences
        path: Quickshell.shellPath("preferences.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(preferences.text());
                if (["system", "gold", "lavender", "ocean", "rose", "forest"].includes(data.themeName)) root.themeName = data.themeName;
                for (const key of ["showClock", "doNotDisturb"])
                    if (typeof data[key] === "boolean") root[key] = data[key];
                for (const key of ["wallpaperFolder", "wallpaperPath"])
                    if (typeof data[key] === "string") root[key] = data[key];
                const ranges = { maxVisibleApps: [3, 8], barWidth: [64, 88], barOpacity: [0.65, 1], barRadius: [12, 32] };
                for (const key of Object.keys(ranges))
                    if (typeof data[key] === "number" && isFinite(data[key]))
                        root[key] = Math.max(ranges[key][0], Math.min(ranges[key][1], data[key]));
            } catch (error) {
                root.saveError = "Preferências inválidas; usando os padrões.";
            }
            root.ready = true;
        }
        onLoadFailed: root.ready = true
        onSaved: root.saveError = ""
        onSaveFailed: root.saveError = "Não foi possível salvar as preferências."
    }
}
