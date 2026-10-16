pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// wi-fi через nmcli (NetworkManager) — общее состояние для панели и шторки
// wi-fi via nmcli (NetworkManager): shared state for the bar and the quick settings
Singleton {
    id: net
    property bool enabled: true
    property var nets: []           // [{ssid, signal, secure, active, saved}]
    property string asking: ""      // сеть, для которой вводим пароль / the network we're entering a password for
    property string status: ""
    readonly property var current: nets.find(n => n.active) ?? null

    function fields(line) {        // nmcli -t экранирует ':' как '\:' / nmcli -t escapes ':' as '\:'
        const out = []; let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (ch === ":") { out.push(cur); cur = ""; continue; }
            cur += ch;
        }
        out.push(cur);
        return out;
    }

    Process {
        id: scan
        property bool rescan: false
        command: ["sh", "-c",
            "nmcli -t -f WIFI g; echo ==; " +
            "nmcli -t -f NAME,TYPE con show | grep ':802-11-wireless$' | sed 's/:802-11-wireless$//'; echo ==; " +
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan " + (rescan ? "yes" : "no")]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("==\n");
                net.enabled = (parts[0] || "").trim() === "enabled";
                const saved = (parts[1] || "").split("\n").filter(x => x.length);
                const seen = {}, list = [];
                for (const l of (parts[2] || "").split("\n")) {
                    if (!l) continue;
                    const f = net.fields(l);
                    const ssid = f[1];
                    if (!ssid || seen[ssid]) continue;
                    seen[ssid] = true;
                    list.push({ ssid: ssid, active: f[0] === "*", signal: parseInt(f[2]) || 0,
                                secure: (f[3] || "") !== "" && f[3] !== "--", saved: saved.includes(ssid) });
                }
                list.sort((a, b) => (b.active - a.active) || (b.saved - a.saved) || (b.signal - a.signal));
                net.nets = list;
            }
        }
    }
    // ─── проводные подключения: кабель, USB-модем (телефон в режиме модема, свисток), мобильная сеть ───
    // [{dev, kind: "ethernet"|"usb"|"gsm", state: "connected"|…, con}] — USB отличаем по тому, что сетевая карта висит на шине USB
    // ─── wired connections: cable, USB modem (a phone tethering, a dongle), mobile network ───
    // [{dev, kind: "ethernet"|"usb"|"gsm", state: "connected"|…, con}]; USB is told apart by the network card sitting on the USB bus
    property var wired: []
    readonly property var wiredUp: wired.find(w => w.state === "connected") ?? null
    Process {
        id: wiredScan
        command: ["sh", "-c",
            'nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | while IFS= read -r l; do ' +
            '  d=${l%%:*}; t=$(echo "$l" | cut -d: -f2); case "$t" in ethernet|gsm|cdma|bt) ;; *) continue ;; esac; ' +
            '  k=$t; [ "$t" = ethernet ] && readlink -f "/sys/class/net/$d/device" 2>/dev/null | grep -q /usb && k=usb; ' +
            '  [ "$t" = cdma ] && k=gsm; [ "$t" = bt ] && k=usb; echo "$k:$l"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                net.wired = text.split("\n").filter(x => x).map(l => {
                    const f = net.fields(l);
                    return { kind: f[0], dev: f[1], state: f[3] || "", con: f[4] || "" };
                }).filter(w => w.state !== "unmanaged");
            }
        }
    }
    function toggleWired(w): void {
        run(w.state === "connected" ? ["nmcli", "dev", "disconnect", w.dev] : ["nmcli", "dev", "connect", w.dev], "");
        wiredLater.restart();
    }
    Timer { id: wiredLater; interval: 1500; onTriggered: wiredScan.running = true }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: wiredScan.running = true }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: net.refresh(false) }
    function refresh(rescan: bool): void { scan.rescan = rescan; scan.running = true; }

    property string pending: ""     // сеть, к которой сейчас подключаемся / the network we're connecting to right now
    Process {
        id: act
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (!err) return;
                // пароль лежал в KWallet (KDE хранит его «у агента»), а без KDE его никто не отдаёт —
                // просим пароль ещё раз и сохраняем уже в самом NetworkManager
                // the password was kept in KWallet (KDE stores it "with the agent"), and without KDE nobody hands it over,
                // so ask for the password again and save it in NetworkManager itself
                if (/secret|пароль|password/i.test(err) && net.pending) { net.asking = net.pending; net.status = L.t("нужен пароль — сохраню его в системе"); }
                else net.status = err.split("\n").pop();
            }
        }
        onExited: (code) => { if (code === 0) { net.status = ""; net.asking = ""; } net.pending = ""; net.refresh(false); }
    }
    function run(cmd, ssid): void { status = "…"; pending = ssid || ""; act.command = cmd; act.running = true; }

    function toggle(): void { run(["nmcli", "radio", "wifi", enabled ? "off" : "on"]); }
    function choose(n): void {
        if (n.active) run(["nmcli", "con", "down", "id", n.ssid]);
        else if (n.saved) run(["nmcli", "con", "up", "id", n.ssid], n.ssid);
        else if (n.secure) { asking = n.ssid; status = ""; }
        else run(["nmcli", "dev", "wifi", "connect", n.ssid], n.ssid);
    }
    // пароль сохраняется в самом NetworkManager (psk-flags 0), а не в кошельке KDE
    // the password is saved in NetworkManager itself (psk-flags 0), not in the KDE wallet
    function connect(ssid: string, password: string): void {
        const n = nets.find(x => x.ssid === ssid);
        if (n && n.saved)
            // имя и пароль идут отдельными аргументами — никакой подстановки в строку команды
            // name and password go as separate arguments: no substitution into the command string
            run(["sh", "-c", 'nmcli con modify id "$1" wifi-sec.psk-flags 0 wifi-sec.psk "$2" && nmcli con up id "$1"',
                 "sh", ssid, password], ssid);
        else
            run(["nmcli", "dev", "wifi", "connect", ssid, "password", password], ssid);
    }

    // ─── управление отдельной сетью (ПКМ по сети, «+», настройки сети) ───
    // ─── managing a single network (right-click a network, "+", network settings) ───
    property string dev: ""                 // имя wi-fi-адаптера (wlan0, wlp…) / wi-fi adapter name (wlan0, wlp…)
    Process {
        running: true
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | head -1 | cut -d: -f1"]
        stdout: StdioCollector { onStreamFinished: net.dev = text.trim() }
    }
    function disconnect(ssid: string): void { run(["nmcli", "con", "down", "id", ssid], ssid); }
    function forget(ssid: string): void { run(["nmcli", "con", "delete", "id", ssid], ssid); }
    // «по умолчанию»: подключаться сама и с высоким приоритетом, как только сеть видна
    // "default": connect automatically and with high priority as soon as the network is visible
    function setDefault(ssid: string, on: bool): void {
        modify(ssid, ["connection.autoconnect", "yes", "connection.autoconnect-priority", on ? "100" : "0"], false);
    }
    function setMetered(ssid: string, on: bool): void { modify(ssid, ["connection.metered", on ? "yes" : "no"], false); }
    function setRandomMac(ssid: string, on: bool): void {
        modify(ssid, ["802-11-wireless.cloned-mac-address", on ? "random" : "permanent"], true);
    }
    // свои DNS через пробел; пусто — снова от роутера
    // your own DNS separated by spaces; empty means from the router again
    function setDns(ssid: string, dns: string): void {
        const d = dns.trim().replace(/[,;]+/g, " ");
        modify(ssid, d ? ["ipv4.dns", d, "ipv4.ignore-auto-dns", "yes"] : ["ipv4.dns", "", "ipv4.ignore-auto-dns", "no"], true);
    }
    // изменить сохранённое подключение; reconnect — переподключиться, чтобы применилось сразу
    // edit a saved connection; reconnect so it applies right away
    function modify(ssid: string, pairs, reconnect: bool): void {
        run(["sh", "-c", 'id="$1"; r="$2"; shift 2; nmcli con modify id "$id" "$@" && ' +
             '{ [ "$r" = 1 ] && nmcli -t -f NAME con show --active | grep -qx "$id" && nmcli con up id "$id" || true; }',
             "sh", ssid, reconnect ? "1" : "0"].concat(pairs), ssid);
        infoLater.restart();
    }
    // добавить сеть вручную (в том числе скрытую)
    // add a network manually (hidden ones too)
    function add(ssid: string, password: string, hidden: bool): void {
        const cmd = ["nmcli", "dev", "wifi", "connect", ssid];
        if (password) cmd.push("password", password);
        if (hidden) cmd.push("hidden", "yes");
        run(cmd, ssid);
    }

    // подробности о сети: настройки подключения + текущие адреса
    // network details: connection settings + current addresses
    property var info: ({})
    property string infoFor: ""
    function loadInfo(ssid: string): void { infoFor = ssid; infoProc.running = true; }
    Timer { id: infoLater; interval: 1500; onTriggered: if (net.infoFor) infoProc.running = true }
    Process {
        id: infoProc
        command: ["sh", "-c",
            'nmcli -t -f connection.autoconnect,connection.autoconnect-priority,connection.metered,ipv4.dns,ipv4.ignore-auto-dns,802-11-wireless.cloned-mac-address,802-11-wireless-security.key-mgmt con show id "$1" 2>/dev/null; ' +
            'echo ==; [ -n "$2" ] && nmcli -t -f GENERAL.HWADDR,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS dev show "$2"',
            "sh", net.infoFor, net.dev]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("==\n"), i = {};
                const put = (block, prefix) => {
                    for (const l of (block || "").split("\n")) {
                        if (!l) continue;
                        const f = net.fields(l), k = f[0].replace(/\[\d+\]$/, ""), v = f.slice(1).join(":");
                        if (i[prefix + k] === undefined) i[prefix + k] = v; else i[prefix + k] += ", " + v;
                    }
                };
                put(parts[0], "");
                put(parts[1], "dev.");
                const active = i["dev.GENERAL.CONNECTION"] === net.infoFor;
                net.info = {
                    auto: i["connection.autoconnect"] === "yes" && parseInt(i["connection.autoconnect-priority"] || "0") > 0,
                    metered: (i["connection.metered"] || "").startsWith("yes"),
                    dns: i["ipv4.ignore-auto-dns"] === "yes" ? (i["ipv4.dns"] || "").replace(/,/g, " ") : "",
                    randomMac: i["802-11-wireless.cloned-mac-address"] === "random",
                    security: i["802-11-wireless-security.key-mgmt"] || "",
                    active: active,
                    ip: active ? (i["dev.IP4.ADDRESS"] || "") : "",
                    gateway: active ? (i["dev.IP4.GATEWAY"] || "") : "",
                    curDns: active ? (i["dev.IP4.DNS"] || "") : "",
                    ip6: active ? (i["dev.IP6.ADDRESS"] || "").split(", ")[0] : "",
                    mac: i["dev.GENERAL.HWADDR"] || ""
                };
            }
        }
    }
}
