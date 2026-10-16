import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// монитор системы в нашем стиле: «ящик», вырастающий из панели над цифрами нагрузки.
// процессор (история и ядра), память и swap, сеть, диски, датчики, самые прожорливые процессы
// the system monitor in our style: a "drawer" growing out of the bar above the load numbers.
// CPU (history and cores), memory and swap, network, disks, sensors, the hungriest processes
PanelWindow {
    id: win
    visible: ShellState.monOpen || hh > 0.5
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.monOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property real rr: Tokens.frameRadius
    readonly property real bigR: Tokens.rounding.extraLarge
    readonly property real w: Math.min(880, width - 80)
    readonly property real fullH: Math.min(580, height - Tokens.barHeight - 60)
    // над полноэкранным окном панели не видно — ящик растёт прямо от нижнего края экрана
    // over a full-screen window the bar isn't visible, so the drawer grows straight from the bottom edge of the screen
    readonly property bool fs: ShellState.fullscreenOn(screen?.name ?? "")
    readonly property real yB: height - (fs ? 0 : Tokens.barHeight)
    readonly property real x0: Math.max(Tokens.frame + rr + 8, Math.min(width - w - Tokens.frame - rr - 8, ShellState.monX - w / 2))
    property real hh: ShellState.monOpen ? fullH : 0
    Behavior on hh { Anim { kind: ShellState.monOpen ? "spatial" : "emphasized" } }

    onVisibleChanged: SysInfo.procWatch = visible
    Component.onCompleted: SysInfo.watchers++

    // клик мимо — закрыть; Esc — тоже
    // click outside to close; Esc too
    MouseArea { anchors.fill: parent; enabled: ShellState.monOpen; onClicked: ShellState.monOpen = false }
    Item { focus: true; Keys.onEscapePressed: ShellState.monOpen = false }

    // форма: из панели вверх, внизу — вогнутые скругления, как у остальных «ящиков»
    // shape: up out of the bar, concave rounding at the bottom, like the other "drawers"
    Shape {
        id: shp
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real yT: win.yB - win.hh
        readonly property real curR: Math.min(win.bigR, win.hh / 2)
        readonly property real cr: Math.min(win.rr, win.hh)
        ShapePath {
            fillColor: Theme.frame
            strokeWidth: -1
            startX: win.x0 - shp.cr; startY: win.yB + 1
            PathLine { x: win.x0 - shp.cr; y: win.yB }
            PathArc  { x: win.x0; y: win.yB - shp.cr; radiusX: shp.cr; radiusY: shp.cr; direction: PathArc.Counterclockwise }
            PathLine { x: win.x0; y: shp.yT + shp.curR }
            PathArc  { x: win.x0 + shp.curR; y: shp.yT; radiusX: shp.curR; radiusY: shp.curR }
            PathLine { x: win.x0 + win.w - shp.curR; y: shp.yT }
            PathArc  { x: win.x0 + win.w; y: shp.yT + shp.curR; radiusX: shp.curR; radiusY: shp.curR }
            PathLine { x: win.x0 + win.w; y: win.yB - shp.cr }
            PathArc  { x: win.x0 + win.w + shp.cr; y: win.yB; radiusX: shp.cr; radiusY: shp.cr; direction: PathArc.Counterclockwise }
            PathLine { x: win.x0 + win.w + shp.cr; y: win.yB + 1 }
        }
    }

    component Card: Rectangle {
        property string title: ""
        default property alias content: inner.data
        radius: Tokens.rounding.large
        color: Theme.surface
        Text { x: 14; y: 10; font.family: Theme.font; font.pixelSize: Tokens.font.small; font.bold: true
               color: Theme.accent; text: parent.title }
        Item { id: inner; x: 14; y: 32; width: parent.width - 28; height: parent.height - 44 }
    }
    component Bar2: Item {
        property real value: 0
        property color tint: Theme.accent
        height: 8
        Rectangle { anchors.fill: parent; radius: 4; color: Theme.surfaceHi }
        Rectangle { width: Math.max(4, parent.width * Math.min(1, parent.value)); height: parent.height; radius: 4; color: parent.tint
                    Behavior on width { Anim { kind: "effects" } } }
    }

    // содержимое: прибито к верху ящика и выезжает вместе с ним
    // content: pinned to the top of the drawer and slides out with it
    Item {
        x: win.x0
        y: shp.yT
        width: win.w
        height: win.hh
        clip: true
        MouseArea { anchors.fill: parent }       // клики внутри не закрывают / clicks inside don't close

        Item {
            id: page
            x: 16; y: 16
            width: win.w - 32
            height: win.fullH - 32
            readonly property real g: 10
            readonly property real h1: 196
            readonly property real h2: 118

            // ── процессор ──
            // ── CPU ──
            Card {
                title: "CPU  ·  " + Math.round(SysInfo.cpu * 100) + "%  ·  " + SysInfo.ghz.toFixed(1) + " GHz  ·  " + L.t("нагрузка") + " " + SysInfo.load
                width: page.width * 0.6 - page.g / 2; height: page.h1
                Spark { width: parent.width; height: 70; values: SysInfo.cpuHist; color: Theme.accent }
                Grid {
                    y: 82
                    width: parent.width
                    columns: Math.min(4, Math.max(1, SysInfo.cores.length))
                    columnSpacing: 14; rowSpacing: 8
                    Repeater {
                        model: SysInfo.cores
                        delegate: Row {
                            required property var modelData
                            required property int index
                            spacing: 6
                            Text { width: 20; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: index }
                            Bar2 { width: (page.width * 0.6 - 60) / 4 - 40; anchors.verticalCenter: parent.verticalCenter; value: modelData }
                        }
                    }
                }
            }
            // ── память ──
            // ── memory ──
            Card {
                x: page.width * 0.6 + page.g / 2
                title: "RAM  ·  " + SysInfo.memUsedGb.toFixed(1) + " / " + SysInfo.memTotalGb.toFixed(1) + " GB"
                width: page.width * 0.4 - page.g / 2; height: page.h1
                Spark { width: parent.width; height: 70; values: SysInfo.memHist; color: Theme.accent2 }
                Column {
                    y: 82; width: parent.width; spacing: 8
                    Bar2 { width: parent.width; value: SysInfo.mem; tint: Theme.accent2 }
                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                           text: "swap  " + SysInfo.swapUsedGb.toFixed(1) + " / " + SysInfo.swapTotalGb.toFixed(1) + " GB" }
                    Bar2 { width: parent.width; value: SysInfo.swapTotalGb > 0 ? SysInfo.swapUsedGb / SysInfo.swapTotalGb : 0; tint: Theme.textDim }
                }
            }

            // ── сеть · диски · датчики ──
            // ── network · disks · sensors ──
            Row {
                y: page.h1 + page.g
                spacing: page.g
                readonly property real cw: (page.width - page.g * 2) / 3
                Card {
                    title: L.t("сеть")
                    width: parent.cw; height: page.h2
                    readonly property real peak: Math.max(1, ...SysInfo.rxHist, ...SysInfo.txHist)
                    Spark { width: parent.width; height: 36; values: SysInfo.rxHist.map(v => v / parent.peak); color: Theme.accent }
                    Row {
                        y: 44; spacing: 16
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: "↓ " + SysInfo.human(SysInfo.rxRate) }
                        Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim; text: "↑ " + SysInfo.human(SysInfo.txRate) }
                    }
                }
                Card {
                    title: L.t("диски")
                    width: parent.cw; height: page.h2
                    Column {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: SysInfo.disks.slice(0, 3)
                            delegate: Column {
                                required property var modelData
                                width: parent.width; spacing: 3
                                Text { width: parent.width; elide: Text.ElideMiddle; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                       color: Theme.text; text: modelData.mount + "  " + modelData.used.toFixed(0) + "/" + modelData.size.toFixed(0) + " GB" }
                                Bar2 { width: parent.width; height: 6; value: modelData.pct; tint: modelData.pct > 0.9 ? Theme.danger : Theme.accent }
                            }
                        }
                    }
                }
                Card {
                    title: L.t("датчики")
                    width: parent.cw; height: page.h2
                    Column {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [["CPU", Math.round(SysInfo.temp) + " °C", SysInfo.temp > 85],
                                    ["GPU", Math.round(SysInfo.gpu * 100) + "% " + L.t("частоты"), false],
                                    [L.t("в сети ").trim(), SysInfo.uptimeText, false]]
                            delegate: Row {
                                required property var modelData
                                spacing: 8
                                Text { width: 60; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[0] }
                                Text { font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                                       color: modelData[2] ? Theme.danger : Theme.text; text: modelData[1] }
                            }
                        }
                    }
                }
            }

            // ── процессы ──
            // ── processes ──
            Card {
                y: page.h1 + page.h2 + page.g * 2
                title: L.t("процессы")
                width: page.width
                height: page.height - y
                // сортировка
                // sorting
                Row {
                    x: parent.width - width; y: -26
                    spacing: 6
                    Repeater {
                        model: [["cpu", "CPU"], ["mem", "RAM"]]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: SysInfo.procSort === modelData[0]
                            width: 48; height: 22; radius: 11
                            color: sel ? Theme.accent : Theme.surfaceHi
                            Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                   color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                            MouseArea { anchors.fill: parent; onClicked: SysInfo.procSort = modelData[0] }
                        }
                    }
                }
                ListView {
                    SmoothWheel {}
                    anchors.fill: parent
                    clip: true
                    model: SysInfo.procs
                    spacing: 1
                    delegate: Rectangle {
                        id: pr
                        required property var modelData
                        width: ListView.view.width
                        height: 24
                        radius: 12
                        color: pm.containsMouse ? Theme.surfaceHi : "transparent"
                        Text { x: 8; width: 60; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                               font.pixelSize: Tokens.font.small; color: Theme.textDim; text: pr.modelData.pid }
                        Text { x: 72; width: parent.width - 72 - 160; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: pr.modelData.name }
                        Text { x: parent.width - 150; width: 60; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                               font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                               color: pr.modelData.cpu > 50 ? Theme.danger : Theme.accent; text: pr.modelData.cpu.toFixed(1) + "%" }
                        Text { x: parent.width - 80; width: 64; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                               font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.accent2; text: pr.modelData.mem.toFixed(1) + "%" }
                        MouseArea {
                            id: pm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.RightButton
                            onClicked: (m) => {
                                const p = pr.mapToItem(null, m.x, m.y), d = pr.modelData;
                                pmenu.items = [
                                    { icon: "close", text: L.t("завершить ") + d.name, action: () => Quickshell.execDetached(["kill", "-TERM", d.pid]) },
                                    { icon: "bin", text: L.t("убить принудительно"), danger: true, action: () => Quickshell.execDetached(["kill", "-KILL", d.pid]) }
                                ];
                                pmenu.openAt(p.x, p.y, false);
                            }
                        }
                    }
                }
            }
        }
    }
    ContextMenu { id: pmenu; screen: win.screen }
}
