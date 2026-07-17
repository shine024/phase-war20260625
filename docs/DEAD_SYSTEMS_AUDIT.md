# Phase War 未启用/死代码系统审计报告

> 审计日期：2026-07-17
> 范围：`scripts/` `managers/` `scenes/` `data/` `resources/`（已排除 `addons/` `.godot/` `tests/`）
> 目的：为"清理无用系统"提供分级清单。每项均附 `文件:行号` 证据。

---

## 清理优先级总览

| 级别 | 含义 | 数量 |
|------|------|------|
| **P0 可直接删** | 纯死代码/幽灵文件，无任何运行时引用，删了零风险 | 7 项 |
| **P1 半死功能（需决策）** | 脚本/数据写好了但玩家无法触达，要么补入口要么删 | 11 项 |
| **P2 孤立 manager** | autoload 注册+存档读写但 0 方法调用，空转消耗启动时间 | 3 项 |
| **P3 死信号/死方法** | 冗余声明，不影响功能但污染代码 | 2 类共 59 项 |
| **P4 已弃用但保留** | 注释已声明弃用，属设计性保留，清理需谨慎 | 8 项 |

---

## 🔴 P0 — 可直接删（纯死代码/幽灵文件）

### P0-1. `managers/tutorial_manager.gd`（B 系统教程）
- **证据**：`managers/tutorial_manager.gd:3-4` 自承"v7.x(A5) 已弃用：本管理器从未被 autoload，且 game_launcher 引用的 tutorial id（'basic_gameplay'）在 TutorialDefs 中不存在"。
- **现状**：实际生效的是 A 系统 `TutorialProgressionManager`（autoload）。B 系统整文件无人引用。
- **清理**：删除文件。确认无 import 指向它即可。

### P0-2. `scenes/game_launcher.gd`（启动器死代码）
- **证据**：`scenes/game_launcher.gd` 全项目无任何 `.tscn` 挂载（grep 仅命中自身和文档）。
- **连带问题**：
  - L98-107 `_load_assets()` 的 `resource_queue` 是空 stub，`is_done()` 恒 true，加载瞬间跳过，`loading_progress` 卡 0。
  - L349/368/386 引用的 `ui_theme.tres`/`interface_sound.tres`/`player_model.tscn` 三个文件磁盘不存在。
  - 它是 `achievement_panel`/`help_panel`/`settings_panel` 的唯一入口，删它等于确认这些面板无入口。
- **清理**：删除文件。

### P0-3. `scenes/ui/new_functions_bar_addon.gd`（未挂载的扩展功能栏）
- **证据**：全项目无 `instance=ExtResource` 或 `add_child` 引用它。
- **连带影响**：其内部 6 个按钮（日常 / 挑战 / 图鉴 / 成就 / 敌源改造 / 合成）全部失效，是以下面板的唯一入口：
  - `enemy_origin_mod_panel`
  - `ChallengeModePanel`（文件本就不存在）
  - `CardCollectionPanel`（文件本就不存在）
  - `synthesis_panel`
- **清理**：删除文件。决策其指向的功能是否已迁移到其他面板。

### P0-4. `managers/statistics_manager.gd`（幽灵 manager）
- **证据**：
  - `project.godot` 的 `[autoload]` 段无此条目。
  - `managers/statistics_manager.gd` 文件不存在。
  - 仅 `managers/manager_lazy_loader.gd:166` 注释和 `managers/save_manager.gd:148` 的残留常量 `SK_STATISTICS` 提及它。
- **连带 bug（重要）**：`managers/new_systems_integration.gd:108` 警告"record_battle_victory 等统计方法全项目无调用者 → 战斗/收集/进度类成就永远不解锁"。
- **清理**：删除残留常量 `SK_STATISTICS` 和相关注释。

### P0-5. `scenes/ui/interactive_tutorial.tscn`（旧版教程场景）
- **证据**：`scenes/ui/tutorial_overlay.gd:6` 注释明确"历史版本（B 系统）已弃用"。
- **清理**：删除 .tscn 和配套 .gd（如果有）。

### P0-6. `managers/manager_lazy_loader.gd` 中 `statistics` 配置残留
- **证据**：`managers/manager_lazy_loader.gd:166-167` 注释承认"v7.x: statistics 配置已删除"，但可能仍有残留字符串。
- **清理**：核对并清除残留。

### P0-7. `scenes/ui/card_enhancement_panel.tscn.original`（备份文件）
- **证据**：`.original` 后缀的备份文件，非功能场景。
- **清理**：直接删除。

---

## 🟠 P1 — 半死功能（写了但玩家打不开）

这些面板/功能代码完整，但玩家无法触发。**需要逐个决策：补入口 or 删？**

### P1-1. `occupation_panel`（势力领地图）⚠️ 高优先级
- **问题**：`scenes/world_map.gd:494-510` 的 `_on_territory_map_button()` 调用 `lazy_loader.ensure_loaded("occupation")`，但 **`UILazyLoader` 没有 `ensure_loaded` 方法**（只有 `get_panel`/`preload_panels`）。
- **现状**：L499 的 `has_method("ensure_loaded")` 守卫恒 false，静默 return，面板不实例化。后续 L508 的 `get_node_or_null("CenterContainer/OccupationPanel")` 也找不到节点（OccupationOverlay 里未内联该节点）。
- **影响**：v6.10 花力气做的势力领地图功能完全不可达。
- **修复建议**：把 L502 的 `ensure_loaded("occupation")` 改为 `get_panel("occupation")`，或在 main.tscn 的 OccupationOverlay 里直接内联 OccupationPanel 节点（参照 FactionPanel 的做法）。

### P1-2. `achievement_panel`（成就面板）
- **问题**：唯一入口在死代码 `game_launcher.gd:368`。`bottom_function_bar.gd` 12 个按钮无"成就"，`main.gd` 无 `_on_achievement_pressed`。
- **现状**：Overlay `AchievementOverlay/CenterContainer`（main.tscn:561-576）是空的。
- **决策**：是否给成就加底部栏按钮？

### P1-3. `help_panel`（帮助面板）
- **问题**：唯一入口在死代码 `game_launcher.gd:386`。
- **决策**：是否补入口？

### P1-4. `drops_inventory_panel`（掉落库存）
- **问题**：全项目无 `get_panel("drops_inventory")` 调用，无 overlay visible 调用，无按钮。
- **现状**：`DropsInventoryOverlay`（main.tscn:605）存在但 CenterContainer 为空。
- **决策**：掉落查看功能是否已被背包/其他面板覆盖？

### P1-5. `level_select_panel`（关卡选择）
- **问题**：无按钮，无处理函数。`afk_level_selector` 是不同的东西（有入口）。
- **现状**：`LevelSelectOverlay`（main.tscn:686）存在但无面板节点。
- **决策**：关卡选择已由 world_map 承担？

### P1-6. `reinforcement_panel`（援护）
- **问题**：无按钮，无 `_toggle_overlay(reinforcement_overlay,...)` 调用。
- **现状**：`ReinforcementOverlay`（main.tscn:762）存在但无面板节点。
- **决策**：援护功能是否废弃？

### P1-7. `manufacture_panel`（制造）— 已被强化面板征用
- **问题**：`main.gd:519` 把 `"progression"` 映射到 `manufacture_overlay`，但实际塞进去的是 `CardEnhancementPanel`（main.gd:657-674）。`manufacture_panel.gd:196` 自承"合成功能已废弃"。
- **决策**：删除 manufacture_panel，把 overlay 重命名为 enhancement_overlay。

### P1-8. `enemy_origin_mod_panel`（敌源 MOD）— 无玩家入口
- **问题**：唯一入口在未挂载的 `new_functions_bar_addon.gd:75-86`。
- **现状**：面板脚本（15KB）完整，EOM 数据/掉落/存档都保留，但玩家无法打开面板操作。
- **决策**：补入口（挂到某个功能栏）or 随 EOM 战斗加成一起彻底废弃？

### P1-9. `ChallengeModeManager` — 注册+存档+日志检查，0 方法调用
- **证据**：
  - autoload 注册：`project.godot:58`（注释自承"仅 main.gd 死检查"）。
  - "死检查"：`scenes/main.gd:1094-1112` `_setup_new_managers()` 遍历含 ChallengeModeManager 的列表，仅 `get_node_or_null` 后 `if existing:` 打日志，**不调用任何方法**。
  - 11 个公共方法（start_survival_challenge/start_boss_rush_challenge/update_challenge_progress/complete_challenge/fail_challenge/get_challenge_records/get_challenge_leaderboard/get_active_challenge/is_in_challenge 等）**全项目 0 外部调用**。
- **决策**：挑战模式是否还要做？不做就删整个 manager + 存档字段。

### P1-10. `CharacterManager` — 注册+存档，0 方法调用
- **证据**：
  - autoload 注册：`project.godot:57`（注释自承"0 处运行时访问，纯存档字段"）。
  - 15 个公共方法（get_character/get_all_characters/get_unlocked_characters/unlock_character/update_relationship/get_relationship_value/get_relationship_description/is_character_dialogue_available/get_character_dialogue/is_story_npc/get_player_character/update_player_attribute 等）**全项目 0 外部调用**。
  - 仅 `save_manager.gd:59,67,106,596` 和 `manager_lazy_loader.gd:188` 的注册/存档引用。
- **决策**：角色关系/对话系统是否还要做？

### P1-11. `LeaderboardManager` — 仅 1 处弱引用
- **证据**：仅 `managers/game_manager.gd:559` 一处功能访问。
- **现状**：底部栏有"排行"按钮（`bottom_function_bar.gd:67`），面板能打开，但数据可能不完整。
- **决策**：保留，但需核查数据流。

---

## 🟡 P2 — 空 stub / 未实现功能（影响体验）

### P2-1. BGM/背景音乐系统完全未实现 ⚠️ 玩家可感知
- **证据**：`managers/audio_manager.gd:4` 注释"BGM/背景音乐尚未实装（无 MusicPlayer）"。
- **现状**：`scenes/ui/settings_panel.gd:117` 也注明"当前无 BGM 播放器，预留接口"。
- **决策**：实装 BGM or 保持静音？

### P2-2. `DebugLogManager` 完全不可用
- **证据**：
  - 注册为 lazy（`manager_lazy_loader.gd:220-225`，id `debug_log`）但全项目**无任何 `ensure_loaded("debug_log")` 真实调用**（3 处命中全在注释里）。
  - 非 autoload。
  - `managers/save_manager.gd:192-196` 注释承认"v7.x(M6) 曾尝试在此 ensure_loaded('debug_log')...如需启用调试日志，可手动 ensure_loaded 或将其改为 autoload"。
- **现状**：8+ 处 `get_node_or_null("/root/DebugLogManager")`（`aura_manager.gd:51`、`blueprint_manager.gd:165`、`phase_instrument_manager.gd:191,454,620,642,693`、`save_manager.gd:203`）**恒返回 null**，所有 debug 日志静默丢失。
- **决策**：要么改为 autoload 让日志恢复，要么删除所有 `get_node_or_null("/root/DebugLogManager")` 调用。

### P2-3. `NewSystemsIntegration` 绕过 lazy loader
- **证据**：`managers/manager_lazy_loader.gd:201-206` 注册了 `new_systems`，但无 `ensure_loaded("new_systems")` 调用。它在 `scenes/main.gd:1151-1168` 被独立实例化（直接 `load().new() + add_child(root)`），完全绕过 ManagerLazyLoader。
- **清理**：删除 lazy 配置（死配置）。

### P2-4. `phase_instrument_manager._equip_starter_cards_for_new_game()` 退化为 no-op
- **证据**：`managers/phase_instrument_manager.gd:1004-1009` 函数体只有 `pass`，注释"v7.x 已停用，保留函数体避免调用点报错"。
- **现状**：新游戏不再自动装备初始卡。
- **决策**：确认是否需要新游戏初始卡。

### P2-5. `card_enhancement_panel` 进化按钮硬禁用
- **证据**：`scenes/ui/card_enhancement_panel.gd:453-459`：`evolve_button.disabled = true` + `evolve_button.text = "当前版本未启用进化"` + 立即 return。
- **现状**：当 BlueprintManager 无 `get_evolution_options` 时进化入口禁用。
- **决策**：进化功能是否启用？

### P2-6. `intel_manual_items.gd` 声望解锁蓝图未实现
- **证据**：`data/intel_manual_items.gd:452` 注释"随着声望解锁更多蓝图（TODO: 实现解锁逻辑）"。

### P2-7. `save_manager` 关键道具系统预留
- **证据**：`managers/save_manager.gd:916` 注释"v6.6: 关键道具系统尚未实现（reserved）"。

### P2-8. `save_manager.start_ng_plus()` 二周目功能
- **证据**：`managers/save_manager.gd:1132` 定义了但全项目无 UI/入口调用。

---

## 🔵 P3 — 死信号 / 死方法（冗余但不影响功能）

### P3-1. SignalBus 死信号（共 28 个）

#### 完全 0 emit（17 个）
| 信号名 | 定义行 |
|--------|--------|
| `toggle_factions` | signal_bus.gd:122 |
| `toggle_phase_laws` | signal_bus.gd:123 |
| `kill_reward_granted` | signal_bus.gd:163 |
| `intel_updated` | signal_bus.gd:173 |
| `intel_unlocked` | signal_bus.gd:174 |
| `intel_tier_reached` | signal_bus.gd:175 |
| `card_reinforced` | signal_bus.gd:192 |
| `reinforcement_failed` | signal_bus.gd:193 |
| `modification_installed` | signal_bus.gd:196 |
| `modification_removed` | signal_bus.gd:197 |
| `modification_failed` | signal_bus.gd:198 |
| `growth_panel_saved` | signal_bus.gd:201（growth_panel.gd:353 注释承认死信号） |
| `card_data_changed` | signal_bus.gd:202（同上） |
| `card_evolved` | signal_bus.gd:205 |
| `evolution_failed` | signal_bus.gd:206 |
| `evolution_path_unlocked` | signal_bus.gd:207 |
| `runeword_triggered` | signal_bus.gd:228 |
| `milestone_reached` | signal_bus.gd:85（signal_bus.gd:82-84 注释承认预留） |

#### 断镜像（本地 manager 有 emit，SignalBus 版本 0 emit，11 个）
| SignalBus 信号 | 本地 manager emit 位置 |
|----------------|----------------------|
| `challenge_started/completed/failed` | challenge_mode_manager.gd:47,117,192,205 |
| `card_obtained/max_level` | card_collection_manager.gd:91,97 |
| `collection_milestone_reached` | card_collection_manager.gd:169 |
| `relationship_changed` | character_manager.gd:226 |
| `character_unlocked` | character_manager.gd:213 |
| `synthesis_completed/failed` | synthesis_manager.gd:75,81,84,94,117 |

> **注**：`signal_bus.gd:165-172` 大段注释已承认情报/阵营/合成/强化/改造/成长/进化系统的 SignalBus 信号"目前均为'声明未接通'状态"。

### P3-2. 死方法（5 个 manager 共 42 个 0 外部调用）

| Manager | 死方法数 | 代表性方法 |
|---------|---------|-----------|
| `instance_registry.gd` | 2 | `has_instance`(L149)、`get_instance_count`(L436) |
| `blueprint_manager.gd` | 10 | `apply_card_drop_first_copy`(L273)、`can_upgrade_blueprint`(L317,DEPRECATED)、`upgrade_blueprint_level`(L322,DEPRECATED)、`get_card_level`(L351)、`is_mod_enabled`(L1031)、`replace_modification`(L1057)、`get_available_modifications`(L1102)、`get_evolution_preview`(L1110)、`set_custom_weapon_slots`(L1207)、`apply_custom_weapon_slots`(L1215) |
| `faction_system_manager.gd` | 17 | `get_relationship_name`(L89)、`add_item_to_store`(L468)、`set_active_faction`(L521)、`get_faction_variant_card`(L542)、`unlock_faction_skill`(L823)、`reset_faction_skill_branch`(L855)、`get_active_event`(L885)、`resolve_faction_event`(L891) 等（详见完整清单） |
| `quest_manager.gd` | 12 | `is_quest_revealed`(L299)、`set_quest_branch`(L304)、`get_quest_branch`(L322)、`get_target_value_for_quest`(L344)、`is_mission_quest`(L669)、`get_quests_by_category`(L694) 等 |
| `save_manager.gd` | 3 | `clear_pending_backpack_ids`(L847)、`add_pending_backpack_card_id`(L1057)、`start_ng_plus`(L1132) |

> **重点**：`faction_system_manager` 的势力事件/技能树子系统（7 个方法）和 `quest_manager` 的剧情分支子系统（11 个方法）**整片未接通**。

---

## ⚪ P4 — 已弃用但保留（清理需谨慎）

这些注释已声明弃用，多数是为存档兼容保留，**不要盲目删**：

| 文件:行号 | 内容 | 弃用原因 |
|----------|------|---------|
| `resources/card_resource.gd:178-206` | 8 个 `@deprecated v6.0/v5.0` 字段（platform_type/weapon_type/合成来源等） | 存档兼容读取 |
| `resources/unit_stats.gd:105-118` | 旧底盘/攻击类型字段 | 存档兼容 |
| `resources/unit_stats_table.gd:869,877,929` | 旧 build_stats/build_multi_stats/get_platform_growth_bias 包装 | 旧接口 |
| `scripts/battle/attack_calculator.gd:37,85` | 两个 `@deprecated v6.2` 伤害计算函数 | "仅用于测试/验证器" |
| `scripts/battle/module_effect_handler.gd:7,22` | `on_bullet_hit()` `@deprecated v7.5` | 全项目零调用方 |
| `data/basic_resources.gd:20,58` | `ID_BASIC_NANO`（已弃用，用 ID_NANO_MATERIALS） | 存档兼容 |
| `data/level_information.gd:646` | 旧查询函数 | 已被 get_available_law_families_for_level 取代 |
| `scripts/signal_bus.gd:136` | 爬塔模式相关信号 | "爬塔模式已移除" |

---

## 🟣 附加：停用的战斗加成链路（v6.8 设计性停用，非 bug）

这些是 v6.8 "收敛我方加成来源" 主动停用的，**数据/UI/掉落/存档外壳保留**，只断开战斗数值注入：

| 文件:行号 | 内容 |
|----------|------|
| `managers/battle/battle_spawn_system.gd:1112` | `# v6.8: 势力变体加成已停用` |
| `managers/battle/battle_spawn_system.gd:1187` | `# v6.8: 敌源MOD（D槽）战斗加成已停用` |
| `scenes/units/construct_unit.gd:162` | `# v6.8: 相位法则被动加成（我方）已停用` |
| `scenes/ui/enemy_origin_mod_panel.gd:11` | `# 战斗加成：v6.8 已停用` |
| `scripts/battle/attack_calculator.gd:55-63,104` | `# v6.2: 直射已删除衰减设定，本块停用`（整段被注释） |

> 这些是设计决策，不是死代码。若要彻底清理，需评估"是否复活"或"连外壳一起删"。

---

## 附加：空转的改造效果（v7.5 已大部分修复）

`scripts/systems/modification_registry.gd` 中仍有少量 effect key 落入 default 分支被塞进 `_special`，而 `unit_stats_table._apply_mod_stat_effects` 不读 `_special`：

| 文件:行号 | 状态 |
|----------|------|
| `modification_registry.gd:485` | 光环 buff 效果（项目无光环系统）—— v7.5 重映射为自身加成已大部分修复 |
| `modification_registry.gd:308,389` | damage_reduction 字段（take_damage 从不读）—— v7.5 改为三维防御 |
| `resources/unit_stats.gd:137` | infantry_mods 暴抗字段空转 —— v7.x 补全数据链 |

> 详细清单见 AGENTS.md "v7.x 改造效果审计" 章节。

---

## 清理建议执行顺序

### 第一波（零风险，可直接删）
1. P0-1 `tutorial_manager.gd`（B 系统）
2. P0-2 `game_launcher.gd`
3. P0-3 `new_functions_bar_addon.gd`
4. P0-5 `interactive_tutorial.tscn`
5. P0-7 `card_enhancement_panel.tscn.original`
6. P0-4/P0-6 清除 statistics 残留常量

### 第二波（需逐个决策）
1. P1-1 修复 `occupation_panel` 入口（改 `ensure_loaded` → `get_panel`）
2. P1-8 `enemy_origin_mod_panel` 补入口 or 删
3. P1-2/P1-3 `achievement_panel`/`help_panel` 补底部栏按钮 or 删
4. P1-4/P1-5/P1-6 `drops_inventory`/`level_select`/`reinforcement` 确认是否已被其他面板覆盖
5. P1-7 删 `manufacture_panel`，重命名 overlay
6. P1-9/P1-10 `ChallengeModeManager`/`CharacterManager` 整体决策（做 or 删）

### 第三波（功能完善）
1. P2-2 `DebugLogManager` 改 autoload or 删所有调用
2. P2-3 删 `new_systems` lazy 死配置
3. P2-1 BGM 系统（实装 or 保持）

### 第四波（代码瘦身）
1. P3-1 清理 28 个死信号
2. P3-2 清理 42 个死方法（faction/quest 子系统整片未接通，重点评估）

---

## 验证清单（清理后必跑）

```powershell
# 项目语法验证
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only

# Smoke test
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"

# Grep 核对（确保删的符号全项目无残留）
# 例如删除某 manager 后：
# grep -r "ManagerName" scripts/ managers/ scenes/ data/ resources/
```

> **注**：本项目 Godot headless `--check-only` 因 133 卡+42 autoload 体量接近 5 分钟超时属既有现象，语法启动到 DefaultCards 构建阶段无错误即视为通过。
