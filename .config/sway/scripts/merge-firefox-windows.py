#!/usr/bin/env python3
"""merge-firefox-windows.py - Normalize Firefox sessionstore to canonical windows.

Canonical layout:
  MAIN  (visible, workspace 5): collaboration.koerbler.com (Zulip), support.brunner.at, aistudio.google.com
  STASH (scratchpad):           web.whatsapp.com, kimai.bwh.at, managedwp.at, md.home.websters.at (HedgeDoc), vikunja.bwh.at

- Tabs keep their full objects (history/scroll/form state preserved), only regrouped + reordered.
- Windows with no known tabs are left untouched.
- Selected tab is set deterministically so sway title-matching works at boot:
    MAIN  -> Zulip tab (title matches .*Zulip.*), STASH -> WhatsApp tab (.*WhatsApp.*)
- Only rewrites the file if a merge/split-fix actually changed something (idempotent).
- MUST run while Firefox is NOT running (it rewrites recovery.jsonlz4 every ~15s).
"""
import lz4.block
import json
import sys
import shutil
import datetime

MAIN_ORDER = ["collaboration.koerbler.com", "support.brunner.at", "aistudio.google.com"]
STASH_ORDER = ["vikunja.bwh.at", "web.whatsapp.com", "kimai.bwh.at", "managedwp.at", "md.home.websters.at"]

MAIN_SELECTED_PREF = "collaboration.koerbler.com"   # Zulip title for sway matching
STASH_SELECTED_PREF = "vikunja.bwh.at"              # Vikunja first tab + title for sway matching

PATH = sys.argv[1] if len(sys.argv) > 1 else (
    "/home/michi/.mozilla/firefox/5446foem.default-release-1778515419450/sessionstore-backups/recovery.jsonlz4"
)

MAGIC = b"mozLz40\0"


def tab_url(tab):
    entries = tab.get("entries", [])
    return entries[-1].get("url", "") if entries else ""


def classify(url):
    for m in MAIN_ORDER:
        if m in url:
            return "main", MAIN_ORDER.index(m)
    for s in STASH_ORDER:
        if s in url:
            return "stash", STASH_ORDER.index(s)
    return "unknown", 999


def main():
    raw = open(PATH, "rb").read()
    assert raw[:8] == MAGIC, "not a mozLz4 file"
    sess = json.loads(lz4.block.decompress(raw[8:]))

    main_tabs, stash_tabs = [], []
    other_windows = []
    for w in sess.get("windows", []):
        buckets = {"main": [], "stash": [], "unknown": []}
        for t in w.get("tabs", []):
            kind, rank = classify(tab_url(t))
            buckets[kind].append((rank, t))
        if not buckets["main"] and not buckets["stash"]:
            other_windows.append(w)  # nothing known here -> keep window as-is
            continue
        # window type by majority of known tabs (ties -> keep unknown tabs with main? no: keep with larger bucket, stash on tie-break? use main on tie)
        if len(buckets["main"]) >= len(buckets["stash"]) and buckets["main"]:
            main_tabs += buckets["main"] + buckets["unknown"]
            stash_tabs += buckets["stash"]
        else:
            stash_tabs += buckets["stash"] + buckets["unknown"]
            main_tabs += buckets["main"]

    # If already canonical (<=1 main-ish window and <=1 stash-ish window, nothing to move), exit quietly
    # Rebuild canonical windows
    def build(tabs, order, selected_pref, template):
        tabs = sorted(tabs, key=lambda rt: (rt[0],))
        objs = [t for _, t in tabs]
        sel = 0
        for i, t in enumerate(objs):
            if selected_pref in tab_url(t):
                sel = i
                break
        w = dict(template)  # keep geometry/attrs of first contributing window
        w["tabs"] = objs
        w["selected"] = sel + 1  # sessionstore selected is 1-based
        return w

    # templates: first window that contributed to each group (fallback: minimal window dict)
    # find templates by re-scanning
    main_template, stash_template = None, None
    for w in sess.get("windows", []):
        kinds = {classify(tab_url(t))[0] for t in w.get("tabs", [])}
        if main_template is None and "main" in kinds and (len([t for t in w["tabs"] if classify(tab_url(t))[0] == "main"]) >= len([t for t in w["tabs"] if classify(tab_url(t))[0] == "stash"])):
            main_template = {k: v for k, v in w.items() if k not in ("tabs", "selected")}
        if stash_template is None and "stash" in kinds and (len([t for t in w["tabs"] if classify(tab_url(t))[0] == "stash"]) > len([t for t in w["tabs"] if classify(tab_url(t))[0] == "main"])):
            stash_template = {k: v for k, v in w.items() if k not in ("tabs", "selected")}
    if main_template is None:
        main_template = {"sizemode": "normal"}
    if stash_template is None:
        stash_template = {"sizemode": "normal"}

    new_windows = []
    changed = False
    if main_tabs:
        new_windows.append(build(main_tabs, MAIN_ORDER, MAIN_SELECTED_PREF, main_template))
    if stash_tabs:
        new_windows.append(build(stash_tabs, STASH_ORDER, STASH_SELECTED_PREF, stash_template))
    new_windows += other_windows

    old_sig = sorted(
        (classify(tab_url(t))[0], tab_url(t)) for w in sess.get("windows", []) for t in w.get("tabs", [])
    )
    new_sig = sorted(
        (classify(tab_url(t))[0], tab_url(t)) for w in new_windows for t in w.get("tabs", [])
    )
    old_layout = [[tab_url(t) for t in w.get("tabs", [])] for w in sess.get("windows", [])]
    new_layout = [[tab_url(t) for t in w] for w in [nw.get("tabs", []) for nw in new_windows]]
    if old_layout == new_layout and len(sess.get("windows", [])) == len(new_windows):
        print("already canonical, no change")
        return 0

    assert old_sig == new_sig, "tab set changed during merge - aborting!"

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.copy2(PATH, PATH + f".pre-merge-{stamp}")
    sess["windows"] = new_windows
    out = MAGIC + lz4.block.compress(json.dumps(sess).encode())
    tmp = PATH + f".tmp-{stamp}"
    open(tmp, "wb").write(out)
    import os
    os.replace(tmp, PATH)  # atomic: concurrent boot-time callers see old or new, never partial
    print(f"merged {len(old_layout)} windows -> {len(new_windows)} windows (backup: {PATH}.pre-merge-{stamp})")
    for i, w in enumerate(new_windows):
        print(f"  window {i} (selected={w.get('selected')}):")
        for t in w.get("tabs", []):
            print(f"    - {tab_url(t)[:80]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
