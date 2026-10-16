#!/bin/sh
# тема nyashell для основного Firefox: цвета палитры, строка адреса и вкладки-таблетки, наш шрифт.
# ничего своего не затираем: пишем chrome/nyashell.css и подключаем его одной строкой в userChrome.css
# аргументы: фон поверхность поверхность+ текст текст2 акцент текст-на-акценте линия
# nyashell theme for the main Firefox: palette colours, address bar and pill tabs, our font.
# nothing of yours is overwritten: we write chrome/nyashell.css and include it with one line in userChrome.css
# arguments: background surface surface+ text text2 accent text-on-accent line
BG=$1 SF=$2 SH=$3 TX=$4 DM=$5 AC=$6 OA=$7 LN=$8
for base in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    ini="$base/profiles.ini"
    [ -f "$ini" ] || continue
    p=$(awk -F= '/^\[Install/{f=1} f && /^Default=/{print $2; exit}' "$ini")
    [ -n "$p" ] || p=$(awk -F= '/^\[Profile/{path="";def=0} /^Path=/{path=$2} /^Default=1/{def=1} def && path {print path; exit}' "$ini")
    [ -n "$p" ] || continue
    case "$p" in /*) d="$p" ;; *) d="$base/$p" ;; esac
    [ -d "$d" ] || continue
    mkdir -p "$d/chrome"
    cat > "$d/chrome/nyashell.css" <<CSS
/* nyashell — создано шеллом из палитры, перезаписывается при смене цветов */
:root {
  --toolbar-bgcolor: $BG !important; --toolbar-color: $TX !important;
  --toolbar-field-background-color: $SF !important; --toolbar-field-focus-background-color: $SF !important;
  --toolbar-field-color: $TX !important; --toolbar-field-focus-color: $TX !important;
  --toolbar-field-border-color: transparent !important; --focus-outline-color: $AC !important;
  --lwt-accent-color: $BG !important; --lwt-text-color: $TX !important;
  --tab-selected-bgcolor: $SH !important; --tab-selected-textcolor: $TX !important;
  --arrowpanel-background: $BG !important; --arrowpanel-color: $TX !important; --arrowpanel-border-color: $LN !important;
  --urlbarView-highlight-background: $AC !important; --urlbarView-highlight-color: $OA !important;
  --button-hover-bgcolor: $SH !important; --tabs-navbar-separator-style: none !important;
}
#navigator-toolbox, #TabsToolbar, #nav-bar, #PersonalToolbar, #titlebar { background: $BG !important; border: none !important; box-shadow: none !important; }
#navigator-toolbox * { font-family: "Nyaspace", "Monaspace Neon Var", "Monaspace Neon NF", sans-serif !important; }
.tab-background { border-radius: 999px !important; margin-block: 5px !important; }
.tabbrowser-tab[selected] .tab-background { background: $SH !important; outline: 1px solid $AC !important; }
.tabbrowser-tab:not([selected]) .tab-label { color: $DM !important; }
#urlbar-background { border-radius: 999px !important; background: $SF !important; border: none !important; }
#urlbar[focused] #urlbar-background { outline: 1.5px solid $AC !important; }
#urlbar-input::placeholder { color: $DM !important; }
toolbarbutton .toolbarbutton-icon, toolbarbutton .toolbarbutton-badge-stack { border-radius: 999px !important; }
CSS
    uc="$d/chrome/userChrome.css"
    [ -f "$uc" ] || : > "$uc"
    grep -q 'nyashell.css' "$uc" || { printf '@import "nyashell.css";\n' | cat - "$uc" > "$uc.tmp" && mv "$uc.tmp" "$uc"; }
    uj="$d/user.js"
    grep -q 'legacyUserProfileCustomizations.stylesheets' "$uj" 2>/dev/null || \
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$uj"
done
