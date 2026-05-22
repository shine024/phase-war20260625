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

## 更新日期：2026-03-28
