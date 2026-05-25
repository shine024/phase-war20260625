# Systems Index: Phase War

> **Status**: Active
> **Created**: 2026-04-08
> **Last Updated**: 2026-05-25
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
6. **Card Drop System** — depends on: Battle System, DropManager ⚠️ *循环依赖：此处放 Core Layer 但依赖 Feature Layer 的 Battle System，建议下移至 Feature Layer*
7. **Backpack System** — depends on: Data Persistence System
8. **Affix System** — depends on: Blueprint System, Configuration System
9. **Success Rate System** — depends on: Configuration System
10. **Knowledge Value System** — depends on: Data Persistence System

#### Feature Layer (depends on core)

1. **Battle System** — depends on: Energy System, Unit Stats System, Damage Calculation System, Deployment System, Wave System, Signal Bus System
2. **Blueprint System** — depends on: Nano Material System, Card Drop System, Data Persistence System
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
- design/gdd/game-pillars.md
- design/gdd/battle-system.md
- ~~design/gdd/blueprint-system.md~~ — **文件缺失，仅存 review log**
- ~~design/gdd/synthesis-system.md~~ — **已删除（v3 移除合成系统）**
- design/gdd/phase-law-system.md
- design/gdd/energy-system.md
- design/gdd/unit-stats-system.md
- design/gdd/drop-system.md
- design/gdd/star-upgrade-system.md
- design/gdd/enhancement-system.md
- design/gdd/knowledge-value-system.md
- design/gdd/achievement-system.md (stub)
- design/gdd/daily-task-system.md (stub)
- design/gdd/leaderboard-system.md (stub)
- design/gdd/quest-system.md (stub)
- design/gdd/tutorial-system.md (stub)

---

## 根目录文档索引

> **注意**：原索引列出 41 个根目录 `.md` 文件，经验证全部已不存在。
> 当前项目根目录仅存 `CLAUDE.md`、`README.md`、`DEEPV.md`。
> 本节保留为历史参考，实际文档请以磁盘文件为准。

### 现存根目录文档

|| 文件名 | 用途 |
|---|--------|------|
| CLAUDE.md | AI助手项目指引 |
| README.md | 项目说明 |
| DEEPV.md | 项目深度说明 |
