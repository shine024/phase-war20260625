# P1A 进度记录 — 消除 get_node_or_null("/root/X") 改为直接 Autoload 引用

日期: 2026-04-11
项目: /d/godotplay/phase-war (Godot 4.5 GDScript)

## 背景

P0-3 已将 39 个 Autoload 压缩到 15 个（24 个移至 ManagerLazyLoader 懒加载）。
P1A 目标：将核心 Autoload 的 `get_node_or_null("/root/X")` + null 检查改为直接裸引用。

### 核心Autoload（15个，可直接裸引用）：
SignalBus, BattleInputState, EnergyManager, PhaseInstrumentManager,
BattleManager, GameManager, BlueprintManager, SaveManager,
PhaseLawManager, BasicResourceManager, AudioManager, DropManager,
ObjectPoolManager, UILazyLoader, ManagerLazyLoader

### 懒加载管理器（24个，保留 get_node_or_null + ensure_loaded）：
QuestManager, AchievementManager, DailyTaskManager, ChallengeModeManager,
FactionSystemManager, AffixManager, CardCollectionManager, CardEnhancementManager,
LawShardManager, StatisticsManager, LeaderboardManager, LoreManager, StatBoostManager,
StoryManager, CharacterManager, TutorialProgressionManager, NewSystemsIntegration,
ToastManager, VersionManager, TowerClimbManager, BattleFeedbackManager,
LevelProgressManager, AuraManager, DebugLog

## 进度

### managers/ 目录 — 已完成的文件
- [x] basic_resource_manager.gd — 全部改完
- [x] energy_manager.gd — 全部改完
- [x] audio_manager.gd — 全部改完
- [x] phase_law_manager.gd — 仅剩 DebugLog/QuestManager（懒加载，保留不动）
- [x] phase_instrument_manager.gd — 仅剩 DebugLog（懒加载，保留不动）
- [x] battle_manager.gd — 仅剩 QuestManager（懒加载，保留不动）
- [x] blueprint_manager.gd — 仅剩 AffixManager（懒加载，保留不动）
- [x] save_manager.gd — 特殊逻辑，不改
- [ ] game_manager.gd — **进行中，还剩约12处核心引用需改**
- [x] drop_manager.gd — 仅剩 LoreManager/StatBoostManager（懒加载，保留不动）

### managers/game_manager.gd 剩余需改的核心引用（12处）：
行号 | 当前代码 | 应改为
488 | `var pim = get_node_or_null("/root/PhaseInstrumentManager")` | 删掉变量，直接用 `PhaseInstrumentManager.xxx`
521 | `var brm = get_node_or_null("/root/BasicResourceManager")` | 删掉变量，直接用 `BasicResourceManager.xxx`
529 | `var bm = get_node_or_null("/root/BlueprintManager")` | 删掉变量，直接用 `BlueprintManager.xxx`
538 | `var bm = get_node_or_null("/root/BlueprintManager")` | 同上
571 | `var pim = get_node_or_null("/root/PhaseInstrumentManager")` | 删掉变量，直接用
594 | `var pim = get_node_or_null("/root/PhaseInstrumentManager")` | 同上
606 | `var save_mgr = get_node_or_null("/root/SaveManager")` | 直接用 `SaveManager.xxx`
614 | `var bp = get_node_or_null("/root/BlueprintManager")` | 直接用 `BlueprintManager.xxx`
627 | `var bp = get_node_or_null("/root/BlueprintManager")` | 同上
698 | `var save_mgr = get_node_or_null("/root/SaveManager")` | 直接用 `SaveManager.xxx`

保留不动的（懒加载/场景节点）：
- 49,51,53: LeaderboardPanel（场景节点，不是管理器）
- 295: LevelProgressManager（懒加载）
- 340,349: FactionSystemManager（懒加载）
- 409,566: QuestManager（懒加载）

### scenes/ 目录 — 未开始（188处）
主要文件和引用密度：
```
grep -rn 'get_node_or_null.*"/root/' --include="*.gd" scenes/ | sed 's/:.*//g' | sort | uniq -c | sort -rn
```
大部分引用是核心Autoload（BlueprintManager, GameManager, PhaseLawManager等），需要逐文件处理。
少量是懒加载管理器引用（保留不动）。

## 替换规则

1. `var X = get_node_or_null("/root/CoreManager")` + `if X:` → 删掉变量声明和null检查，直接用 `CoreManager`
2. `X.has_method("xxx")` 保留（运行时安全检查）
3. 懒加载管理器的引用保留 `ManagerLazyLoader.ensure_loaded("id")` + `get_node_or_null`
4. 场景节点（如 `/root/Main/...`）保留 `get_node_or_null`

## 已完成的其他任务
- [x] P0-3: Autoload 39→15
- [x] P0-4: .gitignore + .editorconfig 修复
- [ ] P1A: managers/game_manager.gd 剩余12处（明天继续）
- [ ] P1A: scenes/ 目录 188处（明天继续）
