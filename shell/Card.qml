import QtQuick

// карточка дашборда
// dashboard card
Rectangle {
    default property alias content: inner.data
    radius: Tokens.rounding.large + 4
    color: Theme.surface
    border.color: Theme.outline
    border.width: 1
    Item { id: inner; anchors.fill: parent; anchors.margins: Tokens.gap.medium }
}
