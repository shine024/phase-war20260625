# 音效资源目录

## 状态：全部已就位（2026-07-17）

共 44 个音频文件，全部已生成并转 OGG 格式。

### SFX 音效（36 个）

#### UI / 系统
- button.ogg - 按钮点击
- button_hover.ogg - 按钮悬停
- panel_open.ogg - 面板打开
- panel_close.ogg - 面板关闭
- card_pickup.ogg - 卡牌拾取
- card_place.ogg - 卡牌放置
- error.ogg - 错误/失败
- cancel.ogg - 取消/操作回退

#### 战斗通用
- hit.ogg - 单位受击
- hurt.ogg - 玩家受伤
- shoot.ogg - 通用射击
- explosion.ogg - 爆炸
- cast.ogg - 施法/相位法则
- impact_generic.ogg - 子弹命中

#### 按武器类型
- gun_smg.ogg - 冲锋枪
- gun_rifle.ogg - 步枪
- gun_mg.ogg - 机枪
- rocket_launch.ogg - 火箭弹
- gun_pistol.ogg - 手枪
- gun_shotgun.ogg - 霰弹枪
- gun_sniper.ogg - 狙击枪
- flak_fire.ogg - 高射炮
- laser_fire.ogg - 激光
- missile_hum.ogg - 导弹
- omega_cannon.ogg - 欧米加炮
- rail_cannon.ogg - 电磁炮

#### 战斗结果
- win.ogg - 胜利
- lose.ogg - 失败
- wave_start.ogg - 新波次开始
- boss_warn.ogg - BOSS 警告
- master_appear.ogg - 相位师登场
- base_destroy.ogg - 基地摧毁

#### 养成系统
- blueprint_unlock.ogg - 蓝图解锁
- enhance.ogg - 强化/合成成功
- achievement.ogg - 成就解锁
- quest_complete.ogg - 任务完成

### BGM 背景音乐（8 首）

**2026-09-26 全量换曲**：全部为 Kevin MacLeod（incompetech.com）作品，
CC BY 4.0（署名义务由游戏内 credits 页 + assets/sfx/CREDITS.md 承载）。
逐曲 ISRC/时长/SHA256/源 URL 见 CREDITS.md 与
`_steam_assets/licenses/incompetech_20260926/LICENSE_EVIDENCE.md`。

- **bgm_title.ogg** — At Launch（185秒，标题屏）
- **bgm_hub.ogg** — Peaceful Desolation（91秒，基地）
- **bgm_battle_ww1.ogg** — Devastation and Revenge（185秒，一战）
- **bgm_battle_ww2.ogg** — Five Armies（156秒，二战）
- **bgm_battle_cold.ogg** — Crypto（204秒，冷战）
- **bgm_battle_modern.ogg** — Rock Hybrid（130秒，现代）
- **bgm_battle_future.ogg** — Space Fighter Loop（101秒，近未来）
- **bgm_boss.ogg** — Final Battle of the Dark Wizards（272秒，Boss 战）

> 旧 7 首"YouTube 免费音乐库 CC0"来源曲已于 2026-09-26 退役（凭据不可追溯，
> UNVERIFIED 红线清零批次）；本体备份在项目外 _art_backup 目录。
> 换 BGM 的标准工序见 CREDITS.md 文末「换曲复用工序」。

## BGM 自动切换逻辑

AudioManager 已实现完整 BGM 系统：
- 游戏启动 → 播放 bgm_title
- 进入主界面 → 切 bgm_hub
- 进入战斗 → 根据关卡时代自动切对应 battle BGM
- BOSS 登场 → 切 bgm_boss
- 战斗结束 → 淡出后切回 bgm_hub
- 所有切换带 1.5s 淡入淡出效果

## 技术规格

- 格式：OGG Vorbis
- 采样率：44.1kHz
- 比特率：SFX 128kbps / BGM VBR q6（≈190kbps）
- 声道：SFX 单声道，BGM 立体声
- 响度：BGM 已统一归一（-14 LUFS 目标，峰值保护；tools/bgm_swap_from_manifest.py）

## 代码集成

- AudioManager 已内置 MusicPlayer + fade 切换
- SFX_NAMES 覆盖全部 36 个音效槽位
- BGM_MAP 映射全部 8 首背景音乐
- 无需修改其他代码即可生效
