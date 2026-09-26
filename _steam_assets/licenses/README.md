# 许可凭据存档索引（licenses/）

商店提交/法务核查时按此索引取证。配套台账：`assets/sfx/CREDITS.md`（音频凭据唯一存档点）、
游戏内 credits 页（`scripts/ui/credits_panel.gd`，玩家可见署名）。

| 目录/文件 | 内容 | 状态 |
|---|---|---|
| `incompetech_20260926/` | **BGM 全量换曲批（v6.28）**：incompetech / Kevin MacLeod，CC BY 4.0。含 CC-BY 法务文本快照、来源站条款页快照、pieces.json 目录快照（1442 首）、逐曲 ISRC+双端 SHA256（`intake_hashes_20260926.json`）、换曲清单（`swap_manifest_20260926.json`）、主文档 `LICENSE_EVIDENCE.md`（含面向商店页的署名文本） | ✅ 现行 8 首 BGM 凭据 |

## 仓库内其他许可落点（不进本目录）

- `assets/fonts/Rajdhani-OFL.txt` / `NotoSansSC-OFL.txt` — 字体 OFL 全文（随构建发行）
- `assets/licenses/godot-engine-LICENSE.txt` + `godot-thirdparty-COPYRIGHT.txt` — 引擎 MIT + 第三方穷举（随构建发行）
- `assets/sfx/CREDITS.md` — SFX 自合成口径（管线真身 `managers/sound_generator.gd`）+ BGM 台账 + 旧曲退役记录

## 录入规矩

新增第三方素材（音乐/字体/图标/模型…）时：许可文本/条款页快照 + 来源 URL + SHA256
按 `<来源>_<日期>/` 建目录入此处，并回写 `assets/sfx/CREDITS.md`（音频）或本索引。
原始下载文件本体放项目外 `_art_backup/`（`*.ogg`/`*.mp3` 均被 .gitignore，git 不保护）。
