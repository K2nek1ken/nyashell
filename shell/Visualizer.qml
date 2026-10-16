import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// визуализатор звука на рабочем столе: над обоями, под окнами, сверху и/или снизу экрана.
// Частоты считает cava (берёт звук, который сейчас играет, из PipeWire / PulseAudio).
// Настройки — Настройки → Вид → Визуализатор
// a sound visualiser on the desktop: above the wallpaper, under windows, at the top and/or bottom of the screen.
// cava computes the frequencies (from whatever is playing now, via PipeWire / PulseAudio).
// Settings: Settings → Look → Visualiser
Scope {
    id: vz
    readonly property bool on: (ShellState.settings.visualizer ?? false) && !ShellState.locked
    readonly property int bars: 48
    property var levels: []           // 0…1 для каждой полосы / 0…1 for each bar
    property bool silent: true
    readonly property string cfg: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nyash-cava.conf"
    property string method: "pipewire"

    Process {
        id: cava
        running: vz.on
        command: ["sh", "-c",
            'cat > "$1" <<EOF\n[general]\nframerate = 30\nbars = $2\nautosens = 1\n[input]\nmethod = $3\nsource = auto\n' +
            '[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n' +
            '[smoothing]\nnoise_reduction = 77\nEOF\nexec cava -p "$1"', "sh", vz.cfg, String(vz.bars), vz.method]
        stdout: SplitParser {
            onRead: (l) => {
                const v = l.split(";").filter(x => x !== "").map(x => Math.min(1, (parseInt(x) || 0) / 1000));
                if (v.length < 2) return;
                vz.levels = v;
                vz.silent = v.every(x => x < 0.01);
            }
        }
        // нет PipeWire-ввода в этой сборке cava — пробуем PulseAudio
        // this cava build has no PipeWire input: try PulseAudio
        onExited: (code) => { if (vz.on && code !== 0 && vz.method === "pipewire") { vz.method = "pulse"; again.restart(); } }
    }
    Timer { id: again; interval: 500; onTriggered: cava.running = vz.on }

    // одна полоса = отдельное маленькое окно ровно под волну (а не прозрачное окно на весь экран):
    // композитору перерисовывать меньше, а холст рисуется в своём потоке и не тормозит шелл.
    // Волна стоит внутри рамки экрана: снизу — над панелью, сверху — под краем рамки
    // one strip = a separate small window just the size of the wave (not a transparent full-screen window):
    // less for the compositor to redraw, and the canvas renders in its own thread without slowing the shell.
    // The wave sits inside the screen frame: at the bottom above the bar, at the top under the frame's edge
    component Strip: PanelWindow {
        id: w
        required property var scr
        required property bool atTop
        screen: scr
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "nyash-visualizer"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: w.atTop; bottom: !w.atTop; left: true; right: true }
        margins { top: w.atTop ? Tokens.frame : 0; bottom: w.atTop ? 0 : Tokens.barHeight; left: Tokens.frame; right: Tokens.frame }
        implicitHeight: hh
        color: "transparent"
        mask: Region {}
        readonly property string style: ShellState.settings.vizStyle ?? "wave"       // wave | bars
        readonly property real hh: ShellState.settings.vizHeight ?? 140
        Canvas {
            id: cv
            anchors.fill: parent
            opacity: (ShellState.settings.vizOpacity ?? 60) / 100
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded
            property var lv: vz.levels
            onLvChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                const v = vz.levels, n = v.length;
                if (n < 2 || vz.silent) return;
                const W = width, H = height, h = H;
                const acc = Theme.accent, acc2 = Theme.accent2;
                const base = w.atTop ? 0 : H, dir = w.atTop ? 1 : -1;
                const g = c.createLinearGradient(0, base, 0, base + dir * h);
                g.addColorStop(0, Qt.rgba(acc.r, acc.g, acc.b, 0.9));
                g.addColorStop(1, Qt.rgba(acc2.r, acc2.g, acc2.b, 0));
                c.fillStyle = g;
                if (w.style === "bars") {
                    const bw = W / n;
                    for (let i = 0; i < n; i++) {
                        const bh = Math.max(2, v[i] * h);
                        c.fillRect(i * bw + bw * 0.18, w.atTop ? 0 : H - bh, bw * 0.64, bh);
                    }
                    return;
                }
                // волна: гладкая кривая через вершины полос (зеркально от центра — симметрично)
                // wave: a smooth curve through the bar tops (mirrored from the centre, symmetrical)
                const pts = v.slice().reverse().concat(v);
                const step = W / (pts.length - 1);
                c.beginPath();
                c.moveTo(0, base);
                let px = 0, py = base + dir * pts[0] * h;
                c.lineTo(px, py);
                for (let i = 1; i < pts.length; i++) {
                    const x = i * step, y = base + dir * pts[i] * h;
                    c.quadraticCurveTo(px, py, (px + x) / 2, (py + y) / 2);
                    px = x; py = y;
                }
                c.lineTo(W, py); c.lineTo(W, base); c.closePath(); c.fill();
            }
        }
    }

    Variants {
        model: vz.on ? Quickshell.screens : []
        delegate: Component {
            Scope {
                id: sc
                required property var modelData
                readonly property string place: ShellState.settings.vizPlace ?? "bottom"     // bottom | top | both
                // на весь экран развёрнута игра — не рисуем
                // a game is full-screen: don't draw
                readonly property bool show: !ShellState.fullscreenOn(modelData.name)
                Strip { scr: sc.modelData; atTop: false; visible: sc.show && sc.place !== "top" }
                Strip { scr: sc.modelData; atTop: true; visible: sc.show && sc.place !== "bottom" }
            }
        }
    }
}
