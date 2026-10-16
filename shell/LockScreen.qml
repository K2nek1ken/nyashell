import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

// экран блокировки почти как у caelestia: размытый снимок стола, в центре — одна большая
// скруглённая группа. Появляется из маленькой плитки с замком (крутится и раскрывается),
// при разблокировке сворачивается обратно. Символы пароля — фигурки, как на Pixel.
// a lock screen much like caelestia's: a blurred snapshot of the desktop, one big rounded
// group in the centre. It appears from a small tile with a lock (spins and unfolds)
// and folds back on unlock. Password characters are little shapes, as on Pixel.
Scope {
    id: root
    property string buffer: ""
    property string status: ""          // "" | "check" | "fail" | "error" | "max"
    property int shakes: 0
    property bool leaving: false
    property bool showPassword: false
    property var fetch: ({})

    // «прогрев» захвата экрана (приём из caelestia)
    // "warming up" screen capture (a trick from caelestia)
    Loader {
        active: true
        asynchronous: true
        onLoaded: active = false
        sourceComponent: ScreencopyView { captureSource: Quickshell.screens[0] }
    }

    Process {
        id: fetchProc
        command: ["sh", "-c",
            ". /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\"; uname -r; cat /etc/hostname 2>/dev/null || hostname; " +
            "pacman -Qq 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.fetch = { os: l[0] || "Linux", kernel: l[1] || "", host: (l[2] || "").trim(), pkgs: (l[3] || "").trim() };
            }
        }
    }
    Connections {
        target: ShellState
        function onLockedChanged() {
            if (ShellState.locked) { fetchProc.running = true; SysInfo.watchers++; root.buffer = ""; root.status = ""; }
            else SysInfo.watchers = Math.max(0, SysInfo.watchers - 1);
        }
    }

    // карточка внутри группы
    // a card inside the group
    component Card: Rectangle {
        default property alias content: inner.data
        radius: Tokens.rounding.large + 4
        color: Theme.surface
        Item { id: inner; anchors.fill: parent; anchors.margins: Tokens.gap.large }
    }

    WlSessionLock {
        id: lock
        locked: ShellState.locked

        WlSessionLockSurface {
            id: surf
            color: "black"

            // стадии: 0 — ещё ничего, 1 — плитка с замком, 2 — раскрыто, 3 — уходим
            // stages: 0 nothing yet, 1 tile with the lock, 2 unfolded, 3 leaving
            property int stage: 0
            readonly property bool open: stage === 2
            Timer { interval: 30; running: true; onTriggered: surf.stage = 1 }
            Timer { interval: 480; running: surf.stage === 1; onTriggered: surf.stage = 2 }
            Connections {
                target: root
                function onLeavingChanged() { if (root.leaving) surf.stage = 3; }
            }

            // размеры как у caelestia: высота 0.7 экрана, 16:9, центр 600 × масштаб
            // sizes as in caelestia: height 0.7 of the screen, 16:9, centre 600 × scale
            readonly property real k: Math.min(1, height / 1440)
            readonly property real bigH: height * 0.7
            readonly property real bigW: Math.min(width * 0.94, bigH * 16 / 9)
            readonly property real centerW: 600 * Math.max(0.75, k)
            readonly property real tile: 110

            // ─── фон: снимок стола или обои, размытый ───
            // стол не «гаснет», а плавно размывается (и обратно при разблокировке)
            // ─── background: desktop snapshot or wallpaper, blurred ───
            // the desktop doesn't "go dark", it blurs smoothly (and back on unlock)
            Item {
                id: bg
                anchors.fill: parent
                property real amount: surf.stage >= 1 && surf.stage < 3 ? 1 : 0
                Behavior on amount { Anim { kind: "slowEffects"; duration: 500 } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blurMax: 64
                    blur: bg.amount
                    brightness: -0.15 * bg.amount
                }
                Image {
                    anchors.fill: parent
                    source: ShellState.wallpaper ? "file://" + ShellState.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // снимок стола, сделанный grim ДО блокировки (во время блокировки захват уже не работает)
                // a desktop snapshot taken by grim BEFORE locking (capture no longer works while locked)
                Image {
                    anchors.fill: parent
                    visible: ShellState.lockShotTime > 0
                    source: ShellState.lockShotTime > 0 ? "file://" + ShellState.lockShot + "?" + ShellState.lockShotTime : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: false
                }
            }

            // вуаль перед сном: плавно в чёрное и обратно после пробуждения
            // a veil before sleep: smoothly to black and back after waking
            Rectangle {
                id: veil
                anchors.fill: parent
                z: 100
                color: "black"
                opacity: 0
                readonly property bool want: ShellState.sleepPending && surf.open
                onWantChanged: if (want) down.restart()
                Connections { target: ShellState; function onSleepFadeChanged() { if (!ShellState.sleepFade) up.restart(); } }
                SequentialAnimation {
                    id: down
                    PauseAnimation { duration: 250 }                 // дать увидеть экран блокировки / let the lock screen be seen
                    NumberAnimation { target: veil; property: "opacity"; to: 1; duration: 700; easing.type: Easing.InOutQuad }
                    ScriptAction { script: { ShellState.sleepFade = true; ShellState.sleepReady(); } }
                }
                NumberAnimation { id: up; target: veil; property: "opacity"; to: 0; duration: 600; easing.type: Easing.OutQuad }
                // если система так и не уснула (например, крышка настроена только блокировать) — экран
                // проявляется от движения мыши или касания тачпада. Но только от настоящего движения:
                // когда вуаль появляется под неподвижным курсором, Qt присылает «движение» сам по себе,
                // и при закрытии крышки это будило экран (сон отменялся по нашей же вине).
                // Курсор над чёрной вуалью спрятан — он маячил, пока экран не погаснет
                // if the system never fell asleep (e.g. the lid is set to only lock), the screen
                // reappears on mouse movement or a touchpad touch. But only on real movement:
                // when the veil appears under a still cursor, Qt sends a "move" by itself,
                // and on closing the lid this woke the screen (sleep was cancelled by our own fault).
                // The cursor is hidden over the black veil: it hovered there until the screen went off
                MouseArea {
                    id: veilMouse
                    anchors.fill: parent
                    enabled: veil.opacity > 0.5
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    property real sx: -1
                    property real sy: -1
                    property real since: 0
                    onEnabledChanged: { sx = -1; since = Date.now(); }
                    function wake(): void { down.stop(); ShellState.woke(); }
                    onPositionChanged: (m) => {
                        if (Date.now() - since < 1500) return;             // сразу после появления — не считаем / right after appearing: doesn't count
                        if (sx < 0) { sx = m.x; sy = m.y; return; }       // первая точка — только запоминаем / first point: only remember it
                        if (Math.abs(m.x - sx) + Math.abs(m.y - sy) > 24) wake();
                    }
                    onPressed: if (Date.now() - since > 600) wake()
                }
            }

            // ─── группа ───
            // ─── group ───
            Item {
                id: box
                anchors.centerIn: parent
                width: surf.open ? surf.bigW : surf.tile
                height: surf.open ? surf.bigH : surf.tile
                scale: surf.stage === 1 || surf.stage === 2 ? 1 : 0
                rotation: surf.stage >= 1 ? 360 : 180
                Behavior on width { Anim { kind: "spatial" } }
                Behavior on height { Anim { kind: "spatial" } }
                Behavior on scale { Anim { kind: "fastSpatial" } }
                Behavior on rotation { Anim { kind: "emphasized"; duration: 420 } }

                Rectangle {
                    anchors.fill: parent
                    radius: surf.open ? Tokens.rounding.extraLarge * 1.5 : surf.tile / 4
                    color: Theme.frame
                    Behavior on radius { Anim { kind: "spatial" } }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; blurMax: 15; shadowColor: "#b0000000" }
                }
                // замок в плитке
                // the lock in the tile
                Icon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: 40
                    color: Theme.accent
                    opacity: surf.open ? 0 : 1
                    rotation: surf.open ? 360 : 0
                    Behavior on opacity { Anim { kind: "effects" } }
                    Behavior on rotation { Anim { kind: "standard" } }
                }

                // содержимое
                // content
                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Tokens.gap.large + 4
                    opacity: surf.open ? 1 : 0
                    scale: surf.open ? 1 : 0.8
                    visible: opacity > 0.01
                    Behavior on opacity { Anim { kind: "effects" } }
                    Behavior on scale { Anim { kind: "spatial" } }

                    readonly property real gap: 20
                    readonly property real sideW: (width - surf.centerW - gap * 2) / 2

                    SystemClock { id: clock; precision: SystemClock.Seconds }

                    // ── левая колонка: погода, система, музыка ──
                    // ── left column: weather, system, music ──
                    Column {
                        width: content.sideW
                        height: parent.height
                        spacing: 12

                        Card {
                            width: parent.width
                            height: 150
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16
                                Icon { name: Weather.iconFor(Weather.code, !Weather.isDay); size: 54; color: Theme.accent
                                       anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { font.family: Theme.font; font.pixelSize: 34; font.bold: true; color: Theme.text
                                           text: Weather.ok ? Weather.temp + "°" : "…" }
                                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; color: Theme.text
                                           text: Weather.ok ? Weather.desc : L.t("нет данных") }
                                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                                           text: Weather.ok ? Weather.city + L.t(" · ощущается ") + Weather.feels + "°" : "" }
                                }
                            }
                        }
                        Card {
                            width: parent.width
                            height: 176
                            Column {
                                anchors.fill: parent
                                spacing: 8
                                Repeater {
                                    model: [
                                        ["pets", root.fetch.os ?? ""],
                                        ["memory", L.t("ядро ") + (root.fetch.kernel ?? "")],
                                        ["dashboard", "mango · nyashell"],
                                        ["hdd", (root.fetch.pkgs ?? "") + L.t(" пакетов")],
                                        ["clock", L.t("в сети ") + SysInfo.uptimeText]
                                    ]
                                    delegate: Row {
                                        required property var modelData
                                        spacing: 12
                                        Rectangle { width: 26; height: 26; radius: 13; color: Theme.tonal
                                                    Icon { anchors.centerIn: parent; name: modelData[0]; size: 12; color: Theme.accent } }
                                        Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                                               font.pixelSize: Tokens.font.smaller; color: Theme.text; text: modelData[1]
                                               elide: Text.ElideRight; width: content.sideW - 80 }
                                    }
                                }
                            }
                        }
                        Card {
                            readonly property var p: Mpris.players.values.find(x => x.isPlaying) ?? Mpris.players.values[0] ?? null
                            width: parent.width
                            height: parent.height - 150 - 176 - 24
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                Vinyl { anchors.horizontalCenter: parent.horizontalCenter
                                        size: Math.min(130, parent.parent.height - 110)
                                        art: parent.parent.parent.p?.trackArtUrl ?? ""
                                        spinning: (parent.parent.parent.p?.isPlaying ?? false) && surf.open }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; width: content.sideW - 60
                                       horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                       font.family: Theme.font; font.pixelSize: Tokens.font.normal; font.bold: true; color: Theme.text
                                       text: parent.parent.parent.p?.trackTitle || L.t("тишина") }
                                MediaControls { anchors.horizontalCenter: parent.horizontalCenter; player: parent.parent.parent.p; big: 38 }
                            }
                        }
                    }

                    // ── центр: часы, дата, аватар, пароль ──
                    // ── centre: clock, date, avatar, password ──
                    Column {
                        x: content.sideW + content.gap
                        width: surf.centerW
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 18

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Text { font.family: Theme.font; font.pixelSize: 130 * Math.max(0.75, surf.k); font.bold: true
                                   color: Theme.accent; text: Qt.formatDateTime(clock.date, "HH") }
                            Text { font.family: Theme.font; font.pixelSize: 130 * Math.max(0.75, surf.k); font.bold: true
                                   color: Theme.accent2; text: Qt.formatDateTime(clock.date, "mm") }
                        }
                        // «циферблат» Nothing OS 5.0: дата, погода, музыка/уведомления, время в сети
                        // Nothing OS 5.0 "dial": date, weather, music/notifications, time online
                        NothingFace {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 22 * Math.max(0.8, surf.k * 1.1)
                            date: clock.date
                        }

                        // аватар: ~/.face, иначе лапка
                        // avatar: ~/.face, otherwise the paw
                        ClippingRectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: surf.centerW * 0.24; height: width
                            radius: width * 0.42
                            color: Theme.surfaceHi
                            Icon { anchors.centerIn: parent; visible: face.status !== Image.Ready
                                   name: "pets"; size: parent.width * 0.4; color: Theme.accent }
                            Image { id: face; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
                                    source: "file://" + Quickshell.env("HOME") + "/.face" }
                        }

                        // поле пароля: таблетка, растёт при вводе
                        // password field: a pill that grows as you type
                        Rectangle {
                            id: pill
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.buffer ? surf.centerW * 0.8 : Math.min(surf.centerW * 0.8, ph.implicitWidth + 130)
                            height: 56
                            radius: 28
                            color: Theme.surface
                            border.color: root.status === "fail" || root.status === "max" ? Theme.danger : "transparent"
                            Behavior on width { Anim { kind: "spatial" } }
                            transform: Translate { id: shake }
                            Connections {
                                target: root
                                function onShakesChanged() { shakeAnim.restart(); input.text = ""; }
                            }
                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                                NumberAnimation { target: shake; property: "x"; to: 12; duration: 70 }
                                NumberAnimation { target: shake; property: "x"; to: -8; duration: 70 }
                                NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
                            }

                            // замок / глаз слева
                            // lock / eye on the left
                            Item {
                                x: 6; width: 44; height: parent.height
                                Icon { anchors.centerIn: parent; name: root.showPassword ? "eye" : "lock"; size: 16
                                       color: root.status === "max" ? Theme.danger : Theme.textDim }
                                StateLayer { anchors.fill: undefined; anchors.centerIn: parent; width: 38; height: 38; radius: 19
                                             onClicked: { root.showPassword = !root.showPassword; input.forceActiveFocus(); } }
                            }

                            // подсказка или фигурки
                            // hint or shapes
                            Item {
                                x: 54; width: parent.width - 108; height: parent.height
                                clip: true
                                Text {
                                    id: ph
                                    anchors.centerIn: parent
                                    opacity: root.buffer ? 0 : 1
                                    Behavior on opacity { Anim { kind: "effects" } }
                                    font.family: Theme.font; font.pixelSize: Tokens.font.normal
                                    color: root.status === "check" ? Theme.accent2 : Theme.textDim
                                    text: root.status === "check" ? L.t("проверяю…") : root.status === "max" ? L.t("слишком много попыток") : L.t("введи пароль")
                                }
                                Text {
                                    visible: root.showPassword
                                    anchors.centerIn: parent
                                    font.family: Theme.font; font.pixelSize: Tokens.font.larger; color: Theme.text
                                    text: root.buffer
                                }
                                // модель меняем по одному символу — иначе все фигурки анимировались бы заново
                                // the model changes one character at a time, otherwise every shape would animate again
                                ListModel { id: chars }
                                Connections {
                                    target: root
                                    function onBufferChanged() {
                                        const n = root.buffer.length;
                                        while (chars.count < n) chars.append({});
                                        while (chars.count > n) chars.remove(chars.count - 1);
                                    }
                                }
                                ListView {
                                    SmoothWheel {}
                                    visible: !root.showPassword
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, contentWidth)
                                    height: 22
                                    orientation: ListView.Horizontal
                                    interactive: false
                                    spacing: 4
                                    model: chars
                                    delegate: Item {
                                        id: ch
                                        width: 22 * wmul
                                        height: 22
                                        property real wmul: 1.3
                                        readonly property int kind: Math.floor(Math.random() * 8)
                                        // Pixel: сначала случайная фигурка, через миг — сжимается в кружок
                                        // Pixel: a random shape first, a moment later it shrinks into a dot
                                        LockShape {
                                            id: fig
                                            anchors.centerIn: parent
                                            size: 22
                                            kind: ch.kind
                                            color: Theme.accent
                                            scale: 0
                                        }
                                        Rectangle {
                                            id: dot
                                            anchors.centerIn: parent
                                            width: 22; height: 22; radius: 11
                                            color: Theme.accent
                                            opacity: 0
                                            scale: 1
                                        }
                                        SequentialAnimation {
                                            running: true
                                            ParallelAnimation {
                                                Anim { target: fig; property: "scale"; from: 0; to: 1; kind: "fastSpatial" }
                                                Anim { target: fig; property: "rotation"; from: -90; to: 0; kind: "fastSpatial" }
                                            }
                                            PauseAnimation { duration: 180 }
                                            ParallelAnimation {
                                                Anim { target: fig; property: "opacity"; to: 0; kind: "fastEffects" }
                                                Anim { target: dot; property: "opacity"; to: 1; kind: "fastEffects" }
                                                Anim { target: dot; property: "scale"; from: 1; to: 2 / 3; kind: "fastSpatial" }
                                                Anim { target: ch; property: "wmul"; to: 1; kind: "effects" }
                                            }
                                        }
                                    }
                                }
                            }

                            // кнопка «войти»: кружок → стрелка акцентом, когда что-то введено
                            // the "log in" button: dot → an accent arrow once something is typed
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40; height: 40
                                radius: root.buffer ? 14 : 20
                                color: root.buffer ? Theme.accent : Theme.surfaceHi
                                scale: root.buffer ? (enterMouse.pressed ? 0.85 : 1) : 0.8
                                Behavior on radius { Anim { kind: "fastSpatial" } }
                                Behavior on scale { Anim { kind: "fastSpatial" } }
                                Behavior on color { CAnim {} }
                                Icon { anchors.centerIn: parent; name: "chevron_right"; size: 14
                                       color: root.buffer ? Theme.onAccent : Theme.textDim }
                                MouseArea { id: enterMouse; anchors.fill: parent; onClicked: root.submit() }
                            }

                            TextInput {
                                id: input
                                anchors.fill: parent
                                opacity: 0
                                focus: true
                                echoMode: TextInput.Password
                                enabled: root.status !== "check" && !root.leaving
                                onTextChanged: root.buffer = text
                                Component.onCompleted: forceActiveFocus()
                                onActiveFocusChanged: if (!activeFocus && surf.open) forceActiveFocus()
                                Keys.onReturnPressed: root.submit()
                                Keys.onEnterPressed: root.submit()
                                Keys.onEscapePressed: text = ""
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                            color: Theme.danger
                            opacity: root.status === "fail" || root.status === "error" ? 1 : 0
                            Behavior on opacity { Anim { kind: "effects" } }
                            text: root.status === "error" ? L.t("ошибка PAM") : L.t("неверный пароль")
                        }
                    }

                    // ── правая колонка: ресурсы и уведомления ──
                    // ── right column: resources and notifications ──
                    Column {
                        x: content.sideW + content.gap * 2 + surf.centerW
                        width: content.sideW
                        height: parent.height
                        spacing: 12

                        Card {
                            width: parent.width
                            height: 250
                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 18
                                Repeater {
                                    model: [["memory", L.t("процессор"), () => SysInfo.cpu, false],
                                            ["dashboard", L.t("память"), () => SysInfo.mem, true],
                                            ["hdd", L.t("диск"), () => SysInfo.disk, false],
                                            ["thermo", L.t("темп."), () => Math.min(1, SysInfo.temp / 100), true]]
                                    delegate: Column {
                                        required property var modelData
                                        spacing: 4
                                        Gauge { anchors.horizontalCenter: parent.horizontalCenter
                                                size: Math.min(80, (content.sideW - 80) / 2); thickness: 7
                                                icon: modelData[0]; value: modelData[2]()
                                                color: modelData[3] ? Theme.accent2 : Theme.accent }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.font
                                               font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData[1] }
                                    }
                                }
                            }
                        }
                        Card {
                            width: parent.width
                            height: parent.height - 250 - 12
                            Column {
                                anchors.fill: parent
                                spacing: 8
                                Row {
                                    spacing: 8
                                    Icon { name: "bell"; size: 13; color: Theme.accent }
                                    Text { font.family: Theme.font; font.pixelSize: Tokens.font.normal; font.bold: true; color: Theme.text
                                           text: Notifs.history.length ? L.t("уведомления · ") + Notifs.history.length : L.t("уведомлений нет") }
                                }
                                Repeater {
                                    model: Notifs.history.slice(0, 4)
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: content.sideW - 32
                                        height: 58
                                        radius: Tokens.rounding.large
                                        color: Theme.surfaceHi
                                        Column {
                                            x: 12; anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                            Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent
                                                   text: modelData.app + " · " + Notifs.ago(modelData.time) }
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font
                                                   font.pixelSize: Tokens.font.smaller; font.bold: true; color: Theme.text; text: modelData.summary }
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; textFormat: Text.PlainText
                                                   font.pixelSize: Tokens.font.small; color: Theme.textDim; text: modelData.body.replace(/<[^>]+>/g, "") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function submit(): void {
        if (buffer.length === 0 || pam.active) return;
        status = "check";
        pam.start();
    }

    // разблокировка: группа сворачивается обратно в плитку и исчезает, потом снимаем блокировку
    // unlock: the group folds back into the tile and disappears, then the lock is released
    Timer {
        id: unlockDelay
        interval: 560
        onTriggered: { ShellState.locked = false; root.leaving = false; root.showPassword = false; }
    }

    PamContext {
        id: pam
        config: "passwd"
        configDirectory: Quickshell.shellPath("pam.d")
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(root.buffer);
        }
        onCompleted: (res) => {
            if (res === PamResult.Success) {
                root.status = "";
                root.buffer = "";
                root.leaving = true;
                unlockDelay.restart();
                return;
            }
            root.status = res === PamResult.MaxTries ? "max" : res === PamResult.Failed ? "fail" : "error";
            root.shakes++;
            reset.restart();
        }
    }
    Timer { id: reset; interval: 3000; onTriggered: if (root.status !== "max") root.status = "" }
}
