import Quickshell.Widgets
import QtQuick

// «state layer» из Material 3 по мотивам caelestia: подсветка при наведении
// и круговая волна от точки нажатия, обрезанная по скруглению родителя
// Material 3 "state layer" after caelestia: hover highlight
// and a circular ripple from the press point, clipped to the parent's rounding
MouseArea {
    id: root
    property real radius: 0
    // цвет подсветки подбирается под фон кнопки: на цветной (например, акцентной) кнопке подсветка цветом текста
    // почти не видна — тогда берём светлую или тёмную в зависимости от яркости фона, и делаем её заметнее
    // the highlight colour adapts to the button's background: on a coloured (e.g. accent) button a text-coloured highlight
    // is barely visible, so a light or dark one is used depending on the background's brightness, and made stronger
    readonly property var bg: parent && parent.color !== undefined ? parent.color : undefined
    readonly property bool coloredBg: bg !== undefined && bg.a > 0.5 && bg.hslSaturation > 0.25
    readonly property real bgLuma: bg !== undefined ? 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b : 0
    property color tint: coloredBg ? (bgLuma > 0.55 ? "#000000" : "#ffffff") : Theme.text
    property real hoverOpacity: coloredBg ? 0.16 : 0.08
    property bool disabled: false
    property real pressX: width / 2
    property real pressY: height / 2
    readonly property real endRadius: Math.sqrt(Math.max(
        pressX ** 2 + pressY ** 2, (width - pressX) ** 2 + pressY ** 2,
        pressX ** 2 + (height - pressY) ** 2, (width - pressX) ** 2 + (height - pressY) ** 2)) * 1.3

    anchors.fill: parent
    hoverEnabled: true
    // клавишами по борду (Nav.qml): эта кнопка — одна из целей, пробел нажимает её
    // dashboard keys (Nav.qml): this button is one of the targets, space presses it
    readonly property bool navDisabled: disabled || !enabled
    function navActivate(): void { if (!navDisabled) root.clicked(null); }
    Component.onCompleted: Nav.register(root)
    Component.onDestruction: Nav.unregister(root)
    enabled: !disabled
    cursorShape: disabled ? undefined : Qt.PointingHandCursor

    onPressed: (e) => {
        pressX = e.x; pressY = e.y;
        fade.stop();
        ripple.width = 0;
        ripple.opacity = root.coloredBg ? 0.2 : 0.12;
        grow.restart();
    }
    onReleased: if (!grow.running) fade.restart()
    onCanceled: fade.restart()

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.tint
            opacity: root.containsMouse && !root.disabled ? root.hoverOpacity : 0
            Behavior on opacity { Anim { kind: "effects" } }
        }
        Rectangle {
            id: ripple
            x: root.pressX - width / 2
            y: root.pressY - height / 2
            width: 0
            height: width
            radius: width / 2
            color: root.tint
            opacity: 0
        }
    }

    // рамка выбранной клавишами кнопки
    // outline of the button selected with the keys
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        visible: Nav.current === root
    }

    Anim {
        id: grow
        target: ripple
        property: "width"
        to: root.endRadius * 2
        kind: "standard"
        duration: Tokens.dur.slowEffects * 2
        onFinished: if (!root.pressed) fade.restart()
    }
    Anim { id: fade; target: ripple; property: "opacity"; to: 0; kind: "effects" }
}
