pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    // playerctld only mirrors the other players; listing it would show every track twice.
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property string selectedName: ""
    property string lastActiveName: ""
    readonly property var player: players.find(p => p.dbusName === selectedName)
        ?? players.find(p => p.dbusName === lastActiveName && p.isPlaying)
        ?? players.find(p => p.isPlaying) ?? players.find(p => p.dbusName === lastActiveName) ?? players[0] ?? null
    readonly property string title: player?.trackTitle || (player ? "Mídia sem título" : "Sua trilha sonora")
    readonly property string artist: player?.trackArtist || player?.identity || "Abra seu player favorito"
    readonly property bool playing: player?.isPlaying ?? false
    // Older Spotify builds report covers on a host that no longer serves them.
    readonly property string artUrl: (player?.trackArtUrl ?? "").replace("https://open.spotify.com/image/", "https://i.scdn.co/image/")
    signal activity()

    function noteActivity(source: var): void {
        if (!source?.isPlaying) return;
        lastActiveName = source.dbusName;
        activity();
    }
    Instantiator {
        model: ScriptModel { values: root.players }
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged(): void { root.noteActivity(modelData); }
            function onTrackChanged(): void { root.noteActivity(modelData); }
            Component.onCompleted: root.noteActivity(modelData)
        }
    }

    function time(seconds: real): string {
        const value = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0");
    }
}
