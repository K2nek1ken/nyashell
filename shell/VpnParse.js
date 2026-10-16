.pragma library
// разбор ссылок и подписок для VPN-менеджера и сборка конфига sing-box (формат 1.12+).
// чистые функции — без QML, поэтому проверяются отдельно
// parsing links and subscriptions for the VPN manager and building the sing-box config (1.12+ format).
// pure functions with no QML, so they're tested separately

function b64(s) {
    s = String(s).trim().replace(/-/g, "+").replace(/_/g, "/").replace(/\s+/g, "");
    while (s.length % 4) s += "=";
    try {
        const bin = (typeof Qt !== "undefined" && Qt.atob) ? Qt.atob(s) : atob(s);
        // utf-8
        try { return decodeURIComponent(bin.split("").map(c => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2)).join("")); }
        catch (e) { return bin; }
    } catch (e) { return ""; }
}
function dec(s) { try { return decodeURIComponent(s || ""); } catch (e) { return s || ""; } }
function query(q) {
    const o = {};
    (q || "").split("&").forEach(kv => { if (!kv) return; const i = kv.indexOf("="); o[dec(i < 0 ? kv : kv.slice(0, i))] = dec(i < 0 ? "" : kv.slice(i + 1)); });
    return o;
}
// user@host:port?query#name → части
// user@host:port?query#name → parts
function split(uri) {
    const m = uri.match(/^([a-z0-9]+):\/\/([^#]*)(?:#(.*))?$/i);
    if (!m) return null;
    let rest = m[2], q = "";
    const qi = rest.indexOf("?"); if (qi >= 0) { q = rest.slice(qi + 1); rest = rest.slice(0, qi); }
    rest = rest.replace(/\/$/, "");
    let user = "", hostport = rest;
    const at = rest.lastIndexOf("@"); if (at >= 0) { user = rest.slice(0, at); hostport = rest.slice(at + 1); }
    let host = hostport, port = 0;
    const hp = hostport.match(/^\[(.+)\]:(\d+)$/) || hostport.match(/^([^:]+):(\d+)$/);
    if (hp) { host = hp[1]; port = parseInt(hp[2]); }
    return { scheme: m[1].toLowerCase(), user: dec(user), host: host, port: port, q: query(q), name: dec(m[3] || "") };
}
function tls(q, defSecurity) {
    const sec = q.security || defSecurity || "";
    if (sec !== "tls" && sec !== "reality") return null;
    const t = { enabled: true, server_name: q.sni || q.peer || q.host || "", insecure: q.allowInsecure === "1" || q.insecure === "1" };
    if (q.alpn) t.alpn = q.alpn.split(",");
    if (q.fp) t.utls = { enabled: true, fingerprint: q.fp };
    if (sec === "reality") { t.reality = { enabled: true, public_key: q.pbk || "", short_id: q.sid || "" }; if (!t.utls) t.utls = { enabled: true, fingerprint: "chrome" }; }
    return t;
}
function transport(q) {
    const type = q.type || q.net || "tcp";
    if (type === "ws") return { type: "ws", path: q.path || "/", headers: q.host ? { Host: q.host } : undefined };
    if (type === "grpc") return { type: "grpc", service_name: q.serviceName || q.path || "" };
    if (type === "http" || type === "h2") return { type: "http", path: q.path || "/", host: q.host ? [q.host] : undefined };
    if (type === "httpupgrade") return { type: "httpupgrade", path: q.path || "/", host: q.host || undefined };
    if (type === "xhttp" || type === "splithttp") return { xray: true, type: "xhttp" };   // это умеет только Xray / only Xray can do this
    return null;
}
function clean(o) { return JSON.parse(JSON.stringify(o)); }

// одна ссылка → узел { name, proto, server, port, outbound, needsXray }
// one link → a node { name, proto, server, port, outbound, needsXray }
function parseUri(uri) {
    uri = uri.trim();
    if (!uri || uri.startsWith("#")) return null;
    let p = null, ob = null, xray = false;
    if (/^vmess:\/\//i.test(uri)) {
        let j = null;
        try { j = JSON.parse(b64(uri.slice(8))); } catch (e) { return null; }
        const q = { type: j.net, host: j.host, path: j.path, security: j.tls, sni: j.sni, alpn: j.alpn, fp: j.fp, serviceName: j.path };
        const tr = transport(q); if (tr && tr.xray) xray = true;
        ob = { type: "vmess", server: j.add, server_port: parseInt(j.port), uuid: j.id, alter_id: parseInt(j.aid || 0), security: j.scy || "auto",
               tls: tls(q) || undefined, transport: tr && !tr.xray ? tr : undefined };
        return { name: j.ps || j.add, proto: "vmess", server: j.add, port: parseInt(j.port), outbound: clean(ob), needsXray: xray, uri: uri };
    }
    if (/^ss:\/\//i.test(uri)) {
        // ss://base64(method:pass)@host:port#name   или   ss://base64(method:pass@host:port)#name
        // ss://base64(method:pass)@host:port#name   or   ss://base64(method:pass@host:port)#name
        let s = split(uri); if (!s) return null;
        let method = "", pass = "";
        if (s.port) { const u = s.user.includes(":") ? s.user : b64(s.user); const i = u.indexOf(":"); method = u.slice(0, i); pass = u.slice(i + 1); }
        else { const all = b64(uri.slice(5).split("#")[0]); const m = all.match(/^([^:]+):(.*)@([^@]+):(\d+)$/); if (!m) return null;
               method = m[1]; pass = m[2]; s.host = m[3]; s.port = parseInt(m[4]); }
        ob = { type: "shadowsocks", server: s.host, server_port: s.port, method: method, password: pass };
        return { name: s.name || s.host, proto: "ss", server: s.host, port: s.port, outbound: clean(ob), needsXray: false, uri: uri };
    }
    p = split(uri); if (!p || !p.host) return null;
    const q = p.q;
    if (p.scheme === "vless" || p.scheme === "trojan") {
        const tr = transport(q); if (tr && tr.xray) xray = true;
        ob = p.scheme === "vless"
            ? { type: "vless", server: p.host, server_port: p.port, uuid: p.user, flow: q.flow || undefined }
            : { type: "trojan", server: p.host, server_port: p.port, password: p.user };
        ob.tls = tls(q, p.scheme === "trojan" ? "tls" : "") || undefined;
        if (tr && !tr.xray) ob.transport = tr;
        if (q.packetEncoding || p.scheme === "vless") ob.packet_encoding = q.packetEncoding || "xudp";
    } else if (p.scheme === "hysteria2" || p.scheme === "hy2") {
        ob = { type: "hysteria2", server: p.host, server_port: p.port, password: p.user,
               tls: { enabled: true, server_name: q.sni || p.host, insecure: q.insecure === "1", alpn: q.alpn ? q.alpn.split(",") : undefined } };
        if (q.obfs) ob.obfs = { type: q.obfs, password: q["obfs-password"] || "" };
        if (q.mport) ob.server_ports = q.mport.split(",").map(x => x.replace("-", ":"));
    } else if (p.scheme === "hysteria") {
        // Hysteria первой версии: hysteria://host:port?auth=…&peer=sni&insecure=1&upmbps=…&downmbps=…&obfsParam=…&alpn=…
        // Hysteria v1: hysteria://host:port?auth=…&peer=sni&insecure=1&upmbps=…&downmbps=…&obfsParam=…&alpn=…
        ob = { type: "hysteria", server: p.host, server_port: p.port, auth_str: q.auth || p.user || undefined,
               up_mbps: parseInt(q.upmbps || q.up || 50), down_mbps: parseInt(q.downmbps || q.down || 100),
               obfs: q.obfsParam || q.obfs || undefined,
               tls: { enabled: true, server_name: q.peer || q.sni || p.host, insecure: q.insecure === "1", alpn: (q.alpn || "hysteria").split(",") } };
        if (q.mport) ob.server_ports = q.mport.split(",").map(x => x.replace("-", ":"));
    } else if (p.scheme === "tuic") {
        const i = p.user.indexOf(":");
        ob = { type: "tuic", server: p.host, server_port: p.port, uuid: i < 0 ? p.user : p.user.slice(0, i), password: i < 0 ? "" : p.user.slice(i + 1),
               congestion_control: q.congestion_control || "bbr",
               tls: { enabled: true, server_name: q.sni || p.host, insecure: q.allow_insecure === "1" || q.insecure === "1", alpn: (q.alpn || "h3").split(",") } };
    } else if (p.scheme === "socks" || p.scheme === "socks5" || p.scheme === "http" || p.scheme === "https") {
        // socks://[логин:пароль@]host:port, http(s)://… — логин и пароль иногда в base64 / login and password are sometimes base64
        let u = p.user;
        if (u && !u.includes(":")) { const d = b64(u); if (d.includes(":")) u = d; }
        const i = u.indexOf(":");
        const http = p.scheme.startsWith("http");
        ob = { type: http ? "http" : "socks", server: p.host, server_port: p.port || (http ? 8080 : 1080),
               username: u ? (i < 0 ? u : u.slice(0, i)) : undefined, password: i < 0 ? undefined : u.slice(i + 1) };
        if (!http) ob.version = "5";
        if (p.scheme === "https") ob.tls = { enabled: true, server_name: q.sni || p.host, insecure: q.insecure === "1" };
        return { name: p.name || p.host, proto: http ? "http" : "socks", server: p.host, port: ob.server_port, outbound: clean(ob), needsXray: false, uri: uri };
    } else return null;
    return { name: p.name || p.host, proto: p.scheme === "hy2" ? "hysteria2" : p.scheme, server: p.host, port: p.port, outbound: clean(ob), needsXray: xray, uri: uri };
}

// ─── ручной редактор сервера (как «Новый профиль» в NekoBox) ───
// ссылка ↔ поля формы. Сохраняем всегда ссылкой: дальше она идёт тем же путём, что и из подписки (parseUri),
// так что у ручных серверов нет своего, отдельного кода сборки конфига
// ─── manual server editor (like "New profile" in NekoBox) ───
// link ↔ form fields. We always save as a link: from there it goes the same way as one from a subscription (parseUri),
// so manual servers have no separate config-building code of their own
const FORM_DEFAULTS = { proto: "vless", name: "", server: "", port: "443", uuid: "", password: "", user: "", method: "2022-blake3-aes-128-gcm",
    flow: "", vmessSec: "auto", security: "tls", sni: "", fp: "chrome", alpn: "", insecure: false, pbk: "", sid: "",
    net: "tcp", path: "", host: "", obfs: "", cc: "bbr" };
// base64 от UTF-8 своими силами: Qt.btoa и btoa по-разному обходятся с не-латиницей
// base64 of UTF-8 on our own: Qt.btoa and btoa handle non-Latin text differently
function b64enc(str) {
    const bytes = [], u = encodeURIComponent(String(str));
    for (let i = 0; i < u.length; i++) {
        if (u[i] === "%") { bytes.push(parseInt(u.substr(i + 1, 2), 16)); i += 2; } else bytes.push(u.charCodeAt(i));
    }
    const A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let out = "";
    for (let i = 0; i < bytes.length; i += 3) {
        const n = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0);
        out += A[(n >> 18) & 63] + A[(n >> 12) & 63] + (i + 1 < bytes.length ? A[(n >> 6) & 63] : "=") + (i + 2 < bytes.length ? A[n & 63] : "=");
    }
    return out;
}
function emptyForm(proto) { return Object.assign({}, FORM_DEFAULTS, proto ? { proto: proto } : {}); }
function uriFields(uri) {
    const f = emptyForm();
    uri = String(uri || "").trim();
    if (/^vmess:\/\//i.test(uri)) {
        let j = {}; try { j = JSON.parse(b64(uri.slice(8))); } catch (e) { return null; }
        return Object.assign(f, { proto: "vmess", name: j.ps || "", server: j.add || "", port: String(j.port || ""), uuid: j.id || "",
            vmessSec: j.scy || "auto", security: j.tls === "tls" ? "tls" : "none", sni: j.sni || "", fp: j.fp || "", alpn: j.alpn || "",
            net: j.net || "tcp", path: j.path || "", host: j.host || "" });
    }
    const n = parseUri(uri); if (!n) return null;
    const p = split(uri), q = p ? p.q : {}, o = n.outbound;
    Object.assign(f, { name: n.name === n.server ? "" : n.name, server: n.server, port: String(n.port || "") });
    if (n.proto === "ss") return Object.assign(f, { proto: "ss", method: o.method, password: o.password });
    if (n.proto === "socks" || n.proto === "http")
        return Object.assign(f, { proto: n.proto, user: o.username || "", password: o.password || "", security: o.tls ? "tls" : "none", sni: o.tls ? (q.sni || "") : "" });
    const tl = o.tls || {};
    Object.assign(f, { sni: tl.server_name && tl.server_name !== n.server ? tl.server_name : (q.sni || ""), insecure: !!tl.insecure,
                       alpn: (tl.alpn || []).join(","), fp: tl.utls ? tl.utls.fingerprint : "" });
    if (n.proto === "vless" || n.proto === "trojan") {
        Object.assign(f, { proto: n.proto, uuid: o.uuid || "", password: o.password || "", flow: o.flow || "",
            security: tl.reality ? "reality" : (tl.enabled ? "tls" : "none"), pbk: tl.reality ? tl.reality.public_key : "", sid: tl.reality ? tl.reality.short_id : "",
            net: q.type || "tcp", path: q.serviceName || q.path || "", host: q.host || "" });
    } else if (n.proto === "hysteria2") Object.assign(f, { proto: "hysteria2", password: o.password, obfs: o.obfs ? o.obfs.password : "" });
    else if (n.proto === "tuic") Object.assign(f, { proto: "tuic", uuid: o.uuid, password: o.password, cc: o.congestion_control || "bbr" });
    else return null;
    return f;
}
function buildUri(f) {
    const e = encodeURIComponent, host = /:/.test(f.server) ? "[" + f.server + "]" : f.server;
    const hp = host + ":" + (parseInt(f.port) || 443), name = f.name ? "#" + e(f.name) : "";
    const qs = (o) => { const k = Object.keys(o).filter(x => o[x] !== "" && o[x] !== undefined && o[x] !== null); return k.length ? "?" + k.map(x => e(x) + "=" + e(o[x])).join("&") : ""; };
    const tlsQ = () => f.security === "none" ? { security: "none" } : Object.assign({ security: f.security, sni: f.sni, fp: f.fp, alpn: f.alpn },
        f.insecure ? { allowInsecure: "1" } : {}, f.security === "reality" ? { pbk: f.pbk, sid: f.sid } : {});
    const netQ = () => f.net === "grpc" ? { type: "grpc", serviceName: f.path } : Object.assign({ type: f.net }, f.net === "tcp" ? {} : { path: f.path, host: f.host });
    switch (f.proto) {
    case "vless": return "vless://" + e(f.uuid) + "@" + hp + qs(Object.assign({ encryption: "none", flow: f.flow }, netQ(), tlsQ())) + name;
    case "trojan": return "trojan://" + e(f.password) + "@" + hp + qs(Object.assign({}, netQ(), tlsQ())) + name;
    case "vmess": {
        const j = { v: "2", ps: f.name || f.server, add: f.server, port: String(parseInt(f.port) || 443), id: f.uuid, aid: "0", scy: f.vmessSec,
                    net: f.net, type: "none", host: f.host, path: f.path, tls: f.security === "tls" ? "tls" : "", sni: f.sni, alpn: f.alpn, fp: f.fp };
        return "vmess://" + b64enc(JSON.stringify(j));
    }
    case "ss": {
        return "ss://" + b64enc(f.method + ":" + f.password).replace(/=+$/, "") + "@" + hp + name;
    }
    case "hysteria2": return "hysteria2://" + e(f.password) + "@" + hp + qs(Object.assign({ sni: f.sni, alpn: f.alpn }, f.insecure ? { insecure: "1" } : {},
                                                                                       f.obfs ? { obfs: "salamander", "obfs-password": f.obfs } : {})) + name;
    case "tuic": return "tuic://" + e(f.uuid) + ":" + e(f.password) + "@" + hp + qs(Object.assign({ sni: f.sni, alpn: f.alpn || "h3", congestion_control: f.cc },
                                                                                                f.insecure ? { allow_insecure: "1" } : {})) + name;
    case "socks": case "http": {
        const auth = f.user ? e(f.user) + (f.password ? ":" + e(f.password) : "") + "@" : "";
        const sch = f.proto === "socks" ? "socks" : (f.security === "tls" ? "https" : "http");
        return sch + "://" + auth + host + ":" + (parseInt(f.port) || (f.proto === "socks" ? 1080 : 8080)) + (sch === "https" && f.sni ? "?sni=" + e(f.sni) : "") + name;
    }
    }
    return "";
}
// одинаковые узлы (для «убрать дубликаты»): по ссылке, иначе по выходу / identical nodes (for "remove duplicates"): by link, otherwise by outbound
function nodeKey(n) {
    if (!n) return "";
    const o = Object.assign({}, n.outbound || {}); delete o.tag;
    return n.proto === "chain" ? "chain:" + JSON.stringify(n.hops) : n.proto + "|" + JSON.stringify(o);
}

// тело подписки → узлы. Понимает: base64 со ссылками, ссылки построчно, JSON sing-box, YAML Clash
// что за формат пришёл — чтобы честно сказать, если разобрать не можем
// subscription body → nodes. Understands: base64 with links, links per line, sing-box JSON, Clash YAML
// which format arrived, so we can say honestly if we can't parse it
function sniff(text) {
    const t = String(text || "").trim();
    if (!t) return "empty";
    if (/happ:\/\/crypt/i.test(t.slice(0, 4000))) return "happ-crypt";
    if (/^<!doctype|^<html/i.test(t)) return "html";
    return "";
}
function parseSubscription(text) {
    let t = String(text || "").trim();
    // JSON: sing-box (outbounds с type) или Xray (outbounds с protocol; часто — массив целых конфигов, как у Happ/v2rayNG)
    // JSON: sing-box (outbounds with type) or Xray (outbounds with protocol; often an array of whole configs, as in Happ/v2rayNG)
    if (t.startsWith("{") || t.startsWith("[")) {
        try {
            const j = JSON.parse(t);
            const list = Array.isArray(j) ? j : [j];
            const xr = list.some(c => (c.outbounds || []).some(o => o.protocol));
            return xr ? fromXrayJson(list) : fromSingBox(list[0]);
        } catch (e) {}
    }
    if (/^\s*proxies\s*:/m.test(t)) return fromClash(t);
    if (!/:\/\//.test(t)) t = b64(t);
    return t.split(/\r?\n/).map(parseUri).filter(n => n);
}

// JSON Xray (как в подписках Happ/v2rayNG): каждый конфиг — сервер, название — remarks.
// Как в Exclave, каждый выход переводится в «родной» формат sing-box — тогда трафик идёт без лишнего звена.
// Через Xray остаются только узлы, которые sing-box не умеет: XHTTP/splithttp, mKCP, QUIC, маски finalmask TCP,
// http-маскировка TCP, постквантовое шифрование VLESS
// Xray JSON (as in Happ/v2rayNG subscriptions): each config is a server, the name is remarks.
// As in Exclave, each outbound is converted to the "native" sing-box format so traffic goes without an extra hop.
// Only nodes sing-box can't do stay on Xray: XHTTP/splithttp, mKCP, QUIC, finalmask TCP masks,
// TCP http obfuscation, VLESS post-quantum encryption
const XRAY_PROXY = ["vless", "vmess", "trojan", "shadowsocks", "socks", "http", "hysteria", "hysteria2"];
function fromXrayJson(list) {
    const out = [];
    list.forEach(c => {
        if (!c || typeof c !== "object") return;
        for (const ob of (c.outbounds || [])) {
            const proto = String(ob.protocol || "").toLowerCase();
            if (!XRAY_PROXY.includes(proto)) continue;
            const name = c.remarks || c.name || ob.tag || proto;
            const n = xrayToSingBox(ob);
            if (n) { out.push(Object.assign(n, { name: name, xray: ob })); break; }
            // sing-box не умеет — оставляем Xray
            // sing-box can't do it: keep Xray
            const st = ob.settings || {}, v = (st.vnext || st.servers || [])[0] || st;
            const net = String((ob.streamSettings || {}).network || "tcp").toLowerCase();
            out.push({ name: name, proto: proto + "/" + net, server: v.address || "", port: parseInt(v.port) || 0,
                       needsXray: true, xray: ob, uri: "" });
            break;
        }
    });
    return out;
}
// диапазон портов Xray («20000-30000», «443,8443», число) → server_ports sing-box («20000:30000»)
// Xray port range ("20000-30000", "443,8443", a number) → sing-box server_ports ("20000:30000")
function xrayPorts(p) {
    if (p === undefined || p === null || p === "") return null;
    return String(p).split(",").map(x => x.trim()).filter(x => x).map(x => x.replace("-", ":"));
}
function xrayTls(ss) {
    const sec = String(ss.security || "none").toLowerCase();
    if (sec === "tls" || sec === "xtls" || sec === "utls") {
        const t = ss.tlsSettings || ss.xtlsSettings || (ss.utlsSettings || {}).tlsConfig || {};
        const o = { enabled: true, server_name: t.serverName || "", insecure: !!t.allowInsecure };
        const alpn = Array.isArray(t.alpn) ? t.alpn : t.alpn ? String(t.alpn).split(",") : null;
        if (alpn && alpn.length) o.alpn = alpn;
        const fp = t.fingerprint || (ss.utlsSettings || {}).imitate;
        if (fp) o.utls = { enabled: true, fingerprint: fp };
        return o;
    }
    if (sec === "reality") {
        const r = ss.realitySettings || {};
        if (r.mldsa65Verify) return false;                     // sing-box этого не умеет / sing-box can't do this
        return { enabled: true, server_name: r.serverName || "",
                 utls: { enabled: true, fingerprint: r.fingerprint || "chrome" },
                 reality: { enabled: true, public_key: r.publicKey || r.password || "", short_id: r.shortId || "" } };
    }
    return null;
}
function xrayTransport(ss) {
    const net = String(ss.network || "tcp").toLowerCase();
    const fm = ss.finalmask || {};
    if (Array.isArray(fm.tcp) && fm.tcp.length) return false;
    if (net === "tcp" || net === "raw") {
        const h = ((ss.tcpSettings || ss.rawSettings || {}).header || {});
        return !h.type || h.type === "none" ? null : false;  // http-маскировка TCP — только Xray / TCP http obfuscation: Xray only
    }
    if (net === "ws" || net === "websocket") {
        const w = ss.wsSettings || {};
        let path = w.path || "/", ed = 0;
        const m = path.match(/[?&]ed=(\d+)/);
        if (m) { ed = parseInt(m[1]); path = path.replace(/[?&]ed=\d+/, "").replace(/\?$/, "") || "/"; }
        const host = w.host || (w.headers || {}).Host || (w.headers || {}).host;
        const t = { type: "ws", path: path };
        if (host) t.headers = { Host: host };
        if (ed || w.maxEarlyData) { t.max_early_data = ed || w.maxEarlyData; t.early_data_header_name = "Sec-WebSocket-Protocol"; }
        return t;
    }
    if (net === "grpc" || net === "gun") return { type: "grpc", service_name: (ss.grpcSettings || ss.gunSettings || {}).serviceName || "" };
    if (net === "httpupgrade") { const u = ss.httpupgradeSettings || {}; return { type: "httpupgrade", path: u.path || "/", host: u.host || undefined }; }
    if (net === "http" || net === "h2") { const u = ss.httpSettings || {}; return { type: "http", path: u.path || "/", host: u.host ? [].concat(u.host) : undefined }; }
    return false;                                              // xhttp, splithttp, kcp, quic…
}
function xrayToSingBox(ob) {
    const proto = String(ob.protocol || "").toLowerCase();
    const st = ob.settings || {}, ss = ob.streamSettings || {};
    // Hysteria 2 из Xray: protocol "hysteria" (version 2) или "hysteria2"
    // Hysteria 2 from Xray: protocol "hysteria" (version 2) or "hysteria2"
    if (proto === "hysteria" || proto === "hysteria2") {
        const sv = st.address ? st : ((st.servers || [])[0] || {});
        if (proto === "hysteria" && st.version && st.version !== 2) return null;
        const hs = ss.hysteriaSettings || {}, h2 = ss.hy2Settings || {};
        if (proto === "hysteria" && hs.version && hs.version !== 2) return null;
        const o = { type: "hysteria2", server: sv.address, server_port: parseInt(sv.port) || 443, password: hs.auth || h2.password || "" };
        const t = xrayTls(ss);
        o.tls = t || { enabled: true, server_name: sv.address };
        if (!o.tls.alpn) o.tls.alpn = ["h3"];
        delete o.tls.utls; delete o.tls.reality;
        // переключение портов (udphop) и маскировка salamander — из hysteriaSettings или finalmask
        // port hopping (udphop) and salamander obfuscation from hysteriaSettings or finalmask
        const hop = hs.udphop || ((ss.finalmask || {}).quicParams || {}).udphop;
        const masks = ((ss.finalmask || {}).udp || []);
        const hopMask = masks.find(m => m.type === "udphop"), obfsMask = masks.find(m => m.type === "salamander");
        if (masks.some(m => m.type !== "udphop" && m.type !== "salamander")) return null;
        const ports = hop ? xrayPorts(hop.ports) : hopMask ? xrayPorts((hopMask.settings || {}).remotePorts) : h2.hopPorts ? xrayPorts(h2.hopPorts) : null;
        if (ports) o.server_ports = ports;
        const obfsPass = obfsMask ? (obfsMask.settings || {}).password : (h2.obfs && h2.obfs.type === "salamander" ? h2.obfs.password : null);
        if (h2.obfs && h2.obfs.type && h2.obfs.type !== "salamander") return null;
        if (obfsPass) o.obfs = { type: "salamander", password: obfsPass };
        if (!o.server) return null;
        return { proto: "hysteria2", server: o.server, port: o.server_port, outbound: clean(o), needsXray: false, uri: "" };
    }
    const v = (st.vnext || st.servers || [])[0] || st;
    const u = (v.users || [])[0] || v;
    const server = v.address, port = parseInt(v.port) || 0;
    if (!server || !port) return null;
    const tls = xrayTls(ss);
    if (tls === false) return null;
    const tr = xrayTransport(ss);
    if (tr === false) return null;
    let o;
    if (proto === "vless") {
        const flow = u.flow || "";
        if (flow && flow !== "xtls-rprx-vision") return null;
        if (u.encryption && u.encryption !== "none") return null;
        o = { type: "vless", server: server, server_port: port, uuid: u.id, flow: flow || undefined, packet_encoding: "xudp" };
    } else if (proto === "vmess") {
        o = { type: "vmess", server: server, server_port: port, uuid: u.id, alter_id: parseInt(u.alterId || 0), security: u.security || "auto" };
    } else if (proto === "trojan") {
        o = { type: "trojan", server: server, server_port: port, password: u.password || v.password };
    } else if (proto === "shadowsocks") {
        o = { type: "shadowsocks", server: server, server_port: port, method: u.method || v.method, password: u.password || v.password };
    } else if (proto === "socks") {
        o = { type: "socks", server: server, server_port: port, username: u.user || undefined, password: u.pass || undefined };
    } else if (proto === "http") {
        o = { type: "http", server: server, server_port: port, username: u.user || undefined, password: u.pass || undefined };
    } else return null;
    if (tls) { o.tls = tls; if (!tls.server_name && !tls.reality) tls.server_name = server; }
    if (tr) o.transport = tr;
    return { proto: proto, server: server, port: port, outbound: clean(o), needsXray: false, uri: "" };
}
// JSON sing-box: берём outbounds с адресом сервера
// sing-box JSON: take the outbounds that have a server address
function fromSingBox(j) {
    const skip = ["direct", "block", "dns", "selector", "urltest"];
    return (j.outbounds || []).filter(o => o.server && !skip.includes(o.type)).map(o => {
        const ob = Object.assign({}, o); const name = ob.tag || o.server; delete ob.tag; delete ob.detour;
        return { name: name, proto: o.type, server: o.server, port: o.server_port || 0, outbound: ob, needsXray: false, uri: "" };
    });
}

// YAML Clash/Mihomo: только раздел proxies (и «- {…}» в одну строку, и блоками с вложенными опциями)
// Clash/Mihomo YAML: only the proxies section (both one-line "- {…}" and blocks with nested options)
function yamlValue(v) {
    v = v.trim();
    if (/^".*"$/.test(v) || /^'.*'$/.test(v)) return v.slice(1, -1);
    if (v === "true") return true; if (v === "false") return false;
    if (/^-?\d+(\.\d+)?$/.test(v)) return parseFloat(v);
    if (v.startsWith("[") && v.endsWith("]")) return v.slice(1, -1).split(",").map(x => yamlValue(x)).filter(x => x !== "");
    if (v.startsWith("{") && v.endsWith("}")) return flowMap(v);
    return v;
}
function flowMap(v) {
    const o = {}; let depth = 0, cur = "", body = v.trim().slice(1, -1);
    const parts = [];
    for (const ch of body) { if (ch === "{" || ch === "[") depth++; if (ch === "}" || ch === "]") depth--;
                             if (ch === "," && depth === 0) { parts.push(cur); cur = ""; } else cur += ch; }
    if (cur.trim()) parts.push(cur);
    for (const p of parts) { const i = p.indexOf(":"); if (i > 0) o[p.slice(0, i).trim().replace(/^["']|["']$/g, "")] = yamlValue(p.slice(i + 1)); }
    return o;
}
function fromClash(text) {
    const L = text.split(/\r?\n/), out = [];
    let i = L.findIndex(l => /^\s*proxies\s*:/.test(l)); if (i < 0) return [];
    const base = L[i].search(/\S/);
    let cur = null, stack = [];
    for (i = i + 1; i < L.length; i++) {
        const l = L[i]; if (!l.trim() || l.trim().startsWith("#")) continue;
        const ind = l.search(/\S/);
        if (ind <= base && !l.trim().startsWith("-")) break;               // следующий раздел / the next section
        const t = l.trim();
        if (t.startsWith("- ")) {
            if (cur) out.push(cur);
            const rest = t.slice(2).trim();
            if (rest.startsWith("{")) { cur = flowMap(rest); stack = []; continue; }
            cur = {}; stack = [{ ind: ind + 2, obj: cur }];
            const k = rest.indexOf(":"); if (k > 0) { const key = rest.slice(0, k).trim(), val = rest.slice(k + 1);
                if (val.trim()) cur[key] = yamlValue(val); else { cur[key] = {}; stack.push({ ind: ind + 4, obj: cur[key] }); } }
            continue;
        }
        if (!cur) continue;
        while (stack.length > 1 && ind < stack[stack.length - 1].ind) stack.pop();
        const k = t.indexOf(":"); if (k <= 0) continue;
        const key = t.slice(0, k).trim().replace(/^["']|["']$/g, ""), val = t.slice(k + 1);
        const target = stack[stack.length - 1].obj;
        if (val.trim()) target[key] = yamlValue(val); else { target[key] = {}; stack.push({ ind: ind + 2, obj: target[key] }); }
    }
    if (cur) out.push(cur);
    return out.map(clashNode).filter(n => n);
}
function clashNode(c) {
    const type = String(c.type || "").toLowerCase(), server = c.server, port = parseInt(c.port || 0);
    if (!server || !port) return null;
    const tlsOn = c.tls === true || type === "trojan" || type === "hysteria2" || type === "tuic" || !!c["reality-opts"];
    const t = tlsOn ? { enabled: true, server_name: c.servername || c.sni || server, insecure: !!c["skip-cert-verify"] } : undefined;
    if (t && c.alpn) t.alpn = Array.isArray(c.alpn) ? c.alpn : [c.alpn];
    if (t && c["client-fingerprint"]) t.utls = { enabled: true, fingerprint: c["client-fingerprint"] };
    if (t && c["reality-opts"]) { t.reality = { enabled: true, public_key: c["reality-opts"]["public-key"] || "", short_id: c["reality-opts"]["short-id"] || "" };
                                  if (!t.utls) t.utls = { enabled: true, fingerprint: "chrome" }; }
    let tr;
    if (c.network === "ws") { const w = c["ws-opts"] || {}; tr = { type: "ws", path: w.path || "/", headers: w.headers || undefined }; }
    else if (c.network === "grpc") tr = { type: "grpc", service_name: (c["grpc-opts"] || {})["grpc-service-name"] || "" };
    else if (c.network === "h2" || c.network === "http") { const h = c["h2-opts"] || c["http-opts"] || {}; tr = { type: "http", path: [].concat(h.path || "/")[0], host: h.host ? [].concat(h.host) : undefined }; }
    let ob = null;
    if (type === "ss") ob = { type: "shadowsocks", server: server, server_port: port, method: c.cipher, password: String(c.password) };
    else if (type === "vmess") ob = { type: "vmess", server: server, server_port: port, uuid: c.uuid, alter_id: parseInt(c.alterId || 0), security: c.cipher || "auto", tls: t, transport: tr };
    else if (type === "vless") ob = { type: "vless", server: server, server_port: port, uuid: c.uuid, flow: c.flow || undefined, tls: t, transport: tr, packet_encoding: "xudp" };
    else if (type === "trojan") ob = { type: "trojan", server: server, server_port: port, password: String(c.password), tls: t, transport: tr };
    else if (type === "hysteria2") { ob = { type: "hysteria2", server: server, server_port: port, password: String(c.password || c.auth || ""), tls: t };
                                     if (c.obfs) ob.obfs = { type: c.obfs, password: c["obfs-password"] || "" }; }
    else if (type === "tuic") ob = { type: "tuic", server: server, server_port: port, uuid: c.uuid, password: String(c.password || ""),
                                     congestion_control: c["congestion-controller"] || "bbr", tls: t };
    else return null;
    return { name: c.name || server, proto: type === "ss" ? "ss" : type, server: server, port: port, outbound: clean(ob), needsXray: false, uri: "" };
}
// заголовок subscription-userinfo: upload=…; download=…; total=…; expire=…
// subscription-userinfo header: upload=…; download=…; total=…; expire=…
function parseUserinfo(h) {
    const o = {};
    String(h || "").split(";").forEach(kv => { const m = kv.trim().match(/^(\w+)=(\d+)/); if (m) o[m[1]] = parseInt(m[2]); });
    return o;
}
// заголовки ответа (curl -D) → объект с именами в нижнем регистре
// response headers (curl -D) → an object with lower-case names
function parseHeaders(raw) {
    const o = {};
    String(raw || "").split(/\r?\n/).forEach(l => { const i = l.indexOf(":"); if (i > 0) o[l.slice(0, i).trim().toLowerCase()] = l.slice(i + 1).trim(); });
    return o;
}
function profileTitle(h) {
    const t = h["profile-title"] || "";
    return t.startsWith("base64:") ? b64(t.slice(7)) : t;
}

// адрес DNS → сервер sing-box 1.12: tls://1.1.1.1, https://dns.google/dns-query, udp://77.88.8.8, tcp://…, local
// DNS address → a sing-box 1.12 server: tls://1.1.1.1, https://dns.google/dns-query, udp://77.88.8.8, tcp://…, local
function dnsServer(tag, addr, detour) {
    addr = String(addr || "local").trim();
    let o;
    if (addr === "local" || addr === "") o = { type: "local" };
    else {
        const m = addr.match(/^(tls|https|udp|tcp|quic|h3):\/\/([^/:]+)(?::(\d+))?(\/.*)?$/);
        if (m) { o = { type: m[1], server: m[2] }; if (m[3]) o.server_port = parseInt(m[3]); if (m[4] && m[1] === "https") o.path = m[4]; }
        else o = { type: "udp", server: addr };
    }
    o.tag = tag;
    if (detour && o.type !== "local") o.detour = detour;
    return o;
}
const GEOSITE = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-";
const GEOIP = "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-";
function lines(t) { return String(t || "").split(/[\n,]+/).map(x => x.trim()).filter(x => x && !x.startsWith("#")); }
// одно наше правило → наборы условий sing-box. Домены, адреса и процессы — отдельными правилами:
// в одном правиле sing-box разные виды условий складываются через «И», а нам нужно «или»
// (как в Exclave: «эти сайты или эти приложения»). Наборы geosite:/geoip: собираются в sets
// one of our rules → sets of sing-box conditions. Domains, addresses and processes are separate rules:
// within one sing-box rule different kinds of conditions are ANDed, and we need OR
// (as in Exclave: "these sites or these apps"). geosite:/geoip: sets are collected into sets
function ruleMatches(r, sets) {
    const dom = {}, ip = {}, proc = {}, path = {};
    const add = (m, k, v) => { (m[k] = m[k] || []).push(v); };
    for (const d of lines(r.domains)) {
        if (d.startsWith("geosite:")) { const n = d.slice(8); sets["geosite-" + n] = GEOSITE + n + ".srs"; add(dom, "rule_set", "geosite-" + n); }
        else if (d.startsWith("full:") || d.startsWith("domain:")) add(dom, "domain", d.slice(d.indexOf(":") + 1));
        else if (d.startsWith("keyword:")) add(dom, "domain_keyword", d.slice(8));
        else if (d.startsWith("regexp:")) add(dom, "domain_regex", d.slice(7));
        else add(dom, "domain_suffix", d.replace(/^\*\./, ""));
    }
    for (const a of lines(r.ips)) {
        if (a.startsWith("geoip:")) { const n = a.slice(6); sets["geoip-" + n] = GEOIP + n + ".srs"; add(ip, "rule_set", "geoip-" + n); }
        else add(ip, "ip_cidr", a.includes("/") ? a : a + (a.includes(":") ? "/128" : "/32"));
    }
    for (const p of lines(r.processes)) p.includes("/") ? add(path, "process_path", p) : add(proc, "process_name", p);
    return [dom, ip, proc, path].filter(m => Object.keys(m).length);
}

// конфиг sing-box. opts: { tun, port, xrayPort, rules: [наши правила], o: {настройки} }
// sing-box config. opts: { tun, port, xrayPort, rules: [our rules], o: {settings} }
function buildConfig(node, opts) {
    const o = Object.assign({ remoteDns: "tcp://1.1.1.1", directDns: "local", strategy: "prefer_ipv4", fakeDns: false,
                              fragment: false, ipv6: true, bypassLan: true, mtu: 9000, stack: "mixed", mode: "rule" }, opts.o || {});
    // цепочка: трафик идёт через первый узел, потом через второй… (у каждого следующего detour = предыдущий)
    // chain: traffic goes through the first node, then the second… (each next one has detour = the previous)
    let extra = [];
    let proxy;
    if (node.proto === "chain") {
        const hops = node.hops || [];
        extra = hops.slice(0, -1).map((h, i) => Object.assign({}, h, { tag: "hop" + i }, i ? { detour: "hop" + (i - 1) } : {}));
        const last = hops[hops.length - 1] || {};
        proxy = Object.assign({}, last, { tag: "proxy" }, hops.length > 1 ? { detour: "hop" + (hops.length - 2) } : {});
    } else proxy = node.needsXray
        ? { type: "socks", tag: "proxy", server: "127.0.0.1", server_port: opts.xrayPort || 10808 }
        : Object.assign({ tag: "proxy" }, node.outbound);

    const inbounds = [{ type: "mixed", tag: "mixed-in", listen: "127.0.0.1", listen_port: opts.port || 2080 }];
    if (opts.tun) inbounds.push({ type: "tun", tag: "tun-in", interface_name: "nyash-tun",
                                  address: o.ipv6 ? ["172.19.0.1/30", "fdfe:dcba:9876::1/126"] : ["172.19.0.1/30"],
                                  mtu: o.mtu, auto_route: true, strict_route: true, stack: o.stack });

    // маршруты: сначала служебное, потом твои правила сверху вниз, в конце — режим
    // сам Xray (через него идут узлы, которые sing-box не умеет) должен ходить к серверу НАПРЯМУЮ — и его
    // DNS-запросы тоже. Иначе в режиме TUN: Xray спрашивает адрес сервера → запрос перехватывает sing-box →
    // отправляет через прокси → а прокси — это сам Xray, которому адрес ещё неизвестен. Петля без ошибок в журнале.
    // Поэтому правило для xray — самое первое, раньше перехвата DNS
    // правило по имени процесса включает в sing-box поиск процесса для КАЖДОГО соединения (обход /proc) —
    // это заметно ест процессор, поэтому добавляем его, только когда Xray правда работает
    // routes: housekeeping first, then your rules top to bottom, the mode at the end
    // Xray itself (nodes sing-box can't do go through it) must reach the server DIRECTLY, and so must its
    // DNS queries. Otherwise in TUN mode: Xray asks for the server's address → sing-box intercepts the query →
    // sends it through the proxy → and the proxy is Xray itself, which doesn't know the address yet. A loop with no errors in the log.
    // So the xray rule comes first, before DNS hijacking
    // a process-name rule makes sing-box look up the process for EVERY connection (walking /proc),
    // which eats noticeable CPU, so it's only added when Xray is actually in use
    const sets = {}, rules = (node.needsXray ? [{ process_name: ["xray"], outbound: "direct" }] : [])
                              .concat([{ action: "sniff" }, { protocol: "dns", action: "hijack-dns" }]);
    if (o.fragment) rules.push({ action: "route-options", tls_fragment: true });
    if (o.bypassLan) rules.push({ ip_is_private: true, outbound: "direct" });
    const dnsRules = [];
    if (o.mode === "rule") {
        for (const r of (opts.rules || [])) {
            if (!r.on) continue;
            for (const m of ruleMatches(r, sets)) {
                if (r.outbound === "block") rules.push(Object.assign({}, m, { action: "reject" }));
                else rules.push(Object.assign({}, m, { outbound: r.outbound === "direct" ? "direct" : "proxy" }));
                // домены «обхода» резолвим прямым DNS
                // "bypass" domains are resolved with the direct DNS
                const isDomain = m.domain || m.domain_suffix || m.domain_keyword || m.domain_regex || (m.rule_set || []).some(x => x.startsWith("geosite-"));
                if (r.outbound === "direct" && isDomain) dnsRules.push(Object.assign({}, m, { server: "direct" }));
            }
        }
    }
    const dnsServers = [dnsServer("remote", o.remoteDns, "proxy"), dnsServer("direct", o.directDns, "")];
    if (o.directDns !== "local") dnsServers.push({ tag: "local", type: "local" });
    if (o.fakeDns && opts.tun) {
        dnsServers.push({ tag: "fakeip", type: "fakeip", inet4_range: "198.18.0.0/15", inet6_range: "fc00::/18" });
        dnsRules.push({ query_type: ["A", "AAAA"], server: "fakeip" });
    }
    const cfg = {
        log: { level: o.logLevel || "warn", timestamp: true },
        dns: { servers: dnsServers, rules: dnsRules, final: o.mode === "direct" ? "direct" : "remote", strategy: o.strategy },
        inbounds: inbounds,
        outbounds: [proxy].concat(extra, [{ type: "direct", tag: "direct" }]),
        route: {
            rules: rules,
            rule_set: Object.keys(sets).map(t => ({ tag: t, type: "remote", format: "binary", url: sets[t], download_detour: "direct" })),
            final: o.mode === "direct" ? "direct" : "proxy",
            auto_detect_interface: true,
            default_domain_resolver: o.directDns === "local" ? "direct" : "local"
        },
        experimental: { clash_api: { external_controller: "127.0.0.1:9090" }, cache_file: { enabled: true, store_fakeip: !!o.fakeDns } }
    };
    if (!cfg.route.rule_set.length) delete cfg.route.rule_set;
    return cfg;
}

// конфиг для проверки пинга: все узлы группы — отдельными выходами, без входов и TUN;
// задержку меряем настоящим запросом через каждый узел (API sing-box /proxies/<tag>/delay)
// ping-check config: every node of the group as a separate outbound, no inbounds or TUN;
// latency is measured with a real request through each node (sing-box API /proxies/<tag>/delay)
function buildTestConfig(nodes, apiPort) {
    const obs = [];
    nodes.forEach((n, i) => {
        if (n.needsXray || n.proto === "chain") return;
        obs.push(Object.assign({}, n.outbound, { tag: "n" + i }));
    });
    obs.push({ type: "direct", tag: "direct" });
    return {
        log: { level: "error" },
        dns: { servers: [{ tag: "local", type: "local" }] },
        outbounds: obs,
        route: { final: "direct", default_domain_resolver: "local" },
        experimental: { clash_api: { external_controller: "127.0.0.1:" + (apiPort || 9091) } }
    };
}

// конфиг Xray для узлов, которые sing-box не умеет (XHTTP, готовые Xray-выходы из JSON-подписок):
// локальный socks на port → узел
// уровень журнала Xray по уровню sing-box из настроек
// Xray config for nodes sing-box can't do (XHTTP, ready-made Xray outbounds from JSON subscriptions):
// a local socks on port → the node
// Xray log level follows the sing-box level from the settings
function xrayLevel(l) { return ({ trace: "debug", debug: "debug", info: "info", warn: "warning", error: "error" })[l] || "warning"; }
function buildXrayConfig(node, port, level) {
    const inb = [{ listen: "127.0.0.1", port: port || 10808, protocol: "socks", settings: { udp: true } }];
    if (node.xray) return clean({ log: { loglevel: xrayLevel(level), access: level === "trace" || level === "debug" ? "" : "none" }, inbounds: inb, outbounds: [Object.assign({}, node.xray, { tag: "out" })] });
    const p = split(node.uri); if (!p) return null;
    const q = p.q, isVless = p.scheme === "vless";
    const stream = { network: (q.type === "splithttp" ? "xhttp" : (q.type || "tcp")), security: q.security || "none" };
    if (stream.network === "xhttp") stream.xhttpSettings = { path: q.path || "/", host: q.host || "", mode: q.mode || "auto" };
    if (stream.network === "ws") stream.wsSettings = { path: q.path || "/", headers: q.host ? { Host: q.host } : undefined };
    if (stream.network === "grpc") stream.grpcSettings = { serviceName: q.serviceName || "" };
    if (stream.security === "tls") stream.tlsSettings = { serverName: q.sni || p.host, fingerprint: q.fp || "chrome", alpn: q.alpn ? q.alpn.split(",") : undefined };
    if (stream.security === "reality") stream.realitySettings = { serverName: q.sni || "", fingerprint: q.fp || "chrome", publicKey: q.pbk || "", shortId: q.sid || "", spiderX: q.spx || "" };
    const ob = isVless
        ? { protocol: "vless", settings: { vnext: [{ address: p.host, port: p.port, users: [{ id: p.user, encryption: q.encryption || "none", flow: q.flow || "" }] }] } }
        : { protocol: "trojan", settings: { servers: [{ address: p.host, port: p.port, password: p.user }] } };
    ob.streamSettings = stream; ob.tag = "out";
    return clean({ log: { loglevel: xrayLevel(level), access: level === "trace" || level === "debug" ? "" : "none" }, inbounds: inb, outbounds: [ob] });
}
