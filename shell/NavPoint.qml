import QtQuick

// место, куда можно прийти клавишами в борде (см. Nav.qml): кладётся внутрь кликабельного элемента
// и повторяет его действие. Для кнопок на StateLayer не нужно — они отмечаются сами
// a spot reachable with the dashboard keys (see Nav.qml): put inside a clickable element
// and repeats its action. Not needed for StateLayer buttons, they mark themselves
Item {
    id: np
    anchors.fill: parent
    property var action: null          // что сделать по пробелу / Enter / what to do on space / Enter
    property real radius: 12
    property bool navDisabled: false
    function navActivate(): void { if (action) action(); }
    Component.onCompleted: Nav.register(np)
    Component.onDestruction: Nav.unregister(np)
    Rectangle {
        anchors.fill: parent
        radius: np.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        visible: Nav.current === np
    }
}
