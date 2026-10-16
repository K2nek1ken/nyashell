#!/bin/sh
# настройка Немо под шелл (запускает шелл при старте, повторный запуск ничего не ломает):
#  · шаблоны «Создать документ» — один раз, удалённые потом не возвращаются;
#  · действия в меню ПКМ (в т.ч. по папкам слева): свойства, терминал, копировать путь, архив как папку;
#  · архивы по двойному клику открываются как папка (один раз; если сменишь программу сама — не трогаем)
# запуск: files-setup.sh [ru|en]
# setting Nemo up for the shell (the shell runs this at start; running it again breaks nothing):
# · "New document" templates, once; deleted ones don't come back;
# · right-click actions (including on the folders on the left): properties, terminal, copy path, archive as folder;
# · archives open as a folder on double click (once; if you change the app yourself we leave it alone)
# usage: files-setup.sh [ru|en]
lang=${1:-en}
here=$(cd "$(dirname "$0")" && pwd)
state="${XDG_STATE_HOME:-$HOME/.local/state}/nyashell"; mkdir -p "$state"
data="${XDG_DATA_HOME:-$HOME/.local/share}"

# ─── действия Немо: наши (nyash-*) обновляем всегда ───
# ─── Nemo actions: ours (nyash-*) are always refreshed ───
mkdir -p "$data/nemo/actions"
cp -f "$here"/actions/nyash-*.nemo_action "$data/nemo/actions/" 2>/dev/null

# ─── шаблоны ───
# ─── templates ───
if [ ! -e "$state/templates-1" ]; then
    t=$(xdg-user-dir TEMPLATES 2>/dev/null)
    if [ -z "$t" ] || [ "$t" = "$HOME" ]; then
        [ "$lang" = ru ] && t="$HOME/Шаблоны" || t="$HOME/Templates"
        command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update --set TEMPLATES "$t"
    fi
    mkdir -p "$t"
    put() {  # put <имя ru> <имя en> <содержимое> / put <ru name> <en name> <content>
        if [ "$lang" = ru ]; then n=$1; else n=$2; fi
        [ -e "$t/$n" ] || printf '%b' "$3" > "$t/$n"
    }
    cpy() {  # cpy <имя ru> <имя en> <файл-заготовка> / cpy <ru name> <en name> <template file>
        if [ "$lang" = ru ]; then n=$1; else n=$2; fi
        [ -e "$t/$n" ] || cp "$here/templates/$3" "$t/$n"
    }
    put "Текстовый файл.txt" "Text file.txt" ""
    put "Заметка.md" "Note.md" "# \n"
    put "Скрипт.sh" "Script.sh" "#!/bin/sh\n\n"
    put "Скрипт на Python.py" "Python script.py" "#!/usr/bin/env python3\n\n"
    put "main.rs" "main.rs" "fn main() {\n    println!(\"hello\");\n}\n"
    put "Компонент.qml" "Component.qml" "import QtQuick\n\nItem {\n}\n"
    put "Страница.html" "Page.html" "<!doctype html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<title></title>\n</head>\n<body>\n\n</body>\n</html>\n"
    put "Данные.json" "Data.json" "{}\n"
    cpy "Документ.odt" "Document.odt" blank.odt
    cpy "Таблица.ods" "Spreadsheet.ods" blank.ods
    cpy "Презентация.odp" "Presentation.odp" blank.odp
    chmod +x "$t"/*.sh "$t"/*.py 2>/dev/null
    : > "$state/templates-1"
fi

# ─── память Немо ───
# ─── Nemo's memory ───
# Немо 6.6 не помнит, где был: каждый запуск — домашняя папка. Окна и вкладки запоминает наше расширение
# nemo-ext/nyash-memory.py (нужен пакет nemo-python), а открывает их обёртка nemo-open.sh
# Nemo 6.6 doesn't remember where it was: every launch opens the home folder. Our nemo-ext/nyash-memory.py
# extension remembers the windows and tabs (needs the nemo-python package), and the nemo-open.sh wrapper reopens them
apps="$data/applications"; mkdir -p "$apps"
ext="$data/nemo-python/extensions"
if gsettings writable org.nemo.preferences restore-tabs-on-startup >/dev/null 2>&1; then
    # Немо 6.7+ сам восстанавливает окно со всеми вкладками — наши расширение и обёртка не нужны
    # Nemo 6.7+ restores its window with all tabs by itself, our extension and wrapper aren't needed
    gsettings set org.nemo.preferences restore-tabs-on-startup true
    rm -f "$ext/nyash-memory.py"
    grep -q '^X-Nyashell-Nemo=1' "$apps/nemo.desktop" 2>/dev/null && rm -f "$apps/nemo.desktop"
elif [ -f /usr/share/applications/nemo.desktop ]; then
    # ссылка, а не копия — обновления шелла сразу доходят до Немо (после его перезапуска)
    # a link rather than a copy, so shell updates reach Nemo right away (after it restarts)
    mkdir -p "$ext" && ln -sf "$here/nemo-ext/nyash-memory.py" "$ext/nyash-memory.py"
    # Немо из меню, с панели и т.п. — через обёртку с памятью (свой ярлык в ~/.local важнее системного)
    # Nemo from the menu, the bar and so on goes through the wrapper with memory (a ~/.local shortcut wins over the system one)
    sed -e "s|^Exec=nemo\b|Exec=sh \"$here/nemo-open.sh\"|" /usr/share/applications/nemo.desktop > "$apps/nemo.desktop.tmp" &&
        printf 'X-Nyashell-Nemo=1\n' >> "$apps/nemo.desktop.tmp" && mv -f "$apps/nemo.desktop.tmp" "$apps/nemo.desktop"
fi
rm -f "$state/nemo-last.txt"      # от прошлой версии памяти / left over from the previous memory version

# ─── архивы как папки ───
# ─── archives as folders ───
mimes="application/zip;application/x-7z-compressed;application/vnd.rar;application/x-rar;application/x-rar-compressed;application/x-tar;application/x-compressed-tar;application/x-bzip-compressed-tar;application/x-xz-compressed-tar;application/x-zstd-compressed-tar;application/x-lzma-compressed-tar;application/gzip;application/x-gzip;application/x-iso9660-image;application/x-cd-image;application/vnd.ms-cab-compressed;application/x-cpio;application/x-lha;"
if [ "$lang" = ru ]; then nm="Архив как папка"; cm="Открыть архив как обычную папку в Немо"; else nm="Archive as Folder"; cm="Open an archive as a regular folder in Nemo"; fi
cat > "$apps/nyash-archive.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=$nm
Comment=$cm
Icon=folder
Exec=sh "$here/archive-open.sh" %U
MimeType=$mimes
NoDisplay=true
Terminal=false
DESK
command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null
if [ ! -e "$state/archives-1" ] && command -v fuse-archive >/dev/null && command -v xdg-mime >/dev/null; then
    # переключаем только там, где стоит file-roller или ничего не выбрано
    # switch only where file-roller or nothing is set
    for m in $(printf '%s' "$mimes" | tr ';' ' '); do
        cur=$(xdg-mime query default "$m" 2>/dev/null)
        case "$cur" in ""|org.gnome.FileRoller.desktop|file-roller.desktop) xdg-mime default nyash-archive.desktop "$m" ;; esac
    done
    : > "$state/archives-1"
fi
exit 0
