pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Shapes
import Quickshell
import "../../services" as Services
import "../../common/theme" as Theme
import "../../common/components"
import "../activity"
import "components"

Column {
    id: root
    spacing: 18
    Component.onCompleted: Services.Resources.acquire()
    Component.onDestruction: Services.Resources.release()

    SectionLabel { text: "ATALHOS RÁPIDOS" }
    Grid {
        id: toggles
        width: parent.width
        columns: 2
        spacing: 10
        readonly property real cellWidth: (width - spacing) / 2
        QuickToggle {
            iconName: "bell.svg"
            label: "Não perturbe"
            detail: checked ? "Avisos guardados em silêncio" : "Avisos aparecem na tela"
            checked: Services.Notices.doNotDisturb
            onClicked: Services.Notices.toggleQuiet()
        }
        QuickToggle {
            iconName: "coffee.svg"
            label: "Manter acordado"
            detail: checked ? "Ligado há " + root.since(Services.Idle.since) : "Energia no modo normal"
            checked: Services.Idle.inhibited
            onClicked: { root.now = Date.now(); Services.Idle.toggle(); }
        }
        QuickToggle {
            iconName: "mic.svg"
            label: "Microfone"
            detail: !Services.Audio.defaultSource ? "Sem entrada" : Services.Audio.sourceMuted ? "Silenciado" : Services.Audio.nodeName(Services.Audio.defaultSource)
            checked: !!Services.Audio.defaultSource && !Services.Audio.sourceMuted
            enabled: !!Services.Audio.defaultSource
            onClicked: Services.Audio.toggleSourceMute()
        }
        QuickToggle {
            iconName: "volume.svg"
            label: "Som"
            detail: !Services.Audio.defaultSink ? "Sem saída" : Services.Audio.muted ? "Silenciado" : Math.round(Services.Audio.volume * 100) + "% · " + Services.Audio.nodeName(Services.Audio.defaultSink)
            checked: !!Services.Audio.defaultSink && !Services.Audio.muted
            enabled: !!Services.Audio.defaultSink
            onClicked: Services.Audio.toggleMute()
        }
    }

    Item {
        width: parent.width; height: 40
        SectionLabel { anchors.verticalCenter: parent.verticalCenter; text: "RECURSOS" }
        ActionButton {
            anchors.right: parent.right
            text: "Monitor de atividades"
            onClicked: ActivityState.show(GadgetsState.screenName)
        }
    }
    Grid {
        id: gauges
        width: parent.width
        columns: 2
        spacing: 10
        readonly property real cellWidth: (width - spacing) / 2
        Gauge {
            label: "CPU"
            value: Services.Resources.cpu
            display: Math.round(Services.Resources.cpu * 100) + "%"
            detail: Services.Resources.cpuTemp >= 0 ? Math.round(Services.Resources.cpuTemp) + " °C" : ""
        }
        Gauge {
            label: "Memória"
            value: Services.Resources.memUsed / Services.Resources.memTotal
            display: Math.round(value * 100) + "%"
            detail: Services.Resources.formatBytes(Services.Resources.memUsed)
        }
        Gauge {
            visible: Services.Resources.hasGpu
            label: "GPU"
            value: Services.Resources.gpu
            display: Math.round(Services.Resources.gpu * 100) + "%"
            detail: Services.Resources.gpuTemp >= 0 ? Math.round(Services.Resources.gpuTemp) + " °C" : ""
        }
        Gauge {
            label: "Disco"
            value: Services.Resources.diskUsed / Services.Resources.diskTotal
            display: Math.round(value * 100) + "%"
            detail: Services.Resources.formatBytes(Services.Resources.diskTotal - Services.Resources.diskUsed) + " livres"
        }
    }

    property real now: Date.now()
    function since(time: real): string {
        const minutes = Math.max(0, Math.floor((now - time) / 60000));
        return minutes < 60 ? minutes + " min" : Math.floor(minutes / 60) + " h " + (minutes % 60) + " min";
    }
    Timer { interval: 30000; repeat: true; running: Services.Idle.inhibited; onTriggered: root.now = Date.now() }

    component QuickToggle: Controls.Button {
        id: toggle
        property string iconName
        property string label
        property string detail
        checked: false
        width: toggles.cellWidth
        height: 64
        padding: 0
        hoverEnabled: true
        opacity: enabled ? 1 : 0.38
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        background: Rectangle {
            radius: 18
            color: toggle.checked ? Theme.Colors.alpha(Theme.Colors.accent, toggle.hovered ? 0.22 : 0.15)
                : toggle.hovered ? Theme.Colors.surfaceHigh : Theme.Colors.surface
            border.width: toggle.activeFocus ? 1 : 0
            border.color: Theme.Colors.alpha(Theme.Colors.accent, 0.6)
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        contentItem: Item {
            Rectangle {
                id: bubble
                x: 12; anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: toggle.checked ? Theme.Colors.accent : Theme.Colors.alpha(Theme.Colors.accent, 0.12)
                Behavior on color { ColorAnimation { duration: 160 } }
                Icon {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    source: Quickshell.shellPath("common/assets/icons/" + toggle.iconName)
                    color: toggle.checked ? Theme.Colors.background : Theme.Colors.accent
                }
            }
            Column {
                x: bubble.x + bubble.width + 12
                width: parent.width - x - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { width: parent.width; text: toggle.label; elide: Text.ElideRight; color: Theme.Colors.textPrimary; font { pixelSize: 13; weight: Font.DemiBold } }
                Text { width: parent.width; text: toggle.detail; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.Colors.textMuted; font.pixelSize: 11 }
            }
        }
    }

    component Gauge: Rectangle {
        id: gauge
        property string label
        property real value
        property string display
        property string detail
        property real shown: Math.max(0, Math.min(1, isFinite(value) ? value : 0))
        width: gauges.cellWidth
        height: 150
        radius: 18
        color: Theme.Colors.surface
        Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Shape {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: 84; height: 84
            preferredRendererType: Shape.CurveRenderer
            // The ring opens at the bottom, like a speedometer.
            ShapePath {
                strokeColor: Theme.Colors.surfaceHigh
                strokeWidth: 7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 42; centerY: 42; radiusX: 36; radiusY: 36; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
                strokeColor: gauge.shown > 0.9 ? Theme.Colors.danger : Theme.Colors.accent
                strokeWidth: 7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 42; centerY: 42; radiusX: 36; radiusY: 36; startAngle: 135; sweepAngle: Math.max(0.1, 270 * gauge.shown) }
            }
        }
        Text {
            anchors.centerIn: ring
            text: gauge.display
            color: Theme.Colors.textPrimary
            font { pixelSize: 17; weight: Font.DemiBold }
        }
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
            width: parent.width - 16
            spacing: 2
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: gauge.label; color: Theme.Colors.textPrimary; font { pixelSize: 12; weight: Font.DemiBold } }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: gauge.detail || " "; elide: Text.ElideRight; color: Theme.Colors.textMuted; font.pixelSize: 11 }
        }
    }
}
