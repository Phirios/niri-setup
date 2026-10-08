// Run with: node --test tests/live.test.js
// live.js is a QML `.pragma library` script, so it has no exports; evaluate it and pick the functions.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test} = require('node:test');

const NAMES = ['activeCasts', 'describeTarget', 'formatElapsed', 'planStart', 'planEnd'];
const source = fs
    .readFileSync(path.join(__dirname, '../plugins/liveMode/live.js'), 'utf8')
    .replace(/^\.pragma library$/m, '');
const Live = new Function(`${source}\nreturn {${NAMES.join(', ')}};`)();

const NOTHING_OWNED = {dnd: false, inhibit: false};
const BOTH_WANTED = {silence: true, keepAwake: true};

test('only casts that are running count as live', () => {
    const casts = [{stream_id: 1, is_active: false}, {stream_id: 2, is_active: true}];
    assert.deepEqual(Live.activeCasts(casts).map(cast => cast.stream_id), [2]);
    assert.deepEqual(Live.activeCasts(undefined), []);
});

test('names what is being shared', () => {
    assert.equal(Live.describeTarget({target: {Output: {name: 'HDMI-A-1'}}}), 'Screen HDMI-A-1');
    assert.equal(Live.describeTarget({target: {Window: {id: 12}}}), 'One window');
    assert.equal(Live.describeTarget({target: 'Nothing'}), 'Screen share');
    assert.equal(Live.describeTarget(undefined), 'Screen share');
});

test('formats how long the share has been running', () => {
    assert.equal(Live.formatElapsed(7), '0:07');
    assert.equal(Live.formatElapsed(754), '12:34');
    assert.equal(Live.formatElapsed(3723), '1:02:03');
    assert.equal(Live.formatElapsed(-5), '0:00');
});

test('a share switches on what is wanted and takes ownership of it', () => {
    const plan = Live.planStart(NOTHING_OWNED, {dnd: false, inhibit: false}, BOTH_WANTED);
    assert.deepEqual(plan.enable, {dnd: true, inhibit: true});
    assert.deepEqual(plan.owned, {dnd: true, inhibit: true});
});

test('what the user had already switched on is left alone and not owned', () => {
    const plan = Live.planStart(NOTHING_OWNED, {dnd: true, inhibit: false}, BOTH_WANTED);
    assert.deepEqual(plan.enable, {dnd: false, inhibit: true});
    assert.deepEqual(plan.owned, {dnd: false, inhibit: true});
});

test('settings that are switched off are never touched', () => {
    const plan = Live.planStart(NOTHING_OWNED, {dnd: false, inhibit: false}, {silence: false, keepAwake: false});
    assert.deepEqual(plan.enable, {dnd: false, inhibit: false});
    assert.deepEqual(plan.owned, NOTHING_OWNED);
});

test('ownership survives a shell restart in the middle of a share', () => {
    const plan = Live.planStart({dnd: true, inhibit: true}, {dnd: true, inhibit: true}, BOTH_WANTED);
    assert.deepEqual(plan.enable, {dnd: false, inhibit: false});
    assert.deepEqual(plan.owned, {dnd: true, inhibit: true});
});

test('the end of a share switches off only what it switched on', () => {
    assert.deepEqual(
        Live.planEnd({dnd: true, inhibit: false}, {dnd: true, inhibit: true}),
        {dnd: true, inhibit: false});
});

test('something the user switched off during the share is not switched off again', () => {
    assert.deepEqual(
        Live.planEnd({dnd: true, inhibit: true}, {dnd: false, inhibit: true}),
        {dnd: false, inhibit: true});
});

test('planning does not modify its inputs', () => {
    const owned = {dnd: false, inhibit: false};
    Live.planStart(owned, {dnd: false, inhibit: false}, BOTH_WANTED);
    assert.deepEqual(owned, {dnd: false, inhibit: false});
});

