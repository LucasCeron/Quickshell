pragma Singleton
import QtQuick
import Quickshell
import "../../config" as Config
Singleton {
    function launch(): void { Quickshell.execDetached([Config.Settings.launcherCommand, "-show", "drun"]); }
}
