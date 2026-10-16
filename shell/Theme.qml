pragma Singleton
import Quickshell
import QtQuick

// палитры: neko (Material You, «содержательный») и адаптивная из обоев
// пресет выбирается через ПКМ по рабочему столу → «акцент» и запоминается
// palettes: neko (Material You, "content") and an adaptive one from the wallpaper
// the preset is chosen via right-click on the desktop → "accent" and remembered
Singleton {
    // neko — палитра Material You в стиле «содержательный», снята со скриншота телефона
    // neko: a Material You palette in the "content" style, taken from a phone screenshot
    readonly property var neko: ({
        name: "neko", frame: "#191616",
        bg: "#e01d1414", surface: "#271e1e", surfaceHi: "#322828", line: "#493e3e",
        accent: "#dfbfbe", accent2: "#d7c4aa", onAccent: "#402b2b",
        text: "#f2ebea", textDim: "#b0a1a0"
    })
    // монохромная — без цвета, только оттенки серого
    // monochrome: no colour, only shades of grey
    readonly property var mono: ({
        name: "mono", frame: "#121212", bg: "#e0151515", surface: "#1c1c1c", surfaceHi: "#272727", line: "#3a3a3a",
        accent: "#e8e8e8", accent2: "#b8b8b8", onAccent: "#161616", text: "#f2f2f2", textDim: "#9c9c9c", danger: "#ff8a80"
    })
    readonly property var palettes: ({ neko: neko, mono: mono })
    // адаптивная — только если есть обои и палитра уже посчитана
    // adaptive: only if there is a wallpaper and the palette has been computed
    readonly property var p: ShellState.accent === "mono" ? mono
                           : (ShellState.accent === "adaptive" && ShellState.wallpaper && ShellState.adaptive) ? ShellState.adaptive : neko

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
    // шрифт интерфейса — из настроек, если он установлен; значки всегда из Neon (он лежит в архиве)
    // UI font from the settings if it's installed; icons always come from Neon (it ships in the archive)
    readonly property var families: Qt.fontFamilies()
    // свой шрифт из файла подгружается сразу, без перезапуска (FontLoader), а в остальном — по имени из системы
    // a custom font from a file is loaded right away, no restart (FontLoader); otherwise by name from the system
    FontLoader { id: userFont; source: ShellState.settings.uiFontFile ? "file://" + ShellState.settings.uiFontFile : "" }
    readonly property string font: (ShellState.settings.uiFontFile && userFont.status === FontLoader.Ready) ? userFont.name
                                 : families.includes(ShellState.settings.uiFont ?? "") ? ShellState.settings.uiFont : iconFont
    readonly property string iconFont: families.includes("Nyaspace") ? "Nyaspace" : families.includes("Monaspace Neon Var") ? "Monaspace Neon Var" : "Monaspace Neon NF"
    readonly property int radius: 16
    readonly property int radiusSm: 12
    readonly property int anim: 180
}
