import Quickshell.Widgets
import QtQuick

// окно «Добавить в плейлист»: те же карточки, что во вкладке «Музыка» — первая с плюсом создаёт новый плейлист
// (окно создания: обложка, название, описание — и трек сразу кладётся туда), остальные — плейлисты с обложками.
// Кладётся поверх вкладки борда (anchors.fill), открывается через pick(file). Клик мимо или Esc — закрыть
// the "Add to playlist" window: the same cards as in the Music tab — the first one with a plus creates a new playlist
// (the create window: cover, name, description, and the track goes there right away), the rest are playlists with covers.
// Placed over a dashboard tab (anchors.fill), opened with pick(file). Click outside or Esc to close
Rectangle {
    id: pp
    property string file: ""                 // какой трек кладём / the track being added
    readonly property string title: file.split("/").pop().replace(/\.[^.]+$/, "")

    function pick(f: string): void {
        file = f; Mpd.loadLists();
        visible = true; keys.forceActiveFocus();
    }
    function done(name: string): void {
        if (!name) return;
        Mpd.addToList(name, file);
        visible = false;
    }

    visible: false
    color: Qt.rgba(0, 0, 0, 0.45)
    z: 50
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: pp.visible = false }
    Item { id: keys; Keys.onEscapePressed: pp.visible = false }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 32)
        height: Math.min(parent.height - 24, head.height + 26 + grid.contentHeight + 16)
        radius: Tokens.rounding.large
        color: Theme.frame; border.color: Theme.line
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        scale: pp.visible ? 1 : 0.92
        Behavior on scale { Anim { kind: "fastSpatial" } }

        // ── выбор плейлиста ──
        // ── picking a playlist ──
        Column {
            id: head
            x: 16; y: 16; width: parent.width - 32
            spacing: 2
            Text { font.family: Theme.font; font.pixelSize: Tokens.font.larger; font.bold: true; color: Theme.text
                   text: L.t("Добавить в плейлист") }
            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                   color: Theme.textDim; text: pp.title }
        }
        GridView {
            id: grid
            x: 10; y: head.y + head.height + 10
            width: parent.width - 20; height: parent.height - y - 8
            clip: true
            SmoothWheel {}
            readonly property int cols: Math.max(3, Math.floor(width / 130))
            cellWidth: Math.floor(width / cols)
            cellHeight: cellWidth + 40
            model: [""].concat(Mpd.playlists)
            delegate: Item {
                id: card
                required property string modelData
                required property int index
                readonly property bool add: index === 0
                width: grid.cellWidth; height: grid.cellHeight
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
                           name: card.add ? "plus" : "queue"; size: card.add ? 24 : 26; color: Theme.accent }
                }
                Column {
                    x: 8; y: cover.y + cover.height + 5; width: card.width - 16
                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                           color: Theme.text; text: card.add ? L.t("Создать плейлист") : card.modelData }
                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: Theme.textDim; visible: !card.add
                           text: (Mpd.counts[card.modelData] ?? 0) + L.t(" треков") }
                }
                MouseArea {
                    id: cm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: card.add ? pp.startNaming() : pp.done(card.modelData)
                    NavPoint { radius: Tokens.rounding.large; action: () => card.add ? pp.startNaming() : pp.done(card.modelData) }
                }
            }
        }
    }

    // новый плейлист — сразу с этим треком; окно выбора при этом закрывается
    // a new playlist, right away with this track; the picker closes at the same time
    PlaylistForm {
        id: form
        parent: pp.parent
        anchors.fill: parent
        submitText: L.t("создать и добавить")
        onSubmitted: (name, cover, desc, fromQueue) => Mpd.createList(name, cover, desc, false, pp.file)
    }
    function startNaming(): void { visible = false; form.openNew(); }
}
