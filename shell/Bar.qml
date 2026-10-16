import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import QtQml
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts

// нижняя панель в духе caelestia-kde: лежит прямо на рамке экрана.
// слева — лапка, страницы, приветствие; в центре — окна; справа — трей, часы, статусы
// bottom bar in the spirit of caelestia-kde: it sits right on the screen frame.
// left: the paw, pages, greeting; centre: windows; right: tray, clock, status icons
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Tokens.barHeight
    color: "transparent"                    // фон рисует Frame / the background is drawn by Frame

    readonly property real pct: Power.pct
    readonly property bool charging: Power.charging
    onPctChanged: if (Power.low) ShellState.caffeine = false

    IdleInhibitor { window: bar; enabled: ShellState.caffeine }
    SystemClock { id: clock; precision: ShellState.settings.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    // у каждого менеджера — свой виджет (не одна шторка, переключающая состояния)
    // every manager has its own widget (not one panel that switches states)
    readonly property var popups: ({ "": qsPanel, wifi: qsWifi, bt: qsBt, audio: qsAudio, notifs: qsNotifs, battery: qsBattery, vpn: vpnPanel })
    function openQs(item, page: string): void {
        const x = item.mapToItem(null, item.width / 2, 0).x;
        const p = popups[page];
        const wasOpen = p.visible;
        for (const k in popups) if (popups[k] !== p) popups[k].close();
        if (wasOpen) p.close(); else if (page === "vpn") p.show(x); else p.show(x, page);
    }
    function isOpen(page: string): bool { return popups[page]?.visible ?? false; }

    // кнопка системного значка: крупный значок + необязательная подпись
    // system icon button: a large icon + an optional label
    component SysBtn: Rectangle {
        id: sb
        property string icon: ""
        property string label: ""
        property color iconColor: Theme.text
        property real iconOpacity: 1
        property bool hot: false
        property bool lit: false                 // включено (например, VPN): вся кнопка цвета акцента / on (e.g. VPN): the whole button in the accent colour
        property bool customIcon: false          // значок рисуется отдельно (детьми кнопки), а не шрифтом / the icon is drawn separately (as the button's children), not with the font
        default property alias extra: sbRow.data
        signal clicked(var m)
        signal wheel(var w)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: sbRow.implicitWidth + 24
        implicitHeight: Math.min(40, Tokens.barHeight - 10)
        radius: height / 2
        color: lit ? Theme.accent : hot ? Theme.tonalHi : Theme.surface
        Behavior on color { CAnim {} }
        // смена значка — короткое «подпрыгивание», а не мгновенная подмена
        // an icon change is a short "bounce", not an instant swap
        onIconChanged: bump.restart()
        SequentialAnimation {
            id: bump
            NumberAnimation { target: sbRow; property: "scale"; to: 0.8; duration: 90; easing.type: Easing.InQuad }
            NumberAnimation { target: sbRow; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
        }
        Row {
            id: sbRow
            anchors.centerIn: parent
            spacing: 6
            Icon { visible: !sb.customIcon; anchors.verticalCenter: parent.verticalCenter; name: sb.icon; size: 22 * Tokens.iconK
                   color: sb.lit ? Theme.onAccent : sb.iconColor; opacity: sb.iconOpacity
                   Behavior on color { CAnim {} } }
            Text { visible: sb.label !== ""; anchors.verticalCenter: parent.verticalCenter
                   font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: sb.label }
        }
        StateLayer {
            radius: sb.radius
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: (m) => sb.clicked(m)
            onWheel: (w) => sb.wheel(w)
        }
    }

    // таблетка-группа на панели (чуть светлее рамки)
    // a pill group on the bar (slightly lighter than the frame)
    component Group: Rectangle {
        default property alias content: row.data
        implicitWidth: row.implicitWidth + Tokens.gap.medium * 2
        implicitHeight: 34
        radius: height / 2
        color: Theme.surface
        Behavior on implicitWidth { Anim { kind: "fastSpatial" } }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.gap.small
        }
    }

    // ПКМ по пустому месту панели — меню (как на столе) + монитор системы и блокировка
    // right-click on empty bar space: a menu (as on the desktop) + system monitor and lock
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        onClicked: (m) => barMenu.openAt(m.x, (bar.screen?.height ?? 1080) - bar.height + m.y, false)
    }
    ContextMenu { id: quickMenu; screen: bar.screen }
    function quick(item, m, items): void {
        const p = item.mapToItem(null, m.x, m.y);
        quickMenu.items = items;
        quickMenu.openAt(p.x, (bar.screen?.height ?? 1080) - bar.height + p.y, false);
    }
    ContextMenu {
        id: barMenu
        screen: bar.screen
        items: [
            { icon: "apps",      text: L.t("приложения"),        action: () => { ShellState.launcherOpen = true; } },
            { icon: "memory",    text: L.t("Монитор системы"),   action: () => { ShellState.monOpen = true; } },
            { icon: "videocam",  text: L.t("записать экран"),     action: () => ShellState.record("full") },
            { icon: "videocam",  text: L.t("записать область"),   action: () => ShellState.record("area") },
            { icon: "wallpaper", text: L.t("сменить обои"),       action: () => { ShellState.pickerOpen = true; } },
            { icon: "settings",  text: L.t("настройки"),          action: () => { ShellState.settingsOpen = true; } },
            { icon: "palette",   text: L.t("цвета: ") + Theme.p.name, action: () => ShellState.cycleAccent() },
            { icon: "lock",      text: L.t("Заблокировать"),      action: () => ShellState.lock() },
            { icon: "refresh",   text: L.t("перезапустить шелл"), action: () => Quickshell.execDetached(["sh", Quickshell.shellPath("restart.sh")]) }
        ]
    }

    // ─── левая зона ───
    // ─── left zone ───
    Row {
        id: leftZone
        anchors.left: parent.left
        anchors.leftMargin: Tokens.gap.medium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap.medium

        // лапка — меню приложений
        // the paw: app menu
        Rectangle {
            width: 34; height: 34
            radius: ShellState.launcherOpen ? 12 : 17
            anchors.verticalCenter: parent.verticalCenter
            color: ShellState.launcherOpen ? Theme.accent : Theme.tonal
            Behavior on radius { Anim { kind: "fastSpatial" } }
            Behavior on color { CAnim {} }
            Icon {
                anchors.centerIn: parent
                name: ShellState.settings.launcherIcon || "pets"; size: 15
                color: ShellState.launcherOpen ? Theme.onAccent : Theme.accent
            }
            StateLayer {
                radius: parent.radius
                onClicked: ShellState.launcherOpen = !ShellState.launcherOpen
            }
        }

        Group {
            id: tagGroup
            anchors.verticalCenter: parent.verticalCenter
            TagDots {
                monitor: bar.screen?.name ?? ""
                offY: (bar.screen?.height ?? 1080) - bar.height
                onMenuAt: (x, y, items) => { quickMenu.items = items; quickMenu.openAt(x, (bar.screen?.height ?? 1080) - bar.height + y, false); }
            }
            // значок режима текущей страницы
            // icon of the current page's layout mode
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: bar.layoutInfo[1]
                size: 13
                color: Theme.accent
            }
        }

        // процессор · видеокарта · температура; клик — подробный монитор (btop)
        // CPU · GPU · temperature; click for the detailed monitor (btop)
        Group {
            id: statsGroup
            anchors.verticalCenter: parent.verticalCenter
            Component.onCompleted: SysInfo.watchers++
            // центр цифр — чтобы монитор по Super+W вырастал прямо над ними
            // centre of the numbers, so the Super+W monitor grows right above them
            onXChanged: posLater.restart()
            onWidthChanged: posLater.restart()
            Timer { id: posLater; interval: 300; running: true
                    onTriggered: ShellState.monX = statsGroup.mapToItem(null, statsGroup.width / 2, 0).x }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "memory"; size: 13; color: Theme.accent }
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                   color: SysInfo.cpu > 0.85 ? Theme.danger : Theme.text; text: Math.round(SysInfo.cpu * 100) + "%"
                   width: statW.width; horizontalAlignment: Text.AlignRight }
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small
                   color: Theme.textDim; text: "GPU" }
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                   color: Theme.text; text: Math.round(SysInfo.gpu * 100) + "%"
                   width: statW.width; horizontalAlignment: Text.AlignRight }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "thermo"; size: 13; color: Theme.accent2 }
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                   color: SysInfo.temp > 85 ? Theme.danger : Theme.text; text: Math.round(SysInfo.temp) + "°"
                   width: statW.width; horizontalAlignment: Text.AlignRight }
            // ширина под самое длинное значение («100%»): цифры меняются, а размер — нет
            // width for the longest value ("100%"): the numbers change, the size doesn't
            TextMetrics { id: statW; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; text: "100%" }
        }

    }

    // ─── режим раскладки текущей страницы + всплывашка при смене ───
    // ─── current page's layout mode + a popup when it changes ───
    readonly property var layoutNames: ({
        "S": [L.t("лента"), "l_scroller"], "F": [L.t("сетка"), "l_grid"], "T": [L.t("мастер + стек"), "l_tile"],
        "DW": [L.t("спираль"), "l_grid"], "M": [L.t("монокль"), "fullscreen"], "G": [L.t("грид"), "l_grid"]
    })
    readonly property var activeTag: (ShellState.mangoTags[bar.screen?.name ?? ""] ?? []).find(t => t.is_active) ?? null
    readonly property var layoutInfo: layoutNames[activeTag?.layout ?? ""] ?? ["", "l_grid"]
    property string lastKey: ""
    onActiveTagChanged: {
        if (!activeTag) return;
        const key = activeTag.index + ":" + activeTag.layout;
        // показываем, только если на той же странице сменился режим
        // shown only if the mode changed on the same page
        if (lastKey && lastKey.split(":")[0] === String(activeTag.index) && lastKey !== key) {
            // берём режим прямо из activeTag: привязка layoutInfo в этот момент может ещё не пересчитаться
            // (обработчик срабатывает раньше неё) — и тост показывал прошлый режим вместо нового
            // take the mode straight from activeTag: the layoutInfo binding may not have updated yet at this point
            // (the handler runs before it), and the toast showed the previous mode instead of the new one
            toastInfo = layoutNames[activeTag.layout] ?? ["", "l_grid"];
            toastOn = true;
            toastTimer.restart();
        }
        lastKey = key;
    }
    property bool toastOn: false
    Timer { id: toastTimer; interval: 1400; onTriggered: bar.toastOn = false }
    property var toastInfo: ["", "l_grid"]
    PopupWindow {
        id: layoutToast
        // окно живёт, пока идёт анимация исчезновения
        // the window lives while the fade-out animation runs
        visible: bar.toastOn || toastCard.opacity > 0.01
        anchor.item: tagGroup
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        implicitWidth: 240                              // постоянная ширина: окно не дёргается при частой смене / fixed width: the window doesn't jump on frequent changes
        implicitHeight: 52
        color: "transparent"
        Rectangle {
            id: toastCard
            anchors.fill: parent
            anchors.bottomMargin: 10
            radius: height / 2
            color: Theme.frame
            border.color: Theme.outline
            // 80% непрозрачности — не заслоняет то, что под ним; выезжает снизу и тает
            // 80% opacity so it doesn't hide what's under it; slides up from below and fades
            opacity: bar.toastOn ? 0.8 : 0
            scale: bar.toastOn ? 1 : 0.9
            transform: Translate { y: bar.toastOn ? 0 : 10; Behavior on y { Anim { kind: "fastSpatial" } } }
            Behavior on opacity { Anim { kind: "effects" } }
            Behavior on scale { Anim { kind: "fastSpatial" } }
            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 10
                Icon { anchors.verticalCenter: parent.verticalCenter; name: bar.toastInfo[1]; size: 18; color: Theme.accent }
                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                       font.pixelSize: Tokens.font.normal; font.bold: true; color: Theme.text
                       text: L.t("режим: ") + bar.toastInfo[0] }
            }
        }
    }

    // ─── панель задач: всё место между приветствием и треем, прижата к левому краю ───
    // окна одного приложения — под одним значком; закреплённые идут первыми
    // ─── taskbar: all the space between the greeting and the tray, aligned left ───
    // windows of one app go under one icon; pinned ones come first
    readonly property var taskGroups: {
        const map = {}, order = [];
        for (const t of ToplevelManager.toplevels.values) {
            if (t.parent) continue;                       // диалоги не показываем / dialogs are not shown
            if (t.appId === "nyash-browser") continue;    // браузер из борда живёт в борде / the dashboard browser lives in the dashboard
            const k = t.appId || t.title || "?";
            if (!map[k]) { map[k] = []; order.push(k); }
            map[k].push(t);
        }
        // закреплённый значок и окно этого приложения часто называются по-разному
        // (ярлык «factorio», окно «steam_app_427520»; ярлык «org.telegram.desktop», окно «TelegramDesktop»).
        // окна, которые относятся к закреплённому ярлыку, кладём под него, а не отдельной кнопкой
        // a pinned icon and that app's window are often named differently
        // (shortcut "factorio", window "steam_app_427520"; shortcut "org.telegram.desktop", window "TelegramDesktop").
        // windows that belong to a pinned shortcut go under it rather than as a separate button
        const pins = ShellState.pinned, used = {};
        const pinWins = pins.map(p => {
            const w = (map[p] ?? []).slice(); used[p] = true;
            for (const k of order) if (!used[k] && bar.pinMatches(p, k)) { w.push(...map[k]); used[k] = true; }
            return { appId: p, windows: w, pinned: true };
        });
        return pinWins.concat(order.filter(k => !used[k]).map(k => ({ appId: k, windows: map[k], pinned: false })));
    }
    function pinMatches(pin: string, appId: string): bool {
        const a = appId.toLowerCase(), p = pin.toLowerCase();
        if (a === p) return true;
        const e = DesktopEntries.byId(pin) ?? DesktopEntries.applications.values.find(x => x.id.toLowerCase() === p);
        if (!e) return p.split(".").pop() === a;
        if ((e.startupClass || "").toLowerCase() === a) return true;
        // игры Steam: окно steam_app_<номер>, ярлык запускает steam://rungameid/<номер>
        // Steam games: the window is steam_app_<id>, the shortcut runs steam://rungameid/<id>
        const g = a.match(/^steam_app_(\d+)$/);
        if (g && (e.execString || "").includes("rungameid/" + g[1])) return true;
        const flat = (x) => x.toLowerCase().replace(/[\s._-]+/g, "");
        return flat(e.name) === flat(appId) || flat(e.id.split(".").pop()) === flat(appId);
    }
    Item {
        anchors.left: leftZone.right
        anchors.leftMargin: Tokens.gap.large
        anchors.right: rightZone.left
        anchors.rightMargin: Tokens.gap.large
        height: parent.height
        clip: true
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: bar.taskGroups
                delegate: TaskApp { barScreen: bar.screen; barHeight: bar.height }
            }
        }
    }

    // ─── идёт запись экрана: красная таблетка с таймером слева от правой зоны, клик — остановить ───
    // ─── screen recording in progress: a red pill with a timer left of the right zone, click to stop ───
    Rectangle {
        id: recPill
        visible: ShellState.recording
        anchors.right: rightZone.left; anchors.rightMargin: Tokens.gap.small
        anchors.verticalCenter: parent.verticalCenter
        width: recRow.implicitWidth + 24; height: 32; radius: 16
        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18)
        property int secs: 0
        Timer { interval: 1000; repeat: true; running: recPill.visible; triggeredOnStart: true
                onTriggered: recPill.secs = Math.floor((Date.now() - ShellState.recSince) / 1000) }
        Row {
            id: recRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 10; height: 10; radius: 5; color: Theme.danger; anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity { running: recPill.visible; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                   color: Theme.danger; text: Math.floor(recPill.secs / 60) + ":" + String(recPill.secs % 60).padStart(2, "0") }
        }
        StateLayer { radius: 16; onClicked: ShellState.stopRecording() }
    }

    // ─── правая зона ───
    // порядок значков задаётся в настройках (Look → Bar order); позиции считаются здесь,
    // скрытые значки (например, bluetooth без адаптера) места не занимают
    // ─── right zone ───
    // the icon order is set in the settings (Look → Bar order); positions are computed here,
    // hidden icons (e.g. bluetooth without an adapter) take no space
    Item {
        id: rightZone
        anchors.right: parent.right
        anchors.rightMargin: Tokens.gap.medium
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        readonly property var order: {
            const o = (ShellState.settings.trayOrder ?? ["tray", "kb", "battery", "audio", "bt", "wifi", "vpn", "clock", "notifs"]).slice();
            if (!o.includes("vpn")) o.splice(Math.max(0, o.indexOf("wifi") + 1), 0, "vpn");
            return o;
        }
        readonly property var items: ({ tray: tray, kb: kbg, battery: batBtn, audio: volBtn, bt: btBtn, wifi: wifiBtn, vpn: vpnBtn, clock: clk, notifs: notifBtn })
        readonly property real gap: Tokens.gap.small
        readonly property var pos: {
            let x = 0; const p = {};
            for (const k of order) {
                const it = items[k];
                if (!it || !it.visible) continue;
                // зазор растёт вместе со значком — когда значок плавно появляется/исчезает, соседи не прыгают
                // the gap grows with the icon, so neighbours don't jump while an icon fades in/out
                p[k] = x; x += it.width + gap * Math.min(1, it.width / 16);
            }
            p.__w = Math.max(0, x - gap);
            return p;
        }
        width: pos.__w
        // значки, которые спрятали в настройках (галочка-глаз в «Порядок значков на панели»)
        // icons hidden in the settings (the eye toggle in "Bar icon order")
        readonly property var hidden: ShellState.settings.trayHidden ?? []
        Instantiator {
            model: Object.keys(rightZone.items)
            delegate: Binding {
                required property string modelData
                target: rightZone.items[modelData]
                property: "visible"
                value: false
                when: rightZone.hidden.includes(modelData)
            }
        }

        // трей фоновых приложений: стрелка на месте, список выезжает влево на общей подложке
        // tray of background apps: the arrow stays put, the list slides out to the left on a shared backing
        Item {
            id: tray
            x: rightZone.pos["tray"] ?? 0
            property bool open: false
            // появление и исчезновение — плавно: k — «насколько трей есть» (0…1), o — насколько раскрыт,
            // rowW — сглаженная ширина списка (значки приходят и уходят по одному)
            // appearing and disappearing are smooth: k is "how present the tray is" (0…1), o is how open it is,
            // rowW is the smoothed list width (icons come and go one at a time)
            readonly property bool has: SystemTray.items.values.length > 0
            // появляется — с лёгкой «пружиной», исчезает — без неё: пружина у нуля уводила размер в минус,
            // и кнопка на миг выворачивалась
            // appears with a slight spring, disappears without one: a spring near zero pushed the size below zero
            // and the button turned inside out for a moment
            property real k: has ? 1 : 0
            Behavior on k { Anim { kind: tray.has ? "slowSpatial" : "emphasized"; duration: tray.has ? Tokens.dur.slowSpatial : 550 } }
            property real o: open ? 1 : 0
            Behavior on o { Anim { kind: "slowSpatial" } }
            property real rowW: trayRow.contentWidth
            Behavior on rowW { Anim { kind: "slowSpatial" } }
            onHasChanged: if (!has) open = false
            readonly property real fullW: Math.max(0, o) * (rowW + 6) + 40
            visible: k > 0.01
            anchors.verticalCenter: parent.verticalCenter
            // место на панели сжимается вместе с кнопкой, а сама кнопка уменьшается целиком (scale),
            // а не сплющивается по ширине — так она одинаково красиво уходит и свёрнутой, и раскрытой
            // the room on the bar shrinks with the button, and the button itself scales down as a whole
            // rather than being squashed in width, so it leaves nicely both collapsed and expanded
            width: fullW * Math.max(0, k)
            height: 40

            Item {
            id: trayBody
            anchors.centerIn: parent
            width: tray.fullW; height: 40
            scale: Math.max(0, tray.k)
            opacity: Math.min(1, Math.max(0, tray.k))
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: tray.open ? Theme.tonal : Theme.surface
                Behavior on color { CAnim {} }
            }
            Item {
                x: 4
                width: trayBody.width - 44
                height: parent.height
                clip: true
                // список, а не Repeater: у него есть переходы — значок приложения появляется и исчезает
                // анимацией, а соседи плавно сдвигаются
                // a list rather than a Repeater: it has transitions, so an app's icon appears and disappears
                // with an animation and the neighbours slide over smoothly
                ListView {
                    id: trayRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: contentWidth; height: 34
                    orientation: ListView.Horizontal
                    interactive: false
                    spacing: 2
                    model: SystemTray.items
                    add: Transition { ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 380 }
                        NumberAnimation { property: "scale"; from: 0.4; to: 1; duration: 520; easing.type: Easing.OutBack } } }
                    remove: Transition { ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 340 }
                        NumberAnimation { property: "scale"; to: 0.4; duration: 400; easing.type: Easing.InCubic } } }
                    displaced: Transition { NumberAnimation { property: "x"; duration: 460; easing.type: Easing.OutCubic } }
                        delegate: Item {
                            id: trayItem
                            required property var modelData
                            width: 34; height: 34
                            IconImage { anchors.centerIn: parent; implicitSize: 22; source: trayItem.modelData.icon }
                            StateLayer {
                                radius: 15
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                onClicked: (m) => {
                                    const it = trayItem.modelData;
                                    if (m.button === Qt.MiddleButton) it.secondaryActivate();
                                    else if (m.button === Qt.LeftButton && !it.onlyMenu) it.activate();
                                    else if (it.hasMenu) {
                                        // меню приложения — нашим стилем, над значком
                                        // the app's menu in our style, above the icon
                                        const p = trayItem.mapToItem(null, trayItem.width / 2, 0);
                                        trayMenu.openFor(it.menu, p.x, (bar.screen?.height ?? 1080) - bar.height + p.y, it.id || "", it.title || "");
                                    }
                                }
                            }
                        }
                }
            }
            // стрелка всегда справа
            // the arrow is always on the right
            Item {
                anchors.right: parent.right
                width: 40; height: 40
                // стрелка нарисована линиями и крутится вокруг своего центра — не «подпрыгивает»
                // the arrow is drawn with lines and rotates around its centre, so it doesn't "jump"
                Shape {
                    anchors.centerIn: parent
                    width: 10; height: 14
                    rotation: tray.open ? 180 : 0
                    Behavior on rotation { Anim { kind: "fastSpatial" } }
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: tray.open ? Theme.accent : Theme.text
                        strokeWidth: 2
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 7.5; startY: 2
                        PathLine { x: 2.5; y: 7 }
                        PathLine { x: 7.5; y: 12 }
                    }
                }
                StateLayer { radius: 20; onClicked: tray.open = !tray.open }
            }
            }
        }

        // раскладка: клик — переключить
        // keyboard layout: click to switch
        Group {
            id: kbg
            x: rightZone.pos["kb"] ?? 0
            anchors.verticalCenter: parent.verticalCenter
            visible: KbLayout.short !== ""
            Text {
                font.family: Theme.font
                anchors.verticalCenter: parent.verticalCenter
                text: KbLayout.short
                color: Theme.accent
                font.pixelSize: Tokens.font.larger
                font.bold: true
            }
        }

        // батарея: рисованная, с молнией при зарядке
        // battery: drawn by hand, with a bolt while charging
        Rectangle {
            id: batBtn
            x: rightZone.pos["battery"] ?? 0
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: batRow.implicitWidth + 24
            implicitHeight: 40
            radius: 20
            color: bar.isOpen("battery") ? Theme.tonalHi : Theme.surface
            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: 6
                Item {
                    width: 26; height: 13
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 23; height: 13; radius: 4
                        color: "transparent"
                        border.width: 1.5
                        border.color: bar.pct < 20 && !bar.charging ? Theme.danger : Theme.textDim
                        Rectangle {
                            visible: Power.present
                            x: 2.5; y: 2.5; height: parent.height - 5; radius: 2
                            width: Math.max(2, (parent.width - 5) * bar.pct / 100)
                            color: bar.charging ? Theme.accent : bar.pct < 20 ? Theme.danger : Theme.text
                            Behavior on width { Anim { kind: "effects" } }
                        }
                        Shape {
                            visible: bar.charging
                            anchors.centerIn: parent
                            width: 8; height: 11
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: Theme.frame
                                strokeColor: Theme.accent
                                strokeWidth: 1
                                joinStyle: ShapePath.RoundJoin
                                startX: 5; startY: 0
                                PathLine { x: 0; y: 6.2 }
                                PathLine { x: 3.6; y: 6.2 }
                                PathLine { x: 2.8; y: 11 }
                                PathLine { x: 8; y: 4.6 }
                                PathLine { x: 4.4; y: 4.6 }
                                PathLine { x: 5; y: 0 }
                            }
                        }
                        // ПК без батареи: внутри пустой батарейки — вилка
                        // PC without a battery: a plug inside an empty battery
                        PlugIcon {
                            visible: !Power.present
                            anchors.centerIn: parent
                            width: 15
                            color: ShellState.caffeine ? Theme.accent : Theme.text
                        }
                        Icon {
                            visible: Power.present && !bar.charging && ShellState.caffeine
                            anchors.centerIn: parent
                            name: "eye"; size: 9; opticalSize: false
                            color: Theme.frame
                        }
                    }
                    Rectangle { x: 23.5; y: 4; width: 2.5; height: 5; radius: 1
                                color: bar.pct < 20 && !bar.charging ? Theme.danger : Theme.textDim }
                }
                Text {
                    visible: Power.present
                    font.family: Theme.font
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(bar.pct) + "%"
                    color: bar.pct < 20 && !bar.charging ? Theme.danger : Theme.text
                    font.pixelSize: Tokens.font.smaller
                }
            }
            StateLayer {
                radius: 20
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => m.button === Qt.RightButton
                    ? bar.quick(batBtn, m, Power.profiles.map(p => ({ icon: "bolt",
                            text: ({ "power-saver": L.t("экономия"), "balanced": L.t("баланс"), "performance": L.t("мощность") })[p] ?? p,
                            checked: Power.profile === p, action: () => Power.setProfile(p) }))
                        .concat([{ separator: true },
                                 { icon: "eye", text: L.t("Не гасить"), checked: ShellState.caffeine, action: () => { ShellState.caffeine = !ShellState.caffeine; } },
                                 { icon: "settings", text: Power.present ? L.t("менеджер батареи") : L.t("менеджер питания"), action: () => bar.openQs(batBtn, "battery") }]))
                    : bar.openQs(batBtn, "battery")
            }
        }
        SysBtn {
            id: volBtn
            x: rightZone.pos["audio"] ?? 0
            icon: Audio.icon()
            label: Math.round((Audio.muted ? 0 : Audio.volume) * 100) + "%"
            iconColor: Audio.muted ? Theme.textDim : Theme.text
            hot: bar.isOpen("audio")
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) Audio.toggleMute();
                else if (m.button === Qt.RightButton)
                    bar.quick(volBtn, m, [{ icon: Audio.muted ? "vol_up" : "vol_off", text: Audio.muted ? L.t("включить звук") : L.t("выключить звук"),
                                            action: () => Audio.toggleMute() }, { separator: true }]
                        .concat(Audio.outputs.map(o => ({ icon: "headphones", text: o.description || o.nickname || o.name,
                                                          checked: o === Audio.sink, action: () => Audio.use(o) })))
                        .concat([{ separator: true }, { icon: "settings", text: L.t("менеджер звука"), action: () => bar.openQs(volBtn, "audio") }]));
                else bar.openQs(volBtn, "audio");
            }
            onWheel: (w) => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
        }
        SysBtn {
            id: btBtn
            x: rightZone.pos["bt"] ?? 0
            visible: Bt.present
            icon: "bluetooth"
            iconColor: Bt.connected.length ? Theme.accent : Theme.text
            iconOpacity: Bt.powered ? 1 : 0.4
            hot: bar.isOpen("bt")
            onClicked: (m) => m.button === Qt.RightButton
                ? bar.quick(btBtn, m, [
                    { icon: "bluetooth", text: Bt.powered ? L.t("выключить Bluetooth") : L.t("включить Bluetooth"), action: () => Bt.toggle() },
                    { icon: "plus", text: L.t("искать устройства"), enabled: Bt.powered, action: () => { Bt.scan(); bar.openQs(btBtn, "bt"); } },
                    { separator: true },
                    { icon: "settings", text: L.t("менеджер Bluetooth"), action: () => bar.openQs(btBtn, "bt") }])
                : bar.openQs(btBtn, "bt")
        }
        // VPN: ключ — ярче, когда подключено; ПКМ — быстрое меню
        // VPN: the key is brighter when connected; right-click for a quick menu
        SysBtn {
            id: vpnBtn
            x: rightZone.pos["vpn"] ?? 0
            visible: ShellState.settings.vpnEnabled ?? true
            customIcon: true
            lit: Vpn.running                       // подключено — вся кнопка цвета акцента / connected: the whole button in the accent colour
            hot: bar.isOpen("vpn")
            KeyIcon { anchors.verticalCenter: parent.verticalCenter; size: 22 * Tokens.iconK
                      color: Vpn.running ? Theme.onAccent : Theme.text
                      Behavior on color { CAnim {} } }
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) Vpn.toggle();
                else if (m.button === Qt.RightButton)
                    bar.quick(vpnBtn, m, [
                        { icon: "key", text: Vpn.running ? L.t("отключить VPN") : L.t("подключить VPN"), enabled: !!Vpn.node || Vpn.running, action: () => Vpn.toggle() },
                        { icon: "public", text: "TUN", checked: Vpn.tun, action: () => Vpn.setTun(!Vpn.tun) },
                        { icon: "refresh", text: L.t("подключаться при входе"), checked: Vpn.autoConnect, action: () => Vpn.setAuto(!Vpn.autoConnect) },
                        { separator: true },
                        { icon: "settings", text: L.t("менеджер VPN"), action: () => bar.openQs(vpnBtn, "vpn") }]);
                else bar.openQs(vpnBtn, "vpn");
            }
        }
        // системные значки — каждый отдельной кнопкой и открывает свой менеджер
        // system icons: each is its own button and opens its own manager
        SysBtn {
            id: wifiBtn
            x: rightZone.pos["wifi"] ?? 0
            // по проводу (кабель, USB-модем, мобильная сеть) — свой значок; Wi-Fi — как обычно
            // wired (cable, USB modem, mobile network) has its own icon; Wi-Fi as usual
            readonly property var w: Net.wiredUp
            icon: w ? (w.kind === "usb" ? "usb" : w.kind === "gsm" ? "cell" : "ethernet") : "wifi"
            iconColor: (w || Net.current) ? Theme.text : Theme.textDim
            iconOpacity: w ? 1 : !Net.enabled ? 0.4 : Net.current ? 0.45 + 0.55 * Net.current.signal / 100 : 0.6
            hot: bar.isOpen("wifi")
            onClicked: (m) => m.button === Qt.RightButton
                ? bar.quick(wifiBtn, m, [
                    { icon: "wifi", text: Net.enabled ? L.t("выключить Wi-Fi") : L.t("включить Wi-Fi"), action: () => Net.toggle() },
                    { icon: "refresh", text: L.t("обновить сети"), action: () => Net.refresh(true) },
                    { separator: true },
                    { icon: "settings", text: L.t("менеджер Wi-Fi"), action: () => bar.openQs(wifiBtn, "wifi") }])
                : bar.openQs(wifiBtn, "wifi")
        }
        // часы: клик — общая шторка быстрых настроек
        // clock: click for the shared quick settings panel
        Group {
            id: clk
            x: rightZone.pos["clock"] ?? 0
            anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "calendar"; size: 12; color: Theme.accent }
            Text {
                font.family: Theme.font
                anchors.verticalCenter: parent.verticalCenter
                // формат часов — из настроек: 24/12 часов и секунды
                // clock format from the settings: 24/12 hours and seconds
                text: Qt.formatDateTime(clock.date, (ShellState.settings.clock24 ?? true ? "HH : mm" : "h : mm")
                                        + (ShellState.settings.clockSeconds ? " : ss" : "")
                                        + (ShellState.settings.clock24 ?? true ? "" : " AP"))
                color: Theme.text
                font.pixelSize: Tokens.font.normal
                font.bold: true
            }
        }

        SysBtn {
            id: notifBtn
            x: rightZone.pos["notifs"] ?? 0
            icon: Notifs.dnd ? "bell_off" : "bell"
            label: Notifs.unread > 0 ? String(Notifs.unread) : ""
            iconColor: Notifs.dnd ? Theme.textDim : Notifs.unread ? Theme.accent : Theme.text
            hot: bar.isOpen("notifs")
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) Notifs.dnd = !Notifs.dnd;
                else if (m.button === Qt.RightButton)
                    bar.quick(notifBtn, m, [
                        { icon: Notifs.dnd ? "bell" : "bell_off", text: Notifs.dnd ? L.t("выключить «не беспокоить»") : L.t("не беспокоить"),
                          action: () => { Notifs.dnd = !Notifs.dnd; } },
                        { icon: "close", text: L.t("очистить все"), enabled: Notifs.history.length > 0, danger: true, action: () => Notifs.clearAll() },
                        { separator: true },
                        { icon: "settings", text: L.t("менеджер уведомлений"), action: () => bar.openQs(notifBtn, "notifs") }]);
                else bar.openQs(notifBtn, "notifs");
            }
        }
    }

    component Qs: QuickSettings {
        screen: bar.screen
        batteryPct: bar.pct
        charging: bar.charging
        barHeight: bar.height
    }
    Qs { id: qsPanel; onRequestPage: (pg) => { const x = qsPanel.px; qsPanel.close(); bar.popups[pg].show(x, pg); } }
    Qs { id: qsWifi; fixedPage: "wifi" }
    Qs { id: qsBt; fixedPage: "bt" }
    Qs { id: qsAudio; fixedPage: "audio" }
    Qs { id: qsNotifs; fixedPage: "notifs"; dock: "right" }
    VpnPanel { id: vpnPanel; screen: bar.screen; barHeight: bar.height }
    Qs { id: qsBattery; fixedPage: "battery" }
    StateLayer {
        parent: kbg
        radius: kbg.radius
        onClicked: KbLayout.next()
    }
    StateLayer {
        parent: clk
        radius: clk.radius
        onClicked: bar.openQs(clk, "")
    }
    StateLayer {
        parent: statsGroup
        radius: statsGroup.radius
        onClicked: {
            ShellState.monX = statsGroup.mapToItem(null, statsGroup.width / 2, 0).x;
            ShellState.monOpen = !ShellState.monOpen;
        }
    }
    TrayMenu { id: trayMenu; screen: bar.screen }
}
