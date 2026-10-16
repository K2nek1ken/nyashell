import Quickshell
import Quickshell.Io
import QtQuick

// менеджер буфера обмена (Super+V) на cliphist: поиск, Enter — вставить в буфер, Del — удалить
// clipboard manager (Super+V) on cliphist: search, Enter to put it on the clipboard, Del to delete
CenterPopup {
    id: cb
    open: ShellState.clipOpen
    onDismissed: ShellState.clipOpen = false
    cardWidth: 560
    cardHeight: 520
    property var items: []          // [{line, id, text, image}]
    readonly property var shown: {
        const q = search.text.toLowerCase();
        return q ? items.filter(i => i.text.toLowerCase().includes(q)) : items;
    }

    onOpenChanged: {
        if (!open) return;
        search.text = "";
        list.currentIndex = 0;
        load.running = true;
        search.forceActiveFocus();
    }

    Process {
        id: load
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                cb.items = text.split("\n").filter(l => l).slice(0, 200).map(l => {
                    const tab = l.indexOf("\t");
                    const t = tab >= 0 ? l.slice(tab + 1) : l;
                    return { line: l, id: tab >= 0 ? l.slice(0, tab) : l, text: t, image: t.startsWith("[[ binary data") };
                });
            }
        }
    }
    function pick(it): void {
        if (!it) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", it.line]);
        ShellState.clipOpen = false;
    }
    function remove(it): void {
        if (!it) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", it.line]);
        items = items.filter(x => x.id !== it.id);
    }

    Rectangle {
        x: 16; y: 16
        width: parent.width - 32
        height: 46
        radius: 23
        color: Theme.surface
        Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "clipboard"; size: 14; color: Theme.accent }
        TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: 46
            anchors.rightMargin: 18
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font
            font.pixelSize: Tokens.font.larger
            color: Theme.text
            onTextChanged: list.currentIndex = 0
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) ShellState.clipOpen = false;
                else if (e.key === Qt.Key_Down) list.incrementCurrentIndex();
                else if (e.key === Qt.Key_Up) list.decrementCurrentIndex();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) cb.pick(cb.shown[list.currentIndex]);
                else if (e.key === Qt.Key_Delete) cb.remove(cb.shown[list.currentIndex]);
                else return;
                e.accepted = true;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text.length === 0
                font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.textDim
                text: L.t("поиск в буфере…   Enter — скопировать, Del — удалить")
            }
        }
    }

    ListView {
        SmoothWheel {}
        id: list
        x: 16; y: 74
        width: parent.width - 32
        height: parent.height - 74 - 56
        clip: true
        spacing: 2
        model: cb.shown
        highlightMoveDuration: 120
        highlight: Rectangle { radius: 20; color: Theme.surface; border.color: Theme.outline }
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: 42
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                spacing: 12
                Icon { anchors.verticalCenter: parent.verticalCenter; name: row.modelData.image ? "image" : "description"
                       size: 13; color: Theme.accent }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: list.width - 90
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
                    text: row.modelData.image ? L.t("картинка · ") + row.modelData.text.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "")
                                              : row.modelData.text.replace(/\s+/g, " ")
                }
            }
            Item {
                anchors.right: parent.right; anchors.rightMargin: 8
                width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                Icon { anchors.centerIn: parent; name: "bin"; size: 12; color: Theme.textDim }
                StateLayer { radius: 14; onClicked: cb.remove(row.modelData) }
            }
            MouseArea {
                anchors.fill: parent; anchors.rightMargin: 40
                hoverEnabled: true
                onEntered: list.currentIndex = row.index
                onClicked: cb.pick(row.modelData)
            }
        }
        Text {
            anchors.centerIn: parent
            visible: cb.items.length === 0
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
            text: L.t("буфер пуст\n(нужны cliphist и wl-clipboard)")
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: wipeT.implicitWidth + 36; height: 32; radius: 16
        color: Theme.tonal
        visible: cb.items.length > 0
        Text { id: wipeT; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
               color: Theme.accent; text: L.t("очистить всю историю") }
        StateLayer { radius: 16; tint: Theme.accent
                     onClicked: { Quickshell.execDetached(["cliphist", "wipe"]); cb.items = []; } }
    }
}
