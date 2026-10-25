pragma Singleton
import QtQuick
QtObject {
    readonly property QtObject colors: Colors
    readonly property QtObject typography: Typography
    readonly property QtObject motion: Motion
}
