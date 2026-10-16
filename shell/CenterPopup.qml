import Quickshell
import Quickshell.Wayland
import QtQuick

// виджет по центру экрана: затемнение, карточка с пружинкой, клик мимо или Esc — закрыть
// a widget in the centre of the screen: dimming, a springy card, click outside or Esc to close
PanelWindow {
    id: pop
    property bool open: false
    default property alias content: card.data
    property real cardWidth: 420
    property real cardHeight: 300
    property alias card: card
    // клик мимо: просим закрыть, а не пишем open = false — иначе рвётся привязка open к состоянию
    // click outside: ask to close rather than writing open = false, otherwise the binding of open to the state breaks
    signal dismissed()

    visible: open || card.opacity > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: pop.open ? 0.35 : 0
        Behavior on opacity { Anim { kind: "effects" } }
    }
    MouseArea { anchors.fill: parent; enabled: pop.open; onClicked: pop.dismissed() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: pop.cardWidth
        height: pop.cardHeight
        radius: Tokens.rounding.extraLarge
        color: Theme.frame
        border.color: Theme.outline
        opacity: pop.open ? 1 : 0
        scale: pop.open ? 1 : 0.92
        Behavior on opacity { Anim { kind: "effects" } }
        Behavior on scale { Anim { kind: pop.open ? "spatial" : "emphasized" } }
        Behavior on height { Anim { kind: "fastSpatial" } }
        MouseArea { anchors.fill: parent; z: -1 }
    }
}
