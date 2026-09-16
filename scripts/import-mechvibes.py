#!/usr/bin/env python3
"""Converts Mechvibes sound packs into KbSound's manifest format.

The two formats differ in three ways, and the conversion is mostly about flattening them:

1. **Different key code namespaces.** Mechvibes uses Linux/X11 key codes (14=Backspace,
   28=Enter, 57=Space) while KbSound uses macOS virtual key codes (51/36/49). `defines`
   therefore cannot be copied across; it has to be re-derived from which keyboard row a
   key sits in.
2. **Row variants are a pattern string.** `GENERIC_R{0-4}.mp3` means "pick one of five
   variants by keyboard row", which has to be expanded into a macOS key code → file map.
3. **Key-up sounds.** Mechvibes' `soundup` and `-up` suffix map onto our `up` field.

Usage:
    python3 scripts/import-mechvibes.py <mechvibes src/audio dir> <output dir>
"""

import json
import re
import shutil
import sys
from pathlib import Path

# macOS virtual key code → keyboard row. Rows match Mechvibes' GENERIC_R{0-4}:
# R0 number row, R1 QWERTY row, R2 ASDF row, R3 ZXCV row, R4 bottom row and modifiers.
ROWS = {
    0: [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51,   # ` 1..0 - = Backspace
        53, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111],  # Esc F1..F12
    1: [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],  # Tab Q..P [ ] \
    2: [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],            # Caps A..L ; ' Return
    3: [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60],              # Shift Z..M , . / RShift
    4: [63, 59, 58, 55, 49, 54, 61, 62,                           # Fn Ctrl Opt Cmd Space
        123, 124, 125, 126],                                      # arrow keys
}

# Mechvibes' special keys (X11 codes) → macOS virtual key codes
SPECIAL_KEYCODES = {"14": 51, "28": 36, "57": 49}

ROW_PATTERN = re.compile(r"^(.*)R\{(\d+)-(\d+)\}(\..+)$")


def expand_row_pattern(pattern):
    """`press/GENERIC_R{0-4}.mp3` → {0: 'press/GENERIC_R0.mp3', ...}"""
    match = ROW_PATTERN.match(pattern)
    if not match:
        return None
    prefix, low, high, suffix = match.groups()
    return {row: f"{prefix}R{row}{suffix}" for row in range(int(low), int(high) + 1)}


def convert(source_dir, pack_name, out_dir, pack_id, display_name, detail):
    config = json.loads((source_dir / "config.json").read_text())
    row_files = expand_row_pattern(config["sound"])
    if row_files is None:
        raise SystemExit(f"{pack_name}: unsupported sound pattern {config['sound']!r}")

    default_up = config.get("soundup")
    defines = config.get("defines", {})

    # Special keys: take down/up from defines and translate the code to macOS.
    # Some packs (mxblue-travel, for one) declare a dedicated sound in the config without
    # shipping the file, so every path is checked; a missing one counts as undeclared and
    # falls back to the row's generic sound.
    specials = {}
    for x11_code, mac_code in SPECIAL_KEYCODES.items():
        down = defines.get(x11_code)
        up = defines.get(f"{x11_code}-up")
        down = down if down and (source_dir / down).exists() else None
        up = up if up and (source_dir / up).exists() else None
        if down or up:
            specials[mac_code] = (down, up)

    keys = {}
    for row, keycodes in ROWS.items():
        for keycode in keycodes:
            if keycode in specials:
                down, up = specials[keycode]
                # A missing down still needs a press sound; fill it from the row's generic one
                entry = {"down": down or row_files[row]}
                if up or default_up:
                    entry["up"] = up or default_up
            else:
                entry = {"down": row_files[row]}
                if default_up:
                    entry["up"] = default_up
            keys[str(keycode)] = entry

    manifest = {
        "formatVersion": 1,
        "id": pack_id,
        "name": display_name,
        "author": "Thomas Lai (tplai/kbsim)",
        "version": "1.0.0",
        "description": detail,
        "defaults": (
            {"down": row_files[2], "up": default_up} if default_up else {"down": row_files[2]}
        ),
        "keys": keys,
    }

    # Copy only the audio files the manifest actually references
    referenced = {manifest["defaults"].get("down"), manifest["defaults"].get("up")}
    for entry in keys.values():
        referenced.update(entry.values())
    referenced.discard(None)

    out = out_dir / pack_name
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for rel in sorted(referenced):
        src = source_dir / rel
        if not src.exists():
            raise SystemExit(f"{pack_name}: missing audio file {rel}")
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"{pack_name}: {len(keys)} key codes, {len(referenced)} audio files")


# Packs to import: source directory name → (pack id, display name, description)
PACKS = {
    "holy-pandas": ("com.tplai.holy-pandas", "Holy Pandas",
                    "Tactile thock with a rounded top-out — the enthusiast favourite."),
    "turquoise": ("com.tplai.turquoise", "Turquoise · Full Travel",
                  "Bright and crisp, with the full down-and-up travel recorded."),
    "cream-travel": ("com.tplai.cream-travel", "NK Cream · Full Travel",
                     "Deep POM creaminess, including the release."),
    "mxblack-travel": ("com.tplai.mxblack-travel", "Cherry MX Black · Full Travel",
                       "Heavy linear with a solid bottom-out and a recorded release."),
    "mxblue-travel": ("com.tplai.mxblue-travel", "Cherry MX Blue · Full Travel",
                      "The classic click, with its distinct upstroke click too."),
    "mxbrown-travel": ("com.tplai.mxbrown-travel", "Cherry MX Brown · Full Travel",
                       "Gentle tactile bump, down and up."),
}


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    audio_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    for name, (pack_id, display, detail) in PACKS.items():
        convert(audio_dir / name, name, out_dir, pack_id, display, detail)
