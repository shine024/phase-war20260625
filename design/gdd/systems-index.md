# Systems Index: Phase War

> **Status**: Active
> **Created**: 2026-04-08
> **Last Updated**: 2026-05-18
> **Source Concept**: design/gdd/game-concept.md

---

## Autoload 管理器索引

`project.godot` **[autoload] 共 16 项**（2026-05-18）。其余管理器由 `ManagerLazyLoader` 按需实例化，见 `managers/manager_lazy_loader.gd`。

| # | 管理器 | 中文描述 | 脚本路径 |
|---|--------|----------|----------|
| 1 | SignalBus | 全局信号总线 | `scripts/signal_bus.gd` |
| 2 | BattleInputState | 战斗输入状态 | `scripts/battle_input_state.gd` |
| 3 | EnergyManager | 战斗能量 | `managers/energy_manager.gd` |
| 4 | PhaseInstrumentManager | 相位仪/能量槽装配 | `managers/phase_instrument_manager.gd` |
| 5 | BattleManager | 战斗流程 | `managers/battle/battle_manager.gd` |
| 6 | GameManager | 游戏生命周期 | `managers/game_manager.gd` |
| 7 | BlueprintManager | 卡牌账号进度（星级/改装；将重命名为 CardDataManager） | `managers/blueprint_manager.gd` |
| 8 | DropManager | 战利品掉落 | `managers/drop_manager.gd` |
| 9 | SaveManager | 存档 | `managers/save_manager.gd` |
| 10 | AudioManager | 音频 | `managers/audio_manager.gd` |
| 11 | PhaseLawManager | 法则 + 四维知识值 | `managers/phase_law_manager.gd` |
| 12 | BasicResourceManager | 纳米/研究点等 | `managers/basic_resource_manager.gd` |
| 13 | ObjectPoolManager | 对象池 | `managers/object_pool.gd` |
| 14 | UILazyLoader | UI 延迟加载 | `managers/ui_lazy_loader.gd` |
| 15 | ManagerLazyLoader | 管理器延迟加载 | `managers/manager_lazy_loader.gd` |
| 16 | PerformanceMetricsManager | 性能指标 | `managers/performance_metrics_manager.gd` |

### 常见 Lazy 管理器（非 autoload）

| 管理器 | 说明 |
|--------|------|
| QuestManager / AchievementManager / DailyTaskManager | 任务与成就 |
| CardEnhancementManager / AffixManager / CardCollectionManager | 卡牌强化与收藏 |
| FactionSystemManager / LevelProgressManager / ChallengeModeManager | 势力与关卡 |
| LoreManager / StoryManager / CharacterManager | 内容（按需） |
| ~~LawShardManager~~ | **已废弃** — 仅存档迁移 shim |
| ~~TowerClimbManager~~ | **已移除**（设计 v3） |

架构决策全文：`docs/ARCH_DECISIONS.md`。

---

## 设计文档系统枚举

Phase War 共 **33个** 设计系统（按设计文档定义），核心循环围绕"战前装配构筑，战中部署操作"展开。

核心设计哲学：
- **构筑深度**：战前装配决定可用兵种
- **战术操作**：战中部署时机和法则施放
- **收集成长**：卡片收集 + 研究点升星 + 知识值解锁法则

### Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Configuration System | Core | MVP | In Progress | — | — |
| 2 | Signal Bus System | Core | MVP | Implemented | — | — |
| 3 | Energy System | Core | MVP | Implemented | — | — |
| 4 | Nano Material System | Core | MVP | In Progress | — | — |
| 5 | Data Persistence System | Core | MVP | Implemented | — | — |
| 6 | Unit Stats System | Gameplay | MVP | In Progress | — | Configuration System |
| 7 | Damage Calculation System | Gameplay | MVP | Implemented | — | Configuration System, Unit Stats System |
| 8 | Deployment System | Gameplay | MVP | Implemented | — | Energy System, Signal Bus System |
| 9 | Wave System | Gameplay | MVP | In Progress | — | Signal Bus System |
| 10 | Battle System | Gameplay | MVP | In Review | design/gdd/battle-system.md | Energy System, Unit Stats System, Damage Calculation System, Deployment System, Wave System, Signal Bus System |
| 11 | Card Drop System | Economy | MVP | In Progress | design/gdd/drop-system.md | Battle System, DropManager |
| 12 | Card Data / Star System | Progression | MVP | In Progress | design/gdd/star-upgrade-system.md | BasicResourceManager, BlueprintManager |
| 13 | Energy Regeneration System | Gameplay | MVP | Implemented | — | Energy System, Signal Bus System |
| 14 | Energy Consumption System | Gameplay | MVP | Implemented | — | Energy System, Signal Bus System |
| 15 | Backpack System | Economy | MVP | In Progress | — | Data Persistence System |
| 16 | Card Manufacturing System | Economy | MVP | In Progress | — | Blueprint System, Backpack System |
| 17 | Environment System | Gameplay | Vertical Slice | In Progress | — | Configuration System |
| 18 | Phase Law System (Basic) | Gameplay | MVP | In Review | design/gdd/phase-law-system.md | Blueprint System, Environment System, Energy System, Nano Material System, Signal Bus System |
| 19 | Combat UI System (Basic) | UI | MVP | Implemented | — | Battle System, Energy System |
| 20 | Affix System | Progression | Vertical Slice | Implemented | — | Blueprint System, Configuration System |
| 21 | Success Rate System | Economy | Vertical Slice | In Progress | — | Configuration System |
| 22 | ~~Synthesis System~~ | Economy | Vertical Slice | **Removed v3** | — | — |
| 23 | Star Rating System | Progression | Vertical Slice | In Progress | — | Battle System, Configuration System |
| 24 | Target Selection System | Gameplay | Vertical Slice | Implemented | — | Unit Stats System, Signal Bus System |
| 25 | Death/Respawn System | Gameplay | Vertical Slice | Implemented | — | Unit Stats System, Signal Bus System |
| 26 | Knowledge Value System | Progression | Vertical Slice | Not Started | — | Data Persistence System |
| 27 | Blueprint Library UI System | UI | Vertical Slice | Implemented | — | Blueprint System |
| 28 | Law Library UI System | UI | Vertical Slice | Implemented | — | Phase Law System |
| 29 | Era System | Progression | Alpha | Not Started | — | Configuration System |
| 30 | Level Unlock System | Progression | Alpha | In Progress | — | Data Persistence System, Configuration System |
| 31 | Quest/Achievement System | Meta | Alpha | Implemented | — | Data Persistence System |
| 32 | ~~Synthesis UI System~~ | UI | Alpha | **Removed v3** | — | — |
| 33 | Resource Loading System | Core | Full Vision | In Progress | — | — |

### Dependency Map

#### Foundation Layer (no dependencies)

1. **Configuration System** — 游戏常量和平衡数据的中心配置
2. **Signal Bus System** — 全局事件通信，解耦系统间依赖
3. **Energy System** — 基础能量管理（战前配置、战斗回复）
4. **Nano Material System** — 纳米材料货币管理
5. **Data Persistence System** — 存档读写、进度保存
6. **Resource Loading System** — 场景、纹理、音频资源加载

#### Core Layer (depends on foundation)

1. **Unit Stats System** — depends on: Configuration System
2. **Damage Calculation System** — depends on: Configuration System, Unit Stats System
3. **Deployment System** — depends on: Energy System, Signal Bus System
4. **Wave System** — depends on: Signal Bus System
5. **Environment System** — depends on: Configuration System
6. **Fragment Drop System** — depends on: Battle System, Configuration System
7. **Backpack System** — depends on: Data Persistence System
8. **Affix System** — depends on: Blueprint System, Configuration System
9. **Success Rate System** — depends on: Configuration System
10. **Knowledge Value System** — depends on: Data Persistence System

#### Feature Layer (depends on core)

1. **Battle System** — depends on: Energy System, Unit Stats System, Damage Calculation System, Deployment System, Wave System, Signal Bus System
2. **Blueprint System** — depends on: Nano Material System, Fragment Drop System, Data Persistence System
3. **Energy Regeneration System** — depends on: Energy System, Signal Bus System
4. **Energy Consumption System** — depends on: Energy System, Signal Bus System
5. **Card Manufacturing System** — depends on: Blueprint System, Backpack System
6. **Phase Law System** — depends on: Blueprint System, Environment System, Energy System, Nano Material System, Signal Bus System
7. **Target Selection System** — depends on: Unit Stats System, Signal Bus System
8. **Death/Respawn System** — depends on: Unit Stats System, Signal Bus System
9. **Star Rating System** — depends on: Battle System, Configuration System
10. ~~**Synthesis System**~~ — **Removed v3**

#### Presentation Layer (depends on features)

1. **Combat UI System** — depends on: Battle System, Energy System
2. **Blueprint Library UI System** — depends on: Blueprint System
3. **Law Library UI System** — depends on: Phase Law System
4. ~~**Synthesis UI System**~~ — **Removed v3**

#### Polish Layer (depends on everything)

1. **Era System** — depends on: Configuration System
2. **Level Unlock System** — depends on: Data Persistence System, Configuration System
3. **Quest/Achievement System** — depends on: Data Persistence System

---

## 已完成 GDD

- design/gdd/game-concept.md
- design/gdd/battle-system.md
- design/gdd/blueprint-system.md
- design/gdd/synthesis-system.md
- design/gdd/phase-law-system.md
- design/gdd/energy-system.md
- design/gdd/unit-stats-system.md
- design/gdd/drop-system.md
- design/gdd/achievement-system.md (stub)
- design/gdd/daily-task-system.md (stub)
- design/gdd/leaderboard-system.md (stub)
- design/gdd/quest-system.md (stub)
- design/gdd/tutorial-system.md (stub)

---

## 根目录文档索引

项目根目录下的 `.md` 文件（共 41 个）：

### 开发文档
| 文件名 | 用途 |
|--------|------|
| CLAUDE.md | AI助手项目指引 |
| README.md | 项目说明 |
| PROJECT_SUMMARY.md | 项目概述 |
| QUICK_REFERENCE.md | 快速参考 |
| DEVELOPMENT_LOG.md | 开发日志 |
| SESSION_SUMMARY.md | 会话总结 |
| UPGRADING.md | 升级指南 |
| DEEPV.md | 项目深度说明 |

### 功能指南
| 文件名 | 用途 |
|--------|------|
| ANALYSIS_TOOLS_GUIDE.md | 分析工具指南 |
| INTEGRATION_GUIDE.md | 集成指南 |
| ENHANCEMENT_QUICK_GUIDE.md | 强化快速指南 |
| APPLICATION_SYSTEM_GUIDE.md | 应用系统指南 |
| COMPREHENSIVE_APPLICATION_SYSTEM_SUMMARY.md | 应用系统完整总结 |
| TASK_SYSTEM_GUIDE.md | 任务系统指南 |
| ACHIEVEMENT_SAVE_SYSTEM_GUIDE.md | 成就存档系统指南 |
| SYNTHESIS_PANEL_GUIDE.md | 合成面板指南 |
| SYNTHESIS_SYSTEM.md | 合成系统文档 |

### 词缀系统
| 文件名 | 用途 |
|--------|------|
| AFFIX_DOCUMENTATION.md | 词缀文档 |
| AFFIX_QUICK_REFERENCE.md | 词缀快速参考 |
| AFFIX_COMBAT_GUIDE.md | 词缀战斗指南 |

### 蓝图系统
| 文件名 | 用途 |
|--------|------|
| blueprint_system_checklist.md | 蓝图系统清单 |
| blueprint_law_full_table.md | 蓝图法则完整表 |
| BLUEPRINT_FIX_SUMMARY.md | 蓝图修复总结 |
| BLUEPRINT_COMPARISON.md | 蓝图对比 |
| BLUEPRINT_BALANCE_REPORT.md | 蓝图平衡报告 |

### 敌人系统
| 文件名 | 用途 |
|--------|------|
| ENEMY_LEADERBOARD_IMPLEMENTATION.md | 敌人排行榜实现 |
| ENEMY_PHASE_LEADERBOARD_GUIDE.md | 敌人阶段排行榜指南 |
| ENEMY_PHASE_MASTERS_GUIDE.md | 敌人阶段大师指南 |

### 世界地图
| 文件名 | 用途 |
|--------|------|
| WORLD_MAP_QUICK_GUIDE.md | 世界地图快速指南 |
| WORLD_MAP_SEPARATION_SUMMARY.md | 世界地图分离总结 |

### 报告与记录
| 文件名 | 用途 |
|--------|------|
| FEATURE_IMPLEMENTATION_REPORT.md | 功能实现报告 |
| FIX_REPORT.md | 修复报告 |
| OPTIMIZATION_REPORT.md | 优化报告 |
| SYSTEM_IMPLEMENTATION_SUMMARY.md | 系统实现总结 |
| SYSTEM_ENHANCEMENT_SUMMARY.md | 系统增强总结 |
| BUGFIX_LEADERBOARD_ENTRY.md | 排行榜条目Bug修复 |

### 中文文档
| 文件名 | 用途 |
|--------|------|
| 碎片转换为蓝图.md | 碎片转蓝图说明 |
| 战斗单位列表_白底提示词.md | 战斗单位白底提示词 |
| 战斗单位列表_白底提示词_主线12条.md | 主线12条单位提示词 |
| 战斗单位列表_参考风格提示词_主线12条.md | 参考风格单位提示词 |
| spglantu20260403.md | 会议记录 (2026-04-03) |
