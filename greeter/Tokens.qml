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

    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
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
    readonly property QtObject font: QtObject {
        readonly property int small: 11
        readonly property int smaller: 12
        readonly property int normal: 13
        readonly property int larger: 15
        readonly property int large: 18
        readonly property int extraLarge: 28
    }

    // рамка вокруг экрана и нижняя панель
    // the frame around the screen and the bottom bar
    readonly property int frame: 8
    readonly property int barHeight: 54
    readonly property int frameRadius: 24
}
