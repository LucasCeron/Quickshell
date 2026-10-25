pragma Singleton
import QtQuick
import "../../config" as Config
QtObject {
    readonly property string monoFamily: Config.Settings.monoFamily
}
