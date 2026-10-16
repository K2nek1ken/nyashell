import QtQuick
import QtQuick.Shapes

// самолётик подключения из Exclave (github.com/dyhkwong/Exclave, GPL-3.0, как и nyashell):
// выключено — контур с прорезями, включено — прорези схлопываются и самолётик становится сплошным.
// Переход — та же морф-анимация пути, что у Exclave (ic_service_connected.xml): числа пути плавно
// перетекают из одного состояния в другое. busy — подключаемся: самолётик мягко пульсирует
// the connect paper plane from Exclave (github.com/dyhkwong/Exclave, GPL-3.0, same as nyashell):
// off is an outline with cut-outs, on: the cut-outs collapse and the plane becomes solid.
// The transition is the same path-morph animation as in Exclave (ic_service_connected.xml): the path's numbers
// flow smoothly from one state to the other. busy means connecting: the plane gently pulses
Item {
    id: pi
    property real size: 18
    property color color: Theme.text
    property bool on: false
    property bool busy: false
    width: size; height: size

    // 0 — с прорезями, 1 — сплошной / 0: with cut-outs, 1: solid
    property real t: on ? 1 : 0
    Behavior on t { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] } }

    // пути из ic_service_connected.xml: одинаковые команды, разные числа — их и смешиваем
    // paths from ic_service_connected.xml: the same commands, different numbers, which we blend
    readonly property string from: "M 17.68 9 L 16.09 16 L 12.7 14.89 L 17.7 8.96 M 10 10.08 L 6.43 13.08 L 5 12.55 L 10 10.08 M 21.25 2.28 L 0 12.8 L 6.83 15.37 L 16.59 7.16 L 9.26 15.89 L 17.55 18.56 L 21.25 2.29 L 21.25 2.29 Z M 9.45 17.56 L 9.46 22 L 12.09 18.41 L 9.45 17.56 L 9.45 17.56 Z"
    readonly property string to: "M 15.5 13.28 L 15.5 13.28 L 15.5 13.28 L 15.5 13.28 M 7.14 11.9 L 7.14 11.9 L 7.14 11.9 L 7.14 11.9 M 21.25 2.28 L 0 12.8 L 6.83 15.37 L 16.59 7.16 L 9.26 15.89 L 17.55 18.56 L 21.25 2.29 L 21.25 2.29 Z M 9.45 17.56 L 9.46 22 L 12.09 18.41 L 9.45 17.56 L 9.45 17.56 Z"
    readonly property var a: from.split(" ")
    readonly property var b: to.split(" ")
    readonly property string path: {
        const k = t, out = [];
        for (let i = 0; i < a.length; i++) {
            const x = parseFloat(a[i]);
            out.push(isNaN(x) ? a[i] : (x + (parseFloat(b[i]) - x) * k).toFixed(3));
        }
        return out.join(" ");
    }

    Shape {
        anchors.centerIn: parent
        width: 24; height: 24
        scale: pi.size / 24
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: pi.color
            strokeWidth: -1
            fillRule: ShapePath.WindingFill        // как у Android по умолчанию / like Android's default
            PathSvg { path: pi.path }
        }
    }

    SequentialAnimation on opacity {
        running: pi.busy; loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        onStopped: pi.opacity = 1
    }
}
