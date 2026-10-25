import "../theme" as Theme
import QtQuick
import Quickshell

// Hover highlight that travels between tiles like a dividing cell, with the
// membrane of the power menu: it rounds up into a sphere, a bud leaves the
// current tile, stretches, pinches off and becomes the new one, passing through
// the tiles on the way, and once it arrives it expands into the tile's rounded
// rectangle. Tiles may differ in size.
//
// `items` are the tiles, each exposing `hovered` and `pressed`; they may sit
// anywhere inside the parent of this item, which should fill the area they span.
// The cell rests on the hovered tile, otherwise on `restIndex` (-1 hides it).
// With `followsHover` off it ignores the pointer and only marks `restIndex`,
// e.g. the focused window. It draws a fill, an outline ring, or both.
// The tile at `ignoredIndex` draws its own highlight and is left out entirely:
// the cell never rests on it, and rather than crossing it, it vanishes and
// reappears on the next tile.
Item {
    id: root

    property var items: []
    property int restIndex: -1
    property int ignoredIndex: -1
    // Corner radius the cell settles into; a tile can override it with its own `cellRadius`.
    property real tileRadius: 14
    property color color: Theme.Colors.alpha(Theme.Colors.accent, 36 / 255)
    property color outlineColor: "transparent"
    property real outlineWidth: 0
    property bool followsHover: true

    // The tiles the cell moves between; indices below refer to this list.
    readonly property var tiles: items.filter((item, index) => item && index !== ignoredIndex)
    readonly property int hoveredIndex: followsHover ? tiles.findIndex(tile => tile.hovered) : -1
    readonly property bool pressing: followsHover && tiles.some(tile => tile.pressed)
    readonly property int target: hoveredIndex >= 0 ? hoveredIndex
        : restIndex >= 0 ? tiles.indexOf(items[restIndex]) : -1

    // Diameter of the travelling sphere relative to the tile's shorter side.
    property real sphereScale: 0.72

    property real position: 0
    property int origin: 0
    property int direction: 1
    property real presence: 0
    // 0: a sphere on the move, 1: the tile's square at rest.
    property real form: 0
    // Tile to reappear on once the cell has vanished, when it would cross the ignored one.
    property int pendingJump: -1
    // Tile the cell is on or on its way to.
    property int heading: -1
    // Set by jumpNext(): the next move lands at once, without dividing.
    property bool instant: false

    readonly property int next: Math.max(0, Math.min(tiles.length - 1, origin + direction))
    readonly property real split: Math.max(0, Math.min(1, (position - origin) * direction))

    property real pressScale: pressing ? 0.9 : 1
    Behavior on pressScale {
        SpringAnimation { spring: 4.5; damping: 0.28; epsilon: 0.002 }
    }

    function smoothstep(edge0, edge1, x) {
        const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    function centerOf(index) {
        const item = tiles[index]
        return item ? item.mapToItem(root, item.width / 2, item.height / 2) : Qt.point(width / 2, height / 2)
    }

    function radiusOf(index) {
        const item = tiles[index]
        return item && item.cellRadius !== undefined ? item.cellRadius : tileRadius
    }

    function halfSizeOf(index) {
        const item = tiles[index]
        return item ? Qt.size(item.width / 2, item.height / 2) : Qt.size(0, 0)
    }

    function itemIndex(tile) {
        return items.indexOf(tiles[tile])
    }

    function crossesIgnored(from, to) {
        if (ignoredIndex < 0)
            return false
        const a = itemIndex(Math.min(Math.floor(from), to))
        const b = itemIndex(Math.max(Math.ceil(from), to))
        return a < ignoredIndex && ignoredIndex < b
    }

    function fade(to, duration) {
        presenceAnimation.stop()
        presenceAnimation.to = to
        presenceAnimation.duration = duration
        presenceAnimation.start()
    }

    // For changes the user made right here: the highlight is already where they looked.
    function jumpNext(): void {
        instant = true
        instantTimeout.restart()
    }

    function moveTo(index) {
        pendingJump = -1
        heading = index

        if (index < 0) {
            fade(0, 200)
            return
        }

        if (instant) {
            instant = false
            travel.stop()
            formAnimation.stop()
            presenceAnimation.stop()
            origin = index
            direction = 1
            position = index
            form = 1
            presence = 1
            return
        }

        if (presence > 0 && crossesIgnored(position, index)) {
            travel.stop()
            roundUp()
            pendingJump = index
            fade(0, 110)
            return
        }

        fade(1, 200)

        // Nothing visible yet: appear in place instead of travelling.
        if (presence === 0) {
            travel.stop()
            origin = index
            direction = 1
            position = index
            form = 0
            expand()
            return
        }

        const distance = Math.abs(index - position)
        travel.stop()
        if (distance === 0) {
            expand()
            return
        }

        roundUp()

        travel.from = position
        travel.to = index
        travel.duration = 240 + 130 * distance
        travel.easing.type = distance > 1.5 ? Easing.InOutQuad : Easing.InOutCubic
        travel.start()
    }

    function roundUp() {
        formAnimation.stop()
        formAnimation.to = 0
        formAnimation.duration = 90
        formAnimation.easing.type = Easing.OutCubic
        formAnimation.start()
    }

    function expand() {
        formAnimation.stop()
        formAnimation.to = 1
        formAnimation.duration = 150
        formAnimation.easing.type = Easing.OutBack
        formAnimation.easing.overshoot = 1.6
        formAnimation.start()
    }

    // Indices into a different list would make the cell jump: start over.
    onTilesChanged: {
        travel.stop()
        formAnimation.stop()
        presenceAnimation.stop()
        presence = 0
        heading = -1
        settle.restart()
    }

    // Leaving a tile for the gap before the next one would make the cell
    // shrink and regrow; give the pointer a moment to arrive.
    onTargetChanged: {
        if (hoveredIndex >= 0) {
            settle.stop()
            moveTo(target)
        } else {
            settle.restart()
        }
    }

    // Crossing a whole tile hands the origin over to the bud; moving back past
    // the origin just makes the bud bloom the other way.
    onPositionChanged: {
        let progress = (position - origin) * direction
        while (progress >= 1) {
            origin += direction
            progress -= 1
        }
        if (progress < 0)
            direction = -direction

        // The eased travel crawls over its last stretch: start filling the
        // square while the sphere is still landing, not after it stops.
        if (travel.running && formAnimation.to !== 1 && Math.abs(travel.to - position) < 0.3)
            expand()
    }

    Component.onCompleted: moveTo(target)

    // A jump requested for a change that never came should not swallow a later one.
    Timer {
        id: instantTimeout

        interval: 1000
        onTriggered: root.instant = false
    }

    Timer {
        id: settle

        interval: 90
        onTriggered: root.moveTo(root.target)
    }

    NumberAnimation {
        id: travel

        target: root
        property: "position"
        onFinished: {
            if (formAnimation.to !== 1)
                root.expand()
        }
    }

    NumberAnimation {
        id: formAnimation

        target: root
        property: "form"
    }

    NumberAnimation {
        id: presenceAnimation

        target: root
        property: "presence"
        easing.type: Easing.OutCubic

        onFinished: {
            if (root.pendingJump >= 0 && root.presence === 0)
                root.moveTo(root.pendingJump)
        }
    }

    ShaderEffect {
        id: membrane

        readonly property real t: root.split
        readonly property real moved: 0.5 * t + 0.5 * root.smoothstep(0, 1, t)
        readonly property real grow: 1 - Math.pow(1 - t, 3)
        // The origin compresses while the bud leaves, then sinks under the surface.
        readonly property real release: 1 - 0.5 * Math.sin(Math.PI * t)
        readonly property real shrink: Math.pow(Math.max(0, (t - 0.5) / 0.5), 2)

        // Reading the size re-evaluates the tiles when the layout changes.
        readonly property bool layout: root.width + root.height >= 0
        readonly property point mother: layout ? root.centerOf(root.origin) : Qt.point(0, 0)
        readonly property point bud: layout ? root.centerOf(root.next) : Qt.point(0, 0)
        readonly property size motherHalf: layout ? root.halfSizeOf(root.origin) : Qt.size(0, 0)
        readonly property size budHalf: layout ? root.halfSizeOf(root.next) : Qt.size(0, 0)

        readonly property real appear: (0.6 + 0.4 * root.presence) * root.pressScale
        readonly property real motherScale: release * (1 - shrink) * appear
        readonly property real budScale: grow * appear

        // The tile's rounded rectangle at form 1, a sphere at form 0.
        function shape(half: size, cornerRadius: real, scale: real): var {
            const sphere = root.sphereScale * Math.min(half.width, half.height)
            const w = (sphere + (half.width - sphere) * root.form) * scale
            const h = (sphere + (half.height - sphere) * root.form) * scale
            const radius = sphere + (cornerRadius - sphere) * Math.min(1, root.form)
            return { w: w, h: h, r: Math.max(0, Math.min(radius * scale, w, h)) }
        }

        readonly property var motherShape: shape(motherHalf, root.radiusOf(root.origin), motherScale)
        readonly property var budShape: shape(budHalf, root.radiusOf(root.next), budScale)

        anchors.fill: parent
        opacity: root.presence
        visible: root.presence > 0 && root.tiles.length > 0

        property size size: Qt.size(width, height)
        property vector4d cells: Qt.vector4d(
            mother.x, mother.y,
            mother.x + (bud.x - mother.x) * moved, mother.y + (bud.y - mother.y) * moved)
        property vector4d halves: Qt.vector4d(motherShape.w, motherShape.h, budShape.w, budShape.h)
        property vector2d radii: Qt.vector2d(motherShape.r, budShape.r)
        property vector2d fade: Qt.vector2d(18 * shrink, 18 * (1 - grow))
        // 0.8 of the shorter side, as in the power menu.
        property real goo: 1.6 * Math.min(motherHalf.width, motherHalf.height, budHalf.width, budHalf.height)
        property real stroke: root.outlineWidth
        property color fill: root.color
        property color outline: root.outlineColor

        fragmentShader: Quickshell.shellPath("common/assets/shaders/cell.frag.qsb")
    }
}
