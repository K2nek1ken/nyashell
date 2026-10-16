pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// bluetooth через bluetoothctl
// bluetooth via bluetoothctl
Singleton {
    id: bt
    property bool present: false
    property bool powered: false
    property var devices: []        // [{mac, name, connected}]
    property string busy: ""
    readonly property var connected: devices.filter(d => d.connected)

    Process {
        id: poll
        command: ["sh", "-c", "bluetoothctl show 2>&1; echo ==; bluetoothctl devices Paired; echo ==; bluetoothctl devices Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("==\n");
                const show = p[0] || "";
                bt.present = show.includes("Controller");
                bt.powered = /Powered:\s*yes/.test(show);
                const conn = (p[2] || "").split("\n").map(l => l.split(" ")[1]).filter(x => x);
                bt.devices = (p[1] || "").split("\n").filter(l => l.startsWith("Device ")).map(l => {
                    const mac = l.split(" ")[1];
                    return { mac: mac, name: l.split(" ").slice(2).join(" "), connected: conn.includes(mac) };
                });
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: poll.running = true }
    function refresh(): void { poll.running = true; }

    Process { id: act; onExited: { bt.busy = ""; poll.running = true; } }
    function run(cmd, mac): void { busy = mac || ""; act.command = cmd; act.running = true; }

    function toggle(): void { run(["bluetoothctl", "power", powered ? "off" : "on"]); }
    function choose(d): void { run(["bluetoothctl", d.connected ? "disconnect" : "connect", d.mac], d.mac); }

    // ─── управление устройствами ───
    // ─── device management ───
    function forget(mac: string): void { run(["bluetoothctl", "remove", mac], mac); }
    function trust(mac: string, on: bool): void { run(["bluetoothctl", on ? "trust" : "untrust", mac], mac); infoLater.restart(); }
    // сопряжение нового: без ввода PIN (подходит наушникам, мышкам, колонкам), потом доверие и подключение
    // pairing a new device: no PIN entry (fine for headphones, mice, speakers), then trust and connect
    function pair(mac: string): void {
        run(["sh", "-c", 'bluetoothctl --agent NoInputNoOutput pair "$1" && bluetoothctl trust "$1" && bluetoothctl connect "$1"', "sh", mac], mac);
    }

    // поиск новых устройств
    // scan for new devices
    property var found: []            // [{mac, name}]
    property bool scanning: false
    function scan(): void { if (!scanner.running) { scanning = true; found = []; scanner.running = true; } }
    Process {
        id: scanner
        command: ["sh", "-c", "bluetoothctl --timeout 12 scan on >/dev/null 2>&1; bluetoothctl devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = bt.devices.map(d => d.mac);
                bt.found = text.split("\n").filter(l => l.startsWith("Device ")).map(l => {
                    const f = l.split(" ");
                    return { mac: f[1], name: f.slice(2).join(" ") };
                }).filter(d => !known.includes(d.mac) && d.name && d.name.replace(/-/g, ":") !== d.mac);
            }
        }
        onExited: bt.scanning = false
    }

    // подробности об устройстве
    // device details
    property var info: ({})
    property string infoFor: ""
    function loadInfo(mac: string): void { infoFor = mac; infoProc.running = true; }
    Timer { id: infoLater; interval: 1200; onTriggered: if (bt.infoFor) infoProc.running = true }
    Process {
        id: infoProc
        command: ["bluetoothctl", "info", bt.infoFor]
        stdout: StdioCollector {
            onStreamFinished: {
                const i = {};
                for (const l of text.split("\n")) { const m = l.match(/^\s+([^:]+):\s*(.*)$/); if (m && i[m[1]] === undefined) i[m[1]] = m[2]; }
                const bat = (i["Battery Percentage"] || "").match(/\((\d+)\)/);
                bt.info = { name: i["Alias"] || i["Name"] || bt.infoFor, trusted: i["Trusted"] === "yes",
                            connected: i["Connected"] === "yes", paired: i["Paired"] === "yes",
                            battery: bat ? parseInt(bat[1]) : -1, icon: i["Icon"] || "" };
            }
        }
    }

    // адаптер не нашёлся: сначала снимаем программную блокировку, если не помогло — предлагаем перезапуск службы
    // no adapter found: first lift the soft block; if that doesn't help, offer to restart the service
    property bool healed: false
    Timer {
        interval: 4000; running: true
        onTriggered: if (!bt.present && !bt.healed) { bt.healed = true; Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]); poll.running = true; }
    }
    function restartService(): void {
        // любой init (systemd / openrc / runit / dinit / s6), имя службы — bluetooth или bluetoothd
        // any init (systemd / openrc / runit / dinit / s6), the service is named bluetooth or bluetoothd
        Quickshell.execDetached(["pkexec", "sh", Quickshell.shellPath("svc.sh"), "restart", "bluetooth", "bluetoothd"]);
        restartLater.restart();
    }
    Timer { id: restartLater; interval: 4000; onTriggered: poll.running = true }
}
