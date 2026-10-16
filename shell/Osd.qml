import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// OSD громкости и яркости — «ящик» из правой рамки по центру, вертикальные ползунки
// volume and brightness OSD: a "drawer" from the middle of the right frame, vertical sliders
PanelWindow {
    id: win
    readonly property real t: Tokens.frame
    readonly property real r: Tokens.frameRadius
    readonly property real bigR: Tokens.rounding.extraLarge
    readonly property real w: Brightness.present ? 124 : 70
    readonly property real h: 230
    property bool shown: false
    property real ww: shown ? w : 0
    Behavior on ww { Anim { kind: win.shown ? "spatial" : "emphasized" } }

    anchors.right: true
    implicitWidth: w + t + 4
    implicitHeight: h + 2 * r
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: body }
    visible: ww > 0.5 || shown

    function show(): void { shown = true; hide.restart(); }
    Timer { id: hide; interval: 1600; onTriggered: if (!hover.hovered) win.shown = false }

    // показываем и когда громкость поменялась не через нас (например, кнопками гарнитуры)
    // also shown when the volume changed not through us (e.g. headset buttons)
    property bool ready: false
    Timer { interval: 2500; running: true; onTriggered: win.ready = true }
    Connections {
        target: Audio
        function onVolumeChanged() { if (win.ready && Date.now() > ShellState.osdQuietUntil) win.show(); }
        function onMutedChanged() { if (win.ready && Date.now() > ShellState.osdQuietUntil) win.show(); }
    }

    Item {
        id: body
        x: win.width - win.t - win.ww
        y: win.r
        width: win.ww
        height: win.h
        HoverHandler { id: hover; onHoveredChanged: if (!hovered) hide.restart() }
    }

    Shape {
        id: shp
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real edgeX: win.width - win.t          // левый край правой рамки / left edge of the right frame
        readonly property real drawerX: edgeX - win.ww                 // левый край ящика / left edge of the drawer
        readonly property real rr: Math.min(win.r, win.ww / 2)
        readonly property real curR: Math.min(win.bigR, win.ww / 2)
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            startX: win.width; startY: win.r - shp.rr
            PathLine { x: shp.edgeX; y: win.r - shp.rr }
            PathArc  { x: shp.edgeX - shp.rr; y: win.r; radiusX: shp.rr; radiusY: shp.rr }
            PathLine { x: shp.drawerX + shp.curR; y: win.r }
            PathArc  { x: shp.drawerX; y: win.r + shp.curR; radiusX: shp.curR; radiusY: shp.curR; direction: PathArc.Counterclockwise }
            PathLine { x: shp.drawerX; y: win.r + win.h - shp.curR }
            PathArc  { x: shp.drawerX + shp.curR; y: win.r + win.h; radiusX: shp.curR; radiusY: shp.curR; direction: PathArc.Counterclockwise }
            PathLine { x: shp.edgeX - shp.rr; y: win.r + win.h }
            PathArc  { x: shp.edgeX; y: win.r + win.h + shp.rr; radiusX: shp.rr; radiusY: shp.rr }
            PathLine { x: win.width; y: win.r + win.h + shp.rr }
        }
    }

    component VSlider: Item {
        id: vs
        property real value: 0
        property string icon: ""
        signal moved(real v)
        signal iconClicked()
        width: 44
        height: win.h - 32
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.surfaceHi
            clip: true
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(parent.width, parent.height * Math.max(0, Math.min(1, vs.value)))
                radius: width / 2
                color: Theme.accent
                Behavior on height { enabled: !ma.pressed; Anim { kind: "fastSpatial" } }
            }
        }
        Text {
            font.family: Theme.font
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            text: Math.round(vs.value * 100)
            font.pixelSize: Tokens.font.small
            color: vs.value > 0.9 ? Theme.onAccent : Theme.textDim
        }
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            name: vs.icon
            size: 15
            color: Theme.onAccent
            MouseArea { anchors.fill: parent; anchors.margins: -8; z: 2; onClicked: vs.iconClicked() }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.bottomMargin: 40
            function set(my) { vs.moved(Math.max(0, Math.min(1, 1 - my / vs.height))); win.show(); }
            onPressed: (e) => set(e.y)
            onPositionChanged: (e) => { if (pressed) set(e.y); }
            onWheel: (e) => { vs.moved(Math.max(0, Math.min(1, vs.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))); win.show(); }
        }
    }

    Item {
        x: shp.drawerX
        y: win.r
        width: win.ww
        height: win.h
        clip: true
        Row {
            anchors.centerIn: parent
            spacing: 12
            opacity: win.shown ? 1 : 0
            Behavior on opacity { Anim { kind: "effects" } }
            VSlider {
                value: Audio.muted ? 0 : Audio.volume
                icon: Audio.icon()
                onMoved: (v) => { if (Audio.muted) Audio.toggleMute(); Audio.setVolume(v); }
                onIconClicked: Audio.toggleMute()
            }
            VSlider {
                visible: Brightness.present
                value: Brightness.value
                icon: "sun"
                onMoved: (v) => Brightness.set(v)
            }
        }
    }
}
