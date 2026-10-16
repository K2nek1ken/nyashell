pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// текущая раскладка клавиатуры из mango
// current keyboard layout from mango
Singleton {
    id: kb
    property string name: ""
    readonly property string short: {
        const n = name.toLowerCase();
        if (n.startsWith("russian")) return "RU";
        if (n.startsWith("english")) return "EN";
        if (n.startsWith("ukrain")) return "UA";
        return name.slice(0, 2).toUpperCase();
    }
    function next(): void { Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]); }

    Process {
        id: watch
        command: ["mmsg", "watch", "keyboardlayout"]
        running: true
        property string buf: ""
        stdout: SplitParser {
            onRead: (line) => {
                watch.buf += line;
                try { const o = JSON.parse(watch.buf); watch.buf = ""; if (o.layout !== undefined) kb.name = o.layout; }
                catch (e) { if (watch.buf.length > 10000) watch.buf = ""; }
            }
        }
        onExited: again.restart()
    }
    Timer { id: again; interval: 1500; onTriggered: watch.running = true }
    Process {
        running: true
        command: ["mmsg", "get", "keyboardlayout"]
        stdout: StdioCollector { onStreamFinished: { try { kb.name = JSON.parse(text).layout ?? kb.name; } catch (e) {} } }
    }
}
