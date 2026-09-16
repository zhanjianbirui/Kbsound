# Third-party assets

## Sound packs

The 21 packs under `Resources/Packs/` come from two places.

### 15 packs: klinkmac

Taken from [klinkmac](https://github.com/rockykusuma/klinkmac) (the repository is MIT
licensed).

In each pack's `manifest.json` the audio files themselves are attributed to
"Mechvibes Community", with `license` either absent or `unknown`.

### 6 packs: mechvibes / kbsim

`holy-pandas`, `turquoise`, `cream-travel`, `mxblack-travel`, `mxblue-travel` and
`mxbrown-travel` come from `src/audio/` of
[mechvibes](https://github.com/hainguyents13/mechvibes) (MIT). Its
`holy-pandas/README.md` states that the audio comes from
[tplai/kbsim](https://github.com/tplai/kbsim) (MIT), and `holy-pandas/LICENSE` is an MIT
text attributed to Thomas Lai.

The licensing chain for these 6 is clearer than for the 15 above, but **the other 5
directories carry no LICENSE file of their own** — their status can only be inferred from
the MIT license of the repository they came from.

The original format is Mechvibes' `config.json` (Linux/X11 key codes); they were
converted to this project's manifest format (macOS virtual key codes) by
`scripts/import-mechvibes.py`.

### On redistribution

The code is MIT licensed (see `LICENSE`). That license **does not cover the audio files
under `Resources/Packs/`**.

The licensing chain for the 15 klinkmac packs is not clear: the upstream repository is
MIT, but the audio files are attributed in their manifests to "Mechvibes Community" with
an `unknown` license, and the original recordists cannot be traced. This repository keeps
the original attributions and claims no rights over the audio.
**If you own one of these recordings and want it removed, open an issue and it will be
taken down immediately.**

On that basis: check the licensing status yourself before forwarding or redistributing
this audio. This repository offers no warranty of any kind for the audio.

## Claude Code skills

The 6 skills under `.claude/skills/` are taken from
[rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills)
(MIT). Only the subset relevant to this project was copied, unmodified. The full license
is in `.claude/skills/LICENSE-apple-skills`.
