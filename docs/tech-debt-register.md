## Technical Debt Register
Last updated: 2026-04-09
Total items: 6 | Completed: 5 | Partial: 1

| ID | Category | Description | Status | Resolution | Sprint |
|----|----------|-------------|--------|-----------|--------|
| TD-001 | Architecture | 保存系统双重实现 — save_manager_enhanced.gd (738行) 无引用 | **Done** | 归档到 managers/_archive/，删除 .uid | Sprint A |
| TD-002 | Architecture | UI美化系统双实现 — ui_beautifier_enhanced.gd (802行) 无引用 | **Done** | 归档到 scripts/_archive/，删除 .uid | Sprint A |
| TD-003 | Code Quality | 备份文件残留 — 10+个 .backup 文件散布各目录 | **Done** | 代码备份已删除，存档备份移至 _archive/ | Sprint A |
| TD-004 | Code Quality | 4个超大文件（>1000行）— leaderboard_panel, backpack_panel, battle_manager, Main | **Done** | leaderboard_panel→3文件MVP拆分, backpack_panel→3文件MVP拆分, battle_manager→3文件拆分（spawn/damage分离），Main.gd 待后续 | Sprint B |
| TD-005 | Code Quality | 中等文件调试日志残留 — store_panel/affix_panel/battle_manager 含大量 _dbg_log 调用 | **Done** | 清除 store_panel.gd 和 affix_panel.gd 调试日志（~50行），battle_manager 拆分时同步清除 | Sprint C |
| TD-006 | Feature Gap | 9个TODO标记的未完成功能 | **Done** | 7个直接实现，2个标记 NOTIMPLEMENTED（教程UI覆盖层需UI场景、全局排行榜需后端） | Sprint C |

### Sprint D — 长期规划（进行中）

| ID | Category | Description | Status | Notes |
|----|----------|-------------|--------|-------|
| TD-007 | Code Quality | 数据文件外置 — 5个纯数据GD文件（~6000行）已提取为JSON | **Partial** | JSON已创建（data/json/，5018行），GDScript加载修改待后续完成 |
| TD-008 | Code Quality | 大Manager拆分 — achievement_manager/faction_system_manager 已拆分为委托+helper | **Done** | achievement_manager→checker+rewards, faction_system_manager→reputation+shop, 全部保持API兼容 |

### 新增文件清单

**Sprint B — UI面板拆分（MVP模式）**
| 文件 | 行数 | 职责 |
|------|------|------|
| scenes/ui/leaderboard/leaderboard_data.gd | ~300 | Model: 数据结构、排序、模拟逻辑 |
| scenes/ui/leaderboard/leaderboard_presenter.gd | ~400 | Presenter: 业务逻辑、UI构建、弹窗 |
| scenes/ui/leaderboard/leaderboard_panel.gd | ~100 | View: UI绑定、信号转发（原1211行→100行） |
| scenes/ui/backpack/backpack_data.gd | 265 | Model: 筛选排序、卡牌数据管理 |
| scenes/ui/backpack/backpack_presenter.gd | 396 | Presenter: 业务逻辑、装备、信号协调 |
| scenes/ui/backpack/backpack_panel.gd | 666 | View: UI显示（原1135行→666行） |
| managers/battle/battle_manager.gd | ~230 | 主入口: 战斗流程（原969行→230行） |
| managers/battle/battle_spawn_system.gd | ~380 | 单位生成、波次管理、部署 |
| managers/battle/battle_damage_system.gd | ~280 | 伤害计算、掉落、奖励、星级 |

**Sprint D — Manager拆分（委托模式）**
| 文件 | 行数 | 职责 |
|------|------|------|
| managers/achievement_manager.gd | 561 | 委托层（原805行→561行） |
| managers/achievement/achievement_checker.gd | 148 | 成就条件检查（20+种需求类型） |
| managers/achievement/achievement_rewards.gd | 72 | 奖励发放逻辑 |
| managers/faction_system_manager.gd | 456 | 委托层（原752行→456行） |
| managers/faction/faction_reputation.gd | 104 | 声望计算、等级阈值、关卡反应 |
| managers/faction/faction_shop.gd | 243 | 7势力商品表、购买检查、物品发放 |

**Sprint D — 数据外置（JSON）**
| 文件 | 行数 | 说明 |
|------|------|------|
| data/json/enemy_phase_masters.json | 2012 | 阶段首领数据 |
| data/json/enemy_phase_equipment.json | 1442 | 阶段装备数据 |
| data/json/quest_definitions.json | 922 | 任务定义 |
| data/json/enemy_archetypes.json | 642 | 敌人原型 |
~~data/json/achievement_definitions_extended.json~~ | ~~0~~ | ~~已删除：空JSON，代码使用.gd源文件加载~~ |

### 清理的文件

**Sprint A — 归档**
| 原路径 | 新路径 |
|--------|--------|
| managers/save_manager_enhanced.gd | managers/_archive/save_manager_enhanced.gd |
| scripts/ui_beautifier_enhanced.gd | scripts/_archive/ui_beautifier_enhanced.gd |

**Sprint A — 删除的备份文件**
- scenes/ui/store_panel.gd.backup, .backup2, store_panel_backup.gd + .uid
- scenes/ui/phase_law_panel.gd.backup
- scenes/ui/bottom_instrument_bar.gd.backup2
- managers/phase_law_manager.gd.backup
- data/default_cards.gd.backup
- resources/drop_tables.gd.backup
- save.json.backup* (3个) → _archive/

**Sprint B — 删除的原文件**
- scenes/ui/leaderboard_panel.gd (原1211行) → 替换为 scenes/ui/leaderboard/ 目录
- managers/battle_manager.gd (原969行) → 替换为 managers/battle/ 目录
