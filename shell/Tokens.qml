pragma Singleton
import Quickshell
import QtQuick

// дизайн-токены из caelestia (plugin/src/Caelestia/Config/tokens.hpp, GPL-3.0):
// кривые Material 3 Expressive, длительности, скругления, отступы, размеры шрифта
// design tokens from caelestia (plugin/src/Caelestia/Config/tokens.hpp, GPL-3.0):
// Material 3 Expressive curves, durations, radii, spacing, font sizes
Singleton {
    // кривые — формат QML BezierSpline: [c1x, c1y, c2x, c2y, x, y, ...]
    // curves are in QML BezierSpline format: [c1x, c1y, c2x, c2y, x, y, ...]
    readonly property var emphasized:      [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
    readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var standard:        [0.2, 0, 0, 1, 1, 1]
    readonly property var standardAccel:   [0.3, 0, 1, 1, 1, 1]
    readonly property var standardDecel:   [0, 0, 0, 1, 1, 1]
    readonly property var fastSpatial:     [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var defaultSpatial:  [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var slowSpatial:     [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var fastEffects:     [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var defaultEffects:  [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var slowEffects:     [0.34, 0.88, 0.34, 1, 1, 1]

    readonly property QtObject dur: QtObject {
        readonly property int small: 200
        readonly property int normal: 400
        readonly property int large: 600
        readonly property int extraLarge: 1000
        readonly property int fastSpatial: 350
        readonly property int defaultSpatial: 500
        readonly property int slowSpatial: 650
        readonly property int fastEffects: 150
        readonly property int defaultEffects: 200
        readonly property int slowEffects: 300
    }

    // множитель скруглений интерфейса (настройки → «Скругление интерфейса», в процентах)
    // UI rounding multiplier (settings → "UI rounding", in percent)
    readonly property real roundK: (ShellState.settings.uiRound ?? 100) / 100
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: Math.round(4 * Tokens.roundK)
        readonly property int small: Math.round(8 * Tokens.roundK)
        readonly property int medium: Math.round(12 * Tokens.roundK)
        readonly property int large: Math.round(16 * Tokens.roundK)
        readonly property int largeIncreased: Math.round(20 * Tokens.roundK)
        readonly property int extraLarge: Math.round(28 * Tokens.roundK)
        readonly property int extraLargeIncreased: Math.round(32 * Tokens.roundK)
        readonly property int extraExtraLarge: Math.round(48 * Tokens.roundK)
    }
    // spacing и padding у caelestia одинаковые — одна шкала
    // caelestia's spacing and padding are the same scale
    readonly property QtObject gap: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
    }
    // размеры под человека (настройки → Look): шрифт, панель, значки — в процентах
    // sizes for humans (settings → Look): font, bar, icons, in percent
    readonly property real fontK: (ShellState.settings.fontScale ?? 100) / 100
    readonly property real iconK: (ShellState.settings.iconScale ?? 100) / 100
    readonly property QtObject font: QtObject {
        readonly property int small: Math.round(11 * Tokens.fontK)
        readonly property int smaller: Math.round(12 * Tokens.fontK)
        readonly property int normal: Math.round(13 * Tokens.fontK)
        readonly property int larger: Math.round(15 * Tokens.fontK)
        readonly property int large: Math.round(18 * Tokens.fontK)
        readonly property int extraLarge: Math.round(28 * Tokens.fontK)
    }

    // рамка вокруг экрана и нижняя панель
    // the frame around the screen and the bottom bar
    readonly property int frame: 8
    readonly property int barHeight: ShellState.settings.barHeight ?? 54
    readonly property int frameRadius: ShellState.settings.frameRadius ?? 24
}
