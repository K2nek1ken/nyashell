import Quickshell
import Quickshell.Widgets
import QtQuick

// вкладка «музыка»: сверху поиск по всей библиотеке и переключатель «Плейлисты · Папки».
// плейлисты — крупные карточки с обложкой (своя картинка или обложка первого трека), как в VK/Spotify;
// «+» — создать (пустой или из текущей очереди). Открытый плейлист — шапка с обложкой и кнопками + треки
// music tab: on top a search across the whole library and a "Playlists · Folders" switch.
// playlists are big cards with a cover (your own picture or the first track's cover), like VK/Spotify;
// "+" creates one (empty or from the current queue). An open playlist is a header with cover and buttons + tracks
Item {
    id: mu
    property var dash
    readonly property bool shown: dash.open && dash.tab === 2
    // последний режим, открытый плейлист и папка запоминаются
    // lists | dirs; берётся из настроек один раз при старте (привязка к настройкам + запись в них давала петлю)
    // the last mode, open playlist and folder are remembered
    // lists | dirs; read from the settings once at start (binding to the settings + writing to them made a loop)
    property string seg: "lists"
    Component.onCompleted: seg = ShellState.settings.musicSeg ?? "lists"
    onSegChanged: if ((ShellState.settings.musicSeg ?? "lists") !== seg) ShellState.set("musicSeg", seg)
    Connections {
        target: Mpd
        function onOpenListChanged() { ShellState.set("musicList", Mpd.openList); }
        function onPathChanged() { ShellState.set("musicPath", Mpd.path); }
    }
    property bool restored: false
    onShownChanged: if (shown) {
        Mpd.loadLists();
        if (!restored) {
            restored = true;
            Mpd.browse(ShellState.settings.musicPath ?? "");
            const l = ShellState.settings.musicList ?? "";
            if (l) Mpd.showList(l);
        } else if (!Mpd.entries.length) Mpd.browse("");
    }

    // меню: под курсором (окно борда не на весь экран — переводим координаты), и пока оно открыто,
    // борд не закрывается от ухода курсора на меню
    // menu: under the cursor (the dashboard window isn't full-screen, so coordinates are translated), and while it's open
    // the dashboard doesn't close when the cursor moves onto the menu
    ContextMenu { id: menu; screen: Quickshell.screens[0]; onVisibleChanged: mu.dash.menuHold = visible }
    function openMenu(item, m, items): void {
        const p = item.mapToItem(null, m.x, m.y);
        const ox = ((dash.screen?.width ?? 1920) - dash.width) / 2;
        menu.items = items; menu.openAt(p.x + ox, p.y, false);
    }
    Connections { target: mu.dash; function onMenusClose() { menu.close(); picker.visible = false; form.visible = false; } }
    // «добавить в плейлист…» и «где лежит файл» — общие для всех меню трека
    // "add to playlist…" and "where the file is" are shared by every track menu
    function fileItems(file: string): var {
        return [{ icon: "plus", text: L.t("добавить в плейлист…"), action: () => picker.pick(file) },
                { icon: "folder_open", text: L.t("открыть расположение файла"), action: () => Mpd.reveal(file) }];
    }
    function trackMenu(item, m, file: string): void {
        openMenu(item, m, [
            { icon: "play_arrow", text: L.t("играть сейчас"), action: () => Mpd.playInFolder(file) },
            { icon: "music", text: L.t("воспроизвести отдельно"), action: () => Mpd.playNow(file) },
            { icon: "skip_next", text: L.t("воспроизвести далее"), action: () => Mpd.add(file, true) },
            { icon: "queue", text: L.t("в очередь"), action: () => Mpd.add(file, false) },
            { separator: true }
        ].concat(mu.fileItems(file)));
    }

    Text {
        anchors.centerIn: parent
        visible: !Mpd.alive
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
        text: L.t("библиотека работает через MPD — он не запущен\n(запусти mpd или включи его службу)")
    }

    Item {
        visible: Mpd.alive
        anchors.fill: parent
        anchors.leftMargin: Tokens.gap.large; anchors.rightMargin: Tokens.gap.large
        anchors.topMargin: 4; anchors.bottomMargin: 4

        // ── поиск и переключатель ──
        // ── search and switch ──
        Row {
            id: top
            width: parent.width
            spacing: 8
            Row {
                id: segs
                spacing: 4
                Repeater {
                    model: [["lists", L.t("Плейлисты")], ["dirs", L.t("Папки")]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: mu.seg === modelData[0] && !q.text
                        width: st.implicitWidth + 28; height: 34; radius: 17
                        color: sel ? Theme.accent : Theme.surface
                        Text { id: st; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                        StateLayer { radius: 17; onClicked: { q.text = ""; mu.seg = modelData[0]; Mpd.openList = ""; } }
                    }
                }
            }
            Rectangle {
                width: parent.width - segs.width - 8; height: 34; radius: 17
                color: Theme.surface
                border.color: q.activeFocus ? Theme.accent : "transparent"
                Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 12; color: Theme.textDim }
                TextInput {
                    id: q
                    anchors.fill: parent; anchors.leftMargin: 34; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                    onTextChanged: searchLater.restart()
                    // клавишами по борду: Esc — очистить, ещё раз (или Enter / вниз) — обратно к выбору кнопок
                    // dashboard keys: Esc clears, again (or Enter / down) goes back to picking buttons
                    Keys.onEscapePressed: { if (text) text = ""; else Nav.back(); }
                    Keys.onReturnPressed: Nav.back()
                    Keys.onDownPressed: Nav.back()
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !q.text; font.family: Theme.font
                           font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: L.t("найти трек, исполнителя, альбом…") }
                }
                Timer { id: searchLater; interval: 250; onTriggered: Mpd.search(q.text) }
                NavPoint { radius: 17; action: () => q.forceActiveFocus() }
            }
        }

        Item {
            id: body
            y: top.height + 8
            width: parent.width; height: parent.height - y

            // ── результаты поиска ──
            // ── search results ──
            ListView {
                visible: q.text.length > 0
                SmoothWheel {}
                anchors.fill: parent
                clip: true; spacing: 2
                model: Mpd.found
                delegate: Rectangle {
                    id: fr
                    required property var modelData
                    width: ListView.view.width; height: 40; radius: 12
                    color: frm.containsMouse ? Theme.surface : "transparent"
                    Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 8; color: Theme.surfaceHi
                                Icon { anchors.centerIn: parent; name: "music"; size: 12; color: Theme.accent } }
                    Column {
                        x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 130
                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                               color: Theme.text; text: fr.modelData.title }
                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: Theme.textDim; text: fr.modelData.artist || "" }
                    }
                    Text { anchors.right: addb.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                           font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: fr.modelData.time }
                    MouseArea {
                        id: frm; anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: (m) => {
                            if (m.button === Qt.LeftButton) Mpd.playInFolder(fr.modelData.file);
                            else if (m.button === Qt.MiddleButton) Mpd.add(fr.modelData.file, true);
                            else mu.trackMenu(fr, m, fr.modelData.file);
                        }
                        NavPoint { anchors.rightMargin: 44; action: () => Mpd.playInFolder(fr.modelData.file) }
                    }
                    // «в очередь» — отдельная кнопка
                    // "to queue" is a separate button
                    Rectangle {
                        id: addb
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30; radius: 15; color: abm.containsMouse ? Theme.accent : Theme.surfaceHi
                        Icon { anchors.centerIn: parent; name: "plus"; size: 11; color: abm.containsMouse ? Theme.onAccent : Theme.accent }
                        MouseArea { id: abm; anchors.fill: parent; hoverEnabled: true; onClicked: Mpd.add(fr.modelData.file, false)
                                    NavPoint { radius: 15; action: () => Mpd.add(fr.modelData.file, false) } }
                    }
                }
                Text { anchors.centerIn: parent; visible: Mpd.found.length === 0; font.family: Theme.font
                       font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: L.t("ничего не нашлось") }
            }

            // ── плейлисты: крупные карточки ──
            // ── playlists: big cards ──
            GridView {
                id: grid
                visible: !q.text && mu.seg === "lists" && Mpd.openList === ""
                SmoothWheel {}
                anchors.fill: parent
                clip: true
                readonly property int cols: Math.max(3, Math.floor(width / 150))
                cellWidth: Math.floor(width / cols)
                cellHeight: cellWidth + 44
                model: [""].concat(Mpd.playlists)
                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index
                    readonly property bool add: index === 0
                    width: grid.cellWidth; height: grid.cellHeight
                    StaggerIn { index: parent.index; step: 25; active: mu.shown }
                    Rectangle {
                        id: cover
                        x: 6; y: 6
                        width: card.width - 12; height: width
                        radius: Tokens.rounding.large
                        color: Theme.surfaceHi
                        scale: cm.containsMouse ? 1.03 : 1
                        Behavior on scale { Anim { kind: "fastSpatial" } }
                        ClippingRectangle {
                            anchors.fill: parent; radius: parent.radius; color: "transparent"
                            visible: !card.add && !!Mpd.covers[card.modelData]
                            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
                                    sourceSize.width: 256; source: card.add ? "" : (Mpd.covers[card.modelData] ?? "") }
                        }
                        Icon { anchors.centerIn: parent; visible: card.add || !Mpd.covers[card.modelData]
                               name: card.add ? "plus" : "queue"; size: card.add ? 28 : 30; color: Theme.accent }
                        // играть — круглая кнопка в углу при наведении
                        // play: a round button in the corner on hover
                        Rectangle {
                            visible: !card.add && cm.containsMouse
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                            width: 40; height: 40; radius: 20; color: Theme.accent
                            Icon { anchors.centerIn: parent; name: "play_arrow"; size: 14; color: Theme.onAccent }
                            MouseArea { anchors.fill: parent; onClicked: Mpd.playList(card.modelData) }
                        }
                    }
                    Column {
                        x: 8; y: cover.y + cover.height + 6; width: card.width - 16
                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                               color: Theme.text; text: card.add ? L.t("Создать плейлист") : card.modelData }
                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: Theme.textDim; visible: !card.add
                               text: (Mpd.counts[card.modelData] ?? 0) + L.t(" треков") }
                    }
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: (m) => {
                            if (card.add) { form.openNew(); return; }
                            const n = card.modelData;
                            if (m.button === Qt.LeftButton) { Mpd.showList(n); return; }
                            if (m.button === Qt.MiddleButton) { Mpd.playList(n); return; }
                            mu.openMenu(card, m, [
                                { icon: "play_arrow", text: L.t("играть"), action: () => Mpd.playList(n) },
                                { icon: "shuffle", text: L.t("перемешать и играть"), action: () => Mpd.shuffleList(n) },
                                { icon: "queue", text: L.t("добавить в очередь"), action: () => Mpd.appendList(n) },
                                { separator: true },
                                { icon: "edit", text: L.t("изменить…"), action: () => form.openEdit(n) },
                                { separator: true },
                                { icon: "bin", text: L.t("удалить плейлист"), danger: true, action: () => Mpd.deleteList(n) }
                            ]);
                        }
                        NavPoint { radius: Tokens.rounding.large; action: () => { if (card.add) form.openNew(); else Mpd.showList(card.modelData); } }
                    }
                }
            }

            // ── открытый плейлист ──
            // ── open playlist ──
            Item {
                visible: !q.text && mu.seg === "lists" && Mpd.openList !== ""
                anchors.fill: parent
                // шапка: обложка, название, кнопки
                // header: cover, title, buttons
                Row {
                    id: head
                    spacing: 14
                    Rectangle {
                        width: 96; height: 96; radius: Tokens.rounding.large; color: Theme.surfaceHi
                        ClippingRectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; visible: !!Mpd.covers[Mpd.openList]
                            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; sourceSize.width: 256; source: Mpd.covers[Mpd.openList] ?? "" } }
                        Icon { anchors.centerIn: parent; visible: !Mpd.covers[Mpd.openList]; name: "queue"; size: 24; color: Theme.accent }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Row {
                            spacing: 8
                            Rectangle { width: 26; height: 26; radius: 13; color: Theme.surface; anchors.verticalCenter: parent.verticalCenter
                                        Icon { anchors.centerIn: parent; name: "chevron_left"; size: 10; color: Theme.text }
                                        StateLayer { radius: 13; onClicked: Mpd.openList = "" } }
                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.larger; font.bold: true; color: Theme.text; text: Mpd.openList }
                        }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: Mpd.listTracks.length + L.t(" треков") }
                        Text { visible: !!Mpd.descs[Mpd.openList]; width: Math.min(implicitWidth, body.width - 130)
                               wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                               text: Mpd.descs[Mpd.openList] ?? "" }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [["play_arrow", L.t("играть"), () => Mpd.playList(Mpd.openList)],
                                        ["shuffle", L.t("перемешать"), () => Mpd.shuffleList(Mpd.openList)],
                                        ["queue", L.t("в очередь"), () => Mpd.appendList(Mpd.openList)],
                                        ["edit", L.t("изменить"), () => form.openEdit(Mpd.openList)]]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: pb.implicitWidth + 44; height: 32; radius: 16
                                    color: index === 0 ? Theme.accent : Theme.surface
                                    Row { anchors.centerIn: parent; spacing: 6
                                        Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData[0]; size: 11
                                               color: index === 0 ? Theme.onAccent : Theme.accent }
                                        Text { id: pb; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                               color: index === 0 ? Theme.onAccent : Theme.text; text: modelData[1] } }
                                    StateLayer { radius: 16; onClicked: modelData[2]() }
                                }
                            }
                        }
                    }
                }
                ListView {
                    SmoothWheel {}
                    y: head.height + 10; width: parent.width; height: parent.height - y
                    clip: true; spacing: 1
                    model: Mpd.listTracks
                    delegate: Rectangle {
                        id: tr
                        required property string modelData
                        required property int index
                        width: ListView.view.width; height: 32; radius: 10
                        color: trm.containsMouse ? Theme.surface : "transparent"
                        Text { x: 10; width: 26; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                               font.pixelSize: Tokens.font.small; color: Theme.textDim; text: tr.index + 1 }
                        Text { x: 40; width: parent.width - 50; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                               text: tr.modelData.split("/").pop().replace(/\.[^.]+$/, "") }
                        MouseArea {
                            id: trm
                            anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (m) => {
                                if (m.button === Qt.LeftButton) {
                                    Quickshell.execDetached(["sh", "-c", 'mpc -q clear && mpc -q load "$1" && mpc -q play "$2"', "sh", Mpd.openList, String(tr.index + 1)]);
                                    return;
                                }
                                mu.openMenu(tr, m, [
                                    { icon: "skip_next", text: L.t("воспроизвести далее"), action: () => Mpd.add(tr.modelData, true) },
                                    { icon: "queue", text: L.t("в очередь"), action: () => Mpd.add(tr.modelData, false) },
                                    { separator: true }
                                ].concat(mu.fileItems(tr.modelData), [
                                    { separator: true },
                                    { icon: "bin", text: L.t("убрать из плейлиста"), danger: true, action: () => Mpd.removeFromList(Mpd.openList, tr.index) }
                                ]));
                            }
                            NavPoint { radius: 10; action: () => Quickshell.execDetached(["sh", "-c", 'mpc -q clear && mpc -q load "$1" && mpc -q play "$2"', "sh", Mpd.openList, String(tr.index + 1)]) }
                        }
                    }
                }
            }

            // ── папки ──
            // ── folders ──
            Item {
                visible: !q.text && mu.seg === "dirs"
                anchors.fill: parent
                Row {
                    id: crumbs
                    spacing: 4
                    Repeater {
                        model: [""].concat(Mpd.path ? Mpd.path.split("/") : [])
                        delegate: Row {
                            required property string modelData
                            required property int index
                            spacing: 4
                            Text { visible: index > 0; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: "›" }
                            Text {
                                font.family: Theme.font; font.pixelSize: Tokens.font.small
                                color: index === (Mpd.path ? Mpd.path.split("/").length : 0) ? Theme.accent : Theme.text
                                text: index === 0 ? L.t("Музыка") : modelData
                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                            onClicked: Mpd.browse(Mpd.path.split("/").slice(0, index).join("/"))
                                            NavPoint { radius: 8; action: () => Mpd.browse(Mpd.path.split("/").slice(0, index).join("/")) } }
                            }
                        }
                    }
                }
                ListView {
                    SmoothWheel {}
                    y: 24; width: parent.width; height: parent.height - 24
                    clip: true; spacing: 1
                    model: Mpd.entries
                    delegate: Rectangle {
                        id: en
                        required property var modelData
                        width: ListView.view.width; height: 44; radius: 14
                        color: em.containsMouse ? Theme.surface : "transparent"
                        Behavior on color { CAnim {} }
                        // значок в плашке: папка — вторым цветом, трек — акцентом
                        // icon in a chip: folders in the second colour, tracks in the accent
                        Rectangle {
                            x: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32; radius: 10
                            color: en.modelData.dir ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.18) : Theme.surfaceHi
                            Icon { anchors.centerIn: parent; name: en.modelData.dir ? "folder_open" : "music"; size: 13
                                   color: en.modelData.dir ? Theme.accent2 : Theme.accent }
                        }
                        Icon { visible: en.modelData.dir; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                               name: "chevron_right"; size: 9; color: Theme.textDim }
                        Text { x: 48; width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                               text: en.modelData.dir ? en.modelData.name : en.modelData.name.replace(/\.[^.]+$/, "") }
                        MouseArea {
                            id: em
                            anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: (m) => {
                                const d = en.modelData;
                                if (m.button === Qt.MiddleButton) { d.dir ? Mpd.addDir(d.file, true) : Mpd.add(d.file, true); return; }
                                if (m.button === Qt.LeftButton) { d.dir ? Mpd.browse(d.file) : Mpd.playInFolder(d.file); return; }
                                if (!d.dir) { mu.trackMenu(en, m, d.file); return; }
                                mu.openMenu(en, m, [
                                    { icon: "folder_open", text: L.t("открыть"), action: () => Mpd.browse(d.file) },
                                    { icon: "queue", text: L.t("в очередь"), action: () => Mpd.addDir(d.file, false) },
                                    { icon: "skip_next", text: L.t("воспроизвести далее"), action: () => Mpd.addDir(d.file, true) }
                                ]);
                            }
                            NavPoint { radius: 14; action: () => { const d = en.modelData; d.dir ? Mpd.browse(d.file) : Mpd.playInFolder(d.file); } }
                        }
                    }
                }
            }
        }
    }

    PlaylistPicker { id: picker; anchors.fill: parent }

    // ── создать / изменить плейлист: обложка, название, описание ──
    // ── create / edit a playlist: cover, name, description ──
    PlaylistForm {
        id: form
        anchors.fill: parent
        queueOption: true
        onSubmitted: (name, cover, desc, fromQueue) => {
            if (editing) Mpd.editList(editing, name, cover, desc);
            else Mpd.createList(name, cover, desc, fromQueue, "");
        }
    }
}
