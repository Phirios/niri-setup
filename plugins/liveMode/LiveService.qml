pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "live.js" as Live

// Follows niri's screencasts. While one runs it switches on Do Not Disturb and the idle
// inhibitor, and gives both back when the last cast ends. Shared by every bar's widget.
Singleton {
    id: root

    readonly property string stateKey: "session"
    readonly property var noSession: ({dnd: false, inhibit: false, startedAt: 0})

    readonly property var casts: Live.activeCasts(NiriService.casts)
    readonly property bool live: casts.length > 0
    readonly property string targetText: live ? Live.describeTarget(casts[0]) : ""
    readonly property string elapsedText: Live.formatElapsed(now - session.startedAt)

    // Set by the widgets from the plugin settings.
    property var pluginService: null
    property string pluginId: ""
    property bool silenceNotifications: true
    property bool keepAwake: true

    /** What this share switched on, and when it began. Persisted, so a shell restart keeps it. */
    property var session: noSession
    property int now: nowSecs()

    readonly property bool ownsDnd: session.dnd
    readonly property bool ownsInhibit: session.inhibit

    function nowSecs() {
        return Math.floor(Date.now() / 1000);
    }

    function currentState() {
        return {dnd: SessionData.doNotDisturb, inhibit: SessionService.idleInhibited};
    }

    function attach(service, id, settings) {
        silenceNotifications = settings.silenceNotifications;
        keepAwake = settings.keepAwake;
        if (pluginService)
            return;
        pluginService = service;
        pluginId = id;
        session = Object.assign({}, noSession, service.loadPluginState(id, stateKey, noSession));
        sync();
    }

    function remember(next) {
        session = next;
        if (pluginService)
            pluginService.savePluginState(pluginId, stateKey, next);
    }

    function begin() {
        const plan = Live.planStart(session, currentState(), {silence: silenceNotifications, keepAwake: keepAwake});
        if (plan.enable.dnd)
            SessionData.setDoNotDisturb(true, 0);
        // Through the service: setting the session flag alone records the wish without engaging it.
        if (plan.enable.inhibit) {
            SessionService.setInhibitReason("Screen share");
            SessionService.enableIdleInhibit();
        }
        now = nowSecs();
        remember({dnd: plan.owned.dnd, inhibit: plan.owned.inhibit, startedAt: session.startedAt || now});
    }

    function end() {
        const plan = Live.planEnd(session, currentState());
        if (plan.dnd)
            SessionData.setDoNotDisturb(false, 0);
        if (plan.inhibit)
            SessionService.disableIdleInhibit();
        remember(noSession);
    }

    // Also covers a shell that was restarted: a share that ended meanwhile is wound up here.
    function sync() {
        if (!pluginService)
            return;
        if (live)
            begin();
        else if (session.startedAt > 0)
            end();
    }

    onLiveChanged: sync()

    Timer {
        interval: 1000
        repeat: true
        running: root.live
        onTriggered: root.now = root.nowSecs()
    }
}
