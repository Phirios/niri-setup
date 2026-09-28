import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Bar pill that only exists while the screen is shared, and a panel that says what the
// share changed. State and the automation live in LiveService.
PluginComponent {
    id: root

    readonly property color liveColor: "#f87171"
    readonly property bool live: LiveService.live
    readonly property var settings: ({
        silenceNotifications: pluginData.silenceNotifications !== false,
        keepAwake: pluginData.keepAwake !== false
    })

    function attach() {
        if (pluginService && pluginId)
            LiveService.attach(pluginService, pluginId, settings);
    }

    onLiveChanged: setVisibilityOverride(live)
    onSettingsChanged: attach()
    onPluginServiceChanged: attach()
    onPluginIdChanged: attach()
    Component.onCompleted: {
        setVisibilityOverride(live);
        attach();
    }

    component LiveDot: Rectangle {
        id: dot

        width: 8
        height: 8
        radius: 4

        SequentialAnimation on opacity {
            running: dot.visible
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.3
                duration: 800
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 800
                easing.type: Easing.InOutSine
            }
        }
    }

    component StateRow: Row {
        id: row

        required property string icon
        required property string title
        required property string detail
        property bool active: true
        /** Shows a switch on the right when set; called with the new state. */
        property var toggleAction: null

        readonly property real textWidth: width - Theme.iconSize - Theme.spacingM
            - (toggleAction ? toggle.width + Theme.spacingM : 0)

        spacing: Theme.spacingM

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            size: Theme.iconSize - 4
            color: row.active ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.4)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: row.textWidth
            spacing: 2

            StyledText {
                width: parent.width
                text: row.title
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: row.detail
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(Theme.surfaceText, 0.55)
                wrapMode: Text.WordWrap
            }
        }

        DankToggle {
            id: toggle

            anchors.verticalCenter: parent.verticalCenter
            visible: !!row.toggleAction
            hideText: true
            checked: row.active
            onToggled: checked => row.toggleAction(checked)
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS + 2

            LiveDot {
                anchors.verticalCenter: parent.verticalCenter
                color: root.liveColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "LIVE"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                font.letterSpacing: 1
                color: root.liveColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: LiveService.elapsedText
                font.pixelSize: Theme.fontSizeSmall
                font.features: ({"tnum": 1})
                color: Theme.withAlpha(Theme.surfaceText, 0.7)
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            LiveDot {
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.liveColor
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "LIVE"
                font.pixelSize: Theme.fontSizeSmall - 2
                font.weight: Font.Bold
                color: root.liveColor
            }
        }
    }

    popoutWidth: 340

    popoutContent: Component {
        Column {
            id: panel

            readonly property real innerWidth: width - leftPadding - rightPadding

            padding: Theme.spacingS
            spacing: Theme.spacingM + 2

            Item {
                width: panel.innerWidth
                height: title.implicitHeight

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    LiveDot {
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.liveColor
                    }

                    StyledText {
                        id: title

                        text: "You are live"
                        font.pixelSize: Theme.fontSizeLarge + 2
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: LiveService.elapsedText
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight: Font.Bold
                    font.features: ({"tnum": 1})
                    color: root.liveColor
                }
            }

            StateRow {
                width: panel.innerWidth
                icon: "cast"
                title: LiveService.targetText
                detail: LiveService.casts.length > 1 ? LiveService.casts.length + " shares are running" : "Viewers see this, minus what is hidden below"
            }

            Rectangle {
                width: panel.innerWidth
                height: 1
                color: Theme.withAlpha(Theme.surfaceText, 0.07)
            }

            StateRow {
                width: panel.innerWidth
                icon: SessionData.doNotDisturb ? "notifications_off" : "notifications"
                active: SessionData.doNotDisturb
                title: SessionData.doNotDisturb ? "Notifications are silenced" : "Notifications are on"
                detail: {
                    if (!SessionData.doNotDisturb)
                        return "Viewers may see notifications pop up";
                    if (LiveService.ownsDnd)
                        return "Switched on for this share, off again when it ends";
                    return "You had this on already, so it stays on";
                }
                toggleAction: on => LiveService.setSilenced(on)
            }

            StateRow {
                width: panel.innerWidth
                icon: "coffee"
                active: SessionService.idleInhibited
                title: SessionService.idleInhibited ? "Screen stays awake" : "Screen may lock when idle"
                detail: {
                    if (!SessionService.idleInhibited)
                        return "The lock screen can come up during the share";
                    if (LiveService.ownsInhibit)
                        return "Held for this share, released when it ends";
                    return "You had this on already, so it stays on";
                }
                toggleAction: on => LiveService.setAwake(on)
            }

            StateRow {
                width: panel.innerWidth
                icon: LiveService.privacyOn ? "visibility_off" : "visibility"
                active: LiveService.privacyOn
                title: LiveService.privacyOn ? "Private surfaces are hidden" : "Everything is visible"
                detail: LiveService.privacyOn
                    ? "Chat, notifications, clipboard and password prompts show as black. Stays set after the share."
                    : "Viewers see the AI chat, notifications and clipboard too"
                toggleAction: on => LiveService.setPrivacy(on)
            }
        }
    }
}
