import Quickshell
import Quickshell.Io
import QtQuick

// страницы (теги mango) точками: пустая — крошечная, занятая — точка, активная — крупный круг-кольцо
// pages (mango tags) as dots: empty is tiny, occupied is a dot, active is a big ring
Row {
    id: root
    signal menuAt(real x, real y, var items)
    function pageMenu(item, m, items): void {
        const p = item.mapToItem(null, m.x, m.y);
        root.menuAt(p.x, p.y, items);
    }
    property string monitor: ""
    readonly property var tags: ShellState.mangoTags[monitor] ?? []
    spacing: ShellState.pageCount > 12 ? 3 : 6
    // страниц много — точки мельче, чтобы ряд не дотягивался до трея
    // many pages: smaller dots so the row doesn't reach the tray
    readonly property real k: ShellState.pageCount > 9 ? Math.max(0.55, 9 / ShellState.pageCount) : 1

    // где на экране лежат точки страниц — для mango: перетащил окно (Ctrl+Super+ЛКМ) и отпустил над точкой —
    // окно переезжает на эту страницу. Координаты окна панели + сдвиг панели от верха экрана
    // where the page dots are on screen, for mango: drag a window (Ctrl+Super+left-drag) and drop it over a dot,
    // and the window moves to that page. Bar window coordinates + the bar's offset from the top of the screen
    property real offX: 0
    property real offY: 0
    function publish(): void { pubLater.restart(); }
    Timer {
        id: pubLater; interval: 300
        onTriggered: {
            const lines = [];
            for (let i = 0; i < dotsRep.count; i++) {
                const d = dotsRep.itemAt(i); if (!d) continue;
                const p = d.mapToItem(null, 0, 0);
                lines.push((i + 1) + " " + Math.round(p.x + root.offX) + " " + Math.round(p.y + root.offY) + " " + Math.round(d.width) + " " + Math.round(d.height));
            }
            pubFile.setText(lines.join("\n") + "\n");
        }
    }
    FileView { id: pubFile; path: Quickshell.env("XDG_RUNTIME_DIR") + "/nyash-pagedots"; printErrors: false }
    // над какой точкой сейчас несут окно (пишет mango во время Ctrl+Super-перетаскивания)
    // which dot a window is being carried over right now (mango writes it during a Ctrl+Super drag)
    FileView { id: hoverFile; path: Quickshell.env("XDG_RUNTIME_DIR") + "/nyash-pagehover"; printErrors: false; watchChanges: true
               onFileChanged: reload() }
    readonly property int dropPage: parseInt((hoverFile.text() || "0").trim()) || 0
    onXChanged: publish()
    onWidthChanged: publish()
    onOffYChanged: publish()
    Component.onCompleted: publish()

    Repeater {
        id: dotsRep
        model: ShellState.pageCount
        delegate: Item {
            id: dot
            required property int index
            readonly property var tag: root.tags.find(t => t.index === index + 1) ?? null
            readonly property bool active: tag?.is_active ?? false
            readonly property bool busy: (tag?.client_count ?? 0) > 0
            readonly property bool urgent: tag?.is_urgent ?? false
            readonly property bool dropHere: root.dropPage === index + 1
            width: active || dropHere ? 26 : Math.round(12 * root.k)
            height: 26
            // окно несут сюда — точка вырастает в кольцо-приглашение
            // a window is being carried here: the dot grows into an inviting ring
            Rectangle {
                anchors.centerIn: parent
                width: 26; height: 26; radius: 13
                color: "transparent"; border.width: 2; border.color: Theme.accent
                opacity: dot.dropHere ? 1 : 0
                scale: dot.dropHere ? 1 : 0.5
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
            anchors.verticalCenter: parent.verticalCenter
            Behavior on width { Anim { kind: "fastSpatial" } }

            Rectangle {
                anchors.centerIn: parent
                width: dot.active ? 22 : dot.busy ? 8 : 5
                height: width
                radius: dot.active ? width / 2 : dot.busy ? 2.5 : width / 2
                color: dot.urgent ? Theme.danger : dot.active ? Theme.accent : dot.busy ? Theme.text : Theme.textDim
                opacity: dot.active || dot.busy ? 1 : 0.5
                Behavior on width { Anim { kind: "fastSpatial" } }
                Behavior on radius { Anim { kind: "fastSpatial" } }
                Behavior on color { CAnim {} }

                // «кольцо» внутри активной — как у caelestia
                // the "ring" inside the active one, as in caelestia
                Rectangle {
                    anchors.centerIn: parent
                    width: dot.active ? 10 : 0
                    height: width
                    radius: width / 2
                    color: Theme.frame
                    Behavior on width { Anim { kind: "fastSpatial" } }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    const n = dot.index + 1;
                    if (m.button !== Qt.RightButton) { Quickshell.execDetached(["mmsg", "dispatch", "view," + n]); return; }
                    // ПКМ по точке страницы: перейти, режим, закрыть все окна на ней
                    // right-click a page dot: go to it, layout mode, close all windows on it
                    const ids = ShellState.mangoClients.filter(c => (c.tags || []).includes(n) && c.monitor === root.monitor).map(c => c.id);
                    const lay = dot.tag?.layout ?? "";
                    root.pageMenu(dot, m, [
                        { icon: "chevron_right", text: L.t("перейти на страницу ") + n, action: () => Quickshell.execDetached(["mmsg", "dispatch", "view," + n]) },
                        { separator: true },
                        { icon: "l_scroller", text: L.t("лента"), checked: lay === "S",
                          action: () => Quickshell.execDetached(["sh", "-c", "mmsg dispatch view," + n + "; mmsg dispatch setlayout,scroller"]) },
                        { icon: "l_grid", text: L.t("сетка"), checked: lay === "F",
                          action: () => Quickshell.execDetached(["sh", "-c", "mmsg dispatch view," + n + "; mmsg dispatch setlayout,fair"]) },
                        { separator: true },
                        { icon: "close", text: L.t("закрыть все окна на странице"), danger: true, enabled: ids.length > 0,
                          action: () => Quickshell.execDetached(["sh", "-c", ids.map(i => "mmsg dispatch killclient client," + i).join("; ")]) }
                    ]);
                }
            }
        }
    }

    // колесо — листать страницы
    // wheel: flip pages
    WheelHandler {
        onWheel: (e) => {
            const cur = (root.tags.find(t => t.is_active) ?? { index: 1 }).index;
            const to = e.angleDelta.y > 0 ? (cur === 1 ? ShellState.pageCount : cur - 1) : (cur === ShellState.pageCount ? 1 : cur + 1);
            Quickshell.execDetached(["mmsg", "dispatch", "view," + to]);
        }
    }
}
