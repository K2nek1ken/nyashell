import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// дашборд — «ящик» из верхней рамки (как у caelestia): подведи курсор к верху по центру.
// вкладки: главная, медиа, система, погода, браузер (chromium инкогнито, живёт, пока жив шелл)
// the dashboard is a "drawer" from the top frame (as in caelestia): move the cursor to the top centre.
// tabs: home, media, system, weather, browser (a separate Firefox, lives as long as the shell)
PanelWindow {
    id: win
    property bool open: false
    property bool pinned: false           // открыт хоткеем — не закрываем, пока не уведут курсор / opened with a hotkey: don't close until the cursor leaves
    property int tab: 0
    // клавишами внутри вкладки (см. Nav.qml); смена вкладки или закрытие — снова на уровне вкладок
    // keys inside a tab (see Nav.qml); switching tabs or closing goes back to the tab level
    property bool navIn: false
    onNavInChanged: if (!navIn) Nav.leave()
    // смена вкладки забирает клавиатуру у поля ввода прошлой вкладки (иначе печать продолжала уходить в её поиск)
    // switching tabs takes the keyboard away from the previous tab's input field (typing kept going into its search)
    onTabChanged: { navIn = false; if (open) keys.forceActiveFocus(); }
    readonly property int browserTab: 5
    // все вкладки; какие показывать — Настройки → Панель и меню → Борд (по умолчанию все, кроме браузера)
    // all tabs; which ones to show is in Settings → Bar and menu → Dashboard (by default all except the browser)
    readonly property var allTabs: [["home", "dashboard", L.t("Главная")], ["player", "music", L.t("Плеер")], ["music", "queue", L.t("Музыка")],
                                    ["eq", "sliders", L.t("Эквалайзер")], ["weather", "w_partly", L.t("Погода")], ["browser", "public", L.t("Браузер")]]
    readonly property var shownTabs: {
        const on = ShellState.settings.dashTabs ?? ["home", "player", "music", "eq", "weather"];
        const r = [];
        for (let i = 0; i < allTabs.length; i++) if (on.includes(allTabs[i][0])) r.push(i);
        return r.length ? r : [0];
    }
    readonly property int tabCount: shownTabs.length
    readonly property int tabPos: Math.max(0, shownTabs.indexOf(tab))
    function tabStep(d: int): void { tab = shownTabs[(tabPos + d + tabCount) % tabCount]; }
    // выключили вкладку, на которой стояли, — переходим на первую из оставшихся
    // the tab we were on got turned off: go to the first remaining one
    onShownTabsChanged: if (!shownTabs.includes(tab)) tab = shownTabs[0]
    Component.onCompleted: if (!shownTabs.includes(tab)) tab = shownTabs[0]
    // полноэкранное окно на этом экране: рамки не видно — ящик висит прямо от верхнего края
    // a full-screen window on this screen: no frame visible, the drawer hangs straight from the top edge
    readonly property bool fs: ShellState.fullscreenOn(screen?.name ?? "")
    readonly property real t: fs ? 0 : Tokens.frame
    readonly property real r: Tokens.frameRadius      // вогнутые углы у рамки / concave corners at the frame
    readonly property real bigR: Tokens.rounding.extraLarge
    // обычный размер и увеличенный — для браузера; окно слоя всегда максимального размера,
    // а видимый «ящик» внутри него плавно растёт по центру
    // браузер живёт в обычном размере борда — ящик больше не растягивается
    // normal size and an enlarged one for the browser; the layer window is always at maximum size,
    // and the visible "drawer" inside it grows smoothly from the centre
    // the browser lives at the dashboard's normal size: the drawer no longer stretches
    readonly property bool wide: false
    readonly property real maxW: Math.min(1180, (screen?.width ?? 1920) - 2 * r - 80)
    readonly property real maxH: Math.min(700, (screen?.height ?? 1080) - Tokens.barHeight - t - 60)
    property real contentW: wide ? maxW : 900
    property real contentH: wide ? maxH : 392
    Behavior on contentW { Anim { kind: "spatial" } }
    Behavior on contentH { Anim { kind: "spatial" } }
    // окно ровно по ширине ящика: центрирует его сам композитор. Раньше окно было «на вырост»
    // (под браузер), а ящик сдвигался внутри — и на экране уезжал вбок, хотя хитбокс стоял верно
    // the window is exactly as wide as the drawer, so the compositor centres it. Previously the window was oversized
    // (for the browser) and the drawer moved inside it, so on screen it drifted sideways though the hitbox was right
    readonly property real ox: 0
    readonly property real h: open ? contentH : 0     // текущая высота ящика / current drawer height

    readonly property var players: Mpris.players.values
    property int playerIdx: -1
    readonly property var player: playerIdx >= 0 && playerIdx < players.length ? players[playerIdx]
                                 : (players.find(p => p.isPlaying) ?? players[0] ?? null)

    anchors.top: true
    implicitWidth: contentW + 2 * r
    implicitHeight: t + maxH + 4
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // борд всегда в самом верхнем слое — над полноэкранными окнами (как монитор системы);
    // только на вкладке браузера — ниже, чтобы окно Firefox было над бордом, а не под ним.
    // слой больше не переключается при открытии: раньше он менялся на лету, и над игрой борд мог остаться внизу
    // the dashboard is always in the topmost layer, above full-screen windows (like the system monitor);
    // only on the browser tab is it lower, so the Firefox window is above the dashboard rather than under it.
    // the layer no longer switches on open: it used to change on the fly, and over a game the dashboard could stay below
    WlrLayershell.layer: tab !== browserTab ? WlrLayer.Overlay : WlrLayer.Top
    // пока открыт диалог выбора файла (обложка плейлиста, импорт EQ) — борд прячется, но остаётся открытым
    // while a file chooser is open (a playlist cover, EQ import) the dashboard hides but stays open
    visible: !ShellState.fileDialog
    mask: Region {
        x: win.open ? win.ox : trigger.x
        y: 0
        // в полноэкранном режиме (игры) край экрана борд не открывает — только Super+S
        // in full screen (games) the screen edge doesn't open the dashboard, only Super+S does
        width: win.open ? win.contentW + 2 * win.r : (win.fs ? 0 : trigger.width)
        height: win.open ? win.t + win.hh : trigger.height
    }

    onOpenChanged: {
        if (!open) navIn = false;
        if (!open) menusClose();
        if (open) SysInfo.watchers++; else { SysInfo.watchers = Math.max(0, SysInfo.watchers - 1); pinned = false; }
    }
    function toggle(): void { if (open) open = false; else { open = true; pinned = true; closeTimer.stop(); focusLater.restart(); } }
    // фокус клавиатуры появляется у окна чуть позже открытия — отдаём его «клавишам» с задержкой
    // keyboard focus reaches the window a little after opening, so hand it to the key handler with a delay
    Timer { id: focusLater; interval: 60; onTriggered: keys.forceActiveFocus() }
    // по ящику кликнули мимо полей ввода — клавиши снова у борда
    // a click on the drawer outside the input fields: keys go back to the dashboard
    signal menusClose()
    // клавиатура: открыт хоткеем — борд забирает её (A/D, стрелки, Esc работают сразу);
    // открыт наведением — получает её по клику (чтобы печатать в полях); на вкладке браузера — у Firefox
    // keyboard: opened with a hotkey, the dashboard takes it (A/D, arrows, Esc work right away);
    // opened by hovering, it gets it on click (to type in the fields); on the browser tab Firefox has it
    WlrLayershell.keyboardFocus: !open || tab === browserTab ? WlrKeyboardFocus.None
                                : pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    Item {
        id: keys
        focus: true
        // два уровня: вкладки (A/D — листать, S / пробел — войти внутрь вкладки) и сама вкладка
        // (WASD / стрелки — по кнопкам, спискам и полям, пробел / Enter — нажать, W с верхнего ряда или Esc — к вкладкам)
        // two levels: tabs (A/D to flip, S / space to enter the tab) and the tab itself
        // (WASD / arrows over buttons, lists and fields, space / Enter to press, W from the top row or Esc back to the tabs)
        Keys.onPressed: (e) => {
            const a = ShellState.keyIs(e, "a") || e.key === Qt.Key_Left, d = ShellState.keyIs(e, "d") || e.key === Qt.Key_Right;
            const w = ShellState.keyIs(e, "w") || e.key === Qt.Key_Up, sDown = ShellState.keyIs(e, "s") || e.key === Qt.Key_Down;
            const go = e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter;
            if (!win.navIn) {
                if (a) win.tabStep(-1);
                else if (d) win.tabStep(1);
                else if ((sDown || go) && win.tab !== win.browserTab) { Nav.home = keys; win.navIn = Nav.enter(pages); }
                else if (e.key === Qt.Key_Escape) win.open = false;
                else return;
            } else {
                if (e.key === Qt.Key_Escape) win.navIn = false;
                else if (go) Nav.activate();
                else if (w) { if (!Nav.move("w")) win.navIn = false; }
                else if (sDown) Nav.move("s");
                else if (a) Nav.move("a");
                else if (d) Nav.move("d");
                else return;
            }
            e.accepted = true;
        }
    }

    // анимируем высоту — ящик выдвигается из-под рамки
    // height is animated: the drawer slides out from under the frame
    property real hh: h
    Behavior on hh { Anim { kind: win.open ? "spatial" : "emphasized"; duration: win.open ? Tokens.dur.defaultSpatial : Tokens.dur.normal } }

    Item {
        id: trigger
        x: win.r + (win.contentW - 320) / 2
        width: 320
        height: win.t + 2
        HoverHandler { onHoveredChanged: if (hovered) { closeTimer.stop(); win.open = true; } }
    }
    // на вкладке браузера ждём дольше (секунду) — но всё равно закрываемся, когда курсор ушёл с борда
    // on the browser tab wait longer (a second), but still close once the cursor has left the dashboard
    Timer { id: closeTimer; interval: ShellState.settings.dashDelay ?? 150
            onTriggered: if (!bodyHover.hovered && !win.menuHold && !ShellState.fileDialog) win.open = false }
    // открыто меню какой-то вкладки (оно — отдельное окно, курсор уходит на него с борда): не закрываемся,
    // а когда меню закроется и курсора над бордом нет — закрываемся как обычно
    // some tab's menu is open (it's a separate window, the cursor moves onto it from the dashboard): don't close,
    // and once the menu closes with no cursor over the dashboard, close as usual
    property bool menuHold: false
    function closeSoon(): void { if (tab !== browserTab) closeTimer.restart(); }
    onMenuHoldChanged: if (!menuHold && open && !bodyHover.hovered) win.closeSoon()
    readonly property bool browserFocused: browserShown && /nyash-browser/i.test(ToplevelManager.activeToplevel?.appId ?? "")
    onBrowserFocusedChanged: if (!browserFocused && open && !bodyHover.hovered) win.closeSoon()
    // при закрытии запоминаются и вкладка борда (tab не сбрасывается), и страницы браузера (окно лишь сворачивается)
    // on close both the dashboard tab (tab isn't reset) and the browser pages (the window is only minimised) are remembered

    Item {
        id: body
        x: win.ox
        width: win.contentW + 2 * win.r
        height: win.t + win.hh
        // курсор ушёл — закрываемся (на всех вкладках). Окно браузера — отдельное окно поверх борда,
        // поэтому «курсор над браузером» узнаём по фокусу: у mango фокус следует за курсором
        // the cursor left: close (on every tab). The browser is a separate window on top of the dashboard,
        // so "cursor over the browser" is known from focus: in mango focus follows the cursor
        HoverHandler {
            id: bodyHover
            onHoveredChanged: {
                if (hovered) closeTimer.stop();
                else if (win.open) win.closeSoon();
            }
        }

        // форма ящика: вогнутые углы сверху, скругления снизу
        // drawer shape: concave corners on top, rounded at the bottom
        Shape {
            id: shp
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real rr: Math.min(win.r, win.hh / 2)
            readonly property real curR: Math.min(win.bigR, win.hh / 2)
            readonly property real fullW: win.ox * 2 + win.contentW + 2 * win.r
            readonly property real bottomY: win.t + win.hh
            ShapePath {
                fillColor: Theme.frame
                strokeWidth: -1
                Behavior on fillColor { CAnim {} }
                startX: win.ox + win.r - shp.rr; startY: 0
                PathLine { x: win.ox + win.r - shp.rr; y: win.t }
                PathArc  { x: win.ox + win.r; y: win.t + shp.rr; radiusX: shp.rr; radiusY: shp.rr }
                PathLine { x: win.ox + win.r; y: shp.bottomY - shp.curR }
                PathArc  { x: win.ox + win.r + shp.curR; y: shp.bottomY; radiusX: shp.curR; radiusY: shp.curR; direction: PathArc.Counterclockwise }
                PathLine { x: shp.fullW - win.ox - win.r - shp.curR; y: shp.bottomY }
                PathArc  { x: shp.fullW - win.ox - win.r; y: shp.bottomY - shp.curR; radiusX: shp.curR; radiusY: shp.curR; direction: PathArc.Counterclockwise }
                PathLine { x: shp.fullW - win.ox - win.r; y: win.t + shp.rr }
                PathArc  { x: shp.fullW - win.ox - win.r + shp.rr; y: win.t; radiusX: shp.rr; radiusY: shp.rr }
                PathLine { x: shp.fullW - win.ox - win.r + shp.rr; y: 0 }
            }
        }

        // содержимое едет вместе с нижним краем
        // the content moves with the bottom edge
        Item {
            x: win.ox + win.r
            y: win.t
            width: win.contentW
            height: win.hh
            clip: true

            Item {
                id: content
                width: win.contentW
                height: win.contentH
                y: win.hh - win.contentH
                opacity: win.open ? 1 : 0
                Behavior on opacity { Anim { kind: "effects" } }

                // ─── вкладки ───
                // ─── tabs ───
                Row {
                    id: tabs
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    Repeater {
                        model: win.shownTabs
                        delegate: Item {
                            required property var modelData        // номер вкладки в allTabs / tab number in allTabs
                            readonly property int ti: modelData
                            width: win.contentW / win.tabCount; height: 44
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: win.allTabs[modelData][1]; size: 14
                                       color: win.tab === ti ? Theme.accent : Theme.textDim }
                                Text { font.family: Theme.font; text: win.allTabs[modelData][2]; font.pixelSize: Tokens.font.smaller
                                       color: win.tab === ti ? Theme.accent : Theme.text }
                            }
                            StateLayer { radius: Tokens.rounding.medium; onClicked: win.tab = ti }
                        }
                    }
                }
                // скользящая черта под активной вкладкой
                // the sliding line under the active tab
                Rectangle {
                    y: tabs.y + 44
                    x: tabs.x + win.tabPos * (win.contentW / win.tabCount) + (win.contentW / win.tabCount - 70) / 2
                    width: 70; height: 3; radius: 2
                    color: Theme.accent
                    Behavior on x { Anim { kind: "fastSpatial" } }
                }
                Rectangle { y: tabs.y + 47; x: 16; width: parent.width - 32; height: 1; color: Theme.surfaceHi }

                // ─── страницы: съезжают вбок ───
                // ─── pages: slide sideways ───
                Item {
                    id: pages
                    y: 62
                    width: parent.width
                    height: parent.height - 62 - 12
                    clip: true

                    Row {
                        x: -win.tabPos * pages.width
                        Behavior on x { Anim { kind: "spatial" } }
                        DashHome { width: pages.width; height: pages.height; dash: win; visible: win.shownTabs.includes(0) }
                        DashMedia { width: pages.width; height: pages.height; dash: win; visible: win.shownTabs.includes(1) }
                        DashMusic { width: pages.width; height: pages.height; dash: win; visible: win.shownTabs.includes(2) }
                        DashEq { width: pages.width; height: pages.height; dash: win; visible: win.shownTabs.includes(3) }
                        DashWeather { width: pages.width; height: pages.height; visible: win.shownTabs.includes(4) }
                        // окно браузера лежит поверх этой пустой страницы (слой «overlay» у mango)
                        // the browser window lies on top of this empty page (mango's "overlay" layer)
                        Item {
                            width: pages.width; height: pages.height
                            visible: win.shownTabs.includes(5)
                            Column {
                                anchors.centerIn: parent
                                visible: !win.browserShown
                                spacing: 10
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "public"; size: 40; color: Theme.accent }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                                       font.pixelSize: Tokens.font.normal; color: Theme.textDim
                                       text: win.browserId < 0 ? L.t("запускаю firefox…") : L.t("секунду…") }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── браузер в борде ───
    // chromium в инкогнито с отдельным профилем. Когда уходим с вкладки или закрываем борд,
    // окно просто сворачивается — вкладки и всё открытое остаются до перезапуска шелла.
    // ─── browser in the dashboard ───
    // a separate Firefox profile. When we leave the tab or close the dashboard,
    // the window is just minimised: tabs and everything open stay until the shell restarts.
    property int browserId: -1
    property bool browserShown: false
    property var knownIds: []
    readonly property bool browserWanted: open && tab === browserTab
    onBrowserWantedChanged: browserWanted ? showSoon.restart() : hideBrowser()
    Timer { id: showSoon; interval: 380; onTriggered: win.showBrowser() }   // ждём, пока ящик раскроется / wait for the drawer to open

    function browserGeom() {
        const sx = screen?.x ?? 0, sy = screen?.y ?? 0, sw = screen?.width ?? 1920;
        const left = sx + (sw - win.width) / 2 + win.ox + win.r;
        return { x: Math.round(left + 10), y: Math.round(sy + win.t + 62), w: Math.round(win.contentW - 20), h: Math.round(win.contentH - 62 - 10) };
    }
    function mm(args): void { Quickshell.execDetached(["mmsg", "dispatch"].concat(args)); }
    function showBrowser(): void {
        if (!browserWanted) return;
        const alive = ShellState.mangoClients.some(c => c.id === browserId);
        if (!alive) {
            browserId = -1;
            knownIds = ShellState.mangoClients.map(c => c.id);
            // Firefox: лёгкий, и в нём можно убрать весь интерфейс, кроме строки адреса (см. browser.sh)
            // Firefox: light, and all of its UI except the address bar can be hidden (see browser.sh)
            Quickshell.execDetached(["sh", Quickshell.shellPath("browser.sh")]);
            return;                                    // окно подхватим, когда mango о нём сообщит / we pick up the window once mango reports it
        }
        const g = browserGeom();
        mm(["focusid", "client," + browserId]);        // заодно разворачивает из свёрнутого / also restores it from minimised
        mm(["resizewin," + g.w + "," + g.h, "client," + browserId]);
        mm(["movewin," + g.x + "," + g.y, "client," + browserId]);
        browserShown = true;
    }
    function hideBrowser(): void {
        showSoon.stop();
        if (browserId >= 0 && browserShown) mm(["minimized", "client," + browserId]);
        browserShown = false;
    }
    // ловим новое окно chromium после запуска и один раз настраиваем его
    // catch the new browser window after launch and set it up once
    Connections {
        target: ShellState
        function onMangoClientsChanged() {
            if (win.browserId >= 0) {
                if (!ShellState.mangoClients.some(c => c.id === win.browserId)) { win.browserId = -1; win.browserShown = false; }
                return;
            }
            const c = ShellState.mangoClients.find(c => !win.knownIds.includes(c.id) && /nyash-browser|firefox/i.test(c.appid || ""));
            if (!c) return;
            win.browserId = c.id;
            // окно открылось на запасной странице: сначала размер и место, потом «на всех страницах» —
            // и только тогда оно появляется, уже внутри борда (без «на весь экран, а потом уменьшается»)
            // the window opened on the spare page: first size and position, then "on all pages",
            // and only then does it appear, already inside the dashboard (no "full screen, then shrinks")
            const g = win.browserGeom(), id = "client," + c.id;
            Quickshell.execDetached(["sh", "-c",
                "mmsg dispatch resizewin," + g.w + "," + g.h + " " + id + "; " +
                "mmsg dispatch movewin," + g.x + "," + g.y + " " + id + "; " +
                "mmsg dispatch toggleoverlay " + id + "; sleep 0.1; " +
                (win.browserWanted ? "mmsg dispatch toggleglobal " + id + "; mmsg dispatch focusid " + id
                                   : "mmsg dispatch toggleglobal " + id + "; mmsg dispatch minimized " + id)]);
            win.browserShown = win.browserWanted;
        }
    }
    // если борд поменял размер, пока браузер открыт — подвинуть окно
    // if the dashboard changed size while the browser is open, move the window
    onContentWChanged: if (browserShown) repos.restart()
    Timer { id: repos; interval: 120; onTriggered: win.showBrowser() }

    // ─── вкладка браузера: всё вокруг борда ловит курсор и клики ───
    // Firefox — отдельное окно, и пока курсор над ним, борд «не видит» мышь. Поэтому вокруг борда кладём
    // невидимый слой: клик по нему или курсор на нём дольше секунды — борд закрывается
    // ─── browser tab: everything around the dashboard catches the cursor and clicks ───
    // Firefox is a separate window, and while the cursor is over it the dashboard can't "see" the mouse. So around the dashboard
    // we put an invisible layer: a click on it or the cursor resting on it for over a second closes the dashboard
    PanelWindow {
        id: catcher
        screen: win.screen
        visible: win.open && win.tab === win.browserTab
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "nyash-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        // сам борд (и браузер в нём) — дырка в слое, туда клики проходят как обычно
        // the dashboard itself (and the browser in it) is a hole in the layer, clicks go through there as usual
        mask: Region {
            item: catchAll
            Region { intersection: Intersection.Subtract
                     x: ((catcher.screen?.width ?? 1920) - win.width) / 2; y: 0; width: win.width; height: win.height }
        }
        Item { id: catchAll; anchors.fill: parent }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: leaveTimer.restart()
            onExited: leaveTimer.stop()
            onPressed: win.open = false
        }
        Timer { id: leaveTimer; interval: 1000; onTriggered: win.open = false }
    }
}
