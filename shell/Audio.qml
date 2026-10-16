pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// звук через pipewire
// sound via pipewire
Singleton {
    id: au
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var inputs: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    // приложения, которые сейчас играют звук
    // apps currently playing sound
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio)

    PwObjectTracker { objects: [au.sink, au.source].filter(x => x).concat(au.outputs, au.inputs, au.streams) }

    function label(n): string {
        const p = n?.properties ?? {};
        return p["application.name"] || n?.description || n?.nickname || n?.name || "?";
    }
    function iconOf(n): string {
        const p = n?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || "audio-card";
    }
    // звуковой поток окна: сравниваем app_id окна с именем/бинарником приложения
    // a window's audio stream: match the window's app_id against the app's name/binary
    function streamFor(appId: string): var {
        const a = (appId || "").toLowerCase();
        if (!a) return null;
        return streams.find(n => {
            const p = n.properties ?? {};
            return [p["application.process.binary"], p["application.name"], p["application.id"],
                    p["pipewire.access.portal.app_id"]].filter(x => x).map(x => String(x).toLowerCase())
                   .some(x => x === a || a.includes(x) || x.includes(a.split(".").pop()));
        }) ?? null;
    }
    function setNodeVolume(n, v: real): void { if (n?.audio) n.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function useInput(node): void { Pipewire.preferredDefaultAudioSource = node; }

    function setVolume(v: real): void { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function toggleMute(): void { if (sink?.audio) sink.audio.muted = !muted; }
    function use(node): void { Pipewire.preferredDefaultAudioSink = node; }
    function icon(): string { return muted || volume === 0 ? "vol_off" : volume < 0.5 ? "vol_down" : "vol_up"; }
}
