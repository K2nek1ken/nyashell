import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// меню приложений — «ящик» из левого нижнего угла рамки (стыкуется с левым краем и панелью).
// избранное (ПКМ), частые, категории, все, поиск; «=2+2» — калькулятор, «>» — действия шелла
// app menu: a "drawer" from the bottom-left corner of the frame (joins the left edge and the bar).
// favourites (right-click), frequent, categories, all, search; "=2+2" is a calculator, ">" shell actions
PanelWindow {
    id: win
    visible: ShellState.launcherOpen || hh > 0.5
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property real t: Tokens.frame
    readonly property real r: Tokens.frameRadius
    readonly property real bigR: Tokens.rounding.extraLarge
    readonly property real w: 700
    readonly property real fullH: 540
    readonly property real yB: height - Tokens.barHeight
    property real hh: ShellState.launcherOpen ? fullH : 0
    Behavior on hh { Anim { kind: ShellState.launcherOpen ? "spatial" : "emphasized" } }

    property string query: ""
    property string category: "all"
    property var favorites: []
    property var usage: ({})         // id -> сколько раз запускали / id -> how many times it was launched

    // ─── данные ───
    // порядок как в KDE Kickoff, «Недавние» сразу под «Избранным»
    // порядок как в KDE: Интернет, Игры, Утилиты, Офис, Разработка, Графика, Мультимедиа, Система, Прочее.
    // «Система» включает и настройки; всё, что не попало никуда, — в «Прочее»
    // ─── data ───
    // order as in KDE Kickoff, "Recent" right under "Favourites"
    // order as in KDE: Internet, Games, Utilities, Office, Development, Graphics, Multimedia, System, Other.
    // "System" includes settings; anything that didn't land anywhere goes to "Other"
    readonly property var categoryDefs: [
        ["fav", L.t("Избранное"), "star", []], ["recent", L.t("Недавние"), "history", []], ["all", L.t("Все приложения"), "apps", []],
        ["net", L.t("Интернет"), "public", ["Network"]],
        ["game", L.t("Игры"), "sports_esports", ["Game"]],
        ["util", L.t("Утилиты"), "build", ["Utility"]],
        ["office", L.t("Офис"), "description", ["Office"]],
        ["dev", L.t("Разработка"), "code", ["Development"]],
        ["gfx", L.t("Графика"), "palette", ["Graphics"]],
        ["av", L.t("Мультимедиа"), "movie", ["AudioVideo", "Audio", "Video"]],
        ["sys", L.t("Система"), "memory", ["System", "Settings"]],
        ["other", L.t("Прочее"), "apps", null]
    ]
    readonly property var mainCats: ["Network", "Game", "Utility", "Office", "Development", "Graphics", "AudioVideo", "Audio", "Video", "System", "Settings"]
    function inCat(e, def): bool {
        const cats = e.categories || [];
        if (def[3] === null) return !cats.some(c => mainCats.includes(c));     // «Прочее» / "Other"
        return cats.some(c => def[3].includes(c));
    }
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var categories: categoryDefs.filter(c =>
        ["fav", "recent", "all"].includes(c[0]) || apps.some(e => inCat(e, c)))

    // ─── нечёткий поиск ───
    // от лучшего к худшему: начало названия → начало слова → где угодно в названии →
    // в описании/ключевых словах → буквы по порядку с пропусками («dch» → DeltaChat) → с одной-двумя опечатками
    // ─── fuzzy search ───
    // best to worst: start of the name → start of a word → anywhere in the name →
    // in the description/keywords → letters in order with gaps ("dch" → DeltaChat) → with one or two typos
    function editDist(a: string, b: string): int {          // Дамерау–Левенштейн (перестановка соседних букв = 1) / Damerau–Levenshtein (swapping neighbouring letters = 1)
        const d = [];
        for (let i = 0; i <= a.length; i++) { d.push([i]); }
        for (let j = 1; j <= b.length; j++) d[0][j] = j;
        for (let i = 1; i <= a.length; i++)
            for (let j = 1; j <= b.length; j++) {
                const c = a[i - 1] === b[j - 1] ? 0 : 1;
                d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + c);
                if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
            }
        return d[a.length][b.length];
    }
    function score(e, q: string): real {
        const n = e.name.toLowerCase();
        // слова: по пробелам/дефисам и по «горбам» CamelCase (DeltaChat → delta, chat)
        // words: split on spaces/hyphens and CamelCase "humps" (DeltaChat → delta, chat)
        const words = n.split(/[\s\-_.]+/).concat(e.name.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase().split(/[\s\-_.]+/));
        if (n.startsWith(q)) return 0;
        if (words.some(w => w.startsWith(q))) return 1;
        const at = n.indexOf(q);
        if (at >= 0) return 2 + at / 100;                                   // «chat» в «deltachat» / "chat" in "deltachat"
        const extra = [e.genericName, e.comment, (e.keywords || []).join(" "), e.id].join(" ").toLowerCase();
        if (extra.includes(q)) return 3;
        // буквы запроса по порядку, с пропусками
        // the query's letters in order, with gaps
        let i = 0, gaps = 0, last = -1;
        for (let k = 0; k < n.length && i < q.length; k++) if (n[k] === q[i]) { if (last >= 0) gaps += k - last - 1; last = k; i++; }
        if (i === q.length && q.length >= 2) return 4 + gaps / 50;
        // опечатки: сравниваем с началом каждого слова той же длины
        // typos: compare with the start of each word of the same length
        if (q.length >= 3) {
            const tol = q.length >= 6 ? 2 : 1;
            const best = Math.min(...words.concat([n]).map(w => editDist(q, w.slice(0, q.length))));
            if (best <= tol) return 5 + best;
        }
        return -1;
    }

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (q.length > 0)
            return apps.map(e => ({ e: e, s: score(e, q) }))
                .filter(x => x.s >= 0)
                .sort((a, b) => a.s - b.s || ((usage[b.e.id]?.count ?? 0) - (usage[a.e.id]?.count ?? 0)))
                .map(x => ({ kind: "app", data: x.e }));
        let list;
        if (category === "fav") list = apps.filter(e => favorites.includes(e.id));
        else if (category === "recent") list = apps.filter(e => usage[e.id]?.last)
                                                    .sort((a, b) => usage[b.id].last - usage[a.id].last).slice(0, 20);
        else if (category === "all") list = apps;
        else {
            const def = categoryDefs.find(c => c[0] === category);
            list = def ? apps.filter(e => inCat(e, def)) : apps;
        }
        return list.map(e => ({ kind: "app", data: e }));
    }

    // ─── хранение: избранное и счётчик запусков ───
    // ─── storage: favourites and launch counter ───
    FileView {
        id: favFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/favorites.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { win.favorites = JSON.parse(text()); } catch (e) { win.favorites = []; } }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { try { win.favorites = JSON.parse(text()); } catch (e) { win.favorites = []; } }
}
    FileView {
        id: useFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/usage.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { win.usage = JSON.parse(text()); } catch (e) { win.usage = {}; } }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { try { win.usage = JSON.parse(text()); } catch (e) { win.usage = {}; } }
}
    ContextMenu { id: menu; screen: win.screen }
    function appMenu(item, e, m): void {
        const p = item.mapToItem(null, m ? m.x : item.width / 2, m ? m.y : item.height / 2);
        const fav = favorites.includes(e.id), pinned = ShellState.pinned.includes(e.id);
        menu.items = [
            { icon: "play_arrow", text: L.t("открыть"), action: () => win.activate({ kind: "app", data: e }) },
            { separator: true },
            { icon: "star", text: fav ? L.t("убрать из избранного") : L.t("добавить в избранное"), action: () => win.toggleFav(e.id) },
            { icon: "pin", text: pinned ? L.t("открепить от панели") : L.t("закрепить на панели"), action: () => ShellState.togglePin(e.id) },
            { icon: "folder_open", text: L.t("расположение файлов"), action: () => win.showFiles(e) },
            { separator: true },
            { icon: "refresh", text: L.t("очистить данные…"), danger: true, action: () => win.askClear(e, p) },
            { icon: "bin", text: L.t("удалить"), danger: true, action: () => win.uninstall(e) }
        ];
        menu.openAt(p.x, p.y, false);
    }
    // «очистить данные»: сначала показываем, какие папки найдены, и только по второму клику — в корзину
    // "clear data": first show which folders were found, and only on a second click move them to the trash
    property var clearFor: null
    property var clearAt: null
    function askClear(e, p): void {
        clearFor = e; clearAt = p;
        dataProc.command = ["sh", Quickshell.shellPath("app-data.sh"), "list", e.id, (e.command?.[0] ?? ""), e.name];
        dataProc.running = true;
    }
    Process {
        id: dataProc
        stdout: StdioCollector {
            onStreamFinished: {
                const dirs = text.split("\n").filter(l => l), e = win.clearFor, home = Quickshell.env("HOME");
                menu.items = dirs.length
                    ? dirs.map(d => ({ icon: "folder_open", text: d.replace(home, "~"), enabled: false }))
                        .concat([{ separator: true },
                                 { icon: "bin", text: L.t("в корзину: ") + dirs.length, danger: true,
                                   action: () => Quickshell.execDetached(["sh", Quickshell.shellPath("app-data.sh"), "trash", e.id, (e.command?.[0] ?? ""), e.name, L.t("перенесено в корзину, папок:")]) },
                                 { icon: "close", text: L.t("отмена"), action: () => {} }])
                    : [{ icon: "close", text: L.t("данных приложения не нашлось"), enabled: false }];
                menu.openAt(win.clearAt.x, win.clearAt.y, false);
            }
        }
    }

    // папка, где лежит программа (а если не нашли — где лежит её ярлык)
    // the folder where the app lives (or, if not found, where its shortcut lives)
    function showFiles(e): void {
        ShellState.launcherOpen = false;
        const bin = (e.command?.[0] ?? e.execString?.split(" ")[0] ?? "");
        Quickshell.execDetached(["sh", "-c",
            'b=$(command -v "$1" 2>/dev/null) && b=$(readlink -f "$b") && exec nemo "$(dirname "$b")"; ' +
            'for d in "$HOME/.local/share/applications" /usr/share/applications /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do ' +
            '[ -f "$d/$2.desktop" ] && exec nemo "$d"; done', "sh", bin, e.id]);
    }
    // удаление: пароль спрашивает наше окно polkit — ввод пароля и есть подтверждение.
    // pacman-пакет определяем по ярлыку; flatpak — своим удалением. Итог — уведомлением
    // uninstalling: our polkit window asks for the password, and entering it is the confirmation.
    // the pacman package is found from the shortcut; flatpak uses its own uninstall. The result comes as a notification
    function uninstall(e): void {
        ShellState.launcherOpen = false;
        Quickshell.execDetached(["sh", "-c",
            'id="$1"; name="$2"; ' +
            'for d in "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications; do ' +
            '  [ -f "$d/$id.desktop" ] && { flatpak uninstall -y --noninteractive "$id" && notify-send -a nyashell "$name" "$3" || notify-send -a nyashell "$name" "$4"; exit; }; done; ' +
            'f=""; for d in "$HOME/.local/share/applications" /usr/share/applications; do [ -f "$d/$id.desktop" ] && f="$d/$id.desktop" && break; done; ' +
            'p=$(pacman -Qqo "$f" 2>/dev/null); [ -n "$p" ] || { notify-send -a nyashell "$name" "$5"; exit; }; ' +
            'pkexec pacman -Rns --noconfirm "$p" && notify-send -a nyashell "$name" "$3 ($p)" || notify-send -a nyashell "$name" "$6"',
            "sh", e.id, e.name, L.t("удалено"), L.t("не удалось удалить"), L.t("не нашла, каким пакетом установлено"), L.t("удаление отменено")]);
    }

    function toggleFav(id: string): void {
        const f = favorites.slice(), i = f.indexOf(id);
        if (i >= 0) f.splice(i, 1); else f.push(id);
        favorites = f;
        favFile.setText(JSON.stringify(f));
    }
    function activate(item): void {
        if (!item) return;
        if (item.kind === "action") item.data.run();
        else {
            const u = Object.assign({}, usage);
            const old = typeof u[item.data.id] === "object" ? u[item.data.id] : { count: u[item.data.id] || 0 };
            u[item.data.id] = { count: (old.count || 0) + 1, last: Date.now() };
            usage = u;
            useFile.setText(JSON.stringify(u));
            item.data.execute();
        }
        ShellState.launcherOpen = false;
    }
    function enter(): void { activate(shown[Math.max(0, list.currentIndex)]); }
    // фокус: в поиск, если он виден, иначе — в невидимого «ловца», который начнёт поиск с первой буквы
    // focus: to the search if it's visible, otherwise to an invisible "catcher" that starts the search from the first letter
    function focusInput(): void { if (bottomRow.visible && bottomRow.searchShown) search.forceActiveFocus(); else keyCatcher.forceActiveFocus(); }
    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: (ev) => {
            if (ev.key === Qt.Key_Escape) { ShellState.launcherOpen = false; ev.accepted = true; }
            else if (ev.key === Qt.Key_Down) { list.incrementCurrentIndex(); ev.accepted = true; }
            else if (ev.key === Qt.Key_Up) { list.decrementCurrentIndex(); ev.accepted = true; }
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { win.enter(); ev.accepted = true; }
            else if (ev.key === Qt.Key_Tab) {
                const i = win.categories.findIndex(c => c[0] === win.category);
                win.category = win.categories[(i + 1) % win.categories.length][0];
                list.currentIndex = 0; ev.accepted = true;
            }
            else if (ev.text && ev.text.trim() && !(ev.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                // первая буква — поле поиска появляется и забирает фокус, буква уже в нём
                // first letter: the search field appears and takes focus, with the letter already in it
                search.text = ev.text;
                Qt.callLater(() => { search.forceActiveFocus(); search.cursorPosition = search.text.length; });
                ev.accepted = true;
            }
        }
    }

    onVisibleChanged: if (visible && ShellState.launcherOpen) {
        search.text = "";
        category = favorites.length > 0 ? "fav" : "all";
        list.currentIndex = 0;
        win.focusInput();
    }
    Connections {
        target: ShellState
        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                search.text = "";
                win.category = win.favorites.length > 0 ? "fav" : "all";
                list.currentIndex = 0;
                win.focusInput();
            }
        }
    }

    // клик мимо — закрыть
    // click outside to close
    MouseArea {
        anchors.fill: parent
        enabled: ShellState.launcherOpen
        onClicked: ShellState.launcherOpen = false
    }

    // ─── форма ящика ───
    // ─── drawer shape ───
    Shape {
        id: shp
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real yT: win.yB - win.hh
        readonly property real rr: Math.min(win.r, win.hh / 2)
        readonly property real curR: Math.min(win.bigR, win.hh / 2)
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            startX: 0; startY: shp.yT - shp.rr
            PathLine { x: win.t; y: shp.yT - shp.rr }
            PathArc  { x: win.t + shp.rr; y: shp.yT; radiusX: shp.rr; radiusY: shp.rr; direction: PathArc.Counterclockwise }
            PathLine { x: win.t + win.w - shp.curR; y: shp.yT }
            PathArc  { x: win.t + win.w; y: shp.yT + shp.curR; radiusX: shp.curR; radiusY: shp.curR }
            PathLine { x: win.t + win.w; y: win.yB - shp.rr }
            PathArc  { x: win.t + win.w + shp.rr; y: win.yB; radiusX: shp.rr; radiusY: shp.rr; direction: PathArc.Counterclockwise }
            PathLine { x: win.t + win.w + shp.rr; y: win.yB + 1 }
            PathLine { x: 0; y: win.yB + 1 }
        }
    }

    // ─── содержимое ───
    // ─── content ───
    Item {
        x: win.t
        y: win.yB - win.hh
        width: win.w
        height: win.hh
        clip: true
        MouseArea { anchors.fill: parent }       // клики внутри не закрывают / clicks inside don't close

        ColumnLayout {
            x: Tokens.gap.large
            y: Tokens.gap.large
            width: win.w - Tokens.gap.large * 2
            height: win.fullH - Tokens.gap.large * 2
            spacing: Tokens.gap.medium
            opacity: ShellState.launcherOpen ? 1 : 0
            Behavior on opacity { Anim { kind: "effects" } }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.gap.medium

                // категории
                // categories
                ListView {
                    SmoothWheel {}
                    Layout.preferredWidth: 176
                    Layout.fillHeight: true
                    spacing: 2
                    clip: true
                    model: win.categories
                    delegate: Item {
                        required property var modelData
                        readonly property bool active: win.query.length === 0 && win.category === modelData[0]
                        // категория: значок в плашке (у выбранной — цвета акцента) и название
                        // category: an icon in a chip (the selected one in the accent colour) and a name
                        width: 176; height: 46
                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: parent.active ? Theme.tonalHi : "transparent"
                            Behavior on color { CAnim {} }
                        }
                        Rectangle {
                            x: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 34; height: 34; radius: 11
                            color: parent.active ? Theme.accent : Theme.surface
                            Behavior on color { CAnim {} }
                            Icon { anchors.centerIn: parent; name: modelData[2]; size: 14
                                   color: parent.parent.active ? Theme.onAccent : Theme.accent }
                        }
                        Text { x: 50; width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.normal; font.bold: parent.active
                               text: modelData[1]; color: parent.active ? Theme.accent : Theme.text }
                        StateLayer { radius: 16; onClicked: { search.text = ""; win.category = modelData[0]; list.currentIndex = 0; } }
                    }
                }

                // избранное (без поиска) — сетка крупных значков
                // favourites (without a search): a grid of large icons
                GridView {
                    SmoothWheel {}
                    id: grid
                    visible: (win.category === "fav" || win.category === "recent") && !win.query && win.shown.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: visible ? win.shown : []
                    cellWidth: Math.floor(width / 4)
                    cellHeight: 104
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        StaggerIn { index: parent.index; active: ShellState.launcherOpen }
                        // карточка приложения: при наведении — подложка и значок чуть крупнее
                        // app card: on hover a backing appears and the icon grows slightly
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Tokens.rounding.large
                            color: cm.containsMouse ? Theme.surface : "transparent"
                            Behavior on color { CAnim {} }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            AppIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 52; icon: cell.modelData.data.icon
                                      scale: cm.containsMouse ? 1.1 : 1
                                      Behavior on scale { Anim { kind: "fastSpatial" } } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; width: grid.cellWidth - 12
                                   horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                   font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                                   text: cell.modelData.data.name }
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (m) => {
                                if (m.button === Qt.LeftButton) win.activate(cell.modelData);
                                else if (m.button === Qt.MiddleButton) win.toggleFav(cell.modelData.data.id);
                                else win.appMenu(cell, cell.modelData.data, m);
                            }
                        }
                    }
                }

                // список
                // list
                ListView {
                    SmoothWheel {}
                    id: list
                    visible: !grid.visible
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: win.shown
                    highlightMoveDuration: 140
                    highlight: Rectangle { radius: 16; color: Theme.surface; border.color: Theme.outline }
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isApp: modelData.kind === "app"
                        readonly property bool fav: isApp && win.favorites.includes(modelData.data.id)
                        width: list.width
                        height: 54
                        // строка: значок покрупнее (у действий — в плашке), название и описание
                        // row: a larger icon (actions have it in a chip), name and description
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 12
                            Item {
                                width: 38; height: 38
                                anchors.verticalCenter: parent.verticalCenter
                                AppIcon { anchors.fill: parent; visible: row.isApp; size: 38
                                          icon: row.isApp ? row.modelData.data.icon : "" }
                                Rectangle { anchors.fill: parent; visible: !row.isApp; radius: 12; color: Theme.tonal
                                    Icon { anchors.centerIn: parent; name: row.isApp ? "" : row.modelData.data.icon; size: 16; color: Theme.accent } }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text
                                       text: row.modelData.data.name }
                                Text { visible: text.length > 0; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                       color: Theme.textDim; text: row.isApp ? (row.modelData.data.genericName || "") : L.t("действие") }
                            }
                        }
                        Icon {
                            visible: row.fav
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            name: "star"; size: 12; color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = row.index
                            onClicked: (m) => {
                                if (!row.isApp || m.button === Qt.LeftButton) { win.activate(row.modelData); return; }
                                if (m.button === Qt.MiddleButton) { win.toggleFav(row.modelData.data.id); return; }
                                win.appMenu(row, row.modelData.data, m);
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: win.shown.length === 0
                        font.family: Theme.font
                        font.pixelSize: Tokens.font.smaller
                        color: Theme.textDim
                        text: win.category === "fav" && !win.query ? L.t("СКМ по приложению — в избранное")
                            : win.category === "recent" && !win.query ? L.t("тут появятся приложения, которые ты недавно запускал(а)")
                            : L.t("ничего не найдено")
                    }
                }
            }

            // нижний ряд: поиск (появляется, когда начинаешь печатать, или всегда — по настройке) и кнопки питания
            // bottom row: search (appears when you start typing, or always, depending on the setting) and power buttons
            RowLayout {
                id: bottomRow
                readonly property bool searchShown: (ShellState.settings.launcherSearchAlways ?? false) || search.text.length > 0
                readonly property bool powerShown: ShellState.settings.launcherPower ?? true
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                // спрятанный ряд не занимает места вовсе — категории и приложения растягиваются до низа
                // a hidden row takes no space at all: categories and apps stretch to the bottom
                visible: searchShown || powerShown
                spacing: Tokens.gap.small

            // поиск снизу, ближе к лапке (как у caelestia). Поле всегда держит фокус — печатать можно сразу,
            // просто, пока пусто, оно спрятано
            // search at the bottom, near the paw (as in caelestia). The field always holds focus, so you can type right away,
            // it's just hidden while empty
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                opacity: bottomRow.searchShown ? 1 : 0
                scale: bottomRow.searchShown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                radius: 24
                color: Theme.surface
                border.color: search.activeFocus ? Theme.outline : "transparent"

                Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; color: Theme.accent }
                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 46
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font
                    font.pixelSize: Tokens.font.larger
                    color: Theme.text
                    selectionColor: Theme.accent
                    onTextChanged: { win.query = text; list.currentIndex = 0; if (!text && !bottomRow.searchShown) Qt.callLater(win.focusInput); }
                    Keys.onPressed: (ev) => {
                        if (ev.key === Qt.Key_Escape) { ShellState.launcherOpen = false; ev.accepted = true; }
                        else if (ev.key === Qt.Key_Down) { list.incrementCurrentIndex(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Up) { list.decrementCurrentIndex(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { win.enter(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Tab && !win.query) {
                            const i = win.categories.findIndex(c => c[0] === win.category);
                            win.category = win.categories[(i + 1) % win.categories.length][0];
                            list.currentIndex = 0;
                            ev.accepted = true;
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        font.family: Theme.font
                        font.pixelSize: Tokens.font.normal
                        color: Theme.textDim
                        text: L.t("поиск…   Tab — категории")
                    }
                }
            }

                // выход / ребут / выкл (полное меню питания — Super+Space)
                // log out / reboot / power off (the full power menu is Super+Space)
                Repeater {
                    model: !bottomRow.powerShown ? [] : [["logout", ["mmsg", "dispatch", "quit"]], ["restart_alt", ["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot"]],
                            ["power_settings_new", ["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff"]]]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: 24
                        color: Theme.surface
                        Icon { anchors.centerIn: parent; name: modelData[0]; size: 15
                               color: index === 2 ? Theme.danger : Theme.accent }
                        StateLayer { radius: 24; onClicked: { ShellState.launcherOpen = false; ShellState.leave(modelData[1]); } }
                    }
                }
            }
        }
    }
}
