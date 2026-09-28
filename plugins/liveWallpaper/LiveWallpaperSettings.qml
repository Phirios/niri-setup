import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "liveWallpaper"

    StringSetting {
        settingKey: "videoPath"
        label: "Video"
        description: "A video file. Playback and hardware decoding use Qt Multimedia."
        placeholder: "~/Videos/Wallpapers/loop.webm"
    }

    ToggleSetting {
        settingKey: "pauseWhenHidden"
        label: "Pause when covered"
        description: "Pause on a monitor while its workspace has windows; play on empty workspaces and in the overview"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "stopOnBattery"
        label: "Stop on battery"
        description: "Show the still wallpaper while the laptop is unplugged"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "stopWhileGaming"
        label: "Stop while gaming"
        description: "Stop while a Steam game or gamescope is running"
        defaultValue: true
    }
}
