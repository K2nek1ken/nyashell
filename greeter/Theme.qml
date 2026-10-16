pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// приёмы с NyashBoard + любимые акценты Неко: пастельно-розовый и оранжевые
// пресет выбирается через ПКМ по рабочему столу → «акцент» и запоминается
// NyashBoard tricks + Neko's favourite accents: pastel pink and oranges
// the preset is chosen via right-click on the desktop → "accent" and remembered
Singleton {
    // neko — палитра с телефона Неко (Material You, «содержательный»), снята со скриншота
    // neko: the palette from Neko's phone (Material You, "content"), taken from a screenshot
    readonly property var neko: ({
        name: "neko", frame: "#191616",
        bg: "#e01d1414", surface: "#271e1e", surfaceHi: "#322828", line: "#493e3e",
        accent: "#dfbfbe", accent2: "#d7c4aa", onAccent: "#402b2b",
        text: "#f2ebea", textDim: "#b0a1a0"
    })
    readonly property var palettes: ({ neko: neko })
    // адаптивная — только если есть обои и палитра уже посчитана
    // экран входа: neko, либо палитра, которую установщик сохранил в palette.json
    // палитра: сначала та, что шелл кладёт при каждой смене цветов (/var/lib/nyagreet), иначе — копия с установки.
    // читаем через text() прямо в привязке: onLoaded у FileView с blockLoading успевал сработать
    // до того, как к нему подключался обработчик, и экран входа оставался в neko
    // adaptive: only if there is a wallpaper and the palette has been computed
    // login screen: neko, or the palette the installer saved in palette.json
    // palette: first the one the shell writes on every colour change (/var/lib/nyagreet), otherwise the copy from install.
    // read with text() right in the binding: onLoaded of a FileView with blockLoading could fire
    // before the handler was connected, and the login screen stayed on neko
    FileView { id: shared; path: "/var/lib/nyagreet/palette.json"; blockLoading: true; printErrors: false; watchChanges: true; onFileChanged: reload() }
    FileView { id: bundled; path: Quickshell.shellPath("palette.json"); blockLoading: true; printErrors: false }
    readonly property var saved: {
        for (const f of [shared, bundled]) {
            try { const j = JSON.parse(f.text()); if (j && j.frame) return j; } catch (e) {}
        }
        return null;
    }
    readonly property var p: saved ?? neko
    // язык — тот же, что выбран в шелле (шелл кладёт его в /var/lib/nyagreet/lang); по умолчанию английский
    // language: the same as chosen in the shell (the shell writes it to /var/lib/nyagreet/lang); English by default
    FileView { id: langFile; path: "/var/lib/nyagreet/lang"; blockLoading: true; printErrors: false; watchChanges: true; onFileChanged: reload() }
    readonly property string lang: (langFile.text() || "en").trim() === "ru" ? "ru" : "en"
    function tr(en: string, ru: string): string { return lang === "ru" ? ru : en; }

    readonly property color frame:     p.frame      // рамка экрана и нижняя панель (сплошные) / screen frame and bottom bar (solid)
    readonly property color bg:        p.bg
    readonly property color surface:   p.surface
    readonly property color surfaceHi: p.surfaceHi
    readonly property color line:      p.line
    readonly property color accent:    p.accent
    readonly property color accent2:   p.accent2
    readonly property color onAccent:  p.onAccent
    readonly property color text:      p.text
    readonly property color textDim:   p.textDim
    readonly property color danger:    "#ef6f6f"

    // ─── Pixel × Caelestia ───
    // декоративная полупрозрачная обводка (ради красоты, как в caelestia)
    // ─── Pixel × Caelestia ───
    // decorative translucent outline (just for looks, as in caelestia)
    readonly property color outline:   Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    // тональные слои Material 3: акцент, едва подмешанный к фону
    // Material 3 tonal layers: the accent barely mixed into the background
    readonly property color tonal:     Qt.rgba(accent.r, accent.g, accent.b, 0.14)
    readonly property color tonalHi:   Qt.rgba(accent.r, accent.g, accent.b, 0.24)
    // «state layer» при наведении
    // hover "state layer"
    readonly property color hover:     Qt.rgba(text.r, text.g, text.b, 0.07)
    readonly property int radiusLg: 26          // большие карточки (M3 extra-large) / large cards (M3 extra-large)
    // пружинка: чуть-чуть перелёта, быстро оседает
    // spring: a tiny overshoot that settles quickly
    readonly property int springMs: 340
    readonly property var families: Qt.fontFamilies()
    readonly property string font: families.includes("Nyaspace") ? "Nyaspace" : families.includes("Monaspace Neon Var") ? "Monaspace Neon Var" : "Monaspace Neon NF"
    readonly property string iconFont: font
    readonly property int radius: 16
    readonly property int radiusSm: 12
    readonly property int anim: 180
}
