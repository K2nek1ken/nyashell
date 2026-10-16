import QtQuick

// значок из шрифта Nyaspace (набор Font Awesome внутри Nerd Font, коды как на NyashBoard)
// an icon from the Nyaspace font (the Font Awesome set inside the Nerd Font, codes as on NyashBoard)
Text {
    id: ic
    property string name: ""
    property real size: 18

    readonly property var glyphs: ({
        pets: 0xf1b0, coffee: 0xf0f4, star: 0xf005, apps: 0xf00a, close: 0xf00d,
        battery_full: 0xf240, battery_5_bar: 0xf241, battery_3_bar: 0xf242,
        battery_alert: 0xf243, battery_charging_full: 0xf0e7,
        lock: 0xf023, logout: 0xf08b, restart_alt: 0xf021, refresh: 0xf021,
        power_settings_new: 0xf011, settings: 0xf013, terminal: 0xf120,
        wallpaper: 0xf03e, movie: 0xf008, code: 0xf121, school: 0xf19d,
        sports_esports: 0xf11b, palette: 0xf1fc, public: 0xf0ac, description: 0xf15c,
        tune: 0xf1de, memory: 0xf2db, build: 0xf0ad, search: 0xf002, folder: 0xf07b,
        skip_previous: 0xf048, play_arrow: 0xf04b, pause: 0xf04c, skip_next: 0xf051,
        music: 0xf001, music_off: 0xf026, key: 0xf084,
        minimize: 0xf2d1, open_in_browser: 0xf2d2, open_in_full: 0xf2d0,
        close_fullscreen: 0xf2d2, fullscreen: 0xf065, sparkle: 0xf005,
        vol_up: 0xf028, vol_down: 0xf027, vol_off: 0xf026, headphones: 0xf025,
        wifi: 0xf1eb, bluetooth: 0xf294, eye: 0xf06e, moon: 0xf186,
        check: 0xf00c, edit: 0xf040, off: 0xf05e, unlock: 0xf09c, bolt: 0xf0e7, sun: 0xe30d, calendar: 0xf073,
        w_sunny: 0xe30d, w_partly: 0xe302, w_cloudy: 0xe312, w_rain: 0xe318, w_snow: 0xe31a,
        w_thunder: 0xe31d, w_fog: 0xe313, w_night: 0xe32b, w_wind: 0xe34b, w_drop: 0xe373,
        hdd: 0xf0a0, user: 0xf007, clock: 0xf017, thermo: 0xf2c9, chevron_left: 0xf053,
        chevron_right: 0xf054, dashboard: 0xf0e4, place: 0xf041, shuffle: 0xf074, repeat: 0xf01e, sync: 0xf021, copy: 0xf0c5, videocam: 0xf03d, chat: 0xf075, keyboard: 0xf11c, phone: 0xf10b, laptop: 0xf109, tv: 0xf26c, search: 0xf002, queue: 0xf0cb, bars: 0xf0c9, sliders: 0xf1de, drop: 0xf043, arrow_right: 0xf061, hand: 0xf256, hand_pointer: 0xf25a, speech: 0xf075, bullhorn: 0xf0a1, l_scroller: 0xf0db, l_grid: 0xf009, l_tile: 0xf00b, pin: 0xf08d, plus: 0xf067, folder_open: 0xf07c, magic: 0xf0d0, clipboard: 0xf0ea, calculator: 0xf1ec, science: 0xf0c3, history: 0xf1da, image: 0xf03e, sleep: 0xf236, bin: 0xf014, bell: 0xf0f3, bell_off: 0xf1f6, trash: 0xf1f8, usb: 0xf287, ethernet: 0xf0e8, plug: 0xf1e6, cell: 0xf012
    })

    // одинаковый кегль ≠ одинаковый вид: широкие низкие значки (wi-fi, глаз) кажутся мельче,
    // высокие (bluetooth, замок) — крупнее. Коэффициенты посчитаны по реальным контурам глифов
    // (смесь площади и наибольшей стороны), громкость — одним коэффициентом на все состояния
    // same size ≠ same look: wide low icons (wi-fi, eye) look smaller,
    // tall ones (bluetooth, lock) look bigger. The factors are computed from the real glyph outlines
    // (a mix of area and the longest side); volume uses one factor for all its states
    readonly property var optical: ({
        wifi: 1.16, bluetooth: 0.89, vol_up: 1.10, vol_down: 1.10, vol_off: 1.10, eye: 1.19,
        moon: 1.02, sun: 1.05, lock: 0.91, pets: 1.08, close: 1.3, bell: 1.0, bell_off: 1.0, headphones: 1.08
    })
    property bool opticalSize: true
    text: glyphs[name] !== undefined ? String.fromCodePoint(glyphs[name]) : name
    color: Theme.text
    font.family: Theme.iconFont
    font.pixelSize: size * (opticalSize ? (optical[name] ?? 1) : 1)
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
