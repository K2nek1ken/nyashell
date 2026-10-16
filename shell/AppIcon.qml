import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

// значок приложения в духе «тематических значков» Android:
// если у темы есть монохромная (-symbolic) версия — берём её и красим в акцент;
// если нет — обычный значок делаем ч/б и тонируем в акцент. Выключается в настройках.
// app icon in the spirit of Android's "themed icons":
// if the theme has a monochrome (-symbolic) version, use it and paint it with the accent;
// if not, make the regular icon greyscale and tint it with the accent. Can be turned off in the settings.
Item {
    id: ai
    property string icon: ""
    property real size: 24
    property color tint: Theme.accent
    readonly property bool themed: ShellState.settings.themedIcons ?? true
    readonly property string symbolic: themed && icon ? Quickshell.iconPath(icon + "-symbolic", true) : ""
    implicitWidth: size
    implicitHeight: size

    // у тем на основе Papirus (Gruvbox Plus и др.) маленькие размеры значков приложений (16–32 px) —
    // монохромные «панельные», и выглядят как тонированные, даже когда тонировка выключена.
    // Поэтому сам значок всегда рисуем крупным (от 64 px: тема отдаёт цветную версию) и уменьшаем
    // масштабом; слой с мип-картами — чтобы уменьшенный значок был гладким
    // Papirus-based themes (Gruvbox Plus and others) have small app icon sizes (16–32 px) that are
    // monochrome "panel" icons and look tinted even when tinting is off.
    // So the icon itself is always drawn large (from 64 px the theme gives the colour version) and scaled
    // down; a mipmapped layer keeps the scaled-down icon smooth
    readonly property real big: Math.max(64, Math.ceil(size))
    Component {
        id: fx
        MultiEffect {
            // у symbolic — просто перекрасить; у цветного — убрать цвет и тонировать
            // symbolic: just recolour; colour icons: remove the colour and tint
            saturation: ai.symbolic ? 0 : -1
            colorization: ai.symbolic ? 1 : 0.55
            colorizationColor: ai.tint
            brightness: ai.symbolic ? 0 : 0.08
        }
    }
    IconImage {
        id: img
        anchors.centerIn: parent
        width: ai.big; height: ai.big
        implicitSize: ai.big
        scale: Math.min(ai.width, ai.height) / ai.big
        source: ai.symbolic || Quickshell.iconPath(ai.icon, "application-x-executable")
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        layer.effect: ai.themed ? fx : null
    }
}
