# 音频素材授权凭据（CREDITS）

> 建档：2026-09-20（标准集合 S17 缺口修复）。本文件是发行凭据唯一存档点，
> 游戏内「制作人员/许可」页的数据源之一。
> **红线：商店页提交前本表不得留有 UNVERIFIED 状态的条目。**
> **2026-09-26 更新：BGM 全量换曲完成，红线已清零。** 证据链主文档
> `_steam_assets/licenses/incompetech_20260926/LICENSE_EVIDENCE.md`。
> **2026-10-08 增补（v6.52.2）：BGM 13 首**——hub 按时代五键（记录1#7）+
> battle_future 换 Hiding Your Reality（记录1#9「春游 BGM」主诉），证据链
> `_steam_assets/licenses/incompetech_20261008/swap_manifest_20261008.json`。

## 结论速览（2026-09-26 核验 / 2026-10-08 增补）

| 类别 | 数量 | 凭据状态 | 判定 |
|---|---|---|---|
| SFX | 36 个 | ✅ 项目内生成管线产物（自合成，无第三方素材） | 无外部授权义务 |
| 环境音 | 1 个（ambient_battle_wind.wav） | 同上，自合成 | 无外部授权义务 |
| **BGM** | **13 首**（8+5） | ✅ **incompetech（Kevin MacLeod）· CC BY 4.0，逐曲溯源+SHA256 存档** | 署名义务已由游戏内 credits 页+凭据表承载 |

## BGM 逐曲状态表（2026-09-26 换曲 / 2026-10-08 增补后）

许可统一 CC BY 4.0（作曲/版权人 Kevin MacLeod）；加工=响度归一（-14 LUFS 目标，
峰值保护）+ OGG Vorbis q6/44.1kHz 转码 + 溯源元数据内嵌（title/artist/ISRC/license）。
ISRC/时长/源 URL/SHA256 逐曲全表见 `LICENSE_EVIDENCE.md` 与
`_steam_assets/licenses/incompetech_20261008/swap_manifest_20261008.json`。

| 文件 | 曲目 | ISRC | 用途 | 凭据状态 |
|---|---|---|---|---|
| bgm_title.ogg | At Launch | USUAN1100539 | 标题屏 | ✅ |
| bgm_hub.ogg | Peaceful Desolation | USUAN1200017 | 基地/大地图（时代曲缺失时回退） | ✅ |
| bgm_hub_ww1.ogg | Man Down | USUAN1700086 | 基地/大地图·一战线（10-08 新增） | ✅ |
| bgm_hub_ww2.ogg | Take the Lead | b62f1a8b-907c-4ba2-922b-49f69cca1be1 | 基地/大地图·二战线（10-08 新增） | ✅ |
| bgm_hub_cold.ogg | Spy Glass | USUAN1500058 | 基地/大地图·冷战线（10-08 新增） | ✅ |
| bgm_hub_modern.ogg | Bass Walker | 6053b5b8-cfbd-4277-9370-bfd7c9e52a22 | 基地/大地图·现代线（10-08 新增） | ✅ |
| bgm_hub_future.ogg | Space Fighter Loop | USUAN1100672 | 基地/大地图·近未来线（10-08 挪档，与 9-26 battle_future 同文件同授权） | ✅ |
| bgm_battle_ww1.ogg | Devastation and Revenge | USUAN1100694 | WW1 战斗 | ✅ |
| bgm_battle_ww2.ogg | Five Armies | USUAN1100875 | WW2 战斗 | ✅ |
| bgm_battle_cold.ogg | Crypto | USUAN1600013 | 冷战战斗 | ✅ |
| bgm_battle_modern.ogg | Rock Hybrid | USUAN1100094 | 现代（MODERN）战斗 | ✅ |
| bgm_battle_future.ogg | **Hiding Your Reality**（10-08 换曲，原 Space Fighter Loop 挪 hub_future） | USUAN1700081 | 近未来（FUTURE）战斗 | ✅ |
| bgm_boss.ogg | Final Battle of the Dark Wizards | USUAN1500085 | Boss 战 | ✅ |

## 换曲记录（2026-10-08，v6.52.2）

- **换下**：`bgm_battle_future` 的 Space Fighter Loop（USUAN1100672）——官方标注"为太空战斗游戏而写的循环"，全曲库唯一轻快/游戏感曲目，与悲怆管弦主语言反差过大（实机 #9「像春游的背景音乐」主诉本体）。本体未退役：原文件挪 `bgm_hub_future.ogg`（近未来基地氛围，授权同曲沿用）。
- **换上**：Hiding Your Reality（USUAN1700081，官方标注 Action/Driving/Epic，铜管+合成器）。
- **新增**：hub 时代四曲 Man Down（8 把大提琴哀伤弦乐，Somber，语义贴一战纪念）/ Take the Lead（紧张重吉他+synth）/ Spy Glass（50 年代侦探爵士，冷战谍报感）/ Bass Walker（Noir 行走贝斯）。
- 首选 ww1 候选 Long Note Two 因源响度 -25.6 LUFS（峰值顶死无法正增益，归一后 -26.9 不可闻）换 Man Down——静态增益纪律下响度不可救的源直接换曲。
- 原始 mp3 归档：`D:/godotplay/_art_backup/bgm_v6522_20261008/incompetech_sources/`；换下前 battle_future 备份：同目录 `pre_swap/`。
- ⚠️ 现役 battle_future（Hiding Your Reality -16.4 LUFS）与 hub_cold（Spy Glass -16.4）比基准轻 2.4dB（源峰值限制，静态增益纪律内极限）；切歌无跳变级差异，复听如感偏轻可在下批统一 loudnorm 二次归一。

## 旧曲退役记录（2026-09-26 下架，本体已移出项目）

原 7 首（bgm_title/hub/battle_ww1/battle_ww2/battle_modern/battle_future/boss）
2026-09-20 核验为 UNVERIFIED：来源声明"YouTube 免费音乐库 CC0"仅是 README 假设，
OGG Vorbis comment 已被 ffmpeg 转码覆写（仅存 `encoder=Lavc62.11.100 libvorbis`），
曲名/创作者/许可链接在文件层不可追溯。另 **bgm_battle_cold.ogg（2026-08-23 入库，
COLD_WAR 战斗曲）当时被 9-20 审计漏登记**，同族处置。

| 退役文件 | SHA256（前 16 位） | 状态 |
|---|---|---|
| bgm_title.ogg | 50d2e2ace5dcb704 | ❌ UNVERIFIED → 已退役 |
| bgm_hub.ogg | aa3057633dac51c6 | ❌ UNVERIFIED → 已退役 |
| bgm_battle_ww1.ogg | 1b59353f63d76deb | ❌ UNVERIFIED → 已退役 |
| bgm_battle_ww2.ogg | 80133385c2d20820 | ❌ UNVERIFIED → 已退役 |
| bgm_battle_cold.ogg | c1b4e468040dca34 | ❌ UNVERIFIED（曾漏登记）→ 已退役 |
| bgm_battle_modern.ogg | bdd7fd2b5eedb12e | ❌ UNVERIFIED → 已退役 |
| bgm_battle_future.ogg | 1b38d91e12c1869a | ❌ UNVERIFIED → 已退役 |
| bgm_boss.ogg | 7d873c444579db28 | ❌ UNVERIFIED → 已退役 |

退役本体+换曲批次源 MP3 归档：
`F:\godot fair duet\_art_backup\bgm_prelicense_20260926\`
（**`*.ogg` 在 .gitignore——音频资产 git 不保护，换曲/删曲前必须走外部备份**）。
若后续在旧下载记录中找到原曲凭据，凭据链可从上述指纹比对恢复，但**不再回装**
（新曲凭据已闭环；回装需重走本表逐曲核验）。

## 第三方署名区（游戏内 credits 页同步展示）

- **音乐**：背景音乐 All by Kevin MacLeod (incompetech.com)，
  Licensed under Creative Commons: By Attribution 4.0
  （https://creativecommons.org/licenses/by/4.0/）——游戏内 credits 页
  「音乐与音效」段已同步（scripts/ui/credits_panel.gd）。
- **音效（2026-10-10 增补，v6.56）**：武器音效九槽（gun_pistol/smg/rifle/mg/shotgun/
  sniper/flak_fire/shoot）源自 **The Free Firearm Sound Library** by bart
  （opengameart.org/content/the-free-firearm-sound-library，**CC0**，无署名义务）；
  missile_hum 源自 **Kenney Sci-Fi Sounds**（kenney.nl，**CC0**）。两者均为公有领域
  等效授权，加工=瞬态剪单发/定长剪+RMS 匹配+OGG q6 转码。原包存档：
  firearm 7z=`D:/godotplay/sfxdl/oga_gun_20261010/firearm_lib.7z`
  （SHA256 前 16 位 `cc1ab5a99a0a3651`）；Kenney 沿用
  `_steam_assets/licenses/kenney_20261010/sci-fi-sounds.zip`。
- **字体**：Rajdhani（Indian Type Foundry · SIL OFL 1.1，`assets/fonts/Rajdhani-OFL.txt`）、
  Noto Sans SC（Adobe/Google 联合 · SIL OFL 1.1，`assets/fonts/NotoSansSC-OFL.txt`，
  与 google/fonts 上游逐字节一致）。⚠️ 2026-09-26 勘误：旧 `OFL.txt` 是已删除的
  Barlow 字体的遗留许可文件（张冠李戴），已替换为 Rajdhani 权威文本；
  无署名头的 `LICENSE` 一并移除，现在按字族一一对应。
- 引擎：Godot Engine 4.5.1（MIT License，© Godot Engine contributors、Juan Linietsky
  与 Ariel Manzur——许可全文随包：assets/licenses/）。

## SFX 自合成口径说明

36 个 SFX + 环境风声为项目内生成管线产物：合成波形代码真身 `managers/sound_generator.gd`
（方波+噪声→枪械、低频扫降→爆炸、正弦扫频→能量武器等原语，16-bit PCM），
离线渲染转 OGG 落盘（2026-07-17 README 记录"全部已生成"；该脚本至今仍是运行期
音频缺失时的兜底合成器）。无第三方素材引用。若其中任何文件后续被替换为外部素材，
**必须**回写本表（来源/许可/凭证）——并同步检查商店页 AI 披露表单范围（标准集合 S10）。

## 许可文本随包发行（v6.28.1 复查补全）

- `export_presets.cfg` include_filter 已补 `assets/fonts/*.txt, assets/licenses/*.txt`
  ——**此前 OFL 全文（all_resources 模式不导出裸 .txt）实际不随包**，credits 页
  "OFL 许可全文随游戏文件附带"是空头承诺，现已落实。
- `assets/licenses/`：`godot-engine-LICENSE.txt`（MIT，© Godot Engine contributors +
  Juan Linietsky, Ariel Manzur——credits 页旧文案"Juan Lini"系缩写讹误已订正）
  + `godot-thirdparty-COPYRIGHT.txt`（Godot 仓库 COPYRIGHT.txt，第三方组件穷举许可）。
- 字体归属已按 TTF name 表逐一比对确认：Rajdhani 三字重 copyright=Indian Type
  Foundry、Noto Sans SC 三件 copyright=Adobe（Reserved Font Name 'Source'），
  与随附 OFL 文本一一对应；usWeightClass 400/500/600/700 与文件名一致。

## 换曲复用工序（下次再换 BGM 照此走）

1. 外部备份旧文件（git 不管 .ogg）→ 2. 下载源曲+许可页快照入
   `_steam_assets/licenses/<source>_<date>/` → 3. 填 `swap_manifest_*.json`
   （slot/源路径/目录时长/元数据）→ 4. `python tools/bgm_swap_from_manifest.py <manifest>`
   （自动拒截断、响度归一、内嵌元数据、同名落位）→ 5.
   `--headless --editor --quit` 重导入 → 6. 更新本表+LICENSE_EVIDENCE+credits 页。
