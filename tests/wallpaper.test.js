// Run with: node --test tests/wallpaper.test.js
// wallpaper.js is a QML `.pragma library` script, so it has no exports; evaluate it and pick the functions.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test} = require('node:test');

const NAMES = ['isGame', 'isGaming', 'decide', 'mpvpaperArgs', 'mayRetry', 'isCovered', 'ipcPath', 'pauseCommand'];
const source = fs
    .readFileSync(path.join(__dirname, '../plugins/liveWallpaper/wallpaper.js'), 'utf8')
    .replace(/^\.pragma library$/m, '');
const Wallpaper = new Function(`${source}\nreturn {${NAMES.join(', ')}};`)();

const READY = {
    videoPath: '/home/me/Videos/loop.webm',
    onBattery: false, stopOnBattery: true,
    gaming: false, stopWhileGaming: true,
    failures: 0,
};

test('recognises Steam games and gamescope, and nothing else', () => {
    assert.equal(Wallpaper.isGame('steam_app_1142710'), true);
    assert.equal(Wallpaper.isGame('gamescope'), true);
    assert.equal(Wallpaper.isGame('steam'), false);
    assert.equal(Wallpaper.isGame('brave-browser'), false);
    assert.equal(Wallpaper.isGame(null), false);
});

test('a game among the open windows means gaming', () => {
    assert.equal(Wallpaper.isGaming([{app_id: 'kitty'}, {app_id: 'steam_app_261550'}]), true);
    assert.equal(Wallpaper.isGaming([{app_id: 'kitty'}, {app_id: 'steam'}]), false);
    assert.equal(Wallpaper.isGaming(undefined), false);
});

test('plays when nothing speaks against it', () => {
    assert.deepEqual(Wallpaper.decide(READY), {run: true, reason: 'Playing'});
});

test('does not play without a video', () => {
    assert.equal(Wallpaper.decide({...READY, videoPath: ''}).run, false);
    assert.match(Wallpaper.decide({...READY, videoPath: ''}).reason, /no video/i);
});

test('stops on battery only when asked to', () => {
    assert.equal(Wallpaper.decide({...READY, onBattery: true}).run, false);
    assert.match(Wallpaper.decide({...READY, onBattery: true}).reason, /battery/i);
    assert.equal(Wallpaper.decide({...READY, onBattery: true, stopOnBattery: false}).run, true);
});

test('stops while a game runs only when asked to', () => {
    assert.equal(Wallpaper.decide({...READY, gaming: true}).run, false);
    assert.match(Wallpaper.decide({...READY, gaming: true}).reason, /game/i);
    assert.equal(Wallpaper.decide({...READY, gaming: true, stopWhileGaming: false}).run, true);
});

test('gives up after repeated crashes instead of restarting forever', () => {
    assert.equal(Wallpaper.mayRetry(2), true);
    assert.equal(Wallpaper.mayRetry(3), false);
    assert.equal(Wallpaper.decide({...READY, failures: 3}).run, false);
    assert.match(Wallpaper.decide({...READY, failures: 3}).reason, /keeps failing/i);
});

test('builds the mpvpaper command for one output, with a control socket', () => {
    assert.deepEqual(
        Wallpaper.mpvpaperArgs('/usr/bin/mpvpaper', 'HDMI-A-1', '/v/loop.webm', '/run/user/1000/lw-HDMI-A-1.sock'),
        ['/usr/bin/mpvpaper',
            '--mpv-options',
            'no-audio loop hwdec=auto-safe panscan=1.0 no-osc no-input-default-bindings '
                + 'input-ipc-server=/run/user/1000/lw-HDMI-A-1.sock',
            'HDMI-A-1', '/v/loop.webm']);
});

test('never uses mpvpaper\'s own auto-pause, which misreads niri windows', () => {
    const args = Wallpaper.mpvpaperArgs('/usr/bin/mpvpaper', 'eDP-1', '/v/loop.webm', '/tmp/x.sock');
    assert.equal(args.some(arg => arg.startsWith('--auto')), false);
});

test('gives each output its own control socket', () => {
    assert.equal(Wallpaper.ipcPath('/run/user/1000', 'eDP-1'), '/run/user/1000/live-wallpaper-eDP-1.sock');
});

const WORKSPACES = [
    {output: 'eDP-1', is_active: true, active_window_id: 30},
    {output: 'eDP-1', is_active: false, active_window_id: null},
    {output: 'HDMI-A-1', is_active: true, active_window_id: null},
    {output: 'HDMI-A-1', is_active: false, active_window_id: 11},
];

test('an output is covered when its visible workspace has a window', () => {
    assert.equal(Wallpaper.isCovered(WORKSPACES, 'eDP-1', false), true);
});

test('windows on other workspaces or other outputs do not cover an output', () => {
    assert.equal(Wallpaper.isCovered(WORKSPACES, 'HDMI-A-1', false), false);
});

test('the overview shows the wallpaper, so nothing counts as covered there', () => {
    assert.equal(Wallpaper.isCovered(WORKSPACES, 'eDP-1', true), false);
});

test('an output niri does not report is treated as visible', () => {
    assert.equal(Wallpaper.isCovered(WORKSPACES, 'DP-3', false), false);
    assert.equal(Wallpaper.isCovered(undefined, 'eDP-1', false), false);
});

test('writes one JSON line that sets mpv\'s pause property', () => {
    assert.equal(Wallpaper.pauseCommand(true), '{"command":["set_property","pause",true]}\n');
    assert.equal(Wallpaper.pauseCommand(false), '{"command":["set_property","pause",false]}\n');
});
