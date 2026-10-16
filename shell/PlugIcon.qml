import QtQuick
import QtQuick.Shapes

// вилка (рисунок неко): провод слева, корпус, пластина и два штыря справа.
// Рисуется в исходных координатах 7430×3969 и масштабируется под ширину
// plug (neko's drawing): cord on the left, body, plate and two prongs on the right.
// Drawn in the original 7430×3969 coordinates and scaled to the width
Item {
    id: pi
    property color color: Theme.accent
    implicitWidth: 16
    implicitHeight: width * 3969.36 / 7430.28
    readonly property real k: width / 7430.28
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: pi.color
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            scale: Qt.size(pi.k, pi.k)
            PathSvg {
                path: "M5380.42 784.71 L6930.28 784.71 C7206.43 784.71 7430.28 978.31 7430.28 1217.13 C7430.28 1455.95 7206.43 1649.55 6930.28 1649.55 L5380.42 1649.55 Z " +
                      "M5380.42 2319.81 L6930.28 2319.81 C7206.43 2319.81 7430.28 2513.41 7430.28 2752.23 C7430.28 2991.05 7206.43 3184.65 6930.28 3184.65 L5380.42 3184.65 Z " +
                      "M0 1984.68 C0 1745.86 223.86 1552.26 500 1552.26 L2562.87 1552.26 L2562.87 2417.1 L500 2417.1 C223.86 2417.1 0 2223.5 0 1984.68 Z " +
                      "M4782.13 432.42 A432.42 432.42 0 0 1 5646.97 432.42 L5646.97 3536.94 A432.42 432.42 0 0 1 4782.13 3536.94 Z " +
                      "M2472.53 1552.11 C2472.53 999.83 2920.24 552.11 3472.53 552.11 L4872.47 552.11 L4872.47 3509.51 L3472.53 3509.51 C2920.24 3509.51 2472.53 3061.79 2472.53 2509.51 Z"
            }
        }
    }
}
