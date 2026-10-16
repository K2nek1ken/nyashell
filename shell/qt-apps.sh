#!/bin/sh
# убрать копии ярлыков Telegram/AyuGram, которые делала прошлая версия шелла (помечены X-Nyashell=1).
# Теперь платформенная тема KDE включена для всего сеанса (env= в config.conf), копии не нужны
# remove the copies of the Telegram/AyuGram shortcuts the previous shell version made (marked X-Nyashell=1).
# The KDE platform theme is now on for the whole session (env= in config.conf), the copies aren't needed
dst="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
grep -l '^X-Nyashell=1' "$dst"/*.desktop 2>/dev/null | while read -r f; do rm -f "$f"; done
exit 0
