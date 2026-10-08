#!/usr/bin/python3
"""Bridge browser/video MPRIS playback to swayidle's logind idle inhibitor."""
import os
import signal
import time

import dbus

PREFIX = 'org.mpris.MediaPlayer2.'
# Dedicated music players deliberately keep their normal idle behavior.
PLAYERS = ('firefox', 'chromium', 'chrome', 'brave', 'vlc', 'mpv',
           'celluloid', 'haruna', 'dragon', 'totem', 'smplayer')


def playing(bus):
    for name in bus.list_names():
        if not name.startswith(PREFIX):
            continue
        player = name[len(PREFIX):].lower()
        if not any(player == p or player.startswith(p + '.') for p in PLAYERS):
            continue
        try:
            props = dbus.Interface(bus.get_object(name, '/org/mpris/MediaPlayer2'),
                                   'org.freedesktop.DBus.Properties')
            if props.Get('org.mpris.MediaPlayer2.Player', 'PlaybackStatus', timeout=1) == 'Playing':
                return True
        except dbus.DBusException:
            continue
    return False


def main():
    session = dbus.SessionBus()
    manager = dbus.Interface(dbus.SystemBus().get_object(
        'org.freedesktop.login1', '/org/freedesktop/login1'),
        'org.freedesktop.login1.Manager')
    fd = None
    running = True

    def stop(*_):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while running:
            active = playing(session)
            if active and fd is None:
                fd = manager.Inhibit('idle', 'video-playback',
                                     'Browser or video player is playing', 'block').take()
                print('Playback active: automatic lock, display-off and suspend inhibited', flush=True)
            elif not active and fd is not None:
                os.close(fd)
                fd = None
                print('Playback paused/stopped: normal idle timers restored', flush=True)
            time.sleep(2)
    finally:
        if fd is not None:
            os.close(fd)


if __name__ == '__main__':
    main()
