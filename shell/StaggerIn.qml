import QtQuick

// появление элемента списка «лесенкой» сверху вниз: кладётся внутрь делегата,
// проигрывается каждый раз, когда становится active (например, при открытии выпадашки)
// a list item appearing as a "staircase" from top to bottom: put inside a delegate,
// plays every time it becomes active (e.g. when a popup opens)
Item {
    id: s
    property int index: 0
    property bool active: false
    property int step: 45                 // задержка между соседними элементами, мс / delay between neighbouring items, ms
    readonly property Item target: parent
    visible: false

    Translate { id: tr; y: 0 }
    Component.onCompleted: { if (target) target.transform = [tr]; if (active) play(); }
    onActiveChanged: if (active) play()

    function play(): void {
        if (!target) return;
        anim.stop();
        target.opacity = 0;
        tr.y = -12;
        anim.start();
    }
    SequentialAnimation {
        id: anim
        PauseAnimation { duration: Math.min(s.index, 12) * s.step }
        ParallelAnimation {
            Anim { target: s.target; property: "opacity"; to: 1; kind: "effects" }
            Anim { target: tr; property: "y"; to: 0; kind: "spatial" }
        }
    }
}
