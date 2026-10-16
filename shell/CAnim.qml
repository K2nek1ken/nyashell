import QtQuick

// смена цвета — «эффектная» кривая caelestia
// colour change: caelestia's "effects" curve
ColorAnimation {
    duration: Tokens.dur.defaultEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tokens.defaultEffects
}
