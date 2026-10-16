import QtQuick
import QtQuick.Shapes

// круговой индикатор: дуга на 270°, значок в центре
// circular gauge: a 270° arc, icon in the centre
Item {
    id: g
    property real value: 0
    property string icon: ""
    property real size: 64
    property real thickness: 6
    property color color: Theme.accent
    width: size
    height: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.surfaceHi
            strokeWidth: g.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: g.size / 2; centerY: g.size / 2
                radiusX: (g.size - g.thickness) / 2; radiusY: radiusX
                startAngle: 135; sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: g.color
            strokeWidth: g.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: g.size / 2; centerY: g.size / 2
                radiusX: (g.size - g.thickness) / 2; radiusY: radiusX
                startAngle: 135
                sweepAngle: 270 * Math.max(0.001, Math.min(1, g.value))
                Behavior on sweepAngle { Anim { kind: "slowEffects" } }
            }
        }
    }
    Icon { anchors.centerIn: parent; name: g.icon; size: g.size * 0.26; color: Theme.text }
}
