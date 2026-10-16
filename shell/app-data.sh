#!/bin/sh
# данные приложения: app-data.sh list|trash <desktop-id> <exec> <name>
# ищем папки с тем же именем (без учёта регистра) в ~/.config, ~/.local/share, ~/.local/state, ~/.cache,
# у flatpak — ~/.var/app/<id>. «trash» переносит их в корзину (gio trash), а не удаляет насовсем
# app data: app-data.sh list|trash <desktop-id> <exec> <name>
# looks for folders with the same name (case-insensitive) in ~/.config, ~/.local/share, ~/.local/state, ~/.cache,
# for flatpak ~/.var/app/<id>. "trash" moves them to the trash (gio trash) rather than deleting them for good
mode=$1; id=$2; exe=$(basename "${3:-}"); name=$4
cands=$(printf '%s\n' "$id" "${id##*.}" "$exe" "$name" "$(printf %s "$name" | tr -d ' ')" "$(printf %s "$name" | tr ' ' '-')" \
        | tr 'A-Z' 'a-z' | grep -vE '^(|desktop|app|bin|sh|env|flatpak|exec|java|python3?|electron)$' | sort -u)
found=""
for base in "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state" "$HOME/.cache"; do
    [ -d "$base" ] || continue
    for d in "$base"/*/; do
        n=$(basename "$d" | tr 'A-Z' 'a-z')
        printf '%s\n' "$cands" | grep -qxF "$n" && found="$found${d%/}
"
    done
done
[ -d "$HOME/.var/app/$id" ] && found="$found$HOME/.var/app/$id
"
found=$(printf %s "$found" | grep -v '^$' | grep -v '/quickshell$\|/mango$\|/nyashell')
if [ "$mode" = list ]; then printf '%s\n' "$found"; exit 0; fi
[ -n "$found" ] || exit 0
printf '%s\n' "$found" | while read -r d; do gio trash "$d" 2>/dev/null || { mkdir -p "$HOME/.local/share/Trash/files"; mv "$d" "$HOME/.local/share/Trash/files/"; }; done
notify-send -a nyashell "$name" "${5:-moved to trash, folders:} $(printf '%s\n' "$found" | wc -l)"
