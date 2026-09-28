.pragma library

// Pure helpers for the live wallpaper. No QML imports, so tests/ can run them under node.

var GAME_APP_ID = /^(steam_app_\d+|gamescope)$/;
/** Crashes in a row after which the wallpaper stays off until the settings change. */
var MAX_FAILURES = 3;
var MPV_OPTIONS = "no-audio loop hwdec=auto-safe panscan=1.0 no-osc no-input-default-bindings";

function isGame(appId) {
    return typeof appId === "string" && GAME_APP_ID.test(appId);
}

function isGaming(windows) {
    return (windows || []).some(function (window) { return isGame(window.app_id); });
}

function mayRetry(failures) {
    return failures < MAX_FAILURES;
}

/** Whether the video should be playing right now, and the reason shown in the settings. */
function decide(state) {
    if (!state.videoPath)
        return {run: false, reason: "No video chosen"};
    if (!mayRetry(state.failures))
        return {run: false, reason: "mpvpaper keeps failing; check the video path, then save the settings again"};
    if (state.stopOnBattery && state.onBattery)
        return {run: false, reason: "Paused on battery"};
    if (state.stopWhileGaming && state.gaming)
        return {run: false, reason: "Stopped while a game is running"};
    return {run: true, reason: "Playing"};
}

/**
 * mpvpaper's own --auto-pause is not used: with --auto-mode it pauses for any window niri
 * reports, on any workspace, and without it it never pauses on niri at all. Pausing goes
 * through mpv's control socket instead, driven by isCovered().
 */
function mpvpaperArgs(binary, output, videoPath, socketPath) {
    return [binary, "--mpv-options", MPV_OPTIONS + " input-ipc-server=" + socketPath, output, videoPath];
}

function ipcPath(runtimeDir, output) {
    return runtimeDir + "/live-wallpaper-" + output + ".sock";
}

/** Whether windows hide the wallpaper on an output: its visible workspace has a window. */
function isCovered(workspaces, output, inOverview) {
    if (inOverview)
        return false;
    return (workspaces || []).some(function (workspace) {
        return workspace.output === output && workspace.is_active && workspace.active_window_id !== null
            && workspace.active_window_id !== undefined;
    });
}

function pauseCommand(paused) {
    return JSON.stringify({command: ["set_property", "pause", paused]}) + "\n";
}

function loadCommand(videoPath) {
    return JSON.stringify({command: ["loadfile", videoPath, "replace"]}) + "\n";
}
