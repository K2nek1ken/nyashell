import QtQuick
import QtQuick.Shapes

// фигуры Material 3 Expressive (солнышко, печенька, цветок…) как ломаные — замена M3Shapes caelestia
// Material 3 Expressive shapes (sunny, cookie, flower…) as polylines, replacing caelestia's M3Shapes
Shape {
    id: sh
    property int kind: 0
    property color color: Theme.accent
    property real size: 24
    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer

    // радиус по углу для каждой фигуры (в долях половины размера)
    // radius by angle for each shape (as a fraction of half the size)
    function radiusAt(k: int, a: real): real {
        switch (k) {
        case 0: return 0.82 + 0.18 * Math.cos(8 * a);              // солнышко / sunny
        case 1: return 0.86 + 0.14 * Math.cos(6 * a);              // печенька / cookie
        case 2: return 0.72 + 0.28 * Math.pow(Math.abs(Math.cos(2 * a)), 0.6); // клевер / clover
        case 3: return 0.9 / Math.cos(((a % (2 * Math.PI / 3)) + 2 * Math.PI / 3) % (2 * Math.PI / 3) - Math.PI / 3) * 0.55; // треугольник / triangle
        case 4: return 0.95 / (Math.abs(Math.cos(a)) + Math.abs(Math.sin(a)));                 // ромб / diamond
        case 5: return 0.9 * Math.cos(Math.PI / 5) / Math.cos(((a + Math.PI / 2) % (2 * Math.PI / 5)) - Math.PI / 5); // пятиугольник / pentagon
        case 6: return 0.9 * Math.cos(Math.PI / 6) / Math.cos((a % (Math.PI / 3)) - Math.PI / 6); // шестиугольник / hexagon
        default: return 0.8 + 0.2 * Math.cos(10 * a);              // мягкий взрыв / soft burst
        }
    }
    readonly property var points: {
        const out = [], n = 72, h = size / 2;
        for (let i = 0; i <= n; i++) {
            const a = i / n * 2 * Math.PI;
            const r = Math.min(1, radiusAt(kind, a)) * h;
            out.push(Qt.point(h + r * Math.cos(a - Math.PI / 2), h + r * Math.sin(a - Math.PI / 2)));
        }
        return out;
    }
    ShapePath {
        fillColor: sh.color
        strokeWidth: -1
        PathPolyline { path: sh.points }
    }
}
