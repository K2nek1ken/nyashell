pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// батарея и профили питания. Кто управляет профилями:
//  ppd  — power-profiles-daemon (или tlp-pd из TLP 1.8+, он отвечает той же командой powerprofilesctl);
//  tlp  — старый TLP без tlp-pd: режимы «от сети» / «от батареи» переключаются через tlp ac / tlp bat
//         (это требует прав — пароль спросит наше окно polkit)
//  none — ни того, ни другого
// battery and power profiles. Who manages the profiles:
// ppd  — power-profiles-daemon (or tlp-pd from TLP 1.8+, which answers the same powerprofilesctl command);
// tlp  — old TLP without tlp-pd: "on AC" / "on battery" modes are switched with tlp ac / tlp bat
//        (this needs privileges, our polkit window will ask for the password)
// none — neither
Singleton {
    id: pw
    readonly property var dev: UPower.displayDevice
    // есть ли вообще батарея ноутбука. На обычном ПК её нет: тогда шелл считает, что всегда 100% от сети —
    // значок рисует батарейку с вилкой, режимы питания и «не гасить» работают, предупреждений о заряде нет
    // whether there is a laptop battery at all. A regular PC has none: then the shell assumes 100% on AC,
    // the icon draws a battery with a plug, power profiles and "keep awake" work, there are no charge warnings
    readonly property bool present: !!dev && dev.isLaptopBattery && dev.isPresent
    readonly property real pct: present ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 100
    readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
    // именно «разряжается» — пока UPower не сообщил состояние (сразу после входа) или зарядка подключена, это false
    // specifically "discharging": false until UPower reports the state (right after login) or while the charger is connected
    readonly property bool onBattery: present && dev.state === UPowerDeviceState.Discharging
    readonly property bool low: onBattery && pct < 20
    readonly property real toEmpty: dev?.timeToEmpty ?? 0      // сек / seconds
    readonly property real toFull: dev?.timeToFull ?? 0
    property string profile: ""                                // "power-saver" | "balanced" | "performance"
    property var profiles: []
    property string backend: "none"

    function fmt(sec: real): string {
        if (!sec || sec <= 0) return "";
        const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60);
        return (h ? h + L.t(" ч ") : "") + m + L.t(" мин");
    }
    readonly property string stateText: !present ? L.t("от сети")
        : full ? L.t("заряжена")
        : charging ? (L.t("заряжается") + (fmt(toFull) ? L.t(" · до полной ") + fmt(toFull) : ""))
        : (L.t("от батареи") + (fmt(toEmpty) ? L.t(" · осталось ") + fmt(toEmpty) : ""))

    Process {
        id: get
        command: ["sh", "-c",
            "if powerprofilesctl get >/dev/null 2>&1; then echo ppd; powerprofilesctl get; echo ==; powerprofilesctl list 2>/dev/null | grep -oE '(power-saver|balanced|performance):'; " +
            "elif command -v tlp >/dev/null; then echo tlp; tlp-stat -s 2>/dev/null | grep -i 'power source\\|mode' | head -2; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n"), kind = (lines[0] || "").trim();
                pw.backend = kind || "none";
                if (kind === "ppd") {
                    const p = lines.slice(1).join("\n").split("==\n");
                    pw.profile = (p[0] || "").trim();
                    pw.profiles = (p[1] || "").split("\n").map(x => x.replace(":", "").trim()).filter(x => x);
                } else if (kind === "tlp") {
                    // TLP без профилей: два режима — как при питании от сети (производительнее) и от батареи (экономнее)
                    // TLP without profiles: two modes, as on AC (faster) and as on battery (more economical)
                    const t = lines.slice(1).join(" ").toLowerCase();
                    pw.profiles = ["power-saver", "performance"];
                    pw.profile = /battery|bat\b/.test(t) ? "power-saver" : "performance";
                } else { pw.profiles = []; pw.profile = ""; }
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: true; triggeredOnStart: true; onTriggered: get.running = true }

    Process { id: setp; onExited: get.running = true }
    function setProfile(name: string): void {
        profile = name;
        setp.command = backend === "tlp"
            ? ["pkexec", "tlp", name === "power-saver" ? "bat" : "ac"]
            : ["powerprofilesctl", "set", name];
        setp.running = true;
    }

    // ─── низкий заряд: предупреждение, а на критическом — сон (пороги в настройках) ───
    // ─── low charge: a warning, and sleep at the critical level (thresholds in the settings) ───
    property bool warned: false
    property bool slept: false
    property bool ready: false
    // сразу после входа UPower отдаёт процент раньше, чем состояние — ждём, пока всё приедет
    // right after login UPower gives the percentage before the state, so wait until everything arrives
    Timer { interval: 6000; running: true; onTriggered: { pw.ready = true; pw.checkLow(); } }
    onPctChanged: checkLater.restart()
    onOnBatteryChanged: checkLater.restart()
    Timer { id: checkLater; interval: 1500; onTriggered: pw.checkLow() }
    function checkLow(): void {
        if (!ready) return;
        if (!onBattery) { warned = false; slept = false; return; }
        const low = ShellState.settings.batteryLow ?? 15, crit = ShellState.settings.batteryCritical ?? 5;
        if (!warned && pct <= low) {
            warned = true;
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "nyashell", L.t("Батарея садится"),
                                     Math.round(pct) + "% — " + L.t("подключи зарядку")]);
        }
        if (!slept && crit > 0 && pct <= crit) { slept = true; ShellState.sleepNow(); }
    }
}
