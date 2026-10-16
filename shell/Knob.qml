import QtQuick
import QtQuick.Shapes

// крутилка: тянуть вверх/вниз или колесо. log — логарифмическая шкала (для частоты)
// a knob: drag up/down or use the wheel. log: a logarithmic scale (for frequency)
Item {
    id: k
    property real value: 0
    property real from: 0
    property real to: 1
    property bool log: false
    property real step: 0.02            // доля шкалы на щелчок колеса / share of the scale per wheel click
    property color color: Theme.accent
    property string label: ""
    property string text: ""
    property real size: 52
    signal moved(real v)
    width: size; height: size + 30

    function toNorm(v: real): real {
        return log ? Math.log(v / from) / Math.log(to / from) : (v - from) / (to - from);
    }
    function fromNorm(n: real): real {
        n = Math.max(0, Math.min(1, n));
        return log ? from * Math.pow(to / from, n) : from + n * (to - from);
    }
    readonly property real norm: Math.max(0, Math.min(1, toNorm(value)))

    Item {
        id: dial
        width: k.size; height: k.size
        Rectangle { anchors.fill: parent; anchors.margins: 6; radius: width / 2; color: Theme.surfaceHi }
        // дуга 270° и значение
        // 270° arc and value
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: Theme.line; strokeWidth: 3; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: k.size / 2; centerY: k.size / 2; radiusX: k.size / 2 - 2; radiusY: k.size / 2 - 2
                               startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: k.color; strokeWidth: 3; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: k.size / 2; centerY: k.size / 2; radiusX: k.size / 2 - 2; radiusY: k.size / 2 - 2
                               startAngle: 135; sweepAngle: 270 * k.norm }
            }
        }
        // указатель
        // pointer
        Rectangle {
            width: 3; height: k.size * 0.18; radius: 1.5; color: Theme.text
            x: k.size / 2 - 1.5; y: 10
            transform: Rotation { origin.x: 1.5; origin.y: k.size / 2 - 10; angle: -135 + 270 * k.norm }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeVerCursor
            property real y0: 0
            property real n0: 0
            onPressed: (e) => { y0 = e.y; n0 = k.norm; }
            onPositionChanged: (e) => k.moved(k.fromNorm(n0 + (y0 - e.y) / 160))
            onWheel: (e) => k.moved(k.fromNorm(k.norm + (e.angleDelta.y > 0 ? k.step : -k.step)))
        }
    }
    Column {
        y: k.size + 2
        anchors.horizontalCenter: parent.horizontalCenter
        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small
               color: Theme.textDim; text: k.label }
        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small
               font.bold: true; color: Theme.text; text: k.text }
    }
}
