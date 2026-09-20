# 音频素材授权凭据（CREDITS）

> 建档：2026-09-20（标准集合 S17 缺口修复）。本文件是发行凭据唯一存档点，
> 游戏内「制作人员/许可」页的数据源之一。
> **红线：商店页提交前本表不得留有 UNVERIFIED 状态的条目**（见文末行动清单）。

## 结论速览（2026-09-20 核验）

| 类别 | 数量 | 凭据状态 | 判定 |
|---|---|---|---|
| SFX | 36 个 | ✅ 项目内生成管线产物（自合成，无第三方素材） | 无外部授权义务 |
| 环境音 | 1 个（ambient_battle_wind.wav） | 同上，自合成 | 无外部授权义务 |
| **BGM** | **7 首** | ❌ **UNVERIFIED——原始署名/许可凭据丢失** | **必须追溯或替换后方可上架** |

## BGM 凭据丢失经过（技术核验记录，2026-09-20）

- 来源声明：`assets/sfx/README.md`（2026-07-17 建档）自述"YouTube 免费音乐库下载，
  CC0/无版权限制"。**该声明是假设不是凭据**：YouTube Audio Library 各曲许可混杂
  （CC0 / CC-BY（要求署名）/ 标准 YouTube 许可（不授权游戏内再分发）），按曲而异。
- **文件层追溯已断**（2026-09-20 实测）：对 7 首 OGG 逐个解析 Ogg Vorbis comment header，
  全部只含转码器痕迹 `encoder=Lavc62.11.100 libvorbis`（ffmpeg/Lavf62.3.100 转码），
  title 字段已被覆写为内部文件名（bgm_title 等）——**原始曲名/创作者/许可链接在转码时即丢失，
  文件本身无法自证来源**。
- 结论：走标准集合 S17 的"替换"腿（查不到凭据 = 视同未授权）。

## BGM 逐曲状态表

| 文件 | 用途 | 时长 | 凭据状态 | 处置 |
|---|---|---|---|---|
| bgm_title.ogg | 标题屏 | 162s | ❌ UNVERIFIED | 待替换 |
| bgm_hub.ogg | 基地/整备 | 121s | ❌ UNVERIFIED | 待替换 |
| bgm_battle_ww1.ogg | WW1 战斗 | 282s | ❌ UNVERIFIED | 待替换 |
| bgm_battle_ww2.ogg | WW2 战斗 | 118s | ❌ UNVERIFIED | 待替换 |
| bgm_battle_modern.ogg | MODERN 战斗 | 101s | ❌ UNVERIFIED | 待替换 |
| bgm_battle_future.ogg | FUTURE 战斗 | 89s | ❌ UNVERIFIED | 待替换 |
| bgm_boss.ogg | Boss 战 | 330s | ❌ UNVERIFIED | 待替换 |

## 替换/追溯行动清单（二选一，上架前完成）

**腿 A 追溯（仅当用户侧仍找得到下载记录）**：浏览器下载历史 → 找到每曲的
YouTube Audio Library 原页 → 记录 曲名/创作者/许可类型 到本表 → CC-BY 曲目
把署名写进下方「第三方署名」区；标准 YouTube 许可曲目仍须替换（该许可不覆盖游戏内嵌）。

**腿 B 替换（推荐，凭据确定性最高）**：从明确商业授权渠道取曲
（如 itch.io 付费音乐包 / Unity Asset Store / Artlist 类订阅，保留发票或许可证 PDF
入 `_steam_assets/licenses/`），换同名文件重跑 `--headless --editor --quit` 完成重导入，
然后逐行更新本表状态为 ✅（附许可类型与凭证文件名）。

## 第三方署名区（游戏内 credits 页同步展示）

- 字体：Rajdhani（SIL OFL 1.1）、Noto Sans SC（SIL OFL 1.1）——assets/fonts/ 内含 OFL.txt。
- 引擎：Godot Engine 4.5.1（MIT License，© Juan Lini and the Godot community）。
- 待 BGM 凭据落定后在此追加音乐署名（若有 CC-BY 义务）。

## SFX 自合成口径说明

36 个 SFX + 环境风声为项目内生成管线产物（2026-07-17 README 记录"全部已生成"），
无第三方素材引用。若其中任何文件后续被替换为外部素材，**必须**回写本表
（来源/许可/凭证）——并同步检查商店页 AI 披露表单范围（标准集合 S10）。
