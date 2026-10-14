# SFX 批量换装证据 2026-10-20（审听反馈 28 项）

触发：审听页 `资料/audio_review_kit/index.html` 用户实测后提交 `问题.txt`（28 项不满意），
拍板「直接下载替换」。旧文件完整备份 `assets/sfx_backup_20261020/`（61 文件）。
清单：`swap_manifest_20261020.json`；源哈希：`intake_hashes_20261020.json`。

## 许可结论（免署名，无 CC BY 义务项）

| 来源族 | 许可 | 覆盖条目 | 证据 URL |
|---|---|---|---|
| Kenney（Interface / Casino / Impact / Sci-fi / Digital Audio） | **CC0** | #16 #19 #20 #22 #23 #25 #26 #27 #28 #32 #48 #50 #53 | https://kenney.nl/assets/interface-sounds 等（各资产页 License 栏标注 CC0，2026-10 亲验） |
| Mixkit SFX | **Mixkit Sound Effects Free License**（商用免费、免署名、免注册） | #24 #49 #51 #54 #56 #58 #59 #60 | https://mixkit.co/license/#sfxFree |
| OGA：Boss Battle（Juhani Junkala） | CC0 | #8 | https://opengameart.org/content/boss-battle-music |
| OGA：Chunky Explosion（OwlishMedia） | CC0 | #31 | https://opengameart.org/content/chunky-explosion |
| OGA：Hurt/Death for character（Badre-Eddine） | CC0 | #33 #34 | https://opengameart.org/content/hurt-death-sound-effect-for-character |
| OGA：512 Sound Effects（Juhani Junkala） | CC0 | #38 | https://opengameart.org/content/512-sound-effects-8-bit-style |
| OGA：Wind sounds（IgnasD） | CC0 | #14 #15 | https://opengameart.org/sites/default/files/wind.zip |
| OGA：War on Water（V-visions） | CC0 | #14 点缀层 | https://opengameart.org/sites/default/files/sndfx.zip |

Mixkit 直链规律：`https://assets.mixkit.co/active_storage/sfx/<ID>/<ID>-preview.mp3`
（本会话 8 条均以此直链下载，哈希见 intake_hashes）。

## 二轮补充（问题2.txt 复审 12 项，同日）

| 来源族 | 许可 | 覆盖条目（二轮） | 证据 URL |
|---|---|---|---|
| Mixkit SFX（11 条新直链 2568/2183/788/2350/2600/2462/901/999/900/767/2029） | Mixkit Sound Effects Free License | #19 #27 #28 #32 #48 #49 #50 #52(新) #53 #59 #60 | https://mixkit.co/license/#sfxFree ；分类页 235 条目录缓存 `_dl/_pages/mixkit_catalog.txt` |
| OGA：RPG Sound Pack（artisticdude） | **CC0**（作者在评论区亲口回复「all the sounds are CC0 … without having to give attribution」，页面已抓档 `_dl/_pages/oga_rpgpack.html`） | #34 | https://opengameart.org/content/rpg-sound-pack |

- 二轮全量仍为免署名授权，无 CC BY 义务项。
- 一轮文件备份 `assets/sfx_backup_round2_20261020/`（11 个）；#52 一轮无文件，二轮新增。

## 加工记录

- Kenney 13 项：包内 OGG **原尺寸直拷**（文件头 OggS 逐一验证），无转码。
- Mixkit 8 项：mp3 → OGG Vorbis q5（ffmpeg 8.0，`-c:a libvorbis -q:a 5`）。
- 裁剪项：#31 `5.62s→3.2s`+0.6s 淡出；#34 `2.36s→1.5s`+0.3s 淡出；#38 `2.05s→1.4s`+0.35s 淡出。
- 合成项：#15 = wind 包 Wind+Wind2 `acrossfade 1.5s` → 11.79s；#14 = Wind.ogg 循环风底(0.55,
  lowpass 3.8k) × shipexplode×4 + gun2Heavy×6 + boatexplode×1 稀疏点缀（amix normalize=0）→ 30s，
  44100Hz 立体声 pcm_s16le，首尾淡入淡出。
- 原文件时长基准（备份档）：hurt 0.26s / unit_death 1.1s / explosion_big 2s / cast 0.5s /
  rocket_launch 0.95s / ambient_battle_wind 30s / ambient_wakeup_wind 12s / bgm_battle_ww1 185.26s。

## 下载通道备注

- kenney.nl 与 assets.mixkit.co 直连快；opengameart.org ~14KB/s 需 `curl -C -` 断点续传。
- 本机系统代理 127.0.0.1:10808 已死，iwr/curl 默认走它必挂：curl 需 `--ssl-no-revoke`，
  或临时 `ProxyOverride`/`-NoProxy`。Freesound 需登录下载，本轮全部绕开。

## 待办

- [x] #8 `bgm_battle_ww1.ogg`：boss_battle.wav（21,773,152B，RIFF 头校验完整）已到位，
      ffmpeg → OGG q5 123.43s 覆写完成，manifest 该条已改 DONE（2026-10-20）。28/28 全部落位。
- [ ] 游戏本体若直接消费 `assets/sfx/`：重导入后跑一遍实机听感（审听页可复听）。

## 三轮换装许可证据（2026-10-20，9 项全真实录音）

原则：用户要求「尽量少用合成」。本轮全部改为真实录音（真 foley 击打 / 真人声 / 真乐器 / 真警报警铃录音）。
许可速览：Mixkit 5 项 = Mixkit Sound Effects Free License（商用免署名，https://mixkit.co/license/#sfxFree）；
OGA 3 包 3 项 + Wikimedia 1 项 = CC0 / Public Domain（商用免署名）。仍无任何需署名条目。#49 首试 Mixkit 1995 后升级：Mixkit 页面无法证明真实性，改用 Commons 页面明载「release into the public domain…without any conditions」的真警报实录。

| 槽位 | 来源 | 直链 | 许可 |
|---|---|---|---|
| #27 impact_generic | Mixkit 498 Wood hard hit（实录木板重击） | https://assets.mixkit.co/active_storage/sfx/498/498-preview.mp3 | Mixkit Free |
| #28 impact_heavy | Mixkit 3046 Metal hammer hit（实录铁锤砸金属） | https://assets.mixkit.co/active_storage/sfx/3046/3046-preview.mp3 | Mixkit Free |
| #49 boss_warn | Wikimedia Civil-defense-siren-waver（明尼苏达真民防警报实录，呜咽档） | https://commons.wikimedia.org/wiki/File:Civil-defense-siren-waver.ogg | PD-self |
| #52 base_alarm | Mixkit 269 Achievement bell（实录铃击→警铃） | https://assets.mixkit.co/active_storage/sfx/269/269-preview.mp3 | Mixkit Free |
| #60 lose | Mixkit 2027 Losing piano（真钢琴下行短句） | https://assets.mixkit.co/active_storage/sfx/2027/2027-preview.mp3 | Mixkit Free |
| #32 cast | OGA「Bell dings/chimes」bell_ding2.wav（真实薄铃击） | https://opengameart.org/content/bell-dingschimes | Public Domain |
| #33 hurt | OGA「Grunts: male death and pain」取痛哼段 | https://opengameart.org/content/grunts-male-death-and-pain | CC0 |
| #34 unit_death | 同上包取濒死长哼段 | 同上 | CC0 |
| #48 wave_start | OGA「Horde war drums loop」William Hector | https://opengameart.org/content/horde-war-drums-loop | CC0 |

OGA 页面亲核摘录（curl 抓页原文）：
- bell-dingschimes 页正文：「Somewhat thin and short chime sound. Copyright/Attribution Notice: Releasing as public domain.」→ 公有领域，可用免署名。
- grunts-male-death-and-pain 页许可字段：CC0。文件 death pain grunts.wav（4,380,108B，约 19 段独立痛哼/濒死哼，按静音切分定位取段）。
- horde-war-drums-loop 页许可字段：CC0，作者 William Hector，文件 horde_war_drums_by_william_hector.wav（3,908,120B，14.77s 密集循环）。

通道备注（本轮新证）：Pixabay 被 Cloudflare「Just a moment…」质询拦截（curl 无法过）；Freesound 需登录；
BBC Sound Effects（RemArc）禁商用——三者均未使用。备选已存档未用：_dl/oga3/yelling_sounds.zip（OGA male-gruntyelling-sounds，CC0）、
_dl/oga3/gorilla.zip（OGA gorilla-sounds，CC0，真实大猩猩录音，可作兽类阵亡备选）。
加工流水与切片参数见 swap_manifest_20261020.json round3 块。
调研子代理补充证据：grunts-male-death-and-pain 页作者原话「You have my blessing to do whatever you want with this sound file」（CC0 双证）； horde-war-drums-loop 真实性存采样盘疑问（CC0 无疑，听感为真鼓采样循环）；备选未用清单见子代理报告存档 _dl/_pages/oga_*。

## 四轮补记（2026-10-20 静音修复轮）

用户反馈「有的没声音」→ 实测 #33/#34/#49 为 -91dB 纯数字静音。根因=-ss 输出 seeking + afade 全源时间线（详见 swap_manifest round4 _comment）。

- #28 impact_heavy **换源**：OGA「Muffled Distant Explosion」NenadSimic，https://opengameart.org/content/muffled-distant-explosion ，页许可字段 CC0（免署名）。原三轮 Mixkit 3046 仍存 _dl/mixkit3/ 备用。
- #32 cast 广岛和平钟（Wikimedia 25822_heigh-hoo_peace-bell-hiroshima.wav）试听后弃用：录音整体太弱（敲击窗 mean -44dB），拉增益会带起底噪；维持 bell_ding2 仅去 aecho+归一。
- 其余 4 项（#33/#34/#49/#60）源与许可不变，仅重切片+输入 seeking 修复+响度归一（max 复测 -5.1~-2.0dB），切片参数见 swap_manifest_20261020.json round4。
- 四轮后仍无任何需署名条目（新增源为 CC0）。

## 五轮补记（2026-10-20 重找轮）

#28/#34/#60 换源（用户「重找」）。三项许可均免署名：

- #28 impact_heavy ← OGA「Metal Impact Sounds」bong1.wav，https://opengameart.org/content/metal-impact-sounds ，页许可字段 CC0（页原文 Copyright/Attribution Notice: Optionally credit Brian MacIntosh——署名可选）。web_fetch 亲核页原文。
- #34 unit_death ← OGA「gorilla-sounds」gorilla_roar.ogg（gorilla.zip 内 ogg/gorilla_roar.ogg，三轮已存档），该包三轮已核 CC0。
- #60 lose ← Mixkit 2032 Crowd disappointment long boo，直链见 _dl/_pages/mixkit_catalog.txt:143（三轮编目亲核），Mixkit Sound Effects Free License 免署名。

五轮后仍无任何需署名条目。
