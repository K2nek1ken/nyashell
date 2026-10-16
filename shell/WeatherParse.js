.pragma library
// ответы разных поставщиков погоды → один формат для шелла.
// коды погоды везде приводятся к кодам WMO (как у Open-Meteo), чтобы значки и подписи были общими
// responses from different weather providers → one format for the shell.
// weather codes are converted to WMO codes everywhere (as in Open-Meteo), so icons and labels are shared

function urlFor(provider, lat, lon) {
    if (provider === "wttr") return "https://wttr.in/" + lat + "," + lon + "?format=j1";
    if (provider === "metno") return "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=" + (+lat).toFixed(3) + "&lon=" + (+lon).toFixed(3);
    return "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
        "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day,pressure_msl" +
        "&hourly=temperature_2m,weather_code,precipitation_probability" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max" +
        "&timezone=auto&forecast_days=7&wind_speed_unit=ms";
}

function parse(provider, text) {
    const j = JSON.parse(text);
    if (provider === "wttr") return wttr(j);
    if (provider === "metno") return metno(j);
    return openMeteo(j);
}

function openMeteo(j) {
    const c = j.current, d = j.daily, hr = j.hourly, now = new Date();
    let start = hr.time.findIndex(t => new Date(t) >= now); if (start < 0) start = 0;
    const hours = [];
    for (let i = start; i < hr.time.length && hours.length < 8; i += 3)
        hours.push({ h: new Date(hr.time[i]).getHours(), temp: Math.round(hr.temperature_2m[i]), code: hr.weather_code[i], pop: hr.precipitation_probability[i] ?? 0 });
    return {
        temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature), humidity: Math.round(c.relative_humidity_2m),
        wind: c.wind_speed_10m, pressure: Math.round(c.pressure_msl * 0.750062), code: c.weather_code, isDay: c.is_day === 1,
        uv: d.uv_index_max[0] ?? 0, sunrise: (d.sunrise[0] || "").slice(11, 16), sunset: (d.sunset[0] || "").slice(11, 16),
        days: d.time.map((t, i) => ({ date: t, max: Math.round(d.temperature_2m_max[i]), min: Math.round(d.temperature_2m_min[i]),
                                      code: d.weather_code[i], pop: d.precipitation_probability_max[i] ?? 0 })),
        hours: hours
    };
}

// wttr.in: коды WorldWeatherOnline → WMO
// wttr.in: WorldWeatherOnline codes → WMO
function wwo(c) {
    c = parseInt(c);
    if (c === 113) return 0; if (c === 116) return 2; if (c === 119 || c === 122) return 3;
    if ([143, 248, 260].includes(c)) return 45;
    if ([176, 263, 266, 293, 296, 353].includes(c)) return 61;
    if ([299, 302, 356].includes(c)) return 63; if ([305, 308, 359].includes(c)) return 65;
    if ([179, 227, 323, 326, 368].includes(c)) return 71; if ([329, 332, 371].includes(c)) return 73; if ([230, 335, 338].includes(c)) return 75;
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(c)) return 66;
    if ([200, 386, 389, 392, 395].includes(c)) return 95;
    return 3;
}
function ampm(t) {           // «07:12 AM» → «07:12»
    const m = String(t || "").match(/(\d+):(\d+)\s*(AM|PM)/i); if (!m) return "";
    let h = parseInt(m[1]) % 12; if (/pm/i.test(m[3])) h += 12;
    return String(h).padStart(2, "0") + ":" + m[2];
}
function wttr(j) {
    const c = j.current_condition[0], today = j.weather[0], ast = (today.astronomy || [{}])[0];
    const nowH = new Date().getHours(), sr = ampm(ast.sunrise), ss = ampm(ast.sunset);
    const hours = [];
    for (const day of j.weather) for (const h of day.hourly) {
        const hh = parseInt(h.time) / 100;
        if (day === today && hh + 3 <= nowH) continue;
        if (hours.length < 8) hours.push({ h: hh, temp: parseInt(h.tempC), code: wwo(h.weatherCode), pop: parseInt(h.chanceofrain) || 0 });
    }
    const nowStr = String(nowH).padStart(2, "0") + ":00";
    return {
        temp: parseInt(c.temp_C), feels: parseInt(c.FeelsLikeC), humidity: parseInt(c.humidity),
        wind: Math.round(parseInt(c.windspeedKmph) / 3.6 * 10) / 10, pressure: Math.round(parseInt(c.pressure) * 0.750062),
        code: wwo(c.weatherCode), isDay: !sr || !ss || (nowStr >= sr && nowStr < ss), uv: parseInt(c.uvIndex) || 0, sunrise: sr, sunset: ss,
        days: j.weather.map(d => ({ date: d.date, max: parseInt(d.maxtempC), min: parseInt(d.mintempC),
                                    code: wwo((d.hourly[4] || d.hourly[0]).weatherCode),
                                    pop: Math.max(...d.hourly.map(h => parseInt(h.chanceofrain) || 0)) })),
        hours: hours
    };
}

// MET Norway: символы → WMO
// MET Norway: symbols → WMO
function sym(s) {
    s = String(s || "").replace(/_(day|night|polartwilight)$/, "");
    if (s === "clearsky") return 0; if (s === "fair") return 1; if (s === "partlycloudy") return 2; if (s === "cloudy") return 3;
    if (s === "fog") return 45;
    if (/thunder/.test(s)) return 95;
    if (/sleet/.test(s)) return 66;
    if (/heavysnow/.test(s)) return 75; if (/lightsnow/.test(s)) return 71; if (/snow/.test(s)) return 73;
    if (/heavyrain/.test(s)) return 65; if (/lightrain/.test(s)) return 61; if (/rain/.test(s)) return 63;
    return 3;
}
function metno(j) {
    const ts = j.properties.timeseries, now = Date.now();
    let i0 = ts.findIndex(t => new Date(t.time).getTime() >= now - 3600e3); if (i0 < 0) i0 = 0;
    const cur = ts[i0], det = cur.data.instant.details;
    const symNow = cur.data.next_1_hours?.summary?.symbol_code || cur.data.next_6_hours?.summary?.symbol_code || "";
    const hours = [];
    for (let i = i0; i < ts.length && hours.length < 8; i += 3) {
        const t = ts[i], s = t.data.next_1_hours || t.data.next_6_hours || {};
        hours.push({ h: new Date(t.time).getHours(), temp: Math.round(t.data.instant.details.air_temperature),
                     code: sym(s.summary?.symbol_code), pop: Math.round(s.details?.probability_of_precipitation ?? 0) });
    }
    // дни: максимум/минимум по каждой дате, значок — около полудня
    // days: max/min for each date, the icon from around noon
    const byDay = {};
    for (const t of ts) {
        const d = t.time.slice(0, 10), v = t.data.instant.details.air_temperature;
        const b = byDay[d] || (byDay[d] = { date: d, max: -99, min: 99, code: 3, pop: 0, mid: 99 });
        b.max = Math.max(b.max, v); b.min = Math.min(b.min, v);
        const h = new Date(t.time).getUTCHours(), s = t.data.next_6_hours || t.data.next_1_hours;
        if (s && Math.abs(h - 12) < b.mid) { b.mid = Math.abs(h - 12); b.code = sym(s.summary?.symbol_code); }
    }
    const days = Object.values(byDay).slice(0, 7).map(b => ({ date: b.date, max: Math.round(b.max), min: Math.round(b.min), code: b.code, pop: 0 }));
    return {
        temp: Math.round(det.air_temperature), feels: Math.round(det.air_temperature), humidity: Math.round(det.relative_humidity ?? 0),
        wind: det.wind_speed ?? 0, pressure: Math.round((det.air_pressure_at_sea_level ?? 0) * 0.750062), code: sym(symNow),
        isDay: !/_night$/.test(symNow), uv: det.ultraviolet_index_clear_sky ?? 0, sunrise: "", sunset: "", days: days, hours: hours
    };
}
