import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// всплывающие уведомления — «ящик» в правом верхнем углу рамки (стыкуется и с верхом, и с правым краем)
// notification popups: a "drawer" in the top-right corner of the frame (joins both the top and the right edge)
PanelWindow {
    id: win
    // полноэкранное окно на этом экране: рамки не видно — ящик уведомлений прилипает прямо к углу экрана
    // a full-screen window on this screen: no frame visible, the notification drawer sticks right to the screen corner
    readonly property bool fs: ShellState.fullscreenOn(screen?.name ?? "")
    readonly property real t: fs ? 0 : Tokens.frame
    readonly property real r: Tokens.frameRadius
    readonly property real bigR: Tokens.rounding.extraLarge
    readonly property real cw: 360                        // ширина карточек / card width
    readonly property real pad: 6           // поля вокруг карточек / margins around the cards
    property int relayout: 0
    readonly property real target: Notifs.popups.length
        ? Math.max(list.implicitHeight, list.childrenRect.height) + win.pad * 2 + relayout * 0 : 0
    Connections { target: Notifs; function onPopupsChanged() { settle1.restart(); settle2.restart(); } }
    Timer { id: settle1; interval: 60;  onTriggered: win.relayout++ }
    Timer { id: settle2; interval: 400; onTriggered: win.relayout++ }
    property real hh: target
    Behavior on hh { Anim { kind: win.target > win.hh ? "spatial" : "emphasized" } }

    anchors { top: true; right: true }
    implicitWidth: r + cw + win.pad * 2 + t
    implicitHeight: 720
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: body }
    visible: hh > 0.5 || target > 0

    Item {
        id: body
        x: win.r
        width: win.width - win.r
        height: win.hh > 0.5 ? win.t + win.hh : 0
    }

    Shape {
        id: shp
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real leftX: win.r
        readonly property real fullW: win.width
        readonly property real bottomY: win.t + win.hh
        readonly property real rr: Math.min(win.r, win.hh / 2)
        readonly property real curR: Math.min(win.bigR, win.hh / 2)
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            startX: shp.leftX - shp.rr; startY: 0
            PathLine { x: shp.leftX - shp.rr; y: win.t }
            PathArc  { x: shp.leftX; y: win.t + shp.rr; radiusX: shp.rr; radiusY: shp.rr }
            PathLine { x: shp.leftX; y: shp.bottomY - shp.curR }
            PathArc  { x: shp.leftX + shp.curR; y: shp.bottomY; radiusX: shp.curR; radiusY: shp.curR; direction: PathArc.Counterclockwise }
            PathLine { x: shp.fullW - win.t - shp.rr; y: shp.bottomY }
            PathArc  { x: shp.fullW - win.t; y: shp.bottomY + shp.rr; radiusX: shp.rr; radiusY: shp.rr }
            PathLine { x: shp.fullW; y: shp.bottomY + shp.rr }
            PathLine { x: shp.fullW; y: 0 }
        }
    }

    Item {
        x: win.r
        y: win.t
        width: win.cw + win.pad * 2
        height: win.hh
        clip: true

        Column {
            id: list
            x: win.pad
            y: win.hh - implicitHeight - win.pad
            width: win.cw
            spacing: Tokens.gap.small

            Repeater {
                model: Notifs.popups
                delegate: NotifCard {
                    required property var modelData
                    width: win.cw
                    entry: modelData
                    popup: true
                    onCloseRequested: Notifs.drop(modelData.key, false)
                    onDismissRequested: Notifs.remove(modelData.key)
                    menuOffsetX: (win.screen?.width ?? 1920) - win.width
                    // новая карточка въезжает справа
                    // a new card slides in from the right
                    NumberAnimation on x { from: win.cw; to: 0; duration: Tokens.dur.defaultSpatial
                                           easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.defaultSpatial }
                }
            }
        }
    }
}
