import Quickshell
import Quickshell.Wayland
import QtQuick

// обои + меню по пкм на пустом месте
// wallpaper + right-click menu on empty space
PanelWindow {
    id: wall
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    color: Theme.bg

    Image {
        id: oldImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: ShellState.wallpaper ? "file://" + ShellState.wallpaper : ""
        sourceSize.width: wall.width
        sourceSize.height: wall.height
        onSourceChanged: { fade.stop(); opacity = 0; }
        onStatusChanged: if (status === Image.Ready) fade.restart()
        NumberAnimation on opacity {
            id: fade
            to: 1
            duration: 600
            easing.type: Easing.OutCubic
            running: false
            onFinished: oldImg.source = img.source
        }
    }

    Particles { anchors.fill: parent; monitor: wall.modelData?.name ?? "" }

    // ─── адаптивная палитра из обоев (считает только первый экран) ───
    // берём уменьшенную копию, строим гистограмму оттенков (насыщенные пиксели весят больше),
    // главный оттенок раскладываем по тонам примерно как схема «содержательный» у Material You
    // ─── adaptive palette from the wallpaper (only the first screen computes it) ───
    // take a scaled-down copy, build a hue histogram (saturated pixels weigh more),
    // and spread the main hue across tones roughly like Material You's "content" scheme
    Canvas {
        id: sampler
        width: 64; height: 40
        opacity: 0
        enabled: false
        readonly property bool main: wall.screen === Quickshell.screens[0]
        readonly property string src: main && ShellState.wallpaper ? "file://" + ShellState.wallpaper : ""
        // новые обои (а не первый показ при старте) — выбор цвета снова «авто»
        // a new wallpaper (not the first display at start): the colour choice goes back to "auto"
        property string lastSrc: ""
        onSrcChanged: {
            if (!src) return;
            // цвета для новых/прежних обоев выставляет ShellState (у каждых обоев — свои)
            // уже загруженная раньше картинка второй раз imageLoaded не присылает — тогда считаем сразу
            // (из-за этого после смены обоев акцент оставался от прежних, пока не тронешь настройки)
            // colours for new/previous wallpapers are set by ShellState (each wallpaper has its own)
            // an image loaded before doesn't send imageLoaded a second time, so compute right away
            // (because of this, after a wallpaper change the accent stayed from the previous one until you touched the settings)
            if (lastSrc && lastSrc !== src) unloadImage(lastSrc);
            lastSrc = src;
            if (isImageLoaded(src)) requestPaint();
            else loadImage(src);
            repaintLater.restart();
        }
        // выбранный в настройках цвет акцента из обоев — пересчитать палитру
        // the wallpaper accent colour chosen in the settings: recompute the palette
        readonly property real chosen: ShellState.settings.seedHue ?? -1
        onChosenChanged: if (src && isImageLoaded(src)) requestPaint()
        onImageLoaded: requestPaint()
        // страховка: если сигнал о загрузке потерялся — пересчитать ещё раз чуть позже
        // safety net: if the load signal got lost, recompute once more a little later
        Timer { id: repaintLater; interval: 900; onTriggered: if (sampler.src && sampler.isImageLoaded(sampler.src)) sampler.requestPaint() }

        function hex(h, s, l) {
            h = ((h % 360) + 360) % 360; s = Math.max(0, Math.min(1, s)); l = Math.max(0, Math.min(1, l));
            const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
            const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x]
                            : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
            return "#" + [r, g, b].map(v => Math.round((v + m) * 255).toString(16).padStart(2, "0")).join("");
        }

        // схемы — по мотивам Material You: насколько ярок акцент, куда сдвинут второй цвет и насколько окрашены фоны.
        // H — главный оттенок, S — его насыщенность в обоях, H2 — второй главный цвет обоев
        // schemes after Material You: how bright the accent is, where the second colour shifts and how tinted the backgrounds are.
        // H is the main hue, S its saturation in the wallpaper, H2 the wallpaper's second main colour
        function build(H, S, H2, scheme) {
            const base = Math.max(0.22, Math.min(0.6, S * 0.8));
            const v = ({
                tonal:      { a: base,                 a2h: H + 35,  a2s: base * 0.7, n: 0.12 },   // один цвет и его оттенки / one colour and its shades
                neutral:    { a: 0.14,                 a2h: H + 20,  a2s: 0.10,       n: 0.04 },   // почти серая, с намёком на цвет / almost grey, with a hint of colour
                vibrant:    { a: 0.78,                 a2h: H + 25,  a2s: 0.62,       n: 0.16 },   // насыщенно / saturated
                expressive: { a: 0.55, ah: H + 240,    a2h: H + 60,  a2s: 0.5,        n: 0.14, nh: H + 15 }, // неожиданный главный цвет / an unexpected main colour
                fidelity:   { a: Math.max(0.35, Math.min(0.85, S)), a2h: H2, a2s: 0.45, n: 0.10 }, // точно как на обоях / exactly as in the wallpaper
                content:    { a: Math.max(0.3, Math.min(0.75, S)), a2h: H2, a2s: 0.5, n: 0.12 },   // главный + второй цвет обоев / main + the wallpaper's second colour
                rainbow:    { a: 0.5,                  a2h: H + 120, a2s: 0.5,        n: 0.0 },    // цветной акцент на сером / a coloured accent on grey
                fruit:      { a: 0.55, ah: H - 50,     a2h: H + 70,  a2s: 0.55,       n: 0.10 }    // «фруктовый салат» / "fruit salad"
            })[scheme] ?? null;
            const c = v ?? { a: base, a2h: H + 35, a2s: base * 0.7, n: 0.12 };
            const ah = c.ah ?? H, nh = c.nh ?? H, n = c.n;
            return {
                name: L.t("адаптивная"),
                frame: hex(nh, n * 0.85, 0.09), bg: "#e0" + hex(nh, n * 1.3, 0.10).slice(1),
                surface: hex(nh, n * 1.1, 0.135), surfaceHi: hex(nh, n, 0.175), line: hex(nh, n * 0.85, 0.26),
                accent: hex(ah, c.a, 0.80), accent2: hex(c.a2h, c.a2s, 0.76), onAccent: hex(ah, Math.min(0.3, c.a * 0.5), 0.21),
                text: hex(nh, Math.min(0.3, n * 2.5), 0.93), textDim: hex(nh, n, 0.66)
            };
        }
        // смена схемы в настройках — пересчитать
        // scheme changed in the settings: recompute
        readonly property string schemeSel: ShellState.settings.scheme ?? "tonal"
        onSchemeSelChanged: if (src && isImageLoaded(src)) requestPaint()

        onPaint: {
            if (!src || !isImageLoaded(src)) return;
            const ctx = getContext("2d");
            ctx.drawImage(src, 0, 0, width, height);
            const d = ctx.getImageData(0, 0, width, height).data;
            const bins = new Array(36).fill(0), sat = new Array(36).fill(0);
            for (let i = 0; i < d.length; i += 4) {
                const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
                const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, c = mx - mn;
                if (c < 0.04 || l < 0.08 || l > 0.95) continue;
                const s = c / (1 - Math.abs(2 * l - 1));
                let h = mx === r ? ((g - b) / c) % 6 : mx === g ? (b - r) / c + 2 : (r - g) / c + 4;
                h = (h * 60 + 360) % 360;
                // центр картинки весит больше краёв: главное на обоях обычно в середине, а не в фоне
                // the centre of the image weighs more than the edges: the subject of a wallpaper is usually in the middle, not the background
                const px = (i / 4) % width, py = Math.floor(i / 4 / width);
                const dx = px / width - 0.5, dy = py / height - 0.5, centre = 1 + 1.6 * Math.max(0, 1 - Math.sqrt(dx * dx + dy * dy) / 0.5);
                const k = Math.floor(h / 10), w = s * (1 - Math.abs(l - 0.5)) * centre;
                bins[k] += w; sat[k] += s * w;
            }
            // главные цвета обоев: до 6 вершин гистограммы, не ближе 30° друг к другу — их можно выбрать в настройках
            // the wallpaper's main colours: up to 6 histogram peaks, at least 30° apart; they can be picked in the settings
            const peaks = [];
            const order = bins.map((v, k) => k).sort((a, b) => bins[b] - bins[a]);
            for (const k of order) {
                if (bins[k] <= 0 || peaks.length >= 6) break;
                if (peaks.some(p => Math.min(Math.abs(p - k), 36 - Math.abs(p - k)) < 3)) continue;
                peaks.push(k);
            }
            ShellState.wallSeeds = peaks.map(k => { const ss = sat[k] / bins[k];
                return { hue: k * 10 + 5, color: hex(k * 10 + 5, Math.max(0.35, Math.min(0.75, ss)), 0.7) }; });
            let best = peaks.length ? peaks[0] : 0;
            if (chosen >= 0) best = Math.round((chosen - 5) / 10);
            const H = best * 10 + 5;
            const S = bins[best] > 0 ? sat[best] / bins[best] : 0.35;
            // второй главный цвет обоев (для схем, которые берут несколько цветов)
            // the wallpaper's second main colour (for schemes that use several colours)
            const H2 = peaks.length > 1 ? peaks.find(k => k !== best) * 10 + 5 : H + 60;
            ShellState.adaptive = build(H, S, H2, ShellState.settings.scheme ?? "tonal");
        }
    }

    // ─── рамка выделения на пустом рабочем столе — как в обычных DE: ничего не выделяет, просто приятно ───
    // ─── selection box on the empty desktop, as in regular DEs: it selects nothing, it just feels nice ───
    property point selFrom: Qt.point(0, 0)
    property point selTo: Qt.point(0, 0)
    property bool selecting: false
    Rectangle {
        id: sel
        x: Math.min(wall.selFrom.x, wall.selTo.x); y: Math.min(wall.selFrom.y, wall.selTo.y)
        width: Math.abs(wall.selTo.x - wall.selFrom.x); height: Math.abs(wall.selTo.y - wall.selFrom.y)
        radius: Math.min(Tokens.rounding.small, width / 2, height / 2)
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
        border.width: 1.5
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
        opacity: 0
        visible: opacity > 0
        // появление — сразу, исчезновение — плавно. Раньше длительность Behavior зависела от selecting и менялась
        // в тот же миг, что и цель анимации, — анимация запускалась со старыми 60 мс и рамка пропадала рывком
        // appears instantly, fades smoothly. The Behavior's duration used to depend on selecting and changed
        // at the same moment as the animation target, so the animation started with the old 60 ms and the box vanished abruptly
        NumberAnimation { id: selFade; target: sel; property: "opacity"; to: 0; duration: ShellState.settings.desktopSelectFade ?? 420; easing.type: Easing.InOutQuad }
    }
    onSelectingChanged: {
        if (selecting) { selFade.stop(); sel.opacity = 1; }
        else selFade.restart();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: (ShellState.settings.desktopSelect ?? true) ? Qt.LeftButton | Qt.RightButton : Qt.RightButton
        // точку нажатия запоминаем отдельно: пока прошлая рамка гаснет, она остаётся на своём месте
        // the press point is remembered separately: while the previous box fades, it stays in place
        property point pressAt: Qt.point(0, 0)
        onPressed: (m) => { if (m.button === Qt.LeftButton) pressAt = Qt.point(m.x, m.y); }
        onPositionChanged: (m) => {
            if (!(pressedButtons & Qt.LeftButton)) return;
            const to = Qt.point(Math.max(0, Math.min(wall.width, m.x)), Math.max(0, Math.min(wall.height, m.y)));
            // от случайного дрожания при обычном клике рамка не появляется
            // the box doesn't appear from accidental jitter during a normal click
            if (!wall.selecting && Math.abs(to.x - pressAt.x) + Math.abs(to.y - pressAt.y) > 6) { wall.selFrom = pressAt; wall.selTo = to; wall.selecting = true; }
            else if (wall.selecting) wall.selTo = to;
        }
        onReleased: wall.selecting = false
        onCanceled: wall.selecting = false
        onClicked: (m) => { if (m.button === Qt.RightButton) menu.openAt(m.x, m.y, false); }
    }

    ContextMenu {
        id: menu
        screen: wall.modelData
        items: [
            { icon: "wallpaper", text: L.t("сменить обои"),       action: () => { ShellState.pickerOpen = true; } },
            { icon: "apps",      text: L.t("приложения"),         action: () => { ShellState.launcherOpen = true; } },
            { icon: "terminal",  text: L.t("терминал"),           action: () => Quickshell.execDetached([ShellState.settings.terminal || "kitty"]) },
            { icon: "settings",  text: L.t("настройки"),          action: () => { ShellState.settingsOpen = true; } },
            { icon: "palette",   text: L.t("цвета: ") + Theme.p.name,
              action: () => ShellState.cycleAccent() },
            { icon: "sparkle",   text: L.t("частицы: ") + ({ petals: L.t("лепестки"), stars: L.t("звёзды"), snow: L.t("снег"), bubbles: L.t("пузырьки"), off: L.t("выкл") })[ShellState.particles],
              action: () => ShellState.cycleParticles() },
            { icon: "refresh",   text: L.t("перезапустить шелл"), action: () => Quickshell.execDetached(["sh", Quickshell.shellPath("restart.sh")]) }
        ]
    }
}
