# 第三方素材

## 音效包

`Resources/Packs/` 下共 21 套音效包，来自两处。

### 15 套：klinkmac

取自 [klinkmac](https://github.com/rockykusuma/klinkmac)（仓库采用 MIT 许可）。

音频文件本身在各包 `manifest.json` 中标注的 `author` 为
"Mechvibes Community"，`license` 未标注或为 `unknown`。

### 6 套：mechvibes / kbsim

`holy-pandas`、`turquoise`、`cream-travel`、`mxblack-travel`、`mxblue-travel`、
`mxbrown-travel` 取自 [mechvibes](https://github.com/hainguyents13/mechvibes)（MIT）
的 `src/audio/`，其 `holy-pandas/README.md` 注明音频来自
[tplai/kbsim](https://github.com/tplai/kbsim)（MIT），
`holy-pandas/LICENSE` 为 Thomas Lai 署名的 MIT 文本。

这 6 套的授权链比上面 15 套清晰，但**其余 5 套目录内没有独立的 LICENSE 文件**，
只能依据同源仓库的 MIT 许可推定。

原始格式是 Mechvibes 的 `config.json`（Linux/X11 键码），
已由 `scripts/import-mechvibes.py` 转换为本项目的 manifest 格式（macOS 虚拟键码）。

### 分发限制

鉴于上述 15 套音频的授权状况不明，**本项目仅供本机自用，不得公开分发打包好的 .app。**

## Claude Code Skills

`.claude/skills/` 下的 6 个 skill 取自
[rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills)（MIT），
仅复制了本项目相关的子集，未做修改。完整授权见 `.claude/skills/LICENSE-apple-skills`。
