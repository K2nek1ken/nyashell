pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// параметрический эквалайзер на встроенном фильтре PipeWire (filter-chain):
// появляется виртуальный выход «nyash EQ», звук идёт через него на настоящий выход.
// частота/усиление/Q меняются на лету (pw-cli set-param), добавление/удаление/тип полосы — перезапуск фильтра
// a parametric equaliser on PipeWire's built-in filter (filter-chain):
// a virtual "nyash EQ" output appears, and sound goes through it to the real output.
// frequency/gain/Q change live (pw-cli set-param); adding/removing a band or changing its type restarts the filter
Singleton {
    id: eq
    readonly property string dir: Quickshell.env("HOME") + "/.config/nyashell-eq"
    readonly property var types: ["peak", "lowshelf", "highshelf", "lowpass", "highpass", "notch", "bandpass"]
    readonly property var pwLabel: ({ peak: "bq_peaking", lowshelf: "bq_lowshelf", highshelf: "bq_highshelf",
                                     lowpass: "bq_lowpass", highpass: "bq_highpass", notch: "bq_notch", bandpass: "bq_bandpass" })
    readonly property var palette: ["#7aa2f7", "#9ece6a", "#e0af68", "#bb9af7", "#f7768e", "#7dcfff", "#ff9e64", "#c0caf5", "#73daca", "#e6b8d4"]

    property bool enabled: false
    property real preamp: 0
    property var bands: []          // [{type, freq, gain, q, on, color}]
    property var presets: ({})      // имя -> {preamp, bands} / name -> {preamp, bands}
    property string preset: ""

    FileView {
        id: store
        path: eq.dir + "/eq.json"
        blockLoading: true
        printErrors: false
        onLoaded: eq.load(text())
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) eq.load(text())
}
    property bool loaded: false
    function load(t: string): void {
        try {
            const d = JSON.parse(t);
            eq.enabled = !!d.enabled; eq.preamp = d.preamp ?? 0; eq.bands = d.bands ?? [];
            eq.presets = d.presets ?? {}; eq.preset = d.preset ?? "";
            eq.loaded = true;
        } catch (e) {}
    }
    Component.onCompleted: {
        // файл мог ещё не прочитаться (обработчик самого FileView срабатывает позже) — дочитываем сами,
        // иначе эквалайзер, включённый в прошлый раз, оставался выключенным и затирался полосами по умолчанию
        // the file may not have been read yet (the FileView's own handler fires later), so read it ourselves,
        // otherwise an equaliser that was on last time stayed off and got overwritten with the default bands
        if (!loaded && store.text()) load(store.text());
        if (!bands.length) bands = [mk("lowshelf", 105, 0, 0.7), mk("peak", 400, 0, 1), mk("peak", 2500, 0, 1), mk("highshelf", 8000, 0, 0.7)];
        Quickshell.execDetached(["mkdir", "-p", dir]);
        // выключен — подчищаем, что могло остаться от прошлых запусков (лишние «nyash EQ»)
        // turned off: clean up whatever previous runs may have left (extra "nyash EQ")
        if (enabled) restartLater.restart(); else stop();
    }
    function mk(type: string, freq: real, gain: real, q: real): var {
        return { type: type, freq: freq, gain: gain, q: q, on: true, color: palette[bands.length % palette.length] };
    }
    function save(): void {
        store.setText(JSON.stringify({ enabled: enabled, preamp: preamp, bands: bands, presets: presets, preset: preset }, null, 1));
    }
    Timer { id: saveLater; interval: 600; onTriggered: eq.save() }

    // ─── изменения ───
    // живые параметры (частота, усиление, Q, преамп) — без перезапуска
    // ─── changes ───
    // live parameters (frequency, gain, Q, preamp) without a restart
    function setBand(i: int, key: string, value): void {
        if (key === "freq") value = Math.max(20, Math.min(20000, value));
        const b = bands.slice(); b[i] = Object.assign({}, b[i]); b[i][key] = value; bands = b;
        if (key === "type" || key === "on") restartLater.restart(); else liveLater.restart();
        saveLater.restart();
    }
    function setPreamp(v: real): void { preamp = Math.max(-24, Math.min(12, v)); liveLater.restart(); saveLater.restart(); }
    function addBand(): void {
        if (bands.length >= 16) return;
        bands = bands.concat([mk("peak", 1000, 0, 1)]); restartLater.restart(); saveLater.restart();
    }
    function removeBand(i: int): void { bands = bands.filter((_, k) => k !== i); restartLater.restart(); saveLater.restart(); }
    function setEnabled(on: bool): void { enabled = on; save(); if (on) restartLater.restart(); else stop(); }
    function savePreset(name: string): void {
        if (!name) return;
        const p = Object.assign({}, presets); p[name] = { preamp: preamp, bands: bands }; presets = p; preset = name; save();
    }
    function loadPreset(name: string): void {
        const p = presets[name]; if (!p) return;
        preamp = p.preamp; bands = p.bands; preset = name; save(); restartLater.restart();
    }
    function deletePreset(name: string): void {
        const p = Object.assign({}, presets); delete p[name]; presets = p; if (preset === name) preset = ""; save();
    }

    // ─── PipeWire ───
    function conf(): string {
        const nodes = ['{ type = builtin name = pre label = bq_highshelf control = { "Freq" = 0.0 "Q" = 1.0 "Gain" = ' + preamp.toFixed(2) + ' } }'];
        const active = bands.map((b, i) => ({ b: b, i: i })).filter(x => x.b.on);
        for (const x of active)
            nodes.push('{ type = builtin name = b' + x.i + ' label = ' + pwLabel[x.b.type] + ' control = { "Freq" = ' + x.b.freq.toFixed(1)
                       + ' "Q" = ' + x.b.q.toFixed(3) + ' "Gain" = ' + x.b.gain.toFixed(2) + ' } }');
        const chain = ["pre"].concat(active.map(x => "b" + x.i));
        const links = [];
        for (let k = 0; k + 1 < chain.length; k++) links.push('{ output = "' + chain[k] + ':Out" input = "' + chain[k + 1] + ':In" }');
        // отдельный процесс pipewire должен сам подключиться к серверу: без protocol-native,
        // client-node и adapter фильтр запускался «в пустоту» и на звук не влиял
        // a separate pipewire process has to connect to the server itself: without protocol-native,
        // client-node and adapter the filter started "into the void" and didn't affect the sound
        return 'context.properties = { log.level = 0 }\n'
             + 'context.spa-libs = {\n  audio.convert.* = audioconvert/libspa-audioconvert\n  support.* = support/libspa-support\n}\n'
             + 'context.modules = [\n'
             + '{ name = libpipewire-module-rt args = { nice.level = -11 } flags = [ ifexists nofail ] }\n'
             + '{ name = libpipewire-module-protocol-native }\n'
             + '{ name = libpipewire-module-client-node }\n'
             + '{ name = libpipewire-module-adapter }\n'
             + '{ name = libpipewire-module-filter-chain\n  args = {\n'
             + '    node.description = "nyash EQ"\n    media.name = "nyash EQ"\n'
             + '    filter.graph = {\n      nodes = [\n        ' + nodes.join("\n        ") + '\n      ]\n'
             + '      links = [\n        ' + links.join("\n        ") + '\n      ]\n    }\n'
             + '    audio.channels = 2\n    audio.position = [ FL FR ]\n'
             + '    capture.props = { node.name = "effect_input.nyash_eq" media.class = Audio/Sink }\n'
             + '    playback.props = { node.name = "effect_output.nyash_eq" node.passive = true'
             + (realSink ? ' target.object = "' + realSink + '" node.dont-reconnect = false' : '') + ' }\n  }\n}\n]\n';
    }
    Timer { id: restartLater; interval: 250; onTriggered: eq.restart() }
    Timer { id: liveLater; interval: 60; onTriggered: eq.live() }
    FileView { id: confFile; path: eq.dir + "/eq.conf"; printErrors: false }

    Process {
        id: chainProc
        command: ["sh", Quickshell.shellPath("eq.sh"), "run", eq.dir + "/eq.conf"]
        onRunningChanged: if (running) defaultLater.restart()
    }
    // после запуска делаем «nyash EQ» выходом по умолчанию
    // after start, make "nyash EQ" the default output
    Timer { id: defaultLater; interval: 900
            onTriggered: Quickshell.execDetached(["sh", "-c",
                'id=$(pw-cli ls Node | awk \'/^[[:space:]]*id /{id=$2} /node.name = "effect_input.nyash_eq"/{gsub(",","",id); print id; exit}\'); ' +
                '[ -n "$id" ] || exit 0; wpctl set-volume "$id" 1.0; ' +
                '! wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q "effect_input.nyash_eq" && wpctl set-default "$id"; true']) }
    // настоящий выход (звуковая карта или наушники) — туда эквалайзер отдаёт обработанный звук
    // the real output (sound card or headphones): where the equaliser sends the processed sound
    property string realSink: ""
    Process {
        id: sinkProbe
        command: ["sh", "-c",
            'nm() { wpctl inspect "$1" 2>/dev/null | sed -n "s/.*node.name = \\"\\(.*\\)\\"/\\1/p" | head -1; }; ' +
            'n=$(nm @DEFAULT_AUDIO_SINK@); ' +
            // по умолчанию стоит наш же эквалайзер (остался от прошлого раза) — берём первый настоящий выход
            // the default is our own equaliser (left over from last time): take the first real output
            'case "$n" in ""|effect_input.nyash_eq) id=$(wpctl status 2>/dev/null | sed -n "/Sinks:/,/Sources:/p" | grep -v "nyash EQ" | grep -oE "[0-9]+\\." | head -1 | tr -d .); ' +
            '  [ -n "$id" ] && n=$(nm "$id") ;; esac; echo "$n"']
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim();
                if (n && n !== "effect_input.nyash_eq") eq.realSink = n;
                // настоящей звуковой карты нет (у PipeWire только «Dummy Output» — auto_null):
                // эквалайзер не включаем вовсе — подключать его некуда, а лишние переключения только мешают
                // there is no real sound card (PipeWire only has "Dummy Output", auto_null):
                // don't turn the equaliser on at all, there's nothing to connect it to and the extra switching only gets in the way
                if (!eq.realSink || eq.realSink.startsWith("auto_null")) {
                    eq.enabled = false; eq.save(); eq.stop();
                    Quickshell.execDetached(["notify-send", "-a", "nyashell", "EQ", L.t("эквалайзер выключен: PipeWire не видит звуковую карту")]);
                    return;
                }
                ShellState.osdQuietUntil = Date.now() + 2500;
                confFile.setText(eq.conf());
                chainProc.running = false;
                startLater.restart();
            }
        }
    }
    function restart(): void {
        if (!enabled) return;
        sinkProbe.running = true;
    }
    Timer { id: startLater; interval: 250; onTriggered: chainProc.running = true }
    // выключили — возвращаем выход по умолчанию на настоящую звуковую карту
    // turned off: point the default output back at the real sound card
    function stop(): void {
        ShellState.osdQuietUntil = Date.now() + 1500;
        chainProc.running = false;
        // убираем все копии фильтра (в том числе оставшиеся от прошлых запусков шелла) и возвращаем выход
        // remove every copy of the filter (including ones left over from previous shell runs) and restore the output
        if (realSink) Quickshell.execDetached(["sh", "-c",
            'sh "$2" stop; id=$(pw-cli ls Node | awk \'/^[[:space:]]*id /{id=$2} /node.name = "\'"$1"\'"/{gsub(",","",id); print id; exit}\'); [ -n "$id" ] && wpctl set-default "$id"',
            "sh", realSink, Quickshell.shellPath("eq.sh")]);
        else Quickshell.execDetached(["sh", Quickshell.shellPath("eq.sh"), "stop"]);
    }
    // живое изменение параметров уже запущенного фильтра
    // live change of the running filter's parameters
    function live(): void {
        if (!enabled || !chainProc.running) return;
        ShellState.osdQuietUntil = Date.now() + 800;
        const p = ['"pre:Gain" ' + preamp.toFixed(2)];
        bands.forEach((b, i) => { if (b.on) p.push('"b' + i + ':Freq" ' + b.freq.toFixed(1), '"b' + i + ':Gain" ' + b.gain.toFixed(2), '"b' + i + ':Q" ' + b.q.toFixed(3)); });
        Quickshell.execDetached(["sh", "-c",
            'id=$(pw-cli ls Node | awk \'/^[[:space:]]*id /{id=$2} /node.name = "effect_input.nyash_eq"/{gsub(",","",id); print id; exit}\'); ' +
            '[ -n "$id" ] && pw-cli set-param "$id" Props "{ params = [ $1 ] }"', "sh", p.join(" ")]);
    }

    // ─── АЧХ для графика (формулы RBJ, частота дискретизации 48 кГц) ───
    // ─── frequency response for the graph (RBJ formulas, 48 kHz sample rate) ───
    function response(b, f: real): real {
        if (!b.on) return 0;
        const fs = 48000, w0 = 2 * Math.PI * b.freq / fs, A = Math.pow(10, b.gain / 40);
        const cw = Math.cos(w0), sw = Math.sin(w0), al = sw / (2 * Math.max(0.05, b.q)), sA = Math.sqrt(A);
        let b0, b1, b2, a0, a1, a2;
        switch (b.type) {
        case "lowshelf":  b0 = A*((A+1)-(A-1)*cw+2*sA*al); b1 = 2*A*((A-1)-(A+1)*cw); b2 = A*((A+1)-(A-1)*cw-2*sA*al);
                          a0 = (A+1)+(A-1)*cw+2*sA*al; a1 = -2*((A-1)+(A+1)*cw); a2 = (A+1)+(A-1)*cw-2*sA*al; break;
        case "highshelf": b0 = A*((A+1)+(A-1)*cw+2*sA*al); b1 = -2*A*((A-1)+(A+1)*cw); b2 = A*((A+1)+(A-1)*cw-2*sA*al);
                          a0 = (A+1)-(A-1)*cw+2*sA*al; a1 = 2*((A-1)-(A+1)*cw); a2 = (A+1)-(A-1)*cw-2*sA*al; break;
        case "lowpass":   b0 = (1-cw)/2; b1 = 1-cw; b2 = (1-cw)/2; a0 = 1+al; a1 = -2*cw; a2 = 1-al; break;
        case "highpass":  b0 = (1+cw)/2; b1 = -(1+cw); b2 = (1+cw)/2; a0 = 1+al; a1 = -2*cw; a2 = 1-al; break;
        case "notch":     b0 = 1; b1 = -2*cw; b2 = 1; a0 = 1+al; a1 = -2*cw; a2 = 1-al; break;
        case "bandpass":  b0 = al; b1 = 0; b2 = -al; a0 = 1+al; a1 = -2*cw; a2 = 1-al; break;
        default:          b0 = 1+al*A; b1 = -2*cw; b2 = 1-al*A; a0 = 1+al/A; a1 = -2*cw; a2 = 1-al/A;
        }
        const w = 2 * Math.PI * f / fs, c1 = Math.cos(w), s1 = Math.sin(w), c2 = Math.cos(2*w), s2 = Math.sin(2*w);
        const nr = b0 + b1*c1 + b2*c2, ni = -(b1*s1 + b2*s2), dr = a0 + a1*c1 + a2*c2, di = -(a1*s1 + a2*s2);
        return 10 * Math.log10((nr*nr + ni*ni) / (dr*dr + di*di));
    }
    function total(f: real): real { return preamp + bands.reduce((s, b) => s + response(b, f), 0); }

    // ─── импорт и экспорт: формат совместим с Poweramp Equalizer ───
    // типы Poweramp: 0 — нижняя полка, 1 — верхняя полка; 2 («Полоса») и 3–4 — колоколообразные полосы
    // с усилением, у нас это «пик». Срезы и полосовой фильтр Poweramp экспортирует другими номерами —
    // при экспорте свой тип пишем ещё и в поле nyashType, чтобы ничего не терялось
    // ─── import and export: format compatible with Poweramp Equalizer ───
    // Poweramp types: 0 low shelf, 1 high shelf; 2 ("Band") and 3–4 are bell-shaped bands
    // with gain, which is our "peak". Poweramp exports cuts and band-pass under other numbers,
    // so on export we also write our own type into nyashType, so nothing is lost
    readonly property var paToOurs: ({ 0: "lowshelf", 1: "highshelf", 2: "peak" })
    readonly property var oursToPa: ({ lowshelf: 0, highshelf: 1, peak: 2 })
    function toHex(c): string {
        if (typeof c === "string") return c;
        if (!c) return "";
        return "#" + ((c >>> 0) & 0xffffff).toString(16).padStart(6, "0");
    }
    function fromJson(d): bool {
        if (!d || !Array.isArray(d.bands)) return false;
        bands = d.bands.slice(0, 16).map((b, i) => ({
            type: b.nyashType ?? paToOurs[b.type] ?? (typeof b.type === "string" ? b.type : "peak"),
            freq: Math.max(20, Math.min(20000, b.frequency ?? b.freq ?? 1000)),
            gain: Math.max(-15, Math.min(15, b.gain ?? 0)),
            q: Math.max(0.1, Math.min(12, b.q ?? 1)),
            on: b.on ?? true,
            color: toHex(b.color) || palette[i % palette.length]
        }));
        preamp = Math.max(-24, Math.min(12, d.preamp ?? 0));
        return true;
    }
    function toJson(name: string): var {
        return {
            name: name || preset || "nyashell",
            preamp: preamp,
            parametric: true,
            bands: bands.map(b => ({ type: oursToPa[b.type] ?? 2, nyashType: b.type, channels: 0, frequency: b.freq,
                                     q: b.q, gain: b.gain, on: b.on, color: b.color }))
        };
    }
    Process {
        id: importProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) return;
                try {
                    const d = JSON.parse(t);
                    if (eq.fromJson(d)) { eq.savePreset(d.name || "imported"); eq.restart(); }
                } catch (err) { Quickshell.execDetached(["notify-send", "-a", "nyashell", "EQ", L.t("не получилось прочитать файл эквалайзера")]); }
            }
        }
    }
    // выбор файла — тем же диалогом, что и обои
    // file choice: the same dialog as for wallpapers
    function importDialog(): void {
        importProc.command = ["sh", "-c",
            'f=$(zenity --file-selection --file-filter="*.json" 2>/dev/null || kdialog --title "EQ" --getopenfilename "$HOME" "*.json" 2>/dev/null); [ -n "$f" ] && cat "$f"'];
        importProc.running = true;
    }
    readonly property bool picking: importProc.running || exportProc.running   // см. ShellState.fileDialog / see ShellState.fileDialog
    Process { id: exportProc }
    function exportDialog(): void {
        const name = preset || "nyashell-eq";
        if (exportProc.running) return;
        exportProc.command = ["sh", "-c",
            'f=$(zenity --file-selection --save --filename="$HOME/$1.json" 2>/dev/null || kdialog --title "EQ" --getsavefilename "$HOME/$1.json" "*.json" 2>/dev/null); ' +
            '[ -n "$f" ] && printf "%s" "$2" > "$f" && notify-send -a nyashell EQ "$f"', "sh", name, JSON.stringify(toJson(name), null, "\t")];
        exportProc.running = true;
    }
}
