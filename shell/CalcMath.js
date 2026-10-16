.pragma library
// маленький безопасный парсер выражений: без eval, только разобранные токены
// a small safe expression parser: no eval, only parsed tokens
function tokenize(src) {
    const s = src.replace(/,/g, ".").replace(/\*\*/g, "^");
    const t = []; let i = 0;
    const two = ["==", "!=", "<=", ">="];
    const map = { "≠": "!=", "≤": "<=", "≥": ">=", "−": "-", "×": "*", "·": "*", "÷": "/", "π": "pi", "√": "sqrt" };
    while (i < s.length) {
        const c = s[i];
        if (/\s/.test(c)) { i++; continue; }
        if (/[0-9.]/.test(c)) {
            let j = i; while (j < s.length && /[0-9.]/.test(s[j])) j++;
            const n = parseFloat(s.slice(i, j)); if (isNaN(n)) throw "число";
            t.push({ k: "num", v: n }); i = j; continue;
        }
        if (/[a-zA-Zа-яА-ЯёЁ_]/.test(c)) {
            let j = i; while (j < s.length && /[a-zA-Zа-яА-ЯёЁ_]/.test(s[j])) j++;
            t.push({ k: "id", v: s.slice(i, j).toLowerCase() }); i = j; continue;
        }
        const d = s.slice(i, i + 2);
        if (two.includes(d)) { t.push({ k: "op", v: d }); i += 2; continue; }
        if (map[c]) { const m = map[c]; t.push(m === "pi" || m === "sqrt" ? { k: "id", v: m } : { k: "op", v: m }); i++; continue; }
        if ("+-*/%^!()<>=".includes(c)) { t.push({ k: "op", v: c }); i++; continue; }
        throw "символ " + c;
    }
    return t;
}

const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    ln: Math.log, log: Math.log10, exp: Math.exp,
    // тригонометрия в градусах — для быстрых прикидок это привычнее
    // trigonometry in degrees: more familiar for quick estimates
    sin: x => Math.sin(x * Math.PI / 180), cos: x => Math.cos(x * Math.PI / 180), tan: x => Math.tan(x * Math.PI / 180),
    asin: x => Math.asin(x) * 180 / Math.PI, acos: x => Math.acos(x) * 180 / Math.PI, atan: x => Math.atan(x) * 180 / Math.PI
};
const CONSTS = { pi: Math.PI, e: Math.E };

function fact(n) {
    if (n < 0 || n !== Math.floor(n) || n > 170) throw "факториал";
    let r = 1; for (let i = 2; i <= n; i++) r *= i; return r;
}

// разбор в дерево: возвращает функцию vars -> значение
// parse into a tree: returns a function vars -> value
function parse(tokens) {
    let p = 0;
    const peek = () => tokens[p], next = () => tokens[p++];
    const isOp = (v) => peek() && peek().k === "op" && peek().v === v;
    const startsOperand = (tk) => tk && (tk.k === "num" || tk.k === "id" || (tk.k === "op" && tk.v === "("));
    const vars = new Set();

    function cmp() {
        const a = add();
        const tk = peek();
        if (tk && tk.k === "op" && ["==", "!=", "<=", ">=", "<", ">", "="].includes(tk.v)) {
            next();
            const b = add();
            const op = tk.v;
            return { f: (e) => { const x = a.f(e), y = b.f(e);
                        return op === "!=" ? x !== y : op === "<=" ? x <= y : op === ">=" ? x >= y
                             : op === "<" ? x < y : op === ">" ? x > y : Math.abs(x - y) < 1e-9; },
                     cmp: op, lhs: a, rhs: b };
        }
        return a;
    }
    function add() {
        let a = mul();
        while (isOp("+") || isOp("-")) {
            const op = next().v, b = mul(), left = a;
            // «50 + 10%» = 55: процент от левой части
            // "50 + 10%" = 55: a percentage of the left side
            if (b.pct) a = { f: (e) => { const x = left.f(e); return op === "+" ? x + x * b.raw(e) / 100 : x - x * b.raw(e) / 100; } };
            else a = { f: (e) => op === "+" ? left.f(e) + b.f(e) : left.f(e) - b.f(e) };
        }
        return a;
    }
    function mul() {
        let a = unary();
        for (;;) {
            if (isOp("*") || isOp("/")) {
                const op = next().v, b = unary(), left = a;
                a = { f: (e) => op === "*" ? left.f(e) * b.f(e) : left.f(e) / b.f(e) };
            } else if (isOp("%") && startsOperand(tokens[p + 1])) {
                // «10%100» = 10: процент от числа
                // "10%100" = 10: a percentage of a number
                next(); const b = unary(), left = a;
                a = { f: (e) => left.f(e) * b.f(e) / 100 };
            } else if (startsOperand(peek()) && !(peek().k === "op")) {
                // неявное умножение: 2x, 3pi, 2sqrt(4)
                // implicit multiplication: 2x, 3pi, 2sqrt(4)
                const b = unary(), left = a;
                a = { f: (e) => left.f(e) * b.f(e) };
            } else if (isOp("(")) {
                const b = unary(), left = a;
                a = { f: (e) => left.f(e) * b.f(e) };
            } else return a;
        }
    }
    function unary() {
        if (isOp("-")) { next(); const a = unary(); return { f: (e) => -a.f(e), pct: a.pct, raw: a.raw ? (e) => -a.raw(e) : undefined }; }
        if (isOp("+")) { next(); return unary(); }
        return power();
    }
    function power() {
        const a = postfix();
        if (isOp("^")) { next(); const b = unary(); return { f: (e) => Math.pow(a.f(e), b.f(e)) }; }
        return a;
    }
    function postfix() {
        let a = primary();
        for (;;) {
            if (isOp("!") && !(tokens[p + 1] && tokens[p + 1].k === "op" && tokens[p + 1].v === "=")) {
                next(); const b = a; a = { f: (e) => fact(b.f(e)) };
            } else if (isOp("%") && !startsOperand(tokens[p + 1])) {
                // одиночный «15%» = 0.15, а в сложении — процент от левой части
                // a lone "15%" = 0.15, but in addition it is a percentage of the left side
                next(); const b = a; a = { f: (e) => b.f(e) / 100, pct: true, raw: (e) => b.f(e) };
            } else return a;
        }
    }
    function primary() {
        const tk = next();
        if (!tk) throw "конец";
        if (tk.k === "num") return { f: () => tk.v };
        if (tk.k === "op" && tk.v === "(") {
            const a = cmp();
            if (!isOp(")")) throw "скобка"; next();
            return { f: a.f };
        }
        if (tk.k === "id") {
            if (FUNCS[tk.v] !== undefined) {
                let arg;
                if (isOp("(")) { next(); arg = cmp(); if (!isOp(")")) throw "скобка"; next(); }
                else arg = power();
                const fn = FUNCS[tk.v];
                return { f: (e) => fn(arg.f(e)) };
            }
            if (CONSTS[tk.v] !== undefined) return { f: () => CONSTS[tk.v] };
            if (tk.v.length === 1) { vars.add(tk.v); return { f: (e) => { if (e[tk.v] === undefined) throw "переменная"; return e[tk.v]; } }; }
            throw "неизвестно: " + tk.v;
        }
        throw "лишний " + tk.v;
    }

    const root = cmp();
    if (p < tokens.length) throw "лишнее";
    root.vars = vars;
    return root;
}

function fmt(v) {
    if (typeof v === "boolean") return v ? "верно" : "неверно";
    if (!isFinite(v)) throw "не число";
    const r = Math.round(v * 1e10) / 1e10;
    return String(Math.abs(r) < 1e-12 ? 0 : r);
}

// корни уравнения f(x)=0: сначала как линейное, потом поиск смен знака + уточнение
// roots of f(x)=0: first as a linear equation, then sign-change search + refinement
function solve(f) {
    const f0 = f(0), f1 = f(1), f2 = f(2);
    if (isFinite(f0) && isFinite(f1) && Math.abs((f2 - f1) - (f1 - f0)) < 1e-9) {
        if (Math.abs(f1 - f0) < 1e-12) return Math.abs(f0) < 1e-9 ? "any" : [];
        return [-f0 / (f1 - f0)];
    }
    const roots = [];
    let px = -1000, pv = f(px);
    for (let x = -1000 + 0.5; x <= 1000; x += 0.5) {
        const v = f(x);
        if (isFinite(pv) && isFinite(v) && (pv === 0 || pv * v < 0)) {
            let lo = px, hi = x;
            for (let k = 0; k < 80; k++) { const m = (lo + hi) / 2; if (f(lo) * f(m) <= 0) hi = m; else lo = m; }
            const r = (lo + hi) / 2;
            if (Math.abs(f(r)) < 1e-6 && !roots.some(q => Math.abs(q - r) < 1e-6)) roots.push(r);
            if (roots.length >= 4) break;
        }
        px = x; pv = v;
    }
    return roots;
}

// главный вход: строка -> { text, kind } или null
// main entry: string -> { text, kind } or null
function calculate(src) {
    if (!src.trim()) return null;
    const tree = parse(tokenize(src));
    const vars = Array.from(tree.vars);
    if (vars.length > 1) throw "больше одной переменной";
    if (vars.length === 1) {
        const x = vars[0];
        if (tree.cmp !== "=" && tree.cmp !== "==") throw "для уравнения нужен знак =";
        const r = solve((v) => { const e = {}; e[x] = v; return tree.lhs.f(e) - tree.rhs.f(e); });
        if (r === "any") return { text: x + " — любое", kind: "eq" };
        if (!r.length) return { text: "корней нет", kind: "eq" };
        return { text: r.map(v => x + " = " + fmt(v)).join(",  "), kind: "eq" };
    }
    const v = tree.f({});
    return { text: fmt(v), kind: typeof v === "boolean" ? "bool" : "num" };
}
