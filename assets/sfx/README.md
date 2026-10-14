# 音效资源目录

## 状态：全部已就位（2026-10-20 换机审核批更新）

共 60 个音频文件（45 SFX + 13 BGM + 2 环境音），全部已生成/落位并转 OGG 格式
（环境音 2 个为 WAV）。

**2026-10-20 换机审核批（v6.69）**：用户经审听页逐条试听后，28 槽替换 + base_alarm
新增落位（历五轮终版）。本批 26 个 SFX 槽 + 2 环境音 + 1 BGM 为第三方免署名素材
（Kenney CC0 / OGA CC0·PD / Wikimedia PD / Mixkit Free License），**无 CC BY 署名
义务项**；动手前全量备份 `D:/godotplay/_art_backup/sfx_pre_swap_20261020/`。逐项
来源/切片参数/哈希见 `CREDITS.md` 与
`_steam_assets/licenses/sfx_swap_20261020/swap_manifest_20261020.json`。

### SFX 音效（45 个：19 自合成 + 26 第三方免署名）

**10-20 批第三方来源速查**（详情 `CREDITS.md`「第三方署名区」）：
- Kenney CC0（6）：button / card_pickup / error / cancel / hit / impact_light
- OGA CC0·PD（7）：impact_heavy（bong1）/ explosion_big（Chunky）/ cast（bell_ding2）/
  hurt（真人痛哼）/ unit_death（大猩猩吼）/ rocket_launch（512 SFX）/ wave_start（真战鼓）
- Wikimedia PD（1）：boss_warn（真民防警报实录）
- Mixkit Free（12）：panel_close / story_page / impact_generic / master_appear /
  base_destroy / base_alarm（**新增文件**）/ ultimate_ready / return_base /
  enhance / quest_complete / win / lose
- 环境音（2）：ambient_battle_wind（OGA 风+炮火点缀合成 30s）/
  ambient_wakeup_wind（OGA Wind+Wind2 交叉淡化 12s）

#### UI / 系统
- button.ogg - 按钮点击（10-20 换：Kenney click_001）
- button_hover.ogg - 按钮悬停（自合成）
- panel_open.ogg - 面板打开（自合成）
- panel_close.ogg - 面板关闭（10-20 换：Mixkit 2568 界面返回音）
- card_pickup.ogg - 卡牌拾取（10-20 换：Kenney 卡牌滑动）
- card_place.ogg - 卡牌放置/部署（自合成）
- error.ogg - 错误/失败（10-20 换：Kenney error_001）
- cancel.ogg - 取消/操作回退（10-20 换：Kenney back_001）
- story_page.ogg - 剧情漫画翻格（10-20 换：Mixkit 1104 真实翻页声）

#### 战斗通用
- hit.ogg - 单位受击（中档，10-20 换：Kenney impactPlate_medium）
- hurt.ogg - 玩家受伤（10-20 换：OGA 真人痛哼取段）
- shoot.ogg - 通用射击（自合成）
- explosion.ogg - 爆炸（自合成）
- explosion_big.ogg - 大爆炸/核爆级（10-20 换：OGA Chunky Explosion 3.2s）
- cast.ogg - 施法/相位法则（10-20 换：OGA 真实铃击 bell_ding2）
- impact_generic.ogg - 命中中档 tier2（10-20 换：Mixkit 498 实录木板重击）
- impact_light.ogg - 命中轻档（10-20 换：Kenney impactPlate_light）
- impact_heavy.ogg - 命中重档（10-20 换：OGA BMacZero 金属深击 bong1）
- unit_death.ogg - 单位阵亡（10-20 换：OGA gorilla_roar 真兽吼）

#### 按武器类型（10-10 CC0 真枪批 + 自合成，本批未动）
- gun_smg.ogg - 冲锋枪
- gun_rifle.ogg - 步枪
- gun_mg.ogg - 机枪
- rocket_launch.ogg - 火箭弹（10-20 换：OGA 512 SFX rocket_01）
- gun_pistol.ogg - 手枪
- gun_shotgun.ogg - 霰弹枪
- gun_sniper.ogg - 狙击枪
- flak_fire.ogg - 高射炮
- laser_fire.ogg - 激光
- missile_hum.ogg - 导弹（Kenney Sci-Fi）
- omega_cannon.ogg - 欧米加炮
- rail_cannon.ogg - 电磁炮
- cannon_fire.ogg - 火炮开火（自合成，v6.42 力度分级 tier2/3 专属）

#### 战斗结果 / 节奏
- win.ogg - 胜利（10-20 换：Mixkit 767 中世纪号角凯旋）
- lose.ogg - 失败（10-20 换：Mixkit 2032 真人群倒彩）
- wave_start.ogg - 新波次开始（10-20 换：OGA William Hector 实录战鼓）
- boss_warn.ogg - BOSS 警告（10-20 换：Wikimedia 真民防警报实录）
- master_appear.ogg - 相位师登场（10-20 换：Mixkit 901 末日踏地）
- base_destroy.ogg - 基地摧毁（10-20 换：Mixkit 1687 金属爆毁）
- base_alarm.ogg - 基地低血量告警（**10-20 新增**：Mixkit 269 实录警铃；
  此前仅 SFX_NAMES 在册 + sound_generator 运行期合成兜底，现按名加载命中真实文件）

#### 养成系统
- blueprint_unlock.ogg - 蓝图解锁（自合成）
- enhance.ogg - 强化/合成成功（10-20 换：Mixkit 2870 上扬正反馈）
- achievement.ogg - 成就解锁（自合成）
- quest_complete.ogg - 任务完成（10-20 换：Mixkit 253）
- ultimate_ready.ogg - 大招就绪（10-20 换：Mixkit 900 铃音）
- return_base.ogg - 回基地转场（10-20 换：Mixkit 1492 转场 whoosh）

### 环境音（2 个，10-20 换 OGA CC0 底）

- ambient_battle_wind.wav - 战场风声+远炮点缀（10-20 换：IgnasD Wind 循环底 ×
  War on Water 炮火稀疏点缀，30s 立体声）
- ambient_wakeup_wind.wav - 苏醒演出柔风（10-20 换：IgnasD Wind+Wind2
  交叉淡化 12s）

### BGM 背景音乐（13 首：12 首 Kevin MacLeod CC BY 4.0 + 1 首 OGA CC0）

**2026-09-26 全量换曲**：12 首为 Kevin MacLeod（incompetech.com）作品，
CC BY 4.0（署名义务由游戏内 credits 页 + assets/sfx/CREDITS.md 承载）。
逐曲 ISRC/时长/SHA256/源 URL 见 CREDITS.md 与
`_steam_assets/licenses/incompetech_20260926/LICENSE_EVIDENCE.md`。
**2026-10-20 换曲 1 首**：bgm_battle_ww1 由 Kevin MacLeod「Devastation and
Revenge」换 **Juhani Junkala「Epic Boss Battle」（OGA · CC0，无缝循环 123.4s）**
——解决「前奏太长」主诉；授权改 CC0 免署名。

- **bgm_title.ogg** — At Launch（185秒，标题屏）
- **bgm_hub.ogg** — Peaceful Desolation（91秒，基地/大地图回退）
- **bgm_hub_ww1.ogg** — Man Down（一战基地）
- **bgm_hub_ww2.ogg** — Take the Lead（二战基地）
- **bgm_hub_cold.ogg** — Spy Glass（冷战基地）
- **bgm_hub_modern.ogg** — Bass Walker（现代基地）
- **bgm_hub_future.ogg** — Space Fighter Loop（近未来基地）
- **bgm_battle_ww1.ogg** — **Epic Boss Battle（10-20 换曲，Juhani Junkala · OGA CC0，一战战斗）**
- **bgm_battle_ww2.ogg** — Five Armies（二战战斗）
- **bgm_battle_cold.ogg** — Crypto（冷战战斗）
- **bgm_battle_modern.ogg** — Rock Hybrid（现代战斗）
- **bgm_battle_future.ogg** — Hiding Your Reality（近未来战斗）
- **bgm_boss.ogg** — Final Battle of the Dark Wizards（Boss 战）

> 旧 7 首"YouTube 免费音乐库 CC0"来源曲已于 2026-09-26 退役（凭据不可追溯，
> UNVERIFIED 红线清零批次）；本体备份在项目外 _art_backup 目录。
> 换 BGM 的标准工序见 CREDITS.md 文末「换曲复用工序」。

## BGM 自动切换逻辑

AudioManager 已实现完整 BGM 系统：
- 游戏启动 → 播放 bgm_title
- 进入基地/大地图 → 按当前时代切 hub 五键（music_key_for_current_era，时代曲缺失回退 bgm_hub）
- 进入战斗 → 根据关卡时代自动切对应 battle BGM
- BOSS 登场 → 切 bgm_boss
- 战斗结束 → 淡出后回 hub（黑门无限 run 驻留 boss；L100 胜利切 title）
- 所有切换带 1.5s 淡入淡出效果

## 技术规格

- 格式：OGG Vorbis（SFX/BGM）+ WAV 16-bit PCM（环境音 2 个）
- 采样率：44.1kHz
- 比特率：自合成 SFX 128kbps；BGM VBR q6（≈190kbps）；10-20 第三方批 OGG q5
- 声道：SFX 单声道为主，BGM 立体声，环境音立体声
- 响度：BGM 已统一归一（-14 LUFS 目标，峰值保护；tools/bgm_swap_from_manifest.py）；
  10-20 批 SFX 按项 max≈-2~-5dB 实测归一（manifest round3~5 记录增益）

## 代码集成

- AudioManager 已内置 MusicPlayer + fade 切换
- SFX_NAMES 覆盖 40 个音效槽（含 base_alarm——10-20 起有真实文件，按名加载
  命中即生效，sound_generator 合成兜底休眠保留）
- BGM_MAP 映射 13 首（title/hub 六键/battle 五键/boss）
- 环境音 AMBIENT_MAP 双键（battle_wind/wakeup_wind）
