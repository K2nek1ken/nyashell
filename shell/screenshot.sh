#!/bin/sh
# скриншоты: screenshot.sh full — весь экран, screenshot.sh area — выделить область
# файл кладётся в «Изображения/Скриншоты» и сразу копируется в буфер обмена
# screenshots: screenshot.sh full for the whole screen, screenshot.sh area to select an area
# the file goes to Pictures/Screenshots and is copied to the clipboard right away
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
f="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
case "$1" in
    area)
        # рамка выделения в цветах палитры (если шелл её сохранил)
        # selection box in the palette colours (if the shell has saved them)
        acc=$(sed -n 's/.*"accent":"#\([0-9a-fA-F]\{6\}\)".*/\1/p' "$HOME/.config/quickshell/nyashell/palette.json" 2>/dev/null)
        g=$(slurp -d -b 00000055 -c "${acc:-dfbfbe}ff" -w 2) || exit 0
        grim -g "$g" "$f" || exit 1 ;;
    geom)
        # область уже выделена в mango (Super+Shift+ЛКМ): "X,Y WxH"
        # the area is already selected in mango (Super+Shift+left-drag): "X,Y WxH"
        grim -g "$2" "$f" || exit 1 ;;
    *)
        grim "$f" || exit 1 ;;
esac
wl-copy < "$f"
act=$(notify-send -a "Screenshot" -i "$f" -A open="Open" -A folder="Folder" -A delete="Delete" "Screenshot saved" "$(basename "$f") — copied to clipboard")
case "$act" in
    open) xdg-open "$f" ;;
    folder) nemo "$dir" ;;
    delete) rm -f "$f"; wl-copy --clear 2>/dev/null ;;
esac
