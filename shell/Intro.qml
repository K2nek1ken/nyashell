import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// заставка при входе в сеанс: экран цвета рамки (как экран входа) «раскрывается» отверстием из центра
// до рабочей области — рамка будто сжимается к краям, открывая обои; дальше окна сеанса въезжают сами.
// играет один раз за сеанс (перезапуск шелла её не повторяет)
// session intro: a screen in the frame colour (like the login screen) "opens" with a hole from the centre
// to the work area, as if the frame shrank to the edges revealing the wallpaper; then the session windows slide in by themselves.
// plays once per session (restarting the shell doesn't repeat it)
PanelWindow {
    id: intro
    screen: Quickshell.screens[0]
    visible: playing
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    color: "transparent"
    mask: Region {}

    property bool playing: false
    property real k: 0                       // 0 — всё закрыто рамкой, 1 — отверстие во всю рабочую область / 0: everything covered by the frame, 1: the hole spans the whole work area
    signal finished()

    // играла ли заставка в этом сеансе — решаем сразу при создании (файл читается синхронно). Раньше это делал
    // отдельный процесс: пока он отвечал, успевали показаться обои, частицы и визуализатор, а потом экран
    // «затемнялся» заставкой. Теперь заставка закрывает экран с самого первого кадра шелла
    // whether the intro has played this session is decided right at creation (the file is read synchronously). This used to be
    // a separate process: while it answered, the wallpaper, particles and visualizer had time to show, and then the screen
    // "darkened" into the intro. Now the intro covers the screen from the shell's very first frame
    FileView {
        id: mark
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nyash-intro-" + (Quickshell.env("XDG_SESSION_ID") || "0")
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        if (mark.text().trim() === "1") { finished(); return; }
        playing = true;
        mark.setText("1");
        anim.start();
    }
    SequentialAnimation {
        id: anim
        PauseAnimation { duration: 700 }         // дать экрану входа догаснуть / let the login screen finish fading
        NumberAnimation { target: intro; property: "k"; from: 0; to: 1; duration: 950; easing.type: Easing.InOutCubic }
        ScriptAction { script: { intro.playing = false; intro.finished(); } }
    }

    // рабочая область: внутри рамки и над панелью
    // work area: inside the frame and above the bar
    readonly property real x0: Tokens.frame
    readonly property real y0: Tokens.frame
    readonly property real x1: width - Tokens.frame
    readonly property real y1: height - Tokens.barHeight
    readonly property real cx: (x0 + x1) / 2
    readonly property real cy: (y0 + y1) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            PathRectangle { x: 0; y: 0; width: intro.width; height: intro.height }
            PathRectangle {
                x: intro.cx + (intro.x0 - intro.cx) * intro.k
                y: intro.cy + (intro.y0 - intro.cy) * intro.k
                width: (intro.x1 - intro.x0) * intro.k
                height: (intro.y1 - intro.y0) * intro.k
                radius: Math.min(Tokens.frameRadius, width / 2, height / 2)
            }
        }
    }
}
