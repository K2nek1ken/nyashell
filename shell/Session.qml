pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// «заморозка» сеанса: какие программы были открыты, на каких страницах и в каких папках.
// сохраняется при выходе/перезагрузке/выключении и раз в пару минут (на случай сбоя),
// восстанавливается при следующем входе. Живые процессы через перезапуск mango не переживают
// (Wayland-приложения закрываются вместе с композитором), поэтому их запускаем заново,
// а свои вкладки/документы они восстанавливают сами. Перезапуск шелла окна не трогает вообще.
// session "freezing": which apps were open, on which pages and in which folders.
// saved on logout/reboot/power off and every couple of minutes (in case of a crash),
// restored at the next login. Live processes don't survive a mango restart
// (Wayland apps close together with the compositor), so they are started again,
// and they restore their own tabs/documents. Restarting the shell doesn't touch the windows at all.
Singleton {
    id: ses
    readonly property string home: Quickshell.env("HOME")
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string file: home + "/.config/quickshell/nyashell/session.json"
    readonly property string termDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/nyashell/term"
    readonly property bool enabled: ShellState.settings.restoreSession ?? true
    property var after: null            // что сделать после сохранения / what to do after saving
    property var saving: []              // окна, которые сохраняем / the windows being saved
    property var expect: []              // что ждём после запуска: [{appid, tag}] / what we wait for after launch: [{appid, tag}]
    property var seen: []                // id окон, которые уже были / ids of windows that already existed

    FileView { id: sf; path: ses.file; blockLoading: true; printErrors: false; watchChanges: true }

    // ─── сохранение ───
    // ─── saving ───
    function save(then): void {
        after = then || null;
        const skip = /^(nyash-browser|quickshell|org\.quickshell)$/;
        saving = ShellState.mangoClients.filter(c => c.pid > 0 && !c.is_scratchpad && !skip.test(c.appid || ""));
        const pids = Array.from(new Set(saving.map(c => String(c.pid))));
        if (!pids.length) { writeAndFinish("[]"); return; }
        // для простых окон kitty (без своей команды) — ещё и снимок экрана со всей прокруткой и папка, в которой
        // сейчас стоит оболочка: kitty отдаёт их через свой сокет (listen_on в kitty.conf).
        // Строка «K<TAB>pid<TAB>json» — что вернул «kitty @ ls» (папка); текст экрана — в файл term/<pid>.txt
        // for plain kitty windows (without their own command), also a screen snapshot with all the scrollback and the folder
        // where the shell currently is: kitty hands them over through its socket (listen_on in kitty.conf).
        // The line "K<TAB>pid<TAB>json" is what "kitty @ ls" returned (the folder); the screen text goes to term/<pid>.txt
        reader.command = ["sh", "-c",
            'd="$1"; shift; mkdir -p "$d"; rm -f "$d"/*.txt; ' +
            'for p in "$@"; do printf "%s\\t%s\\t" "$p" "$(readlink /proc/$p/cwd 2>/dev/null)"; ' +
            'tr "\\000" "\\037" < /proc/$p/cmdline 2>/dev/null; echo; ' +
            'sock="$XDG_RUNTIME_DIR/nyash-kitty-$p"; ' +
            'if [ -S "$sock" ] && [ "$(tr "\\000" " " < /proc/$p/cmdline | sed "s/ *$//; s#.*/##")" = kitty ]; then ' +
            '  timeout 2 kitty @ --to "unix:$sock" get-text --extent all --ansi 2>/dev/null | tail -n 3000 > "$d/$p.txt"; ' +
            '  printf "K\\t%s\\t" "$p"; timeout 2 kitty @ --to "unix:$sock" ls 2>/dev/null | tr -d "\\n"; echo; ' +
            'fi; done', "sh", ses.termDir].concat(pids);
        reader.running = true;
        guard.restart();
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const byPid = {}, kitty = {};
                for (const l of text.split("\n")) {
                    // ответ kitty: папка, где сейчас оболочка в активном окне
                    // kitty's answer: the folder where the shell is in the active window
                    if (l.startsWith("K\t")) {
                        const k = l.split("\t");
                        try {
                            const os = JSON.parse(k.slice(2).join("\t"))[0];
                            const tab = (os.tabs || []).find(t => t.is_focused) || (os.tabs || [])[0];
                            const w = (tab.windows || []).find(x => x.is_focused) || (tab.windows || [])[0];
                            const fg = (w.foreground_processes || [])[0] || {};
                            // запускали ли в окне хоть одну команду (kitty знает это через интеграцию с оболочкой).
                            // Нет — восстанавливаем как свежий терминал, без снимка (иначе старый fastfetch + новый)
                            // whether any command was run in the window; if not, restore it as a fresh terminal
                            const used = w.last_reported_cmdline === undefined ? true : !!w.last_reported_cmdline;
                            const shellFg = /(^|\/)(fish|bash|zsh|sh)$/.test((fg.cmdline || [])[0] || "");
                            kitty[k[1]] = { cwd: fg.cwd || w.cwd || "", used: used, trim: shellFg };
                        } catch (e) { kitty[k[1]] = { cwd: "", used: true, trim: false }; }
                        continue;
                    }
                    const f = l.split("\t");
                    if (f.length < 3) continue;
                    const args = f.slice(2).join("\t").split("\x1f").filter(a => a.length);
                    if (args.length) byPid[f[0]] = { cwd: f[1], args: args };
                }
                const out = [], done = new Set();
                for (const c of ses.saving) {
                    const p = byPid[String(c.pid)];
                    if (!p || done.has(c.pid)) continue;       // одно окно на процесс — второе приложение откроет само / one window per process: the app opens the second one itself
                    if (p.args.join(" ").includes("nyash-browser")) continue;   // браузер из борда шелл запустит сам / the shell starts the dashboard browser itself
                    done.add(c.pid);
                    const e = { appid: c.appid, tag: (c.tags || [1])[0], cwd: p.cwd, args: p.args };
                    const kt = kitty[String(c.pid)];
                    if (kt !== undefined) {
                        if (kt.cwd) e.cwd = kt.cwd;
                        if (kt.used) { e.screen = ses.termDir + "/" + c.pid + ".txt"; e.trim = kt.trim; }
                    }
                    out.push(e);
                }
                if (ses.after) ses.log("сохраняю перед выходом: " + out.map(e => e.appid).join(", "));
                ses.writeAndFinish(JSON.stringify(out, null, 1));
            }
        }
    }
    // FileView пишет асинхронно — при выходе mango шелл умирал раньше, чем файл успевал записаться.
    // поэтому пишем отдельным процессом и продолжаем только когда он закончил
    // FileView writes asynchronously: on mango exit the shell died before the file was written.
    // so we write with a separate process and continue only once it has finished
    Process {
        id: writer
        onExited: ses.finish()
    }
    function writeAndFinish(json: string): void {
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "sh", ses.file, json];
        writer.running = true;
    }
    // если /proc не прочитался — всё равно выходим
    // if /proc couldn't be read, exit anyway
    Timer { id: guard; interval: 2000; onTriggered: ses.finish() }
    function finish(): void {
        guard.stop();
        const f = after; after = null;
        if (f) f();
    }
    Timer { interval: 120000; repeat: true; running: ses.enabled; onTriggered: ses.save(null) }

    // ─── восстановление: только один раз за запуск mango ───
    // Раньше метка «уже восстановлено» была просто файлом в XDG_RUNTIME_DIR. Но эта папка живёт, пока жив
    // пользовательский systemd, — при быстром выходе и входе (и при некоторых настройках logind) она переживала
    // новый вход, метка оставалась, и сеанс не восстанавливался никогда. Теперь в метке — PID текущего mango:
    // новый mango = новый сеанс = восстанавливаем; перезапуск самого шелла — тот же mango, не восстанавливаем
    // ─── restore: only once per mango launch ───
    // The "already restored" mark used to be just a file in XDG_RUNTIME_DIR. But that folder lives as long as the
    // user's systemd does: on a quick logout and login (and with some logind settings) it survived the
    // new login, the mark stayed and the session was never restored. Now the mark holds the current mango's PID:
    // new mango = new session = restore; restarting the shell itself keeps the same mango, no restore
    Process {
        id: marker
        command: ["sh", "-c", 'm="$1/nyash-restored"; cur=$(pgrep -x mango | head -1); [ -n "$cur" ] || cur=none; ' +
                  '[ "$(cat "$m" 2>/dev/null)" = "$cur" ] && exit 1; printf "%s" "$cur" > "$m"', "sh", ses.runtime]
        onExited: (code) => { ses.log(code === 0 ? "новый сеанс mango — восстанавливаю" : "тот же сеанс mango (перезапуск шелла) — не восстанавливаю");
                              if (code === 0 && ses.enabled) startLater.restart(); }
    }
    // короткий журнал: что сохранили и что восстановили (~/.local/state/nyashell/session.log, последние 200 строк)
    // a short log: what was saved and what was restored (~/.local/state/nyashell/session.log, last 200 lines)
    function log(msg: string): void {
        Quickshell.execDetached(["sh", "-c", 'd="${XDG_STATE_HOME:-$HOME/.local/state}/nyashell"; mkdir -p "$d"; f="$d/session.log"; ' +
            'printf "%s %s\n" "$(date "+%F %T")" "$1" >> "$f"; tail -n 200 "$f" > "$f.tmp" && mv "$f.tmp" "$f"', "sh", msg]);
    }
    Component.onCompleted: marker.running = true
    Timer { id: startLater; interval: 2500; onTriggered: ses.restore() }

    function restore(): void {
        let list = [];
        try { list = JSON.parse(sf.text() || "[]"); } catch (e) { list = []; }
        if (!list.length) { log("сохранённый сеанс пуст — восстанавливать нечего"); return; }
        log("восстанавливаю: " + list.map(e => e.appid).join(", "));
        seen = ShellState.mangoClients.map(c => c.id);
        expect = list.map((e, i) => ({ appid: e.appid, tag: e.tag, uid: i }));
        list.forEach((e, i) => { e.uid = i; });
        // окна сразу открываются на своих страницах и тихо (без перехода на них): для каждого — одноразовое
        // правило mango (windowrule-once, по одному на окно — см. патч). Раньше окно открывалось на текущей
        // странице и потом переезжало — всё дёргалось, пока не восстановится последнее
        // windows open straight on their own pages and quietly (without switching to them): each gets a one-time
        // mango rule (windowrule-once, one per window, see the patch). Previously a window opened on the current
        // page and then moved, and everything jumped around until the last one was restored
        const esc = (a) => String(a).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const rules = list.filter(e => e.appid && e.tag > 0)
            .map(e => "windowrule-once=appid:^" + esc(e.appid) + "$,tags:" + e.tag + ",istagsilent:1").join("\n");
        pending = list;
        rulesWriter.command = ["sh", "-c", 'printf "%s\\n" "$2" > "$1" && mmsg dispatch reload_config', "sh", ses.rulesFile, rules];
        rulesWriter.running = true;
        stopWaiting.restart();
    }
    readonly property string rulesFile: home + "/.config/mango/nyash-restore.conf"
    property var pending: []
    Process {
        id: rulesWriter
        // правила на месте — запускаем программы (по одной, с небольшим шагом)
        // the rules are in place: start the apps (one by one, with a small step)
        onExited: { const l = ses.pending; ses.pending = []; l.forEach((e, i) => ses.launchLater(e, 300 + i * 350)); }
    }
    // все окна пришли (или прошла минута) — одноразовые правила больше не нужны
    // all windows have arrived (or a minute has passed): the one-time rules are no longer needed
    function clearRules(): void {
        Quickshell.execDetached(["sh", "-c", ': > "$1" && mmsg dispatch reload_config', "sh", ses.rulesFile]);
    }
    onExpectChanged: if (!expect.length && !pending.length) clearLater.restart()
    Timer { id: clearLater; interval: 3000; onTriggered: ses.clearRules() }
    // ярлык программы по id окна — так же, как значки на панели (TaskApp.qml)
    // the app's desktop entry by window app id, the same lookup as the taskbar icons use
    function entryFor(appid: string): var {
        const a = appid || "", low = a.toLowerCase();
        const e = DesktopEntries.byId(a) ?? DesktopEntries.byId(low) ?? (DesktopEntries.heuristicLookup?.(a) ?? null);
        if (e) return e;
        const all = DesktopEntries.applications.values;
        return all.find(x => (x.startupClass || "").toLowerCase() === low)
            ?? all.find(x => x.name.toLowerCase().replace(/\s+/g, "") === low.replace(/[\s._-]+/g, ""))
            ?? all.find(x => x.id.toLowerCase().includes(low) || low.includes(x.id.toLowerCase().split(".").pop()))
            ?? null;
    }
    function launchEntry(e): void {
        const d = entryFor(e.appid);
        if (d) { log("запускаю по ярлыку: " + e.appid + " → " + d.id); d.execute(); }
        else log("нет ярлыка для " + e.appid + " — не восстановлено");
    }
    function fallbackLater(e): void {
        const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 9000 }', ses);
        t.triggered.connect(() => {
            if (ses.expect.some(x => x.uid === e.uid)) { log(e.appid + ": окно не появилось по сохранённой команде"); ses.launchEntry(e); }
            t.destroy();
        });
        t.start();
    }
    function launchLater(e, delay: int): void {
        const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false }', ses);
        t.interval = Math.max(1, delay);
        t.triggered.connect(() => {
            if (e.screen) {
                // терминал: показать сохранённый экран и запустить оболочку там, где она была. Сами процессы
                // (то, что было запущено) через выход не переживают — это видно по снимку, его можно перечитать
                // terminal: show the saved screen and start the shell where it was. The processes themselves
                // (whatever was running) don't survive a logout; that's visible from the snapshot, which you can reread
                const f = e.screen.replace(/\.txt$/, "") + "-shown.txt";
                // в конце снимка — старое приглашение оболочки (если в окне стояла оболочка): его срезаем вместе с
                // пустыми строками, ниже оболочка нарисует свежее. NYASH_RESTORED — чтобы fish не печатал fastfetch
                // the old prompt at the end of the snapshot is cut off; NYASH_RESTORED stops fish from printing fastfetch
                Quickshell.execDetached(["sh", "-c",
                    'mv -f "$2" "$3" 2>/dev/null; cd "$1" 2>/dev/null || cd; ' +
                    'exec env NYASH_RESTORED=1 kitty --directory "$(pwd)" sh -c \'' +
                    'awk -v trim="$2" \'\\\'\'{ l[NR] = $0 } END { n = NR; ' +
                    'while (n > 0) { t = l[n]; gsub(/\\033\\[[0-9;?]*[A-Za-z]/, "", t); if (t ~ /[^[:space:]]/) break; n-- } ' +
                    'if (trim == 1 && n > 0) n--; for (i = 1; i <= n; i++) print l[i] }\'\\\'\' "$1" 2>/dev/null; ' +
                    'rm -f "$1"; exec "${SHELL:-/bin/sh}"\' sh "$3" "$4"',
                    "sh", e.cwd || ses.home, e.screen, f, e.trim ? "1" : "0"]);
            } else if (e.appid === "nemo") {
                // Немо: все окна — один процесс; обёртка откроет все запомненные папки
                // Nemo: all windows are one process; the wrapper reopens every remembered folder
                Quickshell.execDetached(["sh", Quickshell.shellPath("files/nemo-open.sh")]);
            } else if (e.args.some(a => a.startsWith("--type="))) {
                // сохранился служебный процесс Electron/Chromium, а не сама программа — запускаем по ярлыку
                // a helper process of Electron/Chromium was saved, not the app itself: launch from its desktop entry
                ses.launchEntry(e);
            } else {
                Quickshell.execDetached(["sh", "-c", 'cd "$1" 2>/dev/null; shift; exec "$@"', "sh", e.cwd || ses.home].concat(e.args));
                // окно так и не появилось (так было с DeltaChat: его команда запуска сама по себе не стартует
                // программу) — запускаем по ярлыку, как из меню
                // no window after a while (DeltaChat did this): fall back to the desktop entry, as the menu would
                ses.fallbackLater(e);
            }
            t.destroy();
        });
        t.start();
    }
    // новые окна раскладываем по их старым страницам
    // new windows are placed on their old pages
    Connections {
        target: ShellState
        function onMangoClientsChanged() {
            if (!ses.expect.length) return;
            for (const c of ShellState.mangoClients) {
                if (ses.seen.includes(c.id)) continue;
                ses.seen = ses.seen.concat([c.id]);
                const i = ses.expect.findIndex(x => x.appid === c.appid);
                if (i < 0) continue;
                const tag = ses.expect[i].tag;
                ses.expect = ses.expect.filter((_, k) => k !== i);
                if (!(c.tags || []).includes(tag))
                    Quickshell.execDetached(["mmsg", "dispatch", "tagsilent," + tag, "client," + c.id]);
            }
        }
    }
    Timer { id: stopWaiting; interval: 60000; onTriggered: { ses.expect = []; ses.clearRules(); } }
}
