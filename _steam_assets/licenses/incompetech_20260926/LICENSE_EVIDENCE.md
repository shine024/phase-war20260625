# BGM 授权凭据（incompetech / Kevin MacLeod，CC BY 4.0）——2026-09-26 换曲批次

> 本目录是 2026-09-26 BGM 全面换曲的**授权证据链存档**。替换动机：原 7+1 首 BGM
> （YouTube 免费音乐库来源）经 2026-09-20 核验元数据已被转码覆写、凭据不可追溯，
> 按 S17「查不到凭据 = 视同未授权」处置（详见 assets/sfx/CREDITS.md 退役记录）。
> 原计划走 FreePD（CC0）曲源，**抓取时发现 FreePD.com 已于 2025 年永久关站**，
> 改用 incompetech.com（Kevin MacLeod 官方站，条款明确：免费使用需署名，CC BY 4.0）。

## 授权条款

- **许可**：Creative Commons Attribution 4.0 International（CC BY 4.0）
- **作曲者/版权人**：Kevin MacLeod（incompetech.com）
- **义务**：署名（credit）——本项目以两处承载：①游戏内「制作人员与许可」页
  （`scripts/ui/credits_panel.gd` SECTIONS 音乐段）；②本文件逐曲清单。
- **法务文本快照**：`cc-by-4.0_legalcode.txt`（creativecommons.org/licenses/by/4.0/legalcode.txt）
- **来源站条款页快照**：`snapshot_licenses_page.html`（"Creative Commons — Free:
  No charge. Requires that you credit the music."）
- **目录快照**：`snapshot_pieces_catalog.json`（pieces.json @ 2026-09-26，1442 首）

## 换曲执行摘要

- 选曲依据：incompetech 机器可读目录（genre/feel/description/instruments）按各槽位
  时代气质匹配；8 首全部为 Kevin MacLeod 作品，单一许可族。
- 下载：2026-09-26，原始 MP3 归档于项目外
  `F:\godot fair duet\_art_backup\bgm_prelicense_20260926\incompetech_sources\`
  （*.ogg 在 .gitignore，旧曲同目录备份，不替换不可回退）。
- 加工：`tools/bgm_swap_from_manifest.py`（清单
  `swap_manifest_20260926.json`）——时长校验（拒截断）→ 响度静态增益归一
  （目标 -14 LUFS，真峰值超 -1.5 dBTP 时按峰值回退，无动态处理）→
  ffmpeg libvorbis q6 / 44.1kHz / 立体声 → 溯源元数据内嵌
  （title/artist/ISRC/license URL，vorbis comment stream 级）→ 同名落位 assets/sfx/。
- 旧 8 首（7 未溯源 + bgm_battle_cold 漏登记）SHA256 与退役记录见
  `assets/sfx/CREDITS.md` 文末；音频文件本体在 _art_backup 目录。

## 逐曲凭据表

SHA256 完整值见 `intake_hashes_20260926.json`（源 MP3 与发行 OGG 双端指纹）。
时长/响度列为发行 OGG 实测值（ffmpeg ebur128）。

| 槽位（发行文件名） | 曲目 | ISRC | 时长 | 响度 | 用途/选曲理由 |
|---|---|---|---|---|---|
| bgm_title.ogg | At Launch | USUAN1100539 | 185s | -18.2 LUFS | 标题屏。铜管+军乐小鼓，"military might and hopeful adventure" |
| bgm_hub.ogg | Peaceful Desolation | USUAN1200017 | 91s | -19.8 LUFS | 基地/整备。平静偏苍凉管弦 |
| bgm_battle_ww1.ogg | Devastation and Revenge | USUAN1100694 | 185s | -19.0 LUFS | 一战战斗。"impending battle + great sadness and loss" |
| bgm_battle_ww2.ogg | Five Armies | USUAN1100875 | 156s | -14.1 LUFS | 二战战斗。大编制管弦推进 |
| bgm_battle_cold.ogg | Crypto | USUAN1600013 | 204s | -14.0 LUFS | 冷战战斗。悬疑等待/密码战气质 |
| bgm_battle_modern.ogg | Rock Hybrid | USUAN1100094 | 130s | -21.0 LUFS | 现代战斗。摇滚/电子混合，官方标注 loopable |
| bgm_battle_future.ogg | Space Fighter Loop | USUAN1100672 | 101s | -16.3 LUFS | 近未来战斗。为太空战斗游戏而写的循环 |
| bgm_boss.ogg | Final Battle of the Dark Wizards | USUAN1500085 | 272s | -14.0 LUFS | Boss 战。圣咏+管弦史诗 |

每曲源 URL 模式：`https://incompetech.com/music/royalty-free/mp3-royaltyfree/<曲名 URL 转码>.mp3`
（逐曲完整 URL 在 swap_manifest_20260926.json）。

## 面向玩家/商店页的署名文本（复制即用）

> All background music by Kevin MacLeod (incompetech.com)
> Licensed under Creative Commons: By Attribution 4.0
> https://creativecommons.org/licenses/by/4.0/
> Tracks: "At Launch" · "Peaceful Desolation" · "Devastation and Revenge" ·
> "Five Armies" · "Crypto" · "Rock Hybrid" · "Space Fighter Loop" ·
> "Final Battle of the Dark Wizards"

## 响度备注

旧 BGM 从未归一（实测 -6.1 ~ -18.0 LUFS，跨度 12 dB，标题屏曲过响）。
本批统一到 -14 LUFS 目标；其中 6 首因母带真峰值顶格/越界，按峰值上限
（-1.5 dBTP）回退增益、未加动态压缩（防抽吸伪声，实听裁决权在用户）。
实际成品跨度 -14.0 ~ -21.0 LUFS。若用户实听后要求进一步收紧，动
`tools/bgm_swap_from_manifest.py` 的 TARGET_LUFS/PEAK_CEIL 或引入限幅器重跑。

## 复验指引

1. `ffmpeg -i <ogg>` → 看 vorbis 标签（title/artist/ISRC/comment）与时长。
2. `intake_hashes_20260926.json` 比对 SHA256（确认未再被覆写）。
3. 游戏内：标题屏→基地→各时代战斗→Boss 登场，听切换与循环
   （AudioManager 运行时置 loop=true，与导入设置无关）。
