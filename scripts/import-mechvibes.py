#!/usr/bin/env python3
"""把 Mechvibes 音效包转换成 KbSound 的 manifest 格式。

两边差异有三处，转换主要就是在抹平它们：

1. **键码命名空间不同**。Mechvibes 用 Linux/X11 键码（14=Backspace、28=Enter、
   57=Space），KbSound 用 macOS 虚拟键码（51/36/49）。所以不能直接搬 `defines`，
   要按「这个键在键盘第几行」重新推导。
2. **行变体是模式串**。`GENERIC_R{0-4}.mp3` 表示按键盘行取 5 个变体之一，
   需要展开成每个 macOS 键码到具体文件的映射。
3. **抬键音**。Mechvibes 的 `soundup` / `-up` 后缀对应我们的 `up` 字段。

用法：
    python3 scripts/import-mechvibes.py <mechvibes的src/audio目录> <输出目录>
"""

import json
import re
import shutil
import sys
from pathlib import Path

# macOS 虚拟键码 → 键盘行。行的含义与 Mechvibes 的 GENERIC_R{0-4} 一致：
# R0 数字行、R1 QWERTY 行、R2 ASDF 行、R3 ZXCV 行、R4 底排与修饰键。
ROWS = {
    0: [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51,   # ` 1..0 - = Backspace
        53, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111],  # Esc F1..F12
    1: [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],  # Tab Q..P [ ] \
    2: [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],            # Caps A..L ; ' Return
    3: [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60],              # Shift Z..M , . / RShift
    4: [63, 59, 58, 55, 49, 54, 61, 62,                           # Fn Ctrl Opt Cmd Space
        123, 124, 125, 126],                                      # 方向键
}

# Mechvibes 的特殊键（X11 键码）→ macOS 虚拟键码
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
        raise SystemExit(f"{pack_name}: 不支持的 sound 模式 {config['sound']!r}")

    default_up = config.get("soundup")
    defines = config.get("defines", {})

    # 特殊键：从 defines 里取 down/up，键码换成 macOS 的。
    # 有的包（如 mxblue-travel）在 config 里声明了专属音却没附上文件，
    # 所以逐个校验存在性，缺失的就当没声明，回退到该行的通用音。
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
                # 只缺 down 时仍要有按下的声音，用该行的通用音补上
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

    # 只拷贝 manifest 真正引用到的音频文件
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
            raise SystemExit(f"{pack_name}: 缺少音频文件 {rel}")
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"{pack_name}: {len(keys)} 个键码, {len(referenced)} 个音频文件")


# 要导入的包：源目录名 → (包 id, 显示名, 说明)
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
