# Phase War: Construction Era - 项目长期记忆

## 项目基本信息
- **项目名称**：相位战争：构装纪元（Phase War: Construction Era）
- **引擎**：Godot 4.x
- **游戏类型**：横版自动对战 + 卡牌构筑
- **路径**：d:\godotplay\phase-war

## 核心玩法
- 战前准备（背包管理 + 相位仪装配）→ 自动对战 → 战后成长
- 100关，5个时代（一战/二战/冷战/现代/近未来），每时代20关
- 卡牌分类：平台卡、武器卡、能量卡、相位法则卡

## 已实现系统（截至 2026-03-22）

### 排行榜与相位师系统
- 势力排行：按玩家攻克该势力关卡数排名（势力值≠声望）
- 相位师排行：7位NPC各属一方，动态模拟互相攻伐
- 相位师对战：15%遭遇率，NPC使用同时代平台+武器卡组
- 设计意图：为任务委托系统的进攻/防守任务做准备
- 相位师单位显示：平台+武器配置，敌方相位师显示详细信息

### 任务委托系统（2026-03-22 新增）
- 进攻任务 (attack_faction)：攻击某势力，击败该势力相位师
- 防守任务 (defend_faction)：保护某势力，击退敌方相位师
- 任务流程：接取任务 → 进入该势力关卡 → 15%遭遇相位师 → 击败完成
- 奖励：蓝图碎片 + 纳米材料 + 势力声望（含正/负值）
- 现有任务：3个进攻任务 + 3个防守任务

### 数据层（完整）
- default_cards.gd - 11个平台卡 + 11个武器卡 + 能量卡
- enemy_archetypes.gd - 多时代敌人原型
- enemy_blueprints.gd - 蓝图掉落池
- level_eras.gd - 关卡与时代配置（100关）
- level_information.gd - 关卡信息
- phase_laws.gd - 相位法则（钢铁/烈焰/雷霆/虚空等多家族）
- affix_definitions.gd - 词条系统定义
- basic_resources.gd - 基础资源配置
- battle_environments.gd - 战斗环境（天气/地形等）
- company_definitions.gd / company_store.gd - 势力商店数据
- quest_definitions.gd - 任务定义

### 管理器层（完整）
- game_manager.gd - 游戏主管理器
- battle_manager.gd - 战斗管理（敌人生成、战斗逻辑）
- blueprint_manager.gd - 蓝图解锁与管理
- blueprint_analysis_manager.gd - 蓝图碎片解析（异步升级）
- synthesis_manager.gd - 卡牌合成系统
- card_enhancement_manager.gd - 卡牌强化系统（10级）
- faction_system_manager.gd - 7个势力系统（声望等级）
- affix_manager.gd - 词条系统管理
- affix_combat_handler.gd - 词条战斗效果处理
- active_law_effects.gd - 主动法则效果
- phase_law_manager.gd - 相位法则管理
- phase_instrument_manager.gd - 相位仪管理
- energy_manager.gd - 能量系统
- law_shard_manager.gd - 法则碎片管理
- quest_manager.gd - 任务系统
- save_manager.gd - 存档/读档
- audio_manager.gd - 音频管理
- company_manager.gd - 公司/势力管理
- basic_resource_manager.gd - 基础资源管理

### UI层（大部分完整，少部分缺.tscn）
已有.tscn: battle_hud, phase_instrument_panel, backpack_panel, synthesis_panel,
  card_enhancement_panel, faction_panel, level_info_panel, manufacture_panel,
  phase_law_panel, upgrade_panel, store_panel, quest_panel, settings_panel,
  active_law_cast_panel, affix_panel, health_bar, energy_bar, enemy_spawn_hud,
  player_spawn_hud, unit_info_panel, equipped_passives_box, resource_slot_item,
  backpack_card_item, phase_slot, synthesis_slot
缺.tscn: blueprint_analysis_panel, card_synthesis_panel, backpack_scroll,
  leaderboard_panel, battle_click_overlay, card_affix_tooltip

### 场景层
- main.tscn / title_screen.tscn / world_map.tscn - 主要场景
- battlefield.tscn - 战场场景
- scenes/units/ - 5个单位场景

## 待办工作（已知）
- [x] 补全缺少.tscn的6个UI面板（2026-03-22 完成）
- [x] 在主菜单中集成各UI面板（势力/碎片解析/卡牌合成/卡牌强化，2026-03-22 完成）
- [x] 音效触发点补全（合成/强化/蓝图解锁，2026-03-22 完成）
- [x] 任务委托系统：进攻/防守任务（2026-03-22 完成）
- [x] UI美化和动画效果（2026-03-22 完成）
- [x] synthesis_slot.tscn 补全（2026-03-24 完成）
- [x] LeaderboardOverlay 集成到 main.tscn / main.gd（2026-03-24 完成）
- [x] 相位师遭遇路径修复 + 内嵌兜底数据（2026-03-24 完成）
- [x] save_manager 背包节点路径修复（2026-03-24 完成）
- [x] BlueprintManager.add_blueprint_fragment() 确认存在（2026-03-24 完成）
- [x] 背包无法关闭/滚动（2026-03-25 完成）
- [x] 强化面板卡牌列表为空（@onready路径修复，2026-03-25 完成）
- [x] 势力面板显示空（@onready路径修复，2026-03-25 完成）
- [x] 法则/蓝图工坊无功能键入口（2026-03-25 完成）
- [x] 势力商店Bug全修复（2026-03-28 完成）：company_store.gd 7个无效ID替换；faction_system_manager CARD信号传参修复；blueprint_manager 虚拟碎片ID映射；drop_tables 卡牌ID替换；battle_manager current_level取法修复；game_manager重复掉落调用消除
- [ ] 完整集成测试（流程通跑，在 Godot 编辑器实际运行）
- [ ] 音效资源文件确认（AudioManager.play_sfx 所需 .ogg/.wav 文件）
- [ ] 背景图资源确认（assets/backgrounds/bg_01.png ~ bg_10.png）

## UI重构计划（2026-03-25 开始）
### 新布局：三层结构（战场70% + 相位仪与法则栏80px + 功能键栏60px）
- [x] bottom_instrument_bar.tscn/.gd — 相位仪槽位+法则常驻显示，点击发出信号（2026-03-25完成）
- [x] bottom_function_bar.tscn/.gd — 功能键栏（背包/合成/强化/势力/任务/商店/设置+战斗控制），点击发出信号（2026-03-25完成）
- [x] 重构 main.tscn：BattleContainer 锚点占满顶部(offset_bottom=-140)，底部加 BottomInstrumentBar+BottomFunctionBar，所有Overlay移入PopupLayer(CanvasLayer layer=10)（2026-03-25完成）
- [x] 重写 main.gd：@onready节点引用，监听底部栏信号替代PrepPanel按钮，_open/_close/_toggle_overlay统一管理，_close_all_overlays()清场（2026-03-25完成）
- 弹出面板定位：PopupLayer(CanvasLayer layer=10) 下的 Overlay，fullscreen + CenterContainer 居中

### 关键节点路径（新版 main）
- 战场：BattleContainer/SubViewportContainer/SubViewport/Battlefield
- 仪表栏：BottomInstrumentBar（信号：instrument_area_clicked / law_area_clicked）
- 功能键：BottomFunctionBar（信号：btn_xxx_pressed）
- 弹窗层：PopupLayer（CanvasLayer layer=10）下各 XxxOverlay/CenterContainer/XxxPanel

## 更新日期：2026-06-01

## 蓝图系统 v7.0（2026-06-02）
- **特定蓝图系统**：每个改造模块和进化路径需要特定图纸
- **改造蓝图ID**: `blueprint_<mod_id>`（如 `blueprint_inf_01_submachine_gun`）
- **进化蓝图ID**: `blueprint_evol_<from>_<to>`（如 `blueprint_evol_omega_mk1_omega_mk2`）
- **强化系统**: 只消耗纳米材料，不需要图纸
- **获取方式**: 战斗掉落（基于敌人类型）+ 商店购买
- **价格体系**: common=100, uncommon=250, rare=600, epic=1500, legendary=3500 纳米
- **初始蓝图**: 新游戏赠送7个基础改造图纸
- **已修复**: card_enhancement_panel.gd 移除旧 TYPE_MOD_A/B/C/EVOLVE/ENHANCE/STAR_UPGRADE 引用
- **相关文件**: blueprint_definitions.gd, intel_manual_items.gd, modification_panel.gd, evolution_panel.gd

## 强化改造与进化系统重构计划（2026-06-01）

**核心机制澄清**：
- **军衔系统**：动态计算（基于当前战力），不存储等级。战力提升自动晋升军衔
- **进化机制**：改造完整保留到新卡牌，源卡牌从背包移除
- **条件系统**：战力门槛 + 情报维度（基础/战术/机密/素材）+ 强化等级 + 改造数量

**设计改动**：
- 强化等级：保留Lv1-Lv10（影响战力倍率）
- 军衔称号：根据战力动态显示（步兵"征召兵→战斗大师"、装甲"装填手→钢铁战神"）
- 改造模块：140+个，真实军事技术名称
- 进化路径：真实武器代差（MP18→汤普森→AK-47→M16→机械步兵）
- 所有效果映射到9字段攻击防御体系

**已确认决策**：
- ✅ 旧卡牌强制迁移到新系统
- ✅ 改造槽位统一9槽
- ✅ 军衔系统跨兵种统一（Lv1-Lv10等级表，称号差异化）
- ✅ 改造进化后完整保留到新卡牌
- ✅ 新改造可填充空槽或替换旧改造

**关键文件**：
- 设计文档：`docs/重新构建强化改造与进化20260601.md`（15,000字，8兵种完整设计）
- 实施计划：`docs/REINFORCEMENT_MODIFICATION_EVOLUTION_REVISION_PLAN.md`
- 新数据目录：`data/military_titles/`（军衔）、`data/modification_modules/`（改造）、`data/evolution_paths/`（进化）

**实施阶段**（8周计划）：
1. 第1-2周：数据层搭建（140+改造模块数据录入）
2. 第3周：注册表系统（ModificationRegistry等）
3. 第4-5周：核心逻辑迁移（BlueprintManager改造）
4. 第6-7周：UI系统更新（强化/改造/进化界面）
5. 第8周：测试与调优

**已确认决策**（2026-06-01）：
- ✅ 旧卡牌强制迁移到新系统
- ✅ 改造槽位统一9槽
- ✅ 军衔系统跨兵种统一（统一等级Lv1-Lv10，不同称号）
- ✅ 改造进化后继承，新改造可在新槽或选择替换旧改造

**技术细节**：
- 统一军衔等级表（10级），称号按兵种差异化显示
- 改造继承逻辑：进化时源卡牌改造→目标卡牌，源卡牌清空
- 9槽系统保持不变，新改造可填充空槽或替换已有改造

## 更新日期：2026-06-01
