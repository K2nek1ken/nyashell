import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick

// значок приложения на панели: все его окна под одним значком.
// ЛКМ — свернуть лишнее / развернуть самое используемое, СКМ — новое окно, ПКМ — меню,
// колесо — громкость приложения, наведение — превью всех окон с крестиками и громкостью
// an app icon on the bar: all its windows under one icon.
// left click minimises the extras / restores the most used one, middle click opens a new window, right click a menu,
// wheel sets the app's volume, hovering previews all windows with close buttons and volume
Item {
    id: root
    required property var modelData          // { appId, windows, pinned }
    property var barScreen: null
    property real barHeight: 54
    readonly property string appId: modelData.appId
    readonly property var windows: modelData.windows
    readonly property bool pinned: modelData.pinned
    // ярлык приложения: по id, потом эвристикой Quickshell, потом сами — по классу окна,
    // имени или части id (окно DeltaChat называет себя иначе, чем его ярлык)
    // the app's shortcut: by id, then by Quickshell's heuristic, then ourselves by window class,
    // name or part of the id (the DeltaChat window names itself differently from its shortcut)
    readonly property var entry: {
        const a = appId, low = a.toLowerCase();
        const e = DesktopEntries.byId(a) ?? DesktopEntries.byId(low) ?? (DesktopEntries.heuristicLookup?.(a) ?? null);
        if (e) return e;
        const all = DesktopEntries.applications.values;
        return all.find(x => (x.startupClass || "").toLowerCase() === low)
            ?? all.find(x => x.name.toLowerCase().replace(/\s+/g, "") === low.replace(/[\s._-]+/g, ""))
            ?? all.find(x => x.id.toLowerCase().includes(low) || low.includes(x.id.toLowerCase().split(".").pop()))
            ?? null;
    }
    readonly property bool running: windows.length > 0
    readonly property bool active: windows.some(w => w.activated && !w.minimized)
    readonly property var stream: Audio.streamFor(appId)

    width: 46
    height: 40
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.tonalHi : (mouse.containsMouse ? Theme.hover : "transparent")
        Behavior on color { CAnim {} }
    }
    AppIcon {
        anchors.centerIn: parent
        size: 28 * Tokens.iconK
        icon: root.entry?.icon ?? root.appId
        opacity: root.running ? (root.windows.every(w => w.minimized) ? 0.5 : 1) : 0.55
        scale: mouse.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
    }
    // точки под значком: сколько окон (до трёх)
    // dots under the icon: how many windows (up to three)
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3
        Repeater {
            model: Math.min(root.windows.length, 3)
            delegate: Rectangle { width: root.active ? 8 : 4; height: 3; radius: 1.5
                                  color: root.active ? Theme.accent : Theme.textDim
                                  Behavior on width { Anim { kind: "fastSpatial" } } }
        }
    }

    function launch(): void { if (entry) entry.execute(); }
    // ЛКМ, если окон несколько:
    //   приложение в фокусе и видно несколько окон → остаётся самое используемое, остальные сворачиваются;
    //   видно одно окно и оно в фокусе → сворачивается;
    //   приложение не в фокусе → разворачивается и получает фокус самое используемое.
    // «используемое» = больше всего времени в фокусе за последние минуты (см. Usage.qml).
    // конкретное окно — через превью при наведении
    // left click with several windows:
    // the app is focused and several windows are visible → the most used one stays, the rest are minimised;
    // one window is visible and focused → it is minimised;
    // the app isn't focused → the most used one is restored and focused.
    // "most used" = the most time in focus over the last few minutes (see Usage.qml).
    // a specific window: via the hover preview
    function primary(): void {
        if (!running) { launch(); return; }
        const shown = windows.filter(w => !w.minimized);
        const best = Usage.mostUsed(windows) ?? windows[0];
        if (active && shown.length > 1) {
            const keep = Usage.mostUsed(shown) ?? shown[0];
            for (const w of shown) if (w !== keep) w.minimized = true;
            keep.activate();
            return;
        }
        if (active) { for (const w of shown) w.minimized = true; return; }
        best.minimized = false;
        best.activate();
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onContainsMouseChanged: {
            if (containsMouse && root.running) { hideTimer.stop(); showTimer.restart(); }
            else { showTimer.stop(); hideTimer.restart(); }
        }
        onWheel: (w) => { if (root.stream) Audio.setNodeVolume(root.stream, (root.stream.audio?.volume ?? 0) + (w.angleDelta.y > 0 ? 0.05 : -0.05)); }
        onClicked: (m) => {
            preview.visible = false;
            showTimer.stop();
            if (m.button === Qt.MiddleButton) root.launch();
            else if (m.button === Qt.RightButton) {
                const p = root.mapToItem(null, m.x, m.y);
                menu.openAt(p.x, (root.barScreen ? root.barScreen.height : 1080) - root.barHeight + p.y, false);
            } else root.primary();
        }
    }

    ContextMenu {
        id: menu
        screen: root.barScreen
        items: [
            { icon: "pin", text: root.pinned ? L.t("открепить") : L.t("закрепить на панели"), action: () => ShellState.togglePin(root.appId) },
            { icon: "plus", text: L.t("новое окно"), action: () => root.launch() }
        ].concat(root.windows.length === 1 ? [
            { icon: root.windows[0].minimized ? "open_in_browser" : "minimize",
              text: root.windows[0].minimized ? L.t("развернуть") : L.t("свернуть"), action: () => root.primary() },
            { icon: "fullscreen", text: root.windows[0].fullscreen ? L.t("выйти из полноэкранного") : L.t("на весь экран"),
              action: () => { root.windows[0].fullscreen = !root.windows[0].fullscreen; } }
        ] : []).concat(root.running ? [
            { icon: "close", text: root.windows.length > 1 ? L.t("закрыть все окна") : L.t("закрыть"), danger: true,
              action: () => root.windows.slice().forEach(w => w.close()) }
        ] : []).concat(root.running ? [
            { icon: "bin", text: L.t("завершить приложение"), danger: true, action: () => {
                for (const w of root.windows) {
                    const c = ShellState.mangoClients.find(x => x.appid === root.appId && x.title === w.title) ?? ShellState.mangoClients.find(x => x.appid === root.appId);
                    if (c && c.pid > 0) { Quickshell.execDetached(["sh", Quickshell.shellPath("kill-app.sh"), String(c.pid)]); break; }
                }
            } }
        ] : [])
    }

    Timer { id: showTimer; interval: 400; onTriggered: preview.visible = true }
    Timer { id: hideTimer; interval: 220; onTriggered: if (!mouse.containsMouse && !cardHover.hovered) preview.visible = false }

    // превью всех окон приложения
    // preview of all the app's windows
    PopupWindow {
        id: preview
        visible: false
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        readonly property int n: Math.max(1, Math.min(root.windows.length, 4))
        implicitWidth: n * 248 + (n - 1) * 8 + 20
        implicitHeight: 196 + (root.stream ? 40 : 0)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 10
            radius: Tokens.rounding.extraLarge
            color: Theme.bg
            border.color: Theme.outline
            opacity: preview.visible ? 1 : 0
            Behavior on opacity { Anim { kind: "effects" } }
            HoverHandler { id: cardHover; onHoveredChanged: if (!hovered) hideTimer.restart() }

            Row {
                x: 10; y: 10
                spacing: 8
                Repeater {
                    model: root.windows.slice(0, 4)
                    delegate: Rectangle {
                        id: wcard
                        required property var modelData
                        width: 248; height: 166
                        radius: Tokens.rounding.large
                        color: wm.containsMouse ? Theme.surfaceHi : Theme.surface
                        border.color: modelData.activated ? Theme.accent : "transparent"
                        Text {
                            x: 10; y: 8
                            width: parent.width - 44
                            elide: Text.ElideRight
                            font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                            text: wcard.modelData.title || root.appId
                        }
                        Item {
                            id: pv
                            x: 8; y: 30
                            width: parent.width - 16; height: parent.height - 38
                            ScreencopyView {
                                id: shot
                                anchors.centerIn: parent
                                captureSource: preview.visible ? wcard.modelData : null
                                live: true
                                constraintSize: Qt.size(parent.width, parent.height)
                            }
                            // Quickshell снимает отдельные окна только по протоколу Hyprland — на mango ScreencopyView пуст.
                            // Поэтому снимок окна берём через grim -T (ext-image-copy-capture: mango его поддерживает) —
                            // по id окна из mango (foreign_toplevel_id), раз в ~1 с, только пока превью открыто
                            // Quickshell captures single windows only via Hyprland's protocol, so on mango ScreencopyView is empty.
                            // We grab the window with grim -T instead (ext-image-copy-capture, which mango supports), by the
                            // window's mango id (foreign_toplevel_id), about once a second and only while the preview is open
                            // окно mango для этого окна панели: по программе (без учёта регистра) и заголовку; если
                            // заголовок не совпал — первое окно этой программы, которое ещё не занято другой карточкой
                            // the mango window for this taskbar window: by app (case-insensitive) and title; if no title
                            // matches, the app's first window
                            readonly property var mc: {
                                const t = wcard.modelData, a = String(t.appId || "").toLowerCase();
                                const same = ShellState.mangoClients.filter(c => String(c.appid || "").toLowerCase() === a);
                                return same.find(c => c.title === t.title) ?? same[0] ?? null;
                            }
                            readonly property string snapBase: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nyash-preview-" + (mc?.foreign_toplevel_id ?? "x")
                            // два кадра по очереди: новый снимок грузится в спрятанный, а пока грузится — виден прежний.
                            // Показываем новый только когда он готов, так превью обновляется без мигания значка
                            // two frames in turn: a new shot loads into the hidden one while the old one stays visible.
                            // The new one is shown only once it's ready, so the preview updates without the icon flashing
                            property int flip: 0              // какой кадр сейчас показан / which frame is shown
                            property int loading: -1          // какой кадр грузится / which frame is loading
                            readonly property bool hasShot: (flip === 0 ? snapA : snapB).status === Image.Ready
                            Process {
                                id: grab
                                // без -s: уменьшаем при показе (sourceSize), так надёжнее. Ошибки — в ~/.cache/nyashell/preview.log
                                // no -s: the image is scaled down when shown (sourceSize), more reliable. Errors go to ~/.cache/nyashell/preview.log
                                command: ["sh", "-c", 'grim -T "$1" "$2.tmp.png" 2>"$2.err" && mv -f "$2.tmp.png" "$2" || ' +
                                          '{ mkdir -p "$HOME/.cache/nyashell"; printf "%s id=%s %s\\n" "$(date +%T)" "$1" "$(cat "$2.err")" >> "$HOME/.cache/nyashell/preview.log"; exit 1; }',
                                          "sh", pv.mc?.foreign_toplevel_id ?? "", pv.snapBase + "-" + (1 - pv.flip) + ".png"]
                                onExited: (code) => {
                                    if (code !== 0) return;
                                    const k = 1 - pv.flip;
                                    pv.loading = k;
                                    // меняем строку источника (#время), чтобы картинка перечиталась с диска
                                    // change the source string (#time) so the image is reread from disk
                                    (k === 0 ? snapA : snapB).source = "file://" + pv.snapBase + "-" + k + ".png#" + Date.now();
                                }
                            }
                            Timer {
                                running: preview.visible && !shot.hasContent && !!pv.mc && !wcard.modelData.minimized
                                interval: 1200; repeat: true; triggeredOnStart: true
                                onTriggered: if (!grab.running && pv.loading < 0) grab.running = true
                            }
                            // скруглённые углы, как у остальных карточек: маска ровно по нарисованной картинке,
                            // оба кадра лежат внутри неё (виден только текущий)
                            // rounded corners like the other cards: the clip matches the painted image exactly,
                            // both frames sit inside it (only the current one is visible)
                            component Snap: Image {
                                required property int slot
                                x: -pclip.x; y: -pclip.y
                                width: pv.width; height: pv.height
                                visible: pv.flip === slot
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                smooth: true; mipmap: true
                                sourceSize.width: 480
                                onStatusChanged: {
                                    if (pv.loading !== slot) return;
                                    if (status === Image.Ready) { pv.flip = slot; pv.loading = -1; }
                                    else if (status === Image.Error) pv.loading = -1;
                                }
                            }
                            ClippingRectangle {
                                id: pclip
                                readonly property var img: pv.flip === 0 ? snapA : snapB
                                opacity: !shot.hasContent && pv.hasShot ? 1 : 0
                                x: (pv.width - img.paintedWidth) / 2; y: (pv.height - img.paintedHeight) / 2
                                width: img.paintedWidth; height: img.paintedHeight
                                radius: Tokens.rounding.medium
                                color: "transparent"
                                Snap { id: snapA; slot: 0 }
                                Snap { id: snapB; slot: 1 }
                            }
                            // если и так картинки нет (окно свёрнуто, нет grim) — крупный значок приложения
                            // if there's still no image (window minimised, no grim): a large app icon
                            Column {
                                visible: !shot.hasContent && !pv.hasShot
                                anchors.centerIn: parent
                                spacing: 8
                                IconImage { anchors.horizontalCenter: parent.horizontalCenter; implicitSize: 56
                                            source: Quickshell.iconPath(root.entry?.icon ?? root.appId, "application-x-executable") }
                                Text { anchors.horizontalCenter: parent.horizontalCenter
                                       font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                                       text: wcard.modelData.minimized ? L.t("свёрнуто") : "" }
                            }
                        }
                        MouseArea {
                            id: wm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { preview.visible = false; wcard.modelData.minimized = false; wcard.modelData.activate(); }
                        }
                        // крестик окна — в правом верхнем углу, как у обычного окна
                        // the window's close button: in the top-right corner, like a normal window
                        Rectangle {
                            x: parent.width - 30; y: 4
                            width: 26; height: 26; radius: 13
                            color: xm.containsMouse ? Theme.danger : "transparent"
                            Icon { anchors.centerIn: parent; name: "close"; size: 11
                                   color: xm.containsMouse ? Theme.onAccent : Theme.textDim }
                            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true
                                        onClicked: wcard.modelData.close() }
                        }
                    }
                }
            }

            // громкость приложения
            // app volume
            Row {
                visible: !!root.stream
                x: 16; y: 184
                spacing: 10
                Icon { anchors.verticalCenter: parent.verticalCenter; name: Audio.icon(); size: 13; color: Theme.accent }
                Slider {
                    width: preview.implicitWidth - 110
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.stream?.audio?.volume ?? 0
                    onMoved: (v) => Audio.setNodeVolume(root.stream, v)
                }
                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                       font.pixelSize: Tokens.font.small; color: Theme.text
                       text: Math.round((root.stream?.audio?.volume ?? 0) * 100) + "%" }
            }
        }
    }
}
