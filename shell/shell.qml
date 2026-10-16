//@ pragma IconTheme breeze-dark
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    Intro {}       // заставка при входе в сеанс — первой, чтобы закрыть экран раньше обоев и всего остального / session intro first, so it covers the screen before the wallpaper and everything else

    Variants {
        model: Quickshell.screens
        delegate: Component { Wallpaper {} }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component { Frame {} }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component { Bar {} }
    }

    Launcher {}
    WallpaperPicker {}
    PolkitDialog {}
    Dashboard { id: dash }
    NotifPopups {}
    Osd { id: osd }
    LockScreen {}
    PowerMenu {}
    Calculator {}
    Clipboard {}
    Settings {}
    SysMon {}
    TreeGuard {}
    GifOverlays {}
    Visualizer {}
    HotCorners {}
    readonly property string termTheme: TermTheme.kitty   // пишет цвета kitty/fish при смене палитры / writes kitty/fish colours when the palette changes
    IdleManager {}
    SleepWatch {}
    readonly property int bindsReady: Binds.list.length
    readonly property bool eqReady: Eq.enabled                 // поднимает эквалайзер при старте, если он был включён / brings the equaliser up at start if it was on
    readonly property bool vpnReady: Vpn.autoConnect           // поднимает VPN при старте, если включено автоподключение / brings the VPN up at start if auto-connect is on
    readonly property bool sessionReady: Session.enabled   // запускает сохранение/восстановление сеанса / starts session saving/restoring

    // переключение страниц: если активное окно в фуллскрине (игра) — сначала Esc
    // смена страницы при полноэкранном окне: окно сначала выходит из полноэкранного режима
    // (стягивается в рамки экрана), и только потом переключаемся. Шелл запоминает его и,
    // когда ты вернёшься на ту страницу, снова разворачивает на весь экран (см. TreeGuard)
    // page switching: if the active window is full-screen (a game), Esc first
    // switching pages with a full-screen window: the window first leaves full screen
    // (shrinks into the screen frame), and only then do we switch. The shell remembers it and,
    // when you come back to that page, makes it full-screen again (see TreeGuard)
    function go(cmd: string): void {
        const fs = ShellState.mangoClients.find(c => c.is_fullscreen && c.is_focused);
        if (fs) {
            ShellState.fsParked = ShellState.fsParked.concat([fs.id]);
            Quickshell.execDetached(["sh", "-c", "mmsg dispatch togglefullscreen client," + fs.id + "; sleep 0.25; mmsg dispatch " + cmd]);
        } else
            Quickshell.execDetached(["mmsg", "dispatch", cmd]);
    }

    // по кругу: с первой страницы «назад» — на девятую, с девятой «вперёд» — на первую
    // wrapping: "back" from the first page goes to the last, "forward" from the last goes to the first
    function curTag(): int {
        const mon = ToplevelManager.activeToplevel?.screens?.[0]?.name ?? Quickshell.screens[0]?.name ?? "";
        const tags = ShellState.mangoTags[mon] ?? Object.values(ShellState.mangoTags)[0] ?? [];
        return (tags.find(t => t.is_active) ?? { index: 1 }).index;
    }
    // в ленте Ctrl+Shift+A/D сдвигают её на одну колонку: из-за края экрана выезжает следующее окно
    // (фокус переходит на него, mango прокручивает ленту ровно до него). Если за краем ничего нет —
    // переключаем страницу, как обычно
    // in the scroller Ctrl+Shift+A/D shift it by one column: the next window slides in from past the screen edge
    // (focus moves to it and mango scrolls exactly to it). If there's nothing past the edge,
    // switch the page as usual
    function stripStep(dir: int): bool {
        const scr = ToplevelManager.activeToplevel?.screens?.[0] ?? Quickshell.screens[0];
        const mon = scr?.name ?? "";
        const tag = (ShellState.mangoTags[mon] ?? []).find(t => t.is_active);
        if (!scr || !tag || tag.layout !== "S") return false;
        const list = ShellState.mangoClients.filter(c => c.monitor === mon && (c.tags || []).includes(tag.index)
                && !c.is_floating && !c.is_minimized && !c.is_fullscreen && !c.is_scratchpad && !c.is_namedscratchpad && !c.is_global)
            .sort((a, b) => a.x - b.x || a.y - b.y);
        const left = scr.x, right = scr.x + scr.width;
        const t = dir > 0 ? list.find(c => c.x + c.width > right + 2)
                          : list.slice().reverse().find(c => c.x < left - 2);
        if (!t) return false;
        Quickshell.execDetached(["mmsg", "dispatch", "focusid", "client," + t.id]);
        return true;
    }
    IpcHandler {
        target: "pages"
        function prev(): void { if (root.stripStep(-1)) return; const i = root.curTag(); root.go("view," + (i === 1 ? ShellState.pageCount : i - 1)); }
        function next(): void { if (root.stripStep(1)) return; const i = root.curTag(); root.go("view," + (i === ShellState.pageCount ? 1 : i + 1)); }
    }

    IpcHandler {
        target: "widgets"
        function power(): void { ShellState.powerOpen = !ShellState.powerOpen; }
        function calc(): void { ShellState.calcOpen = !ShellState.calcOpen; }
        function clipboard(): void { ShellState.clipOpen = !ShellState.clipOpen; }
        function settings(): void { ShellState.settingsOpen = !ShellState.settingsOpen; }
        function lang(): void { L.toggle(); }
        function monitor(): void { ShellState.monOpen = !ShellState.monOpen; }
        function wallpaper(): void { ShellState.pickerOpen = !ShellState.pickerOpen; }
        // гифки на экране: режим правки (тащить, колесо — размер, ПКМ — убрать)
        // on-screen GIFs: edit mode (drag, wheel to resize, right-click to remove)
        function gifs(): void { ShellState.gifEditing = !ShellState.gifEditing; }
        // запись экрана: повторный вызов — остановка
        // screen recording: calling it again stops it
        function record(): void { ShellState.recording ? ShellState.stopRecording() : ShellState.record("full"); }
        function recordArea(): void { ShellState.recording ? ShellState.stopRecording() : ShellState.record("area"); }
        // то же, но со звуком системы и микрофоном вместе
        // the same, but with system sound and mic together
        function recordMic(): void { ShellState.recording ? ShellState.stopRecording() : ShellState.record("full", "both"); }
        function recordAreaMic(): void { ShellState.recording ? ShellState.stopRecording() : ShellState.record("area", "both"); }
        function killApp(): void {
            const c = ShellState.mangoClients.find(x => x.is_focused);
            if (c && c.pid > 0) Quickshell.execDetached(["sh", Quickshell.shellPath("kill-app.sh"), String(c.pid)]);
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { ShellState.lock(); }
    }
    // выход из mango через шелл: сначала сохраняется сеанс (Super+Shift+M раньше выходил сразу, мимо сохранения)
    // quitting mango through the shell: the session is saved first (Super+Shift+M used to quit right away, skipping the save)
    IpcHandler {
        target: "session"
        function logout(): void { ShellState.leave(["mmsg", "dispatch", "quit"]); }
        function save(): void { Session.save(null); }
    }

    // клавиши громкости/яркости идут через шелл — так OSD появляется сразу
    // volume/brightness keys go through the shell, so the OSD appears instantly
    IpcHandler {
        target: "osd"
        function volume_up(): void { if (Audio.muted) Audio.toggleMute(); Audio.setVolume(Audio.volume + 0.05); osd.show(); }
        function volume_down(): void { Audio.setVolume(Audio.volume - 0.05); osd.show(); }
        function mute(): void { Audio.toggleMute(); osd.show(); }
        function brightness_up(): void { Brightness.set(Math.min(1, Brightness.value + 0.05)); osd.show(); }
        function brightness_down(): void { Brightness.set(Math.max(0.02, Brightness.value - 0.05)); osd.show(); }
    }

    // перемешивание и повтор плеера: MPD — как кнопки на борде, без него — любой плеер через playerctl
    // the player's shuffle and repeat: MPD like the dashboard buttons, without it any player via playerctl
    IpcHandler {
        target: "player"
        function shuffle(): void {
            if (Mpd.alive) Mpd.toggleRandom();
            else Quickshell.execDetached(["playerctl", "shuffle", "toggle"]);
        }
        // повтор по кругу: весь список → один трек → выкл / repeat cycles: whole list → one track → off
        function repeat(): void {
            if (Mpd.alive) Mpd.cycleRepeat();
            else Quickshell.execDetached(["sh", "-c", 'case "$(playerctl loop 2>/dev/null)" in None) playerctl loop Playlist;; Playlist) playerctl loop Track;; *) playerctl loop None;; esac']);
        }
    }

    IpcHandler {
        target: "notifs"
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
        function clear(): void { Notifs.clearAll(); }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { dash.toggle(); }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            const t = ToplevelManager.activeToplevel;
            if (!ShellState.launcherOpen && t && t.fullscreen) return;
            ShellState.launcherOpen = !ShellState.launcherOpen;
        }
    }
}
