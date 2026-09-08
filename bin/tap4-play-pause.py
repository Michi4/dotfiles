#!/usr/bin/env python3
"""tap4-play-pause.py - raw-evdev 4-finger tap detector -> playerctl play-pause.

Why raw evdev: libinput has no 4-finger-tap event (only 1-finger tap-to-click),
Touchégg never recognized taps on this ELAN pad, and sway only offers hold
(which needs dwell time). The kernel reports the 4 contacts just fine, so we
detect the tap ourselves: exactly 4 slots down+up quickly with minimal movement.
Quick swipes are excluded via the movement threshold; slow holds are excluded
via the duration cap (those are sway's hold:4 territory).
"""
import glob
import os
import subprocess
import sys
import time
import traceback

import evdev
from evdev import ecodes

NAME_HINTS = ("Touchpad", "04F3:31D1")
TAP_FINGERS = 4
MAX_TAP_S = 0.35
MOVE_MM = 8.0
MOVE_RAW_FALLBACK = 200
COOLDOWN_S = 0.8


def log(*a):
    print("[tap4]", *a, flush=True)


def find_device():
    for path in sorted(glob.glob("/dev/input/event*")):
        try:
            dev = evdev.InputDevice(path)
            if all(h in dev.name for h in NAME_HINTS):
                return dev
        except OSError:
            continue
    return None


def fire():
    log("TAP detected -> play-pause")
    subprocess.run(["/usr/bin/playerctl", "play-pause"])


def watch(dev):
    caps = dev.capabilities()
    absinfo = {c: v for c, v in caps.get(ecodes.EV_ABS, [])}
    res_x = None
    if ecodes.ABS_MT_POSITION_X in absinfo:
        res_x = absinfo[ecodes.ABS_MT_POSITION_X].resolution or None
    move_thr = (MOVE_MM * res_x) if res_x else MOVE_RAW_FALLBACK
    log("watching %s (%s), move_thr=%.0f units" % (dev.path, dev.name, move_thr))

    slot = 0
    tracking = {}   # slot -> tracking id or None
    pos = {}        # slot -> (x, y)
    cur = {}        # slot -> value being built before SYN
    n_active = 0
    max_seen = 0
    t0 = 0.0
    start_pos = {}
    max_move = 0.0
    last_fire = 0.0

    def settle():
        nonlocal n_active, max_seen, t0, start_pos, max_move, last_fire
        active = {s for s, t in tracking.items() if t is not None and t >= 0}
        n_active = len(active)
        if n_active > 0 and max_seen == 0:
            t0 = time.monotonic()
            start_pos = {s: pos.get(s, (0, 0)) for s in active}
            max_move = 0.0
        if n_active > max_seen:
            max_seen = n_active
            for s in active:
                start_pos.setdefault(s, pos.get(s, (0, 0)))
        for s in active:
            x0, y0 = start_pos.get(s, pos.get(s, (0, 0)))
            x1, y1 = pos.get(s, (x0, y0))
            max_move = max(max_move, abs(x1 - x0) + abs(y1 - y0))
        if n_active == 0 and max_seen > 0:
            dur = time.monotonic() - t0
            log("touch seq: fingers=%d dur=%.0fms move=%.0f (thr %.0f)"
                % (max_seen, dur * 1000, max_move, move_thr))
            now = time.monotonic()
            if (max_seen == TAP_FINGERS and dur <= MAX_TAP_S
                    and max_move <= move_thr and now - last_fire >= COOLDOWN_S):
                last_fire = now
                fire()
            max_seen = 0

    for ev in dev.read_loop():
        if ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_MT_SLOT:
            slot = ev.value
        elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_MT_TRACKING_ID:
            tracking[slot] = ev.value if ev.value >= 0 else None
        elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_MT_POSITION_X:
            x, y = pos.get(slot, (0, 0))
            pos[slot] = (ev.value, y)
        elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_MT_POSITION_Y:
            x, y = pos.get(slot, (0, 0))
            pos[slot] = (x, ev.value)
        elif ev.type == ecodes.EV_SYN:
            settle()


def main():
    while True:
        dev = find_device()
        if dev is None:
            log("no touchpad found, retrying in 3s")
            time.sleep(3)
            continue
        try:
            watch(dev)
        except OSError as ex:
            log("device lost (%s), rescanning" % ex)
            time.sleep(2)
        except Exception:
            traceback.print_exc()
            time.sleep(2)


if __name__ == "__main__":
    main()
