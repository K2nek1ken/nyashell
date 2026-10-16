import QtQuick
import QtQuick.Shapes

// значок-ключ VPN (по твоему SVG, холст 318×169.42): толстое кольцо слева, стержень вправо, один зубец вниз
// VPN key icon (from your SVG, canvas 318×169.42): a thick ring on the left, a shaft to the right, one tooth down
Item {
    id: k
    property real size: 18
    property color color: Theme.text
    width: size; height: size * 169.42 / 318
    readonly property real s: size / 318
    readonly property real lw: 56.4 * s
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: k.color; strokeWidth: k.lw
            PathAngleArc { centerX: 84.71 * k.s; centerY: 84.71 * k.s; radiusX: 56.51 * k.s; radiusY: 56.51 * k.s; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"; strokeColor: k.color; strokeWidth: k.lw; capStyle: ShapePath.RoundCap
            startX: 145.86 * k.s; startY: 84.71 * k.s
            PathLine { x: 289.8 * k.s; y: 84.71 * k.s }
        }
        ShapePath {
            fillColor: "transparent"; strokeColor: k.color; strokeWidth: k.lw; capStyle: ShapePath.RoundCap
            startX: 259.03 * k.s; startY: 90.5 * k.s
            PathLine { x: 259.03 * k.s; y: 141.22 * k.s }
        }
    }
}
