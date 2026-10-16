#!/bin/sh
# открыть архив как обычную папку в Немо: архив подключается через fuse-archive (только чтение),
# и файлы из него можно копировать (Ctrl+C), перетаскивать мышью, открывать — как с любой папкой.
# Запаковать / распаковать целиком — по-прежнему ПКМ → «Распаковать сюда» / «Сжать…» (file-roller)
# запуск: archive-open.sh <путь или file:// URI>…   |   archive-open.sh --cleanup
# open an archive as a regular folder in Nemo: the archive is mounted with fuse-archive (read-only),
# and its files can be copied (Ctrl+C), dragged and opened like in any folder.
# Packing / unpacking as a whole is still right-click → "Extract here" / "Compress…" (file-roller)
# usage: archive-open.sh <path or file:// URI>…   |   archive-open.sh --cleanup
base="${XDG_RUNTIME_DIR:-/tmp}/nyash-archives"
mkdir -p "$base"

# отключить архивы, которые уже никто не открывает (занятые fusermount не отпустит — это и есть проверка)
# unmount archives nobody has open any more (fusermount won't release busy ones, which is the check)
cleanup() {
    for m in "$base"/*/; do
        [ -d "$m" ] || continue
        if mountpoint -q "$m"; then fusermount3 -u "$m" 2>/dev/null || fusermount -u "$m" 2>/dev/null; fi
        rmdir "$m" 2>/dev/null
    done
}
[ "${1:-}" = --cleanup ] && { cleanup; exit 0; }
cleanup

# file:///путь%20с%20пробелами → /путь с пробелами (побайтно, поэтому и кириллица верная)
# file:///path%20with%20spaces → /path with spaces (byte by byte, so Cyrillic comes out right too)
unuri() {
    case "$1" in
        file://*) printf '%s' "${1#file://}" | LC_ALL=C awk '{
            h = "0123456789abcdef"; s = $0; o = ""
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (c == "%" && i + 2 <= length(s)) {
                    o = o sprintf("%c", (index(h, tolower(substr(s, i + 1, 1))) - 1) * 16 + index(h, tolower(substr(s, i + 2, 1))) - 1)
                    i += 2
                } else o = o c
            }
            printf "%s", o }' ;;
        *) printf '%s' "$1" ;;
    esac
}

for a in "$@"; do
    f=$(unuri "$a")
    [ -f "$f" ] || continue
    if ! command -v fuse-archive >/dev/null; then exec file-roller "$f"; fi
    name=$(basename "$f"); m="$base/$name"; i=1
    while [ -e "$m" ] && ! mountpoint -q "$m"; do m="$base/$name ($i)"; i=$((i + 1)); done
    # уже подключён этот же архив — просто открываем
    # this archive is already mounted: just open it
    if ! mountpoint -q "$m"; then
        mkdir -p "$m"
        # lazycache: открывается сразу, а не после распаковки всего архива в кэш
        # lazycache: opens right away instead of after unpacking the whole archive into the cache
        if ! fuse-archive -o lazycache -o quiet "$f" "$m" </dev/null 2>/dev/null; then
            rmdir "$m" 2>/dev/null
            # не вышло (например, архив с паролем) — открываем в обычном архиваторе
            # didn't work (e.g. a password-protected archive): open it in the regular archiver
            file-roller "$f" &
            continue
        fi
    fi
    nemo "$m" &
done
