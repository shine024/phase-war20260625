# Steam 上架冲刺 · 会话工作记录（2026-09-02~03）

> 一轮会话三块工作：①战场单位可读性修复 ②Steam 商店素材全套（截图/视频/胶囊图）③标题画面重制。
> 变更明细按时间序见 `docs/CHANGELOG.md` v26.9 A-E 节；本文是**决策与复现视角**的归档记录。

---

## 一、战场单位可读性三件套（v26.9 A-C）

### 起因

用户实机反馈：战斗画面我方卡图在背景上不清晰（`_anim_review/对比图/战斗.png`）。

### 诊断（量化证据）

| 采样区 | 亮度 | 与背景差 |
|---|---|---|
| 我方炮车本体 | ~126 | 与沙地差 **30-60**（同色域融底） |
| 我方野炮本体 | ~95 | 同上 |
| 敌方机甲本体 | ~113 | 与背景差 ~100（天然清晰） |

代码侧确认：描边只存在于文字（名牌/飘字），单位 sprite 零边缘处理；地面单位零投影（只有 v23.5 空中单位有）；中景雾化亮带恰在单位站位线上进一步吃轮廓。

### 修复（三项全做，统一深色描边）

| # | 内容 | 文件 |
|---|------|------|
| 1 | **alpha 膨胀描边 shader**（8 向×3 环取样，1.6 屏幕像素深色外扩；半透明像素保护不涂实） | `shaders/unit_outline.gdshader` + `scripts/battle/unit_outline.gd` |
| 2 | **全单位投影**（空中=呼吸悬空影；地面=贴地接触影 ×0.72 透明度） | `scripts/battle/air_unit_shadow.gd`（推广）+ `card_grid_unit_visuals.gd`（`_sync_air_shadow`→`_sync_unit_shadow`） |
| 3 | **背景压暗一档** `BG_DIM=(0.80,0.80,0.87)` 叠乘时代 tint | `scenes/battlefield/battlefield.gd`（收口 `_apply_background_texture`） |

### ⚠️ 关键契约（改单位贴图/缩放前必读）

凡运行期直写 `unit_spr.texture` 或 `scale`，**必须调 `UnitOutline.refresh(spr)`**：
- `edge_texels = OUTLINE_PX / scale.x`（帧动画 attach 有 scale×2 补偿，不刷则描边翻倍）
- `region_uv` 收敛到当前帧 UV 区——雪碧图 AtlasTexture 不裁剪会采到**相邻帧轮廓**出鬼影
- 已接入：UnitFrameAnim.FrameDriver 三处 / BossIdleAnim.FrameDriver；AttackPoseAnim 同分辨率整图无需刷新

### 验证

- `tests/_tmp_outline_check.gd`（shader 加载/uniform 数学含 AtlasTexture 换算/投影双模式）ALL PASS
- master_power_smoke 8/8；`run.scene_headless` 渲染验收（真实 L100 背景+6 张真实卡走完整链）：描边清晰、贴地影可读、帧动画无越帧鬼影
- 对比图：`_anim_review/对比图/_before_after.png`

---

## 二、Steam 商店素材全套

### 环境侦察结论（决定了整条管线）

- 采集机显示器仅 **1024×768 虚拟屏** → 交互式截屏路线否决，改引擎内视口捕获
- `run.scene_headless` 裸模式陷阱：不带 screenshots 参数 = headless 假窗口渲染全空（详见 AGENTS.md agent_tools 第 7 条）
- 1920×1080 超屏窗口在 ANGLE 环境渲染表面丢失 → 战场走 **SubViewport 超采样**（渲染目标独立于窗口），UI 走窗口捕获+blur-pad
- ffmpeg 8.0 可用（gyan essentials build）

### 采集编排器 `tests/_tmp_steam_cap.gd`（可复用范例）

模式：`title / map / base / panel / battle / battle_long`（写入 `.godot/steam_cap_mode.txt`）。
踩坑沉淀（全部已写入 AGENTS.md 第 8 条）：
1. 绝不 `change_scene_to_file`（释放驱动器静默断链）——用 `root.add_child + current_scene` 赋值
2. match 分支协程必须 `await`（否则协程链孤儿回收，函数只跑前半段）
3. AFK 推图入口会被 AFK 推图进度钳到 L1/2——改手动选关链 `set_current_level(100) + on_start_battle + 自动部署按钮`
4. 离线奖励弹窗污染 UI 截图——只删 offline dialog 本体（popup_layer 下驻留 overlay 面板，全清会断链）
5. 战场相机被 screen_shake 夺权——自建第二相机 `make_current`；内容带 world y∈[140,853]，机位 cam.y=495、zoom 1.5

### 交付物（`_steam_assets/`）

| 目录 | 内容 |
|------|------|
| `screenshots/` | 7 张 1920×1080 商店截图：战斗×3（SubViewport 原生 1080p 无 HUD）+ 基地/世界地图/成长/标题×4（blur-pad） |
| `video/phase_war_trailer.mp4` | 65.3s 预告片（片头卡 3.5s → L100 实机 60s → 片尾卡 3s，交叉淡化，H.264+AAC crf18）；母带 `battle_raw.avi`（215MB 无损）保留 |
| `capsules/` | 胶囊图 12 张：header 920×430 / small 462×174 / main 616×353 / 页面背景 1438×810 / 社区图标 184×184 / library capsule 600×900 / hero 3840×1240 / logo 1280×720（+2x 版本） |
| `README.md` | 上传顺序、重新采集方法、上架待办 |

### 录制管线

`--write-movie battle_raw.avi --fixed-fps 30`（Movie Maker，含立体声）→ ffmpeg：
`crop=1028:578:0:85`（裁掉窗口边带）→ `scale=1920:1080:lanczos + unsharp` → xfade 交叉淡化 → 片头/片尾卡为 PIL 生成（Noto Sans SC + Rajdhani，青色主色）。

### 顺手修复（上架阻断项）

标题页 4 个开发按钮（切换存档/战斗效果检查/3v3 群战演练/重看开场）原本无 debug 门控、
正式构建常驻 → `title_screen.gd` 按 `OS.is_debug_build()` 隐藏（场景按钮运行时隐藏 +
`_add_replay_intro_button` 创建期短路，双保险）。

---

## 三、标题画面重制（v26.9 E）

### 起因

用户反馈"开始界面背景不好"——旧图是 `bg_default.png` 压暗 0.58 一战废墟，灰蒙蒙。

### 新背景（agnes 生成专属 key art）

- 生成器 `tools/generate_title_bg.py`，两方案 prompt（遵循 `tools/_agnes_image_api.md` 行为实测：
  负面词只留结构性排除、内容全部正面意象锁死、左侧暗部负空间写进 prompt）
- **v1 命中**：巨型相位机甲立于二战废墟、青色能量纹、左侧暗部天然放菜单列 →
  放大 1920×1080 落盘 `assets/backgrounds/title_bg.png`
- v2 备选（相位传送门）留档 `_steam_assets/video/title_bg_v2.png`
- ⚠️ agnes `size=1920x1080` 参数实际返回 1312×736（等比），放大+轻锐化后可用

### 配套美化（ui-review 规范：token/工厂/层级）

| 项 | 旧 → 新 |
|----|---------|
| 背景 modulate | 0.58 洗白 → 0.85 + 左侧 GradientTexture2D 暗部渐变 |
| 菜单列位置 | 屏幕正中 → 左 52%（节点路径零破坏） |
| 标题 lockup | 64px 纯青 Label → 88px Noto Medium + 字距 + 描边阴影 + 青色分隔线 |
| 副题 | 紫色 → 青灰 Rajdhani 字距版 |
| 按钮层级 | 平铺 → 三层：主操作 solid（新游戏/继续/进入基地）/ 次操作 ghost（设置/退出）/ 开发灰弱化 |
| 版本号 | 硬编码 "v0.1.0" → 读 `project.godot application/config/version`（新设 0.26.9） |
| 呼吸动效 | scale 脉冲（左上轴心会左右漂移）→ self_modulate 亮度脉冲 |

### 胶囊图统一（跟进轮）

`tools/make_steam_capsules.py` 底图从战斗截图换为机甲 key art（`crop_band` 加横向锚点参数，
竖版 library capsule 裁切对准机甲）——标题页/预告片片头卡/商店截图/胶囊图全部同源同风格。

### 验证

gdparse / `tests/ui_p1_validation.gd` ALL PASS（53 文件）；实拍对比
`_anim_review/对比图/_title_before_after.png`；商店 06_title.png 已重拍。

---

## 四、遗留待办（非本轮范围）

1. **商店文案与定价**：Steamworks 后台人工填写（简短描述/详细介绍/标签）
2. **预告片传 YouTube**：mp4 上传后回填商店视频链接
3. 视频如需更精剪（字幕/节奏/配乐）：母带 `_steam_assets/video/battle_raw.avi`
4. 正式构建（非 debug）实测一次标题页：确认开发按钮隐藏生效
5. 战斗截图后 3 张（battle_4~6）是战斗结束后的空场，留档未删；如需更多战斗瞬间可重跑 battle 模式
