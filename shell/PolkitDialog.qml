import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts

// свой polkit-агент: окно пароля сразу забирает клавиатуру
// our own polkit agent: the password window takes the keyboard right away
Scope {
    PolkitAgent { id: agent }

    PanelWindow {
        id: pw
        visible: agent.isActive
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#80000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) { pass.text = ""; pass.forceActiveFocus(); }

        function submit(): void {
            if (agent.flow) agent.flow.submit(pass.text);
            pass.text = "";
        }
        function cancel(): void {
            if (agent.flow) agent.flow.cancelAuthenticationRequest();
        }

        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: col.implicitHeight + 36
            radius: Theme.radiusLg
            color: Theme.bg
            border.color: Theme.line

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                Text {
                    font.family: Theme.font
                    text: L.t("нужен пароль")
                    color: Theme.accent
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    font.family: Theme.font
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: agent.flow?.message ?? ""
                    color: Theme.text
                    font.pixelSize: 13
                }
                Text {
                    font.family: Theme.font
                    Layout.fillWidth: true
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    text: agent.flow?.supplementaryMessage ?? ""
                    color: agent.flow?.supplementaryIsError ? Theme.danger : Theme.textDim
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 10
                    color: Theme.surface
                    border.color: agent.flow?.failed ? Theme.danger : "transparent"
                    TextInput {
                        font.family: Theme.font
                        id: pass
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: agent.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        font.pixelSize: 15
                        Keys.onPressed: (ev) => {
                            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { pw.submit(); ev.accepted = true; }
                            else if (ev.key === Qt.Key_Escape) { pw.cancel(); ev.accepted = true; }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [[L.t("отмена"), false], [L.t("ок"), true]]
                        delegate: Rectangle {
                            required property var modelData
                            width: 90
                            height: 34
                            radius: 8
                            color: modelData[1] ? Theme.accent : (bm.containsMouse ? Theme.surfaceHi : Theme.surface)
                            Text {
                                font.family: Theme.font
                                anchors.centerIn: parent
                                text: modelData[0]
                                color: modelData[1] ? Theme.bg : Theme.text
                            }
                            MouseArea {
                                id: bm
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modelData[1] ? pw.submit() : pw.cancel()
                            }
                        }
                    }
                }
            }
        }
    }
}
