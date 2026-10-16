pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// нагрузка системы: процессор, память, диск, температура, аптайм (обновляется, только пока кто-то смотрит)
// system load: CPU, memory, disk, temperature, uptime (updates only while someone is watching)
Singleton {
    id: si
    property int watchers: 0          // дашборд увеличивает, пока открыт / the dashboard raises it while open
    property real cpu: 0              // 0..1
    property real mem: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real disk: 0
    property string diskText: ""
    property real temp: 0             // °C
    // видеокарта: у встроенной Intel нагрузку без root не прочитать, поэтому берём
    // текущую частоту от максимальной — хорошее приближение «насколько она сейчас занята»
    // GPU: integrated Intel load can't be read without root, so we use
    // the current frequency relative to the maximum, a good approximation of "how busy it is right now"
    property real gpu: 0
    Process {
        id: gpuProc
        command: ["sh", "-c", 'for c in /sys/class/drm/card*/; do [ -f "$c/gt_act_freq_mhz" ] && { cat "$c/gt_act_freq_mhz" "$c/gt_RP0_freq_mhz"; exit; }; ' +
                  '[ -f "$c/device/gpu_busy_percent" ] && { cat "$c/device/gpu_busy_percent"; echo 100; exit; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n").map(Number);
                si.gpu = v.length === 2 && v[1] > 0 ? Math.min(1, v[0] / v[1]) : 0;
            }
        }
    }
    property real uptime: 0           // сек / seconds
    property var cpuHist: []          // последние 60 замеров / the last 60 samples
    property var memHist: []
    property real rxRate: 0           // байт/с / bytes/s
    property real txRate: 0
    property var netPrev: null
    function human(b: real): string {
        if (b < 1024) return Math.round(b) + L.t(" Б/с");
        if (b < 1048576) return (b / 1024).toFixed(0) + L.t(" КБ/с");
        return (b / 1048576).toFixed(1) + L.t(" МБ/с");
    }
    property var prev: null

    // ── для монитора системы ──
    // ── for the system monitor ──
    property var cores: []            // загрузка по ядрам 0..1 / per-core load 0..1
    property var corePrev: []
    property real ghz: 0              // средняя частота / average frequency
    property string load: ""          // средняя загрузка за 1/5/15 мин / load average over 1/5/15 min
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property var rxHist: []           // байт/с, последние 60 / bytes/s, the last 60
    property var txHist: []
    property var disks: []            // [{mount, used, size, pct}]
    property var procs: []            // [{pid, name, cpu, mem}]
    property bool procWatch: false    // процессы опрашиваем, только пока монитор открыт / processes are polled only while the monitor is open
    property string procSort: "cpu"   // "cpu" | "mem"
    FileView { id: loadf; path: "/proc/loadavg" }
    FileView { id: cpuinfo; path: "/proc/cpuinfo" }
    Process {
        id: psProc
        command: ["sh", "-c", "ps -eo pid=,comm=,%cpu=,%mem= --sort=-%" + si.procSort + " | head -n 14"]
        stdout: StdioCollector {
            onStreamFinished: si.procs = text.split("\n").filter(l => l.trim()).map(l => {
                const f = l.trim().split(/\s+/);
                return { pid: f[0], name: f.slice(1, f.length - 2).join(" "), cpu: parseFloat(f[f.length - 2]), mem: parseFloat(f[f.length - 1]) };
            })
        }
    }
    Process {
        id: dfProc
        command: ["sh", "-c", "df -P -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: si.disks = text.split("\n").filter(l => l.trim()).map(l => {
                const f = l.trim().split(/\s+/);
                return { mount: f[5], used: parseInt(f[2]) / 1048576, size: parseInt(f[1]) / 1048576, pct: parseInt(f[4]) / 100 };
            }).filter(d => d.size > 0.5 && !d.mount.startsWith("/boot") && !d.mount.startsWith("/run"))
        }
    }
    property int slowTick: 0

    readonly property string uptimeText: {
        const d = Math.floor(uptime / 86400), h = Math.floor(uptime % 86400 / 3600), m = Math.floor(uptime % 3600 / 60);
        return (d ? d + L.t(" д ") : "") + (h ? h + L.t(" ч ") : "") + m + L.t(" мин");
    }

    FileView { id: stat; path: "/proc/stat" }
    FileView { id: meminfo; path: "/proc/meminfo" }
    FileView { id: up; path: "/proc/uptime" }
    FileView { id: netdev; path: "/proc/net/dev" }

    Process {
        id: misc
        command: ["sh", "-c", "df -P / | tail -1; echo ==; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("==\n");
                const f = (p[0] || "").trim().split(/\s+/);
                if (f.length >= 5) {
                    si.disk = parseInt(f[2]) / Math.max(1, parseInt(f[1]));
                    si.diskText = (parseInt(f[2]) / 1048576).toFixed(0) + " / " + (parseInt(f[1]) / 1048576).toFixed(0) + L.t(" ГБ");
                }
                const t = parseInt((p[1] || "").trim());
                if (t) si.temp = t / 1000;
            }
        }
    }

    function tick(): void {
        gpuProc.running = true;
        stat.reload(); meminfo.reload(); up.reload();
        const c = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (c.length >= 4) {
            const idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0);
            if (prev) {
                const dt = total - prev.total, di = idle - prev.idle;
                if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt));
            }
            prev = { total: total, idle: idle };
        }
        const mi = {};
        for (const l of meminfo.text().split("\n")) { const m = l.match(/^(\w+):\s+(\d+)/); if (m) mi[m[1]] = parseInt(m[2]); }
        if (mi.MemTotal) {
            memTotalGb = mi.MemTotal / 1048576;
            memUsedGb = (mi.MemTotal - (mi.MemAvailable ?? mi.MemFree)) / 1048576;
            mem = memUsedGb / memTotalGb;
            swapTotalGb = (mi.SwapTotal || 0) / 1048576;
            swapUsedGb = ((mi.SwapTotal || 0) - (mi.SwapFree || 0)) / 1048576;
        }
        uptime = parseFloat(up.text()) || 0;
        // ядра
        // cores
        const lines = stat.text().split("\n").filter(l => /^cpu\d+ /.test(l));
        const cs = [], cp = [];
        lines.forEach((l, i) => {
            const v = l.trim().split(/\s+/).slice(1).map(Number);
            const idle = v[3] + (v[4] || 0), total = v.reduce((a, b) => a + b, 0);
            const p = corePrev[i];
            cs.push(p && total > p.total ? Math.max(0, Math.min(1, 1 - (idle - p.idle) / (total - p.total))) : 0);
            cp.push({ total: total, idle: idle });
        });
        cores = cs; corePrev = cp;
        if (procWatch) {
            loadf.reload(); cpuinfo.reload();
            load = loadf.text().split(" ").slice(0, 3).join("  ");
            const mhz = cpuinfo.text().split("\n").filter(l => l.startsWith("cpu MHz")).map(l => parseFloat(l.split(":")[1]));
            ghz = mhz.length ? mhz.reduce((a, b) => a + b, 0) / mhz.length / 1000 : 0;
            psProc.running = true;
            if (slowTick++ % 5 === 0) dfProc.running = true;
        }
        cpuHist = cpuHist.concat([cpu]).slice(-60);
        memHist = memHist.concat([mem]).slice(-60);
        netdev.reload();
        let rx = 0, tx = 0;
        for (const l of netdev.text().split("\n").slice(2)) {
            const m = l.trim().match(/^([^:]+):\s*(.*)$/);
            if (!m || m[1] === "lo") continue;
            const f = m[2].split(/\s+/).map(Number);
            rx += f[0] || 0; tx += f[8] || 0;
        }
        const now = Date.now();
        if (netPrev) {
            const dt = (now - netPrev.t) / 1000;
            if (dt > 0) { rxRate = Math.max(0, (rx - netPrev.rx) / dt); txRate = Math.max(0, (tx - netPrev.tx) / dt); }
        }
        netPrev = { rx: rx, tx: tx, t: now };
        rxHist = rxHist.concat([rxRate]).slice(-60);
        txHist = txHist.concat([txRate]).slice(-60);
        misc.running = true;
    }

    Timer { interval: 2000; repeat: true; running: si.watchers > 0; triggeredOnStart: true; onTriggered: si.tick() }
}
