import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// одно уведомление (и во всплывашке, и в истории)
// a single notification (both in the popup and in the history)
Rectangle {
    id: card
    property var entry
    property bool popup: false
    signal closeRequested()          // время вышло — спрятать всплывашку / time's up: hide the popup
    signal dismissRequested()        // нажали крестик — убрать насовсем / the cross was pressed: remove for good
    // ПКМ по карточке — меню: действия уведомления, убрать, больше не показывать от приложения
    // right-click on the card: a menu with the notification's actions, remove, never show from this app
    property real menuOffsetX: 0     // если карточка в окне не на весь экран — сдвиг до левого края экрана / if the card is in a window that isn't full-screen: offset to the left edge of the screen
    ContextMenu { id: nmenu; screen: Quickshell.screens[0] }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (ev) => {
            const e = card.entry, p0 = card.mapToItem(null, ev.position.x, ev.position.y);
            const p = { x: p0.x + card.menuOffsetX, y: p0.y };
            nmenu.items = (e?.actions ?? []).map(a => ({ icon: "play_arrow", text: a.text, action: () => Notifs.invoke(e, a.id) }))
                .concat((e?.actions ?? []).length ? [{ separator: true }] : [])
                .concat([
                    { icon: "close", text: L.t("убрать"), action: () => card.dismissRequested() },
                    { icon: "bell_off", text: L.t("не показывать от ") + (e?.app ?? ""), danger: true, action: () => Notifs.mute(e.app) }
                ]);
            nmenu.openAt(p.x, p.y, false);
        }
    }

    implicitHeight: col.implicitHeight + Tokens.gap.medium * 2
    radius: Tokens.rounding.large + 4
    color: entry?.critical ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12) : Theme.surface
    border.color: entry?.critical ? Theme.danger : Theme.outline
    border.width: 1

    // автозакрытие всплывашки; наведение ставит на паузу
    // the popup closes by itself; hovering pauses it
    property real remain: 1
    NumberAnimation on remain {
        running: card.popup && !(card.entry?.critical ?? false)
        paused: hover.hovered
        from: 1; to: 0
        duration: 6000
        onFinished: card.closeRequested()
    }
    HoverHandler { id: hover }

    ColumnLayout {
        id: col
        x: Tokens.gap.medium
        y: Tokens.gap.medium
        width: parent.width - Tokens.gap.medium * 2
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            // картинка уведомления или значок приложения
            // the notification's image or the app icon
            ClippingRectangle {
                width: 34; height: 34; radius: 12
                color: Theme.tonal
                Image {
                    anchors.fill: parent
                    visible: (card.entry?.image ?? "") !== ""
                    // путь к файлу приходит без file:// — без него Image его не находит
                    // the file path comes without file://, and without it Image can't find it
                    source: { const i = card.entry?.image ?? ""; return i.startsWith("/") ? "file://" + i : i; }
                    sourceSize.width: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                IconImage {
                    anchors.centerIn: parent
                    visible: (card.entry?.image ?? "") === ""
                    implicitSize: 20
                    source: Quickshell.iconPath(card.entry?.icon || "dialog-information", "dialog-information")
                }
            }
            Column {
                Layout.fillWidth: true
                Row {
                    spacing: 6
                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent
                           text: card.entry?.app ?? "" }
                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                           text: "· " + Notifs.ago(card.entry?.time ?? Date.now()) }
                }
                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font
                       font.pixelSize: Tokens.font.normal; font.bold: true; color: Theme.text
                       text: card.entry?.summary ?? "" }
            }
            Item {
                width: 24; height: 24
                Layout.alignment: Qt.AlignTop
                Icon { anchors.centerIn: parent; name: "close"; size: 11; color: Theme.textDim }
                StateLayer { radius: 12; onClicked: card.dismissRequested() }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 4 : 3
            elide: Text.ElideRight
            textFormat: Text.StyledText
            font.family: Theme.font
            font.pixelSize: Tokens.font.smaller
            color: Theme.textDim
            text: card.entry?.body ?? ""
        }

        // кнопки действий. Row, а не Flow: Flow внутри ColumnLayout зацикливал расчёт высоты,
        // и уведомление с кнопками (например, от скриншота) сплющивалось в «бугорок»
        // action buttons. Row, not Flow: a Flow inside a ColumnLayout looped the height calculation,
        // and a notification with buttons (e.g. from a screenshot) collapsed into a "bump"
        Row {
            Layout.fillWidth: true
            visible: (card.entry?.actions ?? []).length > 0 && !!card.entry?.n
            spacing: 6
            Repeater {
                model: card.entry?.actions ?? []
                delegate: Rectangle {
                    required property var modelData
                    width: at.implicitWidth + 22; height: 28; radius: 14
                    color: Theme.tonal
                    Text { id: at; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: Theme.accent; text: modelData.text }
                    StateLayer { radius: 14; tint: Theme.accent; onClicked: Notifs.invoke(card.entry, modelData.id) }
                }
            }
        }

        // полоска оставшегося времени
        // remaining time bar
        Rectangle {
            visible: card.popup && !(card.entry?.critical ?? false)
            Layout.fillWidth: true
            height: 2; radius: 1
            color: Theme.surfaceHi
            Rectangle { width: parent.width * card.remain; height: 2; radius: 1; color: Theme.accent }
        }
    }
}
