pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// экраны: список, режимы и масштаб — через wlr-randr (mango поддерживает управление выходами);
// изменения применяются сразу и запоминаются в конфиге mango строкой monitorrule
// displays: list, modes and scale via wlr-randr (mango supports output management);
// changes apply immediately and are remembered in the mango config as a monitorrule line
Singleton {
    id: d
    property var outputs: []      // [{name, description, scale, modes: [{w, h, r, current}]}]
    function refresh(): void { probe.running = true; }
    Process {
        id: probe
        command: ["wlr-randr", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    d.outputs = JSON.parse(text).filter(o => o.enabled !== false).map(o => ({
                        name: o.name, description: o.description || o.name, scale: o.scale || 1,
                        modes: (o.modes || []).map(m => ({ w: m.width, h: m.height, r: Math.round(m.refresh), current: !!m.current }))
                    }));
                } catch (e) { d.outputs = []; }
            }
        }
    }
    Component.onCompleted: refresh()

    function current(o) { return o.modes.find(m => m.current) ?? o.modes[0] ?? { w: 0, h: 0, r: 0 }; }
    function apply(o, mode, scale: real): void {
        const m = mode ?? current(o), s = scale > 0 ? scale : o.scale;
        Quickshell.execDetached(["wlr-randr", "--output", o.name, "--mode", m.w + "x" + m.h + "@" + m.r, "--scale", String(s)]);
        // запомнить в конфиге mango (заменяем строку этого экрана)
        // remember in the mango config (replace this screen's line)
        ShellState.cfgEdit(["sh", "-c",
            'f="$HOME/.config/mango/config.conf"; sed -i "/^monitorrule=name:$1,/d" "$f"; ' +
            'echo "monitorrule=name:$1,width:$2,height:$3,refresh:$4,scale:$5" >> "$f"',
            "sh", o.name, String(m.w), String(m.h), String(m.r), String(s)]);
        refreshLater.restart();
    }
    Timer { id: refreshLater; interval: 800; onTriggered: d.refresh() }
}
