import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "wallpaper.js" as Wallpaper

// One long-lived Qt video player owns the visible wallpaper. During a switch, the other
// player starts behind it; after the blur transition it becomes the long-lived player.
// Never hand either clip to another decoder mid-playback, which would replay frames.
PluginComponent {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string videoPath: expandHome(pluginData.videoPath || "")
    readonly property bool pauseWhenHidden: pluginData.pauseWhenHidden !== false
    readonly property bool stopOnBattery: pluginData.stopOnBattery !== false
    readonly property bool stopWhileGaming: pluginData.stopWhileGaming !== false

    readonly property bool onBattery: BatteryService.batteryAvailable && !BatteryService.isPluggedIn
    readonly property bool gaming: Wallpaper.isGaming(NiriService.windows)
    property int failures: 0
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
    onDecisionChanged: console.info("LiveWallpaper:", decision.reason)

    IpcHandler {
        target: "liveWallpaper"

        function select(path: string): string {
            if (!path || !/\.(mp4|webm|mkv|mov)$/i.test(path))
                return "INVALID_VIDEO_PATH";
            const prefs = Object.assign({}, SettingsData.screenPreferences || {});
            prefs.wallpaper = [];
            SettingsData.set("screenPreferences", prefs);
            root.pluginService.savePluginData(root.pluginId, "videoPath", root.expandHome(path));
            return "VIDEO_SELECTED";
        }
    }

    // Clear a player left by the previous mpvpaper-based plugin on the first load.
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

            readonly property bool paused: root.pauseWhenHidden
                && Wallpaper.isCovered(NiriService.allWorkspaces, modelData.name, NiriService.inOverview)
            property int activeSlot: 0
            property string playingPath: ""
            property string transitionTarget: ""
            property string queuedPath: ""
            property bool readyA: false
            property bool readyB: false
            property bool transitioning: false

            function mediaFor(slot) { return slot === 0 ? mediaA : mediaB; }
            function effectFor(slot) { return slot === 0 ? effectA : effectB; }
            function fileUrl(path) { return "file://" + encodeURI(path); }

            function clearAll() {
                transitionEnter.stop();
                prepareDeadline.stop();
                retry.stop();
                mediaA.stop();
                mediaB.stop();
                mediaA.source = "";
                mediaB.source = "";
                wallpaperWindow.visible = false;
                playingPath = "";
                transitionTarget = "";
                queuedPath = "";
                transitioning = false;
                readyA = false;
                readyB = false;
                activeSlot = 0;
            }

            function startInitial(path) {
                if (!path || !root.shouldRun)
                    return;
                activeSlot = 0;
                readyA = false;
                effectA.blur = 0;
                effectA.opacity = 1;
                effectB.opacity = 0;
                playingPath = path;
                mediaA.source = fileUrl(path);
                mediaA.play();
            }

            function requestVideo(path) {
                if (!root.shouldRun || !path)
                    return;
                if (!playingPath) {
                    startInitial(path);
                    return;
                }
                if (path === transitionTarget || (!transitionTarget && path === playingPath))
                    return;
                if (transitionTarget || transitioning) {
                    queuedPath = path;
                    return;
                }
                const nextSlot = 1 - activeSlot;
                const nextMedia = mediaFor(nextSlot);
                const nextEffect = effectFor(nextSlot);
                transitionTarget = path;
                if (nextSlot === 0)
                    readyA = false;
                else
                    readyB = false;
                nextMedia.stop();
                nextMedia.source = "";
                nextEffect.blur = 1;
                nextEffect.opacity = 1;
                effectFor(activeSlot).blur = 0;
                effectFor(activeSlot).opacity = 1;
                nextMedia.source = fileUrl(path);
                nextMedia.play();
                prepareDeadline.restart();
            }

            function maybeStartTransition() {
                if (!transitionTarget || transitioning)
                    return;
                if (!(activeSlot === 0 ? readyB : readyA))
                    return;
                prepareDeadline.stop();
                transitioning = true;
                transitionEnter.start();
            }

            function syncPlayback() {
                if (!root.shouldRun)
                    return;
                const currentReady = activeSlot === 0 ? readyA : readyB;
                if (paused && currentReady && !transitioning && !transitionTarget)
                    mediaFor(activeSlot).pause();
                else
                    mediaFor(activeSlot).play();
            }

            function refresh() {
                if (!root.shouldRun) {
                    clearAll();
                    return;
                }
                if (!playingPath)
                    startInitial(root.videoPath);
                else if (root.videoPath !== playingPath)
                    requestVideo(root.videoPath);
                syncPlayback();
            }

            function mediaFailed(slot, message) {
                console.warn("LiveWallpaper: video failed on", modelData.name, message);
                if (slot !== activeSlot && transitionTarget) {
                    prepareDeadline.stop();
                    transitionTarget = "";
                    transitioning = false;
                    retry.start();
                    return;
                }
                root.failures++;
                clearAll();
                if (root.shouldRun)
                    retry.start();
            }

            Connections {
                target: root
                function onVideoPathChanged() { player.refresh(); }
                function onShouldRunChanged() { player.refresh(); }
            }

            onPausedChanged: syncPlayback()

            Timer {
                id: prepareDeadline
                interval: 2500
                onTriggered: {
                    console.warn("LiveWallpaper: next video did not produce a frame on", player.modelData.name);
                    player.mediaFor(1 - player.activeSlot).stop();
                    player.transitionTarget = "";
                    retry.start();
                }
            }

            Timer {
                id: retry
                interval: 5000
                onTriggered: player.refresh()
            }

            MediaPlayer {
                id: mediaA
                videoOutput: videoA
                loops: MediaPlayer.Infinite
                onErrorOccurred: (error, message) => player.mediaFailed(0, message)
            }

            MediaPlayer {
                id: mediaB
                videoOutput: videoB
                loops: MediaPlayer.Infinite
                onErrorOccurred: (error, message) => player.mediaFailed(1, message)
            }

            PanelWindow {
                id: wallpaperWindow
                screen: player.modelData
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "dms:live-wallpaper"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                color: "black"
                visible: false

                mask: Region { item: Item {} }

                VideoOutput {
                    id: videoA
                    anchors.fill: parent
                    visible: false
                    fillMode: VideoOutput.PreserveAspectCrop
                    Connections {
                        target: videoA.videoSink
                        function onVideoFrameChanged() {
                            if (player.readyA)
                                return;
                            player.readyA = true;
                            if (player.activeSlot === 0 && !player.transitionTarget && root.shouldRun)
                                wallpaperWindow.visible = true;
                            player.syncPlayback();
                            player.maybeStartTransition();
                        }
                    }
                }

                VideoOutput {
                    id: videoB
                    anchors.fill: parent
                    visible: false
                    fillMode: VideoOutput.PreserveAspectCrop
                    Connections {
                        target: videoB.videoSink
                        function onVideoFrameChanged() {
                            if (player.readyB)
                                return;
                            player.readyB = true;
                            if (player.activeSlot === 1 && !player.transitionTarget && root.shouldRun)
                                wallpaperWindow.visible = true;
                            player.syncPlayback();
                            player.maybeStartTransition();
                        }
                    }
                }

                MultiEffect {
                    id: effectA
                    anchors.fill: parent
                    source: videoA
                    z: player.activeSlot === 0 ? 2 : 1
                    blurEnabled: true
                    blurMax: 64
                    blur: 0
                    opacity: 1
                    autoPaddingEnabled: false
                }

                MultiEffect {
                    id: effectB
                    anchors.fill: parent
                    source: videoB
                    z: player.activeSlot === 1 ? 2 : 1
                    blurEnabled: true
                    blurMax: 64
                    blur: 0
                    opacity: 0
                    autoPaddingEnabled: false
                }
            }

            SequentialAnimation {
                id: transitionEnter
                ParallelAnimation {
                    NumberAnimation {
                        target: player.effectFor(player.activeSlot)
                        property: "blur"
                        from: 0; to: 1; duration: 320
                        easing.type: Easing.InOutCubic
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 180 }
                        NumberAnimation {
                            target: player.effectFor(player.activeSlot)
                            property: "opacity"
                            from: 1; to: 0; duration: 140
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
                NumberAnimation {
                    target: player.effectFor(1 - player.activeSlot)
                    property: "blur"
                    from: 1; to: 0; duration: 320
                    easing.type: Easing.InOutCubic
                }
                onFinished: {
                    const oldSlot = player.activeSlot;
                    player.mediaFor(oldSlot).stop();
                    player.mediaFor(oldSlot).source = "";
                    player.effectFor(oldSlot).opacity = 0;
                    player.activeSlot = 1 - oldSlot;
                    player.playingPath = player.transitionTarget;
                    player.transitionTarget = "";
                    player.transitioning = false;
                    player.syncPlayback();
                    if (player.queuedPath && player.queuedPath !== player.playingPath) {
                        const path = player.queuedPath;
                        player.queuedPath = "";
                        Qt.callLater(() => player.requestVideo(path));
                    }
                }
            }
        }
    }
}
