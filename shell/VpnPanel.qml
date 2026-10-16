import Quickshell
import Quickshell.Io
import QtQuick

// выпадашка VPN (значок-ключ на панели): группы и подписки, серверы, подключение, TUN/прокси.
// карточка группы: клик — раскрыть серверы, ⟳ — обновить подписку, ПКМ — изменить/удалить
// VPN popup (the key icon on the bar): groups and subscriptions, servers, connection, TUN/proxy.
// group card: click to expand the servers, ⟳ updates the subscription, right-click to edit/delete
BarPopup {
    id: vp
    cardWidth: 660
    cardHeight: 560
    property string page: "list"           // list | rules | opts | add | rule | links | node
    property string ruleEditing: ""        // правило в форме (пусто — новое) / the rule in the form (empty: a new one)
    property string ruleOut: "direct"
    property string addKind: "sub"         // sub | manual
    property string open: ""               // открытая вкладка группы / open group tab
    readonly property bool showLogs: Vpn.showLogs
    readonly property bool form: page === "add" || page === "rule" || page === "links" || page === "node"
    property string editing: ""            // группа, которую правим (форма та же, что для добавления) / the group being edited (same form as for adding)
    function show(x: real): void { page = "list"; openAt(x); }
    onPastePressed: if (page === "list") pasteImport()
    onSelectAllPressed: if (page === "list" && srv.group) { picked = Vpn.order(srv.group); pickAnchor = 0; }

    // ─── мультивыделение, как в NekoBox: Ctrl+клик — добавить/убрать, Shift+клик — диапазон, Ctrl+A — все ───
    // ─── multi-selection, as in NekoBox: Ctrl+click to add/remove, Shift+click for a range, Ctrl+A for all ───
    property var picked: []                // настоящие номера узлов в открытой группе / real node indices in the open group
    property int pickAnchor: -1            // откуда тянуть диапазон (позиция в таблице) / where a range starts (position in the table)
    function pickClick(row: int, i: int, mods: int): bool {
        if (mods & Qt.ShiftModifier && pickAnchor >= 0) {
            const ord = Vpn.order(srv.group), a = Math.min(pickAnchor, row), b = Math.max(pickAnchor, row);
            picked = ord.slice(a, b + 1);
            return true;
        }
        if (mods & Qt.ControlModifier) {
            picked = picked.includes(i) ? picked.filter(x => x !== i) : picked.concat([i]);
            pickAnchor = row;
            return true;
        }
        return false;
    }

    component Field: Rectangle {
        id: fld
        signal enter()
        property alias text: ti.text
        property string hint: ""
        property bool multi: false
        // подсказки как в fish: по началу текущей строки — полупрозрачное продолжение, Tab или → — принять
        // fish-style suggestions: from the start of the current line a translucent continuation, Tab or → to accept
        property var suggest: []
        readonly property string curLine: {
            const t = ti.text.slice(0, ti.cursorPosition), i = t.lastIndexOf("\n");
            return t.slice(i + 1);
        }
        readonly property string ghost: {
            if (!suggest.length || !ti.activeFocus || curLine.length < 1) return "";
            const after = ti.text.slice(ti.cursorPosition);
            if (after.length && after[0] !== "\n") return "";             // подсказываем только в конце строки / suggest only at the end of the line
            const low = curLine.toLowerCase();
            const m = suggest.find(x => x.toLowerCase().startsWith(low) && x.length > curLine.length);
            return m ? m.slice(curLine.length) : "";
        }
        function acceptGhost(): bool {
            if (!ghost) return false;
            ti.insert(ti.cursorPosition, ghost);
            return true;
        }
        width: 380; height: multi ? 96 : 36; radius: multi ? 14 : 18
        color: Theme.surface
        border.color: ti.activeFocus ? Theme.accent : Theme.outline
        TextEdit {
            id: ti
            anchors.fill: parent; anchors.margins: 10; anchors.leftMargin: 14
            verticalAlignment: parent.multi ? TextEdit.AlignTop : TextEdit.AlignVCenter
            wrapMode: TextEdit.WrapAnywhere
            font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text
            Keys.onReturnPressed: (e) => { if (parent.multi) e.accepted = false; else parent.enter(); }
            Keys.onTabPressed: (e) => { e.accepted = fld.acceptGhost(); }
            Keys.onRightPressed: (e) => { e.accepted = fld.acceptGhost(); }
            Text { visible: !ti.text; font: ti.font; color: Theme.textDim; text: parent.parent.hint; width: parent.width; wrapMode: Text.Wrap }
            // само продолжение — сразу за курсором
            // the continuation itself, right after the cursor
            Text {
                visible: fld.ghost !== ""
                readonly property rect r: ti.positionToRectangle(ti.cursorPosition)
                x: r.x; y: r.y
                font: ti.font; color: Theme.textDim; opacity: 0.6
                text: fld.ghost
            }
        }
    }

    // ряд «таблеток» с выбором одного значения
    // a row of "pills" choosing one value
    component Chips: Flow {
        id: chipsRow
        property var opts: []                  // [[значение, подпись]] / [[value, label]]
        property var current
        signal pick(var v)
        width: parent ? parent.width : 400
        spacing: 4
        Repeater {
            model: chipsRow.opts
            delegate: Rectangle {
                required property var modelData
                readonly property bool sel: chipsRow.current === modelData[0]
                width: ct2.implicitWidth + 20; height: 26; radius: 13
                color: sel ? Theme.accent : Theme.surfaceHi
                Text { id: ct2; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                MouseArea { anchors.fill: parent; onClicked: chipsRow.pick(modelData[0]) }
            }
        }
    }
    // переключатель с заголовком и подсказкой
    // a switch with a title and a hint
    component Toggle2: Rectangle {
        id: tg
        property string title
        property string hint: ""
        property bool on: false
        signal flip()
        width: 380; height: hint ? 50 : 36; radius: 18
        color: tgm.containsMouse ? Theme.surfaceHi : "transparent"
        Column { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80
            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: tg.title }
            Text { visible: !!tg.hint; width: parent.width; elide: Text.ElideRight; font.family: Theme.font
                   font.pixelSize: Tokens.font.small; color: Theme.textDim; text: tg.hint } }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 24; radius: 12; color: tg.on ? Theme.accent : Theme.surfaceHi
                    Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                x: tg.on ? parent.width - width - 4 : 4
                                color: tg.on ? Theme.onAccent : Theme.textDim
                                Behavior on x { Anim { kind: "fastSpatial" } } } }
        MouseArea { id: tgm; anchors.fill: parent; hoverEnabled: true; onClicked: tg.flip() }
    }
    // куда положить серверы: одна из своих групп или новая (тогда — поле для названия). Подписок тут нет:
    // при обновлении их список приходит целиком заново, и добавленное руками пропало бы
    // where to put the servers: one of your groups or a new one (then a name field). No subscriptions here:
    // on update their list arrives anew as a whole, and anything added by hand would be lost
    component GroupPick: Column {
        id: gp
        property string target: "__new"
        property alias newName: gpn.text
        width: parent ? parent.width : 400
        spacing: 6
        Chips {
            opts: Vpn.manualGroups.map(g => [g.id, g.name]).concat([["__new", "+ " + L.t("новая группа")]])
            current: gp.target
            onPick: (v) => gp.target = v
        }
        Field { id: gpn; width: gp.width; visible: gp.target === "__new"; hint: L.t("название новой группы") }
        // группа по умолчанию: открытая (если своя), иначе первая своя, иначе новая
        // the default group: the open one (if it's yours), otherwise your first one, otherwise a new one
        function reset(preferId: string): void {
            const own = Vpn.manualGroups;
            target = own.some(g => g.id === preferId) ? preferId : (own[0]?.id ?? "__new");
            gpn.text = "";
        }
    }
    // подпись раздела формы / a form section label
    component Label2: Text { topPadding: 4; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent }
    ContextMenu { id: menu; screen: vp.screen }
    function fmtDate(ms: real): string { return ms ? Qt.formatDateTime(new Date(ms), "dd.MM hh:mm") : "—"; }
    function infoLine(g): string {
        const i = g.info || {}, parts = [];
        const used = (i.upload || 0) + (i.download || 0);
        if (i.total) parts.push(Vpn.human(used) + " / " + Vpn.human(i.total));
        else if (used) parts.push(Vpn.human(used) + L.t(" использовано"));
        if (i.expire) parts.push(L.t("до ") + Qt.formatDate(new Date(i.expire * 1000), "dd.MM.yyyy"));
        parts.push(g.nodes.length + L.t(" серв."));
        return parts.join("  ·  ");
    }

    Item {
        anchors.fill: parent
        anchors.margins: Tokens.gap.large

        // ── шапка ──
        // ── header ──
        Row {
            id: head
            spacing: 10
            PlaneIcon { size: 20; on: Vpn.running; busy: Vpn.wanted && !Vpn.running
                        color: Vpn.running ? Theme.accent : Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.larger; font.bold: true; color: Theme.text
                       text: vp.page === "add" ? (vp.editing ? L.t("Изменить группу") : L.t("Новая группа"))
                           : vp.page === "rule" ? (vp.ruleEditing ? L.t("Изменить маршрут") : L.t("Новый маршрут"))
                           : vp.page === "links" ? L.t("Добавить ссылки")
                           : vp.page === "node" ? (vp.nodeIdx >= 0 ? L.t("Изменить сервер") : L.t("Новый сервер")) : "VPN" }
                Text { width: 300; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: Vpn.status && !Vpn.running ? Theme.danger : Theme.textDim
                       text: vp.form ? "" : Vpn.status || (Vpn.running
                             ? (L.t("подключено: ") + (Vpn.node?.name ?? "") + (Vpn.livePing ? "  ·  " + (Vpn.livePing < 0 ? L.t("нет связи") : Vpn.livePing + " ms") : "  ·  " + L.t("клик — проверить")))
                             : L.t("отключено"))
                       MouseArea { anchors.fill: parent; enabled: Vpn.running; cursorShape: Qt.PointingHandCursor; onClicked: Vpn.testCurrent() } }
            }
        }
        Rectangle {
            anchors.right: parent.right
            width: 30; height: 30; radius: 15
            visible: vp.page !== "opts"
            readonly property bool form: vp.form
            color: form ? Theme.accent : Theme.surfaceHi
            Icon { anchors.centerIn: parent; name: parent.form ? "close" : "plus"; size: 12; color: parent.form ? Theme.onAccent : Theme.text }
            // на вкладке серверов «+» — меню, как «Сервер» в NekoBox: новый сервер, ссылки, буфер, группа
            // on the servers tab "+" is a menu, like "Server" in NekoBox: a new server, links, clipboard, a group
            StateLayer { radius: 15; onClicked: (m) => {
                if (vp.page === "rule") vp.page = "rules";
                else if (vp.form) vp.page = "list";
                else if (vp.page === "rules") vp.startRule(null);
                else { const p = parent.mapToItem(null, parent.width / 2, parent.height); vp.addMenu(p.x, p.y); }
            } }
        }

        // ── вкладки: серверы · маршруты · настройки ──
        // ── tabs: servers · routes · settings ──
        Row {
            id: tabs
            visible: vp.page === "list" || vp.page === "rules" || vp.page === "opts"
            y: 46
            spacing: 4
            Repeater {
                model: [["list", L.t("Серверы")], ["rules", L.t("Маршруты")], ["opts", L.t("Настройки")]]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: vp.page === modelData[0]
                    width: tbt.implicitWidth + 24; height: 28; radius: 14
                    color: sel ? Theme.accent : Theme.surfaceHi
                    Text { id: tbt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                    StateLayer { radius: 14; onClicked: vp.page = modelData[0] }
                }
            }
        }

        // ── серверы, как в NekoBox: вкладки групп, таблица серверов, журнал ──
        // ── servers, as in NekoBox: group tabs, server table, log ──
        Item {
            id: srv
            visible: vp.page === "list"
            y: 82; width: parent.width; height: parent.height - 82 - bottom.height - 8 - (Vpn.draft.length ? 46 : 0)
            readonly property var group: Vpn.groups.find(g => g.id === vp.open) ?? Vpn.groups[0] ?? null

            // вкладки групп: клик — открыть, ПКМ — меню группы, «+» — новая группа
            // group tabs: click to open, right-click for the group menu, "+" for a new group
            ListView {
                id: gtabs
                width: parent.width; height: 30
                orientation: ListView.Horizontal
                spacing: 4; clip: true
                model: Vpn.groups.concat([{ id: "__add" }])
                delegate: Rectangle {
                    id: gt
                    required property var modelData
                    readonly property bool add: modelData.id === "__add"
                    readonly property bool sel: !add && srv.group && srv.group.id === modelData.id
                    width: add ? 30 : gtt.implicitWidth + 26; height: 30; radius: 15
                    color: sel ? Theme.accent : Theme.surface
                    Text { id: gtt; visible: !gt.add; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: gt.sel ? Theme.onAccent : Theme.text; text: gt.modelData.name ?? "" }
                    Icon { visible: gt.add; anchors.centerIn: parent; name: "plus"; size: 11; color: Theme.accent }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (m) => {
                            if (gt.add) { vp.editing = ""; vp.page = "add"; return; }
                            if (m.button === Qt.LeftButton) { vp.open = gt.modelData.id; vp.picked = []; vp.pickAnchor = -1; return; }
                            vp.groupMenu(gt, m, gt.modelData);
                        }
                    }
                }
            }
            // сведения о группе и инструменты
            // group info and tools
            Item {
                id: ginfo
                y: 36; width: parent.width; height: 30
                visible: !!srv.group
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; elide: Text.ElideRight
                       font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: vp.picked.length ? Theme.accent : Theme.textDim
                       text: vp.picked.length ? L.t("выбрано: ") + vp.picked.length + "  ·  " + L.t("ПКМ по выделенным — действия")
                           : srv.group ? vp.infoLine(srv.group) + (srv.group.updated ? "  ·  " + vp.fmtDate(srv.group.updated) : "") : "" }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: [["refresh", L.t("обновить"), () => Vpn.update(srv.group.id), srv.group?.type === "sub"],
                                ["bolt", L.t("пинг"), () => Vpn.ping(srv.group.id), true],
                                ["queue", L.t("порядок"), null, true]]
                        delegate: Rectangle {
                            id: tb
                            required property var modelData
                            visible: modelData[3]
                            width: 28; height: 28; radius: 14
                            color: (modelData[0] === "bolt" && Vpn.pingGroup === srv.group?.id) || (modelData[0] === "refresh" && Vpn.busyGroup === srv.group?.id)
                                   ? Theme.accent : Theme.surfaceHi
                            Icon { anchors.centerIn: parent; name: tb.modelData[0]; size: 11; color: parent.color === Theme.accent ? Theme.onAccent : Theme.accent }
                            MouseArea { anchors.fill: parent
                                onClicked: (m) => {
                                    if (tb.modelData[2]) { tb.modelData[2](); return; }
                                    const p = tb.mapToItem(null, m.x, m.y), g = srv.group;
                                    menu.items = [{ icon: "queue", text: L.t("как в подписке"), checked: !g.sort || g.sort === "none", action: () => Vpn.setSort(g.id, "none") },
                                                  { icon: "bolt", text: L.t("по пингу"), checked: g.sort === "ping", action: () => Vpn.setSort(g.id, "ping") },
                                                  { icon: "queue", text: L.t("по имени"), checked: g.sort === "name", action: () => Vpn.setSort(g.id, "name") }];
                                    menu.openAt(p.x, p.y, false);
                                } }
                        }
                    }
                }
            }
            // таблица: № · тип · адрес · имя · пинг
            // table: # · type · address · name · ping
            Rectangle {
                id: tbl
                y: 70; width: parent.width; height: parent.height - 70 - (vp.showLogs ? logBox.height + 6 : 0)
                radius: Tokens.rounding.large
                color: Theme.surface
                clip: true
                readonly property var cols: [0.07, 0.17, 0.30, 0.34, 0.12]
                function cx(i: int): real { let x = 10; for (let k = 0; k < i; k++) x += (width - 20) * cols[k]; return x; }
                function cw(i: int): real { return (width - 20) * cols[i] - 6; }
                Repeater {
                    model: ["#", L.t("тип"), L.t("адрес"), L.t("имя"), L.t("пинг")]
                    delegate: Text { required property string modelData; required property int index
                                     x: parent.cx(index); y: 8; width: parent.cw(index); elide: Text.ElideRight
                                     font.family: Theme.font; font.pixelSize: Tokens.font.small; font.bold: true; color: Theme.accent; text: modelData }
                }
                Rectangle { x: 8; y: 28; width: parent.width - 16; height: 1; color: Theme.line }
                ListView {
                    id: table
                    SmoothWheel {}
                    y: 32; width: parent.width; height: parent.height - 34
                    clip: true
                    model: srv.group ? Vpn.order(srv.group) : []
                    // пустое место под списком: ПКМ — меню добавления (как в NekoBox), двойной клик — новый сервер
                    // empty space below the list: right-click for the add menu (as in NekoBox), double-click for a new server
                    footer: MouseArea {
                        width: table.width; height: Math.max(40, table.height - table.contentHeight + 2)
                        acceptedButtons: Qt.RightButton | Qt.LeftButton
                        onClicked: (m) => { vp.picked = []; if (m.button === Qt.RightButton) { const p = mapToItem(null, m.x, m.y); vp.addMenu(p.x, p.y); } }
                        onDoubleClicked: vp.startNode(srv.group?.id ?? "", -1)
                    }
                    delegate: Rectangle {
                        id: row
                        required property int modelData
                        required property int index
                        readonly property var n: srv.group.nodes[modelData]
                        readonly property bool sel: Vpn.selGroup === srv.group.id && Vpn.selNode === modelData
                        readonly property bool picked: vp.picked.includes(modelData)
                        width: table.width; height: 34
                        color: picked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                             : sel ? Theme.tonalHi : rm.containsMouse ? Theme.surfaceHi : (index % 2 ? Qt.rgba(1, 1, 1, 0.02) : "transparent")
                        // полоска слева у выделенных / a stripe on the left of selected rows
                        Rectangle { visible: row.picked; x: 2; width: 3; height: parent.height - 10; anchors.verticalCenter: parent.verticalCenter
                                    radius: 1.5; color: Theme.accent }
                        // №, тип (таблеткой), адрес, имя (с флагом страны), пинг
                        // #, type (as a pill), address, name (with a country flag), ping
                        Text { x: tbl.cx(0); width: tbl.cw(0); anchors.verticalCenter: parent.verticalCenter
                               font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: row.index + 1 }
                        Rectangle {
                            x: tbl.cx(1); anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(tbl.cw(1), ptx.implicitWidth + 14); height: 20; radius: 10
                            color: row.n?.needsXray ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.22) : Theme.tonal
                            Text { id: ptx; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: 10; font.bold: true
                                   color: row.n?.needsXray ? Theme.accent2 : Theme.accent
                                   text: vp.protoLabel(row.n?.proto ?? "") + (row.n?.needsXray ? " · X" : "") }
                        }
                        Text { x: tbl.cx(2); width: tbl.cw(2); anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideMiddle
                               font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                               text: row.n?.proto === "chain" ? "—" : (row.n?.server ?? "") + ":" + (row.n?.port ?? "") }
                        Row {
                            x: tbl.cx(3); width: tbl.cw(3); anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text { id: flg; visible: text !== ""; font.pixelSize: 15; text: vp.flagOf(row.n?.name ?? "") }
                            Text { width: parent.width - (flg.visible ? flg.width + 6 : 0); elide: Text.ElideRight
                                   anchors.verticalCenter: parent.verticalCenter
                                   font.family: Theme.font; font.pixelSize: Tokens.font.small
                                   color: row.sel ? Theme.accent : Theme.text; text: vp.cleanName(row.n?.name ?? "") }
                        }
                        Text {
                            x: tbl.cx(4); anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.font; font.pixelSize: Tokens.font.small; font.bold: true
                            readonly property int p: row.n?.ping ?? 0
                            visible: row.n?.ping !== undefined
                            color: p < 0 ? Theme.danger : p < 250 ? "#9ece6a" : p < 600 ? "#e0af68" : Theme.danger
                            text: p < 0 ? "×" : p + " ms"
                        }
                        MouseArea {
                            id: rm; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (m) => {
                                const g = srv.group, i = row.modelData;
                                if (m.button === Qt.LeftButton) {
                                    if (vp.pickClick(row.index, i, m.modifiers)) return;
                                    vp.picked = []; vp.pickAnchor = row.index;
                                    Vpn.select(g.id, i); if (!Vpn.running) Vpn.connect(); return;
                                }
                                const p = row.mapToItem(null, m.x, m.y);
                                // ПКМ по выделенному при нескольких выделенных — меню для всех сразу
                                // right-click on a selected row with several selected: a menu for all of them at once
                                if (vp.picked.length > 1 && vp.picked.includes(i)) vp.bulkMenu(p.x, p.y, g);
                                else { vp.picked = []; vp.nodeMenu(p.x, p.y, g, i); }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !srv.group || srv.group.nodes.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
                        text: !srv.group ? L.t("групп пока нет — нажми «+»,\nчтобы добавить подписку или ссылки")
                                         : srv.group.type === "sub" ? L.t("в группе нет серверов — обнови подписку")
                                         : L.t("в группе нет серверов — «+» сверху или ПКМ здесь,\nчтобы добавить сервер или ссылки (Ctrl+V — из буфера)")
                    }
                }
            }
            // журнал ядра
            // core log
            Rectangle {
                id: logBox
                visible: vp.showLogs
                anchors.bottom: parent.bottom
                width: parent.width; height: 110
                radius: Tokens.rounding.large
                color: Theme.surface
                ListView {
                    anchors.fill: parent; anchors.margins: 8
                    clip: true
                    model: Vpn.logs
                    onModelChanged: Qt.callLater(positionViewAtEnd)
                    reuseItems: true
                    delegate: Text { required property string modelData; width: ListView.view.width; wrapMode: Text.WrapAnywhere
                                     font.family: Theme.font; font.pixelSize: 10; color: /ERROR|FATAL/.test(modelData) ? Theme.danger : Theme.textDim
                                     text: modelData }
                }
            }
        }

        // ── собираемая цепочка ──
        // ── the chain being assembled ──
        Rectangle {
            visible: vp.page === "list" && Vpn.draft.length > 0
            anchors.bottom: bottom.top; anchors.bottomMargin: 6
            width: parent.width; height: 40; radius: 20
            color: Theme.tonalHi
            Text { x: 14; width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideMiddle
                   font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.text
                   text: L.t("цепочка: ") + Vpn.draft.map(h => h.name).join(" → ") }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Rectangle { width: 30; height: 30; radius: 15; color: Theme.surfaceHi
                            Icon { anchors.centerIn: parent; name: "close"; size: 10; color: Theme.textDim }
                            StateLayer { radius: 15; onClicked: Vpn.clearDraft() } }
                Rectangle { width: ct.implicitWidth + 24; height: 30; radius: 15; color: Theme.accent
                            Text { id: ct; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                   font.bold: true; color: Theme.onAccent; text: L.t("создать") }
                            StateLayer { radius: 15; tint: Theme.onAccent; onClicked: Vpn.saveChain("") } }
            }
        }

        // ── низ: скорость, TUN, кнопка ──
        // ── bottom: speed, TUN, button ──
        Item {
            id: bottom
            visible: vp.page === "list" || vp.page === "rules" || vp.page === "opts"
            anchors.bottom: parent.bottom
            width: parent.width; height: 56
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: "▲ " + Vpn.human(Vpn.up) + "/s" }
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: "▼ " + Vpn.human(Vpn.down) + "/s" }
                Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.textDim; text: "127.0.0.1:" + Vpn.port }
            }
            // как в NekoBox: два независимых переключателя и журнал. Прокси на порту работает всегда
            // as in NekoBox: two independent switches and the log. The proxy on the port always works
            Row {
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: [["TUN", Vpn.tun, () => Vpn.setTun(!Vpn.tun)],
                            [L.t("системный прокси"), Vpn.sysProxy, () => Vpn.setSysProxy(!Vpn.sysProxy)],
                            [L.t("логи"), vp.showLogs, () => Vpn.setShowLogs(!Vpn.showLogs)]]
                    delegate: Rectangle {
                        required property var modelData
                        width: ck.implicitWidth + 40; height: 28; radius: 14
                        color: modelData[1] ? Theme.tonalHi : Theme.surfaceHi
                        Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 4
                                    color: parent.modelData[1] ? Theme.accent : "transparent"; border.color: Theme.accent
                                    Icon { visible: parent.parent.modelData[1]; anchors.centerIn: parent; name: "check"; size: 8; color: Theme.onAccent } }
                        Text { id: ck; x: 30; anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font
                               font.pixelSize: Tokens.font.small; color: Theme.text; text: modelData[0] }
                        MouseArea { anchors.fill: parent; onClicked: parent.modelData[2]() }
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 52; height: 52; radius: Vpn.running ? 18 : 26
                color: Vpn.running ? Theme.accent : Theme.surfaceHi
                Behavior on radius { Anim { kind: "fastSpatial" } }
                Behavior on color { CAnim {} }
                // самолётик из Exclave: сплошной — подключено, с прорезями — нет, пульсирует — подключаемся
                // the Exclave paper plane: solid when connected, with cut-outs when not, pulsing while connecting
                PlaneIcon { anchors.centerIn: parent; size: 24; on: Vpn.running; busy: Vpn.wanted && !Vpn.running
                            color: Vpn.running ? Theme.onAccent : Theme.accent
                            Behavior on color { CAnim {} } }
                StateLayer { radius: parent.radius; onClicked: Vpn.toggle() }
            }
        }

        // ── маршруты: сверху вниз, срабатывает первое подходящее ──
        // ── routes: top to bottom, the first match wins ──
        ListView {
            visible: vp.page === "rules"
            SmoothWheel {}
            y: 82; width: parent.width; height: parent.height - 82 - bottom.height - 8
            clip: true; spacing: 6
            model: Vpn.rules
            delegate: Rectangle {
                id: rc
                required property var modelData
                required property int index
                width: ListView.view.width; height: 58; radius: Tokens.rounding.large
                color: Theme.surface
                opacity: modelData.on ? 1 : 0.55
                readonly property string summary: {
                    const r = modelData, sp = (t) => (t || "").split(/[\n,]+/).map(x => x.trim()).filter(x => x);
                    const d = sp(r.domains), i = sp(r.ips), p = sp(r.processes), parts = [];
                    if (d.length) parts.push(d.length === 1 ? d[0] : d[0] + " +" + (d.length - 1));
                    if (i.length) parts.push(i.length + L.t(" адр."));
                    if (p.length) parts.push(p.length + L.t(" прил."));
                    return parts.join("  ·  ") || L.t("пусто");
                }
                Column {
                    x: 14; y: 9; width: parent.width - 170; spacing: 3
                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; font.bold: true
                           color: Theme.text; text: rc.modelData.name || (L.t("Правило ") + (rc.index + 1)) }
                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Tokens.font.small
                           color: Theme.textDim; text: rc.summary }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => {
                        if (m.button === Qt.LeftButton) { vp.startRule(rc.modelData); return; }
                        const p = rc.mapToItem(null, m.x, m.y), r = rc.modelData;
                        menu.items = [{ icon: "settings", text: L.t("изменить"), action: () => vp.startRule(r) },
                                      { icon: "chevron_left", text: L.t("выше"), enabled: rc.index > 0, action: () => Vpn.moveRule(r.id, -1) },
                                      { icon: "chevron_right", text: L.t("ниже"), enabled: rc.index < Vpn.rules.length - 1, action: () => Vpn.moveRule(r.id, 1) },
                                      { separator: true },
                                      { icon: "bin", text: L.t("удалить"), danger: true, action: () => Vpn.removeRule(r.id) }];
                        menu.openAt(p.x, p.y, false);
                    }
                }
                // куда: обход / прокси / блок (клик — следующее)
                // where to: bypass / proxy / block (click for the next)
                Rectangle {
                    anchors.right: sw.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    readonly property var look: ({ direct: [L.t("обход"), Theme.surfaceHi, Theme.text], proxy: [L.t("прокси"), Theme.accent, Theme.onAccent],
                                                   block: [L.t("блок"), Theme.danger, Theme.frame] })[rc.modelData.outbound || "direct"]
                    width: ot.implicitWidth + 20; height: 26; radius: 13; color: look[1]
                    Text { id: ot; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: parent.look[2]; text: parent.look[0] }
                    MouseArea { anchors.fill: parent; onClicked: {
                        const order = ["direct", "proxy", "block"];
                        Vpn.setRule(rc.modelData.id, { outbound: order[(order.indexOf(rc.modelData.outbound || "direct") + 1) % 3] });
                    } }
                }
                // вкл/выкл
                // on/off
                Rectangle {
                    id: sw
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 24; radius: 12
                    color: rc.modelData.on ? Theme.accent : Theme.surfaceHi
                    Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                x: rc.modelData.on ? parent.width - width - 4 : 4
                                color: rc.modelData.on ? Theme.onAccent : Theme.textDim
                                Behavior on x { Anim { kind: "fastSpatial" } } }
                    MouseArea { anchors.fill: parent; onClicked: Vpn.setRule(rc.modelData.id, { on: !rc.modelData.on }) }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: Vpn.rules.length === 0
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.textDim
                text: L.t("маршрутов нет — всё идёт по режиму из настроек.\n«+» — добавить: сайты, адреса или приложения")
            }
        }

        // ── форма маршрута ──
        // ── route form ──
        Flickable {
            visible: vp.page === "rule"
            y: 48; width: parent.width; height: parent.height - 48
            contentHeight: rform.implicitHeight
            clip: true
            SmoothWheel {}
            Column {
                id: rform
                width: parent.width
                spacing: 8
                Field { id: rName; width: rform.width; hint: L.t("название (необязательно)") }
                Text { width: rform.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: L.t("сайты: example.com (с поддоменами), full:точный.домен, keyword:слово, geosite:category-ru") }
                Field { id: rDomains; width: rform.width; multi: true; hint: "claude.ai\ngeosite:youtube" }
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: L.t("адреса: 1.2.3.4, 10.0.0.0/8, geoip:ru") }
                Field { id: rIps; width: rform.width; multi: true; height: 64; hint: "geoip:ru" }
                Text { width: rform.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: L.t("приложения: имя процесса (Telegram, steam) или путь (/usr/bin/firefox). Tab — принять подсказку") }
                Field { id: rProcs; width: rform.width; multi: true; height: 64; hint: "Telegram\nsteamwebhelper"; suggest: vp.procNames }
                // подставить приложение из открытых окон (имя процесса берётся само)
                // fill in an app from the open windows (the process name is picked up automatically)
                Rectangle {
                    width: pk.implicitWidth + 28; height: 28; radius: 14; color: Theme.surfaceHi
                    Text { id: pk; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent
                           text: L.t("выбрать из открытых окон…") }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: (m) => {
                            vp.pickAt = parent.mapToItem(null, m.x, m.y);
                            const pids = ShellState.mangoClients.map(c => c.pid).filter(p => p > 0);
                            // у окна берём имя исполняемого файла и имена его дочерних процессов (у Electron-программ
                            // сетью часто занимается дочерний: у DeltaChat — deltachat-rpc-server)
                            // from the window we take the executable's name and its child processes' names (in Electron apps
                            // a child often does the networking: deltachat-rpc-server for DeltaChat)
                            procProc.command = ["sh", "-c", 'kids() { for c in $(pgrep -P "$1"); do echo "$c"; kids "$c"; done; }; ' +
                                'for p in "$@"; do echo "$p"; kids "$p"; done | while read -r q; do readlink "/proc/$q/exe" 2>/dev/null; done | sed "s|.*/||; s| (deleted)||" | sort -u', "sh"].concat(pids.map(String));
                            procProc.running = true;
                        }
                    }
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: [["direct", L.t("обход")], ["proxy", L.t("прокси")], ["block", L.t("блок")]]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: vp.ruleOut === modelData[0]
                            width: rt.implicitWidth + 26; height: 30; radius: 15
                            color: sel ? (modelData[0] === "block" ? Theme.danger : Theme.accent) : Theme.surfaceHi
                            Text { id: rt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                   color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                            StateLayer { radius: 15; onClicked: vp.ruleOut = modelData[0] }
                        }
                    }
                }
                Rectangle {
                    width: rs.implicitWidth + 40; height: 36; radius: 18; color: Theme.accent
                    Text { id: rs; anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: Tokens.font.smaller
                           color: Theme.onAccent; text: vp.ruleEditing ? L.t("сохранить") : L.t("добавить") }
                    StateLayer { radius: 18; tint: Theme.onAccent; onClicked: vp.submitRule() }
                }
            }
        }

        // ── настройки ядра ──
        // ── core settings ──
        Flickable {
            visible: vp.page === "opts"
            SmoothWheel {}
            y: 82; width: parent.width; height: parent.height - 82 - bottom.height - 8
            contentHeight: ocol.implicitHeight
            clip: true
            Column {
                id: ocol
                width: parent.width
                spacing: 6
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: L.t("режим маршрутов") }
                Chips { opts: [["rule", L.t("правила")], ["global", L.t("всё через прокси")], ["direct", L.t("всё напрямую")]]
                        current: Vpn.opts.mode; onPick: (v) => Vpn.setOpt("mode", v) }
                Text { topPadding: 6; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: "DNS" }
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: L.t("удалённый (через прокси), Enter — применить") }
                Field { id: oRemote; width: ocol.width; text: Vpn.opts.remoteDns; hint: "tcp://1.1.1.1"; onEnter: Vpn.setOpt("remoteDns", oRemote.text.trim() || "tcp://1.1.1.1") }
                Text { font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim; text: L.t("прямой (для «обхода»): local — системный") }
                Field { id: oDirect; width: ocol.width; text: Vpn.opts.directDns; hint: "local"; onEnter: Vpn.setOpt("directDns", oDirect.text.trim() || "local") }
                Chips { opts: [["prefer_ipv4", L.t("сначала IPv4")], ["prefer_ipv6", L.t("сначала IPv6")], ["ipv4_only", L.t("только IPv4")]]
                        current: Vpn.opts.strategy; onPick: (v) => Vpn.setOpt("strategy", v) }
                Toggle2 { title: "FakeDNS"; hint: L.t("быстрее в режиме TUN; после отключения VPN приложения иногда надо перезапустить")
                          on: Vpn.opts.fakeDns; onFlip: Vpn.setOpt("fakeDns", !Vpn.opts.fakeDns) }
                Text { topPadding: 6; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: L.t("маршрут") }
                Toggle2 { title: L.t("обход LAN"); hint: L.t("локальная сеть и роутер — мимо VPN"); on: Vpn.opts.bypassLan; onFlip: Vpn.setOpt("bypassLan", !Vpn.opts.bypassLan) }
                Toggle2 { title: L.t("маршрут IPv6"); hint: L.t("пускать IPv6 через TUN"); on: Vpn.opts.ipv6; onFlip: Vpn.setOpt("ipv6", !Vpn.opts.ipv6) }
                Toggle2 { title: L.t("фрагментация TLS Client Hello"); hint: L.t("может помочь обойти блокировку по SNI (экспериментально)")
                          on: Vpn.opts.fragment; onFlip: Vpn.setOpt("fragment", !Vpn.opts.fragment) }
                Text { topPadding: 6; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: L.t("журнал") }
                Text { width: ocol.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: L.t("сколько писать во вкладку «логи»: «всё» — каждое соединение и запрос DNS (для поиска проблем; ядро чуть медленнее)") }
                Chips { opts: [["error", L.t("ошибки")], ["warn", L.t("предупреждения")], ["info", L.t("события")], ["debug", L.t("подробно")], ["trace", L.t("всё")]]
                        current: Vpn.opts.logLevel ?? "warn"; onPick: (v) => Vpn.setOpt("logLevel", v) }
                Text { topPadding: 6; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.accent; text: L.t("стек TUN") }
                Chips { opts: [["mixed", "mixed"], ["system", "system"], ["gvisor", "gVisor"]]
                        current: Vpn.opts.stack; onPick: (v) => Vpn.setOpt("stack", v) }
                Row {
                    spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: "MTU" }
                    Field { id: oMtu; width: 90; text: String(Vpn.opts.mtu); onEnter: Vpn.setOpt("mtu", parseInt(oMtu.text) || 9000) }
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller; color: Theme.text; text: L.t("порт прокси") }
                    Field { id: oPort; width: 90; text: String(Vpn.port); onEnter: Vpn.setPort(parseInt(oPort.text) || 2080) }
                }
                Toggle2 { title: L.t("восстанавливать после перезагрузки"); hint: L.t("был включён при выключении — включится снова при входе"); on: Vpn.autoConnect; onFlip: Vpn.setAuto(!Vpn.autoConnect) }
            }
        }

        // ── добавить ссылки в группу: вставить текстом или из буфера (одна или много, base64-подписка, JSON, Clash) ──
        // ── add links to a group: paste as text or from the clipboard (one or many, a base64 subscription, JSON, Clash) ──
        Flickable {
            visible: vp.page === "links"
            y: 48; width: parent.width; height: parent.height - 48
            contentHeight: lform.implicitHeight
            clip: true
            SmoothWheel {}
            Column {
                id: lform
                width: parent.width
                spacing: 8
                Label2 { text: L.t("в группу") }
                GroupPick { id: lTarget }
                Label2 { text: L.t("ссылки") }
                Field { id: lLinks; width: lform.width; multi: true; height: 200
                        hint: L.t("ссылки vless:// vmess:// trojan:// ss:// hy2:// tuic:// socks:// — по одной в строке") }
                Text { visible: !!vp.linksErr; font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.danger; text: vp.linksErr }
                Row {
                    spacing: 8
                    Rectangle {
                        width: la.implicitWidth + 40; height: 36; radius: 18; color: Theme.accent
                        Text { id: la; anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: Tokens.font.smaller
                               color: Theme.onAccent; text: L.t("добавить") }
                        StateLayer { radius: 18; tint: Theme.onAccent; onClicked: vp.submitLinks() }
                    }
                    Rectangle {
                        width: lp.implicitWidth + 32; height: 36; radius: 18; color: Theme.surfaceHi
                        Text { id: lp; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                               color: Theme.text; text: L.t("вставить из буфера") }
                        StateLayer { radius: 18; onClicked: { vp.clipFor = "field"; clipProc.running = true; } }
                    }
                }
            }
        }

        // ── сервер вручную, как «Новый профиль» в NekoBox: протокол, адрес, ключи, транспорт, шифрование ──
        // ── a server by hand, like "New profile" in NekoBox: protocol, address, keys, transport, encryption ──
        Flickable {
            id: nflick
            visible: vp.page === "node"
            y: 48; width: parent.width; height: parent.height - 48
            contentHeight: nform.implicitHeight + 8
            clip: true
            SmoothWheel {}
            Column {
                id: nform
                width: parent.width - 8
                spacing: 8
                readonly property string pr: vp.nf.proto
                readonly property bool hasTls: ["vless", "vmess", "trojan", "http"].includes(pr)
                readonly property bool hasNet: ["vless", "vmess", "trojan"].includes(pr)
                readonly property bool tlsOn: hasTls && vp.nf.security !== "none"
                readonly property bool quic: pr === "hysteria2" || pr === "tuic"

                Label2 { visible: vp.nodeIdx < 0; text: L.t("в группу") }
                GroupPick { id: nTarget; visible: vp.nodeIdx < 0 }

                Label2 { text: L.t("протокол") }
                Chips { opts: [["vless", "VLESS"], ["vmess", "VMess"], ["trojan", "Trojan"], ["ss", "Shadowsocks"], ["hysteria2", "Hysteria2"],
                               ["tuic", "TUIC"], ["socks", "SOCKS5"], ["http", "HTTP"]]
                        current: vp.nf.proto; onPick: (v) => vp.setF("proto", v) }

                Label2 { text: L.t("сервер") }
                Field { id: nName; width: nform.width; hint: L.t("название (необязательно)") }
                Row {
                    spacing: 8
                    Field { id: nServer; width: nform.width - 108; hint: L.t("адрес: example.com или 1.2.3.4") }
                    Field { id: nPort; width: 100; hint: L.t("порт") }
                }
                Field { id: nUuid; width: nform.width; visible: ["vless", "vmess", "tuic"].includes(nform.pr); hint: "UUID" }
                Row {
                    spacing: 8
                    visible: nform.pr === "socks" || nform.pr === "http"
                    Field { id: nUser; width: (nform.width - 8) / 2; hint: L.t("логин (необязательно)") }
                    Field { id: nPass2; width: (nform.width - 8) / 2; hint: L.t("пароль (необязательно)") }
                }
                Field { id: nPass; width: nform.width; visible: ["trojan", "ss", "hysteria2", "tuic"].includes(nform.pr); hint: L.t("пароль") }
                Chips { visible: nform.pr === "ss"; current: vp.nf.method; onPick: (v) => vp.setF("method", v)
                        opts: ["2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm", "2022-blake3-chacha20-poly1305", "aes-128-gcm", "aes-256-gcm",
                               "chacha20-ietf-poly1305"].map(x => [x, x]) }
                Chips { visible: nform.pr === "vless"; current: vp.nf.flow; onPick: (v) => vp.setF("flow", v)
                        opts: [["", L.t("без flow")], ["xtls-rprx-vision", "xtls-rprx-vision"]] }
                Chips { visible: nform.pr === "vmess"; current: vp.nf.vmessSec; onPick: (v) => vp.setF("vmessSec", v)
                        opts: ["auto", "aes-128-gcm", "chacha20-poly1305", "none", "zero"].map(x => [x, x]) }
                Chips { visible: nform.pr === "tuic"; current: vp.nf.cc; onPick: (v) => vp.setF("cc", v)
                        opts: [["bbr", "BBR"], ["cubic", "CUBIC"], ["new_reno", "NewReno"]] }
                Field { id: nObfs; width: nform.width; visible: nform.pr === "hysteria2"; hint: L.t("пароль obfs salamander (если есть)") }

                // транспорт / transport
                Label2 { visible: nform.hasNet; text: L.t("транспорт") }
                Chips { visible: nform.hasNet; current: vp.nf.net; onPick: (v) => vp.setF("net", v)
                        // XHTTP через Xray собираем только для VLESS и Trojan / XHTTP via Xray is only built for VLESS and Trojan
                        opts: [["tcp", "TCP"], ["ws", "WebSocket"], ["grpc", "gRPC"], ["http", "HTTP/2"], ["httpupgrade", "HTTPUpgrade"]]
                              .concat(nform.pr === "vmess" ? [] : [["xhttp", "XHTTP"]]) }
                Row {
                    spacing: 8
                    visible: nform.hasNet && vp.nf.net !== "tcp"
                    Field { id: nPath; width: vp.nf.net === "grpc" ? nform.width : (nform.width - 8) / 2
                            hint: vp.nf.net === "grpc" ? "serviceName" : L.t("путь, например /ws") }
                    Field { id: nHost; visible: vp.nf.net !== "grpc"; width: (nform.width - 8) / 2; hint: L.t("host (необязательно)") }
                }
                Text { visible: nform.hasNet && vp.nf.net === "xhttp"; width: nform.width; wrapMode: Text.Wrap
                       font.family: Theme.font; font.pixelSize: Tokens.font.small; color: Theme.textDim
                       text: L.t("XHTTP умеет только Xray — такой сервер пойдёт через него") }

                // шифрование / encryption
                Label2 { visible: nform.hasTls || nform.quic; text: L.t("шифрование") }
                Chips { visible: nform.hasTls; current: vp.nf.security; onPick: (v) => vp.setF("security", v)
                        opts: [["none", L.t("нет")], ["tls", "TLS"]].concat(nform.pr === "vless" ? [["reality", "REALITY"]] : []) }
                Row {
                    spacing: 8
                    visible: nform.tlsOn || nform.quic
                    Field { id: nSni; width: nform.pr === "http" ? nform.width : (nform.width - 8) / 2; hint: L.t("SNI (по умолчанию — адрес)") }
                    Field { id: nAlpn; visible: nform.pr !== "http"; width: (nform.width - 8) / 2; hint: L.t("ALPN, например h2,http/1.1") }
                }
                Chips { visible: nform.tlsOn && nform.pr !== "http"; current: vp.nf.fp; onPick: (v) => vp.setF("fp", v)
                        opts: [["chrome", "Chrome"], ["firefox", "Firefox"], ["safari", "Safari"], ["edge", "Edge"], ["randomized", L.t("случайный")], ["", L.t("без отпечатка")]] }
                Row {
                    spacing: 8
                    visible: nform.pr === "vless" && vp.nf.security === "reality"
                    Field { id: nPbk; width: (nform.width - 8) / 2; hint: L.t("публичный ключ (pbk)") }
                    Field { id: nSid; width: (nform.width - 8) / 2; hint: "short id (sid)" }
                }
                Toggle2 { visible: (nform.tlsOn && vp.nf.security === "tls" && nform.pr !== "http") || nform.quic; width: nform.width
                          title: L.t("не проверять сертификат"); hint: L.t("только для своих серверов с самоподписанным сертификатом")
                          on: vp.nf.insecure; onFlip: vp.setF("insecure", !vp.nf.insecure) }

                Text { visible: !!vp.nodeErr; width: nform.width; wrapMode: Text.Wrap; font.family: Theme.font; font.pixelSize: Tokens.font.small
                       color: Theme.danger; text: vp.nodeErr }
                Row {
                    spacing: 8
                    Rectangle {
                        width: ns.implicitWidth + 40; height: 36; radius: 18; color: Theme.accent
                        Text { id: ns; anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: Tokens.font.smaller
                               color: Theme.onAccent; text: vp.nodeIdx >= 0 ? L.t("сохранить") : L.t("добавить") }
                        StateLayer { radius: 18; tint: Theme.onAccent; onClicked: vp.submitNode(false) }
                    }
                    // как «Скопировать ссылку» в редакторе NekoBox: собрать ссылку, не сохраняя
                    // like "Copy link" in the NekoBox editor: build the link without saving
                    Rectangle {
                        width: nc.implicitWidth + 32; height: 36; radius: 18; color: Theme.surfaceHi
                        Text { id: nc; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                               color: Theme.text; text: L.t("скопировать ссылку") }
                        StateLayer { radius: 18; onClicked: vp.submitNode(true) }
                    }
                }
            }
        }

        // ── добавить / изменить группу ──
        // ── add / edit a group ──
        Flickable {
            visible: vp.page === "add"
            y: 48; width: parent.width; height: parent.height - 48
            contentHeight: form.implicitHeight
            clip: true
            SmoothWheel {}
            Column {
                id: form
                width: parent.width
                spacing: 8
                Row {
                    visible: !vp.editing
                    spacing: 4
                    Repeater {
                        model: [["sub", L.t("подписка")], ["manual", L.t("ссылки")]]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: vp.addKind === modelData[0]
                            width: kt.implicitWidth + 26; height: 30; radius: 15
                            color: sel ? Theme.accent : Theme.surfaceHi
                            Text { id: kt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Tokens.font.small
                                   color: parent.sel ? Theme.onAccent : Theme.text; text: modelData[1] }
                            StateLayer { radius: 15; onClicked: vp.addKind = modelData[0] }
                        }
                    }
                }
                Field { id: fName; width: form.width; hint: L.t("название (необязательно — возьмётся из подписки)") }
                Field { id: fUrl; width: form.width; visible: vp.editing ? vp.editKind === "sub" : vp.addKind === "sub"; hint: "https://…  " + L.t("ссылка на подписку") }
                Field { id: fUa; width: form.width; visible: fUrl.visible; hint: "User-Agent (" + L.t("например") + " Happ/3.25.1)" }
                Field { id: fHeaders; width: form.width; visible: fUrl.visible; multi: true
                        hint: L.t("свои заголовки, по одному в строке:\nX-Hwid: …\nX-Device-Os: …") }
                Row {
                    visible: fUrl.visible
                    spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.font; font.pixelSize: Tokens.font.smaller
                           color: Theme.text; text: L.t("автообновление, ч:") }
                    Field { id: fInt; width: 70; text: "12" }
                }
                Field { id: fLinks; width: form.width; visible: !vp.editing && vp.addKind === "manual"; multi: true; height: 160
                        hint: L.t("ссылки vless:// vmess:// trojan:// ss:// hy2:// tuic:// — по одной в строке") }
                Rectangle {
                    width: st.implicitWidth + 40; height: 36; radius: 18; color: Theme.accent
                    Text { id: st; anchors.centerIn: parent; font.family: Theme.font; font.bold: true; font.pixelSize: Tokens.font.smaller
                           color: Theme.onAccent; text: vp.editing ? L.t("сохранить") : L.t("добавить") }
                    StateLayer { radius: 18; tint: Theme.onAccent; onClicked: vp.submit() }
                }
            }
        }
    }

    function startRule(r): void {
        ruleEditing = r ? r.id : ""; ruleOut = r ? (r.outbound || "direct") : "direct";
        rName.text = r?.name ?? ""; rDomains.text = r?.domains ?? ""; rIps.text = r?.ips ?? ""; rProcs.text = r?.processes ?? "";
        page = "rule";
    }
    function submitRule(): void {
        const r = { name: rName.text.trim(), domains: rDomains.text, ips: rIps.text, processes: rProcs.text, outbound: ruleOut };
        if (ruleEditing) Vpn.setRule(ruleEditing, r); else Vpn.addRule(r);
        page = "rules";
    }
    property var pickAt: ({ x: 0, y: 0 })
    property var procNames: []
    Process {
        id: namesProc
        command: ["sh", "-c", 'for p in /proc/[0-9]*; do readlink "$p/exe" 2>/dev/null; done | sed "s|.*/||; s| (deleted)||" | sort -u']
        stdout: StdioCollector { onStreamFinished: vp.procNames = text.split("\n").filter(l => l && !/^(sh|bash|fish|sleep|cat|ps|sed|sort|readlink)$/.test(l)) }
    }
    onPageChanged: if (page === "rule") namesProc.running = true
    Process {
        id: procProc
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(l => l);
                menu.items = names.length ? names.map(n => ({ icon: "apps", text: n, action: () => {
                        const cur = rProcs.text.trim(); rProcs.text = cur ? cur + "\n" + n : n; } }))
                    : [{ icon: "close", text: L.t("открытых окон нет"), enabled: false }];
                menu.openAt(vp.pickAt.x, vp.pickAt.y, false);
            }
        }
    }
    // флаг страны: из эмодзи в названии сервера, иначе по названию/коду страны
    // country flag: from an emoji in the server name, otherwise from the country name/code
    readonly property var countries: ({
        "герман": "DE", "germany": "DE", "нидерл": "NL", "netherl": "NL", "голланд": "NL", "финлянд": "FI", "finland": "FI",
        "швец": "SE", "sweden": "SE", "франц": "FR", "france": "FR", "польш": "PL", "poland": "PL", "латв": "LV", "latvia": "LV",
        "эстон": "EE", "estonia": "EE", "литв": "LT", "lithuan": "LT", "казах": "KZ", "kazakh": "KZ", "турц": "TR", "turkey": "TR",
        "сша": "US", "usa": "US", "united states": "US", "америк": "US", "великобр": "GB", "англи": "GB", "united kingdom": "GB", "uk ": "GB",
        "япон": "JP", "japan": "JP", "сингап": "SG", "singapore": "SG", "швейц": "CH", "switz": "CH", "австри": "AT", "austria": "AT",
        "россия": "RU", "russia": "RU", "москв": "RU", "канад": "CA", "canada": "CA", "гонконг": "HK", "hong kong": "HK", "оаэ": "AE", "uae": "AE",
        "испан": "ES", "spain": "ES", "итал": "IT", "italy": "IT", "норвег": "NO", "norway": "NO", "чехи": "CZ", "czech": "CZ",
        "венгр": "HU", "hungary": "HU", "румын": "RO", "romania": "RO", "болгар": "BG", "bulgaria": "BG", "грузи": "GE", "georgia": "GE",
        "армен": "AM", "armenia": "AM", "молдов": "MD", "moldova": "MD", "сербия": "RS", "serbia": "RS", "индия": "IN", "india": "IN"
    })
    function flagOf(name: string): string {
        const m = String(name).match(/[\u{1F1E6}-\u{1F1FF}]{2}/u);
        if (m) return m[0];
        const low = " " + String(name).toLowerCase() + " ";
        let cc = "";
        for (const k in countries) if (low.includes(k)) { cc = countries[k]; break; }
        if (!cc) { const c2 = String(name).match(/\b([A-Z]{2})\b/); if (c2 && Object.values(countries).includes(c2[1])) cc = c2[1]; }
        if (!cc) return "";
        return String.fromCodePoint(0x1F1E6 + cc.charCodeAt(0) - 65, 0x1F1E6 + cc.charCodeAt(1) - 65);
    }
    // название без флага — флаг рисуется отдельно
    // name without the flag: the flag is drawn separately
    function cleanName(name: string): string { return String(name).replace(/[\u{1F1E6}-\u{1F1FF}]{2}\s*/gu, "").trim(); }
    // метка протокола: короткое имя и цвет семьи
    // protocol label: a short name and the family colour
    function protoLabel(p: string): string {
        const base = String(p).split("/")[0];
        return ({ vless: "VLESS", vmess: "VMess", trojan: "Trojan", shadowsocks: "SS", ss: "SS", hysteria2: "Hy2", hysteria: "Hy1", tuic: "TUIC", chain: "⛓", socks: "SOCKS", http: "HTTP" })[base] ?? base.toUpperCase();
    }
    function groupMenu(item, m, g): void {
        const p = item.mapToItem(null, m.x, m.y);
        menu.items = (g.type === "sub" ? [{ icon: "refresh", text: L.t("обновить"), action: () => Vpn.update(g.id) }]
                                       : [{ icon: "plus", text: L.t("новый сервер…"), action: () => { vp.open = g.id; vp.startNode(g.id, -1); } },
                                          { icon: "copy", text: L.t("добавить ссылки…"), action: () => { vp.open = g.id; vp.startLinks("", g.id); } }])
            .concat([{ icon: "bolt", text: L.t("проверить пинг"), action: () => { vp.open = g.id; Vpn.ping(g.id); } },
                     { icon: "copy", text: L.t("скопировать все ссылки"), enabled: g.nodes.some(n => n.uri),
                       action: () => Quickshell.execDetached(["wl-copy", g.nodes.filter(n => n.uri).map(n => n.uri).join("\n")]) },
                     { icon: "settings", text: L.t("изменить"), action: () => vp.startEdit(g) },
                     { separator: true }],
                    g.type === "manual" ? [{ icon: "magic", text: L.t("убрать дубликаты"), action: () => Vpn.cleanGroup(g.id, false) },
                                           { icon: "close", text: L.t("убрать недоступные"), enabled: g.nodes.some(n => n.ping < 0), action: () => Vpn.cleanGroup(g.id, true) },
                                           { separator: true }] : [],
                    [{ icon: "bin", text: L.t("удалить группу"), danger: true, action: () => Vpn.removeGroup(g.id) }]);
        menu.openAt(p.x, p.y, false);
    }
    property string editKind: "sub"
    function startEdit(g): void {
        editing = g.id; editKind = g.type; page = "add";
        fName.text = g.name || ""; fUrl.text = g.url || ""; fUa.text = g.ua || ""; fHeaders.text = g.headers || ""; fInt.text = String(g.interval || 12);
    }
    function submit(): void {
        const h = parseInt(fInt.text) || 12;
        if (editing) {
            Vpn.editGroup(editing, editKind === "sub"
                ? { name: fName.text.trim(), url: fUrl.text.trim(), ua: fUa.text.trim(), headers: fHeaders.text, interval: h }
                : { name: fName.text.trim() });
            if (editKind === "sub") Vpn.update(editing);
        } else if (addKind === "sub") {
            if (!fUrl.text.trim()) return;
            Vpn.addSubscription(fName.text.trim(), fUrl.text, fUa.text.trim(), fHeaders.text, h);
        } else {
            if (!fLinks.text.trim()) return;
            Vpn.addManual(fName.text.trim(), fLinks.text);
        }
        fName.text = ""; fUrl.text = ""; fUa.text = ""; fHeaders.text = ""; fLinks.text = ""; fInt.text = "12";
        editing = ""; page = "list";
    }

    // ─── добавление серверов (как в NekoBox) ───
    // ─── adding servers (as in NekoBox) ───
    function addMenu(x: real, y: real): void {
        const gid = srv.group?.id ?? "";
        menu.items = [
            { icon: "plus", text: L.t("новый сервер…"), action: () => vp.startNode(gid, -1) },
            { icon: "copy", text: L.t("добавить ссылки…"), action: () => vp.startLinks("", gid) },
            { icon: "clipboard", text: L.t("из буфера обмена (Ctrl+V)"), action: () => vp.pasteImport() },
            { separator: true },
            { icon: "queue", text: L.t("новая группа или подписка…"), action: () => { vp.editing = ""; vp.page = "add"; } }
        ];
        menu.openAt(x, y, false);
    }
    // меню сервера: подключиться, цепочка, изменить, клонировать, в другую группу, ссылка, удалить
    // server menu: connect, chain, edit, clone, to another group, link, delete
    function nodeMenu(x: real, y: real, g, i: int): void {
        const n = g.nodes[i], own = g.type === "manual";
        const others = Vpn.manualGroups.filter(o => o.id !== g.id);
        // куда скопировать/перенести — вторым меню на том же месте / where to copy/move: a second menu in the same spot
        const pickGroup = (move) => {
            menu.items = others.map(o => ({ icon: "queue", text: o.name, action: () => Vpn.copyNode(g.id, i, o.id, "", move) }))
                .concat(others.length ? [{ separator: true }] : [],
                        [{ icon: "plus", text: L.t("в новую группу"), action: () => Vpn.copyNode(g.id, i, "", "", move) }]);
            menu.openAt(x, y, false);
        };
        menu.items = [
            { icon: "key", text: L.t("подключиться"), action: () => { Vpn.select(g.id, i); if (!Vpn.running) Vpn.connect(); } },
            { icon: "plus", text: L.t("добавить в цепочку"), enabled: !n?.needsXray && n?.proto !== "chain", action: () => Vpn.addHop(g.id, i) },
            { separator: true }
        ].concat(own ? [
            { icon: "edit", text: L.t("изменить…"), enabled: vp.editable(n), action: () => vp.startNode(g.id, i) },
            { icon: "copy", text: L.t("клонировать"), action: () => Vpn.cloneNode(g.id, i) },
            { icon: "arrow_right", text: L.t("перенести в группу…"), action: () => pickGroup(true) }
        ] : [
            // из подписки — копией в свою группу, там её уже можно менять
            // from a subscription: as a copy into your group, where it can be changed
            { icon: "copy", text: L.t("скопировать в свою группу…"), action: () => pickGroup(false) }
        ], [
            { icon: "copy", text: L.t("скопировать ссылку"), enabled: !!n?.uri, action: () => Quickshell.execDetached(["wl-copy", n.uri]) }
        ], own ? [{ separator: true }, { icon: "bin", text: L.t("удалить"), danger: true, action: () => Vpn.removeNode(g.id, i, false) }] : []);
        menu.openAt(x, y, false);
    }
    // меню для нескольких выделенных серверов / a menu for several selected servers
    function bulkMenu(x: real, y: real, g): void {
        const list = picked.slice(), own = g.type === "manual", n = list.length;
        const others = Vpn.manualGroups.filter(o => o.id !== g.id);
        const done = () => { vp.picked = []; vp.pickAnchor = -1; };
        const pickGroup = (move) => {
            menu.items = others.map(o => ({ icon: "queue", text: o.name, action: () => { Vpn.copyNode(g.id, list, o.id, "", move); done(); } }))
                .concat(others.length ? [{ separator: true }] : [],
                        [{ icon: "plus", text: L.t("в новую группу"), action: () => { Vpn.copyNode(g.id, list, "", "", move); done(); } }]);
            menu.openAt(x, y, false);
        };
        const links = list.map(i => g.nodes[i]?.uri).filter(u => u);
        menu.items = [
            { icon: "copy", text: L.t("скопировать ссылки") + " (" + links.length + ")", enabled: links.length > 0,
              action: () => Quickshell.execDetached(["wl-copy", links.join("\n")]) },
            own ? { icon: "arrow_right", text: L.t("перенести в группу…"), action: () => pickGroup(true) }
                : { icon: "copy", text: L.t("скопировать в свою группу…"), action: () => pickGroup(false) }
        ].concat(own ? [{ icon: "copy", text: L.t("скопировать в группу…"), action: () => pickGroup(false) }] : [],
                 [{ icon: "close", text: L.t("снять выделение"), action: done }],
                 own ? [{ separator: true }, { icon: "bin", text: L.t("удалить выбранные") + " (" + n + ")", danger: true,
                          action: () => { Vpn.removeNodes(g.id, list, false); done(); } }] : []);
        menu.openAt(x, y, false);
    }
    // руками менять можно узлы со ссылкой (из JSON/Clash-подписок и цепочки — нет)
    // nodes with a link can be changed by hand (ones from JSON/Clash subscriptions and chains can't)
    function editable(n): bool { return !!n && !!n.uri && VP.uriFields(n.uri) !== null; }

    // буфер обмена: Ctrl+V на вкладке серверов — сразу в открытую группу (если она своя), иначе — в форму ссылок
    // clipboard: Ctrl+V on the servers tab goes straight into the open group (if it's yours), otherwise into the links form
    property string clipFor: ""            // paste | field
    function pasteImport(): void { clipFor = "paste"; clipProc.running = true; }
    Process {
        id: clipProc
        command: ["sh", "-c", "wl-paste --no-newline 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (vp.clipFor === "field") { if (t) lLinks.text = lLinks.text.trim() ? lLinks.text.trim() + "\n" + t : t; return; }
                if (!t || !VP.parseSubscription(t).length) { Vpn.status = L.t("в буфере нет ссылок на серверы"); return; }
                const g = srv.group;
                if (g && g.type === "manual") Vpn.importLinks(g.id, "", t);
                else vp.startLinks(t, "");
            }
        }
    }
    property string linksErr: ""
    function startLinks(text: string, groupId: string): void {
        lTarget.reset(groupId || srv.group?.id || ""); lLinks.text = text; linksErr = ""; page = "links";
    }
    function submitLinks(): void {
        if (!lLinks.text.trim()) return;
        const id = Vpn.importLinks(lTarget.target, lTarget.newName.trim(), lLinks.text);
        if (!id) { linksErr = L.t("ссылок на серверы не нашлось — проверь текст"); return; }
        open = id; lLinks.text = ""; page = "list";
    }

    // редактор сервера: поля ↔ ссылка (VpnParse.uriFields / buildUri)
    // the server editor: fields ↔ link (VpnParse.uriFields / buildUri)
    property var nf: VP.emptyForm("vless")
    property string nodeGroup: ""
    property int nodeIdx: -1               // -1 — новый / -1: a new one
    property string nodeErr: ""
    function setF(k: string, v): void {
        const o = Object.assign({}, nf); o[k] = v;
        // REALITY бывает только у VLESS / REALITY only exists for VLESS
        if (k === "proto" && v !== "vless" && o.security === "reality") o.security = "tls";
        if (k === "proto" && (v === "socks" || v === "http")) o.security = "none";
        if (k === "proto" && v === "vmess" && o.net === "xhttp") o.net = "tcp";
        nf = o;
    }
    function startNode(groupId: string, i: int): void {
        const g = Vpn.groups.find(x => x.id === groupId);
        const n = i >= 0 ? g?.nodes[i] : null;
        const f = n ? VP.uriFields(n.uri) : VP.emptyForm(nf.proto || "vless");
        if (!f) return;
        nodeGroup = groupId; nodeIdx = n ? i : -1; nodeErr = ""; nf = f;
        nTarget.reset(groupId);
        nName.text = f.name; nServer.text = f.server; nPort.text = n ? f.port : ""; nUuid.text = f.uuid;
        nPass.text = f.password; nPass2.text = f.password; nUser.text = f.user; nObfs.text = f.obfs;
        nPath.text = f.path; nHost.text = f.host; nSni.text = f.sni; nAlpn.text = f.alpn; nPbk.text = f.pbk; nSid.text = f.sid;
        nflick.contentY = 0;
        page = "node";
    }
    function submitNode(copyOnly: bool): void {
        const f = Object.assign({}, nf, {
            name: nName.text.trim(), server: nServer.text.trim(), port: nPort.text.trim(), uuid: nUuid.text.trim(),
            password: (nf.proto === "socks" || nf.proto === "http") ? nPass2.text : nPass.text, user: nUser.text.trim(), obfs: nObfs.text.trim(),
            path: nPath.text.trim(), host: nHost.text.trim(), sni: nSni.text.trim(), alpn: nAlpn.text.trim(), pbk: nPbk.text.trim(), sid: nSid.text.trim()
        });
        if (!f.port) f.port = f.proto === "socks" ? "1080" : f.proto === "http" ? "8080" : "443";
        const port = parseInt(f.port);
        nodeErr = !f.server ? L.t("укажи адрес сервера")
                : !(port > 0 && port < 65536) ? L.t("порт — число от 1 до 65535")
                : (["vless", "vmess", "tuic"].includes(f.proto) && !f.uuid) ? L.t("нужен UUID")
                : (["trojan", "ss", "hysteria2"].includes(f.proto) && !f.password) ? L.t("нужен пароль")
                : (f.security === "reality" && !f.pbk) ? L.t("для REALITY нужен публичный ключ") : "";
        if (nodeErr) return;
        const uri = VP.buildUri(f), n = VP.parseUri(uri);
        if (!n) { nodeErr = L.t("не получилось собрать сервер — проверь поля"); return; }
        if (copyOnly) { Quickshell.execDetached(["wl-copy", uri]); Vpn.status = L.t("ссылка скопирована"); return; }
        if (nodeIdx >= 0) Vpn.setNode(nodeGroup, nodeIdx, n);
        else { const id = Vpn.addNodes(nTarget.target, nTarget.newName.trim(), [n]); if (id) open = id; }
        page = "list";
    }
}
