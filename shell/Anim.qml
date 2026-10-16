import QtQuick

// анимация в стиле caelestia: kind = "spatial" | "fastSpatial" | "slowSpatial" |
// "effects" | "fastEffects" | "slowEffects" | "emphasized" | "standard"
// caelestia-style animation: kind = "spatial" | "fastSpatial" | "slowSpatial" |
// "effects" | "fastEffects" | "slowEffects" | "emphasized" | "standard"
NumberAnimation {
    property string kind: "spatial"
    readonly property var table: ({
        spatial:     [Tokens.defaultSpatial, Tokens.dur.defaultSpatial],
        fastSpatial: [Tokens.fastSpatial,    Tokens.dur.fastSpatial],
        slowSpatial: [Tokens.slowSpatial,    Tokens.dur.slowSpatial],
        effects:     [Tokens.defaultEffects, Tokens.dur.defaultEffects],
        fastEffects: [Tokens.fastEffects,    Tokens.dur.fastEffects],
        slowEffects: [Tokens.slowEffects,    Tokens.dur.slowEffects],
        emphasized:  [Tokens.emphasized,     Tokens.dur.normal],
        standard:    [Tokens.standard,       Tokens.dur.normal]
    })
    duration: (table[kind] ?? table.spatial)[1]
    easing.type: Easing.BezierSpline
    easing.bezierCurve: (table[kind] ?? table.spatial)[0]
}
