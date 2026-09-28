.pragma library

// Pure helpers for live mode. No QML imports, so tests/ can run them under node.

function activeCasts(casts) {
    return (casts || []).filter(function (cast) { return cast && cast.is_active; });
}

function describeTarget(cast) {
    var target = cast ? cast.target : null;
    if (target && target.Output && target.Output.name)
        return "Screen " + target.Output.name;
    if (target && target.Window)
        return "One window";
    return "Screen share";
}

function pad(value) {
    return value < 10 ? "0" + value : "" + value;
}

function formatElapsed(secs) {
    var total = Math.max(0, Math.floor(secs));
    var hours = Math.floor(total / 3600);
    var mins = Math.floor((total % 3600) / 60);
    var rest = total % 60;
    return hours > 0 ? hours + ":" + pad(mins) + ":" + pad(rest) : mins + ":" + pad(rest);
}

/**
 * What a share switches on. It owns only what it switched on itself, so that the end of the
 * share gives back exactly that and leaves alone what the user had set before.
 * `owned` carries over what an interrupted run (a shell restart) already owned.
 */
function planStart(owned, current, wanted) {
    var enable = {
        dnd: !!wanted.silence && !current.dnd,
        inhibit: !!wanted.keepAwake && !current.inhibit
    };
    return {
        enable: enable,
        owned: {dnd: !!owned.dnd || enable.dnd, inhibit: !!owned.inhibit || enable.inhibit}
    };
}

/** What the end of a share switches off: only what it owns and what is still on. */
function planEnd(owned, current) {
    return {
        dnd: !!owned.dnd && !!current.dnd,
        inhibit: !!owned.inhibit && !!current.inhibit
    };
}

// custom/privacy.kdl is a switch: it either includes privacy-rules.kdl or includes nothing.
// niri reloads it on change, so rewriting it turns the screen-share rules on or off at once.
var PRIVACY_INCLUDE = 'include optional=true "privacy-rules.kdl"';

function privacySwitchText(on) {
    var header = "// Written by the Live Mode plugin; use its switch in the bar instead of editing this.\n"
        + "// The rules themselves are in privacy-rules.kdl.\n";
    return header + (on ? PRIVACY_INCLUDE : "// hiding is switched off") + "\n";
}

function isPrivacyOn(text) {
    return (text || "").split("\n").some(function (line) { return line.trim() === PRIVACY_INCLUDE; });
}
