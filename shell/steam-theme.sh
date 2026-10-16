#!/bin/sh
# Steam + Millennium + Minimal Dark: цвета палитры шелла и компактная верхняя панель в узком окне
# (например, Steam на полэкрана: вкладки становятся значками, меню прячутся — ничего не уезжает за край).
# Ничего из скина не перезаписываем: пишем nyash.css рядом и подключаем его одной строкой.
# steam-theme.sh ФОН ПОВЕРХНОСТЬ ПОВЕРХНОСТЬ+ ТЕКСТ ТЕКСТ2 АКЦЕНТ
# Steam + Millennium + Minimal Dark: shell palette colours and a compact top bar in a narrow window
# (e.g. Steam on half the screen: tabs become icons, menus hide, nothing slides off the edge).
# Nothing in the skin is overwritten: we write nyash.css next to it and include it with one line.
# steam-theme.sh BACKGROUND SURFACE SURFACE+ TEXT TEXT2 ACCENT
BG=$1 SF=$2 SH=$3 TX=$4 DM=$5 AC=$6
acc_rgb=$(printf "%d, %d, %d" 0x$(echo ${AC#\#} | cut -c1-2) 0x$(echo ${AC#\#} | cut -c3-4) 0x$(echo ${AC#\#} | cut -c5-6))
for base in "$HOME/.local/share/Steam/steamui/skins" "$HOME/.steam/steam/steamui/skins" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamui/skins"; do
    [ -d "$base" ] || continue
    for d in "$base"/*/; do
        [ -f "$d/skin.json" ] && grep -qi "minimal" "$d/skin.json" "$d/metadata.json" 2>/dev/null || continue
        cat > "$d/nyash.css" <<CSS
/* nyashell — создано шеллом из палитры; перезаписывается при смене цветов */
:root {
    --minimal_dark_color: $AC !important;
    --minimal_dark_color_rgb: $acc_rgb !important;
    --SystemAccentColor: $AC !important;
    --SystemAccentColor-RGB: $acc_rgb !important;
    --minimal_dark_be_grey: $SH !important;
    --minimal_dark_black: $SF !important;
    --minimal_dark_blacker: $BG !important;
    --minimal_dark_blacker_alt: $BG !important;
    --minimal_dark_blacker_alt1: $BG !important;
    --minimal_dark_blacker_alt2: $BG !important;
    --minimal_dark_greyblack: $SH !important;
    --minimal_dark_topgrey: $DM !important;
    --minimal_dark_topgrey1: $TX !important;
    --minimal_dark_less_white: $TX !important;
    --minimal_dark_progress_bar: $AC !important;
}

/* окно уже 1280 px: вкладки сверху — только значками, без текста «Steam» */
@media (max-width: 1280px) {
    ._7AlhCx3XGzBeIrQaCneUD {
        font-size: 0px !important;
    	width: 33px !important;
    }

    ._7AlhCx3XGzBeIrQaCneUD:hover {
        font-size: 0px !important;
    	width: 33px !important;
    }
    ._2UyOBeiSdBayaFdRa39N2O {
        padding-left: 19px !important;
    }

    .bSKGlAJG2UVWTsntEJY2v {
        font-size: 0px !important;
        padding-right: 0px !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(1) {
        width: auto !important;
        padding-left: 0px !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(2)::before {
        transform: translate(-11px, 0px) !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(3)::before {
        transform: translate(-10px, 0px) !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(4)::before {
        transform: translate(-11px, 0px) !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(5)::before {
        transform: translate(-11px, 0px) !important;
    }

    .bSKGlAJG2UVWTsntEJY2v .GG9wVQz6PLlhGHlJyZh4E {
        transform: scale(.84) translate(15px, 0px) !important;
    }

    .bSKGlAJG2UVWTsntEJY2v .GG9wVQz6PLlhGHlJyZh4E {
        transform: scale(.84) translate(11px, 0px) !important;
    }

    ._2D64jIEK7wpUR_NlObDW76 {
        transform: translate(-88px, 0px) !important;
    }
}
/* окно уже 1000 px (полэкрана на 1920): ещё и меню сверху прячутся */
@media (max-width: 1000px) {
    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(2) {
    	display: none !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(3) {
    	display: none !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(4) {
    	display: none !important;
    }

    ._2UyOBeiSdBayaFdRa39N2O:nth-of-type(5) {
    	display: none !important;
    }

    ._3Z3ohQ8-1NKnCZkbS6fvy {
        margin-left: 134px !important;
    }

    ._2D64jIEK7wpUR_NlObDW76 {
        translate: -180px 0px !important;
    }
}
CSS
        # @import в CSS работает только в начале файла, а нам нужно быть ПОСЛЕ правил скина, чтобы победить их.
        # поэтому вставляем свой блок в конец между метками и при обновлении заменяем только его
        # @import in CSS only works at the start of a file, and we need to come AFTER the skin's rules to beat them.
        # so our block is inserted at the end between markers, and updates replace only that block
        for f in libraryroot.custom.css friends.custom.css; do
            [ -f "$d/$f" ] || continue
            sed -i '/\/\* nyash-start \*\//,/\/\* nyash-end \*\//d' "$d/$f"
            sed -i '/@import url("nyash.css");/d' "$d/$f"
            { printf '\n/* nyash-start */\n'; cat "$d/nyash.css"; printf '/* nyash-end */\n'; } >> "$d/$f"
        done
    done
done
