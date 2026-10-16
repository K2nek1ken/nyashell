pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// сочетания клавиш: читаем из конфига mango, показываем по-человечески, даём переназначить.
// переназначения хранятся в настройках шелла и заново применяются к конфигу при каждом старте —
// так они переживают обновления (install.sh кладёт свежий конфиг)
// key bindings: read from the mango config, shown in human terms, can be reassigned.
// reassignments are stored in the shell settings and reapplied to the config on every start,
// so they survive updates (install.sh puts a fresh config in place)
Singleton {
    id: b
    readonly property string file: Quickshell.env("HOME") + "/.config/mango/config.conf"
    // сигнатура действия -> { to: "MODS,KEY" или "NONE" (снято), from: "MODS,KEY" (как было по умолчанию) }
    // action signature -> { to: "MODS,KEY" or "NONE" (unbound), from: "MODS,KEY" (the default) }
    readonly property var overrides: {
        const raw = ShellState.settings.binds ?? {}, out = {};
        for (const k in raw) out[k] = typeof raw[k] === "string" ? { to: raw[k], from: "" } : raw[k];
        return out;
    }
    readonly property string offMark: "#nyash-off "   // так помечаем снятые сочетания в конфиге / this is how unbound shortcuts are marked in the config

    FileView {
        id: cf
        path: b.file
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: cf.reload()
        onLoaded: b.parse()
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { b.parse() }
}

    // что делает сочетание — по-человечески
    // what a shortcut does, in human terms
    function describe(kind: string, action: string): string {
        const a = action;
        const map = [
            ["launcher toggle", "Меню приложений"], ["dashboard toggle", "Борд"], ["widgets clipboard", "Буфер обмена"],
            ["widgets calc", "Калькулятор"], ["widgets power", "Меню питания"], ["widgets settings", "Настройки"],
            ["widgets lang", "Язык интерфейса"], ["widgets monitor", "Монитор системы"], ["widgets killApp", "Завершить приложение"], ["widgets wallpaper", "Выбор обоев"], ["widgets gifs", "Гифки: двигать и менять размер"], ["widgets recordAreaMic", "Запись области с микрофоном"], ["widgets recordMic", "Запись экрана с микрофоном"], ["widgets recordArea", "Запись области"], ["widgets record", "Запись экрана"], ["lock lock", "Заблокировать"], ["session logout", "Выйти из сеанса"], ["pages prev", "Назад: лента на окно влево или страница"],
            ["pages next", "Вперёд: лента на окно вправо или страница"], ["osd volume_up", "Громче"], ["osd volume_down", "Тише"],
            ["osd mute", "Без звука"], ["osd brightness_up", "Ярче"], ["osd brightness_down", "Темнее"],
            ["nyashell/restart.sh", "Перезапустить шелл"], ["spawn,kitty", "Терминал"], ["spawn,nemo", "Файлы"], ["nemo-open.sh", "Файлы"],
            ["killclient", "Закрыть окно"], ["togglefloating", "Плавающее окно"], ["togglefullscreen", "На весь экран"],
            ["switch_layout", "Лента ↔ сетка"], ["switch_proportion_preset", "Ширина окна в ленте"],
            ["focusdir,left", "Фокус влево"], ["focusdir,right", "Фокус вправо"], ["focusdir,up", "Фокус вверх"],
            ["focusdir,down", "Фокус вниз"], ["move_client,left", "Окно влево"], ["move_client,right", "Окно вправо"],
            ["move_client,up", "Окно вверх"], ["move_client,down", "Окно вниз"], ["tagtoleft", "Окно на страницу назад"],
            ["tagtoright", "Окно на страницу вперёд"], ["reload_config", "Перечитать конфиг mango"], ["quit", "Выйти из сеанса"],
            ["viewtoleft", "Страница назад"], ["viewtoright", "Страница вперёд"],
            ["moveresize,curmove", "Перетащить окно"], ["moveresize,curresize", "Изменить размер окна"], ["minimized", "Свернуть окно"],
            ["mpd-skip.sh prev", "Предыдущий трек"], ["mpd-skip.sh next", "Следующий трек"], ["mpc -q prev", "Предыдущий трек"], ["mpc -q next", "Следующий трек"], ["mpc -q toggle", "Пауза / играть"],
            ["player shuffle", "Перемешивание вкл/выкл"], ["player repeat", "Повтор: список → трек → выкл"],
            ["screenshot.sh full", "Скриншот экрана"], ["screenshot.sh area", "Скриншот области"], ["nya_shot_region", "Скриншот области"],
            ["playerctl play-pause", "Пауза / играть"], ["playerctl next", "Следующий трек"], ["playerctl previous", "Предыдущий трек"]
        ];
        for (const [k, v] of map) if (a.includes(k)) return L.t(v);
        return a;
    }
    function pretty(mods: string, key: string, kind: string): string {
        const m = mods === "NONE" ? [] : mods.split("+").map(x => ({ SUPER: "Super", CTRL: "Ctrl", SHIFT: "Shift", ALT: "Alt" })[x] ?? x);
        const k = kind === "mousebind" ? ({ btn_left: "ЛКМ", btn_right: "ПКМ", btn_middle: "СКМ" })[key] ?? key
                : kind === "axisbind" ? L.t("колесо") : key.length === 1 ? key.toUpperCase() : key.replace(/^XF86/, "");
        return m.concat([L.t(k)]).join(" + ") + (kind === "bindr" ? " " + L.t("(отпустить)") : "");
    }

    property var list: []        // [{line, kind, mods, key, action, sig, text, combo}]
    // группы для окна настроек: по смыслу, а не в порядке строк конфига
    // groups for the settings window: by meaning, not by the order of config lines
    readonly property var groupOrder: [["shell", "Шелл"], ["shots", "Скриншоты и запись"], ["windows", "Окна"], ["pages", "Страницы"],
                                       ["media", "Музыка, звук и яркость"], ["apps", "Программы"], ["system", "Система"]]
    function category(e): string {
        const a = e.action;
        if (/screenshot\.sh|widgets record|nya_shot_region/.test(a)) return "shots";
        if (/osd |mpd-skip|mpc |playerctl|XF86Audio|ipc call player /.test(a) || /^XF86(Audio|MonBrightness)/.test(e.key)) return "media";
        if (/pages (prev|next)|viewto|tagto|^view,|^tag,/.test(a) || e.kind === "axisbind") return "pages";
        if (/killclient|minimized|killApp|togglefloating|togglefullscreen|focusdir|move_client|moveresize|switch_proportion_preset|switch_layout|togglemaximize/.test(a)) return "windows";
        if (/reload_config|^quit|restart\.sh|session logout/.test(a)) return "system";
        if (/^spawn,(kitty|nemo|foot|alacritty|firefox)/.test(a) || /^spawn,[a-z-]+$/.test(a) || /nemo-open\.sh/.test(a)) return "apps";
        return "shell";
    }
    readonly property var groups: {
        const out = [];
        for (const [id, title] of groupOrder) {
            const items = list.filter(e => category(e) === id)
                .sort((x, y) => describe(x.kind, x.action).localeCompare(describe(y.kind, y.action)));
            if (items.length) out.push({ id: id, title: title, items: items });
        }
        return out;
    }
    // ─── сочетания, заглушённые в отдельных программах ───
    // Настройки → Ввод → «Глушить сочетания в программах». Каждое правило — строка конфига
    //   bind=CTRL,q,blockfor,(?i)(deltachat|telegram)
    // blockfor — действие из патча mango: если в фокусе окно этих программ, нажатие проглатывается и до
    // программы не доходит; в остальных окнах сочетание работает как обычно. Настоящее сочетание на тех же
    // клавишах всегда важнее. В списке клавиш эти строки не показываются
    // ─── shortcuts muted in specific apps ───
    // Settings → Input → "Mute shortcuts in specific apps". Each rule is a config line
    // bind=CTRL,q,blockfor,(?i)(deltachat|telegram)
    // blockfor is an action from the mango patch: if one of these apps is focused, the key press is swallowed and never
    // reaches the app; in other windows the shortcut works as usual. A real binding on the same
    // keys always wins. These lines are not shown in the key list
    readonly property var blockLines: (ShellState.settings.keyBlocks ?? []).map(r => {
        const apps = String(r.apps ?? "").split(/[\s,;|]+/).map(x => x.replace(/[^A-Za-z0-9._-]/g, "")).filter(x => x)
                         .map(x => x.replace(/\./g, "\\."));
        return r.key && apps.length ? "bind=" + (r.mods || "NONE") + "," + r.key + ",blockfor,(?i)(" + apps.join("|") + ")" : "";
    }).filter(x => x)
    property var blockInFile: []
    property bool blockSent: false
    onBlockLinesChanged: Qt.callLater(syncBlocks)
    function syncBlocks(): void {
        if (!ShellState.startupDone) return;
        if (JSON.stringify(blockLines) === JSON.stringify(blockInFile)) { blockSent = false; return; }
        if (blockSent) return;            // правка уже ушла — ждём, пока файл перечитается / the edit has already been sent; wait for the file to be reread
        blockSent = true;
        ShellState.cfgEdit(["sh", "-c",
            'f="$1"; shift; awk \'!/^bind=[^,]*,[^,]*,blockfor,/\' "$f" > "$f.tmp" && ' +
            '{ for l in "$@"; do printf "%s\\n" "$l" >> "$f.tmp"; done; mv "$f.tmp" "$f"; }',
            "sh", b.file].concat(blockLines));
    }
    Connections { target: ShellState; function onStartupDoneChanged() { Qt.callLater(b.syncBlocks); } }

    function parse(): void {
        const out = [];
        const blocks = [];
        cf.text().split("\n").forEach((l, i) => {
            if (/^bind=[^,]*,[^,]*,blockfor,/.test(l)) { blocks.push(l.trim()); return; }   // не настоящее сочетание / not a real shortcut
            const m = l.match(/^(#nyash-off )?(bind|bindr|bindl|mousebind|axisbind)=([^,]*),([^,]*),(.*)$/);
            if (!m) return;
            const action = m[5].trim(), off = !!m[1];
            out.push({ line: i + 1, off: off, kind: m[2], mods: m[3].trim(), key: m[4].trim(), action: action,
                       sig: m[2] + "|" + action, text: describe(m[2], action),
                       combo: off ? "—" : pretty(m[3].trim(), m[4].trim(), m[2]) });
        });
        list = out;
        blockInFile = blocks;
        blockSent = false;
        Qt.callLater(syncBlocks);
    }
    Component.onCompleted: parse()
    Timer { interval: 2500; running: true; onTriggered: { b.parse(); b.applyOverrides(); } }

    // заменить сочетание у действия: пишем в конфиг и перечитываем mango
    // replace an action's shortcut: write it to the config and reload mango
    function remember(entry, to: string): void {
        const o = Object.assign({}, overrides);
        const prev = o[entry.sig];
        o[entry.sig] = { to: to, from: prev?.from || (entry.off ? "" : entry.mods + "," + entry.key) };
        ShellState.set("binds", o);
    }
    // ЛКМ: новое сочетание
    // left click: a new shortcut
    function set(entry, mods: string, key: string): void {
        remember(entry, mods + "," + key);
        writeLine(entry, entry.kind + "=" + mods + "," + key + "," + entry.action);
    }
    // ПКМ: снять сочетание (строка остаётся в конфиге, но закомментирована — mango его отпускает)
    // right click: unbind (the line stays in the config but commented out, so mango releases it)
    function clear(entry): void {
        if (entry.off) return;
        remember(entry, "NONE");
        writeLine(entry, offMark + entry.kind + "=" + entry.mods + "," + entry.key + "," + entry.action);
    }
    // СКМ: вернуть как было по умолчанию
    // middle click: back to the default
    function restore(entry): void {
        const o = Object.assign({}, overrides), was = o[entry.sig];
        if (!was) return;
        delete o[entry.sig];
        ShellState.set("binds", o);
        if (was.from) {
            const [m, k] = was.from.split(",");
            writeLine(entry, entry.kind + "=" + m + "," + k + "," + entry.action);
        }
    }
    // строку ищем не по номеру, а по самому действию (номера строк меняются от версии к версии конфига)
    // the line is found by the action itself, not by number (line numbers change between config versions)
    function writeLine(entry, text: string): void {
        ShellState.cfgEdit(["sh", "-c",
            'awk -v k="$1" -v a="$2" -v r="$3" \'{ l=$0; sub(/^#nyash-off /, "", l); ' +
            'if (index(l, k "=") == 1) { rest = substr(l, length(k) + 2); if (match(rest, /^[^,]*,[^,]*,/) && substr(rest, RLENGTH + 1) == a) $0 = r } } 1\' ' +
            '"$4" > "$4.tmp" && mv "$4.tmp" "$4"',
            "sh", entry.kind, entry.action, text, b.file]);
    }
    // при старте: переназначения снова в конфиг (он мог обновиться)
    // on start: reassignments go back into the config (it may have been updated)
    function applyOverrides(): void {
        for (const e of list) {
            const o = overrides[e.sig];
            if (!o) continue;
            if (o.to === "NONE") {
                if (!e.off) writeLine(e, offMark + e.kind + "=" + e.mods + "," + e.key + "," + e.action);
                continue;
            }
            const [mods, key] = o.to.split(",");
            if (e.off || mods !== e.mods || key !== e.key) writeLine(e, e.kind + "=" + mods + "," + key + "," + e.action);
        }
    }
    function conflict(mods: string, key: string, except): var {
        return list.find(e => e !== except && !e.off && e.kind !== "mousebind" && e.kind !== "axisbind" && e.mods === mods && e.key === key) ?? null;
    }

    // клавиша Qt → имя клавиши, как его ждёт mango
    // Qt key → key name as mango expects it
    function keyName(ev): string {
        const k = ev.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(97 + k - Qt.Key_A);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(48 + k - Qt.Key_0);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1);
        const t = {};
        t[Qt.Key_Space] = "space"; t[Qt.Key_Tab] = "Tab"; t[Qt.Key_Backtab] = "Tab"; t[Qt.Key_Return] = "Return";
        t[Qt.Key_Enter] = "Return"; t[Qt.Key_Left] = "Left"; t[Qt.Key_Right] = "Right"; t[Qt.Key_Up] = "Up";
        t[Qt.Key_Down] = "Down"; t[Qt.Key_Minus] = "minus"; t[Qt.Key_Equal] = "equal"; t[Qt.Key_Comma] = "comma";
        t[Qt.Key_Period] = "period"; t[Qt.Key_Slash] = "slash"; t[Qt.Key_Backslash] = "backslash";
        t[Qt.Key_Semicolon] = "semicolon"; t[Qt.Key_Apostrophe] = "apostrophe"; t[Qt.Key_BracketLeft] = "bracketleft";
        t[Qt.Key_BracketRight] = "bracketright"; t[Qt.Key_QuoteLeft] = "grave"; t[Qt.Key_Delete] = "Delete";
        t[Qt.Key_Home] = "Home"; t[Qt.Key_End] = "End"; t[Qt.Key_PageUp] = "Prior"; t[Qt.Key_PageDown] = "Next";
        t[Qt.Key_Print] = "Print"; t[Qt.Key_Insert] = "Insert";
        return t[k] ?? "";
    }
    function modsOf(ev): string {
        const m = [];
        if (ev.modifiers & Qt.MetaModifier) m.push("SUPER");
        if (ev.modifiers & Qt.ControlModifier) m.push("CTRL");
        if (ev.modifiers & Qt.ShiftModifier) m.push("SHIFT");
        if (ev.modifiers & Qt.AltModifier) m.push("ALT");
        return m.length ? m.join("+") : "NONE";
    }
}
