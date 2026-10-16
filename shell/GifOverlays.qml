import Quickshell
import Quickshell.Wayland
import QtQuick

// гифки поверх экрана (как GifEngine): анимированные GIF / WebP / APNG прозрачными «наклейками».
// «поверх всего» — слой overlay (видно даже над играми на весь экран), «на рабочем столе» — над обоями, под окнами.
// Клики проходят насквозь. Ctrl+Alt+G — режим правки: тащи мышью, колесо — размер, ПКМ — убрать с экрана.
// Список и настройки — Настройки → Вид → Гифки; хранится в settings.gifs
// GIFs on top of the screen (like GifEngine): animated GIF / WebP / APNG as transparent "stickers".
// "on top of everything" is the overlay layer (visible even over full-screen games), "on the desktop" is above the wallpaper, under windows.
// Clicks go through. Ctrl+Alt+G is edit mode: drag with the mouse, wheel to resize, right-click to remove from the screen.
// The list and settings are in Settings → Look → GIFs; stored in settings.gifs
Scope {
    id: go
    Variants {
        model: (ShellState.settings.gifs ?? []).filter(g => g.on && g.file)
        delegate: Component {
            PanelWindow {
                id: gw
                required property var modelData
                readonly property var g: modelData
                screen: Quickshell.screens.find(s => s.name === g.screen) ?? Quickshell.screens[0]
                WlrLayershell.layer: g.top ? WlrLayer.Overlay : WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                anchors { top: true; left: true }
                color: "transparent"
                // во время перетаскивания двигаем окно сами, в настройки пишем по отпусканию
                // while dragging we move the window ourselves and write to the settings on release
                property real px: g.x ?? 100
                property real py: g.y ?? 100
                property real pw: g.w ?? 240
                margins { left: Math.round(px); top: Math.round(py) }
                readonly property real ratio: img.sourceSize.width > 0 ? img.sourceSize.height / img.sourceSize.width : 1
                implicitWidth: Math.round(pw)
                implicitHeight: Math.max(16, Math.round(pw * ratio))
                // вне режима правки — клики насквозь
                // outside edit mode clicks go through
                mask: ShellState.gifEditing ? full : empty
                Region { id: empty }
                Region { id: full; item: body }

                function commit(): void { ShellState.updateGif(g.id, { x: Math.round(px), y: Math.round(py), w: Math.round(pw) }); }

                Item {
                    id: body
                    anchors.fill: parent
                    AnimatedImage {
                        id: img
                        anchors.fill: parent
                        source: "file://" + gw.g.file
                        playing: true
                        cache: false
                        mirror: !!gw.g.flip
                        opacity: (gw.g.op ?? 100) / 100
                        smooth: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: ShellState.gifEditing
                        color: "transparent"; radius: 8
                        border.width: 2; border.color: Theme.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: ShellState.gifEditing && !gw.g.lock
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property real sx: 0
                        property real sy: 0
                        // окно едет вместе с курсором, поэтому считаем сдвиг от точки нажатия внутри окна
                        // the window moves with the cursor, so the offset is computed from the press point inside the window
                        onPressed: (m) => {
                            if (m.button === Qt.RightButton) { ShellState.updateGif(gw.g.id, { on: false }); return; }
                            sx = m.x; sy = m.y;
                        }
                        onPositionChanged: (m) => {
                            if (!pressed) return;
                            gw.px = Math.max(-gw.pw / 2, Math.min(gw.screen.width - 24, gw.px + m.x - sx));
                            gw.py = Math.max(-gw.implicitHeight / 2, Math.min(gw.screen.height - 24, gw.py + m.y - sy));
                        }
                        onReleased: gw.commit()
                        onWheel: (w) => { gw.pw = Math.max(48, Math.min(gw.screen.width, gw.pw * (w.angleDelta.y > 0 ? 1.08 : 0.92))); saveLater.restart(); }
                    }
                    Timer { id: saveLater; interval: 400; onTriggered: gw.commit() }
                }
            }
        }
    }
}
