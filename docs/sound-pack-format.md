# Sound pack format

A KbSound sound pack is a directory holding one `manifest.json` and the audio files it
references:

```
<pack-id>/
├── manifest.json
├── midpitch.wav
├── spacebar.wav
└── …
```

Audio is decoded by macOS, so wav, mp3, m4a, flac, Ogg Vorbis and Opus all work. Every
file inside one pack must share the same sample rate and channel count — a single
`AVAudioPlayerNode` can only be connected with one format at a time.

## manifest.json

```jsonc
{
  "formatVersion": 1,
  "id": "com.example.mx-blue-pbt",
  "name": "Cherry MX Blue · PBT",     // shown in the menu
  "author": "…",
  "description": "…",
  "defaults": { "down": "midpitch.wav", "up": "default-up.wav" },
  "keys": {
    "49": { "down": "spacebar.wav", "up": "space-up.wav" }
  }
}
```

| Field | Required | Meaning |
|---|---|---|
| `formatVersion` | yes | Always `1` today. |
| `id` | yes | Reverse-DNS identifier. Also the directory name once imported, and the key used when a user pack shadows a built-in one. |
| `name` | yes | Display name in the menu bar panel. |
| `author` | no | Free text. |
| `description` | no | Free text. |
| `defaults` | yes | The sound used by any key without its own entry. |
| `keys` | no | Per-key overrides, keyed by macOS virtual key code as a decimal string. |

Rules:

- `up` may be omitted everywhere; most packs only define `down`.
- Lookup order is `keys[keyCode].<phase>` → `defaults.<phase>` → silence.
- Tonal variation is baked into the pack (different key codes point at low / mid / high /
  alt pitch files). KbSound does not randomize pitch at runtime.

`KeycodeMap.swift` lists the macOS virtual key codes and the keyboard row each belongs
to; the rows match Mechvibes' `GENERIC_R{0-4}` variants.

## Where packs are loaded from

1. Built in: `KbSound.app/Contents/Resources/Packs/`
2. User: `~/Library/Application Support/KbSound/Packs/`

A user pack with the same `id` shadows the built-in one. Importing the same `id` twice
replaces the existing directory rather than creating a duplicate.

## Mechvibes packs

KbSound imports Mechvibes packs directly; pick the folder holding the pack's
`config.json` in **Import sound pack…**. Both layouts are handled:

| `key_define_type` | Layout | Handling |
|---|---|---|
| `multi` | One file per sound | X11 key codes are translated to macOS ones, and `GENERIC_R{0-4}` row patterns are expanded per row. |
| `single` | One audio sprite plus `[offset ms, duration ms]` | Each slice is cut into its own wav at import time. |

To batch-convert packs from the command line instead:

```sh
python3 scripts/import-mechvibes.py <mechvibes src/audio dir> <output dir>
```
