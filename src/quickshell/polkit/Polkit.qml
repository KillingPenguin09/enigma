import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../reusables/buttons"
import "../"

PanelWindow {
    id: polkitWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PolkitService.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: PolkitService.isActive
    color: PolkitService.isActive ? Qt.rgba(0, 0, 0, 0.55) : "transparent"

    property var rootObj
    function s(val) {
        return (rootObj && typeof rootObj.s === "function") ? rootObj.s(val) : val;
    }

    property real crLarge: ThemeBackend.borderRadius
    property real crMedium: Math.max(0, ThemeBackend.borderRadius - 2)
    property real crSmall: Math.max(0, ThemeBackend.borderRadius - 4)

    property real toolbarHeight: s(32)
    property real actionHeight: s(42)
    property bool isAuthenticating: false

    function grabInputFocus() {
        passwordInput.forceInputFocus();
    }

    onVisibleChanged: {
        if (visible) {
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            focusRetryTimer.restart();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 50
        repeat: false
        onTriggered: {
            polkitWindow.grabInputFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: polkitWindow.visible
        onActivated: PolkitService.cancel()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: polkitWindow.visible && passwordInput.text.length > 0
        onActivated: polkitWindow.submitPassword()
    }

    function submitPassword() {
        if (!PolkitService.flow || polkitWindow.isAuthenticating) return;
        polkitWindow.isAuthenticating = true;
        PolkitService.submit(passwordInput.text);
    }

    Connections {
        target: PolkitService

        function onRequestStarted() {
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            focusRetryTimer.restart();
        }

        function onAuthenticationFailed() {
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            passwordInput.markError();
            focusRetryTimer.restart();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PolkitService.cancel()
    }

    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: s(520)
        implicitHeight: cardLayout.implicitHeight + (polkitWindow.s(18) * 2)
        color: ThemeBackend.base
        radius: polkitWindow.crLarge
        border.color: ThemeBackend.surface0
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowVerticalOffset: polkitWindow.s(4)
            shadowBlur: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: polkitWindow.s(18)
            spacing: polkitWindow.s(14)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: polkitWindow.s(8)

                Text {
                    text: {
                        if (PolkitService.flow && PolkitService.flow.actionId) return PolkitService.flow.actionId;
                        return typeof I18n !== "undefined" ? I18n.t("polkit.default_description") : "Authentication is needed to run this action as superuser.";
                    }
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: polkitWindow.s(12)
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: {
                        if (PolkitService.flow && PolkitService.flow.message) return PolkitService.flow.message;
                        return typeof I18n !== "undefined" ? I18n.t("polkit.default_message") : "An application is requesting administrative rights.";
                    }
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: polkitWindow.s(14)
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.5)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorText.implicitHeight + polkitWindow.s(12)
                radius: polkitWindow.crSmall
                color: Qt.alpha(ThemeBackend.red, 0.12)
                border.color: Qt.alpha(ThemeBackend.red, 0.4)
                border.width: 1
                visible: PolkitService.errorMessage !== ""

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: polkitWindow.s(6)
                    spacing: polkitWindow.s(8)

                    Text {
                        text: "󰅚"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: polkitWindow.s(14)
                        color: ThemeBackend.red
                    }

                    Text {
                        id: errorText
                        text: PolkitService.errorMessage
                        color: ThemeBackend.red
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: polkitWindow.s(12)
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            PasswordInput {
                id: passwordInput
                Layout.fillWidth: true
                Layout.preferredHeight: polkitWindow.toolbarHeight + polkitWindow.s(6)
                visible: !PolkitService.flow || PolkitService.flow.isResponseRequired !== false

                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                errorColor: ThemeBackend.red
                busyColor: ThemeBackend.peach

                cornerRadius: polkitWindow.crSmall
                horizontalPadding: polkitWindow.s(10)
                verticalPadding: polkitWindow.s(4)

                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: polkitWindow.s(13)

                showLockIcon: true
                showSubmitButton: true
                lockButtonSize: polkitWindow.toolbarHeight + polkitWindow.s(2)

                hasError: PolkitService.errorMessage !== ""
                isBusy: polkitWindow.isAuthenticating

                placeholderText: {
                    if (PolkitService.flow && PolkitService.flow.inputPrompt) {
                        let p = PolkitService.flow.inputPrompt.trim();
                        if (p.endsWith(":")) p = p.slice(0, -1);
                        return p;
                    }
                    return typeof I18n !== "undefined" ? I18n.t("polkit.password_placeholder") : "Password";
                }

                onAccepted: polkitWindow.submitPassword()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: polkitWindow.s(8)
                spacing: polkitWindow.s(12)

                ClickButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: polkitWindow.s(36)
                    buttonText: typeof I18n !== "undefined" ? I18n.t("polkit.cancel", "Cancel") : "Cancel"
                    accentColor: ThemeBackend.surface1
                    onClicked: PolkitService.cancel()
                }

                ClickButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: polkitWindow.s(36)
                    buttonText: typeof I18n !== "undefined" ? I18n.t("polkit.authenticate", "Authenticate") : "Authenticate"
                    accentColor: ThemeBackend.mauve
                    enabled: passwordInput.text.length > 0 || polkitWindow.isAuthenticating
                    onClicked: polkitWindow.submitPassword()
                }
            }
        }
    }
}
