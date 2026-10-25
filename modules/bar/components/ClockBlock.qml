import "../../../common/theme" as Theme
import QtQuick
import Quickshell

Item {
    id: root
    property color accentColor: Theme.Colors.accent
    implicitWidth: 64
    implicitHeight: clockColumn.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: clockColumn
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH")
            color: root.accentColor
            font.pixelSize: 28
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "mm")
            color: root.accentColor
            opacity: 0.75
            font.pixelSize: 28
            font.weight: Font.Light
        }
        Item {
            width: 1
            height: 8
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("pt_BR").toString(clock.date, "dd MMM").replace(".", "").toLowerCase()
            color: root.accentColor
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("pt_BR").toString(clock.date, "yyyy").replace(".", "").toUpperCase()
            color: root.accentColor
            font.pixelSize: 15
            font.weight: Font.Medium
            font.letterSpacing: 1
        }
    }
}
