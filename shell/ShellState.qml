pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// общее состояние шелла
// shared shell state
Singleton {
    id: st
    property bool launcherOpen: false
    property bool pickerOpen: false
    property bool powerOpen: false
    property bool calcOpen: false
    property bool clipOpen: false
    property bool caffeine: false   // «не давать экрану гаснуть» / "don't let the screen turn off"
    // настройки (окно «Настройки», Super+I); хранятся в settings.json
    // settings (the Settings window, Super+I); stored in settings.json
    property var settings: ({
        userName: "",                         // пусто — имя пользователя системы / empty: the system user name
        idleDim: 5, idleLock: 10,             // минуты; 0 — никогда / minutes; 0 means never
        treeLimit: 4, minW: 560, minH: 360,   // сетка / grid
        halfForTwo: true,                     // лента: два окна — по 1/2 / scroller: two windows at 1/2 each
        fullscreenPage: true,                 // полноэкранные — на свою страницу / full-screen windows get their own page
        masterStack: false,                   // режим «мастер + стек» в Super+Tab / the "master + stack" mode in Super+Tab
        weatherCity: "",                      // пусто — определять по Wi-Fi / empty: detect from Wi-Fi
        uiFont: "Nyaspace",                   // шрифт шелла / shell font
        themedIcons: true,                    // значки приложений в цвет акцента / app icons in the accent colour
        iconTheme: "Gruvbox-Plus-Dark",       // тема значков (если не установлена — breeze-dark) / icon theme (if not installed, breeze-dark)
        frameRadius: 24,                      // скругление внутренних углов рамки экрана / rounding of the screen frame's inner corners
        screenRadius: 0,                      // скругление самих углов экрана (0 — нет) / rounding of the screen corners themselves (0 = none)
        uiRound: 100,                         // скругление карточек и виджетов, % / rounding of cards and widgets, %
        windowRadius: 5,                      // скругление окон (mango) / window rounding (mango)
        lang: "en",                           // язык интерфейса (Super+G) / UI language (Super+G)
        restoreSession: true,                 // после входа снова открыть приложения / reopen apps after login
        firefoxTheme: true,                   // тема шелла для Firefox / shell theme for Firefox
        dashDelay: 150,                       // сколько борд ждёт возвращения курсора, мс / how long the dashboard waits for the cursor to come back, ms
        realBlur: true,                       // настоящая прозрачность: за окнами видно другие окна (тяжелее для видеокарты) / real transparency: other windows show behind windows (heavier on the GPU)
        blurStrength: 1,                      // сила размытия окон: 0 — без размытия / window blur strength: 0 means no blur
        winOpacity: 90,                       // непрозрачность активного окна, % / active window opacity, %
        winOpacityInactive: 90,               // непрозрачность остальных окон, % / opacity of the other windows, %
        cursorTheme: "",                      // тема курсора (пусто — как в системе) / cursor theme (empty: as in the system)
        cursorSize: 24,
        // kbLayouts: [...] — раскладки клавиатуры (коды xkb); пока не заданы, конфиг mango не трогаем
        // kbLayouts: [...] keyboard layouts (xkb codes); while unset, the mango config is left alone
        seedHue: -1,                          // оттенок акцента из обоев (-1 — главный автоматически) / accent hue from the wallpaper (-1: the main one automatically)
        scheme: "tonal",                      // схема адаптивной темы (как у Material You) / adaptive theme scheme (as in Material You)
        batteryLow: 15,                       // предупредить при таком заряде, % / warn at this charge, %
        batteryCritical: 5,                   // уснуть при таком заряде, % (0 — не засыпать) / sleep at this charge, % (0 = don't sleep)
        clock24: true,                        // часы 24 ч / 24-hour clock
        clockSeconds: false,
        kbToggle: "grp:alt_shift_toggle",     // чем переключать / what switches it
        recAudio: "system",                   // звук в записи экрана: none | system | mic / sound in screen recordings: none | system | mic
        appAccent: true,                      // акцент шелла в программах GTK и KDE / shell accent in GTK and KDE apps
        deltaTheme: true,                     // тема DeltaChat (custom:nyashell) / DeltaChat theme (custom:nyashell)
        steamTheme: true,                     // цвета и узкое окно для Steam + Minimal Dark / colours and a narrow window for Steam + Minimal Dark
        terminal: "kitty",                    // терминал и файловый менеджер для кнопок шелла / terminal and file manager for the shell's buttons
        files: "nemo"
    })
    readonly property string sysUser: { const u = Quickshell.env("USER") || "user"; return u.charAt(0).toUpperCase() + u.slice(1); }
    readonly property string userName: settings.userName || sysUser
    FileView {
        id: setFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/settings.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { st.settings = Object.assign({}, st.settings, JSON.parse(text())); st.settingsRead = true; } catch (e) {} }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { try { st.settings = Object.assign({}, st.settings, JSON.parse(text())); st.settingsRead = true; } catch (e) {} }
}
    // защита: если кто-то меняет настройку раньше, чем прочитан файл, — сначала дочитываем файл,
    // иначе записались бы стандартные значения поверх твоих
    // safeguard: if something changes a setting before the file has been read, read the file first,
    // otherwise the defaults would be written over yours
    property bool settingsRead: false
    function set(key: string, value): void {
        if (!settingsRead) {
            try { settings = Object.assign({}, settings, JSON.parse(setFile.text() || "{}")); } catch (e) {}
            settingsRead = true;
        }
        const s = Object.assign({}, settings);
        s[key] = value;
        settings = s;
        setFile.setText(JSON.stringify(s, null, 2));
        if (key === "masterStack" || key === "halfForTwo") applyMango();
        if (key === "iconTheme") applyIconTheme();
        if (key === "windowRadius") applyWindowRadius();
        if (key === "realBlur" || key === "blurStrength") applyBlur();
        if (key === "winOpacity" || key === "winOpacityInactive") applyOpacity();
        if (key === "lang") shareWithGreeter();
        if ((key === "seedHue" || key === "scheme") && !restoringWall) rememberWall();
        if (key === "cursorTheme" || key === "cursorSize") applyCursor();
        if (key === "kbLayouts" || key === "kbToggle") applyKeyboard();
        if (key === "pageCount") applyPages();
        if (key === "appAccent" && value) TermTheme.write();
        if (key === "appAccent" && !value) Quickshell.execDetached(["sh", Quickshell.shellPath("qt-apps.sh"), "off"]);
        if ((key === "deltaTheme" || key === "steamTheme") && value) TermTheme.write();
        if (key === "firefoxTheme" && value) TermTheme.write();
    }
    // то, что живёт в конфиге mango: набор режимов для Super+Tab
    // все правки конфига mango — строго по очереди, одной цепочкой (раньше несколько правок при старте
    // шли одновременно и затирали друг друга — так «терялись» переназначенные клавиши), в конце — перечитать
    // what lives in the mango config: the set of modes for Super+Tab
    // all mango config edits go strictly in order, in one chain (several edits at start used to
    // run at once and overwrite each other, which is how reassigned keys got "lost"), with a reload at the end
    property var cfgQueue: []
    function cfgEdit(argv): void {
        cfgQueue = cfgQueue.concat([argv]);
        if (!cfgProc.running) cfgNext();
    }
    function cfgNext(): void {
        if (!cfgQueue.length) { cfgReload.restart(); return; }
        cfgProc.command = cfgQueue[0];
        cfgQueue = cfgQueue.slice(1);
        cfgProc.running = true;
    }
    Process { id: cfgProc; onExited: st.cfgNext() }
    Timer { id: cfgReload; interval: 200; onTriggered: Quickshell.execDetached(["mmsg", "dispatch", "reload_config"]) }

    function applyMango(): void {
        const cycle = settings.masterStack ? "scroller,fair,tile" : "scroller,fair";
        cfgEdit(["sh", "-c", 'f="$HOME/.config/mango/config.conf"; grep -qx "circle_layout=$1" "$f" || sed -i "s/^circle_layout=.*/circle_layout=$1/" "$f"', "sh", cycle]);
        Quickshell.execDetached(["mmsg", "dispatch", "setoption,nya_scroller_half," + (settings.halfForTwo ? 1 : 0)]);
    }
    Component.onCompleted: {
        // настройки — до всего остального (см. applyIconTheme): иначе в mango ушли бы значения по умолчанию
        // settings before everything else (see applyIconTheme): otherwise the defaults would go to mango
        if (!settingsRead) {
            try { settings = Object.assign({}, settings, JSON.parse(setFile.text() || "{}")); settingsRead = true; } catch (e) {}
        }
        // то же для остальных файлов шелла: обои, акцент, частицы, закреплённые — до того, как их кто-то использует
        // the same for the shell's other files: wallpaper, accent, particles, pinned, before anyone uses them
        { const v = wallFile.text().trim(); if (v && v !== wallpaper) wallpaper = v; }
        { const v = accentFile.text().trim(); if (v) accent = v; }
        { const v = partFile.text().trim(); if (v) particles = v; }
        if (pinFile.text()) { try { pinned = JSON.parse(pinFile.text()); } catch (e) {} }
        startupDone = true;
        syncMango(); applyMango(); palInit.start(); applyIconTheme(); applyWindowRadius();
    }
    // ещё раз через пару секунд: при самом старте настройки могли быть не прочитаны,
    // и mango получал значения по умолчанию (так «не сохранялось» скругление окон)
    // после старта ещё раз прописываем свои настройки в конфиг mango: обновление шелла кладёт свежий
    // config.conf со значениями по умолчанию (из-за этого «слетала» вторая раскладка)
    // once more after a couple of seconds: at the very start the settings may not have been read yet,
    // and mango got the defaults (that's why window rounding "wasn't saved")
    // after start write our settings into the mango config again: a shell update puts a fresh
    // config.conf with defaults in place (that's why the second layout "fell off")
    Timer { interval: 2500; running: true; onTriggered: {
        st.applyWindowRadius(); st.applyMango(); st.applyBlur(); st.applyOpacity(); st.applyCursor();
        if (st.settings.kbLayouts) st.applyKeyboard();
        if (st.settings.pageCount) st.applyPages();
        for (const k in (st.settings.mango ?? {})) st.applyMangoOpt(k, String(st.settings.mango[k]));
        st.applyMangoOpt("rootcolor", st.rootColor);
        // Немо: шаблоны «Создать документ», действия в меню ПКМ, архивы как папки (см. files/files-setup.sh)
        // Nemo: "New document" templates, right-click actions, archives as folders (see files/files-setup.sh)
        Quickshell.execDetached(["sh", Quickshell.shellPath("files/files-setup.sh"), L.lang]);
    } }
    // скругление окон: сразу в работающий mango и в конфиг, чтобы пережило перезапуск
    // ─── крышка ноутбука: что делать при закрытии (настройка logind, нужен пароль — спросит наше окно polkit) ───
    // systemd-logind (Arch) или elogind (Artix и др. без systemd) — у них разные папки настроек
    // window rounding: straight into the running mango and into the config so it survives a restart
    // ─── laptop lid: what to do on close (a logind setting, needs a password, our polkit window will ask) ───
    // systemd-logind (Arch) or elogind (Artix and others without systemd) keep their settings in different folders
    function setLid(action: string): void {
        Quickshell.execDetached(["sh", "-c",
            'printf "[Login]\\nHandleLidSwitch=%s\\nHandleLidSwitchExternalPower=%s\\n" "$1" "$1" > /tmp/nyash-lid.conf && ' +
            'pkexec sh -c "if [ -d /run/systemd/system ]; then d=/etc/systemd/logind.conf.d; else d=/etc/elogind/logind.conf.d; fi; ' +
            'mkdir -p \\$d && cp /tmp/nyash-lid.conf \\$d/50-nyash-lid.conf && ' +
            '{ systemctl kill -s HUP systemd-logind 2>/dev/null || pkill -HUP -x elogind-daemon 2>/dev/null || pkill -HUP -x elogind; true; }" && ' +
            'notify-send -a nyashell "$2"', "sh", action, L.t("действие при закрытии крышки сохранено")]);
        set("lidAction", action);
    }
    // часовой пояс и синхронизация времени: timedatectl (systemd), без него — напрямую
    // (/etc/localtime и служба NTP через openrc / runit / dinit). Пароль спросит polkit
    // timezone and time sync: timedatectl (systemd), without it directly
    // (/etc/localtime and the NTP service via openrc / runit / dinit). polkit will ask for the password
    property bool timedated: true
    property bool ntpControl: true
    function setTimezone(tz: string): void {
        Quickshell.execDetached(["sh", "-c",
            'if command -v timedatectl >/dev/null && [ -d /run/systemd/system ]; then timedatectl set-timezone "$1"; ' +
            'else [ -f "/usr/share/zoneinfo/$1" ] && pkexec ln -sf "/usr/share/zoneinfo/$1" /etc/localtime; fi', "sh", tz]);
        tzLater.restart();
    }
    function setNtp(on: bool): void {
        if (timedated) Quickshell.execDetached(["timedatectl", "set-ntp", on ? "true" : "false"]);
        else Quickshell.execDetached(["sh", "-c", 'pkexec sh "$1" "$2" || notify-send -a nyashell "$3"', "sh",
                                      Quickshell.shellPath("ntp.sh"), on ? "on" : "off", L.t("не нашла службу времени: поставь chrony или ntp")]);
        tzLater.restart();
    }
    property string timezone: ""
    property bool ntp: true
    property var timezones: []
    Process {
        id: tzProbe
        running: true
        command: ["sh", "-c",
            'if command -v timedatectl >/dev/null && [ -d /run/systemd/system ]; then timedatectl show -p Timezone -p NTP --value; echo td; echo ==; timedatectl list-timezones; ' +
            'else readlink -f /etc/localtime | sed "s#.*/zoneinfo/##"; pgrep -x "chronyd|ntpd|openntpd" >/dev/null && echo yes || echo no; ' +
            'sh "$0" probe >/dev/null 2>&1 && echo rc || echo none; echo ==; ' +
            '{ echo UTC; grep -v "^#" /usr/share/zoneinfo/zone1970.tab 2>/dev/null | cut -f3; } | sort -u; fi', Quickshell.shellPath("ntp.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("==\n"), head = (parts[0] || "").trim().split("\n");
                st.timezone = head[0] || ""; st.ntp = (head[1] || "yes") === "yes"; st.timedated = head[2] === "td"; st.ntpControl = head[2] !== "none";
                st.timezones = (parts[1] || "").split("\n").filter(x => x);
            }
        }
    }
    Timer { id: tzLater; interval: 1500; onTriggered: tzProbe.running = true }

    // WASD в меню не должны зависеть от раскладки: на русской A/D — это Ф/В. Проверяем и букву,
    // и физическую клавишу (код xkb = evdev + 8), и русскую букву на том же месте
    // WASD in menus mustn't depend on the layout: on the Russian one A/D are Ф/В. Check the letter,
    // the physical key (xkb code = evdev + 8) and the Russian letter in the same place
    function keyIs(e, letter: string): bool {
        const m = ({ a: [Qt.Key_A, 0x424, 38], d: [Qt.Key_D, 0x412, 40], w: [Qt.Key_W, 0x426, 25], s: [Qt.Key_S, 0x42B, 39] })[letter];
        return !!m && (e.key === m[0] || e.key === m[1] || e.nativeScanCode === m[2]);
    }

    // ─── свои шрифты ───
    // текст шелла — любым шрифтом (значки всё равно из Nyaspace); эмодзи — своим цветным шрифтом.
    // файл выбирается диалогом, копируется в ~/.local/share/fonts/nyashell-user (font-add.sh)
    // ─── custom fonts ───
    // shell text in any font (icons still come from Nyaspace); emoji in your own colour font.
    // the file is picked with a dialog and copied to ~/.local/share/fonts/nyashell-user (font-add.sh)
    property string fontPickKind: ""
    readonly property bool fontPicking: fontPick.running
    function pickFont(kind: string): void {
        if (fontPick.running) return;
        fontPickKind = kind;
        fontPick.command = ["sh", "-c",
            'f=$(if command -v zenity >/dev/null; then zenity --file-selection --title="$2" --file-filter="*.ttf *.otf *.ttc"; ' +
            'else kdialog --getopenfilename "$HOME" "*.ttf *.otf *.ttc"; fi) && [ -n "$f" ] && sh "$3" "$1" "$f"',
            "sh", kind, L.t("Файл шрифта"), Quickshell.shellPath("font-add.sh")];
        fontPick.running = true;
    }
    function resetEmoji(): void {
        Quickshell.execDetached(["sh", Quickshell.shellPath("font-add.sh"), "emoji-reset"]);
        set("emojiFont", "");
        Quickshell.execDetached(["notify-send", "-a", "nyashell", L.t("Эмодзи"), L.t("вернула стандартные эмодзи — перезапусти шелл (Super+Ctrl+R)")]);
    }
    Process {
        id: fontPick
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 2 || !l[0]) return;
                if (st.fontPickKind === "emoji") {
                    st.set("emojiFont", l[0]);
                    Quickshell.execDetached(["notify-send", "-a", "nyashell", l[0], L.t("эмодзи заменены — перезапусти шелл (Super+Ctrl+R), в других программах — после их перезапуска")]);
                } else {
                    st.set("uiFontFile", l[1]);
                    st.set("uiFont", l[0]);
                }
            }
        }
    }

    // узоры наклеек пластинки (для треков без обложки) — см. Vinyl.qml
    // vinyl label patterns (for tracks without a cover), see Vinyl.qml
    readonly property var vinylKindsAll: ["split", "triangles", "rings", "squares", "flowers", "moons", "stars", "plus", "hexes", "paws"]

    // ─── гифки на экране (GifOverlays.qml) ───
    // ─── on-screen GIFs (GifOverlays.qml) ───
    property bool gifEditing: false
    readonly property string gifDir: Quickshell.env("HOME") + "/.local/share/nyashell/gifs"
    function updateGif(id: string, patch): void {
        set("gifs", (settings.gifs ?? []).map(g => g.id === id ? Object.assign({}, g, patch) : g));
    }
    function removeGif(id: string): void {
        const g = (settings.gifs ?? []).find(x => x.id === id);
        set("gifs", (settings.gifs ?? []).filter(x => x.id !== id));
        if (g && g.file && g.file.startsWith(gifDir + "/")) Quickshell.execDetached(["rm", "-f", g.file]);
    }
    function pickGif(): void {
        if (gifPick.running) return;
        gifPick.command = ["sh", "-c",
            'f=$(if command -v zenity >/dev/null; then zenity --file-selection --title="$1" --file-filter="*.gif *.webp *.png *.apng"; ' +
            'else kdialog --getopenfilename "$HOME" "*.gif *.webp *.png *.apng"; fi) && [ -n "$f" ] || exit 1; ' +
            'mkdir -p "$2"; d="$2/$(date +%s)-$(basename "$f")"; cp "$f" "$d" && echo "$d"', "sh", L.t("Гифка"), gifDir];
        gifPick.running = true;
    }
    readonly property bool gifPicking: gifPick.running
    // открыт диалог выбора файла (zenity/kdialog) — это обычное окно, и оверлеи шелла (борд, настройки) прячутся,
    // чтобы диалог не оказался под ними; после выбора они возвращаются как были
    // a file chooser dialog (zenity/kdialog) is open: it's a normal window, so the shell overlays (dashboard, settings) hide
    // so the dialog doesn't end up under them; after the choice they come back as they were
    readonly property bool fileDialog: fontPicking || gifPicking || Mpd.picking || Eq.picking
    Process {
        id: gifPick
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (!f) return;
                const scr = Quickshell.screens[0];
                st.set("gifs", (st.settings.gifs ?? []).concat([{ id: String(Date.now()), file: f, on: true, top: false,
                    screen: scr?.name ?? "", x: Math.round((scr?.width ?? 1920) / 2 - 120), y: Math.round((scr?.height ?? 1080) / 2 - 120),
                    w: 240, op: 100, flip: false }]));
            }
        }
    }

    // ─── настройки ввода и прочие опции mango из окна настроек: settings.mango = { ключ: значение } ───
    // пишутся в config.conf (и перечитываются), а при старте — ещё раз: обновление кладёт свежий конфиг
    // ─── input settings and other mango options from the settings window: settings.mango = { key: value } ───
    // written to config.conf (and reloaded), and once more at start: an update puts a fresh config in place
    function mangoOpt(key: string, def): var { const v = (settings.mango ?? {})[key]; return v === undefined ? def : Number(v); }
    function setMango(key: string, value): void {
        const m = Object.assign({}, settings.mango ?? {}); m[key] = value; set("mango", m);
        applyMangoOpt(key, String(value));
    }
    // фон самого mango (виден до старта шелла) — цвета рамки, как и заставка. Раньше это был серый по умолчанию:
    // при входе сначала мелькал серый экран
    // mango's own background (visible before the shell starts): the frame colour, like the intro. It used to be the default grey,
    // and a grey screen flashed first on login
    readonly property string rootColor: "0x" + Theme.frame.toString().replace("#", "").slice(-6).toLowerCase() + "ff"
    onRootColorChanged: if (startupDone) rootLater.restart()
    Timer { id: rootLater; interval: 1500; onTriggered: st.applyMangoOpt("rootcolor", st.rootColor) }
    function applyMangoOpt(key: string, v: string): void {
        if (!/^[a-z_]+$/.test(key) || !/^[-0-9.a-z_]+$/.test(v)) return;
        cfgEdit(["sh", "-c", 'f="$HOME/.config/mango/config.conf"; grep -q "^$1=" "$f" && sed -i "s|^$1=.*|$1=$2|" "$f" || echo "$1=$2" >> "$f"', "sh", key, v]);
    }
    // ─── углы экрана (HotCorners.qml): что делает каждый угол ───
    // ─── screen corners (HotCorners.qml): what each corner does ───
    readonly property var cornerActions: [["none", "ничего"], ["dashboard", "борд"], ["launcher", "меню приложений"], ["overview", "обзор окон"],
                                          ["settings", "настройки"], ["power", "меню питания"], ["lock", "блокировка"],
                                          ["prev", "страница назад"], ["next", "страница вперёд"], ["shot", "скриншот"]]

    // ─── число страниц (теги mango, 1–31). Последняя страница — ещё и «стоянка» браузера из борда ───
    // ─── number of pages (mango tags, 1–31). The last page is also the dashboard browser's "parking spot" ───
    readonly property int pageCount: Math.max(2, Math.min(31, settings.pageCount ?? 9))
    function applyPages(): void {
        cfgEdit(["sh", "-c",
            'f="$HOME/.config/mango/config.conf"; ' +
            'grep -q "^tag_num=" "$f" && sed -i "s/^tag_num=.*/tag_num=$1/" "$f" || echo "tag_num=$1" >> "$f"; ' +
            'sed -i "/nyash-browser/s/tags:[0-9]*/tags:$1/" "$f"', "sh", String(pageCount)]);
    }

    // ─── список раскладок xkb: код → название («de» → «German»), с вариантами («us(dvorak)») ───
    // ─── list of xkb layouts: code → name ("de" → "German"), with variants ("us(dvorak)") ───
    property var xkbLayouts: []
    Process {
        running: true
        command: ["sh", "-c", 'f=/usr/share/X11/xkb/rules/evdev.lst; [ -f "$f" ] || f=/usr/share/X11/xkb/rules/base.lst; ' +
                  'awk \'/^! layout/{s=1;next} /^! variant/{s=2;next} /^!/{s=0} ' +
                  's==1 && NF{c=$1; $1=""; sub(/^ +/,""); print c "\\t" $0} ' +
                  's==2 && NF{v=$1; l=$2; sub(/:$/,"",l); $1=""; $2=""; sub(/^ +/,""); print l "(" v ")\\t" $0}\' "$f"']
        stdout: StdioCollector { onStreamFinished: st.xkbLayouts = text.split("\n").filter(x => x.includes("\t")).map(x => x.split("\t")) }
    }
    function layoutName(code: string): string {
        const f = xkbLayouts.find(x => x[0] === code);
        return f ? f[1] : "";
    }
    function findLayouts(q: string): var {
        q = q.trim().toLowerCase();
        if (q.length < 2) return [];
        const exact = xkbLayouts.filter(x => x[0] === q);
        const rest = xkbLayouts.filter(x => x[0] !== q && (x[0].startsWith(q) || x[1].toLowerCase().includes(q)))
            .sort((a, b) => (a[0].includes("(") ? 1 : 0) - (b[0].includes("(") ? 1 : 0));
        return exact.concat(rest).slice(0, 8);
    }

    // ─── раскладки клавиатуры: в конфиг mango и сразу перечитать ───
    // ─── keyboard layouts: into the mango config and reload right away ───
    function applyKeyboard(): void {
        const l = (settings.kbLayouts ?? ["us"]).filter(x => /^[a-z]{2,3}(\([a-z0-9_]+\))?$/.test(x)).join(","), o = settings.kbToggle ?? "grp:alt_shift_toggle";
        if (!l) return;
        cfgEdit(["sh", "-c",
            'f="$HOME/.config/mango/config.conf"; sed -i -e "s/^xkb_rules_layout=.*/xkb_rules_layout=$1/" -e "s/^xkb_rules_options=.*/xkb_rules_options=$2/" "$f"',
            "sh", l, o]);
    }

    // ─── прозрачность окон: сразу (mango перекрашивает открытые окна) и в конфиг ───
    // игры и видео (правило с opacity 1.0 в конфиге) остаются непрозрачными
    // ─── window opacity: right away (mango repaints open windows) and into the config ───
    // games and video (the opacity 1.0 rule in the config) stay opaque
    function applyOpacity(): void {
        const fo = (Math.max(30, Math.min(100, settings.winOpacity ?? 90)) / 100).toFixed(2);
        const uo = (Math.max(30, Math.min(100, settings.winOpacityInactive ?? 90)) / 100).toFixed(2);
        Quickshell.execDetached(["sh", "-c", 'mmsg dispatch setoption,focused_opacity,"$1"; mmsg dispatch setoption,unfocused_opacity,"$2"', "sh", fo, uo]);
        cfgEdit(["sh", "-c",
            'f="$HOME/.config/mango/config.conf"; sed -i -e "s/^focused_opacity=.*/focused_opacity=$1/" -e "s/^unfocused_opacity=.*/unfocused_opacity=$2/" ' +
            // старое правило со своей прозрачностью для kitty и nemo — убираем, теперь у всех окон одна настройка
            // the old rule with its own opacity for kitty and nemo is removed: all windows now share one setting
            '-e "/^windowrule=appid:^(kitty|nemo)\\$,focused_opacity/d" "$f"', "sh", fo, uo]);
    }

    // ─── курсор ───
    // установленные темы курсора: папки с подпапкой cursors в ~/.local/share/icons, ~/.icons, /usr/share/icons
    // ─── cursor ───
    // installed cursor themes: folders with a cursors subfolder in ~/.local/share/icons, ~/.icons, /usr/share/icons
    property var cursorThemes: []
    Process {
        running: true
        command: ["sh", "-c", 'for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do for t in "$d"/*/; do [ -d "$t/cursors" ] && basename "$t"; done; done | sort -u']
        stdout: StdioCollector { onStreamFinished: st.cursorThemes = text.split("\n").filter(x => x && x !== "default") }
    }
    // применяем везде: mango (курсор на рабочем столе и в его окнах), GTK, KDE/Qt и запасной index.theme для остального
    // applied everywhere: mango (cursor on the desktop and in its windows), GTK, KDE/Qt and a fallback index.theme for the rest
    function applyCursor(): void {
        const t = settings.cursorTheme || "", z = String(settings.cursorSize ?? 24);
        if (!t) return;
        cfgEdit(["sh", "-c",
            'f="$HOME/.config/mango/config.conf"; ' +
            'grep -q "^cursor_theme=" "$f" && sed -i "s/^cursor_theme=.*/cursor_theme=$1/" "$f" || echo "cursor_theme=$1" >> "$f"; ' +
            'grep -q "^cursor_size=" "$f" && sed -i "s/^cursor_size=.*/cursor_size=$2/" "$f" || echo "cursor_size=$2" >> "$f"', "sh", t, z]);
        Quickshell.execDetached(["sh", "-c",
            'gsettings set org.gnome.desktop.interface cursor-theme "$1" 2>/dev/null; gsettings set org.gnome.desktop.interface cursor-size "$2" 2>/dev/null; ' +
            'command -v kwriteconfig6 >/dev/null && { kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$1"; kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize "$2"; }; ' +
            'mkdir -p "$HOME/.icons/default" && printf "[Icon Theme]\\nInherits=%s\\n" "$1" > "$HOME/.icons/default/index.theme"; ' +
            'mmsg dispatch setoption,cursor_theme,"$1" 2>/dev/null; mmsg dispatch setoption,cursor_size,"$2" 2>/dev/null; true', "sh", t, z]);
    }

    // blur_optimized=1 — mango размывает только обои (дёшево); 0 — честно размывает всё, что под окном
    // сила размытия: 0 — выкл; 1–10 → радиус и число проходов (больше 6 — второй проход, мягче, но тяжелее)
    // blur_optimized=1: mango blurs only the wallpaper (cheap); 0: it honestly blurs everything under the window
    // blur strength: 0 off; 1–10 → radius and number of passes (above 6 a second pass: softer but heavier)
    function applyBlur(): void {
        // «настоящая прозрачность» (blur_optimized=0) размывает всё, что под окном, а не только обои.
        // мерцающие рамки в этом режиме чинит патч mango (полная перерисовка, когда что-то меняется)
        // "real transparency" (blur_optimized=0) blurs everything under a window, not just the wallpaper.
        // the mango patch fixes the flickering borders in this mode (full redraw whenever something changes)
        const opt = settings.realBlur ? "0" : "1", k = Math.round(settings.blurStrength ?? 1);
        // сила размытия (размытие «двойным Кавасе») растёт в основном от числа проходов, радиус — добавка
        // blur strength ("dual Kawase" blur) grows mostly with the number of passes; the radius adds a bit
        const on = k > 0 ? "1" : "0", radius = String(4 + k), passes = String(k <= 2 ? 1 : k <= 5 ? 2 : k <= 8 ? 3 : 4);
        for (const [key, val] of [["blur", on], ["blur_optimized", opt], ["blur_params_radius", radius], ["blur_params_num_passes", passes]])
            Quickshell.execDetached(["mmsg", "dispatch", "setoption," + key + "," + val]);
        cfgEdit(["sh", "-c",
            'f="$HOME/.config/mango/config.conf"; sed -i -e "s/^blur=.*/blur=$1/" -e "s/^blur_optimized=.*/blur_optimized=$2/" ' +
            '-e "s/^blur_params_radius=.*/blur_params_radius=$3/" -e "s/^blur_params_num_passes=.*/blur_params_num_passes=$4/" "$f"',
            "sh", on, opt, radius, passes]);
    }
    function applyWindowRadius(): void {
        const r = Math.round(settings.windowRadius ?? 5);
        Quickshell.execDetached(["mmsg", "dispatch", "setoption,border_radius," + r]);
        cfgEdit(["sh", "-c", 'sed -i "s/^border_radius=.*/border_radius=$1/" "$HOME/.config/mango/config.conf"', "sh", String(r)]);
    }

    // тема значков: Quickshell читает её только при запуске (строка pragma в shell.qml),
    // поэтому при смене переписываем строку и перезапускаем шелл; заодно GTK- и Qt-программам
    // icon theme: Quickshell reads it only at startup (the pragma line in shell.qml),
    // so on change we rewrite the line and restart the shell; GTK and Qt apps get it too
    property var iconThemes: []          // установленные темы: ["breeze-dark", "Gruvbox-Plus-Dark", …] / installed themes: ["breeze-dark", "Gruvbox-Plus-Dark", …]
    Process {
        id: themeScan
        running: true
        command: ["sh", "-c", 'for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do ' +
                  'for t in "$d"/*/; do [ -f "$t/index.theme" ] && [ -d "$t/apps" -o -d "$t/scalable" -o -d "$t/48x48" -o -d "$t/symbolic" ] && basename "$t"; done; done | sort -u']
        stdout: StdioCollector { onStreamFinished: st.iconThemes = text.split("\n").filter(x => x && x !== "hicolor" && x !== "default") }
    }
    function applyIconTheme(): void {
        // при старте это вызывается из Component.onCompleted, а он мог сработать раньше, чем прочитан
        // settings.json, — тогда бралась тема по умолчанию, строка pragma переписывалась на неё и шелл
        // перезапускался уже с ней (выбранная тема «слетала» обратно). Поэтому сначала дочитываем файл
        // at start this is called from Component.onCompleted, which could fire before
        // settings.json was read: then the default theme was taken, the pragma line rewritten to it and the shell
        // restarted with it (the chosen theme "fell back"). So the file is read first
        if (!settingsRead) {
            try { settings = Object.assign({}, settings, JSON.parse(setFile.text() || "{}")); settingsRead = true; } catch (e) {}
        }
        const want = settings.iconTheme || "breeze-dark";
        Quickshell.execDetached(["sh", "-c",
            't="$1"; d="$HOME/.local/share/icons/$t"; [ -d "$d" ] || [ -d "/usr/share/icons/$t" ] || [ -d "$HOME/.icons/$t" ] || t=breeze-dark; ' +
            'gsettings set org.gnome.desktop.interface icon-theme "$t" 2>/dev/null; ' +
            'command -v kwriteconfig6 >/dev/null && kwriteconfig6 --file kdeglobals --group Icons --key Theme "$t"; ' +
            'f="$HOME/.config/quickshell/nyashell/shell.qml"; ' +
            'grep -qx "//@ pragma IconTheme $t" "$f" || { sed -i "1s|^//@ pragma IconTheme .*|//@ pragma IconTheme $t|" "$f"; ' +
            'sleep 0.5; sh "$HOME/.config/quickshell/nyashell/restart.sh"; }', "sh", want]);
    }
    // палитра в файл и при старте — её забирает экран входа
    // palette to a file, also at start: the login screen picks it up
    Timer { id: palInit; interval: 2000; onTriggered: { palFile.setText(JSON.stringify(Theme.p)); st.shareWithGreeter(); } }
    // экран входа читает палитру и обои из /var/lib/nyagreet (папку делает установщик доступной нам на запись)
    // the login screen reads the palette and wallpaper from /var/lib/nyagreet (the installer makes that folder writable for us)
    function shareWithGreeter(): void {
        Quickshell.execDetached(["sh", "-c",
            'd=/var/lib/nyagreet; [ -w "$d" ] || exit 0; printf "%s" "$1" > "$d/palette.json.tmp" && mv "$d/palette.json.tmp" "$d/palette.json"; ' +
            '[ -n "$2" ] && [ -f "$2" ] && cp "$2" "$d/wallpaper.tmp" && mv "$d/wallpaper.tmp" "$d/wallpaper"; ' +
            'printf "%s" "$3" > "$d/lang"; chmod a+r "$d"/* 2>/dev/null',
            "sh", JSON.stringify(Theme.p), wallpaper, settings.lang ?? "en"]);
    }
    property bool settingsOpen: false
    property string settingsQuery: ""     // поиск в окне настроек / search in the settings window
    property bool monOpen: false        // монитор системы / system monitor
    property real monX: 400             // над чем открывать (центр цифр нагрузки на панели) / where to open it (centre of the load numbers on the bar)
    property bool locked: false     // экран блокировки / lock screen
    readonly property string lockShot: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nyash-lock.png"
    property real lockShotTime: 0   // чтобы картинка не бралась из кэша / so the picture isn't taken from the cache
    // блокировка: окна «уезжают» со стола (переход на пустую страницу — mango анимирует это сам),
    // остаются одни обои, и уже поверх них появляется экран блокировки с размытием.
    // после разблокировки возвращаемся на прежнюю страницу — окна въезжают обратно.
    // если пустой страницы нет — старый способ: снимок экрана как фон
    // locking: windows "slide off" the desktop (switching to an empty page, mango animates it itself),
    // only the wallpaper stays, and the blurred lock screen appears on top of it.
    // after unlocking we return to the previous page and the windows slide back in.
    // if there is no empty page, the old way: a screenshot as the background
    property int lockReturnTag: 0
    property string lockReturnMon: ""
    function lock(): void {
        if (locked || shooter.running || lockSlide.running) return;
        for (const mon in mangoTags) {
            const tags = mangoTags[mon], cur = tags.find(t => t.is_active);
            const empty = tags.find(t => t.client_count === 0 && !t.is_active);
            if (cur && cur.client_count > 0 && empty) {
                lockReturnTag = cur.index; lockReturnMon = mon;
                lockShotTime = 0;
                Quickshell.execDetached(["mmsg", "dispatch", "view," + empty.index]);
                lockSlide.restart();
                return;
            }
            if (cur && cur.client_count === 0) { lockShotTime = 0; locked = true; return; }   // и так пусто / already empty
        }
        shooter.running = true;
        lockFallback.restart();
    }
    Timer { id: lockSlide; interval: 420; onTriggered: st.locked = true }
    Process {
        id: shooter
        command: ["grim", "-l", "0", st.lockShot]
        onExited: (code) => { st.lockShotTime = code === 0 ? Date.now() : 0; lockFallback.stop(); st.locked = true; }
    }
    // если grim не установлен или завис — блокируем всё равно
    // if grim isn't installed or hangs, lock anyway
    Timer { id: lockFallback; interval: 1200; onTriggered: { shooter.running = false; st.lockShotTime = 0; st.locked = true; } }
    // выход/перезагрузка/выключение: сначала запоминаем открытые приложения
    // log out/reboot/power off: remember the open apps first
    function leave(cmd): void { Session.save(() => Quickshell.execDetached(cmd)); }

    // сон: сначала блокировка, потом засыпание
    // перед сном экран блокировки плавно уходит в чёрное, а не гаснет рывком
    // сон: блокировка → экран блокировки ПОЯВИЛСЯ → плавно в чёрное → только тогда засыпаем.
    // затемнение запускает сам экран блокировки, когда он уже на экране (а не таймер вслепую)
    // sleep: lock first, then sleep
    // before sleep the lock screen fades smoothly to black rather than going off abruptly
    // sleep: lock → the lock screen HAS APPEARED → smoothly to black → only then sleep.
    // the lock screen starts the dimming itself once it's on screen (not a blind timer)
    property bool sleepPending: false       // собираемся спать / about to sleep
    property bool sleepFade: false          // вуаль опущена / the veil is down
    property bool sleepManual: false        // сон по нашей кнопке (иначе — logind сам усыпит) / sleep from our button (otherwise logind puts it to sleep itself)
    signal sleepReady()                     // вуаль опустилась / the veil has come down
    function sleepNow(): void {
        sleepManual = true;
        sleepPending = true;
        lock();
        sleepGuard.restart();
    }
    onSleepReady: {
        sleepGuard.stop();
        if (sleepManual) Quickshell.execDetached(["sh", "-c", "systemctl suspend 2>/dev/null || loginctl suspend"]);
        sleepManual = false;
    }
    // если экран блокировки так и не появился — всё равно засыпаем
    // if the lock screen never appeared, sleep anyway
    Timer { id: sleepGuard; interval: 4000; onTriggered: st.sleepReady() }
    function woke(): void { sleepPending = false; sleepFade = false; }
    onLockedChanged: {
        if (locked) return;
        sleepPending = false; sleepFade = false;
        if (lockReturnTag > 0) {
            Quickshell.execDetached(["mmsg", "dispatch", "view," + lockReturnTag]);
            lockReturnTag = 0;
        }
    }
    property var mangoTags: ({})    // монитор -> теги из mango (заполняет TreeGuard) / monitor -> tags from mango (filled by TreeGuard)
    property var mangoClients: []   // окна из mango (заполняет TreeGuard) / windows from mango (filled by TreeGuard)
    // на этом экране сейчас видно полноэкранное окно? Тогда рамки и панели под ним не видно,
    // и «ящики» (борд, монитор системы) прижимаются прямо к краю экрана
    // is a full-screen window visible on this screen right now? Then the frame and bar under it aren't visible,
    // and the "drawers" (dashboard, system monitor) press right up to the screen edge
    function fullscreenOn(mon: string): bool {
        return mangoClients.some(c => c.is_fullscreen && c.is_visible && (!mon || c.monitor === mon));
    }
    property var fsParked: []       // окна, которые мы вывели из полноэкранного при смене страницы / windows we took out of full screen when switching pages
    property var wallSeeds: []      // главные цвета текущих обоев [{hue, color}] / main colours of the current wallpaper [{hue, color}]
    property real osdQuietUntil: 0  // до этого момента всплывашка громкости молчит (эквалайзер перестраивается) / until this moment the volume popup stays quiet (the equaliser is being rebuilt)

    // ─── запись экрана ───
    // идёт ли запись — смотрим раз в секунду (запускают её и горячие клавиши, и меню)
    // ─── screen recording ───
    // whether recording is running is checked once a second (both hotkeys and the menu start it)
    property bool recording: false
    property real recSince: 0
    // audio: если не задан — из настроек; «both» — звук системы и микрофон вместе
    // audio: if not given, from the settings; "both" is system sound and mic together
    function record(mode: string, audio): void {
        // кадров в секунду, высота кадра и битрейт (кбит/с); 0 — как есть / подбирает кодировщик
        // frames per second, frame height and bitrate (kbit/s); 0 means as is / the encoder decides
        Quickshell.execDetached(["sh", Quickshell.shellPath("record.sh"), mode, audio || (settings.recAudio ?? "system"),
                                 String(settings.recFps ?? 0), String(settings.recHeight ?? 0), String(settings.recBitrate ?? 0)]);
        recCheck.restart();
    }
    function stopRecording(): void { Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]); }
    Process {
        id: recProbe
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: (code) => {
            const on = code === 0;
            if (on && !st.recording) st.recSince = Date.now();
            st.recording = on;
        }
    }
    Timer { id: recCheck; interval: st.recording ? 1000 : 4000; repeat: true; running: true; onTriggered: recProbe.running = true }

    // текущие обои хранятся в файле, чтобы пережить перезапуск
    // the current wallpaper is kept in a file to survive restarts
    property string wallpaper: ""
    FileView {
        id: wallFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/wallpaper.txt"
        blockLoading: true
        printErrors: false
        onLoaded: st.wallpaper = text().trim()
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { st.wallpaper = text().trim() }
}
    // частицы на рабочем столе, как на сайте: "petals" | "stars" | "off"
    // desktop particles, as on the website: "petals" | "stars" | "snow" | "bubbles" | "off"
    property string particles: "petals"
    FileView {
        id: partFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/particles.txt"
        blockLoading: true
        printErrors: false
        onLoaded: { const v = text().trim(); if (v) st.particles = v; }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { const v = text().trim(); if (v) st.particles = v; }
}
    readonly property var particleKinds: ["petals", "stars", "snow", "bubbles", "off"]
    function cycleParticles(): void { setParticles(particleKinds[(particleKinds.indexOf(particles) + 1) % particleKinds.length]); }
    function setParticles(k: string): void { particles = k; partFile.setText(k); }

    // акцентный пресет (см. Theme.palettes)
    // accent preset (see Theme.palettes)
    property string accent: "adaptive"
    FileView {
        id: accentFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/accent.txt"
        blockLoading: true
        printErrors: false
        onLoaded: { const v = text().trim(); if (v) st.accent = v; }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { const v = text().trim(); if (v) st.accent = v; }
}
    // только две схемы: neko и адаптивная (если есть обои)
    // цвета: neko → от обоев → монохром → neko…
    // only two schemes: neko and adaptive (if there is a wallpaper)
    // colours: neko → from the wallpaper → monochrome → neko…
    function cycleAccent(): void {
        setAccent(accent === "neko" ? (wallpaper ? "adaptive" : "mono") : accent === "adaptive" ? "mono" : "neko");
    }
    function setAccent(name: string): void {
        accent = name;
        accentFile.setText(accent);
        if (!restoringWall) rememberWall();
    }

    // ─── цвета запоминаются для каждых обоев ───
    // вернулся к прежним обоям — вернулись и их цвета (режим, выбранный цвет из обоев, схема)
    // ─── colours are remembered per wallpaper ───
    // go back to a previous wallpaper and its colours come back too (mode, chosen wallpaper colour, scheme)
    property bool restoringWall: false
    function rememberWall(): void {
        if (!wallpaper) return;
        const all = Object.assign({}, settings.wallPrefs ?? {});
        all[wallpaper] = { accent: accent, seedHue: settings.seedHue ?? -1, scheme: settings.scheme ?? "tonal" };
        restoringWall = true; set("wallPrefs", all); restoringWall = false;
    }
    // при запуске обои просто читаются из файла — это не смена обоев, их цвета восстанавливать не нужно
    // (иначе при старте, пока не прочитаны настройки, цвет из обоев сбрасывался на «авто»)
    // at startup the wallpaper is simply read from the file: that's not a wallpaper change, its colours needn't be restored
    // (otherwise at start, before the settings were read, the wallpaper colour was reset to "auto")
    property bool startupDone: false
    onWallpaperChanged: {
        shareWithGreeter();
        if (!wallpaper || !startupDone) return;
        const p = (settings.wallPrefs ?? {})[wallpaper];
        restoringWall = true;
        if (p) {
            if (p.accent && p.accent !== accent) { accent = p.accent; accentFile.setText(accent); }
            if ((p.seedHue ?? -1) !== (settings.seedHue ?? -1)) set("seedHue", p.seedHue ?? -1);
            if (p.scheme && p.scheme !== (settings.scheme ?? "tonal")) set("scheme", p.scheme);
        } else if ((settings.seedHue ?? -1) !== -1) set("seedHue", -1);   // новые обои — цвет из них «авто» / a new wallpaper: its colour is "auto"
        restoringWall = false;
    }
    // рамка активного окна в mango — тем же акцентом, полупрозрачно
    // the active window's border in mango: the same accent, translucent
    onAccentChanged: syncMango()
    onAdaptiveChanged: if (accent === "adaptive") syncMango()
    function syncMango(): void {
        const hex = String(Theme.p.accent).replace("#", "");
        Quickshell.execDetached(["mmsg", "dispatch", "setoption,focuscolor,0x" + hex + "66"]);
    }

    // закреплённые на панели приложения (app_id окна)
    // apps pinned to the bar (window app_id)
    property var pinned: []
    FileView {
        id: pinFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/pinned.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { st.pinned = JSON.parse(text()); } catch (e) { st.pinned = []; } }
        // при blockLoading файл читается ещё до того, как подключается onLoaded, — сигнал теряется.
        // поэтому то же самое делаем и сразу после создания (иначе настройки «слетали» на стандартные)
        // with blockLoading the file is read before onLoaded is connected, so the signal is lost.
        // so we do the same right after creation too (otherwise the settings "fell back" to the defaults)
        Component.onCompleted: if (text()) { try { st.pinned = JSON.parse(text()); } catch (e) { st.pinned = []; } }
}
    function togglePin(appId: string): void {
        const p = pinned.slice(), i = p.indexOf(appId);
        if (i >= 0) p.splice(i, 1); else p.push(appId);
        pinned = p;
        pinFile.setText(JSON.stringify(p));
    }

    // адаптивная палитра: считается из обоев (см. Wallpaper.qml). При старте сразу берём
    // последнюю сохранённую — иначе шелл пару секунд был в neko, пока считались обои
    // adaptive palette: computed from the wallpaper (see Wallpaper.qml). At start the last saved one
    // is taken right away, otherwise the shell sat in neko for a couple of seconds while the wallpaper was analysed
    property var adaptive: {
        try { const p = JSON.parse(palStart.text()); return p && p.name !== "neko" && p.name !== "mono" ? p : null; } catch (e) { return null; }
    }
    FileView { id: palStart; path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/palette.json"; blockLoading: true; printErrors: false }

    // текущая палитра — в файл, её забирает установщик экрана входа
    // the current palette goes to a file; the login screen installer picks it up
    FileView {
        id: palFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nyashell/palette.json"
        printErrors: false
    }
    Connections {
        target: Theme
        function onPChanged() { palFile.setText(JSON.stringify(Theme.p)); st.shareWithGreeter(); }
    }

    function setWallpaper(path: string): void {
        wallpaper = path;
        wallFile.setText(path);
    }
}
