# nyashell

A desktop shell for [MangoWC](https://github.com/mangowm/mango) built with [Quickshell](https://quickshell.org).

Bar with pages, taskbar and tray; drawers that grow out of the screen frame (app menu, dashboard,
system monitor, notifications, quick settings); lock screen and a matching greetd login screen;
music player on MPD with an equaliser; VPN client on sing-box; clipboard, calculator, power menu,
screenshots and screen recording; session restore; Material-You-style colours from the wallpaper,
also applied to GTK/KDE apps, kitty, fish, Firefox, Steam and DeltaChat.

Any installed font (or a .ttf/.otf file) can be used for the interface text, and any colour emoji
font for emoji: *Settings → Look*.

The interface is in **English** and **Russian** (Super+G or Settings → Look). The full feature
list lives in **Settings → About**.

> Russian version below / русская версия ниже.

## Requirements

* **Arch Linux**, **Artix** or another Arch-based distro (EndeavourOS, CachyOS, Manjaro…), with any init:
  systemd, OpenRC, runit, dinit or s6. The installer uses `pacman` and an AUR helper (`paru` or `yay`;
  it installs `yay-bin` if there is none).
  Without systemd the shell takes care of what systemd would do: the nyagreet login screen starts the session
  inside `dbus-run-session`, the mango config starts PipeWire, and the installer adds the init scripts for
  NetworkManager and bluetooth. With another display manager on Artix, start mango as `dbus-run-session mango`.
* A GPU with working Wayland drivers. Blur and real transparency are on by default; set
  *Settings → Look → Blur strength* to 0 on weak hardware.

MangoWC is built from source at a pinned commit with the nyashell patch (window animations, live drag,
page-dot drop, region screenshots, full-damage blur, shortcuts muted only in chosen apps). It is installed to `/usr/local`, so a distro
`mangowm` package, if you have one, stays untouched.

## Install

```sh
git clone https://github.com/K2nek1ken/nyashell
cd nyashell
./install.sh
```

Parts — each can be installed (and removed) on its own:

| part | what it is |
| --- | --- |
| `shell` | the shell itself, its mango config, portals, Qt/GTK theming |
| `mango` | MangoWC built with the nyashell patch (`/usr/local`) |
| `terminal` | kitty and its config |
| `prompt` | fish, fastfetch, zoxide and their configs |
| `files` | nemo (archives open as folders, "New document" templates, extra right-click actions), phones over MTP, dark GTK theme |
| `music` | MPD library (mpd, mpc, mpd-mpris) |
| `vpn` | sing-box and Xray |
| `apps` | firefox (also used by the optional dashboard browser tab), mpv, btop |
| `icons` | Gruvbox Plus icons |
| `fonts` | Nyaspace as the system font |
| `greeter` | nyagreet login screen on greetd (not installed by default: it asks) |

```sh
./install.sh -y                       # everything except the login screen, no questions
./install.sh --terminal --prompt      # ONLY these parts (--terminal=1, =true, =yes work too)
./install.sh --terminal=0 --vpn=no    # everything EXCEPT these parts
./install.sh --greeter=1 --vpn=0      # both kinds can be mixed, any number of flags
./install.sh --list                   # the parts
```

Qt apps get the KDE platform theme for the whole session (as on KDE): colours and the accent come from the shell,
file dialogs go through the portal. This needs `plasma-integration`, which the `shell` part installs.

Then log out and choose the **Mango** session. Running `./install.sh` again updates everything and keeps
your settings.

What it touches: packages (only missing ones are installed, and each is recorded),
`~/.config/quickshell/nyashell`, `~/.config/mango/config.conf`, the dots in `~/.config`, fonts in
`~/.local/share/fonts/nyashell`, and `/etc/greetd` with `--greeter`. Every file it replaces is backed up
to `~/.local/state/nyashell/backup` first.

## Uninstall

```sh
./uninstall.sh            # everything; asks before removing packages
./uninstall.sh -y         # removes everything it installed, keeps VPN profiles and wallpapers
./uninstall.sh --music    # only these parts; --music=0 — everything except them
./uninstall.sh --purge    # also deletes VPN profiles, EQ presets and wallpapers
./uninstall.sh --keep-packages
```

A copy of the uninstaller is kept in `~/.local/state/nyashell/bin/`, so it works after the repo folder is gone.
It restores the files it backed up, switches the display manager back (if the installer switched it),
removes the patched mango from `/usr/local`, and removes **only the packages the installer added**
(`pacman -Rns`, so the dependencies pulled in with them go too). Packages something else still needs
are kept.

## Keys

| keys | action |
| --- | --- |
| Super (tap) | app menu |
| Super+S | dashboard |
| Super+I | settings |
| Super+L | lock |
| Super+Space | power menu |
| Super+V / Super+R | clipboard / calculator |
| Super+W | system monitor |
| Super+G | switch language |
| Super+A / Super+D | terminal / files |
| Ctrl+Shift+A / D | previous / next page; in the scroller, previous / next window first |
| Super+Shift+A / D | move window to the previous / next page |
| Super+wheel | scroll pages |
| Super+Tab | scroller ↔ grid |
| Super+E | window width preset (scroller) |
| Super+F / Super+C | fullscreen / floating |
| Alt+Q / Ctrl+Q / Super+Q | close window / minimise / kill the whole app |
| Super+drag, Super+right-drag | move / resize |
| Print, Super+Shift+S | screenshot |
| Shift+Print, Super+Shift+drag | area screenshot |
| Ctrl+Print / Ctrl+Shift+Print | record screen / area (again to stop); add Alt for the microphone |
| Ctrl+Shift+F | wallpaper picker |
| Ctrl+Alt+G | move / resize the on-screen GIFs (again to finish) |
| in the dashboard | A/D tabs, S/Space into the tab, WASD/arrows to move, Space/Enter to press, Esc back |
| Ctrl+Alt+A / D, Ctrl+Shift+Space | previous / next track, play-pause |
| Super+Ctrl+R | restart the shell |
| Super+Shift+M | quit mango |

All keys can be changed in *Settings → Keys*.

## Credits and licence

nyashell is **GPL-3.0**. Design tokens (Material 3 Expressive curves, durations, radii), StateLayer
and the overall concept (screen frame, bottom bar, dashboard) are adapted from
[caelestia-shell](https://github.com/caelestia-dots/shell) (GPL-3.0). The mango patch applies to
[MangoWC](https://github.com/mangowm/mango) (GPL-3.0).

The bundled **Nyaspace** font is a modified Monaspace Neon (GitHub Next) with Nerd Fonts glyphs,
under the SIL Open Font License 1.1 — see `shell/fonts/`.

---

# nyashell (по-русски)

Шелл для [MangoWC](https://github.com/mangowm/mango) на [Quickshell](https://quickshell.org):
панель со страницами, задачами и треем; выдвижные панели из рамки экрана (меню приложений, борд,
монитор системы, уведомления, быстрые настройки); экран блокировки и экран входа greetd в том же стиле;
плеер на MPD с эквалайзером; VPN на sing-box; буфер обмена, калькулятор, меню питания, скриншоты и запись
экрана; восстановление сеанса; цвета из обоев в стиле Material You — и в программах GTK/KDE, kitty, fish,
Firefox, Steam, DeltaChat.

Интерфейс на **английском** (по умолчанию) и **русском**: Super+G или Настройки → Вид. Там же можно
поставить свой шрифт для текста (любой установленный или файлом .ttf/.otf) и свой шрифт эмодзи.

## Установка

Нужен Arch Linux, Artix или другой дистрибутив на основе Arch; init любой: systemd, OpenRC, runit, dinit, s6.
Без systemd шелл берёт его работу на себя: экран входа nyagreet запускает сеанс внутри `dbus-run-session`,
конфиг mango запускает PipeWire, а установщик ставит службы NetworkManager и bluetooth для твоего init.
С другим экраном входа на Artix запускай mango как `dbus-run-session mango`.

```sh
git clone https://github.com/K2nek1ken/nyashell
cd nyashell
./install.sh               # спросит про необязательные части
./install.sh -y            # всё, кроме экрана входа, без вопросов
./install.sh --terminal    # ТОЛЬКО эти части (флагов сколько угодно: --shell --mango …)
./install.sh --terminal=0  # всё, КРОМЕ этих частей (=0, =false, =no); оба вида можно смешивать
./install.sh --list        # части: shell mango terminal prompt files music vpn apps icons fonts greeter
```

Установщик ставит недостающие пакеты (и записывает, какие именно), собирает mango на закреплённом коммите
с патчем nyashell в `/usr/local`, раскладывает шелл, конфиг mango и дотфайлы. Всё, что он заменяет,
сначала копируется в `~/.local/state/nyashell/backup`. Повторный запуск обновляет всё и сохраняет
настройки. После установки выйди из сеанса и выбери **Mango**.

## Удаление

```sh
./uninstall.sh             # спросит перед удалением пакетов
./uninstall.sh -y          # удалит всё, что ставил установщик; профили VPN и обои оставит
./uninstall.sh --music     # только эти части; --music=0 — всё, кроме них
./uninstall.sh --purge     # заодно удалит профили VPN, пресеты эквалайзера и обои
```

Возвращает твои старые файлы из копий, возвращает прежний менеджер входа (если установщик его менял),
удаляет патченый mango и **только те пакеты, которые поставил установщик**, вместе с зависимостями,
которые пришли с ними (`pacman -Rns`). Пакеты, которые нужны чему-то ещё, остаются.

## Клавиши

Таблица выше; все сочетания меняются в *Настройки → Клавиши*.

## Лицензия

GPL-3.0. Дизайн-токены и общая концепция — из [caelestia-shell](https://github.com/caelestia-dots/shell)
(GPL-3.0). Шрифт **Nyaspace** — изменённый Monaspace Neon со значками Nerd Fonts, SIL OFL 1.1
(`shell/fonts/`).
