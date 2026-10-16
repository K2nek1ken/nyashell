import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// рамка вокруг экрана как у caelestia: сплошная, со скруглёнными внутренними углами.
// Снизу она толще — это фон нижней панели. Сама рамка клики не ловит.
// a frame around the screen like caelestia's: solid, with rounded inner corners.
// It is thicker at the bottom, which is the bottom bar's background. The frame itself doesn't catch clicks.
Scope {
    id: root
    required property var modelData

    // резервируем место по краям (снизу место резервирует сама панель)
    // reserve space at the edges (the bar reserves the space at the bottom itself)
    component Edge: PanelWindow {
        screen: root.modelData
        color: "transparent"
        exclusiveZone: Tokens.frame
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
    }
    Edge { anchors.top: true }
    Edge { anchors.left: true }
    Edge { anchors.right: true }

    PanelWindow {
        id: fr
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        // рамка и фон панели — в том же слое, что и значки панели (Top): перетаскиваемое плавающее окно
        // уходит под всю панель целиком, а не оказывается между фоном и значками.
        // полноэкранные окна у mango всё равно выше этого слоя
        // the frame and bar background are in the same layer as the bar icons (Top): a dragged floating window
        // goes under the whole bar rather than ending up between the background and the icons.
        // mango's full-screen windows are above this layer anyway
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"
        mask: Region {}

        readonly property real t: Tokens.frame
        readonly property real b: Tokens.barHeight
        readonly property real r: Tokens.frameRadius

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.frame
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                Behavior on fillColor { CAnim {} }

                // внешний прямоугольник — весь экран
                // outer rectangle: the whole screen
                startX: 0; startY: 0
                PathLine { x: fr.width; y: 0 }
                PathLine { x: fr.width; y: fr.height }
                PathLine { x: 0; y: fr.height }
                PathLine { x: 0; y: 0 }

                // «окно» со скруглёнными углами — дырка
                // the rounded "window": the hole
                PathMove { x: fr.t + fr.r; y: fr.t }
                PathLine { x: fr.width - fr.t - fr.r; y: fr.t }
                PathArc  { x: fr.width - fr.t; y: fr.t + fr.r; radiusX: fr.r; radiusY: fr.r }
                PathLine { x: fr.width - fr.t; y: fr.height - fr.b - fr.r }
                PathArc  { x: fr.width - fr.t - fr.r; y: fr.height - fr.b; radiusX: fr.r; radiusY: fr.r }
                PathLine { x: fr.t + fr.r; y: fr.height - fr.b }
                PathArc  { x: fr.t; y: fr.height - fr.b - fr.r; radiusX: fr.r; radiusY: fr.r }
                PathLine { x: fr.t; y: fr.t + fr.r }
                PathArc  { x: fr.t + fr.r; y: fr.t; radiusX: fr.r; radiusY: fr.r }
            }
        }
    }

    // скруглённые углы экрана (настройки → «Скругление углов экрана»): чёрные «уголки» поверх всего
    // rounded screen corners (settings → "Screen corner rounding"): black "corners" on top of everything
    PanelWindow {
        id: corners
        screen: root.modelData
        visible: (ShellState.settings.screenRadius ?? 0) > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        mask: Region {}
        readonly property real sr: ShellState.settings.screenRadius ?? 0
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "black"
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                startX: 0; startY: 0
                PathLine { x: corners.width; y: 0 }
                PathLine { x: corners.width; y: corners.height }
                PathLine { x: 0; y: corners.height }
                PathLine { x: 0; y: 0 }
                PathMove { x: corners.sr; y: 0 }
                PathLine { x: corners.width - corners.sr; y: 0 }
                PathArc  { x: corners.width; y: corners.sr; radiusX: corners.sr; radiusY: corners.sr }
                PathLine { x: corners.width; y: corners.height - corners.sr }
                PathArc  { x: corners.width - corners.sr; y: corners.height; radiusX: corners.sr; radiusY: corners.sr }
                PathLine { x: corners.sr; y: corners.height }
                PathArc  { x: 0; y: corners.height - corners.sr; radiusX: corners.sr; radiusY: corners.sr }
                PathLine { x: 0; y: corners.sr }
                PathArc  { x: corners.sr; y: 0; radiusX: corners.sr; radiusY: corners.sr }
            }
        }
    }
}
