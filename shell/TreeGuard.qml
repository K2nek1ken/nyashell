import Quickshell
import Quickshell.Io
import QtQuick

// «демон» раскладок:
//  1) в режиме дерева на странице не больше 4 окон: лишнее уезжает на следующую страницу,
//     а когда место освобождается — окна, которые мы вытеснили, возвращаются обратно;
//  2) режим каждой страницы (лента/дерево) запоминается и восстанавливается при входе.
// layout "daemon":
// 1) in tree mode a page holds at most 4 windows: the extra one moves to the next page,
//    and when space frees up, the windows we pushed out come back;
// 2) each page's mode (scroller/tree) is remembered and restored at login.
Scope {
    id: g
    readonly property int limit: ShellState.settings.treeLimit ?? 4
    readonly property int tagCount: ShellState.pageCount
    readonly property string stateFile: Quickshell.env("HOME") + "/.config/quickshell/nyashell/layouts.json"
    // минимальный размер окна в «деревьях»: если окно на странице становится меньше —
    // самое новое уезжает на следующую страницу (так не бывает слайсов и лепёшек)
    // minimum window size in "trees": if a window on the page becomes smaller,
    // the newest one moves to the next page (so there are no slivers or pancakes)
    readonly property int minW: ShellState.settings.minW ?? 560
    readonly property int minH: ShellState.settings.minH ?? 360
    readonly property var symToName: ({
        "S": "scroller", "DW": "dwindle", "F": "fair", "VF": "vertical_fair",
        "T": "tile", "G": "grid", "RT": "right_tile", "CT": "center_tile", "VT": "vertical_tile"
    })
    // какие режимы вообще разрешены; спираль убрана — вместо неё ровная сетка
    // мастер+стек пока выключен (потом — в настройках)
    // which modes are allowed at all; the spiral is gone, an even grid replaces it
    // master+stack is off for now (later in the settings)
    readonly property var allowed: ShellState.settings.masterStack ? ["scroller", "fair", "tile"] : ["scroller", "fair"]
    function sanitize(name) { return name === "dwindle" ? "fair" : allowed.includes(name) ? name : name === "tile" ? "fair" : ""; }

    // для каких раскладок действуют лимит и минимальный размер (ленты бесконечные — там не нужно)
    // the layouts the limit and minimum size apply to (scrollers are endless, not needed there)
    readonly property var treeSyms: ["DW", "F", "VF", "T", "G", "RT", "CT", "VT"]

    property var clients: []
    property var tags: ({})        // монитор -> массив тегов из mmsg / monitor -> array of tags from mmsg
    property var saved: ({})       // монитор -> { "5": "dwindle", ... } / monitor -> { "5": "dwindle", ... }
    property bool restored: false
    property bool busy: false      // пока ждём, что mango применит наш ход / while waiting for mango to apply our move
    property var autoHalf: ({})     // окна ленты, которым мы сами поставили 1/2 / scroller windows we set to 1/2 ourselves
    property var fsHome: ({})       // окно на весь экран -> страница, откуда мы его увезли / full-screen window -> the page we moved it from

    function mmsg(args): void {
        Quickshell.execDetached(["mmsg"].concat(args));
    }

    // ─── сохранённые режимы ───
    // ─── saved modes ───
    FileView {
        id: layoutFile
        path: g.stateFile
        blockLoading: true
        printErrors: false
        onLoaded: { try { g.saved = JSON.parse(text()); } catch (e) { g.saved = {}; } }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { try { g.saved = JSON.parse(text()); } catch (e) { g.saved = {}; } }
}

    // ─── потоки событий из mango (каждое событие — одна строка JSON) ───
    // ─── event streams from mango (each event is one JSON line) ───
    component Stream: Process {
        id: proc
        property string what: ""
        property string buf: ""
        signal message(var obj)
        command: ["mmsg", "watch", what]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                proc.buf += line;
                try { const o = JSON.parse(proc.buf); proc.buf = ""; proc.message(o); }
                catch (e) { if (proc.buf.length > 500000) proc.buf = ""; }
            }
        }
        // если mmsg отвалился — переподключаемся
        // if mmsg dropped off, reconnect
        onExited: restart.restart()
        property Timer restart: Timer { interval: 1000; onTriggered: proc.running = true }
    }

    Stream {
        what: "all-tags"
        onMessage: (o) => g.onTags(o)
    }
    Stream {
        what: "all-clients"
        onMessage: (o) => { g.clients = o.clients || []; ShellState.mangoClients = g.clients; g.check(); g.liftToasts(); }
    }

    // первоначальное состояние (watch может молчать, пока ничего не изменилось)
    // initial state (watch may stay silent until something changes)
    Process {
        command: ["mmsg", "get", "all-tags"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { g.onTags(JSON.parse(text)); } catch (e) {} } }
    }
    Process {
        command: ["mmsg", "get", "all-clients"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { g.clients = JSON.parse(text).clients || []; g.check(); } catch (e) {} } }
    }

    property var lastCounts: ({})       // монитор -> {страница: окон} с прошлого раза / monitor -> {page: windows} from last time
    property string emptyMon: ""
    property int emptyTag: 0
    Timer {
        id: emptyLater
        interval: 400
        onTriggered: {
            const tags = g.tags[g.emptyMon] ?? [], act = tags.find(x => x.is_active);
            if (!act || act.index !== g.emptyTag || act.client_count > 0) return;     // уже ушли или окно вернулось / already left, or the window came back
            for (let k = 1; k < tagCount; k++) {
                const idx = ((act.index - 1 - k + tagCount) % tagCount) + 1, tg = tags.find(x => x.index === idx);
                if (tg && tg.client_count > 0) { Quickshell.execDetached(["mmsg", "dispatch", "view," + idx]); break; }
            }
        }
    }
    function onTags(o): void {
        const t = {};
        for (const m of (o.all_tags || [])) t[m.monitor] = m.tags;
        // страница опустела у нас на глазах — через 0.4 с (если так и осталось) уходим на занятую.
        // пауза нужна: при переносе окна на другую страницу mango на миг показывает старую пустой
        // the page emptied before our eyes: after 0.4 s (if it's still empty) go to an occupied one.
        // the pause is needed: when a window moves to another page, mango briefly shows the old one as empty
        for (const mon in t) {
            const act0 = t[mon].find(x => x.is_active);
            const prev = lastCounts[mon] ?? {};
            if (act0 && act0.client_count === 0 && (prev[act0.index] ?? 0) > 0 && restoreDone) {
                g.emptyMon = mon; g.emptyTag = act0.index; emptyLater.restart();
            }
            const c = {};
            for (const x of t[mon]) c[x.index] = x.client_count;
            const lc = Object.assign({}, lastCounts); lc[mon] = c; lastCounts = lc;
        }
        tags = t;
        ShellState.mangoTags = t;
        // вернулись на страницу, где «припарковано» полноэкранное окно — снова на весь экран
        // back on the page where a full-screen window is "parked": full screen again
        if (ShellState.fsParked.length) {
            const back = [];
            for (const id of ShellState.fsParked) {
                const c = clients.find(x => x.id === id);
                if (!c) continue;                                         // окно закрыли / the window was closed
                const onActive = Object.keys(t).some(mon => (t[mon].find(x => x.is_active)?.index) === (c.tags || [])[0] && c.monitor === mon);
                if (onActive && !c.is_fullscreen) Quickshell.execDetached(["mmsg", "dispatch", "togglefullscreen", "client," + id]);
                else if (!c.is_fullscreen) back.push(id);
            }
            ShellState.fsParked = back;
        }
        if (!restored) { restored = true; restoreLater.restart(); }
        else remember();
        check();
    }

    // пока восстанавливаем — ничего не запоминаем, иначе стартовые режимы затрут сохранённые
    // while restoring, remember nothing, otherwise the startup modes would overwrite the saved ones
    property bool restoreDone: false
    Timer { id: restoreLater; interval: 1500; onTriggered: { g.restore(); settle.restart(); } }
    Timer { id: settle; interval: 2500; onTriggered: { g.restoreDone = true; g.remember(); } }

    // ─── запомнить режимы ───
    // ─── remember the modes ───
    function remember(): void {
        if (!restoreDone) return;
        const s = JSON.parse(JSON.stringify(saved));
        let changed = false;
        for (const mon in tags) {
            s[mon] = s[mon] || {};
            for (const t of tags[mon]) {
                const name = sanitize(symToName[t.layout]);
                if (name && s[mon][t.index] !== name) { s[mon][t.index] = name; changed = true; }
            }
        }
        if (changed) { saved = s; layoutFile.setText(JSON.stringify(s)); }
    }

    // ─── восстановить режимы: пробегаем по страницам, где режим отличается, и возвращаемся ───
    // ─── restore the modes: walk through the pages whose mode differs, and come back ───
    function restore(): void {
        for (const mon in tags) {
            const want = saved[mon];
            if (!want) continue;
            const active = (tags[mon].find(t => t.is_active) || {}).index || 1;
            let cmds = [];
            for (const t of tags[mon]) {
                // старую «спираль» из памяти превращаем в ровную сетку
                // an old remembered "spiral" becomes an even grid
                const name = sanitize(want[t.index]) || (t.layout === "DW" || t.layout === "T" ? "fair" : "");
                if (name && symToName[t.layout] !== name)
                    // «;», а не «&&»: не рассчитываем на код возврата mmsg
                    // ";" rather than "&&": we don't rely on mmsg's exit code
                    cmds.push("mmsg dispatch view," + t.index + "; sleep 0.08; mmsg dispatch setlayout," + name);
            }
            if (cmds.length === 0) continue;
            cmds.push("mmsg dispatch view," + active);
            Quickshell.execDetached(["sh", "-c", "mmsg dispatch focusmon," + mon + "; " + cmds.join("; sleep 0.05; ")]);
        }
    }

    function tiledOn(mon, idx) {
        return clients.filter(c => c.monitor === mon && (c.tags || []).includes(idx)
            && !c.is_floating && !c.is_minimized && !c.is_fullscreen
            && !c.is_scratchpad && !c.is_namedscratchpad && !c.is_global);
    }

    function layoutOf(mon, idx) {
        const t = (tags[mon] || []).find(x => x.index === idx);
        return t ? t.layout : "";
    }

    // ─── лента: два окна — по 1/2, три и больше — снова по 1/3 ───
    // трогаем только ширины, которые выставили сами (ручные 2/3 и т. п. не ломаем)
    // ─── scroller: two windows at 1/2 each, three or more back to 1/3 ───
    // only widths we set ourselves are touched (manual 2/3 and the like aren't broken)
    function tuneScroller(): bool {
        for (const mon in tags) {
            const at = (tags[mon] || []).find(t => t.is_active && t.layout === "S");
            if (!at) continue;
            const here = tiledOn(mon, at.index);
            const near = (a, b) => Math.abs(a - b) < 0.02;
            if (here.length === 2) {
                const c = here.find(c => near(c.scroller_proportion ?? 0, 0.333));
                if (c) {
                    const h = Object.assign({}, autoHalf); h[c.id] = true; autoHalf = h;
                    act("set_proportion,0.5 client," + c.id, "");
                    return true;
                }
            } else if (here.length >= 3) {
                const c = here.find(c => autoHalf[c.id] && near(c.scroller_proportion ?? 0, 0.5));
                if (c) {
                    const h = Object.assign({}, autoHalf); delete h[c.id]; autoHalf = h;
                    act("set_proportion,0.333 client," + c.id, "");
                    return true;
                }
            }
        }
        return false;
    }

    // ─── полноэкранное окно — на свою отдельную страницу, после — обратно ───
    // ─── a full-screen window goes to its own page, and back afterwards ───
    function fullscreenPages(): bool {
        for (const c of clients) {
            if (!c.is_fullscreen || fsHome[c.id] !== undefined) continue;
            const idx = (c.tags || [])[0];
            const others = clients.filter(x => x.id !== c.id && x.monitor === c.monitor
                && (x.tags || []).includes(idx) && !x.is_minimized && !x.is_scratchpad);
            if (others.length === 0) continue;                 // и так одно на странице / already alone on the page
            const free = (tags[c.monitor] || []).find(t => t.client_count === 0 && t.index !== idx);
            if (!free) continue;                               // свободных страниц нет — оставляем / no free pages: leave it
            const h = Object.assign({}, fsHome); h[c.id] = idx; fsHome = h;
            act("tag," + free.index + " client," + c.id, "view," + free.index);
            return true;
        }
        for (const id in fsHome) {
            const c = clients.find(x => String(x.id) === id);
            const h = Object.assign({}, fsHome);
            if (!c) { delete h[id]; fsHome = h; continue; }    // окно закрыли / the window was closed
            // вышло из полноэкранного только на время смены страницы (мы сами его «припарковали») —
            // остаётся на своей странице: вернёшься — снова развернётся на весь экран
            // it left full screen only for the page switch (we "parked" it ourselves),
            // so it stays on its page: come back and it goes full screen again
            if (!c.is_fullscreen && ShellState.fsParked.includes(c.id)) continue;
            if (!c.is_fullscreen) {                            // вышло из полноэкранного — домой / it left full screen: back home
                const home = h[id];
                delete h[id]; fsHome = h;
                act("tag," + home + " client," + c.id, "view," + home);
                return true;
            }
        }
        return false;
    }

    // ─── главная проверка ───
    // ─── main check ───
    function check(): void {
        if (busy) return;
        // страницы — изолированные пространства: окна (и полноэкранные игры в том числе) сами никуда не переезжают.
        // прежний перенос полноэкранного окна на свободную страницу убран — он и утаскивал игру со Steam на 9-ю
        // половинки для двух окон в ленте теперь делает сам mango (nya_scroller_half)
        // pages are isolated spaces: windows (full-screen games included) don't move anywhere by themselves.
        // the old moving of a full-screen window to a free page is gone: it was what dragged a Steam game to page 9
        // halves for two windows in the scroller are now done by mango itself (nya_scroller_half)
        for (const mon in tags) {
            for (let idx = 1; idx <= tagCount; idx++) {
                if (!treeSyms.includes(layoutOf(mon, idx))) continue;
                const here = tiledOn(mon, idx);
                const tooSmall = here.length > 1 && here.some(c => c.width > 0 && (c.width < minW || c.height < minH));

                // переполнение (больше 4 или кто-то стал слишком мелким):
                // самое новое окно — на ближайшую страницу, где есть место
                // overflow (more than 4, or someone got too small):
                // the newest window goes to the nearest page with room
                if (here.length > limit || tooSmall) {
                    const victim = here.reduce((a, b) => (a.id > b.id ? a : b));
                    // ищем место дальше по страницам, а с последней — по кругу с первой.
                    // Если места нет нигде — окно сворачивается (иначе на последней странице
                    // окна сжимались бесконечно)
                    // look for room further along the pages, and from the last one wrap around to the first.
                    // If there's no room anywhere, the window is minimised (otherwise on the last page
                    // windows shrank endlessly)
                    const order = [];
                    for (let t = idx + 1; t <= tagCount; t++) order.push(t);
                    for (let t = 1; t < idx; t++) order.push(t);
                    if (!order.some(t => tiledOn(mon, t).length < limit)) {
                        act("minimized client," + victim.id, "");
                        Quickshell.execDetached(["notify-send", "-a", "nyashell", L.t("Все страницы заняты"),
                                                 L.t("новое окно свёрнуто — оно на панели")]);
                        return;
                    }
                    for (const t of order) {
                        if (tiledOn(mon, t).length < limit) {
                            const srcName = symToName[layoutOf(mon, idx)] || "fair";
                            const emptyDst = tiledOn(mon, t).length === 0;
                            act("tag," + t + " client," + victim.id,
                                "view," + t + (emptyDst && layoutOf(mon, t) !== layoutOf(mon, idx)
                                               ? "; sleep 0.05; mmsg dispatch setlayout," + srcName : ""));
                            return;
                        }
                    }
                }

                // окна назад сами больше не возвращаются: освободилось место — это просто свободное место.
                // (раньше возврат ещё и срывал Super+F: полноэкранное окно не считается «местом в сетке»,
                // на его страницу тут же возвращалось вытесненное окно, и mango снимал полноэкранный режим)
                // windows no longer come back by themselves: freed space is just free space.
                // (coming back also broke Super+F: a full-screen window doesn't count as a "grid slot",
                // the pushed-out window immediately returned to its page and mango dropped full screen)
            }
        }
    }

    // один ход за раз, потом пауза, чтобы mango успел прислать новое состояние
    // one move at a time, then a pause so mango can send the new state
    function act(first: string, second: string): void {
        busy = true;
        const parts = first.split(" ");
        let sh = "mmsg dispatch " + parts.join(" ");
        if (second) sh += "; sleep 0.05; mmsg dispatch " + second;
        Quickshell.execDetached(["sh", "-c", sh]);
        cooldown.restart();
    }
    Timer { id: cooldown; interval: 250; onTriggered: { g.busy = false; g.check(); } }

    // всплывающие окна Steam (notificationtoasts_*) Steam сам ставит к нижнему краю экрана — то есть под панель.
    // если такое окно залезло на панель или рамку, поднимаем его в правый нижний угол рабочей области
    // Steam's popup windows (notificationtoasts_*) are placed by Steam at the bottom edge of the screen, i.e. under the bar.
    // if such a window ends up on the bar or the frame, lift it into the bottom-right corner of the work area
    property var lifted: ({})
    function liftToasts(): void {
        const scr = Quickshell.screens[0];
        if (!scr) return;
        const bottom = scr.height - Tokens.barHeight - 8, right = scr.width - Tokens.frame - 8;
        for (const c of clients) {
            if (!/^notificationtoasts/i.test(c.title || "")) continue;
            if (c.y + c.height <= bottom && c.x + c.width <= right) continue;
            const key = c.id + ":" + c.y;
            if (lifted[key]) continue;
            const l = Object.assign({}, lifted); l[key] = true; lifted = l;
            const x = Math.max(0, right - c.width), y = Math.max(0, bottom - c.height);
            Quickshell.execDetached(["mmsg", "dispatch", "movewin," + x + "," + y, "client," + c.id]);
        }
    }
}
