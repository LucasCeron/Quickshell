pragma Singleton
import QtQuick
import QtMultimedia
import Quickshell

// Interface sounds, synthesised by scripts/generate-sounds.py.
Singleton {
    // Water drop: power menu.
    function drop(): void { dropEffect.play() }

    SoundEffect {
        id: dropEffect
        source: Quickshell.shellPath("common/assets/sounds/drop.wav")
        volume: 0.6
    }
}
