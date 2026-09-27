import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "liveMode"

    ToggleSetting {
        settingKey: "silenceNotifications"
        label: "Silence notifications"
        description: "Switch on Do Not Disturb while the screen is shared, and off again afterwards"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "keepAwake"
        label: "Keep the screen awake"
        description: "Hold off the idle lock and screen-off while the screen is shared"
        defaultValue: true
    }
}
