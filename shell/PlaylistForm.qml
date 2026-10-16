import Quickshell.Widgets
import QtQuick

// окно создания / изменения плейлиста: крестик и заголовок, обложка (клик — выбрать картинку) рядом с названием,
// ниже описание. Кладётся поверх вкладки борда (anchors.fill).
// openNew() — новый плейлист, openEdit(имя) — изменить существующий. Результат — сигнал submitted
// the playlist create / edit window: a cross and a title, the cover (click to pick a picture) next to the name,
// the description below. Placed over a dashboard tab (anchors.fill).
// openNew() for a new playlist, openEdit(name) to change an existing one. The result comes as the submitted signal
Rectangle {
    id: pf
    property string editing: ""              // имя изменяемого плейлиста, "" — новый / the playlist being edited, "" for a new one
    property bool queueOption: false         // показать «взять треки из текущей очереди» / show "take tracks from the current queue"
    property string submitText: editing ? L.t("сохранить") : L.t("создать")
    property string cover: ""                // выбранная картинка (путь), "" — не меняли / the chosen picture (path), "" if unchanged
    property bool fromQueue: false
    signal submitted(string name, string cover, string desc, bool fromQueue)

    readonly property string name: nameIn.text.trim().replace(/\//g, "-")
    // такое имя уже занято другим плейлистом / the name is already taken by another playlist
    readonly property bool taken: name !== "" && name !== editing && Mpd.playlists.includes(name)
    readonly property bool ok: name !== "" && !taken
    readonly property string preview: cover ? "file://" + cover : (editing ? (Mpd.covers[editing] ?? "") : "")

    function openNew(): void { editing = ""; reset(""); }
    function openEdit(n: string): void { editing = n; reset(n); }
    function reset(n: string): void {
        cover = ""; fromQueue = false;
        nameIn.text = n; descIn.text = n ? (Mpd.descs[n] ?? "") : "";
        visible = true; nameIn.forceActiveFocus(); nameIn.selectAll();
    }
    function submit(): void {
        if (!ok) return;
        submitted(name, cover, descIn.text, fromQueue);
        visible = false;
    }

    visible: false
    color: Qt.rgba(0, 0, 0, 0.45)
    z: 60
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: pf.visible = false }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(480, parent.width - 32)
        height: Math.min(parent.height - 16, col.implicitHeight + 32)
        radius: Tokens.rounding.large
        color: Theme.frame; border.color: Theme.line
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        scale: pf.visible ? 1 : 0.92
        Behavior on scale { Anim { kind: "fastSpatial" } }

        Column {
            id: col
            x: 16; y: 16; width: parent.width - 32
            spacing: 10

            // шапка: крестик и заголовок / header: a cross and the title
            Row {
                spacing: 12
                Rectangle {
                    width: 30; height: 30; radius: 15; color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { anchors.centerIn: parent; name: "close"; size: 13; color: Theme.text }
                    StateLayer { radius: 15; onClicked: pf.visible = false }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.larger
                       font.bold: true; color: Theme.text
                       text: pf.editing ? L.t("Изменить плейлист") : L.t("Создание плейлиста") }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.line }

            // обложка и название / cover and name
            Row {
                width: parent.width
                spacing: 12
                Rectangle {
                    id: coverBox
                    width: 84; height: 84; radius: Tokens.rounding.large
                    color: Theme.surface
                    ClippingRectangle {
                        anchors.fill: parent; radius: parent.radius; color: "transparent"; visible: !!pf.preview
                        Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
                                sourceSize.width: 256; source: pf.preview }
                    }
                    // при наведении (или пока картинки нет) — значок «выбрать картинку»
                    // on hover (or while there's no picture) an "pick a picture" icon
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: pf.preview ? Qt.rgba(0, 0, 0, 0.45) : "transparent"
                        visible: !pf.preview || coverHit.containsMouse
                        Icon { anchors.centerIn: parent; name: "image"; size: 22; color: pf.preview ? "white" : Theme.textDim }
                    }
                    MouseArea {
                        id: coverHit
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Mpd.pickImage(p => { if (p) pf.cover = p; })
                        NavPoint { radius: Tokens.rounding.large; action: () => Mpd.pickImage(p => { if (p) pf.cover = p; }) }
                    }
                }
                Column {
                    width: parent.width - coverBox.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Rectangle {
                        width: parent.width; height: 44; radius: 14
                        color: "transparent"
                        border.color: pf.taken ? Theme.danger : (nameIn.activeFocus ? Theme.accent : Theme.line)
                        TextInput {
                            id: nameIn
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter; clip: true
                            font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                            KeyNavigation.tab: descIn
                            Keys.onReturnPressed: pf.submit()
                            Keys.onEscapePressed: pf.visible = false
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !nameIn.text; font.family: Theme.font
                                   font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: L.t("Название") }
                        }
                        NavPoint { radius: 14; action: () => nameIn.forceActiveFocus() }
                    }
                    Text { visible: pf.taken; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.danger
                           text: L.t("плейлист с таким названием уже есть") }
                }
            }

            // описание / description
            // вкладка борда невысокая: описание забирает только то место, что осталось (от 40 до 100 px),
            // чтобы кнопки внизу всегда влезали
            // a dashboard tab isn't tall: the description takes only the room that's left (40 to 100 px)
            // so the buttons at the bottom always fit
            Rectangle {
                readonly property real fixed: 32 + 30 + 1 + 84 + 34 + 4 * 10
                width: parent.width; height: Math.max(40, Math.min(100, pf.height - 16 - fixed))
                radius: 14
                color: "transparent"
                border.color: descIn.activeFocus ? Theme.accent : Theme.line
                Flickable {
                    id: descFlick
                    anchors.fill: parent; anchors.margins: 10
                    contentHeight: descIn.implicitHeight; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    TextEdit {
                        id: descIn
                        width: descFlick.width
                        wrapMode: TextEdit.Wrap
                        font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                        selectionColor: Theme.accent; selectedTextColor: Theme.onAccent
                        KeyNavigation.tab: nameIn
                        Keys.onEscapePressed: pf.visible = false
                        // курсор всегда в виду / keep the cursor in view
                        onCursorRectangleChanged: {
                            const r = cursorRectangle;
                            if (r.y < descFlick.contentY) descFlick.contentY = r.y;
                            else if (r.y + r.height > descFlick.contentY + descFlick.height) descFlick.contentY = r.y + r.height - descFlick.height;
                        }
                        Text { visible: !descIn.text; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                               color: Theme.textDim; text: L.t("Описание") }
                    }
                }
                NavPoint { radius: 14; action: () => descIn.forceActiveFocus() }
            }

            // кнопки: слева — «из текущей очереди» (только для нового), справа — создать / сохранить
            // buttons: on the left "from the current queue" (new playlists only), on the right create / save
            Item {
                width: parent.width; height: 34
                Rectangle {
                    visible: pf.queueOption && !pf.editing
                    width: qr.implicitWidth + 24; height: 34; radius: 17
                    color: pf.fromQueue ? Theme.tonalHi : Theme.surface
                    Behavior on color { CAnim {} }
                    Row {
                        id: qr; anchors.centerIn: parent; spacing: 8
                        Rectangle { width: 16; height: 16; radius: 5; anchors.verticalCenter: parent.verticalCenter
                                    color: pf.fromQueue ? Theme.accent : "transparent"; border.color: pf.fromQueue ? Theme.accent : Theme.textDim
                                    Icon { anchors.centerIn: parent; visible: pf.fromQueue; name: "check"; size: 9; color: Theme.onAccent } }
                        Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.small
                               color: Theme.text; text: L.t("с треками из текущей очереди") }
                    }
                    StateLayer { radius: 17; onClicked: pf.fromQueue = !pf.fromQueue }
                }
                Rectangle {
                    anchors.right: parent.right
                    width: sb.implicitWidth + 32; height: 34; radius: 17
                    color: Theme.accent; opacity: pf.ok ? 1 : 0.45
                    Text { id: sb; anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: Tokens.font.small
                           color: Theme.onAccent; text: pf.submitText }
                    StateLayer { radius: 17; tint: Theme.onAccent; onClicked: pf.submit() }
                }
            }
        }
    }
}
