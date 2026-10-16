import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// частицы на рабочем столе: лепестки сакуры, звёздочки, снег, пузырьки.
// Всё настраивается в Настройки → Рабочий стол → Частицы: количество, размер и разброс размеров,
// прозрачность, скорость, вращение, покачивание, цвет. Вид частиц — там же или ПКМ по рабочему столу
// desktop particles: sakura petals, stars, snow, bubbles.
// Everything is set in Settings → Desktop → Particles: count, size and size variety,
// opacity, speed, spin, sway, colour. The particle type is there too, or right-click the desktop
Item {
    id: field
    readonly property string kind: ShellState.particles          // petals | stars | snow | bubbles | off
    readonly property bool live: kind !== "off"
    property string monitor: ""
    readonly property var activeTag: (ShellState.mangoTags[monitor] ?? []).find(t => t.is_active) ?? null
    // экономим видеокарту: в фуллскрине и пока на странице есть окна (стол почти не виден) — не анимируем
    // saving the GPU: no animation in full screen and while the page has windows (the desktop is barely visible)
    readonly property bool paused: (ToplevelManager.activeToplevel?.fullscreen ?? false)
                                   || ((ShellState.settings.partPauseWindows ?? true) && activeTag ? activeTag.client_count > 0 : false)

    // ─── настройки (проценты — от «как задумано» для этого вида частиц) ───
    // ─── settings (percentages are relative to "as designed" for this particle type) ───
    readonly property var s: ShellState.settings
    readonly property real density: (s.partCount ?? 100) / 100
    readonly property real baseSize: s.partSize ?? 13               // px
    readonly property real sizeVar: (s.partSizeVar ?? 45) / 100     // 0 — все одного размера / 0: all the same size
    readonly property real alpha: (s.partOpacity ?? 22) / 100
    readonly property real speed: Math.max(0.1, (s.partSpeed ?? 100) / 100)
    readonly property real spin: (s.partSpin ?? 100) / 100          // 0 — не вращаются / 0: no spinning
    readonly property real sway: (s.partSway ?? 100) / 100
    readonly property string colorMode: s.partColor ?? "auto"       // auto | accent | accent2 | text | mix

    // у каждого вида своё «как задумано»: время пролёта (мс), снос вбок (px), оборот (мс)
    // each type has its own "as designed": fall time (ms), sideways drift (px), one turn (ms)
    readonly property var base: ({
        petals:  { fall: [16000, 38000], drift: [30, 140], turn: [9000, 23000], up: false, sizeK: 1.0 },
        stars:   { fall: [20000, 42000], drift: [20, 90],  turn: [12000, 30000], up: false, sizeK: 1.0 },
        snow:    { fall: [10000, 22000], drift: [15, 60],  turn: [20000, 40000], up: false, sizeK: 0.85 },
        bubbles: { fall: [18000, 40000], drift: [20, 80],  turn: [0, 0],         up: true,  sizeK: 1.1 }
    })[kind] ?? { fall: [16000, 38000], drift: [30, 140], turn: [9000, 23000], up: false, sizeK: 1 }

    // плотность как на сайте: одна частица на ~34000 px² (от 18 до 90), умноженная на настройку
    // density as on the website: one particle per ~34000 px² (18 to 90), multiplied by the setting
    readonly property int count: live ? Math.round(Math.min(400, Math.max(4, density * Math.min(90, Math.max(18, width * height / 34000))))) : 0

    function tint(r: real): color {
        const m = colorMode === "auto" ? (kind === "snow" ? "text" : "accent") : colorMode;
        if (m === "mix") return r < 0.4 ? Theme.accent : r < 0.75 ? Theme.accent2 : Theme.text;
        return m === "accent2" ? Theme.accent2 : m === "text" ? Theme.text : Theme.accent;
    }

    // скорость, вращение и вид меняют длительности анимаций — проще пересоздать частицы
    // speed, spin and type change animation durations, so it's simpler to recreate the particles
    readonly property string animKey: kind + "|" + speed + "|" + spin + "|" + sway
    onAnimKeyChanged: { rep.model = 0; Qt.callLater(() => { rep.model = Qt.binding(() => field.count); }); }

    Repeater {
        id: rep
        model: field.count
        delegate: Item {
            id: p
            // случайное у каждой частицы — своё и постоянное, настройки только масштабируют его
            // each particle's randomness is its own and constant; the settings only scale it
            readonly property real rSize: Math.random()
            readonly property real rAlpha: Math.random()
            readonly property real rColor: Math.random()
            readonly property real frac: Math.random()
            readonly property real x0: Math.random() * field.width
            readonly property real drift: (field.base.drift[0] + Math.random() * (field.base.drift[1] - field.base.drift[0]))
                                          * field.sway * (Math.random() < 0.5 ? -1 : 1)
            readonly property int fall: (field.base.fall[0] + Math.random() * (field.base.fall[1] - field.base.fall[0])) / field.speed
            readonly property int turn: field.base.turn[1] > 0 && field.spin > 0
                                        ? (field.base.turn[0] + Math.random() * (field.base.turn[1] - field.base.turn[0])) / field.spin : 0
            readonly property real sz: Math.max(2, field.baseSize * field.base.sizeK * (1 + (rSize * 2 - 1) * field.sizeVar))
            readonly property bool up: field.base.up
            width: sz
            height: sz
            x: x0
            opacity: Math.min(1, field.alpha * (0.5 + rAlpha))

            // падение (или подъём у пузырьков): первый проход с случайной высоты, дальше — по кругу
            // falling (or rising, for bubbles): the first pass from a random height, then in a loop
            SequentialAnimation on y {
                running: field.live
                paused: field.paused
                NumberAnimation { from: p.up ? (1 - p.frac) * field.height : p.frac * field.height
                                  to: p.up ? -40 : field.height + 30; duration: Math.max(1, p.fall * (1 - p.frac)) }
                NumberAnimation { from: p.up ? field.height + 40 : -30; to: p.up ? -40 : field.height + 30
                                  duration: p.fall; loops: Animation.Infinite }
            }
            // покачивание в сторону
            // swaying sideways
            SequentialAnimation on x {
                running: field.live && p.drift !== 0
                paused: field.paused
                loops: Animation.Infinite
                NumberAnimation { from: p.x0; to: p.x0 + p.drift; duration: Math.max(1, p.fall / 2); easing.type: Easing.InOutSine }
                NumberAnimation { from: p.x0 + p.drift; to: p.x0; duration: Math.max(1, p.fall / 2); easing.type: Easing.InOutSine }
            }
            // вращение вокруг своей оси
            // spinning around its own axis
            NumberAnimation on rotation {
                running: field.live && p.turn > 0
                paused: field.paused
                from: 0
                to: Math.random() < 0.5 ? 360 : -360
                duration: Math.max(1, p.turn)
                loops: Animation.Infinite
            }

            readonly property color col: field.tint(rColor)

            // лепесток: овал с выемкой сверху
            // petal: an oval with a notch on top
            Shape {
                visible: field.kind === "petals"
                width: 24; height: 24
                scale: p.sz / 24
                anchors.centerIn: parent
                ShapePath {
                    fillColor: p.col
                    strokeWidth: -1
                    PathSvg { path: "M12 4 L9.5 0.5 C4 2 0.5 8 2.5 15 C4.5 21 9 24 12 24 C15 24 19.5 21 21.5 15 C23.5 8 20 2 14.5 0.5 Z" }
                }
            }
            // звёздочка — глиф из шрифта сайта; мерцает
            // star: a glyph from the website font; twinkles
            Icon {
                visible: field.kind === "stars"
                anchors.centerIn: parent
                name: "sparkle"
                size: p.sz
                color: p.col
                SequentialAnimation on opacity {
                    running: field.live && field.kind === "stars"
                    paused: field.paused
                    loops: Animation.Infinite
                    PauseAnimation { duration: Math.random() * 4000 }
                    NumberAnimation { to: 0.35; duration: 1400 + Math.random() * 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1400 + Math.random() * 1600; easing.type: Easing.InOutSine }
                }
            }
            // снежинка: шесть лучей с веточками
            // snowflake: six rays with branches
            Shape {
                visible: field.kind === "snow"
                width: 24; height: 24
                scale: p.sz / 24
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: p.col
                    strokeWidth: 1.8
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: "M12 12 L12.00 1.00 M12.00 5.62 L9.59 2.94 M12.00 5.62 L14.41 2.94 M12 12 L2.47 6.50 M6.47 8.81 L2.95 9.56 M6.47 8.81 L5.36 5.39 M12 12 L2.47 17.50 M6.47 15.19 L5.36 18.61 M6.47 15.19 L2.95 14.44 M12 12 L12.00 23.00 M12.00 18.38 L14.41 21.06 M12.00 18.38 L9.59 21.06 M12 12 L21.53 17.50 M17.53 15.19 L21.05 14.44 M17.53 15.19 L18.64 18.61 M12 12 L21.53 6.50 M17.53 8.81 L18.64 5.39 M17.53 8.81 L21.05 9.56" }
                }
            }
            // пузырёк: тонкое кольцо с бликом
            // bubble: a thin ring with a highlight
            Rectangle {
                visible: field.kind === "bubbles"
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(p.col.r, p.col.g, p.col.b, 0.18)
                border.width: Math.max(1, p.sz / 14)
                border.color: p.col
                Rectangle { x: parent.width * 0.22; y: parent.height * 0.2; width: parent.width * 0.22; height: width; radius: width / 2
                            color: p.col; opacity: 0.8 }
            }
        }
    }
}
