pragma ComponentBehavior: Bound

import "../../common/theme" as Theme

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Activity monitor that slides in along the right side of the screen: CPU with
// history and per-core load, memory, network, disk and the busiest processes.
// Samples come from stats.sh once a second, only while the panel is open.
PanelWindow {// qmllint disable uncreatable-type
    id: root

    readonly property int historyLength: 48

    // Raw counters from the previous sample, to turn totals into rates.
    property var lastCpu: []
    property real lastRx: -1
    property real lastTx: -1
    property real lastSampleTime: 0

    property real cpuTotal: 0
    property var cpuCores: []
    property var cpuHistory: []
    property real memUsed: 0
    property real memTotal: 1
    property real swapUsed: 0
    property real swapTotal: 0
    property real rxRate: 0
    property real txRate: 0
    property var rxHistory: []
    property var txHistory: []
    property real diskUsed: 0
    property real diskTotal: 1
    property real uptime: 0
    property var processes: []

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: 420
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ActivityState.open

    WlrLayershell.namespace: "config-activity"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region {
        item: card
    }


    onVisibleChanged: {
        if (!visible)
            return

        lastCpu = []
        lastRx = -1
        lastTx = -1
        card.forceActiveFocus()
        entrance.restart()
        sampler.running = true
    }

    function formatBytes(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let value = bytes
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return value.toFixed(value >= 100 || unit === 0 ? 0 : 1) + " " + units[unit]
    }

    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor(seconds % 86400 / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        return (days > 0 ? days + "d " : "") + hours + "h " + String(minutes).padStart(2, "0") + "m"
    }

    function pushHistory(list, value) {
        const next = list.concat([value])
        return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next
    }

    function parse(text) {
        const sections = {}
        let current = ""
        for (const line of text.split("\n")) {
            if (line.startsWith("#")) {
                current = line.slice(1)
                sections[current] = []
            } else if (line.trim() !== "" && current) {
                sections[current].push(line.trim().split(/\s+/))
            }
        }

        const now = Date.now()
        const elapsed = root.lastSampleTime > 0 ? (now - root.lastSampleTime) / 1000 : 0
        root.lastSampleTime = now

        // CPU: busy share of the jiffies since the last sample, overall and per core.
        const cpu = (sections.cpu ?? []).map(fields => {
            const values = fields.slice(1).map(Number)
            const idle = values[3] + values[4]
            const total = values.reduce((sum, value) => sum + value, 0)
            return { idle: idle, total: total }
        })
        if (root.lastCpu.length === cpu.length) {
            const usage = cpu.map((sample, index) => {
                const total = sample.total - root.lastCpu[index].total
                const idle = sample.idle - root.lastCpu[index].idle
                return total > 0 ? Math.max(0, Math.min(1, 1 - idle / total)) : 0
            })
            root.cpuTotal = usage[0]
            root.cpuCores = usage.slice(1)
            root.cpuHistory = root.pushHistory(root.cpuHistory, usage[0])
        }
        root.lastCpu = cpu

        const mem = {}
        for (const fields of sections.mem ?? [])
            mem[fields[0].replace(":", "")] = Number(fields[1]) * 1024
        root.memTotal = mem.MemTotal || 1
        root.memUsed = (mem.MemTotal ?? 0) - (mem.MemAvailable ?? 0)
        root.swapTotal = mem.SwapTotal ?? 0
        root.swapUsed = root.swapTotal - (mem.SwapFree ?? 0)

        const net = (sections.net ?? [])[0]
        if (net) {
            const rx = Number(net[0])
            const tx = Number(net[1])
            if (root.lastRx >= 0 && elapsed > 0) {
                root.rxRate = Math.max(0, (rx - root.lastRx) / elapsed)
                root.txRate = Math.max(0, (tx - root.lastTx) / elapsed)
                root.rxHistory = root.pushHistory(root.rxHistory, root.rxRate)
                root.txHistory = root.pushHistory(root.txHistory, root.txRate)
            }
            root.lastRx = rx
            root.lastTx = tx
        }

        const disk = (sections.disk ?? [])[0]
        if (disk) {
            root.diskUsed = Number(disk[0])
            root.diskTotal = Number(disk[1]) || 1
        }

        root.uptime = Number(((sections.uptime ?? [])[0] ?? [0])[0])
        root.processes = (sections.ps ?? []).map(fields => ({
            pid: fields[0], cpu: Number(fields[1]), mem: Number(fields[2]), name: fields.slice(3).join(" ")
        }))
    }

    Process {
        id: sampler

        command: [Quickshell.shellPath("modules/activity/stats.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            if (!sampler.running)
                sampler.running = true
        }
    }

    Rectangle {
        id: card

        property real slide: 0

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 64
            rightMargin: 16
        }

        width: 380
        height: content.implicitHeight + 36
        radius: 22

        color: Theme.Colors.alpha(Theme.Colors.popup, 250 / 255)
        border.width: 1
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 56 / 255)

        transform: Translate { x: card.slide }
        focus: true

        Keys.onEscapePressed: ActivityState.hide()

        ParallelAnimation {
            id: entrance

            NumberAnimation { target: card; property: "slide"; from: 48; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        Column {
            id: content

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 18
            }

            spacing: 16

            // Header
            Item {
                width: parent.width
                height: 30

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Atividade"
                        color: Theme.Colors.label

                        font {
                            family: Theme.Typography.monoFamily
                            pixelSize: 16
                            bold: true
                        }
                    }

                    Text {
                        text: "ligado há " + root.formatUptime(root.uptime)
                        color: Theme.Colors.textMuted

                        font {
                            family: Theme.Typography.monoFamily
                            pixelSize: 11
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    HeaderButton {
                        label: "btop"
                        onClicked: ActivityState.openBtop()
                    }

                    HeaderButton {
                        label: "✕"
                        onClicked: ActivityState.hide()
                    }
                }
            }

            // CPU
            Section {
                title: "CPU"
                value: Math.round(root.cpuTotal * 100) + "%"

                Graph {
                    width: parent.width
                    height: 64
                    values: root.cpuHistory
                    maximum: 1
                    lineColor: Theme.Colors.accent
                }

                // One bar per core.
                Row {
                    width: parent.width
                    height: 26
                    spacing: 3

                    Repeater {
                        model: root.cpuCores

                        Rectangle {
                            id: core

                            required property real modelData

                            width: (parent.width - (root.cpuCores.length - 1) * 3) / Math.max(1, root.cpuCores.length)
                            height: parent.height
                            radius: 4
                            color: Theme.Colors.alpha(Theme.Colors.surfaceHigh, 160 / 255)

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(2, parent.height * core.modelData)
                                radius: 4
                                color: Theme.Colors.alpha(Theme.Colors.accent, (110 + 145 * core.modelData) / 255)

                                Behavior on height {
                                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            // Memory
            Section {
                title: "Memória"
                value: root.formatBytes(root.memUsed) + " / " + root.formatBytes(root.memTotal)

                Meter {
                    width: parent.width
                    fraction: root.memUsed / root.memTotal
                }

                Meter {
                    width: parent.width
                    visible: root.swapTotal > 0
                    fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : 0
                    caption: "swap  " + root.formatBytes(root.swapUsed) + " / " + root.formatBytes(root.swapTotal)
                    thin: true
                }
            }

            // Network
            Section {
                title: "Rede"
                value: "↓ " + root.formatBytes(root.rxRate) + "/s   ↑ " + root.formatBytes(root.txRate) + "/s"

                Item {
                    width: parent.width
                    height: 48

                    readonly property real peak: Math.max(1024, ...root.rxHistory, ...root.txHistory)

                    Graph {
                        anchors.fill: parent
                        values: root.rxHistory
                        maximum: parent.peak
                        lineColor: Theme.Colors.accent
                    }

                    Graph {
                        anchors.fill: parent
                        values: root.txHistory
                        maximum: parent.peak
                        lineColor: Theme.Colors.textSecondary
                        filled: false
                    }
                }
            }

            // Disk
            Section {
                title: "Disco  /"
                value: root.formatBytes(root.diskUsed) + " / " + root.formatBytes(root.diskTotal)

                Meter {
                    width: parent.width
                    fraction: root.diskUsed / root.diskTotal
                }
            }

            // Processes
            Section {
                title: "Processos"
                value: "CPU   MEM"

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.processes

                        ProcessRow {}
                    }
                }
            }
        }
    }

    // A titled block with its headline value on the right.
    component Section: Column {
        id: section

        property string title
        property string value
        default property alias body: inner.data

        width: parent ? parent.width : 0
        spacing: 8

        Item {
            width: section.width
            height: 18

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: section.title
                color: Theme.Colors.textMuted

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 11
                    bold: true
                    capitalization: Font.AllUppercase
                    letterSpacing: 1
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: section.value
                color: Theme.Colors.textPrimary

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 12
                }
            }
        }

        Column {
            id: inner

            width: section.width
            spacing: 6
        }
    }

    component Meter: Column {
        id: meter

        property real fraction: 0
        property string caption
        property bool thin: false

        spacing: 4

        Rectangle {
            width: meter.width
            height: meter.thin ? 5 : 8
            radius: height / 2
            color: Theme.Colors.alpha(Theme.Colors.surfaceHigh, 160 / 255)

            Rectangle {
                width: Math.max(height, parent.width * Math.min(1, meter.fraction))
                height: parent.height
                radius: height / 2
                color: meter.fraction > 0.85 ? Theme.Colors.danger : Theme.Colors.accent

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            visible: meter.caption !== ""
            text: meter.caption
            color: Theme.Colors.textMuted

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 10
            }
        }
    }

    // Line graph of the recent samples, newest on the right, with a soft fill below.
    component Graph: Canvas {
        id: graph

        property var values: []
        property real maximum: 1
        property color lineColor: Theme.Colors.accent
        property bool filled: true

        onValuesChanged: requestPaint()
        onMaximumChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (graph.values.length < 2)
                return

            const step = width / (root.historyLength - 1)
            const offset = (root.historyLength - graph.values.length) * step
            const yOf = value => height - 2 - (height - 4) * Math.min(1, value / graph.maximum)

            ctx.beginPath()
            graph.values.forEach((value, index) => {
                const x = offset + index * step
                if (index === 0)
                    ctx.moveTo(x, yOf(value))
                else
                    ctx.lineTo(x, yOf(value))
            })

            ctx.lineWidth = 1.6
            ctx.lineJoin = "round"
            ctx.strokeStyle = graph.lineColor
            ctx.stroke()

            if (!graph.filled)
                return

            ctx.lineTo(width, height)
            ctx.lineTo(offset, height)
            ctx.closePath()
            const gradient = ctx.createLinearGradient(0, 0, 0, height)
            gradient.addColorStop(0, Qt.rgba(graph.lineColor.r, graph.lineColor.g, graph.lineColor.b, 0.28))
            gradient.addColorStop(1, Qt.rgba(graph.lineColor.r, graph.lineColor.g, graph.lineColor.b, 0))
            ctx.fillStyle = gradient
            ctx.fill()
        }
    }

    component ProcessRow: Rectangle {
        id: row

        required property var modelData

        width: parent ? parent.width : 0
        height: 26
        radius: 8
        color: rowMouse.containsMouse ? Theme.Colors.itemHover : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: numbers.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: row.modelData.name
            elide: Text.ElideRight
            color: Theme.Colors.textPrimary

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 12
            }
        }

        Row {
            id: numbers

            anchors.right: kill.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                width: 40
                horizontalAlignment: Text.AlignRight
                text: row.modelData.cpu.toFixed(1)
                color: Theme.Colors.accent

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 12
                }
            }

            Text {
                width: 40
                horizontalAlignment: Text.AlignRight
                text: row.modelData.mem.toFixed(1)
                color: Theme.Colors.textSecondary

                font {
                    family: Theme.Typography.monoFamily
                    pixelSize: 12
                }
            }
        }

        // Ends the process (SIGTERM); only shown on hover.
        Text {
            id: kill

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 16

            text: "✕"
            horizontalAlignment: Text.AlignHCenter
            color: killMouse.containsMouse ? Theme.Colors.danger : Theme.Colors.textMuted
            opacity: rowMouse.containsMouse ? 1 : 0

            font.pixelSize: 11
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
        }

        MouseArea {
            id: killMouse

            anchors.fill: kill
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["kill", row.modelData.pid])
        }
    }

    component HeaderButton: Rectangle {
        id: headerButton

        property string label

        signal clicked()

        width: Math.max(30, labelText.implicitWidth + 18)
        height: 28
        radius: 14
        color: headerMouse.containsMouse ? Theme.Colors.alpha(Theme.Colors.accent, 36 / 255) : "transparent"
        border.width: 1
        border.color: Theme.Colors.alpha(Theme.Colors.accent, 60 / 255)

        Text {
            id: labelText

            anchors.centerIn: parent
            text: headerButton.label
            color: Theme.Colors.accent

            font {
                family: Theme.Typography.monoFamily
                pixelSize: 12
            }
        }

        MouseArea {
            id: headerMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: headerButton.clicked()
        }
    }
}
