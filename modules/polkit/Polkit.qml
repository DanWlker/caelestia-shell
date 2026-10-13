pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

// Fork: polkit agent inside the shell, replacing hyprpolkitagent. While a request is open, every screen is dimmed and
// the prompt shows on the screen that was focused when it arrived (only that one takes the keyboard). Polkit and PAM
// check the password as before; this is only the prompt.
Scope {
    id: root

    property string promptScreen

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            const focused = Hypr.focusedMonitor?.name ?? "";
            root.promptScreen = Screens.screens.some(s => s.name === focused) ? focused : (Screens.screens[0]?.name ?? "");
        }
        onIsRegisteredChanged: console.info(`Polkit agent ${isRegistered ? "registered" : "not registered"}`)
    }

    Variants {
        model: agent.isActive ? Screens.screens : []

        StyledWindow {
            id: win

            required property ShellScreen modelData
            readonly property bool hasPrompt: modelData.name === root.promptScreen
            property real dim // Starts at 0 so the dimming fades in

            screen: modelData
            name: "polkit"
            color: Qt.alpha(Colours.palette.m3scrim, dim)
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: hasPrompt ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Component.onCompleted: dim = 0.45

            Behavior on dim {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Loader {
                anchors.centerIn: parent
                active: win.hasPrompt && !!agent.flow

                sourceComponent: Prompt {
                    flow: agent.flow
                }
            }
        }
    }

    component Prompt: StyledRect {
        id: prompt

        required property AuthFlow flow
        property bool showPassword

        function submit(): void {
            if (flow.isResponseRequired && passwordField.text.length > 0) {
                flow.submit(passwordField.text);
                passwordField.text = "";
            }
        }

        implicitWidth: 440
        implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainer

        Keys.onEscapePressed: flow.cancelAuthenticationRequest()

        Component.onCompleted: passwordField.forceActiveFocus()

        // Shadow (RectangularShadow, cheaper than a layer effect)
        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        Connections {
            function onAuthenticationFailed(): void {
                passwordField.isError = true;
                passwordField.forceActiveFocus();
            }

            target: prompt.flow
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            spacing: Tokens.spacing.medium

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "admin_panel_settings"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Authentication required")
                font: Tokens.font.title.large
            }

            // Capped, so a long command (e.g. pkexec with many arguments) can't push the buttons off screen
            StyledText {
                Layout.fillWidth: true
                text: prompt.flow.message
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 8
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            StyledTextField {
                id: passwordField

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                enabled: prompt.flow.isResponseRequired
                placeholderText: prompt.flow.inputPrompt.replace(/:\s*$/, "") || Tr.tr("Password")
                leadingIcon: "key"
                trailingIcon: prompt.showPassword || prompt.flow.responseVisible ? "visibility_off" : "visibility"
                trailingIconInteractive: !prompt.flow.responseVisible
                echoMode: prompt.showPassword || prompt.flow.responseVisible ? TextInput.Normal : TextInput.Password
                errorText: prompt.flow.supplementaryMessage || Tr.tr("Wrong password, try again")
                supportingText: prompt.flow.supplementaryIsError ? "" : prompt.flow.supplementaryMessage
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                onAccepted: prompt.submit()
                onTrailingIconClicked: {
                    prompt.showPassword = !prompt.showPassword;
                    forceActiveFocus();
                }
                Keys.onEscapePressed: prompt.flow.cancelAuthenticationRequest()
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.small

                TextButton {
                    isRound: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    type: TextButton.Tonal
                    text: Tr.trCtx("Cancel", "button")
                    onClicked: prompt.flow.cancelAuthenticationRequest()
                }

                TextButton {
                    isRound: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    type: TextButton.Filled
                    disabled: !prompt.flow.isResponseRequired || passwordField.text.length === 0
                    text: Tr.tr("Authenticate")
                    onClicked: prompt.submit()
                }
            }
        }
    }
}
