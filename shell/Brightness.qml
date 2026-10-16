pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// яркость экрана через brightnessctl
// screen brightness via brightnessctl
Singleton {
    id: br
    property real value: 1        // 0..1
    property bool present: false

    Process {
        id: get
        command: ["brightnessctl", "-m"]
        // формат: устройство,класс,текущее,процент,максимум
        // format: device,class,current,percent,max
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5) { br.present = true; br.value = parseInt(f[2]) / Math.max(1, parseInt(f[4])); }
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: get.running = true }

    // пишем не чаще, чем раз в 60 мс, пока тащат ползунок
    // write at most once every 60 ms while the slider is dragged
    property real pending: -1
    Timer {
        id: throttle
        interval: 60
        onTriggered: if (br.pending >= 0) {
            Quickshell.execDetached(["brightnessctl", "-q", "s", Math.round(Math.max(0.02, br.pending) * 100) + "%"]);
            br.pending = -1;
        }
    }
    function set(v: real): void { value = v; pending = v; if (!throttle.running) throttle.start(); }
}
