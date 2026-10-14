# 音频素材授权凭据（CREDITS）

> 建档：2026-09-20（标准集合 S17 缺口修复）。本文件是发行凭据唯一存档点，
> 游戏内「制作人员/许可」页的数据源之一。
> **红线：商店页提交前本表不得留有 UNVERIFIED 状态的条目。**
> **2026-09-26 更新：BGM 全量换曲完成，红线已清零。** 证据链主文档
> `_steam_assets/licenses/incompetech_20260926/LICENSE_EVIDENCE.md`。
> **2026-10-08 增补（v6.52.2）：BGM 13 首**——hub 按时代五键（记录1#7）+
> battle_future 换 Hiding Your Reality（记录1#9「春游 BGM」主诉），证据链
> `_steam_assets/licenses/incompetech_20261008/swap_manifest_20261008.json`。
> **2026-10-20 更新（v6.69 音频审核批）：换机审听 28 项 + base_alarm 新增落位**——
> 逐项证据链 `_steam_assets/licenses/sfx_swap_20261020/`（swap_manifest_20261020.json +
> LICENSE_EVIDENCE_20261020.md + intake_hashes_20261020.json + 音效备选调研报告.md），
> 动手前全量备份 `D:/godotplay/_art_backup/sfx_pre_swap_20261020/`。

## 结论速览（2026-10-20 最终态）

| 类别 | 数量 | 凭据状态 | 判定 |
|---|---|---|---|
| SFX | 45 个（19 自合成 + 26 第三方免署名） | ✅ 19 个=项目内生成管线产物；26 个=Kenney CC0×6 / OGA CC0/PD×7 / Wikimedia PD×1 / Mixkit Free×12，逐项哈希存档 | 全量无外部授权义务（无 CC BY 署名项） |
| 环境音 | 2 个 | ✅ OGA CC0（IgnasD Wind + V-visions War on Water 合成/交叉淡化） | 无外部授权义务 |
| **BGM** | **13 首**（12 CC BY 4.0 + 1 CC0） | ✅ 12 首 incompetech（Kevin MacLeod）CC BY 4.0 逐曲溯源；**bgm_battle_ww1 10-20 换 Juhani Junkala「Epic Boss Battle」（OGA CC0）** | CC BY 署名义务由游戏内 credits 页+本表承载；OGA 项免署名 |

## BGM 逐曲状态表（2026-09-26 换曲 / 2026-10-08 增补 / 2026-10-20 ww1 换曲后）

12 首为 Kevin MacLeod（incompetech）CC BY 4.0；加工=响度归一（-14 LUFS 目标，
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
| bgm_battle_ww1.ogg | **Epic Boss Battle（10-20 换曲，原 Devastation and Revenge USUAN1100694）** | 无（OGA CC0） | WW1 战斗（无缝循环 123.4s，4 秒内进主旋律） | ✅ Juhani Junkala · OGA · CC0（opengameart.org/content/boss-battle-music） |
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

- **音乐**：背景音乐 12 首 All by Kevin MacLeod (incompetech.com)，
  Licensed under Creative Commons: By Attribution 4.0
  （https://creativecommons.org/licenses/by/4.0/）；另 1 首（bgm_battle_ww1）
  Epic Boss Battle by Juhani Junkala（opengameart.org，**CC0**，免署名）
  （2026-10-20 换曲）。游戏内 credits 页「音乐与音效」段已同步
  （scripts/ui/credits_panel.gd）。
- **音效（2026-10-10 增补，v6.56）**：武器音效九槽（gun_pistol/smg/rifle/mg/shotgun/
  sniper/flak_fire/shoot）源自 **The Free Firearm Sound Library** by bart
  （opengameart.org/content/the-free-firearm-sound-library，**CC0**，无署名义务）；
  missile_hum 源自 **Kenney Sci-Fi Sounds**（kenney.nl，**CC0**）。两者均为公有领域
  等效授权，加工=瞬态剪单发/定长剪+RMS 匹配+OGG q6 转码。原包存档：
  firearm 7z=`D:/godotplay/sfxdl/oga_gun_20261010/firearm_lib.7z`
  （SHA256 前 16 位 `cc1ab5a99a0a3651`）；Kenney 沿用
  `_steam_assets/licenses/kenney_20261010/sci-fi-sounds.zip`。
- **音效（2026-10-20 批量换装 26 槽 + base_alarm 新增 + 环境音 2 项，v6.69）**：
  全部免署名授权，无 CC BY 义务项。来源族：
  - Kenney（Interface / Casino / Impact 等包）· **CC0**（kenney.nl，2026-10 各资产页亲验）
  - OpenGameArt：Boss Battle（Juhani Junkala）/ Chunky Explosion（OwlishMedia）/
    Hurt-Death for character / 512 SFX（Juhani Junkala）/ Wind（IgnasD）/ War on Water
    （V-visions）/ Metal Impact Sounds（BMacZero）/ Bell dings-chimes（Public Domain）/
    Grunts: male death and pain / Horde war drums loop（William Hector）/
    gorilla-sounds · **全 CC0**（opengameart.org 逐页核实）
  - Mixkit SFX（#253/#269/#498/#767/#900/#901/#1104/#1492/#1687/#2032/#2568 等）·
    **Mixkit Sound Effects Free License**（商用免费、免署名、免注册，
    https://mixkit.co/license/#sfxFree）
  - Wikimedia「Civil-defense-siren-waver」by Techtonic 2008 · **Public Domain-self**
    （commons.wikimedia.org，页原文 release into the public domain without any conditions）
  逐项来源/切片参数/哈希：`_steam_assets/licenses/sfx_swap_20261020/swap_manifest_20261020.json`
  （round1~round5 块）+ `LICENSE_EVIDENCE_20261020.md` + `intake_hashes_20261020.json`。
- **字体**：Rajdhani（Indian Type Foundry · SIL OFL 1.1，`assets/fonts/Rajdhani-OFL.txt`）、
  Noto Sans SC（Adobe/Google 联合 · SIL OFL 1.1，`assets/fonts/NotoSansSC-OFL.txt`，
  与 google/fonts 上游逐字节一致）。⚠️ 2026-09-26 勘误：旧 `OFL.txt` 是已删除的
  Barlow 字体的遗留许可文件（张冠李戴），已替换为 Rajdhani 权威文本；
  无署名头的 `LICENSE` 一并移除，现在按字族一一对应。
- 引擎：Godot Engine 4.5.1（MIT License，© Godot Engine contributors、Juan Linietsky
  与 Ariel Manzur——许可全文随包：assets/licenses/）。

## SFX 自合成口径说明

45 个 SFX + 2 个环境音中，**19 个 SFX 仍为项目内生成管线产物**（2026-10-20 换装后
余量）：合成波形代码真身 `managers/sound_generator.gd`（方波+噪声→枪械、低频扫降→
爆炸、正弦扫频→能量武器等原语，16-bit PCM），离线渲染转 OGG 落盘；该脚本至今仍是
运行期音频缺失时的兜底合成器（`base_alarm` 槽 10-20 起已有真实文件 Mixkit 269，
synthesizer 兜底休眠但保留）。**其余 26 个 SFX 槽 + 2 个环境音为 10-20 批第三方
免署名素材**（来源表见上「第三方署名区」）。若其中任何文件后续再被替换为外部素材，
**必须**回写本表（来源/许可/凭证）——并同步检查商店页 AI 披露表单范围（标准集合 S10）。

- **story_page（2026-10-11 增补，v6.57 记录3#1）**：剧情漫画翻格提示音重制为项目内
  程序合成（`tools/_tmp_gen_sfx_v657.py` 可重跑，seed=20261011：扫频带通噪声挥扫
  +36Hz 纸颤+高频碎纸粒，RMS 匹配旧档）。旧档（v6.54 Kenney CC0 划擦声，登记缺口
  补记）备份 `D:/godotplay/_art_backup/sfx_pre_v657_20261011/`。实机主诉"开始剧情/
  黑门出现后剧情过渡提示音很差"（两处同源=序章漫画逐格推进音，黑门在
  intro_comic_panels 第 3 格登场）。**10-20 换装批又换为 Mixkit 1104 Page Turn
  Single（真实翻页声，Mixkit Free License 免署名）——以 10-20 manifest 为准。**
- **SFX 批量换装 28 项（2026-10-20 一轮）**：换机审听反馈（问题.txt）触发，
  逐项来源/许可/哈希证据链 `_steam_assets/licenses/sfx_swap_20261020/`。来源族：Kenney
  Interface/Casino/Impact/Sci-fi/Digital Audio（**CC0**）、Mixkit SFX Free License
  （**商用免署名**）、OGA Boss Battle/Chunky Explosion/Hurt-Death/512 SFX/Wind/
  War on Water（**全 CC0**）。**本批无 CC BY 义务项**。动手前全量备份
  `D:/godotplay/_art_backup/sfx_pre_swap_20261020/`（120 文件，唯一回滚锚点）；
  替换前原始版另存 `资料/audio_review_kit/assets/sfx_backup_20261020/`（换机档案内）。
- **SFX 二轮换装 12 项（2026-10-20 当日复审）**：问题2.txt 复审 #19/#27/#28/#32/#34/
  #48/#49/#50/#52/#53/#59/#60 一轮效果仍不满意，全部换源换音色（Mixkit 11 条新直链 +
  OGA RPG Sound Pack mnstr14，均免署名）。**#52 base_alarm 为新增文件**（此前
  SFX_NAMES 在册但游戏走 sound_generator 运行期合成兜底，无 .ogg 资源）——10-20 起
  落位真实文件（Mixkit 269 Achievement bell，四轮重切片版），AudioManager 按名加载
  命中即自动实生效，无需改代码。逐项证据链 `swap_manifest_20261020.json` 的
  `round2` 块。（二轮中间版备份 `sfx_backup_round2_20261020/` 已随 10-20 收尾清理
  删除，仅保留动手前原始版。）
- **三轮真录音换装 9 项 + 四轮静音修复 + 五轮换源（2026-10-20 同日）**：见下文
  专节；四轮修 ffmpeg `-ss` 输出 seeking + afade 全源时间线 bug（3 项纯数字静音
  根因），五轮 #28/#34/#60 换源。最终成品经用户确认「这套可以了」落位。

## 三轮真录音换装 9 项（2026-10-20）

27 impact_generic.ogg = Mixkit「Wood hard hit」（Mixkit Sound Effects Free License，mixkit.co 免署名）
28 impact_heavy.ogg = OGA BMacZero「Metal Impact Sounds」bong1（CC0，opengameart.org/content/metal-impact-sounds；五轮换，历轮：铁锤→远爆→真金属 bong）
34 unit_death.ogg = OGA「gorilla-sounds」gorilla_roar（CC0，opengameart.org/content/gorilla-sounds；五轮换，三轮起真人包改真兽吼）
32 cast.ogg = OGA「Bell dings/chimes」bell_ding2（Public Domain，opengameart.org/content/bell-dingschimes；四轮重切片修复偏弱）
33 hurt.ogg = OGA「Grunts: male death and pain」death pain grunts.wav 取段（CC0，opengameart.org/content/grunts-male-death-and-pain；四轮输入 seeking 修复）
48 wave_start.ogg = OGA「Horde war drums loop」by William Hector（CC0，opengameart.org/content/horde-war-drums-loop）
49 boss_warn.ogg = Wikimedia「Civil-defense-siren-waver」by Techtonic 2008（Public Domain，commons.wikimedia.org；四轮换最响窗+增益）
52 base_alarm.ogg = Mixkit 269「Achievement bell」（Mixkit Sound Effects Free License；新增文件）
60 lose.ogg = Mixkit 2032「Crowd disappointment long boo」（Mixkit Sound Effects Free License；五轮换，历轮：2029 复古→2027 钢琴→真人群倒彩）

全部免署名可用。切片/转码参数见 `_steam_assets/licenses/sfx_swap_20261020/swap_manifest_20261020.json`
round3~round5 块。（中间版备份 round3/4/5 目录已随收尾清理删除。）

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

## 换曲复用工序（下次再换 BGM/SFX 照此走）

1. 外部备份旧文件（git 不管 .ogg，`D:/godotplay/_art_backup/<批次名>/`）→
2. 下载源素材+许可页抓档入 `_steam_assets/licenses/<source>_<date>/` →
3. 填 `swap_manifest_*.json`（slot/源路径/时长/元数据，多轮换装按 roundN 块累加）→
4. 转码/归一（BGM 走 `tools/bgm_swap_from_manifest.py`：拒截断+响度归一+内嵌元数据+
   同名落位；SFX 手剪走 ffmpeg，**`-ss` 必须放 `-i` 前（输入 seeking）**——
   10-20 四轮实证：输出 seeking + afade 全源时间线会把裁剪段淡成纯数字静音）→
5. `--headless --editor --quit` 重导入 → 6. 更新本表+LICENSE_EVIDENCE+credits 页。
