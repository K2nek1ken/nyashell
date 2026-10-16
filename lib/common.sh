# shellcheck shell=bash disable=SC2034
# shared by install.sh and uninstall.sh (bash)

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyashell"
BACKUP="$STATE/backup"
SRC="${XDG_DATA_HOME:-$HOME/.local/share}/nyashell/mango-src"
SHELL_DIR="$HOME/.config/quickshell/nyashell"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/nyashell"

ok()   { printf '\e[35m♡\e[0m %s\n' "$*"; }
info() { printf '\e[36m·\e[0m %s\n' "$*"; }
warn() { printf '\e[33m!\e[0m %s\n' "$*"; }
die()  { printf '\e[31m✗\e[0m %s\n' "$*"; exit 1; }

# ─── components ───
# every part of nyashell that can be installed or removed on its own
COMPONENTS="shell mango terminal prompt files music vpn apps icons fonts greeter"
describe() {
    case "$1" in
        shell)    echo "the shell itself, its mango config, portals and Qt/GTK theming" ;;
        mango)    echo "MangoWC built with the nyashell patch (/usr/local)" ;;
        terminal) echo "kitty and its config" ;;
        prompt)   echo "fish, fastfetch, zoxide and their configs" ;;
        files)    echo "nemo, archives, phones over MTP, dark GTK theme" ;;
        music)    echo "MPD music library (mpd, mpc, mpd-mpris) and its config" ;;
        vpn)      echo "sing-box and Xray for the VPN client" ;;
        apps)     echo "firefox (dashboard browser), mpv, btop" ;;
        icons)    echo "Gruvbox Plus icon theme" ;;
        fonts)    echo "Nyaspace as the system font (fontconfig)" ;;
        greeter)  echo "nyagreet login screen on greetd" ;;
    esac
}
is_component() { case " $COMPONENTS " in *" $1 "*) return 0 ;; esac; return 1; }

# parse_components <default set> <args…>: sets WANT (the chosen components) and EXTRA_ARGS
#   --name / --name=1 / --name=true / --name=yes  → only the components named like this
#   --name=0 / --name=false / --name=no           → everything (by default) except these
# both kinds can be mixed; any number of flags
parse_components() {
    local defaults=$1; shift
    local pos="" neg="" a n v
    EXTRA_ARGS=()
    for a in "$@"; do
        case "$a" in
            --*) n=${a#--}; v=1
                 case "$n" in *=*) v=${n#*=}; n=${n%%=*} ;; esac
                 if is_component "$n"; then
                     case "$v" in 1|true|yes|on) pos="$pos $n" ;; 0|false|no|off) neg="$neg $n" ;;
                                  *) die "--$n=$v: use 1/true/yes or 0/false/no" ;; esac
                 else EXTRA_ARGS+=("$a"); fi ;;
            *) EXTRA_ARGS+=("$a") ;;
        esac
    done
    local base=$defaults c
    [ -n "$pos" ] && base=$pos
    WANT=""
    for c in $COMPONENTS; do
        case " $base " in *" $c "*) ;; *) continue ;; esac
        case " $neg " in *" $c "*) continue ;; esac
        WANT="$WANT $c"
    done
    WANT=${WANT# }
    POSITIVE=$pos; NEGATIVE=$neg
}
want() { case " $WANT " in *" $1 "*) return 0 ;; esac; return 1; }

# ─── init system: systemd (Arch) or openrc / runit / dinit / s6 (Artix) ───
if [ -d /run/systemd/system ]; then INIT=systemd
elif command -v rc-service >/dev/null 2>&1; then INIT=openrc
elif [ -d /run/runit ] || command -v sv >/dev/null 2>&1; then INIT=runit
elif command -v dinitctl >/dev/null 2>&1; then INIT=dinit
elif command -v s6-rc >/dev/null 2>&1; then INIT=s6
else INIT=unknown; fi
DMS="sddm lightdm gdm lxdm ly greetd display-manager"
RUNIT_ON=/etc/runit/runsvdir/default
# s6 on Artix (wiki.artixlinux.org/Main/S6): scripts live in /etc/s6/sv as foo-srv + foo-log, s6-rc uses the plain
# name foo; a service starts at boot when an empty file named after it is in the default bundle, then s6-db-reload
S6_ON=/etc/s6/adminsv/default/contents.d
dm_current() {   # the display manager that starts at boot (service name without .service)
    local d
    case "$INIT" in
        systemd) d=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service 2>/dev/null)
                 [ "$d" = display-manager ] && d=""; echo "$d" ;;
        openrc)  for d in $DMS; do rc-update show default 2>/dev/null | grep -qw "$d" && { echo "$d"; return; }; done ;;
        runit)   for d in $DMS; do [ -e "$RUNIT_ON/$d" ] && { echo "$d"; return; }; done ;;
        dinit)   for d in $DMS; do [ -e "/etc/dinit.d/boot.d/$d" ] && { echo "$d"; return; }; done ;;
        s6)      for d in $DMS; do [ -e "$S6_ON/$d" ] && { echo "$d"; return; }; done ;;
    esac
}
dm_switch() {    # dm_switch <from|""> <to>: enable <to> at boot instead of <from>
    local from=$1 to=$2
    case "$INIT" in
        systemd) [ -n "$from" ] && sudo systemctl disable "$from"; sudo systemctl enable "$to" ;;
        openrc)  [ -n "$from" ] && sudo rc-update del "$from" default; sudo rc-update add "$to" default ;;
        runit)   [ -n "$from" ] && sudo rm -f "$RUNIT_ON/$from"; sudo ln -sf "/etc/runit/sv/$to" "$RUNIT_ON/" ;;
        dinit)   [ -n "$from" ] && sudo dinitctl disable "$from"; sudo dinitctl enable "$to" ;;
        s6)      [ -n "$from" ] && sudo rm -f "$S6_ON/$from"; sudo mkdir -p "$S6_ON" && sudo touch "$S6_ON/$to" && sudo s6-db-reload ;;
        *) return 1 ;;
    esac
}

svc_on() {      # svc_on <name>: enable a system service at boot and start it now, with any init
    local s=$1
    case "$INIT" in
        systemd) sudo systemctl enable --now "$s" ;;
        openrc)  sudo rc-update add "$s" default && sudo rc-service "$s" start ;;
        runit)   sudo ln -sf "/etc/runit/sv/$s" "$RUNIT_ON/" ;;
        dinit)   sudo dinitctl enable "$s" ;;
        s6)      sudo mkdir -p "$S6_ON" && sudo touch "$S6_ON/$s" && sudo s6-db-reload && sudo s6-rc -u change "$s" ;;
        *) return 1 ;;
    esac
}
svc_exists() {  # svc_exists <name>: the init knows this service
    case "$INIT" in
        systemd) systemctl cat "$1.service" >/dev/null 2>&1 ;;
        openrc)  [ -x "/etc/init.d/$1" ] ;;
        runit)   [ -d "/etc/runit/sv/$1" ] ;;
        dinit)   [ -f "/etc/dinit.d/$1" ] ;;
        s6)      [ -d "/etc/s6/sv/$1-srv" ] || [ -d "/etc/s6/adminsv/$1-srv" ] ;;
        *) return 1 ;;
    esac
}

yes=0
ask() {   # ask "question" default(y|n) -> 0 for yes
    local d=$2 r
    [ "$yes" = 1 ] && { [ "$d" = y ]; return; }
    read -r -p "$1 [$( [ "$d" = y ] && echo Y/n || echo y/N )] " r
    r=${r:-$d}; [[ "$r" =~ ^[Yy] ]]
}
