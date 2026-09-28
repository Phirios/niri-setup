import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "wallpaper.js" as Wallpaper

// Runs one mpvpaper per monitor while the video should be playing. The still wallpaper that
// DMS draws stays underneath, so stopping the video simply reveals it.
PluginComponent {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string videoPath: expandHome(pluginData.videoPath || "")
    readonly property string mpvpaperPath: expandHome(pluginData.mpvpaperPath || "~/.local/bin/mpvpaper")
    readonly property bool pauseWhenHidden: pluginData.pauseWhenHidden !== false
    readonly property bool stopOnBattery: pluginData.stopOnBattery !== false
    readonly property bool stopWhileGaming: pluginData.stopWhileGaming !== false

    readonly property bool onBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property bool gaming: Wallpaper.isGaming(NiriService.windows)

    /** Crashes in a row; reset whenever the settings change. */
    property int failures: 0
    /** False until players left behind by an earlier shell have been cleared away. */
    property bool ready: false

    readonly property var decision: Wallpaper.decide({
        videoPath: videoPath,
        onBattery: onBattery,
        stopOnBattery: stopOnBattery,
        gaming: gaming,
        stopWhileGaming: stopWhileGaming,
        failures: failures
    })
    readonly property bool shouldRun: ready && decision.run

    function expandHome(path) {
        const trimmed = path.trim();
        if (trimmed === "~")
            return home;
        return trimmed.indexOf("~/") === 0 ? home + trimmed.slice(1) : trimmed;
    }

    onVideoPathChanged: failures = 0
    onMpvpaperPathChanged: failures = 0
    onDecisionChanged: console.info("LiveWallpaper:", decision.reason)

    // A shell that was killed leaves its players running, and they would stack up.
    Process {
        running: true
        command: ["pkill", "-x", "mpvpaper"]
        onExited: root.ready = true
    }

    Variants {
        model: Quickshell.screens

        Item {
            id: player

            required property var modelData
            property real startedAt: 0

            readonly property string socketPath: Wallpaper.ipcPath(root.runtimeDir, modelData.name)
            readonly property bool paused: root.pauseWhenHidden
                && Wallpaper.isCovered(NiriService.allWorkspaces, modelData.name, NiriService.inOverview)

            function sendPause() {
                if (control.connected)
                    control.write(Wallpaper.pauseCommand(paused));
            }

            // Switching through DMS should be immediate. Updating Process.command alone does
            // not restart a running mpvpaper, so tell its mpv child to load the new file.
            Connections {
                target: root
                function onVideoPathChanged() {
                    if (control.connected && root.videoPath) {
                        control.write(Wallpaper.loadCommand(root.videoPath));
                        return;
                    }
                    videoReload.restart();
                }
            }

            Timer {
                id: videoReload
                interval: 100
            }

            onPausedChanged: sendPause()

            // mpv's control socket. It appears a moment after mpvpaper starts, so connecting is
            // retried until it succeeds; the current pause state is sent on every connect.
            Socket {
                id: control

                path: player.socketPath
                onConnectionStateChanged: {
                    if (connected)
                        player.sendPause();
                }
            }

            Timer {
                interval: 500
                repeat: true
                running: mpvpaper.running && !control.connected
                onTriggered: control.connected = true
            }

            Process {
                id: mpvpaper

                command: Wallpaper.mpvpaperArgs(root.mpvpaperPath, player.modelData.name, root.videoPath, player.socketPath)
                running: root.shouldRun && !restart.running && !videoReload.running
                onStarted: player.startedAt = Date.now()
                onRunningChanged: {
                    if (!running)
                        control.connected = false;
                    // Still wanted but gone: it crashed, or could not be started at all.
                    if (running || !root.shouldRun || videoReload.running)
                        return;
                    const livedLong = player.startedAt > 0 && Date.now() - player.startedAt > restart.interval * 6;
                    root.failures = livedLong ? 1 : root.failures + 1;
                    player.startedAt = 0;
                    console.warn("LiveWallpaper: mpvpaper stopped on", player.modelData.name);
                    restart.start();
                }
            }

            Timer {
                id: restart

                interval: 5000
            }
        }
    }
}
