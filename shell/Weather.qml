pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "WeatherParse.js" as WP

// погода: Open-Meteo (бесплатно, без ключа, подробно).
// место: по окружающим Wi-Fi сетям через beaconDB (VPN не мешает — IP не используется),
// если не вышло — запасной город. Название города — Nominatim (OSM), по-русски.
// weather: Open-Meteo (free, no key, detailed).
// location: from the surrounding Wi-Fi networks via beaconDB (a VPN doesn't interfere, the IP isn't used),
// otherwise a fallback city. City name from Nominatim (OSM), localised.
Singleton {
    id: w
    readonly property var fallback: ({ name: L.t("Лондон"), lat: 51.507, lon: -0.128 })
    property bool triedIp: false
    readonly property string ua: "nyashell/1.0 (personal desktop shell)"

    property real lat: fallback.lat
    property real lon: fallback.lon
    property string city: fallback.name
    property string source: "fallback"      // "wifi" | "fallback"

    property bool ok: false
    property string lastError: ""
    property int temp: 0
    property int feels: 0
    property int humidity: 0
    property real wind: 0                   // м/с / m/s
    property int pressure: 0                // мм рт. ст. / mmHg
    property real uv: 0
    property int code: 0                    // код WMO / WMO code
    property bool isDay: true
    property string sunrise: ""
    property string sunset: ""
    readonly property string desc: describe(code)
    property var hours: []                  // [{h, temp, code, pop}]
    property var days: []                   // [{date, max, min, code, pop}]

    function describe(c: int): string {
        if (c === 0) return L.t("ясно");
        if (c === 1) return L.t("преимущественно ясно");
        if (c === 2) return L.t("переменная облачность");
        if (c === 3) return L.t("пасмурно");
        if (c === 45 || c === 48) return L.t("туман");
        if (c >= 51 && c <= 55) return L.t("морось");
        if (c === 56 || c === 57) return L.t("ледяная морось");
        if (c === 61) return L.t("небольшой дождь");
        if (c === 63) return L.t("дождь");
        if (c === 65) return L.t("сильный дождь");
        if (c === 66 || c === 67) return L.t("ледяной дождь");
        if (c === 71) return L.t("небольшой снег");
        if (c === 73) return L.t("снег");
        if (c === 75) return L.t("сильный снег");
        if (c === 77) return L.t("снежная крупа");
        if (c >= 80 && c <= 82) return L.t("ливень");
        if (c === 85 || c === 86) return L.t("снегопад");
        if (c === 95) return L.t("гроза");
        if (c === 96 || c === 99) return L.t("гроза с градом");
        return "";
    }
    function iconFor(c: int, night: bool): string {
        if (c === 0 || c === 1) return night ? "w_night" : "w_sunny";
        if (c === 2) return "w_partly";
        if (c === 3) return "w_cloudy";
        if (c === 45 || c === 48) return "w_fog";
        if (c >= 95) return "w_thunder";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "w_snow";
        return "w_rain";
    }

    // nmcli -t экранирует ':' как '\:'
    // nmcli -t escapes ':' as '\:'
    function fields(line) {
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

    // ─── 1. где мы: Wi-Fi вокруг → beaconDB ───
    // ─── 1. where we are: Wi-Fi around → beaconDB ───
    Process {
        id: scan
        command: ["nmcli", "-t", "-f", "BSSID,SIGNAL", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const aps = text.split("\n").filter(l => l).map(l => w.fields(l))
                    .filter(f => f[0] && f[0].length === 17)
                    .map(f => ({ macAddress: f[0].toLowerCase(), signalStrength: Math.round(parseInt(f[1]) / 2 - 100) }));
                if (aps.length < 2) { w.useFallback(); return; }
                locate.command = ["curl", "-sf", "--max-time", "15", "-A", w.ua, "-H", "Content-Type: application/json",
                    "-d", JSON.stringify({ considerIp: false, wifiAccessPoints: aps }),
                    "https://api.beacondb.net/v1/geolocate"];
                locate.running = true;
            }
        }
    }
    Process {
        id: locate
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (!j.location) throw L.t("нет");
                    w.lat = j.location.lat; w.lon = j.location.lng; w.source = w.triedIp ? "ip" : "wifi";
                    reverse.command = ["curl", "-sf", "--max-time", "15", "-A", w.ua,
                        "https://nominatim.openstreetmap.org/reverse?format=json&zoom=10&accept-language=" + L.lang + "&lat=" + w.lat + "&lon=" + w.lon];
                    reverse.running = true;
                    w.fetch();
                } catch (e) { w.useFallback(); }
            }
        }
    }
    Process {
        id: reverse
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const a = JSON.parse(text).address || {};
                    w.city = a.city || a.town || a.village || a.municipality || a.county || w.city;
                } catch (e) {}
            }
        }
    }
    function useFallback(): void {
        // wi-fi не помог — пробуем по IP (это может быть адрес VPN), потом уже запасной город
        // wi-fi didn't help: try by IP (it may be the VPN's address), and only then the fallback city
        if (!triedIp) {
            triedIp = true;
            locate.command = ["curl", "-sf", "--max-time", "15", "-A", ua, "-H", "Content-Type: application/json",
                "-d", JSON.stringify({ considerIp: true }), "https://api.beacondb.net/v1/geolocate"];
            locate.running = true;
            return;
        }
        lat = fallback.lat; lon = fallback.lon; city = fallback.name; source = "fallback";
        fetch();
    }

    // ─── 2. погода ───
    // поставщик — из настроек («auto» — по очереди, пока кто-то не ответит: Open-Meteo → wttr.in → MET Norway)
    // ─── 2. weather ───
    // provider from the settings ("auto" tries them in turn until one answers: Open-Meteo → wttr.in → MET Norway)
    readonly property string provider: ShellState.settings.weatherProvider ?? "auto"
    readonly property var order: provider === "auto" ? ["openmeteo", "wttr", "metno"] : [provider]
    property int tryIdx: 0
    property string usedProvider: ""          // кто ответил в последний раз / who answered last time
    readonly property var names: ({ openmeteo: "Open-Meteo", wttr: "wttr.in", metno: "MET Norway" })
    onProviderChanged: { tryIdx = 0; fetch(); }
    Process {
        id: req
        property string prov: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = WP.parse(req.prov, text);
                    w.temp = r.temp; w.feels = r.feels; w.humidity = r.humidity; w.wind = r.wind; w.pressure = r.pressure;
                    w.code = r.code; w.isDay = r.isDay; w.uv = r.uv; w.sunrise = r.sunrise; w.sunset = r.sunset;
                    w.days = r.days; w.hours = r.hours;
                    w.ok = true; w.lastError = ""; w.usedProvider = req.prov; w.tryIdx = 0;
                } catch (e) {
                    const name = w.names[req.prov] ?? req.prov;
                    w.lastError = text.trim() ? name + L.t(" ответил что-то непонятное") : L.t("нет ответа от ") + name;
                    // в режиме «авто» — следующий поставщик
                    // in "auto" mode: the next provider
                    if (w.tryIdx + 1 < w.order.length) { w.tryIdx++; nextLater.restart(); } else w.tryIdx = 0;
                }
            }
        }
    }
    Timer { id: nextLater; interval: 300; onTriggered: w.fetch() }
    function fetch(): void {
        if (req.running) return;
        const p = order[Math.min(tryIdx, order.length - 1)];
        req.prov = p;
        // curl без -f: при ошибке сервера всё равно видим ответ; через прокси VPN, если он включён, — сам по TUN
        // curl without -f: on a server error we still see the response; through the VPN proxy if it's on, or by itself via TUN
        req.command = ["curl", "-s", "-L", "--max-time", "20", "-A", ua, WP.urlFor(p, lat, lon)];
        req.running = true;
    }

    // город, заданный в настройках, — ищем координаты геокодером Open-Meteo
    // a city set in the settings: find its coordinates with Open-Meteo's geocoder
    readonly property string manualCity: ShellState.settings.weatherCity ?? ""
    onManualCityChanged: locateNow()
    Process {
        id: geocode
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text).results[0];
                    w.lat = r.latitude; w.lon = r.longitude; w.city = r.name; w.source = "manual";
                    w.fetch();
                } catch (e) { w.lastError = L.t("город «") + w.manualCity + L.t("» не нашёлся"); }
            }
        }
    }
    function locateNow(): void {
        if (manualCity) {
            geocode.command = ["curl", "-sf", "--max-time", "15", "-A", ua,
                "https://geocoding-api.open-meteo.com/v1/search?count=1&language=" + L.lang + "&name=" + encodeURIComponent(manualCity)];
            geocode.running = true;
        } else if (!scan.running && !locate.running) { triedIp = false; scan.running = true; }
    }

    // место уточняем раз в 3 часа, погоду — раз в 20 минут;
    // пока данных нет — пробуем каждую минуту, и сразу, как только появилась сеть
    // location is refined every 3 hours, weather every 20 minutes;
    // while there's no data, try every minute, and right away once the network appears
    Timer { id: relocate; interval: 3 * 3600 * 1000; repeat: true; running: true; triggeredOnStart: true
            onTriggered: w.locateNow() }
    Timer { interval: w.ok ? 20 * 60 * 1000 : 60 * 1000; repeat: true; running: true; onTriggered: w.fetch() }
    Connections {
        target: Net
        function onCurrentChanged() { if (Net.current) { w.ok ? w.fetch() : relocate.restart(); } }
    }
}
