pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../config" as Config
Singleton {
    id: root
    property bool ready: false
    readonly property real volume: defaultSink?.audio?.volume ?? 0
    readonly property bool muted: defaultSink?.audio?.muted ?? false
    readonly property bool sourceMuted: defaultSource?.audio?.muted ?? false
    // Device changes are announced only after startup has settled.
    property bool announce: false
    function nodeName(node: var): string { return node?.description || node?.nickname || node?.name || "Dispositivo"; }
    onDefaultSourceChanged: {
        sourceSwitch.restart();
        if (announce && defaultSource) Toaster.show("Entrada de áudio", nodeName(defaultSource), "mic.svg");
    }
    // A new input device brings its own mute state; only announce real toggles.
    onSourceMutedChanged: Qt.callLater(() => {
        if (announce && !sourceSwitch.running)
            Toaster.show(sourceMuted ? "Microfone silenciado" : "Microfone ativo", nodeName(defaultSource), "mic.svg");
    })
    Timer { id: sourceSwitch; interval: 300 }
    signal levelChanged()
    onDefaultSinkChanged: {
        ready = false;
        warmup.restart();
        if (announce && defaultSink) Toaster.show("Saída de áudio", nodeName(defaultSink), "volume.svg");
    }
    onVolumeChanged: if (ready) levelChanged()
    onMutedChanged: if (ready) levelChanged()
    PwObjectTracker { objects: [root.defaultSink, root.defaultSource].filter(node => node) }
    Timer { id: warmup; interval: 500; running: true; onTriggered: root.ready = true }
    Timer { interval: 3000; running: true; onTriggered: root.announce = true }
    function setVolume(value: real): void { if (defaultSink?.audio) defaultSink.audio.volume = Math.max(0, Math.min(1, value)); }
    function toggleMute(): void { if (defaultSink?.audio) defaultSink.audio.muted = !defaultSink.audio.muted; }
    function toggleSourceMute(): void { if (defaultSource?.audio) defaultSource.audio.muted = !defaultSource.audio.muted; }
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio !== null && !node.isStream && node.isSink)
    // Apps playing sound right now, each with its own volume.
    // Playback streams are sinks for the app feeding them; recording streams are not.
    readonly property var streams: Pipewire.nodes.values.filter(node => node.audio !== null && node.isStream && node.isSink)
    function appName(node: var): string {
        const props = node?.properties ?? {};
        return props["application.name"] || props["application.process.binary"] || node?.name || "Aplicativo";
    }
    function appIcon(node: var): string {
        const props = node?.properties ?? {};
        const name = props["application.icon-name"]
            || DesktopEntries.heuristicLookup(props["application.process.binary"] || props["application.name"] || "")?.icon
            || props["application.process.binary"] || "";
        return Quickshell.iconPath(name, "audio-x-generic");
    }
    readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio !== null && !node.isStream && !node.isSink)
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var preferredSink: Pipewire.preferredDefaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property var preferredSource: Pipewire.preferredDefaultAudioSource
    function selectSink(node: var): void { Pipewire.preferredDefaultAudioSink = node; }
    function selectSource(node: var): void { Pipewire.preferredDefaultAudioSource = node; }
    function openMixer(): void { Quickshell.execDetached([Config.Settings.mixerCommand]); }
}
