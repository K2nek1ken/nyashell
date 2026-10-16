import QtQuick

// плавная прокрутка колесом: вместо рывка на шаг — мягкая доводка к цели.
// кладётся внутрь ListView/GridView/Flickable. Тачпад (пиксельная прокрутка) идёт как есть — он и так плавный
// smooth wheel scrolling: instead of a jump per step, a soft glide to the target.
// put inside a ListView/GridView/Flickable. A touchpad (pixel scrolling) goes as is, it's smooth already
WheelHandler {
    id: sw
    // сам Flickable: у ListView/GridView родитель — contentItem, поэтому ищем по свойству contentY
    // the Flickable itself: for ListView/GridView the parent is contentItem, so look it up by the contentY property
    readonly property var flick: (parent && parent.contentY !== undefined) ? parent
                               : (parent && parent.parent && parent.parent.contentY !== undefined) ? parent.parent : null
    property real step: 110
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property real goal: 0

    function clampY(y: real): real {
        const f = flick;
        const top = f.originY - f.topMargin;
        const bottom = f.originY + Math.max(0, f.contentHeight - f.height) + f.bottomMargin;
        return Math.max(top, Math.min(bottom, y));
    }
    onWheel: (e) => {
        const f = flick;
        if (!f || f.contentHeight <= f.height) return;
        if (e.pixelDelta.y !== 0) { anim.stop(); f.contentY = clampY(f.contentY - e.pixelDelta.y); e.accepted = true; return; }
        const from = anim.running ? goal : f.contentY;
        goal = clampY(from - e.angleDelta.y / 120 * step);
        anim.to = goal;
        anim.restart();
        e.accepted = true;
    }
    // у WheelHandler не бывает дочерних объектов — поэтому анимация лежит в свойстве (спасибо за находку)
    // a WheelHandler can't have child objects, so the animation lives in a property
    property NumberAnimation _anim: NumberAnimation {
        id: anim
        target: sw.flick
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic
    }
}
