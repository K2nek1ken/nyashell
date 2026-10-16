import Quickshell
import QtQuick

// вкладка «плеер». Два вида с плавным переходом между ними (pl.q: 0 — плеер на всю вкладку, 1 — с очередью):
//  • на всю вкладку: большая пластинка слева, справа крупно название (акцентом) и исполнитель,
//    ниже прогресс во всю ширину и широкие кнопки; справа вверху — кнопка очереди;
//  • с очередью: пластинка уменьшается, название и исполнитель уезжают вниз-влево под неё,
//    прогресс и кнопки сужаются влево, а очередь выезжает из правого края.
// Без MPD — прежняя вкладка для любых плееров (MPRIS)
// player tab. Two views with a smooth transition between them (pl.q: 0 player fills the tab, 1 with the queue):
// • full tab: a big vinyl on the left, on the right a large title (in the accent) and the artist,
//   below a full-width progress bar and wide buttons; the queue button top right;
// • with the queue: the vinyl shrinks, title and artist move down-left under it,
//   progress and buttons narrow to the left, and the queue slides in from the right edge.
// Without MPD it's the old tab for any player (MPRIS)
Item {
    id: m
    property var dash
    readonly property bool shown: dash.open && dash.tab === 1

    DashMediaMpris { anchors.fill: parent; dash: m.dash; visible: !Mpd.alive }

    function fmt(sec: real): string {
        if (!sec || sec < 0) return "0:00";
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function lerp(a: real, b: real, t: real): real { return a + (b - a) * t; }

    // меню трека в очереди (ПКМ): под курсором, и пока оно открыто, борд не закрывается (как во вкладке «музыка»)
    // queue track menu (right click): under the cursor, and while it's open the dashboard stays (as in the Music tab)
    ContextMenu { id: menu; screen: Quickshell.screens[0]; onVisibleChanged: m.dash.menuHold = visible }
    Connections { target: m.dash; function onMenusClose() { menu.close(); picker.visible = false; } }
    function queueMenu(item, e, i: int): void {
        const t = Mpd.queue[i];
        if (!t) return;
        const p = item.mapToItem(null, e.x, e.y);
        const ox = ((dash.screen?.width ?? 1920) - dash.width) / 2;
        menu.items = [
            { icon: "play_arrow", text: L.t("играть"), action: () => Mpd.play(i) },
            { icon: "skip_next", text: L.t("воспроизвести далее"), enabled: i !== Mpd.pos, action: () => Mpd.playNext(i) },
            { separator: true },
            { icon: "plus", text: L.t("добавить в плейлист…"), action: () => picker.pick(t.file) },
            { icon: "folder_open", text: L.t("открыть расположение файла"), action: () => Mpd.reveal(t.file) },
            { separator: true },
            { icon: "bin", text: L.t("убрать из очереди"), danger: true, action: () => Mpd.remove(i) }
        ];
        menu.openAt(p.x + ox, p.y, false);
    }

    // кнопка управления: в широком виде — растянутая таблетка, в узком — круг
    // control button: a stretched pill in the wide view, a circle in the narrow one
    component Ctl: Rectangle {
        id: ctl
        property string icon
        property bool on: false
        property bool big: false
        property real w: 40
        signal hit()
        width: w; height: big ? 50 : 38
        radius: on && !big ? height * 0.32 : height / 2
        color: on ? Theme.accent : Theme.surfaceHi
        Behavior on radius { Anim { kind: "fastSpatial" } }
        Behavior on color { CAnim {} }
        Icon { id: ci; anchors.centerIn: parent; name: ctl.icon; size: ctl.height * 0.34; color: ctl.on ? Theme.onAccent : Theme.text
               Behavior on color { CAnim {} } }
        // смена значка (играть ↔ пауза) — с коротким «пружинящим» переходом
        // icon change (play ↔ pause) with a short springy transition
        onIconChanged: pop.restart()
        SequentialAnimation { id: pop
            NumberAnimation { target: ci; property: "scale"; to: 0.6; duration: 80 }
            NumberAnimation { target: ci; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutBack } }
        StateLayer { radius: parent.radius; onClicked: parent.hit() }
    }

    Item {
        id: pl
        anchors.fill: parent
        anchors.leftMargin: Tokens.gap.large
        anchors.rightMargin: Tokens.gap.large
        anchors.topMargin: 6; anchors.bottomMargin: 6
        visible: Mpd.alive
        clip: true

        readonly property bool showQueue: ShellState.settings.playerQueue ?? true
        property real q: showQueue ? 1 : 0
        Behavior on q { NumberAnimation { duration: 480; easing.type: Easing.InOutCubic } }
        readonly property real colW: 280                       // ширина левой колонки, когда открыта очередь / width of the left column when the queue is open

        // ── геометрия двух видов ──
        // ── geometry of the two views ──
        readonly property real ctlH: 50
        readonly property real bigV: Math.min(height - ctlH - 46, 230)       // пластинка на всю вкладку / vinyl filling the tab
        readonly property real smallV: Math.min(130, height - 170)          // пластинка рядом с очередью / vinyl next to the queue
        readonly property real vSize: m.lerp(bigV, smallV, q)
        // высота блока «пластинка + название» в компактном виде и отступ, чтобы он стоял по центру над прогрессом
        // height of the "vinyl + title" block in the compact view and the offset that centres it above the progress bar
        readonly property real compactBlock: smallV + 8 + titleCol.implicitHeight
        readonly property real compactTop: Math.max(0, (height - ctlH - 34 - 8 - compactBlock) / 2)
        readonly property real vy: m.lerp(0, compactTop, q)
        readonly property real vx: m.lerp(8, (colW - smallV) / 2, q)

        Vinyl {
            id: vinyl
            x: pl.vx; y: pl.vy
            size: pl.vSize
            art: Mpd.art
            seed: Mpd.cur.file ?? ""
            spinning: Mpd.playing && m.shown
            // скретч: положил руку — музыка встала, крутишь — звук скретча и перемотка, отпустил — играет дальше
            // scratch: put your hand on it and the music stops, spin it for a scratch sound and seeking, let go and it plays on
            scratchable: true
            property bool wasPlaying: false
            onGrabbed: { wasPlaying = Mpd.playing; if (wasPlaying) Mpd.mpc(["pause"]); }
            onLetGo: if (wasPlaying) Mpd.mpc(["play"])
            onScratched: (sec) => {
                Mpd.seekRel(sec);
                const v = Math.abs(sec);
                Quickshell.execDetached(["sh", Quickshell.shellPath("scratch.sh"), v > 2.2 ? "3" : v > 0.9 ? "2" : "1"]);
            }
        }

        // название и исполнитель: справа от большой пластинки → под маленькой
        // title and artist: right of the big vinyl → under the small one
        Column {
            id: titleCol
            x: m.lerp(pl.bigV + 36, 0, pl.q)
            y: m.lerp(pl.bigV / 2 - height / 2, pl.compactTop + pl.smallV + 8, pl.q)
            width: m.lerp(pl.width - pl.bigV - 36 - 48, pl.colW, pl.q)
            spacing: m.lerp(8, 2, pl.q)
            Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: pl.q > 0.5 ? 1 : 2; wrapMode: Text.Wrap
                   font.family: Theme.font; font.bold: true; font.pixelSize: m.lerp(30, Tokens.font.larger, pl.q)
                   color: Theme.accent; text: Mpd.cur.title || L.t("тишина") }
            Text { width: parent.width; elide: Text.ElideRight
                   font.family: Theme.font; font.pixelSize: m.lerp(18, Tokens.font.smaller, pl.q)
                   color: Theme.text; opacity: 0.85; text: Mpd.cur.artist || (Mpd.queue.length ? "" : L.t("очередь пуста")) }
            Text { visible: pl.q < 0.5 && !!Mpd.cur.album; opacity: 1 - pl.q * 2; width: parent.width; elide: Text.ElideRight
                   font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: Mpd.cur.album || "" }
        }

        // прогресс: во всю ширину → в ширину левой колонки
        // progress: full width → the width of the left column
        Item {
            id: prog
            x: 0
            y: pl.height - pl.ctlH - 34
            width: m.lerp(pl.width, pl.colW, pl.q)
            height: 26
            // прогресс хранится долей (0…1) и анимируется именно доля — полоса всегда в размер шкалы,
            // даже пока сама шкала сжимается/растягивается вместе с очередью.
            // Тянуть можно: зажми и веди — перемотка, когда отпустишь. Откат к началу (новый трек) — полупрозрачный
            // progress is stored as a fraction (0…1) and the fraction is what animates, so the bar always fits the track,
            // even while the track itself shrinks/stretches with the queue.
            // You can drag it: hold and move, it seeks when you let go. A jump back to the start (new track) is translucent
            property real target: Mpd.duration > 0 ? Math.min(1, Mpd.elapsed / Mpd.duration) : 0
            property real frac: target
            property bool dragging: false
            property real dragFrac: 0
            property bool rewinding: false
            onTargetChanged: {
                if (dragging) return;
                rewinding = target < frac - 0.05;            // резкий шаг назад — это откат, а не прогресс / a sharp step back is a reset, not progress
                fracAnim.to = target; fracAnim.duration = rewinding ? 420 : 900; fracAnim.restart();
            }
            NumberAnimation { id: fracAnim; target: prog; property: "frac"; easing.type: Easing.OutCubic
                              onFinished: prog.rewinding = false }
            Rectangle {
                id: bar
                y: 4; width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
                Rectangle {
                    height: parent.height; radius: 3; color: Theme.accent
                    width: parent.width * (prog.dragging ? prog.dragFrac : prog.frac)
                    opacity: prog.rewinding ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                // «ручка» — видна при наведении и когда тянешь
                // the "handle": visible on hover and while dragging
                Rectangle {
                    width: 14; height: 14; radius: 7; color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * (prog.dragging ? prog.dragFrac : prog.frac) - width / 2
                    scale: pm.containsMouse || prog.dragging ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                }
                MouseArea {
                    id: pm
                    anchors.fill: parent; anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function at(x: real): real { return Math.max(0, Math.min(1, (x - 8) / bar.width)); }
                    onPressed: (e) => { prog.dragging = true; prog.dragFrac = at(e.x); }
                    onPositionChanged: (e) => { if (prog.dragging) prog.dragFrac = at(e.x); }
                    onReleased: {
                        const f = prog.dragFrac;
                        prog.dragging = false;
                        fracAnim.stop(); prog.frac = f;
                        Mpd.seek(f);
                    }
                }
            }
            // время под шкалой: пока тянешь — куда перемотаешь
            // time under the bar: while dragging, where it will seek to
            Text { anchors.left: parent.left; anchors.bottom: parent.bottom; font.family: Theme.font
                   font.pixelSize: Tokens.font.small; color: prog.dragging ? Theme.accent : Theme.textDim
                   text: m.fmt(prog.dragging ? prog.dragFrac * Mpd.duration : Mpd.elapsed) }
            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; font.family: Theme.font
                   font.pixelSize: Tokens.font.small; color: Theme.textDim; text: m.fmt(Mpd.duration) }
        }

        // кнопки: широкие таблетки → компактные круги
        // buttons: wide pills → compact circles
        Row {
            id: ctls
            readonly property real total: m.lerp(Math.min(pl.width, 640), pl.colW, pl.q)
            readonly property real unit: (total - spacing * 4) / 6                 // «играть» — в два раза шире / "play" is twice as wide
            x: m.lerp((pl.width - total) / 2, 0, pl.q)
            y: pl.height - pl.ctlH
            height: pl.ctlH
            spacing: 8
            Ctl { anchors.verticalCenter: parent.verticalCenter; w: ctls.unit; icon: "shuffle"; on: Mpd.shuffleOn; onHit: Mpd.toggleRandom() }
            Ctl { anchors.verticalCenter: parent.verticalCenter; w: ctls.unit; icon: "skip_previous"; onHit: Mpd.prev() }
            Ctl { anchors.verticalCenter: parent.verticalCenter; w: ctls.unit * 2; big: true; on: true
                  icon: Mpd.playing ? "pause" : "play_arrow"; onHit: Mpd.toggle() }
            Ctl { anchors.verticalCenter: parent.verticalCenter; w: ctls.unit; icon: "skip_next"; onHit: Mpd.next() }
            Ctl {
                anchors.verticalCenter: parent.verticalCenter; w: ctls.unit
                icon: Mpd.repeatMode === "one" ? "repeat" : "sync"; on: Mpd.repeatMode !== "off"
                onHit: Mpd.cycleRepeat()
                Rectangle { visible: Mpd.repeatMode === "one"; anchors.right: parent.right; anchors.top: parent.top
                            anchors.rightMargin: 4; width: 14; height: 14; radius: 7; color: Theme.text
                            Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: 9; font.bold: true
                                   color: Theme.frame; text: "1" } }
            }
        }

        // кнопка очереди — справа вверху в обоих видах
        // queue button: top right in both views
        Rectangle {
            z: 5
            anchors.right: parent.right; y: 0
            width: 34; height: 34; radius: pl.showQueue ? 11 : 17
            color: pl.showQueue ? Theme.accent : Theme.surface
            Behavior on radius { Anim { kind: "fastSpatial" } }
            Behavior on color { CAnim {} }
            Icon { anchors.centerIn: parent; name: "queue"; size: 12; color: pl.showQueue ? Theme.onAccent : Theme.accent }
            StateLayer { radius: parent.radius; onClicked: ShellState.set("playerQueue", !pl.showQueue) }
        }

    Item {
        id: qpanel
        visible: pl.q > 0.01
        opacity: Math.min(1, pl.q * 1.5)
        width: pl.width - pl.colW - Tokens.gap.large
        x: pl.width - width * pl.q + (1 - pl.q) * 40          // выезжает справа / slides in from the right
        height: pl.height

        Rectangle {
            id: searchBox
            width: parent.width - 44; height: 34; radius: 17
            color: Theme.surface
            border.color: qsearch.activeFocus ? Theme.accent : "transparent"
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 12; color: Theme.textDim }
            TextInput {
                id: qsearch
                anchors.fill: parent; anchors.leftMargin: 34; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                onTextChanged: searchLater.restart()
                Keys.onEscapePressed: { if (text) text = ""; else Nav.back(); }
                Keys.onReturnPressed: Nav.back()
                Keys.onDownPressed: Nav.back()
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !qsearch.text; font.family: Theme.font
                       font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: L.t("найти в библиотеке…") }
            }
            Timer { id: searchLater; interval: 250; onTriggered: Mpd.search(qsearch.text) }
            NavPoint { radius: 17; action: () => qsearch.forceActiveFocus() }
        }

        // результаты поиска: ЛКМ — в конец очереди, СКМ — воспроизвести далее
        // search results: left click to the end of the queue, middle click to play next
        ListView {
            id: results
            visible: qsearch.text.length > 0
            SmoothWheel {}
            y: 42; width: parent.width; height: parent.height - 42
            clip: true; spacing: 2
            model: Mpd.found
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 34; radius: 17
                color: rm.containsMouse ? Theme.surface : "transparent"
                Text { x: 12; width: parent.width - 70; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                       font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                       text: modelData.title + (modelData.artist ? "  ·  " + modelData.artist : "") }
                // ЛКМ по строке — играть сейчас (вместе с папкой трека), СКМ — следующим
                // left click on a row plays it now (along with the track's folder), middle click plays it next
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: (e) => e.button === Qt.MiddleButton ? Mpd.add(modelData.file, true) : Mpd.playInFolder(modelData.file)
                            NavPoint { radius: 17; anchors.rightMargin: 36; action: () => Mpd.playInFolder(modelData.file) } }
                // «+» — в конец очереди
                // "+": to the end of the queue
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14; color: pq.containsMouse ? Theme.accent : Theme.surfaceHi
                    Icon { anchors.centerIn: parent; name: "plus"; size: 10; color: pq.containsMouse ? Theme.onAccent : Theme.accent }
                    MouseArea { id: pq; anchors.fill: parent; hoverEnabled: true; onClicked: Mpd.add(modelData.file, false)
                                NavPoint { radius: 14; action: () => Mpd.add(modelData.file, false) } }
                }
            }
        }

        // очередь
        // queue
        ListView {
            id: queue
            visible: !results.visible
            SmoothWheel {}
            y: 42; width: parent.width; height: parent.height - 42
            clip: true; spacing: 2
            model: Mpd.queue
            interactive: dragFrom < 0
            readonly property real rowH: 46
            // при переходе на вкладку плеера — прокрутить очередь так, чтобы играющий трек был посередине
            // when switching to the player tab, scroll the queue so the playing track is in the middle
            NumberAnimation { id: centerAnim; target: queue; property: "contentY"; duration: 450; easing.type: Easing.OutCubic }
            function centerCurrent(): void {
                if (Mpd.pos < 0 || Mpd.pos >= count || dragFrom >= 0) return;
                const maxY = Math.max(originY, originY + contentHeight - height);
                centerAnim.to = Math.max(originY, Math.min(maxY, originY + Mpd.pos * rowH - (height - rowH) / 2));
                centerAnim.restart();
            }
            Connections {
                target: m
                function onShownChanged() { if (m.shown) Qt.callLater(queue.centerCurrent); }
            }
            property int dragFrom: -1
            property int dragTo: -1
            property real dragY: 0               // где курсор, в координатах списка / where the cursor is, in list coordinates
            function updateDrop(): void {
                dragTo = Math.max(0, Math.min(count - 1, Math.floor((dragY + contentY - originY) / rowH)));
            }
            function drop(apply: bool): void {
                if (dragFrom < 0) return;
                if (apply) Mpd.move(dragFrom, dragTo);
                dragFrom = -1; dragTo = -1;
            }
            // у края списка — прокручиваем сами, чтобы можно было утащить трек далеко
            // near the list's edge we scroll by ourselves, so a track can be dragged far
            Timer {
                interval: 16; repeat: true
                running: queue.dragFrom >= 0 && (queue.dragY < 40 || queue.dragY > queue.height - 40)
                onTriggered: {
                    const v = queue.dragY < 40 ? -(40 - queue.dragY) / 4 : (queue.dragY - queue.height + 40) / 4;
                    const maxY = Math.max(queue.originY, queue.originY + queue.contentHeight - queue.height);
                    queue.contentY = Math.max(queue.originY, Math.min(maxY, queue.contentY + v));
                    queue.updateDrop();
                }
            }
            // Ctrl+ПКМ по очереди — вернуть только что убранный трек
            // Ctrl+right-click on the queue brings back the track just removed
            MouseArea {
                anchors.fill: parent; z: -1
                acceptedButtons: Qt.RightButton
                onClicked: (e) => { if (e.modifiers & Qt.ControlModifier) Mpd.undoRemove(); }
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === Mpd.pos
                // строка очереди: номер (у играющего — «пляшущие» полоски), название и исполнитель в две строки, длительность
                // queue row: number (the playing one has "dancing" bars), title and artist on two lines, duration
                width: ListView.view.width; height: 44; radius: 14
                color: current ? Theme.tonalHi : (qm.containsMouse ? Theme.surface : "transparent")
                Behavior on color { CAnim {} }
                opacity: queue.dragFrom === index ? 0.4 : 1
                Text { visible: !row.current; x: 8; width: 28; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
                       font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: row.index + 1 }
                Row {
                    visible: row.current
                    x: 13; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 3; radius: 1.5; color: Theme.accent
                            height: 6
                            SequentialAnimation on height {
                                running: row.current && Mpd.playing && m.shown; loops: Animation.Infinite
                                NumberAnimation { to: 6 + (index * 7 % 11); duration: 260 + index * 70 }
                                NumberAnimation { to: 4; duration: 260 + index * 50 }
                            }
                        }
                    }
                }
                Column {
                    x: 42; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                           font.bold: row.current; color: row.current ? Theme.accent : Theme.text; text: row.modelData.title }
                    Text { visible: !!row.modelData.artist; width: parent.width; elide: Text.ElideRight; font.family: Theme.font
                           font.pixelSize: Tokens.font.small; color: Theme.textDim; text: row.modelData.artist || "" }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                       font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: row.modelData.time }
                // ЛКМ — играть, ПКМ — меню, СКМ — убрать из очереди, Ctrl+ПКМ — вернуть убранное;
                // зажать ЛКМ и тянуть — переставить трек
                // left click plays, right click opens the menu, middle click removes from the queue, Ctrl+right-click brings back
                // the removed one; hold the left button and drag to move the track
                MouseArea {
                    id: qm
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    pressAndHoldInterval: 300
                    // пока тащим, список не должен перехватить мышь и начать прокрутку
                    // while dragging the list must not grab the mouse and start scrolling
                    preventStealing: queue.dragFrom >= 0
                    onPressAndHold: {
                        if (!(qm.pressedButtons & Qt.LeftButton)) return;
                        queue.dragFrom = row.index; queue.dragTo = row.index;
                        queue.dragY = qm.mapToItem(queue, qm.mouseX, qm.mouseY).y;
                    }
                    onPositionChanged: (e) => {
                        if (queue.dragFrom < 0) return;
                        queue.dragY = mapToItem(queue, e.x, e.y).y;
                        queue.updateDrop();
                    }
                    onReleased: queue.drop(true)
                    onCanceled: queue.drop(false)
                    onClicked: (e) => {
                        if (queue.dragFrom >= 0) return;
                        if (e.button === Qt.MiddleButton) Mpd.remove(row.index);
                        else if (e.button === Qt.RightButton) {
                            if (e.modifiers & Qt.ControlModifier) Mpd.undoRemove(); else m.queueMenu(row, e, row.index);
                        } else Mpd.play(row.index);
                    }
                    NavPoint { radius: 14; action: () => Mpd.play(row.index) }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: Mpd.queue.length === 0
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
                text: L.t("очередь пуста — найди трек выше\nили добавь всю библиотеку кнопкой справа")
            }
        }

        // куда встанет перетаскиваемый трек (вне списка: всё, что объявлено внутри ListView, уезжает вместе с содержимым)
        // where the dragged track will land (outside the list: anything declared inside a ListView scrolls with its content)
        Rectangle {
            visible: queue.dragFrom >= 0 && y >= queue.y - 2 && y <= queue.y + queue.height
            x: 8; width: queue.width - 16; height: 2; radius: 1; color: Theme.accent
            y: queue.dragTo * queue.rowH + (queue.dragTo > queue.dragFrom ? queue.rowH - 2 : 0) - queue.contentY + queue.originY + queue.y
            z: 3
        }
        // «призрак» перетаскиваемого трека едет за курсором
        // a "ghost" of the dragged track follows the cursor
        Rectangle {
            visible: queue.dragFrom >= 0
            z: 4
            x: 4; width: queue.width - 8; height: 40; radius: 14
            y: queue.y + Math.max(0, Math.min(queue.height - height, queue.dragY - height / 2))
            opacity: 0.9
            color: Theme.surfaceHi; border.color: Theme.accent
            Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "bars"; size: 11; color: Theme.accent }
            Text { x: 40; width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                   font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                   text: queue.dragFrom >= 0 ? (Mpd.queue[queue.dragFrom]?.title ?? "") : "" }
        }

        // «убрано — нажми, чтобы вернуть» (или Ctrl+ПКМ по очереди)
        // "removed — click to bring it back" (or Ctrl+right-click on the queue)
        Rectangle {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!Mpd.undo
            width: ut.implicitWidth + 28; height: 28; radius: 14
            color: Theme.frame; border.color: Theme.accent
            Text { id: ut; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                   text: L.t("убрано из очереди — нажми, чтобы вернуть") }
            StateLayer { radius: 14; onClicked: Mpd.undoRemove() }
        }
    }
    }

    PlaylistPicker { id: picker; anchors.fill: parent }
}
