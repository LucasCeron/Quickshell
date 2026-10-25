pragma Singleton
import QtQuick
import Quickshell
QtObject {
    readonly property int maxVisibleApps: 5
    // Opens rofi with the greeting of the ghibli-glass theme.
    readonly property string launcherCommand: Quickshell.env("HOME") + "/.config/rofi/themes/ghibli-glass/launch.sh"
    readonly property string terminalCommand: "ghostty"
    readonly property string networkCommand: "nm-connection-editor"
    readonly property string mixerCommand: "pavucontrol"
    readonly property string monoFamily: "JetBrainsMono Nerd Font"
}
