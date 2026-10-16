pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// MPD — фоновый музыкальный проигрыватель без окна. Управление и очередь — через mpc.
// изменения ловим через «mpc idleloop», так что опроса раз в секунду нет (кроме прогресса, пока играет)
// MPD: a background music player with no window. Controls and queue go through mpc.
// changes are caught via "mpc idleloop", so there's no once-a-second polling (except progress while playing)
Singleton {
    id: mpd
    property bool alive: false
    property string state: "stop"            // play | pause | stop
    property int pos: -1                     // номер текущего трека в очереди (с 0) / current track's number in the queue (from 0)
    property real elapsed: 0
    property real duration: 0
    property bool random: false
    property string repeatMode: "off"        // off | all | one
    property var cur: ({})                   // {title, artist, album, file}
    property var queue: []                   // [{pos, title, artist, time, file}]
    property var found: []                   // результаты поиска по библиотеке / library search results
    property string art: ""                  // обложка текущего трека (file://…) / current track's cover (file://…)
    readonly property bool playing: state === "play"

    function mpc(args): void { Quickshell.execDetached(["mpc", "-q"].concat(args)); }
    function toggle(): void { mpc(["toggle"]); }
    // ручное переключение — с плавным переходом громкости (если кроссфейд включён)
    // manual skipping with a smooth volume transition (if crossfade is on)
    readonly property int crossfade: ShellState.settings.crossfade ?? 3
    function skip(args): void {
        if (crossfade > 0) Quickshell.execDetached(["sh", Quickshell.shellPath("mpd-skip.sh")].concat(args));
        else mpc(args);
    }
    function next(): void { skip(["next"]); }
    function prev(): void { skip(["prev"]); }
    function play(i: int): void { skip(["play", String(i + 1)]); }
    function seekRel(sec: real): void {
        const s = Math.round(sec);
        if (!s) return;
        elapsed = Math.max(0, Math.min(duration, elapsed + s));
        mpc(["seek", (s > 0 ? "+" : "-") + Math.abs(s)]);
    }
    // кроссфейд в конце трека делает сам MPD
    // MPD does the crossfade at the end of a track itself
    onCrossfadeChanged: mpc(["crossfade", String(crossfade)])
    function seek(frac: real): void { mpc(["seek", Math.round(frac * 100) + "%"]); }
    // перемешивание — режим (см. mpd-shuffle.sh): включаешь — очередь переставляется по-настоящему (её и видно
    // в списке), текущий трек первым; выключаешь — возвращается прежний порядок, музыка не прерывается.
    // Пока режим включён, новая очередь (папка, плейлист, вся библиотека) тоже перемешивается
    // shuffle is a mode (see mpd-shuffle.sh): turn it on and the queue is really reordered (that's what the
    // list shows), current track first; turn it off and the old order returns without interrupting the music.
    // While the mode is on, a new queue (folder, playlist, whole library) gets shuffled too
    readonly property bool shuffleOn: ShellState.settings.mpdShuffle ?? false
    readonly property string shuffleSh: Quickshell.shellPath("mpd-shuffle.sh")
    function toggleRandom(): void {
        const on = !shuffleOn;
        ShellState.set("mpdShuffle", on);
        Quickshell.execDetached(["sh", shuffleSh, on ? "on" : "off"]);
        shuffledAt = Date.now();
    }
    property real shuffledAt: 0
    // повтор по кругу: выкл → весь список → один трек → выкл
    // repeat cycles: off → whole list → one track → off
    function cycleRepeat(): void {
        if (repeatMode === "off") mpc(["repeat", "on"]);
        else if (repeatMode === "all") mpc(["single", "on"]);
        else { mpc(["repeat", "off"]); mpc(["single", "off"]); }
    }
    function move(from: int, to: int): void { if (from !== to) mpc(["move", String(from + 1), String(to + 1)]); }
    // «воспроизвести далее» — сразу после текущего
    // "play next": right after the current one
    function playNext(i: int): void {
        const to = pos < 0 ? 0 : (i > pos ? pos + 1 : pos);
        move(i, to);
    }

    // удаление с возможностью отмены (Ctrl+ПКМ в течение 3 с)
    // removal that can be undone (Ctrl+right-click within 3 s)
    property var undo: null                  // {file, pos}
    function remove(i: int): void {
        const t = queue[i];
        if (!t) return;
        undo = { file: t.file, pos: i };
        undoTimer.restart();
        mpc(["del", String(i + 1)]);
    }
    function undoRemove(): void {
        if (!undo) return;
        const u = undo; undo = null; undoTimer.stop();
        Quickshell.execDetached(["sh", "-c", 'mpc -q add "$1" && n=$(mpc playlist | wc -l) && mpc -q move "$n" "$2"', "sh", u.file, String(u.pos + 1)]);
    }
    Timer { id: undoTimer; interval: 3000; onTriggered: mpd.undo = null }

    // библиотека: поиск и добавление
    // library: search and adding
    function search(q: string): void {
        if (!q.trim()) { found = []; return; }
        searchProc.command = ["mpc", "search", "-f", "%title%\\t%artist%\\t%time%\\t%file%", "any", q.trim()];
        searchProc.running = true;
    }
    function add(file: string, next: bool): void {
        if (next && pos >= 0) Quickshell.execDetached(["sh", "-c", 'mpc -q insert "$1"', "sh", file]);
        else mpc(["add", file]);
    }
    function addAll(): void { Quickshell.execDetached(["sh", "-c", 'mpc -q update --wait; mpc -q clear; mpc -q add /; mpc -q play; sh "$1" ifon', "sh", shuffleSh]); }

    // ─── чтение состояния ───
    // ─── reading the state ───
    function refresh(): void { statusProc.running = true; queueProc.running = true; }
    Process {
        id: statusProc
        command: ["mpc", "-f", "%title%\t%artist%\t%album%\t%file%", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const L = text.split("\n");
                mpd.alive = text.length > 0;
                // формат mpc по умолчанию: [строка трека], [playing] #3/10 1:23/3:45 (35%), volume:… repeat: on random: off single: off
                // mpc's default format: [track line], [playing] #3/10 1:23/3:45 (35%), volume:… repeat: on random: off single: off
                const opt = L.find(l => l.includes("repeat:")) ?? "";
                mpd.random = /random: on/.test(opt);
                const rep = /repeat: on/.test(opt), single = /single: on/.test(opt);
                mpd.repeatMode = !rep ? "off" : single ? "one" : "all";
                const st = L.find(l => /^\[(playing|paused)\]/.test(l));
                if (st) {
                    mpd.state = st.startsWith("[playing]") ? "play" : "pause";
                    const m = st.match(/#(\d+)\/\d+\s+(\d+):(\d+)\/(\d+):(\d+)/);
                    if (m) { mpd.pos = parseInt(m[1]) - 1; mpd.elapsed = parseInt(m[2]) * 60 + parseInt(m[3]); mpd.duration = parseInt(m[4]) * 60 + parseInt(m[5]); }
                    const f = (L[0] || "").split("\t");
                    mpd.cur = { title: f[0] || (f[3] || "").split("/").pop(), artist: f[1] || "", album: f[2] || "", file: f[3] || "" };
                } else {
                    mpd.state = "stop"; mpd.pos = -1; mpd.elapsed = 0; mpd.duration = 0; mpd.cur = {};
                }
                artProc.running = true;
            }
        }
        onExited: (code) => { if (code !== 0) mpd.alive = false; }
    }
    Process {
        id: queueProc
        command: ["mpc", "playlist", "-f", "%position%\\t%title%\\t%artist%\\t%time%\\t%file%"]
        stdout: StdioCollector {
            onStreamFinished: mpd.queue = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t");
                return { pos: parseInt(f[0]) - 1, title: f[1] || (f[4] || "").split("/").pop(), artist: f[2] || "", time: f[3] || "", file: f[4] || "" };
            })
        }
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: mpd.found = text.split("\n").filter(l => l).slice(0, 60).map(l => {
                const f = l.split("\t");
                return { title: f[0] || (f[3] || "").split("/").pop(), artist: f[1] || "", time: f[2] || "", file: f[3] || "" };
            })
        }
    }
    // обложка: сначала встроенная в сам файл (ffmpeg достаёт её один раз и кладёт в кэш),
    // и только если её нет — картинка рядом с треком (cover.jpg, folder.jpg…)
    // cover: first the one embedded in the file itself (ffmpeg extracts it once into the cache),
    // and only if there is none, a picture next to the track (cover.jpg, folder.jpg…)
    Process {
        id: artProc
        command: ["sh", "-c",
            'm=$(awk -F\'"\' \'/^music_directory/{print $2; exit}\' "$HOME/.config/mpd/mpd.conf" 2>/dev/null); ' +
            'm=${m:-$(xdg-user-dir MUSIC)}; m=$(eval echo "$m"); f="$m/$1"; [ -n "$1" ] && [ -f "$f" ] || exit 0; ' +
            'c="$HOME/.cache/nyashell/covers"; mkdir -p "$c"; o="$c/$(printf %s "$1" | md5sum | cut -c1-20).jpg"; ' +
            '[ -s "$o" ] && { echo "$o"; exit 0; }; ' +
            'ffmpeg -v quiet -y -i "$f" -an -frames:v 1 -vf "scale=512:512:force_original_aspect_ratio=decrease" "$o" 2>/dev/null; ' +
            '[ -s "$o" ] && { echo "$o"; exit 0; }; rm -f "$o"; d=$(dirname "$f"); ' +
            'for x in cover.jpg cover.png folder.jpg folder.png Cover.jpg Folder.jpg front.jpg; do [ -f "$d/$x" ] && { echo "$d/$x"; exit 0; }; done',
            "sh", mpd.cur.file ?? ""]
        stdout: StdioCollector { onStreamFinished: mpd.art = text.trim() ? "file://" + text.trim() : "" }
    }
    // события mpd: любое изменение — перечитать
    // mpd events: any change means reread
    Process {
        id: idle
        running: true
        command: ["mpc", "idleloop", "player", "playlist", "options"]
        stdout: SplitParser { onRead: (line) => mpd.refresh() }
        onExited: again.restart()
    }
    Timer { id: again; interval: 3000; onTriggered: { mpd.refresh(); idle.running = true; } }
    // прогресс тикает сам, пока играет
    // progress ticks by itself while playing
    Timer { interval: 1000; repeat: true; running: mpd.playing; onTriggered: mpd.elapsed = Math.min(mpd.duration, mpd.elapsed + 1) }
    Component.onCompleted: { refresh(); mpc(["crossfade", String(crossfade)]); }

    // ─── библиотека и плейлисты (вкладка «Музыка») ───
    // ─── library and playlists (Music tab) ───
    readonly property string plDir: Quickshell.env("HOME") + "/.local/share/mpd/playlists"
    property string path: ""                 // открытая папка библиотеки (относительно папки музыки) / open library folder (relative to the music folder)
    property var entries: []                 // [{dir: bool, name, file}]
    property var playlists: []               // имена / names
    property string openList: ""             // открытый плейлист / open playlist
    property var listTracks: []              // его треки (пути) / its tracks (paths)
    // папка музыки из mpd.conf (или XDG_MUSIC_DIR) — кусок для sh-скриптов, кладёт путь в $m
    // the music folder from mpd.conf (or XDG_MUSIC_DIR): a snippet for sh scripts, puts the path into $m
    readonly property string musicDirSh: 'm=$(awk -F\'"\' \'/^music_directory/{print $2; exit}\' "$HOME/.config/mpd/mpd.conf" 2>/dev/null); ' +
                                          'm=${m:-$(xdg-user-dir MUSIC)}; m=$(eval echo "$m"); '
    // «mpc ls» в корне показывает и сохранённые плейлисты, а в папках — файлы .m3u/.cue, и по одному имени их
    // не отличить от папок. Поэтому смотрим на диск: папка — D, звуковой файл — F, остальное не показываем
    // "mpc ls" at the root also lists saved playlists, and inside folders .m3u/.cue files, and by name alone they
    // can't be told apart from folders. So we look at the disk: a folder is D, an audio file is F, the rest is hidden
    function browse(p: string): void {
        path = p;
        lsProc.command = ["sh", "-c", musicDirSh +
            'mpc ls "$1" 2>/dev/null | while IFS= read -r e; do ' +
            '  if [ -d "$m/$e" ]; then echo "D$e"; ' +
            '  elif printf %s "$e" | grep -qiE "\\.(mp3|flac|ogg|oga|opus|m4a|aac|wav|wma|alac|ape|mpc|wv|dsf|aiff?)$"; then echo "F$e"; ' +
            '  elif [ ! -d "$m" ] && ! printf %s "$e" | grep -qiE "\\.(m3u8?|pls|cue|xspf)$"; then echo "D$e"; fi; done',
            "sh", p || "/"];
        lsProc.running = true;
    }
    Process {
        id: lsProc
        stdout: StdioCollector {
            onStreamFinished: {
                mpd.entries = [...new Set(text.split("\n").filter(l => l.length > 1))].map(l => ({ dir: l[0] === "D", name: l.slice(1).split("/").pop(), file: l.slice(1) }))
                    .sort((a, b) => (b.dir - a.dir) || a.name.localeCompare(b.name));
            }
        }
    }
    // показать трек в файловом менеджере (выделенным), иначе просто открыть его папку
    // show the track in the file manager (selected), otherwise just open its folder
    function reveal(file: string): void {
        Quickshell.execDetached(["sh", "-c", musicDirSh + 'f="$m/$1"; ' +
            // путь в URI: пробелы, кавычки и кириллица — через %XX / the path as a URI: spaces, quotes and Cyrillic as %XX
            'u=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$f" 2>/dev/null) || u=$f; ' +
            'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 ' +
            '--method org.freedesktop.FileManager1.ShowItems "[\'file://$u\']" "" >/dev/null 2>&1 || xdg-open "$(dirname "$f")"', "sh", file]);
    }
    function addDir(p: string, next: bool): void {
        if (next && pos >= 0) Quickshell.execDetached(["sh", "-c", 'mpc -f "%file%" listall "$1" | tac | while read -r f; do mpc -q insert "$f"; done', "sh", p]);
        else mpc(["add", p]);
    }
    // играть трек вместе с его папкой: очередь становится этой папкой, начиная с выбранного трека
    // play a track along with its folder: the queue becomes that folder, starting from the chosen track
    function playInFolder(file: string): void {
        const dir = file.includes("/") ? file.slice(0, file.lastIndexOf("/")) : "/";
        Quickshell.execDetached(["sh", "-c",
            'mpc -q clear && mpc -q add "$1" && i=$(mpc -f "%file%" playlist | grep -nxF "$2" | cut -d: -f1 | head -1) && mpc -q play "${i:-1}"; sh "$3" ifon',
            "sh", dir, file, shuffleSh]);
    }
    // «воспроизвести отдельно» — только этот трек, в конец очереди
    // "play separately": only this track, at the end of the queue
    function playNow(file: string): void {
        Quickshell.execDetached(["sh", "-c", 'mpc -q add "$1" && mpc -q play "$(mpc playlist | wc -l)"', "sh", file]);
    }
    // плейлисты — обычные .m3u в папке MPD: их видит и MPD, и любой другой плеер
    // playlists are plain .m3u files in MPD's folder: MPD and any other player can see them
    function loadLists(): void { listsProc.running = true; coversProc.running = true; }
    // обложки и размеры плейлистов: своя картинка (имя.jpg/png рядом с .m3u), иначе — обложка первого трека
    // playlist covers and sizes: your own picture (name.jpg/png next to the .m3u), otherwise the first track's cover
    property var covers: ({})        // имя -> file://… / name -> file://…
    property var counts: ({})        // имя -> сколько треков / name -> number of tracks
    property var descs: ({})         // имя -> описание / name -> description
    Process {
        id: coversProc
        command: ["sh", "-c",
            'pl="$1"; m=$(awk -F\'"\' \'/^music_directory/{print $2; exit}\' "$HOME/.config/mpd/mpd.conf" 2>/dev/null); m=${m:-$(xdg-user-dir MUSIC)}; m=$(eval echo "$m"); ' +
            'c="$HOME/.cache/nyashell/covers"; mkdir -p "$c"; ' +
            'for f in "$pl"/*.m3u; do [ -f "$f" ] || continue; n=$(basename "$f" .m3u); cnt=$(grep -vc "^#" "$f"); img=""; ' +
            '  ds=$(sed -n "s/^#DESCRIPTION://p" "$f" | head -1 | tr "\\t" " "); ' +
            '  for e in jpg png jpeg webp; do [ -f "$pl/$n.$e" ] && img="$pl/$n.$e" && break; done; ' +
            '  if [ -z "$img" ]; then t=$(grep -v "^#" "$f" | head -1); if [ -n "$t" ]; then o="$c/$(printf %s "$t" | md5sum | cut -c1-20).jpg"; ' +
            '    [ -s "$o" ] || ffmpeg -v quiet -y -i "$m/$t" -an -frames:v 1 -vf "scale=512:512:force_original_aspect_ratio=decrease" "$o" 2>/dev/null; [ -s "$o" ] && img="$o"; fi; fi; ' +
            '  printf "%s\\t%s\\t%s\\t%s\\n" "$n" "$cnt" "$img" "$ds"; done',
            "sh", mpd.plDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const cv = {}, ct = {}, ds = {};
                for (const l of text.split("\n")) {
                    const f = l.split("\t"); if (!f[0]) continue;
                    ct[f[0]] = parseInt(f[1]) || 0;
                    if (f[2]) cv[f[0]] = "file://" + f[2];
                    if (f[3]) ds[f[0]] = f[3].replace(/\\n/g, "\n");
                }
                mpd.covers = cv; mpd.counts = ct; mpd.descs = ds;
            }
        }
    }
    // выбор картинки для обложки (zenity или kdialog); путь приходит в cb, отмена — пустая строка
    // picking a cover picture (zenity or kdialog); the path comes to cb, cancelling gives an empty string
    property var pickCb: null
    readonly property bool picking: imgProc.running      // см. ShellState.fileDialog / see ShellState.fileDialog
    function pickImage(cb): void { pickCb = cb; imgProc.running = true; }
    Process {
        id: imgProc
        command: ["sh", "-c", 'zenity --file-selection --file-filter="*.jpg *.jpeg *.png *.webp" 2>/dev/null || kdialog --getopenfilename "$HOME" "*.jpg *.jpeg *.png *.webp" 2>/dev/null']
        stdout: StdioCollector { onStreamFinished: { const cb = mpd.pickCb; mpd.pickCb = null; if (cb) cb(text.trim()); } }
    }
    // описание — строка «#DESCRIPTION:…» в начале .m3u: MPD и другие плееры строки с # пропускают.
    // переносы строк хранятся как \n, табы — пробелами
    // the description is a "#DESCRIPTION:…" line at the top of the .m3u: MPD and other players skip # lines.
    // line breaks are stored as \n, tabs as spaces
    function descLine(d: string): string { return d.trim() ? "#DESCRIPTION:" + d.trim().replace(/\t/g, " ").replace(/\r?\n/g, "\\n") : ""; }
    // своя обложка — картинка копируется рядом с .m3u под именем плейлиста / your own cover: the picture is copied next to the .m3u under the playlist's name
    // (сначала во временный файл — вдруг выбрали ту же картинку, что уже лежит там) / (via a temp file first, in case the very same picture was chosen)
    readonly property string coverSh: '[ -n "$C" ] && cp "$C" "$P/.cover.tmp" && { rm -f "$P/$N".jpg "$P/$N".png "$P/$N".jpeg "$P/$N".webp; e="${C##*.}"; mv "$P/.cover.tmp" "$P/$N.$e"; }; '
    // новый плейлист: название, обложка, описание; треки — из текущей очереди и/или один трек (из окна «Добавить в плейлист»)
    // a new playlist: name, cover, description; tracks from the current queue and/or one track (from the "Add to playlist" window)
    // аргументы скриптам — через окружение (env), так их проще читать / script arguments go through the environment (env), easier to read
    function createList(name: string, cover: string, desc: string, fromQueue: bool, file: string): void {
        if (!name) return;
        Quickshell.execDetached(["env", "P=" + plDir, "N=" + name, "C=" + (cover || ""), "D=" + descLine(desc),
            "Q=" + (fromQueue ? "1" : ""), "T=" + (file || ""), "sh", "-c",
            'mkdir -p "$P" && { [ -n "$D" ] && printf "%s\\n" "$D"; [ -n "$Q" ] && mpc -f "%file%" playlist; ' +
            '[ -n "$T" ] && printf "%s\\n" "$T"; } > "$P/$N.m3u"; ' + coverSh]);
        listsLater.restart();
    }
    // изменить плейлист: новое название (файлы переименовываются), обложка (если выбрали новую) и описание
    // edit a playlist: a new name (the files get renamed), the cover (if a new one was picked) and the description
    function editList(from: string, name: string, cover: string, desc: string): void {
        if (!from || !name) return;
        Quickshell.execDetached(["env", "P=" + plDir, "O=" + from, "N=" + name, "C=" + (cover || ""), "D=" + descLine(desc), "sh", "-c",
            'cd "$P" || exit 1; if [ "$O" != "$N" ]; then for e in m3u jpg jpeg png webp; do [ -f "$O.$e" ] && mv "$O.$e" "$N.$e"; done; fi; ' +
            'f="$N.m3u"; { [ -n "$D" ] && printf "%s\\n" "$D"; grep -v "^#DESCRIPTION:" "$f" || true; } > "$f.tmp" && mv "$f.tmp" "$f"; ' + coverSh]);
        if (openList === from) openList = name;
        listsLater.restart();
        openLater.restart();
    }
    // «перемешать и играть» — включает режим перемешивания (выключишь — плейлист вернётся в свой порядок)
    // "shuffle and play" turns the shuffle mode on (turn it off and the playlist returns to its own order)
    function shuffleList(name: string): void {
        ShellState.set("mpdShuffle", true);
        Quickshell.execDetached(["sh", "-c", 'mpc -q clear && mpc -q load "$1" && mpc -q play && sh "$2" on', "sh", name, shuffleSh]);
    }
    Process {
        id: listsProc
        command: ["sh", "-c", 'ls -1 "$1" 2>/dev/null | sed -n "s/\\.m3u$//p"', "sh", mpd.plDir]
        stdout: StdioCollector { onStreamFinished: mpd.playlists = text.split("\n").filter(l => l) }
    }
    function deleteList(name: string): void {
        Quickshell.execDetached(["sh", "-c", 'cd "$1" && rm -f "$2.m3u" "$2.jpg" "$2.jpeg" "$2.png" "$2.webp"', "sh", plDir, name]);
        if (openList === name) openList = "";
        listsLater.restart();
    }
    // трек — в конец плейлиста (нет такого плейлиста — он появится) / a track to the end of a playlist (created if it doesn't exist)
    function addToList(name: string, file: string): void {
        if (!name || !file) return;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$3" >> "$1/$2.m3u"', "sh", plDir, name, file]);
        if (openList === name) openLater.restart();
        listsLater.restart();
    }
    function removeFromList(name: string, i: int): void {
        // i — номер трека, строки с # (описание) не считаются / i is the track number, # lines (the description) don't count
        Quickshell.execDetached(["sh", "-c", 'f="$1/$2.m3u"; awk -v n="$3" \'/^#/ {print; next} {if (++k != n) print}\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"', "sh", plDir, name, String(i + 1)]);
        listsLater.restart();
        openLater.restart();
    }
    function playList(name: string): void { Quickshell.execDetached(["sh", "-c", 'mpc -q clear && mpc -q load "$1" && mpc -q play; sh "$2" ifon', "sh", name, shuffleSh]); }
    function appendList(name: string): void { mpc(["load", name]); }
    function showList(name: string): void { openList = name; listProc.running = true; }
    Timer { id: listsLater; interval: 250; onTriggered: mpd.loadLists() }
    Timer { id: openLater; interval: 250; onTriggered: if (mpd.openList) listProc.running = true }
    Process {
        id: listProc
        command: ["cat", mpd.plDir + "/" + mpd.openList + ".m3u"]
        stdout: StdioCollector { onStreamFinished: mpd.listTracks = text.split("\n").filter(l => l && !l.startsWith("#")) }
    }
}
