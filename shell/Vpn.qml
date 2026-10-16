pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "VpnParse.js" as VP

// VPN-менеджер: группы (подписки и обычные), подключение через sing-box (TUN + прокси на порту),
// узлы, которые sing-box не умеет (XHTTP), — через Xray как звено цепочки. Этап 1
// VPN manager: groups (subscriptions and plain ones), connection through sing-box (TUN + a proxy on a port),
// nodes sing-box can't handle (XHTTP) go through Xray as a chain link. Stage 1
Singleton {
    id: v
    readonly property string dir: Quickshell.env("HOME") + "/.config/nyashell-vpn"

    property var groups: []        // [{id, name, type:"sub"|"manual", url, ua, headers:"K: V\n…", interval, updated, info, nodes:[…]}]
    property string selGroup: ""
    property int selNode: -1
    property bool tun: true
    property int port: 2080
    property bool autoConnect: false
    property bool wanted: false    // пользователь хочет быть подключённым / the user wants to be connected
    // маршруты: [{id, name, on, domains, ips, processes, outbound: "direct"|"proxy"|"block"}] — сверху вниз, первое совпадение
    // routes: [{id, name, on, domains, ips, processes, outbound: "direct"|"proxy"|"block"}], top to bottom, first match
    property var rules: []
    // настройки ядра
    // core settings
    property var opts: ({ remoteDns: "tcp://1.1.1.1", directDns: "local", strategy: "prefer_ipv4", fakeDns: false,
                          fragment: false, ipv6: false, bypassLan: true, mtu: 9000, stack: "mixed", mode: "rule", logLevel: "warn" })

    readonly property bool running: box.running
    readonly property var node: { const g = groups.find(x => x.id === selGroup); return g && g.nodes[selNode] ? g.nodes[selNode] : null; }
    property string status: ""     // текст ошибки или состояния / error or status text
    property real up: 0            // скорость, байт/с / speed, bytes/s
    property real down: 0
    property string busyGroup: ""  // какая подписка сейчас обновляется / which subscription is updating right now

    FileView {
        id: store
        path: v.dir + "/state.json"
        blockLoading: true
        printErrors: false
        onLoaded: v.load(text())
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) v.load(text())
}
    property bool loaded: false
    function load(t: string): void {
        try {
            const d = JSON.parse(t);
            v.groups = d.groups ?? []; v.selGroup = d.selGroup ?? ""; v.selNode = d.selNode ?? -1;
            v.tun = d.tun ?? true; v.port = d.port ?? 2080; v.wanted = d.wanted ?? false;
            // восстанавливать после перезагрузки: было подключено при выключении — подключиться снова (по умолчанию да)
            // restore after a reboot: if it was connected at shutdown, connect again (yes by default)
            v.autoConnect = d.restore ?? true;
            v.showLogs = d.showLogs ?? false;
            v.rules = d.rules ?? []; v.opts = Object.assign({}, v.opts, d.opts ?? {}); v.sysProxy = d.sysProxy ?? false;
            // прежнее значение по умолчанию → как в Exclave
            // the old default → as in Exclave
            if (v.opts.remoteDns === "tls://1.1.1.1") v.opts = Object.assign({}, v.opts, { remoteDns: "tcp://1.1.1.1" });
            v.loaded = true;
        } catch (e) {}
    }
    property bool showLogs: false
    function setShowLogs(on: bool): void { showLogs = on; save(); }
    function save(): void {
        store.setText(JSON.stringify({ groups: groups, selGroup: selGroup, selNode: selNode, tun: tun, port: port,
                                       restore: autoConnect, showLogs: showLogs, wanted: wanted, rules: rules, opts: opts, sysProxy: sysProxy }, null, 1));
    }
    Component.onCompleted: {
        if (!(ShellState.settings.vpnEnabled ?? true)) return;        // VPN выключен в настройках / VPN is turned off in the settings
        Quickshell.execDetached(["mkdir", "-p", dir]);
        // файл мог прочитаться позже этого обработчика (как было с настройками) — дочитываем сами,
        // иначе «был подключён» не успевало загрузиться, и VPN после перезагрузки не поднимался
        // the file may have been read after this handler (as happened with the settings), so read it ourselves,
        // otherwise "was connected" didn't load in time and the VPN didn't come up after a reboot
        if (!loaded && store.text()) load(store.text());
        if (autoConnect && wanted && node) startLater.restart();
        else stopCore();          // осталось от прошлого запуска шелла — аккуратно гасим, чтобы не висел туннель / left over from a previous shell run: shut it down gently so no tunnel is left hanging
        autoUpdate.start();
    }

    // ─── группы ───
    // ─── groups ───
    function uid(): string { return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36); }
    function addSubscription(name: string, url: string, ua: string, headers: string, interval: int): void {
        const g = { id: uid(), name: name || L.t("подписка"), type: "sub", url: url.trim(), ua: ua || "", headers: headers || "",
                    interval: interval || 12, updated: 0, info: {}, nodes: [] };
        groups = groups.concat([g]); save(); update(g.id);
    }
    function addManual(name: string, links: string): void {
        const nodes = VP.parseSubscription(links);
        groups = groups.concat([{ id: uid(), name: name || L.t("группа"), type: "manual", nodes: nodes, updated: Date.now(), info: {} }]); save();
    }
    function editGroup(id: string, patch): void {
        groups = groups.map(g => g.id === id ? Object.assign({}, g, patch) : g); save();
    }
    function removeGroup(id: string): void {
        groups = groups.filter(g => g.id !== id);
        if (selGroup === id) { selGroup = ""; selNode = -1; if (running) disconnect(); }
        save();
    }

    // обновление подписки: curl с твоими заголовками; из ответа — узлы, трафик/срок, название
    // updating a subscription: curl with your headers; from the response: nodes, traffic/expiry, name
    property var queue: []
    function update(id: string): void {
        if (busyGroup) { queue = queue.concat([id]); return; }
        const g = groups.find(x => x.id === id); if (!g || g.type !== "sub") return;
        busyGroup = id;
        const args = ["sh", "-c",
            // сначала напрямую; если соединение сбросили (часто так блокируют адрес подписки) и VPN включён —
            // ещё раз через сам VPN (локальный прокси). Ошибка curl уходит в журнал VPN целиком
            // direct first; if the connection was reset (subscription addresses are often blocked this way) and the VPN is on,
            // try again through the VPN itself (the local proxy). curl's error goes into the VPN log in full
            't=$(mktemp -d); url="$1"; ua="$2"; px="$3"; shift 3; ' +
            'set -- -sS -L --connect-timeout 5 --speed-time 5 --speed-limit 1 --max-time 25 -D "$t/h" -o "$t/b" ${ua:+-A "$ua"} "$@"; ' +
            'curl "$@" "$url" 2>"$t/e"; rc=$?; ' +
            'if [ "$rc" != 0 ] && [ -n "$px" ]; then : > "$t/h"; curl -x "$px" "$@" "$url" 2>>"$t/e"; rc=$?; fi; ' +
            'cat "$t/h"; echo "@@NYASH@@"; cat "$t/b"; echo "@@NYASH@@$rc"; cat "$t/e"; rm -rf "$t"',
            "sh", g.url, g.ua, running ? "socks5h://127.0.0.1:" + port : ""];
        for (const l of (g.headers || "").split("\n")) if (l.includes(":")) args.push("-H", l.trim());
        fetchProc.command = args;
        fetchProc.running = true;
    }
    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@NYASH@@");
                const rc = parseInt((parts[2] || "").trim().split("\n")[0]);
                const id = v.busyGroup;
                if (rc === 0 && parts.length >= 3) {
                    // заголовков может быть несколько блоков (переадресации) — берём последний
                    // there may be several header blocks (redirects): take the last one
                    const blocks = parts[0].split(/\r?\n\r?\n/).filter(b => b.trim());
                    const h = VP.parseHeaders(blocks[blocks.length - 1] || "");
                    const nodes = VP.parseSubscription(parts[1]);
                    const g = v.groups.find(x => x.id === id);
                    const title = VP.profileTitle(h);
                    v.editGroup(id, { nodes: nodes.length ? nodes : (g?.nodes ?? []), updated: Date.now(),
                                      info: VP.parseUserinfo(h["subscription-userinfo"]),
                                      name: (g && g.name && g.name !== L.t("подписка")) ? g.name : (title || g?.name) });
                    // ответ сохраняем как есть — в нём видно, что именно прислал сервер
                    // the response is saved as is: it shows exactly what the server sent
                    lastSub.setText(parts[1]);
                    const kind = VP.sniff(parts[1]);
                    v.status = nodes.length ? ""
                        : kind === "happ-crypt" ? L.t("сервер прислал зашифрованные ссылки Happ (happ://crypt) — их открывает только Happ. Попробуй другой User-Agent, например v2rayNG/1.9.0 или clash-verge")
                        : kind === "html" ? L.t("вместо подписки пришла веб-страница — проверь ссылку или User-Agent")
                        : kind === "empty" ? L.t("сервер прислал пустой ответ — возможно, не нравится User-Agent или заголовки")
                        : L.t("формат подписки не распознан; ответ сервера — в ~/.config/nyashell-vpn/last-sub.txt");
                } else {
                    const err = (parts[2] || "").split("\n").slice(1).join(" ").trim() || "curl " + rc;
                    v.log("[subscription] " + err);
                    // самые частые случаи — понятными словами
                    // the most common cases, in plain words
                    v.status = /\(35\)|\(56\)|reset by peer|Recv failure/i.test(err)
                        ? L.t("сервер подписки сбросил соединение — похоже, адрес блокируют. Включи VPN на любом рабочем сервере и обнови ещё раз (подписка скачается через VPN)")
                        : /\(6\)|resolve/i.test(err) ? L.t("не удалось найти адрес подписки (DNS)")
                        : /\(28\)|timed out/i.test(err) ? L.t("сервер подписки не ответил вовремя")
                        : L.t("не удалось обновить подписку: ") + err;
                }
                v.busyGroup = "";
                if (v.queue.length) { const n = v.queue[0]; v.queue = v.queue.slice(1); v.update(n); }
            }
        }
    }
    // автообновление: раз в 30 мин смотрим, у каких подписок вышел их интервал
    // auto-update: every 30 min check which subscriptions have passed their interval
    Timer {
        id: autoUpdate
        interval: 30 * 60 * 1000; repeat: true; triggeredOnStart: true
        onTriggered: {
            for (const g of v.groups)
                if (g.type === "sub" && Date.now() - (g.updated || 0) > (g.interval || 12) * 3600 * 1000) v.update(g.id);
        }
    }

    // ─── подключение ───
    // ─── connecting ───
    function select(groupId: string, i: int): void {
        selGroup = groupId; selNode = i; save();
        if (running || wanted) reconnect();
    }
    function connect(): void { if (!node) { status = L.t("выбери сервер"); return; } wanted = true; save(); reconnect(); }
    // аккуратная остановка: сначала просим sing-box выйти самому (SIGINT) — тогда он снимает маршруты и правила TUN.
    // если убить его сразу, правила остаются, и трафик продолжает уходить в несуществующий туннель
    // a gentle stop: first ask sing-box to exit by itself (SIGINT), so it removes its routes and TUN rules.
    // if it's killed straight away the rules stay and traffic keeps going into a tunnel that no longer exists
    function disconnect(): void { wanted = false; save(); stopCore(); up = 0; down = 0; }
    function stopCore(): void {
        Quickshell.execDetached(["sh", "-c", 'pkill -INT -f "sing-box run -c $1" ; pkill -INT -f "xray run -c $2"; true',
                                 "sh", dir + "/sing-box.json", dir + "/xray.json"]);
        hardStop.restart();
    }
    Timer { id: hardStop; interval: 1500; onTriggered: { box.running = false; xray.running = false; } }
    function toggle(): void { running ? disconnect() : connect(); }
    function setTun(on: bool): void { tun = on; save(); if (running) reconnect(); }
    function setAuto(on: bool): void { autoConnect = on; save(); }

    FileView { id: cfgFile; path: v.dir + "/sing-box.json"; printErrors: false }
    FileView { id: lastSub; path: v.dir + "/last-sub.txt"; printErrors: false }
    FileView { id: xrayFile; path: v.dir + "/xray.json"; printErrors: false }
    function reconnect(): void {
        if (!node) return;
        stopCore();
        cfgFile.setText(JSON.stringify(VP.buildConfig(node, { tun: tun, port: port, xrayPort: 10808, rules: rules, o: opts }), null, 1));
        if (node.needsXray) xrayFile.setText(JSON.stringify(VP.buildXrayConfig(node, 10808, v.opts.logLevel), null, 1));
        startLater.restart();
    }
    Timer { id: startLater; interval: 1700; onTriggered: { hardStop.stop(); box.running = false; xray.running = false; v.status = L.t("подключаюсь…"); checkProc.running = true; } }
    // сначала проверка конфига — ошибки sing-box показываем в панели, а не молча
    // check the config first: sing-box errors are shown in the panel rather than silently
    Process {
        id: checkProc
        command: ["sing-box", "check", "-c", v.dir + "/sing-box.json"]
        stderr: StdioCollector { id: checkErr }
        onExited: (code) => {
            if (code !== 0) { v.status = "sing-box: " + checkErr.text.trim().split("\n").pop(); return; }
            if (v.node?.needsXray) xray.running = true;
            box.running = true;
        }
    }
    Process {
        id: box
        // ядро — отдельный процесс; чуть пониже приоритет, чтобы под нагрузкой оно не отбирало процессор у ввода и отрисовки
        // the core is a separate process; slightly lower priority so under load it doesn't take the CPU from input and drawing
        command: ["nice", "-n", "5", "sing-box", "run", "-c", v.dir + "/sing-box.json"]
        stderr: SplitParser { onRead: (l) => v.log(l) }
        onRunningChanged: {
            if (running) { v.status = ""; v.startedAt = Date.now(); traffic.running = true; v.livePing = 0; firstTest.restart(); }
            else { traffic.running = false; v.up = 0; v.down = 0; }
        }
    }
    Process { id: xray; command: ["nice", "-n", "5", "xray", "run", "-c", v.dir + "/xray.json"]
              stdout: SplitParser { onRead: (l) => v.log("[xray] " + l) } stderr: SplitParser { onRead: (l) => v.log("[xray] " + l) } }

    // ─── журнал ядра ───
    // Раньше каждая строка пересоздавала массив logs, а с ним и весь список в панели. Когда браузер открывает
    // сотни соединений, ядро пишет сотни строк в секунду — и весь шелл (он однопоточный: QML, отрисовка и ввод
    // живут в одном потоке) захлёбывался. Теперь строки копятся в простом буфере без сигналов, а наружу
    // (logs) уходят не чаще 3 раз в секунду и только когда журнал открыт
    // ─── core log ───
    // Every line used to recreate the logs array and with it the whole list in the panel. When a browser opens
    // hundreds of connections the core writes hundreds of lines a second, and the whole shell (it's single-threaded: QML, drawing and input
    // live in one thread) choked. Now lines pile up in a plain buffer with no signals, and go out
    // (logs) at most 3 times a second and only while the log is open
    property var logs: []
    property var buf: []
    property int dropped: 0
    property real startedAt: 0
    property string lastErr: ""
    function log(l: string): void {
        if (!l.trim()) return;
        const b = v.buf;
        const keep = ["trace", "debug", "info"].includes(opts.logLevel) ? 2000 : 300;
        b.push(l);
        if (b.length > keep * 2) b.splice(0, b.length - keep);
        // ошибки при запуске (первые 8 с) — в строку статуса; дальше ERROR — это обычные оборванные соединения
        // errors at start (the first 8 s) go to the status line; after that ERROR is just ordinary dropped connections
        if (/FATAL/.test(l) || (/ERROR/.test(l) && Date.now() - v.startedAt < 8000)) v.lastErr = l;
        if (!flush.running) flush.start();
    }
    Timer {
        id: flush
        interval: 330
        onTriggered: {
            if (v.lastErr) { v.status = v.lastErr.replace(/\x1b\[[0-9;]*m/g, "").replace(/^.*?(FATAL|ERROR)/, "$1"); v.lastErr = ""; }
            if (!v.showLogs) return;            // журнал закрыт — список не трогаем вообще / the log is closed: don't touch the list at all
            const keep = ["trace", "debug", "info"].includes(v.opts.logLevel) ? 2000 : 300;
            v.logs = v.buf.slice(-Math.min(keep, 400)).map(x => x.replace(/\x1b\[[0-9;]*m/g, ""));
        }
    }
    onShowLogsChanged: if (showLogs) flush.restart()
    // системный прокси: программы, которые его слушают (GNOME/GTK, KDE, многие браузеры), идут через :port
    // system proxy: apps that listen to it (GNOME/GTK, KDE, many browsers) go through :port
    property bool sysProxy: false
    function setSysProxy(on: bool): void {
        sysProxy = on; save();
        Quickshell.execDetached(["sh", "-c",
            'on="$1"; p="$2"; ' +
            'if [ "$on" = 1 ]; then gsettings set org.gnome.system.proxy mode manual; ' +
            '  for t in http https socks; do gsettings set org.gnome.system.proxy.$t host 127.0.0.1; gsettings set org.gnome.system.proxy.$t port "$p"; done; ' +
            'else gsettings set org.gnome.system.proxy mode none; fi 2>/dev/null; ' +
            'if command -v kwriteconfig6 >/dev/null; then kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType "$([ "$on" = 1 ] && echo 1 || echo 0)"; ' +
            '  for k in httpProxy httpsProxy socksProxy; do kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key $k "http://127.0.0.1 $p"; done; fi; true',
            "sh", on ? "1" : "0", String(port)]);
    }
    // скорость — из API sing-box: строка JSON раз в секунду
    // speed from the sing-box API: a JSON line once a second
    Process {
        id: traffic
        command: ["sh", "-c", "sleep 1; exec curl -sN http://127.0.0.1:9090/traffic"]
        stdout: SplitParser { onRead: (l) => { try { const t = JSON.parse(l); v.up = t.up; v.down = t.down; } catch (e) {} } }
    }

    // ─── пинг ───
    // ─── ping ───
    property string pingGroup: ""          // какую группу сейчас проверяем / which group is being checked right now
    readonly property string testUrl: "https%3A%2F%2Fwww.google.com%2Fgenerate_204"
    FileView { id: testFile; path: v.dir + "/ping.json"; printErrors: false }
    function ping(id: string): void {
        const g = groups.find(x => x.id === id); if (!g || pingProc.running) return;
        pingGroup = id;
        testFile.setText(JSON.stringify(VP.buildTestConfig(g.nodes, 9091)));
        // узлы через Xray: свой временный конфиг на отдельном порту — пинг тоже настоящий
        // nodes via Xray: their own temporary config on a separate port, so the ping is real too
        const tags = g.nodes.map((n, i) => {
            if (n.proto === "chain") return "";
            if (!n.needsXray) return "n" + i;
            if (!hasXray) return "tcp|" + i + "|" + n.server + "|" + n.port;
            const port = 20800 + i, file = dir + "/ping-xray-" + i + ".json";
            Quickshell.execDetached(["sh", "-c", 'printf "%s" "$2" > "$1"', "sh", file, JSON.stringify(VP.buildXrayConfig(n, port))]);
            return "xray|" + i + "|" + file + "|" + port;
        }).filter(t => t);
        pingProc.command = ["sh", Quickshell.shellPath("vpn-ping.sh"), dir + "/ping.json", testUrl, "https://www.google.com/generate_204"].concat(tags);
        pingLater.restart();
    }
    Timer { id: pingLater; interval: 300; onTriggered: { pingProc.running = true; pingGuard.restart(); } }
    // по 8 серверов разом, на каждый не больше 5 с — плюс запас на запуск временного sing-box
    // 8 servers at a time, at most 5 s each, plus some headroom for starting the temporary sing-box
    Timer {
        id: pingGuard
        interval: (Math.ceil((v.groups.find(g => g.id === v.pingGroup)?.nodes.length ?? 8) / 8) * 5 + 6) * 1000
        onTriggered: if (pingProc.running) pingProc.running = false
    }
    property bool hasXray: false
    Process { running: true; command: ["sh", "-c", "command -v xray"]; onExited: (code) => v.hasXray = code === 0 }
    Process {
        id: pingProc
        stdout: SplitParser {
            onRead: (l) => {
                const m = l.trim().match(/^(\d+)\s+(-?\d+)$/); if (!m) return;
                const id = v.pingGroup, i = parseInt(m[1]), ms = parseInt(m[2]);
                v.groups = v.groups.map(g => g.id !== id ? g : Object.assign({}, g, {
                    nodes: g.nodes.map((n, k) => k === i ? Object.assign({}, n, { ping: ms }) : n) }));
            }
        }
        onExited: { v.pingGroup = ""; v.save(); }
    }
    // проверка текущего подключения — как «подключено, нажмите для проверки» в Exclave
    // check of the current connection, like "connected, tap to check" in Exclave
    property int livePing: 0
    function testCurrent(): void { if (running && !curProc.running) curProc.running = true; }
    Timer { id: firstTest; interval: 1500; onTriggered: v.testCurrent() }
    Process {
        id: curProc
        command: ["sh", "-c", 'curl -s -m 5 "http://127.0.0.1:9090/proxies/proxy/delay?timeout=4500&url=' + v.testUrl + '" | sed -n "s/.*\\"delay\\":\\([0-9]*\\).*/\\1/p"']
        stdout: StdioCollector { onStreamFinished: v.livePing = parseInt(text.trim()) || -1 }
    }

    // ─── сортировка ───
    // ─── sorting ───
    function setSort(id: string, mode: string): void { editGroup(id, { sort: mode }); }
    // порядок показа: индексы узлов (выбор всегда по настоящему индексу)
    // display order: node indices (selection always uses the real index)
    function order(g) {
        const idx = g.nodes.map((_, i) => i);
        if (g.sort === "ping") idx.sort((a, b) => {
            const pa = g.nodes[a].ping, pb = g.nodes[b].ping;
            const va = pa === undefined ? 1e9 - 1 : pa < 0 ? 1e9 : pa, vb = pb === undefined ? 1e9 - 1 : pb < 0 ? 1e9 : pb;
            return va - vb;
        });
        else if (g.sort === "name") idx.sort((a, b) => g.nodes[a].name.localeCompare(g.nodes[b].name));
        return idx;
    }

    // ─── цепочки ───
    // ─── chains ───
    property var draft: []                 // собираемая цепочка: [{group, index, name}] / the chain being assembled: [{group, index, name}]
    function addHop(groupId: string, i: int): void {
        const g = groups.find(x => x.id === groupId), n = g?.nodes[i];
        if (!n || n.needsXray || n.proto === "chain") { status = L.t("в цепочку можно только узлы sing-box"); return; }
        draft = draft.concat([{ group: groupId, index: i, name: n.name, outbound: n.outbound }]);
    }
    function clearDraft(): void { draft = []; }
    function saveChain(name: string): void {
        if (draft.length < 2) { status = L.t("в цепочке нужно минимум два узла"); return; }
        let g = groups.find(x => x.id === "chains");
        const node = { name: name || draft.map(h => h.name).join(" → "), proto: "chain", server: "", port: 0,
                       hops: draft.map(h => h.outbound), needsXray: false };
        if (!g) groups = groups.concat([{ id: "chains", name: L.t("Цепочки"), type: "manual", nodes: [node], updated: Date.now(), info: {} }]);
        else editGroup("chains", { nodes: g.nodes.concat([node]) });
        draft = []; save();
    }
    // ─── серверы внутри групп (как в NekoBox: добавить в любую свою группу, изменить, клонировать, перенести) ───
    // ─── servers inside groups (as in NekoBox: add to any of your groups, edit, clone, move) ───
    // в подписку руками не добавляем: при обновлении её список серверов целиком приходит заново
    // we don't add by hand to a subscription: on update its server list arrives anew as a whole
    readonly property var manualGroups: groups.filter(g => g.type === "manual")
    // куда класть: id своей группы или новая группа с именем newName; возвращает id
    // where to put: an id of your group or a new group named newName; returns the id
    function addNodes(groupId: string, newName: string, nodes): string {
        if (!nodes.length) return "";
        const g = groups.find(x => x.id === groupId && x.type === "manual");
        if (g) { editGroup(g.id, { nodes: g.nodes.concat(nodes), updated: Date.now() }); return g.id; }
        const id = uid();
        groups = groups.concat([{ id: id, name: newName || L.t("группа"), type: "manual", nodes: nodes, updated: Date.now(), info: {} }]);
        save();
        return id;
    }
    // ссылки текстом (несколько, base64-подписка, JSON, Clash — что угодно из того, что понимает подписка)
    // links as text (several, a base64 subscription, JSON, Clash: anything a subscription understands)
    function importLinks(groupId: string, newName: string, text: string): string {
        const nodes = VP.parseSubscription(text);
        if (!nodes.length) { status = L.t("ссылок не нашлось"); return ""; }
        const id = addNodes(groupId, newName, nodes);
        status = L.t("добавлено серверов: ") + nodes.length;
        return id;
    }
    // заменить узел (ручной редактор) / replace a node (the manual editor)
    function setNode(groupId: string, i: int, n): void {
        const g = groups.find(x => x.id === groupId); if (!g || !n) return;
        editGroup(groupId, { nodes: g.nodes.map((x, k) => k === i ? n : x) });
        if (selGroup === groupId && selNode === i && running) reconnect();
    }
    function cloneNode(groupId: string, i: int): void {
        const g = groups.find(x => x.id === groupId), n = g?.nodes[i]; if (!n) return;
        const c = Object.assign({}, n, { name: n.name + L.t(" (копия)") }); delete c.ping;
        editGroup(groupId, { nodes: g.nodes.slice(0, i + 1).concat([c], g.nodes.slice(i + 1)) });
        if (selGroup === groupId && selNode > i) selNode++;
    }
    // копии в другую группу (move — ещё и убрать отсюда); idx — один номер или список (мультивыделение)
    // copies into another group (move also removes them from here); idx is one number or a list (multi-selection)
    function copyNode(fromId: string, idx, toId: string, newName: string, move: bool): void {
        const g = groups.find(x => x.id === fromId); if (!g) return;
        const list = (Array.isArray(idx) ? idx : [idx]).filter(i => g.nodes[i]).sort((a, b) => a - b);
        if (!list.length) return;
        const carried = selGroup === fromId && list.includes(selNode) ? list.indexOf(selNode) : -1;
        const to = addNodes(toId, newName, list.map(i => { const c = Object.assign({}, g.nodes[i]); delete c.ping; return c; }));
        if (!move || g.type !== "manual") return;
        removeNodes(fromId, list, true);
        // выбранный сервер переехал — выбор едет за ним, соединение не рвём
        // the selected server moved: the selection follows it, the connection stays
        if (carried >= 0) { const tg = groups.find(x => x.id === to); selGroup = to; selNode = tg.nodes.length - list.length + carried; save(); }
    }
    function removeNode(groupId: string, i: int, keepConn: bool): void { removeNodes(groupId, [i], keepConn); }
    // keepConn — выбранный узел переносим, соединение не рвём / keepConn: the selected node is being moved, the connection stays
    function removeNodes(groupId: string, list, keepConn: bool): void {
        const g = groups.find(x => x.id === groupId); if (!g) return;
        editGroup(groupId, { nodes: g.nodes.filter((_, k) => !list.includes(k)) });
        if (selGroup !== groupId || selNode < 0) return;
        // номера после удалённых сдвигаются — выбранный сервер должен остаться тем же
        // numbers after the removed ones shift, the selected server must stay the same
        if (list.includes(selNode)) { if (!keepConn) { selNode = -1; if (running) disconnect(); } }
        else selNode -= list.filter(k => k < selNode).length;
        save();
    }
    // убрать повторы и мёртвые (по последней проверке пинга) / remove repeats and dead ones (by the last ping check)
    function cleanGroup(groupId: string, dead: bool): void {
        const g = groups.find(x => x.id === groupId); if (!g) return;
        const seen = {}, keep = [];
        g.nodes.forEach((n, k) => {
            const key = VP.nodeKey(n);
            const drop = dead ? (n.ping !== undefined && n.ping < 0) : !!seen[key];
            seen[key] = true;
            if (!drop || (selGroup === groupId && selNode === k)) keep.push(k);   // выбранный не трогаем / the selected one is kept
        });
        const removed = g.nodes.length - keep.length;
        if (selGroup === groupId && selNode >= 0) selNode = keep.indexOf(selNode);
        editGroup(groupId, { nodes: keep.map(k => g.nodes[k]) });
        status = L.t("убрано серверов: ") + removed;
    }

    // ─── маршруты и настройки (изменения сразу применяются, если подключено) ───
    // ─── routes and settings (changes apply immediately if connected) ───
    function applyLater(): void { save(); if (running) reapply.restart(); }
    Timer { id: reapply; interval: 700; onTriggered: v.reconnect() }
    function addRule(r): void { rules = rules.concat([Object.assign({ id: uid(), on: true, outbound: "direct" }, r)]); applyLater(); }
    function setRule(id: string, patch): void { rules = rules.map(r => r.id === id ? Object.assign({}, r, patch) : r); applyLater(); }
    function removeRule(id: string): void { rules = rules.filter(r => r.id !== id); applyLater(); }
    function moveRule(id: string, d: int): void {
        const i = rules.findIndex(r => r.id === id), j = i + d;
        if (i < 0 || j < 0 || j >= rules.length) return;
        const a = rules.slice(); [a[i], a[j]] = [a[j], a[i]]; rules = a; applyLater();
    }
    function setOpt(k: string, val): void { const o = Object.assign({}, opts); o[k] = val; opts = o; applyLater(); }
    function setPort(p: int): void { port = p; applyLater(); }

    function human(b: real): string {
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GiB";
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MiB";
        if (b >= 1024) return (b / 1024).toFixed(0) + " KiB";
        return Math.round(b) + " B";
    }
}
