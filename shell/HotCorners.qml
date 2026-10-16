import Quickshell
import Quickshell.Wayland
import QtQuick

// углы экрана (как «края экрана» в KDE): курсор в угол и чуть задержать — действие.
// Что делает каждый угол — Настройки → Ввод → Углы экрана (settings.corners: { tl, tr, bl, br })
// screen corners (like KDE's "screen edges"): move the cursor into a corner and hold briefly to run an action.
// What each corner does is in Settings → Input → Screen corners (settings.corners: { tl, tr, bl, br })
Scope {
    id: hc
    function run(a: string, scr): void {
        if (a === "dashboard") Quickshell.execDetached(["qs", "-c", "nyashell", "ipc", "call", "dashboard", "toggle"]);
        else if (a === "launcher") ShellState.launcherOpen = !ShellState.launcherOpen;
        else if (a === "overview") Quickshell.execDetached(["mmsg", "dispatch", "toggleoverview"]);
        else if (a === "settings") ShellState.settingsOpen = !ShellState.settingsOpen;
        else if (a === "power") ShellState.powerOpen = !ShellState.powerOpen;
        else if (a === "lock") ShellState.lock();
        else if (a === "prev" || a === "next") Quickshell.execDetached(["qs", "-c", "nyashell", "ipc", "call", "pages", a]);
        else if (a === "shot") Quickshell.execDetached(["sh", Quickshell.shellPath("screenshot.sh"), "full"]);
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: sc
                required property var modelData
                Variants {
                    model: ["tl", "tr", "bl", "br"]
                    delegate: Component {
                        PanelWindow {
                            id: cw
                            required property string modelData
                            readonly property string act: (ShellState.settings.corners ?? {})[modelData] ?? "none"
                            screen: sc.modelData
                            visible: act !== "none" && !ShellState.locked && !ShellState.fullscreenOn(sc.modelData.name)
                            WlrLayershell.layer: WlrLayer.Overlay
                            WlrLayershell.namespace: "nyash-corner"
                            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                            exclusionMode: ExclusionMode.Ignore
                            anchors { top: modelData[0] === "t"; bottom: modelData[0] === "b"; left: modelData[1] === "l"; right: modelData[1] === "r" }
                            implicitWidth: 3; implicitHeight: 3
                            color: "transparent"
                            Item {
                                anchors.fill: parent
                                HoverHandler {
                                    id: hv
                                    onHoveredChanged: if (hovered) dwell.restart(); else dwell.stop()
                                }
                            }
                            // короткая задержка — чтобы угол не срабатывал, когда курсор просто пролетает мимо
                            // a short delay so a corner doesn't fire when the cursor just flies past
                            Timer { id: dwell; interval: 140; onTriggered: if (hv.hovered) hc.run(cw.act, sc.modelData) }
                        }
                    }
                }
            }
        }
    }
}
