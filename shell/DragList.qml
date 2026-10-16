import QtQuick

// список, который упорядочивают перетаскиванием: хватаешь строку и тянешь вверх или вниз,
// остальные расступаются. Отпустил — новый порядок уходит в reordered(order)
// a list you reorder by dragging: grab a row and pull it up or down,
// the others make way. Let go and the new order goes to reordered(order)
Item {
    id: dl
    property var model: []                // ключи по порядку / keys in order
    property var names: ({})              // ключ → подпись / key → label
    property int rowW: 220
    property int rowH: 30
    property int gap: 4
    signal reordered(var order)
    // если canHide — у каждой строки есть глаз: спрятать / показать (ключи спрятанных — в hidden)
    // if canHide, every row has an eye: hide / show (keys of hidden ones are in hidden)
    property bool canHide: false
    property var hidden: []
    signal toggled(string key)
    width: rowW
    height: Math.max(0, model.length * (rowH + gap) - gap)

    property int from: -1                 // какую строку тащим / which row is being dragged
    property int to: -1                   // куда она встанет / where it will land
    // где стоит строка i, пока одну из строк тащат
    // where row i sits while one of the rows is being dragged
    function slotOf(i: int): int {
        if (from < 0 || i === from) return i;
        if (from < to && i > from && i <= to) return i - 1;
        if (from > to && i >= to && i < from) return i + 1;
        return i;
    }

    Repeater {
        model: dl.model
        delegate: Rectangle {
            id: row
            required property string modelData
            required property int index
            readonly property bool held: dl.from === index
            property real dragY: 0
            width: dl.rowW; height: dl.rowH; radius: dl.rowH / 2
            y: held ? dragY : dl.slotOf(index) * (dl.rowH + dl.gap)
            z: held ? 2 : 1
            color: held ? Theme.tonalHi : Theme.surfaceHi
            scale: held ? 1.03 : 1
            Behavior on y { enabled: !row.held; Anim { kind: "fastSpatial" } }
            Behavior on scale { Anim { kind: "fastSpatial" } }
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "bars"; size: 10
                   color: row.held ? Theme.accent : Theme.textDim }
            readonly property bool off: dl.hidden.includes(modelData)
            Text { x: 32; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.strikeout: row.off
                   font.pixelSize: Tokens.font.smaller; color: row.off ? Theme.textDim : Theme.text; text: dl.names[row.modelData] ?? row.modelData }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true          // настройки прокручиваются — не отдаём им жест / the settings scroll, so don't give them the gesture
                property real grab: 0
                onPressed: (m) => {
                    grab = mapToItem(dl, m.x, m.y).y - row.y;
                    row.dragY = row.y;
                    dl.from = row.index; dl.to = row.index;
                }
                onPositionChanged: (m) => {
                    if (!pressed || dl.from !== row.index) return;
                    const ny = Math.max(0, Math.min(dl.height - dl.rowH, mapToItem(dl, m.x, m.y).y - grab));
                    row.dragY = ny;
                    dl.to = Math.round(ny / (dl.rowH + dl.gap));
                }
                function finish(): void {
                    const f = dl.from, t = dl.to;
                    dl.from = -1; dl.to = -1;
                    if (f < 0 || f === t) return;
                    const o = dl.model.slice(), it = o.splice(f, 1)[0];
                    o.splice(t, 0, it);
                    dl.reordered(o);
                }
                onReleased: finish()
                onCanceled: finish()
            }
            // глаз — поверх области перетаскивания, чтобы клик по нему не начинал перенос
            // the eye sits above the drag area so clicking it doesn't start a move
            Rectangle {
                visible: dl.canHide
                anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: eyeMa.containsMouse ? Theme.tonalHi : "transparent"
                Icon { anchors.centerIn: parent; name: row.off ? "off" : "eye"; size: 10; color: row.off ? Theme.textDim : Theme.accent }
                MouseArea { id: eyeMa; anchors.fill: parent; hoverEnabled: true; onClicked: dl.toggled(row.modelData) }
            }
        }
    }
}
