#!/bin/sh
# свои шрифты: font-add.sh text|emoji FILE — копирует файл в ~/.local/share/fonts/nyashell-user
# и печатает «семейство\nпуть». Для emoji ещё и делает его первым эмодзи-шрифтом в fontconfig
# (его видят и шелл после перезапуска, и все остальные программы). font-add.sh emoji-reset — вернуть как было
# custom fonts: font-add.sh text|emoji FILE copies the file to ~/.local/share/fonts/nyashell-user
# and prints "family\npath". For emoji it also makes it the first emoji font in fontconfig
# (the shell sees it after a restart, and so do all other apps). font-add.sh emoji-reset puts it back as it was
mode=$1; f=$2
dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/nyashell-user"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/60-nyashell-emoji.conf"
if [ "$mode" = emoji-reset ]; then rm -f "$conf"; fc-cache -f >/dev/null 2>&1; exit 0; fi
[ -f "$f" ] || exit 2
case "$f" in *.ttf|*.otf|*.ttc|*.TTF|*.OTF|*.TTC) ;; *) exit 2 ;; esac
fam=$(fc-scan --format '%{family[0]}\n' "$f" 2>/dev/null | head -1)
[ -n "$fam" ] || exit 3
mkdir -p "$dir"; dest="$dir/$(basename "$f")"
[ "$f" = "$dest" ] || cp -f "$f" "$dest" || exit 4
if [ "$mode" = emoji ]; then
    x=$(printf '%s' "$fam" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    mkdir -p "$(dirname "$conf")"
    cat > "$conf" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- written by nyashell: emoji font chosen in Settings -->
<fontconfig>
  <alias binding="strong">
    <family>emoji</family>
    <prefer><family>$x</family><family>Noto Color Emoji</family></prefer>
  </alias>
</fontconfig>
XML
fi
fc-cache -f "$dir" >/dev/null 2>&1
printf '%s\n%s\n' "$fam" "$dest"
