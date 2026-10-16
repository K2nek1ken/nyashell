import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import Qt.labs.folderlistmodel

// выбор обоев — карусель: в центре картинка целиком, к краям — всё сильнее «сложены».
// тащи мышью или крути колесо, ЛКМ — выбрать, стрелки + Enter тоже работают
// wallpaper picker as a carousel: the picture in the centre is whole, towards the edges they get more and more "folded".
// drag with the mouse or turn the wheel, left click to choose; arrows + Enter work too
PanelWindow {
    id: win
    // пока открыт выбор файла — карусель прячется, чтобы окно выбора не оказалось под ней
    // while the file chooser is open the carousel hides, so the chooser doesn't end up under it
    visible: (ShellState.pickerOpen || fade.opacity > 0.01) && !chooser.running
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.pickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    // своя папка: выбранные файлы копируются сюда, чтобы обои не пропали, если исходник удалят
    // our own folder: chosen files are copied here so the wallpaper isn't lost if the original is deleted
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/nyashell/wallpapers"
    Process { running: true; command: ["mkdir", "-p", win.dir] }

    // диалог выбора файла: zenity (GTK — он в теме шелла через adw-gtk3), если его нет — kdialog
    // file chooser dialog: zenity (GTK, themed like the shell via adw-gtk3), kdialog if it's missing
    Process {
        id: chooser
        command: ["sh", "-c",
            'if command -v zenity >/dev/null; then zenity --file-selection --title="' + L.t("Обои") + '" --file-filter="*.png *.jpg *.jpeg *.webp"; ' +
            'else kdialog --title "' + L.t("Обои") + '" --getopenfilename "$HOME" "image/png image/jpeg image/webp"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                const src = text.trim();
                if (!src) return;
                copier.dest = win.dir + "/" + Date.now() + "-" + src.split("/").pop();
                copier.command = ["cp", "--", src, copier.dest];
                copier.running = true;
            }
        }
    }
    Process {
        id: copier
        property string dest: ""
        onExited: (code) => { if (code === 0) ShellState.setWallpaper(copier.dest); }
    }

    FolderListModel {
        id: files
        folder: "file://" + win.dir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Time
        sortReversed: false
    }

    // ─── карусель ───
    // ─── carousel ───
    readonly property real centerW: Math.min(width * 0.46, 760)
    readonly property real centerH: centerW * 9 / 16
    readonly property real minW: 46                 // ширина самой «сложенной» полоски / width of the most "folded" strip
    readonly property real gap: 10
    readonly property real fold: 1.15               // как быстро складываются соседние / how quickly the neighbours fold
    readonly property int shown: 3                  // сколько видно с каждой стороны / how many are visible on each side
    readonly property int preload: 5                // и сколько ещё держим загруженными за краем / and how many more stay loaded past the edge
    property int index: 0
    property real pos: 0                            // плавная позиция (дробная во время анимации) / smooth position (fractional during the animation)
    Behavior on pos { enabled: !drag.pressed; Anim { kind: "spatial" } }

    function widthAt(t: real): real { return minW + (centerW - minW) * Math.exp(-fold * Math.abs(t)); }
    // центр элемента на расстоянии t от середины: интеграл ширин — поэтому всё едет плавно
    // centre of an item at distance t from the middle: an integral of widths, so everything moves smoothly
    function offsetAt(t: real): real {
        const a = Math.abs(t);
        const integral = minW * a + (centerW - minW) * (1 - Math.exp(-fold * a)) / fold;
        return Math.sign(t) * (integral + gap * a);
    }
    // после удаления — на ближайшую картинку (ту, что встала на место удалённой, или предыдущую, если удалили последнюю)
    // after deleting, go to the nearest picture (the one that took the deleted one's place, or the previous if the last was deleted)
    property int deleting: -1
    Connections {
        target: files
        function onCountChanged(): void { if (win.deleting >= 0) afterDelete.restart(); }
    }
    // папка перечитывается не за один шаг (список может на миг опустеть) — ждём, пока он устоится
    // the folder isn't reread in one step (the list may briefly be empty), so wait for it to settle
    Timer {
        id: afterDelete
        interval: 200
        onTriggered: {
            const i = Math.min(win.deleting, files.count - 1);
            win.deleting = -1;
            win.index = Math.max(0, i); win.pos = win.index;
        }
    }
    function go(i: int): void { index = Math.max(0, Math.min(files.count - 1, i)); pos = index; }
    function pick(i: int): void {
        go(i);
        const p = files.get(i, "filePath");
        if (p) ShellState.setWallpaper(p);
    }

    onVisibleChanged: if (visible && ShellState.pickerOpen) {
        // открываемся на текущих обоях
        // open on the current wallpaper
        for (let i = 0; i < files.count; i++)
            if (files.get(i, "filePath") === ShellState.wallpaper) { index = i; pos = i; break; }
        keys.forceActiveFocus();
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) ShellState.pickerOpen = false;
            else if (e.key === Qt.Key_Left || ShellState.keyIs(e, "a")) win.go(win.index - 1);
            else if (e.key === Qt.Key_Right || ShellState.keyIs(e, "d")) win.go(win.index + 1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.pick(win.index);
            // Delete — убрать картинку из коллекции (в корзину, не насовсем)
            // Delete removes the picture from the collection (to the trash, not for good)
            else if (e.key === Qt.Key_Delete && files.count > 0) {
                const f = files.get(win.index, "filePath");
                if (f) { win.deleting = win.index; Quickshell.execDetached(["sh", "-c", 'gio trash "$1" 2>/dev/null || rm -f "$1"', "sh", f]); }
            }
            else return;
            e.accepted = true;
        }
    }

    Rectangle {
        id: fade
        anchors.fill: parent
        color: "#000000"
        opacity: ShellState.pickerOpen ? 0.55 : 0
        Behavior on opacity { Anim { kind: "effects" } }
        MouseArea { anchors.fill: parent; onClicked: ShellState.pickerOpen = false }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: fade.opacity / 0.55
        scale: ShellState.pickerOpen ? 1 : 0.96
        Behavior on scale { Anim { kind: "spatial" } }

        // перетаскивание и колесо — двигают карусель
        // dragging and the wheel move the carousel
        MouseArea {
            id: drag
            x: 0; width: parent.width
            y: (parent.height - win.centerH) / 2 - 20
            height: win.centerH + 40
            property real startX: 0
            property real startPos: 0
            property bool moved: false
            onPressed: (e) => { startX = e.x; startPos = win.pos; moved = false; }
            onPositionChanged: (e) => {
                const dx = e.x - startX;
                if (Math.abs(dx) > 6) moved = true;
                win.pos = Math.max(0, Math.min(files.count - 1, startPos - dx / (win.minW * 3)));
            }
            onReleased: (e) => {
                if (moved) win.go(Math.round(win.pos));
            }
            onClicked: (e) => {
                if (moved) return;
                // клик по картинке — выбрать её
                // clicking a picture chooses it
                const t = win.pos;
                let best = -1, bd = 1e9;
                for (let i = 0; i < files.count; i++) {
                    if (Math.abs(i - t) > win.shown + 0.5) continue;
                    const cx = stage.width / 2 + win.offsetAt(i - t);
                    const d = Math.abs(e.x - cx);
                    if (d < win.widthAt(i - t) / 2 && d < bd) { best = i; bd = d; }
                }
                if (best >= 0) win.pick(best);
            }
            onWheel: (w) => win.go(win.index + (w.angleDelta.y > 0 ? -1 : 1))
        }

        Item {
            id: viewport
            readonly property real half: win.offsetAt(win.shown + 0.5)
            x: stage.width / 2 - half
            width: half * 2
            height: stage.height
            clip: true

        Repeater {
            model: files
            delegate: Item {
                id: slot
                required property string filePath
                required property int index
                readonly property real t: index - win.pos
                // загружаем видимые + по пять за краем, остальных вообще не рисуем
                // load the visible ones + five past each edge, don't draw the rest at all
                readonly property bool far: Math.abs(t) > win.shown + win.preload
                visible: !far && Math.abs(t) < win.shown + 1.5
                width: win.widthAt(t)
                height: win.centerH * (1 - 0.18 * Math.min(1, Math.abs(t)))
                x: viewport.half + win.offsetAt(t) - width / 2
                // у края — плавно гаснут, чтобы выезжали мягко, а не обрубались
                // they fade smoothly at the edge, so they slide in softly instead of being cut off
                opacity: Math.max(0, Math.min(1, win.shown + 1 - Math.abs(t)))
                y: (stage.height - height) / 2
                z: 100 - Math.abs(t)

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.extraLarge
                    color: Theme.surface
                    border.width: ShellState.wallpaper === slot.filePath ? 3 : 0
                    border.color: Theme.accent
                    Image {
                        // картинка не сжимается, а «прячется» за краями — эффект сложенной полоски
                        // the picture doesn't shrink, it "hides" behind the edges: the folded-strip effect
                        anchors.centerIn: parent
                        width: win.centerW
                        height: parent.height
                        source: slot.far ? "" : "file://" + slot.filePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 640
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: Math.min(0.55, Math.abs(slot.t) * 0.22)
                    }
                }
            }
        }

        }

        Text {
            anchors.centerIn: parent
            visible: files.count === 0
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.font
            font.pixelSize: Tokens.font.larger
            color: Theme.text
            text: L.t("обоев пока нет\nвыбери файл кнопкой ниже")
        }

        // подпись и кнопка выбора файла — под каруселью
        // caption and file chooser button under the carousel
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height + win.centerH) / 2 + 26
            spacing: 14
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: files.count > 0
                font.family: Theme.font
                font.pixelSize: Tokens.font.smaller
                color: Theme.textDim
                text: (win.index + 1) + " / " + files.count + L.t("   ·   ← → или колесо, ЛКМ / Enter — поставить")
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: pickRow.implicitWidth + 44
                height: 44
                radius: 22
                color: Theme.accent
                Row {
                    id: pickRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "folder_open"; size: 15; color: Theme.onAccent }
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                           font.pixelSize: Tokens.font.normal; font.bold: true; color: Theme.onAccent
                           text: L.t("выбрать файл…") }
                }
                StateLayer { radius: 22; tint: Theme.onAccent; onClicked: chooser.running = true }
            }
        }
    }
}
