#!/usr/bin/env python3
"""Directional rectangle donation, retaining Hyprland's native Dwindle layout."""
import argparse
import copy
import fcntl
from fractions import Fraction
import json
import os
from pathlib import Path
import subprocess
import sys
import time

MIN_SIZE = 200
SHARES = tuple(Fraction(n, d) for n, d in [(1,5), (1,4), (1,3), (1,2), (2,3), (3,4), (4,5), (1,1)])
STATE = Path.home() / '.local/state/hypr-smart-resize'


class Refused(Exception):
    pass


def ipc(*args, structured=False):
    p = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=15)
    if p.returncode:
        raise Refused(p.stderr.strip() or p.stdout.strip())
    return json.loads(p.stdout) if structured else p.stdout


def option(name):
    return ipc('getoption', name, '-j', structured=True)


def edges(r):
    return r[0], r[1], r[0] + r[2], r[1] + r[3]


def near(a, b):
    return abs(a-b) < 2


def overlap(a, b, c, d):
    return min(b, d) - max(a, c) > 1


def transform(r, direction, inverse=False):
    x, y, w, h = r
    if direction == 'left':
        return [-x-w, y, w, h]
    if direction == 'down':
        return [y, x, h, w]
    if direction == 'up':
        return [y, -x-w, h, w] if inverse else [-y-h, x, h, w]
    return list(r)


def tree(rects):
    """Recover a guillotine partition, rejecting holes and impossible BSP shapes."""
    if not rects:
        raise Refused('No tiled windows')
    x = min(r[0] for r in rects.values())
    y = min(r[1] for r in rects.values())
    right = max(r[0]+r[2] for r in rects.values())
    bottom = max(r[1]+r[3] for r in rects.values())
    area = [x, y, right-x, bottom-y]
    if abs(sum(r[2]*r[3] for r in rects.values()) - area[2]*area[3]) > 8:
        raise Refused('The requested geometry leaves a hole')
    if len(rects) == 1:
        return {'id': next(iter(rects)), 'box': area}
    for axis in (0, 1):
        ends = sorted({r[axis]+r[axis+2] for r in rects.values()})
        for cut in ends[:-1]:
            lo = {k:r for k,r in rects.items() if r[axis]+r[axis+2] <= cut+0.01}
            hi = {k:r for k,r in rects.items() if r[axis] >= cut-0.01}
            if not lo or not hi or len(lo)+len(hi) != len(rects):
                continue
            ratio = (cut-area[axis])/area[axis+2]
            if not .05 <= ratio <= .95:
                continue
            try:
                a, b = tree(lo), tree(hi)
            except Refused:
                continue
            return {'axis':axis, 'ratio':ratio, 'a':a, 'b':b, 'box':area}
    raise Refused('This rectangle arrangement cannot be represented by Dwindle')


def content(r, root, inset):
    x, y, right, bottom = edges(r)
    rx, ry, rr, rb = edges(root)
    border, gap = inset
    left_i = border + (0 if near(x, rx) else gap)
    right_i = border + (0 if near(right, rr) else gap)
    top_i = border + (0 if near(y, ry) else gap)
    bottom_i = border + (0 if near(bottom, rb) else gap)
    return [x+left_i, y+top_i, right-x-left_i-right_i, bottom-y-top_i-bottom_i]


def check(rects, before, root, inset):
    for k, r in rects.items():
        if r != before[k] and min(content(r, root, inset)[2:]) < MIN_SIZE:
            raise Refused('An affected window would be smaller than 200 px')
    tree(rects)


def plan(before, focused, direction, root, inset=(0, 0), shrink=False, take_all=False):
    rs = {k:transform(r, direction) for k,r in before.items()}
    a = rs[focused]
    ax, ay, ar, ab = edges(a)
    donors = [k for k,r in rs.items() if k != focused and near(r[0], ar)
              and overlap(ay, ab, r[1], r[1]+r[3])]
    if not donors:
        raise Refused('No tiled neighbour in that direction')

    # Move a complete shared divider. Expand its connected receiving windows,
    # shrink every connected donor, and preserve all other edges.
    receivers, donating = {focused}, set(donors)
    changed = True
    while changed:
        changed = False
        for k,r in rs.items():
            y1, y2 = r[1], r[1]+r[3]
            if near(r[0]+r[2], ar) and any(overlap(y1,y2,rs[d][1],rs[d][1]+rs[d][3]) for d in donating):
                if k not in receivers:
                    receivers.add(k); changed = True
            if near(r[0], ar) and any(overlap(y1,y2,rs[d][1],rs[d][1]+rs[d][3]) for d in receivers):
                if k not in donating:
                    donating.add(k); changed = True
    # Ratios describe the local shared span of the active window and its
    # adjacent neighbours. Gaps/borders are applied by Hyprland afterwards.
    shared_span = a[2] + min(rs[k][2] for k in donors)

    def candidate(amount):
        result = copy.deepcopy(rs)
        for k in receivers:
            result[k][2] += amount
        for k in donating:
            result[k][0] += amount
            result[k][2] -= amount
        result = {k:transform(r, direction, True) for k,r in result.items()}
        check(result, before, root, inset)
        return result

    if shrink and take_all:
        raise Refused('Shrink and take-all cannot be combined')
    shares = [Fraction(1)] if take_all else (reversed(SHARES[:-1]) if shrink else SHARES)
    for share in shares:
        amount = float(share)*shared_span-a[2]
        # Client coordinates can be rounded to integers; do not make a tiny
        # second resize when the previous operation already reached this share.
        if (amount >= -2) if shrink else (amount <= 2):
            continue
        if share == 1:
            # The whole row is available only when the neighbour can retain
            # a rectangle above/below it, instead of vanishing.
            if len(donors) != 1:
                continue
            k = donors[0]
            d = rs[k]
            dx, dy, dr, db = edges(d)
            remaining = None
            if take_all or d[2] < d[3]:
                if near(ay, dy) and ab < db-1:
                    remaining = [dx, ab, d[2], db-ab]
                elif near(ab, db) and ay > dy+1:
                    remaining = [dx, dy, d[2], ay-dy]
            if remaining is None:
                continue
            result = copy.deepcopy(rs)
            result[focused][2] = dr-ax
            result[k] = remaining
            result = {i:transform(r, direction, True) for i,r in result.items()}
            try:
                check(result, before, root, inset)
            except Refused:
                continue
            return result, {'mode':'reshape', 'fraction':'1', 'shared_span':shared_span,
                            'amount':round(dr-ar, 4), 'donors':donors}
        try:
            result = candidate(amount)
        except Refused:
            continue
        return result, {'mode':'divider', 'fraction':str(share), 'shared_span':shared_span,
                        'amount':round(amount, 4), 'donors':sorted(donating),
                        'receivers':sorted(receivers)}
    if take_all:
        raise Refused('The neighbour cannot leave a rectangle of at least 200 px after giving up this space')
    size = 'smaller' if shrink else 'larger'
    raise Refused(f'No {size} fraction fits while keeping affected windows at least 200 px')


def snapshot():
    active = ipc('activewindow', '-j', structured=True)
    if not active or active.get('floating') or active.get('fullscreen'):
        raise Refused('Focus a tiled, non-fullscreen window')
    if active['workspace']['id'] <= 0:
        raise Refused('Special workspaces are not supported')
    if option('general:layout').get('str') != 'dwindle':
        raise Refused('This shortcut requires Dwindle')
    if not option('dwindle:preserve_split')['bool'] or not option('dwindle:use_active_for_splits')['bool']:
        raise Refused('Dwindle needs preserve_split and use_active_for_splits enabled')
    windows = [w for w in ipc('clients', '-j', structured=True)
               if w['workspace']['id'] == active['workspace']['id'] and w['mapped'] and not w['floating']]
    if any(w.get('grouped') or w.get('fullscreen') or w['monitor'] != active['monitor'] for w in windows):
        raise Refused('Grouped/fullscreen windows or mixed monitors are not supported')
    css = option('general:gaps_in')['css'].split()
    if len(set(css)) != 1:
        raise Refused('Asymmetric gaps are not supported')
    gap, border = float(css[0]), option('general:border_size')['int']
    raw = {w['address']:w['at']+w['size'] for w in windows}
    rx = min(r[0] for r in raw.values())-border
    ry = min(r[1] for r in raw.values())-border
    rr = max(r[0]+r[2] for r in raw.values())+border
    rb = max(r[1]+r[3] for r in raw.values())+border
    root = [rx, ry, rr-rx, rb-ry]
    rects = {}
    for k,r in raw.items():
        x,y,right,bottom = edges(r)
        x -= border + (0 if near(x-border, rx) else gap)
        y -= border + (0 if near(y-border, ry) else gap)
        right += border + (0 if near(right+border, rr) else gap)
        bottom += border + (0 if near(bottom+border, rb) else gap)
        rects[k] = [x,y,right-x,bottom-y]
    tree(rects)
    return {'rects':rects, 'raw':raw, 'root':root, 'inset':[border,gap],
            'focused':active['address'], 'workspace':active['workspace']['id'],
            'titles':{w['address']:w['title'] for w in windows}}


def seed(t):
    return t['id'] if 'id' in t else seed(t['a'])


def commands(rects, focused):
    t = tree(rects)
    anchor = seed(t)
    def focus(k):
        return 'run(hl.dsp.focus({window=' + json.dumps('address:'+k) + '}))'

    def floating(k, enabled):
        return ('run(hl.dsp.window.float({action=' + json.dumps('on' if enabled else 'off')
                + ',window=' + json.dumps('address:'+k) + '}))')

    def layout(msg):
        return 'run(hl.dsp.layout(' + json.dumps(msg) + '))'

    # Detach from the tile tree without leaving the visible workspace. A single
    # IPC evaluation keeps the temporary floating geometry out of rendered frames.
    result = [floating(k, True) for k in rects if k != anchor]
    # Also normalize the anchor in case this rebuild is recovering a failed one.
    result.append(floating(anchor, False))

    def build(node):
        if 'id' in node:
            return
        left, right = seed(node['a']), seed(node['b'])
        direction = 'r' if node['axis'] == 0 else 'd'
        result.extend([focus(left), layout('preselect '+direction), floating(right, False),
                       focus(right), layout(f'splitratio {2*node["ratio"]:.9f} exact')])
        build(node['a']); build(node['b'])
    build(t)
    result += [layout('preselect none'), focus(focused)]
    return result


def rebuild(snap, rects):
    run = 'local function run(d) local r=hl.dispatch(d); if not r.ok then error(r.error or "Dispatch failed") end end\n'
    result = ipc('eval', run + '\n'.join(commands(rects, snap['focused'])))
    lines = result.splitlines()
    if any(line.strip() != 'ok' for line in lines if line.strip()):
        raise Refused('Hyprland rejected a layout command: ' + result[:400])


def verify(snap, rects):
    expected = {k:content(r, snap['root'], snap['inset']) for k,r in rects.items()}
    for _ in range(20):
        clients = {w['address']:w for w in ipc('clients', '-j', structured=True)}
        if all(k in clients and not clients[k]['floating']
               and clients[k]['workspace']['id'] == snap['workspace']
               and (r == content(snap['rects'][k], snap['root'], snap['inset'])
                    or min(clients[k]['size']) >= MIN_SIZE)
               and max(abs(a-b) for a,b in zip(clients[k]['at']+clients[k]['size'], r)) <= 2
               for k,r in expected.items()):
            return
        time.sleep(.05)
    raise Refused('Observed window geometry does not match the calculated layout')


def apply(snap, rects):
    # Detect windows added, removed, moved, or resized during planning.
    current = snapshot()
    if current['raw'] != snap['raw'] or current['focused'] != snap['focused']:
        raise Refused('The layout changed during planning; try again')
    try:
        rebuild(snap, rects)
        verify(snap, rects)
    except Exception:
        rebuild(snap, snap['rects'])
        verify(snap, snap['rects'])
        raise
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE/'undo.json').write_text(json.dumps({'before':snap, 'after':rects}, indent=2))


def notify(message):
    subprocess.run(['notify-send', '-a', 'Window resize', 'Window resize', message],
                   capture_output=True, timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('direction', choices=['left','right','up','down','undo'])
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--shrink', action='store_true', help='Retract this edge to the next smaller fraction')
    parser.add_argument('--take-all', action='store_true', help='Take the whole adjacent span if the neighbour can retain a rectangle')
    parser.add_argument('--notify', action='store_true')
    args = parser.parse_args()
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE/'lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        snap = snapshot()
        if args.direction == 'undo':
            saved = json.loads((STATE/'undo.json').read_text())
            verify(saved['before'], saved['after'])
            if snap['workspace'] != saved['before']['workspace'] or set(snap['rects']) != set(saved['after']):
                raise Refused('Windows changed since the last resize; undo refused')
            desired, details = saved['before']['rects'], {'mode':'undo'}
        else:
            desired, details = plan(snap['rects'], snap['focused'], args.direction, snap['root'], snap['inset'], shrink=args.shrink, take_all=args.take_all)
        review = {'direction':args.direction, 'shrink':args.shrink, 'take_all':args.take_all, **details, 'windows':[
            {'title':snap['titles'][k], 'before':snap['raw'][k],
             'after':[round(v,2) for v in content(r,snap['root'],snap['inset'])]}
            for k,r in desired.items() if r != snap['rects'][k]]}
        if not args.dry_run:
            apply(snap, desired)
        print(json.dumps(review, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (Refused, OSError, KeyError, ValueError, subprocess.TimeoutExpired) as exc:
        if '--notify' in sys.argv:
            notify(str(exc))
        print(str(exc), file=sys.stderr)
        sys.exit(1)
