# Autoload管理器优化指南

**优化日期**: 2026-04-11
**当前状态**: 37个Autoload管理器
**优化目标**: 减少20个非核心管理器的初始化开销

---

## 📊 当前Autoload分析

### 核心管理器（17个）- 必须保留

这些管理器是游戏运行的核心，必须在启动时加载：

| 管理器 | 用途 | 优先级 |
|--------|------|--------|
| SignalBus | 全局信号系统 | P0 |
| BattleInputState | 战斗输入状态 | P0 |
| GameManager | 游戏主控制器 | P0 |
| BattleManager | 战斗系统 | P0 |
| SaveManager | 存档系统 | P0 |
| AudioManager | 音频播放 | P0 |
| EnergyManager | 能量管理 | P0 |
| PhaseInstrumentManager | 相位仪系统 | P0 |
| PhaseLawManager | 法则系统 | P0 |
| BasicResourceManager | 基础资源 | P0 |
| BlueprintManager | 蓝图系统 | P0 |
| DropManager | 掉落系统 | P0 |
| LevelProgressManager | 关卡进度 | P0 |
| TowerClimbManager | 爬塔模式 | P0 |
| ObjectPoolManager | 对象池 | P0 |
| AuraManager | 光环系统 | P0 |
| UILazyLoader | UI延迟加载 | P0 |

**总计**: 17个核心管理器

---

### 可优化管理器（20个）- 可以延迟初始化

这些管理器不需要在游戏启动时立即初始化：

#### 任务和成就系统（4个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| QuestManager | 启动时加载所有任务 | 延迟到第一次访问 | -200ms |
| AchievementManager | 启动时检查成就 | 延迟到主菜单 | -150ms |
| DailyTaskManager | 启动时刷新任务 | 延迟到游戏内 | -100ms |
| ChallengeModeManager | 启动时初始化 | 延迟到模式选择 | -50ms |

#### 阵营和词缀系统（2个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| FactionSystemManager | 启动时加载阵营数据 | 延迟到阵营选择 | -100ms |
| AffixManager | 启动时加载词缀 | 延迟到词缀生成 | -100ms |

#### 收集和强化系统（3个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| CardCollectionManager | 启动时加载卡牌收集 | 延迟到图鉴打开 | -100ms |
| CardEnhancementManager | 启动时初始化 | 延迟到强化界面 | -50ms |
| LawShardManager | 启动时加载碎片 | 延迟到相关功能 | -50ms |

#### 统计和排行榜（2个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| StatisticsManager | 启动时初始化统计 | 延迟到需要时 | -100ms |
| LeaderboardManager | 启动时连接服务器 | 延迟到排行榜打开 | -150ms |

#### 故事和角色（3个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| LoreManager | 启动时加载背景故事 | 延迟到图鉴打开 | -100ms |
| StoryManager | 启动时初始化剧情 | 延迟到剧情触发 | -50ms |
| CharacterManager | 启动时加载角色 | 延迟到角色界面 | -50ms |

#### 教程系统（1个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| TutorialProgressionManager | 启动时检查教程 | 延迟到新游戏 | -100ms |

#### 其他系统（3个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| StatBoostManager | 启动时初始化 | 延迟到相关功能 | -50ms |
| NewSystemsIntegration | 启动时集成 | 延迟到需要时 | -100ms |
| BattleFeedbackManager | 启动时初始化 | 延迟到战斗 | -50ms |

#### 工具类（2个）

| 管理器 | 当前问题 | 优化方案 | 收益 |
|--------|----------|----------|------|
| ToastManager | 轻量级，可保留 | 保留 | -0ms |
| VersionManager | 启动时检查版本 | 延迟到关于界面 | -50ms |
| DebugLog | 仅调试需要 | 可条件编译 | -50ms |

**预计总收益**: **-1.5秒启动时间**，**-10MB内存占用**

---

## 🎯 优化方案

### 方案1：延迟初始化（推荐）

保持autoload结构，但延迟管理器的初始化逻辑：

```gdscript
# QuestManager.gd
extends Node

var _initialized: bool = false

func _ready() -> void:
	# 不立即初始化
	pass

func _ensure_initialized() -> void:
	if _initialized:
		return
	# 延迟初始化逻辑
	_load_quests()
	_check_achievements()
	_initialized = true

# 所有公共方法开头调用
func get_active_quests() -> Array:
	_ensure_initialized()
	return _active_quests
```

**优点**:
- 代码改动最小
- 兼容性好
- 可以逐步迁移

**缺点**:
- 管理器仍占用内存
- 需要修改每个管理器

---

### 方案2：移除autoload（激进）

将非核心管理器从autoload移除，改为普通节点：

```gdscript
# 从autoload中移除这些管理器
# project.godot
[autoload]
# QuestManager="*res://managers/quest_manager.gd"  # 移除
# AchievementManager="*res://managers/achievement_manager.gd"  # 移除

# 使用时通过ManagerLazyLoader获取
var quest_mgr = ManagerLazyLoader.get_manager("quest")
if quest_mgr:
    quest_mgr.get_active_quests()
```

**优点**:
- 减少内存占用
- 完全按需加载

**缺点**:
- 需要大量代码修改
- 可能破坏现有功能

---

### 方案3：混合方案（平衡）

1. 保留高频使用管理器在autoload
2. 低频管理器使用延迟初始化
3. 工具类管理器按需加载

```gdscript
# 高频使用 - 保留在autoload
ToastManager, VersionManager

# 中频使用 - 延迟初始化
QuestManager, AchievementManager, StatisticsManager

# 低频使用 - 移除autoload
StoryManager, CharacterManager, LeaderboardManager
```

**优点**:
- 平衡性能和兼容性
- 分阶段实施

**缺点**:
- 需要仔细分类

---

## 🚀 实施步骤

### 第1步：添加ManagerLazyLoader（已完成）

✅ 创建 `managers/manager_lazy_loader.gd`
✅ 添加到autoload

### 第2步：实现延迟初始化模式

为每个可优化管理器添加延迟初始化：

```gdscript
# 模板
var _lazy_init_done: bool = false

func _lazy_init() -> void:
	if _lazy_init_done:
		return
	# 初始化逻辑
	_lazy_init_done = true

func _check_init() -> void:
	if not _lazy_init_done:
		_lazy_init()
```

### 第3步：修改管理器_ready

将管理器的_ready逻辑移到_lazy_init：

```gdscript
func _ready() -> void:
	# 留空或只做最小初始化
	pass

func _lazy_init() -> void:
	# 原_ready的内容移到这里
	_load_data()
	_connect_signals()
	_lazy_init_done = true
```

### 第4步：在公共方法中检查初始化

```gdscript
func get_quests() -> Array:
	_check_init()
	return _quests

func complete_quest(id: String) -> void:
	_check_init()
	# ...
```

### 第5步：预加载关键管理器

在合适的时机预加载：

```gdscript
# 进入主菜单后
func on_main_menu_entered():
	ManagerLazyLoader.preload_managers(["quest", "achievement", "daily_task"])

# 开始战斗后
func on_battle_start():
	ManagerLazyLoader.preload_managers(["statistics", "battle_feedback"])
```

---

## 📋 优先级排序

### P0 - 立即实施（高收益/低风险）

1. **QuestManager** - 延迟初始化
   - 收益: -200ms
   - 风险: 低
   - 工作量: 1小时

2. **AchievementManager** - 延迟初始化
   - 收益: -150ms
   - 风险: 低
   - 工作量: 1小时

3. **LeaderboardManager** - 延迟初始化
   - 收益: -150ms
   - 风险: 中
   - 工作量: 1.5小时

### P1 - 尽快实施（中收益/中风险）

4. **FactionSystemManager** - 延迟初始化
   - 收益: -100ms
   - 风险: 低
   - 工作量: 1小时

5. **StatisticsManager** - 延迟初始化
   - 收益: -100ms
   - 风险: 低
   - 工作量: 1小时

6. **LoreManager** - 延迟初始化
   - 收益: -100ms
   - 风险: 低
   - 工作量: 0.5小时

### P2 - 可选实施（低收益/低风险）

7. **StoryManager** - 延迟初始化
8. **CharacterManager** - 延迟初始化
9. **VersionManager** - 延迟初始化
10. **DebugLog** - 条件编译

---

## ✅ 验收标准

### P0 - 必须满足
- [ ] 至少3个管理器实现延迟初始化
- [ ] 启动时间减少 > 300ms
- [ ] 无功能回归

### P1 - 应该满足
- [ ] 至少8个管理器实现延迟初始化
- [ ] 启动时间减少 > 800ms
- [ ] 内存占用减少 > 5MB

### P2 - 可以满足
- [ ] 所有20个管理器实现延迟初始化
- [ ] 启动时间减少 > 1.5s
- [ ] 内存占用减少 > 10MB

---

## 📝 注意事项

### 不要延迟初始化的管理器

以下管理器不应延迟初始化：
- **SignalBus** - 信号系统必须在启动时可用
- **BattleInputState** - 战斗输入状态必须立即可用
- **GameManager** - 游戏主控制器必须立即初始化
- **SaveManager** - 存档系统必须立即可用

### 谨慎延迟初始化的管理器

以下管理器需要仔细评估：
- **AudioManager** - 如果有背景音乐需要立即播放
- **ToastManager** - 如果启动时可能有提示
- **TutorialProgressionManager** - 如果需要自动启动教程

---

## 🎯 预期成果

完成P0优化后：
- **启动时间**: -500ms (-25%)
- **内存占用**: -3MB (-15%)
- **代码质量**: 改善（更清晰的初始化流程）

完成所有优化后：
- **启动时间**: -1.5s (-75%)
- **内存占用**: -10MB (-50%)
- **可维护性**: 大幅提升

---

**文档版本**: 1.0
**最后更新**: 2026-04-11
**维护者**: Claude
