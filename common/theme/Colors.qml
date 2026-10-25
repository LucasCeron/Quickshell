pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../config" as Config

Singleton {
    id: root

    readonly property string configHome: Config.Settings.configHome
    property var systemColors: ({})
    property var hyprColors: ({})
    readonly property var selectedColors: Presets.palette(Config.Settings.themeName)

    function parsePalette(text: string): var {
        try {
            const data = JSON.parse(text);
            return data !== null && typeof data === "object" && !Array.isArray(data) ? data : {};
        } catch (error) {
            return {};
        }
    }

    function valid(value: var): bool {
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value);
    }

    function resolve(name: string, fallback: string): color {
        if (valid(root.selectedColors[name])) return root.selectedColors[name];
        if (Config.Settings.themeName !== "system") return fallback;
        if (valid(root.hyprColors[name])) return root.hyprColors[name];
        if (valid(root.systemColors[name])) return root.systemColors[name];
        return fallback;
    }

    function alpha(value: color, opacity: real): color {
        return Qt.rgba(value.r, value.g, value.b, opacity);
    }

    readonly property color primary: resolve("primary", "#FFDB89")
    readonly property color hover: resolve("hover", "#FFE3A0")
    readonly property color pressed: resolve("pressed", "#E6C476")
    readonly property color accent: resolve("accent", "#E5B94F")
    readonly property color accentHover: resolve("accentHover", "#FFE6A7")
    readonly property color background: resolve("background", "#1C1C1E")
    readonly property color surface: resolve("surface", "#2C2C2E")
    readonly property color surfaceHigh: resolve("surfaceHigh", "#38383A")
    readonly property color textPrimary: resolve("textPrimary", "#F5F5F3")
    readonly property color textSecondary: resolve("textSecondary", "#B8B8B2")
    readonly property color textMuted: resolve("textMuted", "#777773")
    readonly property color shadow: resolve("shadow", "#1A1A1A")
    readonly property color sidebar: resolve("sidebar", "#18191D")
    readonly property color popup: resolve("popup", "#1C1D21")
    readonly property color pill: resolve("pill", "#141517")
    readonly property color itemHover: resolve("itemHover", "#313135")
    readonly property color indicator: resolve("indicator", "#665A42")
    readonly property color deviceHover: resolve("deviceHover", "#252527")
    readonly property color label: resolve("label", "#F2F2F2")
    readonly property color switchTrack: resolve("switchTrack", "#3A3A3C")
    readonly property color switchThumb: resolve("switchThumb", "#AAAAAA")
    readonly property color pillHover: resolve("pillHover", "#39393E")
    readonly property color powerLabel: resolve("powerLabel", "#F4E8C8")
    readonly property color appHover: resolve("appHover", "#303035")
    readonly property color appMuted: resolve("appMuted", "#85858D")
    readonly property color scrollHandle: resolve("scrollHandle", "#48484E")
    readonly property color scrollArrow: resolve("scrollArrow", "#A0A0A8")
    readonly property color disabled: resolve("disabled", "#808080")
    readonly property color danger: resolve("danger", "#FF5F57")

    FileView {
        id: systemFile
        path: root.configHome + "/palette/palette.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.systemColors = root.parsePalette(systemFile.text())
        onLoadFailed: root.systemColors = ({})
        onFileChanged: reload()
    }

    FileView {
        id: hyprFile
        path: root.configHome + "/hypr/palette.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.hyprColors = root.parsePalette(hyprFile.text())
        onLoadFailed: root.hyprColors = ({})
        onFileChanged: reload()
    }
}
