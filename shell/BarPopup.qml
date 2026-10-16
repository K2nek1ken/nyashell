import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// выпадашка менеджера: непрозрачный «ящик», вырастающий из панели над своим значком,
// с вогнутыми скруглениями с обеих сторон в месте стыка — как меню приложений и монитор.
// Клик мимо или Esc — закрыть.
// a manager popup: an opaque "drawer" growing out of the bar above its icon,
// with concave rounding on both sides where it joins, like the app menu and the monitor.
// Click outside or Esc to close.
PanelWindow {
    id: pop
    default property alias content: card.data
    property real px: 0            // центр значка по x / icon centre on x
    property real cardWidth: 320
    property real cardHeight: 300
    property real barHeight: 52
    // "center" — над своим значком; "right" — в правом нижнем углу, срастаясь и с панелью, и с правой рамкой
    // (так живут уведомления: они и всплывают с правого края)
    // "center": above its icon; "right": in the bottom-right corner, joined to both the bar and the right frame
    // (that's where notifications live: they pop up from the right edge)
    property string dock: "center"

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    readonly property real rr: Tokens.frameRadius
    readonly property real bigR: Tokens.rounding.extraLarge
    readonly property real yB: height - barHeight
    // место под вогнутые скругления с обеих сторон, чтобы оба угла были одинаковыми
    // room for the concave rounding on both sides so both corners match
    readonly property real xR: width - Tokens.frame                  // внутренний край правой рамки / inner edge of the right frame
    readonly property real x0: dock === "right" ? xR - cardWidth
        : Math.max(Tokens.frame + rr + 4, Math.min(width - cardWidth - Tokens.frame - rr - 4, px - cardWidth / 2))
    property real hh: 0
    Behavior on hh { Anim { kind: pop.hh > 0 && !closeLater.running ? "spatial" : "emphasized" } }

    function openAt(x: real): void { px = x; closeLater.stop(); visible = true; hh = cardHeight; }
    // закрытие — тоже анимацией: ящик уезжает обратно в панель, потом окно прячется
    // closing is animated too: the drawer slides back into the bar, then the window hides
    function close(): void {
        if (!visible) return;
        hh = 0;
        closeLater.restart();
    }
    Timer { id: closeLater; interval: 260; onTriggered: pop.visible = false }
    onVisibleChanged: if (visible) hh = cardHeight
    onCardHeightChanged: if (visible && !closeLater.running) hh = cardHeight

    MouseArea { anchors.fill: parent; onClicked: pop.close() }
    // Esc закрывает. Не Shortcut: он ронял шелл при выходе (QQuickShortcut в деструкторе)
    // Esc closes. Not a Shortcut: it crashed the shell on exit (QQuickShortcut in the destructor)
    // Ctrl+V — сигнал pastePressed (VPN вставляет ссылки из буфера, как NekoBox)
    // Ctrl+V gives the pastePressed signal (the VPN pastes links from the clipboard, like NekoBox)
    signal pastePressed()
    signal selectAllPressed()             // Ctrl+A — VPN выделяет все серверы группы / Ctrl+A: the VPN selects every server in the group
    Item {
        focus: true
        Keys.onEscapePressed: pop.close()
        Keys.onPressed: (e) => {
            if (e.matches(StandardKey.Paste)) { pop.pastePressed(); e.accepted = true; }
            else if (e.matches(StandardKey.SelectAll)) { pop.selectAllPressed(); e.accepted = true; }
        }
    }

    Shape {
        id: shp
        visible: pop.dock === "center"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real yT: pop.yB - pop.hh
        readonly property real curR: Math.min(pop.bigR, pop.hh / 2)
        readonly property real cr: Math.min(pop.rr, pop.hh)
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            startX: pop.x0 - shp.cr; startY: pop.yB + 1
            PathLine { x: pop.x0 - shp.cr; y: pop.yB }
            PathArc  { x: pop.x0; y: pop.yB - shp.cr; radiusX: shp.cr; radiusY: shp.cr; direction: PathArc.Counterclockwise }
            PathLine { x: pop.x0; y: shp.yT + shp.curR }
            PathArc  { x: pop.x0 + shp.curR; y: shp.yT; radiusX: shp.curR; radiusY: shp.curR }
            PathLine { x: pop.x0 + pop.cardWidth - shp.curR; y: shp.yT }
            PathArc  { x: pop.x0 + pop.cardWidth; y: shp.yT + shp.curR; radiusX: shp.curR; radiusY: shp.curR }
            PathLine { x: pop.x0 + pop.cardWidth; y: pop.yB - shp.cr }
            PathArc  { x: pop.x0 + pop.cardWidth + shp.cr; y: pop.yB; radiusX: shp.cr; radiusY: shp.cr; direction: PathArc.Counterclockwise }
            PathLine { x: pop.x0 + pop.cardWidth + shp.cr; y: pop.yB + 1 }
        }
    }

    // форма «в углу»: слева — вогнутый стык с панелью, сверху справа — вогнутый стык с правой рамкой
    // "corner" shape: on the left a concave joint with the bar, top right a concave joint with the right frame
    Shape {
        visible: pop.dock === "right"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            startX: pop.width; startY: shp.yT - shp.cr
            PathLine { x: pop.xR; y: shp.yT - shp.cr }
            PathArc  { x: pop.xR - shp.cr; y: shp.yT; radiusX: shp.cr; radiusY: shp.cr; direction: PathArc.Clockwise }
            PathLine { x: pop.x0 + shp.curR; y: shp.yT }
            PathArc  { x: pop.x0; y: shp.yT + shp.curR; radiusX: shp.curR; radiusY: shp.curR; direction: PathArc.Counterclockwise }
            PathLine { x: pop.x0; y: pop.yB - shp.cr }
            PathArc  { x: pop.x0 - shp.cr; y: pop.yB; radiusX: shp.cr; radiusY: shp.cr; direction: PathArc.Clockwise }
            PathLine { x: pop.x0 - shp.cr; y: pop.yB + 1 }
            PathLine { x: pop.width; y: pop.yB + 1 }
        }
    }

    // содержимое: прибито к верху ящика и выезжает вместе с ним
    // content: pinned to the top of the drawer and slides out with it
    Item {
        x: pop.x0
        y: shp.yT
        width: pop.cardWidth
        height: pop.hh
        clip: true
        MouseArea { anchors.fill: parent }
        Item {
            id: card
            width: pop.cardWidth
            height: pop.cardHeight
        }
    }
}
