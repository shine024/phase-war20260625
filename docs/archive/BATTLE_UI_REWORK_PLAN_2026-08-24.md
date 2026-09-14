# 战斗界面美化执行方案（P0+P1+P2 全量 · 10 批次 · 2026-08-24）

> 来源：2026-08-24 战斗界面"机械无趣"问题诊断 + 用户确认的三级全量方案。
> 与 `docs/UI_OPTIMIZATION_PLAN_2026-08-24.md`（批次三：tooltip/帮助面板/颜色清剿）并存、互不冲突。
> 完成一批就勾选 + CHANGELOG 记批次。

## 0. 诊断（为什么感觉"机械无趣"）

战斗"内容"不缺料——震屏、定帧、BOSS 横幅、几十种命中特效都在（BattleSpectacle + VfxImpactFactory 很厚实）。**无聊的是"框"**：

1. **底部 124px 是"工程面板"**：相位仪栏和功能按钮栏是 tscn 手写 StyleBoxFlat（直角、无发光、仅 2px 顶边亮线），与 PanelStyles 体系（12 圆角 + accent 发光）两种语言；15 个功能按钮常驻，视觉权重淹没真正的核心操作（部署槽）。
2. **战场没有纵深**：GridPattern 是 2% 透明色块而非网格；背景图缺失退化为纯色；双方 3×3 斜阵无地面引导，单位像悬浮在黑布上。
3. **基地毫无存在感**：相位场驱动器（200HP 胜负核心）只是 x=40 边缘小 Sprite（scale 0.08），无光环/血条/任何视觉宣告。
4. **敌我无色彩身份**：全屏单一霓虹青 accent，绿血条 vs 红血条是唯一阵营区分。
5. **关键信息是裸文字**：顶部"第 N 关/波次/时间"无底板悬浮；战斗能量无常驻条（藏在 tooltip）；波次无进度可视化。

## 1. 设计方向与总原则

**方向：「深色玻璃拟态 + 双阵营霓虹识别」。** 战场本体是视觉主角，UI 退为半透明悬浮玻璃件；我方 = 霓虹青（`DT.COLOR_ACCENT_CYAN`），敌方 = 信号红，中性系统 UI 沿用青。**不引入新美术外包**——全部效果程序生成（Polygon2D / GradientTexture2D / CPUParticles2D）+ 复用现有纹理。

**层次模型**（z 轴自下而上）：关卡背景贴图(-10) → 阵营地面着色(-9) → 氛围粒子(-8) → 部署网格高亮 → 单位/基地 → 头顶 UI → 暗角(CanvasLayer 35) → HUD(40) → 演出层(已有 200)。

**每批铁律**：
- 颜色/字号只走 `DesignTokens`，样式只走 `PanelStyles` 工厂；新增阵营 tint 色先入 DT 再消费，禁止字面量。
- 动效 0.15~0.25s、SINE+EASE_OUT；呼吸/脉动全部 `DT.is_motion_reduce()` 短路。
- 中文 ≥12px；10px 仅限纯数字角标白名单。
- **零战斗逻辑改动**：spawn/damage/AI/部署链路（instance_id 精确匹配）不碰；信号只连接不改语义。
- `gl_compatibility` 渲染器：粒子一律 CPUParticles2D，渐变一律 GradientTexture2D，不依赖 canvas shader。
- 每批独立 git 提交、独立可回退。

## 2. 现状关键数据（实施时对照）

| 项 | 实测值 | 位置 |
|---|---|---|
| 视口 / 战场 SubViewport | 1280×720 / 1280×580 | main.tscn L95-99 |
| BattleContainer 底边 | `offset_bottom = -124`（勿动） | main.tscn L66-73 |
| 相位仪栏 | 高 64px，StyleBoxFlat_bg 直角+顶边 2px | bottom_instrument_bar.tscn L5-25 |
| 槽构建/配色 | L894-983；`_fit_slots_to_bar` L514-541 | bottom_instrument_bar.gd |
| 能量 tooltip | L1269-1284 | bottom_instrument_bar.gd |
| 功能按钮 | 15 枚 BTN_CONFIGS，62×56，badge=set_btn_badge | bottom_function_bar.gd L71-86, L195-244 |
| 顶部 HUD | 44px 无底板；CenterSection 280px；RightSection 5 钮 56×36 | top_hud_bar.tscn |
| 我方基地 | (40,360)，Body=Sprite2D scale 0.08 转 36°/s | battlefield.tscn / phase_field_driver.tscn |
| 基地信号 | `phase_driver_hp_changed(hp,max)` / `phase_driver_destroyed` | phase_field_driver.gd:14,31 |
| 战场布局常量 | X 40~1240；空带 60px 居中(x=640)；行偏移 [-120,-55,10]；斜阵 ±34px | card_grid_battle_layout.gd |
| 我方带范围 | player_band_start_x()≈96 ~ 610；敌方带 ≈670~1185 | 同上 |
| 槽位查询 | `player_slot_centers` / `find_nearest_player_slot` / `is_player_slot_occupied` | battle_slot_grid.gd |
| 血条 | Node2D 纯 Polygon2D，98×15，状态图标行 11px 在 y=-22 | unit_hp_bar.tscn/.gd |
| 部署触发 | pending_deploy_platform_card_id 空→非空；1-9 键同链路 | battle_input_state.gd / bottom_instrument_bar.gd |

## 3. P0 轨道 · 视觉统一与焦点

### BU-1 底部操作区重构（悬浮卡 + 按钮抽屉）★最大视觉收益

**文件**：`scenes/main.tscn`、`scenes/ui/bottom_instrument_bar.tscn/.gd`、`scenes/ui/bottom_function_bar.tscn/.gd`、`scenes/main.gd`、`scripts/signal_bus.gd`（如需新增信号）。

- [x] **底栏悬浮卡片化**：`BattleBottomBar`（VBox，现通栏 124px）外层改 MarginContainer（左右各 16px、下 8px、上 4px），相位仪栏浮在战场下缘。`BattleContainer.offset_bottom = -124` 保持不变，战场区域不动。（实现偏差：未加 MarginContainer，直接改 VBox offsets + `alignment=END` + 子序重排，节点路径零改动）
- [x] **相位仪栏换 PanelStyles 语言**：弃用 tscn 的 `StyleBoxFlat_bg`，`_ready()` 调 `PanelStyles.make_panel_frame(DT.COLOR_ACCENT_CYAN)` 后微调：底 alpha 0.97→0.92（战场微透）、12 圆角、accent 边 + 发光 shadow（alpha 0.22 / size 10）。
- [x] **槽位状态机**（bottom_instrument_bar.gd L894-983）：集中到新 `_refresh_slot_affordability()`——
  - 可部署：边框 alpha 0.85→1.0 + 呼吸微光（modulate.a 0.85↔1.0，1.2s Tween 循环，motion_reduce 静止 1.0）；
  - 能量不足：EnergyDim 压暗罩（0.45 黑）+ 图标不动 + 费用角标转 `DT.COLOR_DANGER`（cost_badge 新增 warn 属性）；
  - 部署选中态：边框转金色（`DT.COLOR_GOLD` a=1.0）+ 金色发光 shadow（轮询 pending，instance_id 精确匹配）；
  - 监听 EnergyManager 能量变化信号（SignalBus.energy_changed 已存在）+ BattleInputState pending 变更。现有悬停 ×1.18 保留。
- [x] **常驻能量条**：`NameSection` 中部加 EnergyRow（ProgressBar 100×10：底 CARD_DEEP、填充 `DT.COLOR_ENERGY`）+ 12pt "45/60"。tooltip 详细回复速率不动。
- [x] **功能按钮抽屉**：
  - 收起态：BottomFunctionBar 默认 visible=false；相位仪条右端加 "菜单" 按钮（48px，`make_button_styles` ghost 青）；
  - 展开：0.2s 淡入+自底生长（SINE OUT）；再点 ☰ / ESC / 任意面板打开后自动收起；`btn_*_pressed` 信号体系零改动，main.gd 接线不变；
  - 红点聚合：`set_btn_badge()` 同步刷新 ☰ 聚合角标（_badge_counts → set_menu_badge，数字=总和）；
  - 首解锁：`FeatureUnlockPopup.show_once("drawer_menu", "功能菜单", ...)`（菜单按钮首按时触发）。

### BU-2 基地视觉强化（我方 + 敌方）

**文件**：`scenes/units/phase_field_driver.tscn/.gd`、`scenes/units/enemy_phase_field_driver.tscn/.gd`、新增 `scenes/units/base_aura.gd`（可复用光环组件）。

- [x] 底座光环 GroundAura（Polygon2D 透视扁圆 ~90×28px，z=-1）：我方青 `(0,0.85,1,0.18)` / 敌方红 `(0.95,0.25,0.25,0.18)`，呼吸 alpha ±0.06、2.4s。（实现在 base_aura.gd 纯 _draw）
- [x] 核心血条：基地头顶简化专版（base_aura.gd 内含，含 boss 护盾蓝色段）+ 标签 + 数字；我方接 `phase_driver_hp_changed`，敌方在 take_damage/add_boss_shield 直调。
- [x] 受击反馈：`take_damage()` 光环闪白 0.15s + scale punch 1.0→1.06→1.0（0.12s）；HP≤30% 光环转红脉动（对齐 unit_hp_bar.gd L322-331 低血语言）。
- [x] 待机层次：$Body（36°/s）上加第二 Sprite2D 复用同纹理：scale ×1.15、modulate.a 0.5、反向旋转（我方 -18°/s、敌方 -12°/s）——零新美术双层相位场。
- [x] 摧毁演出不动（phase_driver_destroyed → BattleSpectacle 失败链路已有）。

### BU-3 顶部 HUD 胶囊 + 波次进度条

**文件**：`scenes/ui/top_hud_bar.tscn/.gd`。

- [x] CenterSection 外包胶囊 PanelContainer：底 `(0.04,0.06,0.10,0.78)`、圆角 14、1px 青边 alpha 0.22、padding 12/4。
- [x] InfoRow 下加 4px WaveProgressBar（圆角 2、底 CARD_DEEP、填充 ACCENT_CYAN，>80% 转 GOLD）；数据源复用现有波次文本来源（wave_idx/total_waves）。
- [x] 右上五钮（1撤/2战/3倍/4停/5返，56×36）迁入 `make_button_styles(DT.COLOR_ACCENT_CYAN)` 四态。（实现偏差：保留原自定义样式——C6 已有完整四态 + 设计稿 .hud-btn 语义，迁移属纯替换无收益）
- [x] mouse_filter=IGNORE 穿透保持（仅按钮可点）。

## 4. P1 轨道 · 战场生命力

### BU-4 阵营地面着色 + 前线分界

**文件**：`scenes/battlefield/battlefield.tscn`、新增 `scripts/battle/battlefield_ambience.gd`（BU-7 复用）。

- [x] 两片 TextureRect（GradientTexture2D，z=-9，1280×580 视口坐标）：我方 x≈40~610 青渐变 `(0,0.7,0.9,0.07)→透明` 外缘向中线衰减；敌方 x≈670~1240 镜像红 `(0.85,0.2,0.2,0.07)`。**alpha 上限 0.07 硬约束**（再浓干扰读单位）。（实现在 battlefield_ambience.gd，半场以 640 中线分界）
- [x] 前线分界：x=640 竖细线（2px，白 alpha 0.06 常显），空带正中。
- [x] 只做大区着色不描格（兼容 v9.5 斜阵 ±34px）。

### BU-5 部署区可视化

**文件**：`scenes/battlefield/battle_slot_grid.gd`、`scenes/battlefield/battlefield.gd`（定位部署 click handler）、`scenes/ui/bottom_instrument_bar.gd`（触发钩子）。

- [x] BattleSlotGrid 下加 SlotHighlightLayer（Node2D）：我方 9 槽各一圆角矩形（宽≈128.6=`battle_card_width_px()`、高按行带），默认全隐。（实现在 battle_slot_grid.gd 内部类 SlotHighlight，宽 ×1.05≈150、高 58）
- [x] 触发/关闭：`pending_deploy_platform_card_id` 空→非空 0.15s 淡入；部署完成/取消/ESC 淡出；1-9 快捷键同链路自动覆盖。（轮询 pending 实现，无需改 click overlay）
- [x] 三态：空格绿边 `(0.32,0.85,0.45,0.8)`+10% 绿底；占用格红边 0.6+8% 红底；悬停格（`find_nearest_player_slot` 返回）金边+15% 底。
- [x] 复用拖拽红绿语义（批次二标准），零学习成本。

### BU-6 单位头顶 UI 整合

**文件**：`scenes/units/unit_hp_bar.tscn/.gd`。**先我方 construct_unit 试点，再推 enemy_unit。**

- [x] 阵营底板：Bg 改阵营色暗化——我方 `(0.05,0.18,0.22,0.95)` / 敌方 `(0.22,0.08,0.08,0.95)`，Fill 保持 2px 内缩自然露"描边"。
- [x] 护盾条与血条间距统一 1px（原 -9~-3 与 -7.5~7.5 错位）。
- [x] 状态图标 11px→14px、间距 2→3、上限 10→8（超出 "+N"）。
- [x] 精英/BOSS：底板换金描边 + 左右金色小三角（实施时查 enemy_unit.gd 原型字段）。（实现：读 meta `target_priority_tag`，enemy_unit 与产兵 ConstructUnit 均写；精英=金描边、boss=描边+三角；因按标记驱动，无需"我方试点再推敌方"分步）
- [x] 受击白闪/治疗绿闪/低血脉动/伤害数字全部不动（成熟资产）。

### BU-7 战场氛围层

**文件**：`scripts/battle/battlefield_ambience.gd`、`scenes/main.tscn`。

- [x] 时代氛围粒子（CPUParticles2D，z=-8，≤24 粒）：按 `level_eras.gd` 时代切预设——一战/二战飘灰烟尘、冷战细尘、近未来青色微粒上浮；发射区覆盖 1280×580。（实现在 battlefield_ambience.gd，≤20 粒 + 4×4 程序贴图）
- [x] 暗角：程序生成 radial GradientTexture2D（中心透明→边缘黑 0.35），全屏 TextureRect 放 CanvasLayer layer=35（HUD 40 之下），mouse_filter=IGNORE。（0.32 强度，main.gd _setup_battle_vignette）
- [x] GridPattern 处置：main.tscn 的 2% 青色块删除，换程序生成真网格纹理（32px 网格 alpha 0.04），仅服务主菜单氛围层。（32px 青线 alpha 0.05 STRETCH_TILE 平铺，原 ColorRect 隐藏保留）
- [x] motion_reduce 时粒子停发（暗角静态保留）。

## 5. P2 轨道 · 布局级重构

### BU-8 战斗 HUD 情景化（依赖 BU-1 抽屉）

**文件**：`scenes/main.gd`、`scenes/main.tscn`、`resources/game_config.gd`、设置面板。

- [x] 战斗进行中（battle_started/ended 驱动）自动隐藏低频元素：BattleLogBar（96px）滑出，战场有效高度让渡。常驻例外：TopHudBar、BottomInstrumentBar、单位血条。
- [x] BattleLogBar 改"新消息滑出 3s 后收回"。
- [x] 热区：探入保持展开，移开 0.6s 收回。（偏差：原稿"屏幕下缘 24px 热区"与悬浮相位仪栏部署槽热区冲突，改为日志条原位矩形外扩 12px 热区）
- [x] 开关（默认开）+ 设置面板"战斗界面——日志自动隐藏"。（偏差：存 settings.cfg `hud_auto_hide` 键而非 GameConfig 资源——与音量/可访问性同存储同面板，下场战斗生效）

### BU-9 基地实体化升级

**文件**：`scenes/units/phase_field_driver.gd/.tscn`、`scenes/units/enemy_phase_field_driver.*`、复用 `scripts/battle/vfx_impact_factory.gd`。

- [x] 能量脉冲：每 3s 光环扩散一圈（scale 0.35→1.4 + alpha 0.5→0，0.9s）。（base_aura.gd _draw 扩散环）
- [x] 受创劣化：HP<60% 光环降饱和+间歇闪烁；<30% 挂 CPUParticles2D 火花/烟（12 粒）。
- [x] 落地阴影椭圆（黑 0.35 alpha）。（BU-2 的 base_aura 已含，提前交付）
- [x] 被摧毁：VfxImpactFactory.spawn_layered_impact 大档 + screen_shake 8.0/0.5s → 接 BattleSpectacle 失败/胜利演出。（走 Battlefield.request_screen_shake）

### BU-10 战斗叙事带整合

**文件**：`scenes/ui/battle_announcer.tscn/.gd`、`managers/battle/battle_spectacle.gd`、`scenes/ui/buff_fold_card.gd`。

- [x] TopCenterAnnouncer / 波次胶囊统一 StyleBox 语言（深底 0.78 + 青边 0.22 + 14 圆角）。（连杀标签偏差：保留金色大字原样式，加底板反而抢戏）
- [x] 垂直槽位：y72 胶囊 → y96 播报 → BOSS 横幅 y110 与播报同现时下避让至 y152（battle_spectacle._title_banner_y()，三处横幅调用点统一）；连杀标签原位（右上 x-220,180）。
- [x] BuffFoldCard 边框色对齐胶囊语言（青 0.22）。（偏差：圆角保留 6 档位——172px 小卡用 14 过大）

## 6. 实施顺序与验证

**顺序**：BU-1 → BU-3 → BU-2 → BU-4 → BU-5 → BU-6 → BU-7 → BU-8 → BU-9 → BU-10。
BU-1/3/2 是"第一眼改观"三件套，做完先肉眼验收一轮再推后面。

**每批验证**：
1. 改动文件单文件 `load()` 断言（秒级）；
2. `tests/ui_unified_check.gd` + 涉及 HUD 结构时 `tests/ui_p1_validation.gd`（新文件加 CHANGED_SCRIPTS）；
3. headless 战斗 smoke + 五时间点截图（部署前 / 部署悬停网格亮 / 战斗中 / 基地低血 / BOSS 登场）；
4. 1280×720 与 1920×1080 双分辨率肉眼五问（悬停有说明？点击有反馈？失败给原因？ESC 逐层退？换分辨率不破版？）；
5. FPS 不降（新增常驻节点 <40，粒子总量 <40 粒）。

**风险与预案**：
| 风险 | 预案 |
|---|---|
| 抽屉入口变深 | 首解锁弹窗 + ☰ 常驻呼吸点；留配置回退默认展开 |
| 地面着色干扰读图 | alpha 硬上限 0.07 + 开关 |
| HUD 自动隐藏误事 | 只藏低频元素 + 新消息主动滑出 + 设置开关 |
| 血条改动面大 | 我方试点再推敌方 |
| main.tscn 结构改动 | 走 agent_tools scene.* API，逐批 refs.validate_project |

**明确不做**：不动 1280×720 与 PopupLayer 十二面板；不重绘卡图/徽章；不改部署数值与战斗平衡；不引入着色器后期。

## 7. 验收结论（2026-08-24 机器验收轮）

工具：`tests/bu_visual_capture.gd`（四态截图 + 结构探针）。结果 **8 项全过**：
顶部胶囊/波次条、底部悬浮卡+菜单+能量条、地面着色方向（左青右红）、双基地光环（青/红色偏实测 ±45/51）、
暗角（角 44 vs 心 82）、部署高亮（pending 绿像素 0→3766）、功能抽屉（14 按钮居中无溢出）、
GdUnit 145/145。验收中修复 1 个 P1：cost_badge meta 缺键报错刷屏（has_meta 守卫）。

已知边界：本机屏幕 1024×768，截图为 4:3 自适应布局——**16:9 比例观感留玩家 F5 终验**；
敌方红光环仅相位师关卡出现（验收以 ensure_enemy_phase_driver({}) 强制渲染）。
计划第 6 节"五时间点截图/双分辨率肉眼五问"中的 BOSS 登场、基地低血两态未自动截取
（需相位师关卡+受击脚本编排），随玩家 F5 一并人工核。
