extends Node
## 管理器延迟加载系统 v2
const DEBUG_MANAGER_LAZY_LOG := false
## 将非核心管理器从 project.godot [autoload] 移除，
## 改为按需 load() + new() + add_child(root) 实例化
## 实例化后仍可通过 /root/NodeName 访问（与Autoload行为一致）
##
## 用法：
##   ManagerLazyLoader.ensure_loaded("quest")           # 确保已创建
##   var mgr = ManagerLazyLoader.get_manager("quest")    # 获取引用
##   var mgr = get_node_or_null("/root/QuestManager")    # 创建后也可用

## 管理器配置：id -> { node_name, script_path, priority, description, dependencies }
var _manager_configs: Dictionary = {}
## 已加载的管理器缓存：id -> Node
var _loaded_managers: Dictionary = {}

## 核心管理器（仍在 project.godot [autoload] 中，此处仅作记录）
const CORE_MANAGERS: Array = [
	"SignalBus",
	"BattleInputState",
	"GameManager",
	"BattleManager",
	"SaveManager",
	"AudioManager",
	"EnergyManager",
	"PhaseInstrumentManager",
	"PhaseLawManager",
	"BasicResourceManager",
	"BlueprintManager",
	"DropManager",
	"ObjectPoolManager",
	"UILazyLoader",
	"ManagerLazyLoader"
]

# ─── 生命周期 ───────────────────────────────────────────

func _ready() -> void:
	_ensure_configs_initialized()
	if DEBUG_MANAGER_LAZY_LOG:
		print("[ManagerLazyLoader] v2 初始化完成")
		print("  核心Autoload: ", CORE_MANAGERS.size(), " 个")
		print("  可延迟加载:   ", _manager_configs.size(), " 个")
		print("  Autoload总计: ", CORE_MANAGERS.size() + 1, " 个 (含ManagerLazyLoader)")

func _ensure_configs_initialized() -> void:
	if not _manager_configs.is_empty():
		return
	_manager_configs = {
		# ── 战斗相关 (priority 1) ──
		"aura": {
			"node_name": "AuraManager",
			"script_path": "res://managers/aura_manager.gd",
			"priority": 1,
			"description": "光环系统"
		},
		"battle_feedback": {
			"node_name": "BattleFeedbackManager",
			"script_path": "res://managers/battle_feedback_manager.gd",
			"priority": 1,
			"description": "战斗反馈"
		},
		"level_progress": {
			"node_name": "LevelProgressManager",
			"script_path": "res://managers/level_progress_manager.gd",
			"priority": 1,
			"description": "关卡进度"
		},
		# ── 任务和成就 (priority 2) ──
		"quest": {
			"node_name": "QuestManager",
			"script_path": "res://managers/quest_manager.gd",
			"priority": 2,
			"description": "任务系统"
		},
		"achievement": {
			"node_name": "AchievementManager",
			"script_path": "res://managers/achievement_manager.gd",
			"priority": 2,
			"description": "成就系统"
		},
		"daily_task": {
			"node_name": "DailyTaskManager",
			"script_path": "res://managers/daily_task_manager.gd",
			"priority": 2,
			"description": "日常任务"
		},
		"challenge_mode": {
			"node_name": "ChallengeModeManager",
			"script_path": "res://managers/challenge_mode_manager.gd",
			"priority": 2,
			"description": "挑战模式"
		},
		# ── 阵营和词缀 (priority 3) ──
		"faction": {
			"node_name": "FactionSystemManager",
			"script_path": "res://managers/faction_system_manager.gd",
			"priority": 3,
			"description": "阵营系统"
		},
		"affix": {
			"node_name": "AffixManager",
			"script_path": "res://managers/affix_manager.gd",
			"priority": 3,
			"description": "词缀系统"
		},
		# ── 收集和强化 (priority 4) ──
		"card_collection": {
			"node_name": "CardCollectionManager",
			"script_path": "res://managers/card_collection_manager.gd",
			"priority": 4,
			"description": "卡牌收集"
		},
		"card_enhancement": {
			"node_name": "CardEnhancementManager",
			"script_path": "res://managers/card_enhancement_manager.gd",
			"priority": 4,
			"description": "卡牌强化"
		},
		"stat_boost": {
			"node_name": "StatBoostManager",
			"script_path": "res://managers/stat_boost_manager.gd",
			"priority": 4,
			"description": "属性提升"
		},
		# ── 统计和排行榜 (priority 5) ──
		"statistics": {
			"node_name": "StatisticsManager",
			"script_path": "res://managers/statistics_manager.gd",
			"priority": 5,
			"description": "统计系统"
		},
		"leaderboard": {
			"node_name": "LeaderboardManager",
			"script_path": "res://managers/leaderboard_manager.gd",
			"priority": 5,
			"description": "排行榜"
		},
		# ── 故事和角色 (priority 6) ──
		"lore": {
			"node_name": "LoreManager",
			"script_path": "res://managers/lore_manager.gd",
			"priority": 6,
			"description": "背景故事"
		},
		"story": {
			"node_name": "StoryManager",
			"script_path": "res://managers/story_manager.gd",
			"priority": 6,
			"description": "故事系统"
		},
		"character": {
			"node_name": "CharacterManager",
			"script_path": "res://managers/character_manager.gd",
			"priority": 6,
			"description": "角色管理"
		},
		# ── 教程 (priority 7) ──
		"tutorial": {
			"node_name": "TutorialProgressionManager",
			"script_path": "res://managers/tutorial_progression_manager.gd",
			"priority": 7,
			"description": "教程系统"
		},
		# ── 集成 (priority 8) ──
		"new_systems": {
			"node_name": "NewSystemsIntegration",
			"script_path": "res://managers/new_systems_integration.gd",
			"priority": 8,
			"description": "新系统集成"
		},
		# ── 工具类 (priority 9-10) ──
		"toast": {
			"node_name": "ToastManager",
			"script_path": "res://managers/toast_manager.gd",
			"priority": 9,
			"description": "提示消息"
		},
		"version": {
			"node_name": "VersionManager",
			"script_path": "res://managers/version_manager.gd",
			"priority": 9,
			"description": "版本管理"
		},
		"debug_log": {
			"node_name": "DebugLog",
			"script_path": "res://managers/debug_log_manager.gd",
			"priority": 99,
			"description": "调试日志"
		}
	}


# ─── 核心 API ───────────────────────────────────────────

## 获取管理器（按需实例化）。返回 Node 或 null。
func get_manager(manager_id: String) -> Node:
	_ensure_configs_initialized()
	if _is_cached_and_valid(manager_id):
		return _loaded_managers[manager_id]

	if not _manager_configs.has(manager_id):
		push_error("[ManagerLazyLoader] 未配置的管理器: ", manager_id)
		return null

	var manager = _instantiate_manager(manager_id)
	if manager:
		_loaded_managers[manager_id] = manager
	return manager


## 确保管理器已加载（不返回值，仅供副作用调用）。
## 用法：ManagerLazyLoader.ensure_loaded("quest") 后，
##       get_node_or_null("/root/QuestManager") 即可正常使用。
func ensure_loaded(manager_id: String) -> void:
	_ensure_configs_initialized()
	if not _is_cached_and_valid(manager_id):
		get_manager(manager_id)


## 通过节点名获取（兼容 /root/NodeName 风格）。
func get_manager_by_name(node_name: String) -> Node:
	var id = _find_id_by_node_name(node_name)
	if id.is_empty():
		# 可能是核心管理器，尝试从场景树获取
		return get_node_or_null("/root/" + node_name)
	return get_manager(id)


# ─── 批量预加载 ─────────────────────────────────────────

## 按优先级预加载：加载 priority <= max_priority 的所有管理器
func preload_by_priority(max_priority: int) -> int:
	var count := 0
	for id in _manager_configs:
		if _manager_configs[id].get("priority", 99) <= max_priority:
			if get_manager(id):
				count += 1
	if count > 0:
		if DEBUG_MANAGER_LAZY_LOG:
			print("[ManagerLazyLoader] 预加载 priority<=", max_priority, ": ", count, " 个管理器")
	return count


## 预加载指定管理器列表
func preload_managers(manager_ids: Array) -> int:
	var count := 0
	for id in manager_ids:
		if get_manager(id):
			count += 1
	return count


# ─── 状态查询 ───────────────────────────────────────────

## 检查管理器是否已实例化且有效
func is_loaded(manager_id: String) -> bool:
	return _is_cached_and_valid(manager_id)

## 通过节点名检查是否已加载
func is_loaded_by_name(node_name: String) -> bool:
	var id = _find_id_by_node_name(node_name)
	return not id.is_empty() and is_loaded(id)

## 获取单个管理器状态
func get_status(manager_id: String) -> Dictionary:
	var id = manager_id
	var config: Dictionary
	if _manager_configs.has(id):
		config = _manager_configs[id]
	else:
		var found = _find_id_by_node_name(manager_id)
		if not found.is_empty():
			id = found
			config = _manager_configs[id]
	return {
		"manager_id": id,
		"node_name": config.get("node_name", ""),
		"is_loaded": _is_cached_and_valid(id),
		"priority": config.get("priority", 99),
		"description": config.get("description", ""),
		"script_path": config.get("script_path", "")
	}

## 获取所有管理器状态
func get_all_status() -> Dictionary:
	var result := {}
	for id in _manager_configs:
		result[id] = get_status(id)
	return result

## 获取核心管理器列表
func get_core_managers() -> Array:
	return CORE_MANAGERS.duplicate()

## 获取所有可延迟加载的管理器 ID 列表
func get_lazy_manager_ids() -> Array:
	return _manager_configs.keys()

## 检查是否为核心管理器
func is_core_manager(node_name: String) -> bool:
	return node_name in CORE_MANAGERS

## 获取已加载管理器数量
func get_loaded_count() -> int:
	var count := 0
	for id in _loaded_managers:
		if is_instance_valid(_loaded_managers[id]):
			count += 1
	return count


# ─── 内部方法 ───────────────────────────────────────────

## 检查缓存是否有效
func _is_cached_and_valid(manager_id: String) -> bool:
	if not _loaded_managers.has(manager_id):
		return false
	if not is_instance_valid(_loaded_managers[manager_id]):
		_loaded_managers.erase(manager_id)
		return false
	return true


## 实例化管理器并添加到场景树
func _instantiate_manager(manager_id: String) -> Node:
	var config = _manager_configs[manager_id]
	var script_path: String = config.get("script_path", "")
	var node_name: String = config.get("node_name", "")

	if script_path.is_empty():
		push_error("[ManagerLazyLoader] 脚本路径为空: ", manager_id)
		return null

	# 防止重复添加到场景树
	var existing = get_node_or_null("/root/" + node_name)
	if existing:
		_loaded_managers[manager_id] = existing
		if DEBUG_MANAGER_LAZY_LOG:
			print("[ManagerLazyLoader] 管理器已存在于场景树: ", node_name)
		return existing

	# 加载脚本
	var script = load(script_path)
	if script == null:
		push_error("[ManagerLazyLoader] 无法加载脚本: ", script_path)
		return null

	# 实例化
	var manager = script.new()
	if manager == null:
		push_error("[ManagerLazyLoader] 无法实例化: ", manager_id, " (", script_path, ")")
		return null

	# 设置节点名并添加到场景树根节点（模拟 Autoload 行为）
	manager.name = node_name
	var root: Node = get_tree().root
	if root == null:
		push_error("[ManagerLazyLoader] 场景树根节点不可用: ", manager_id)
		return null
	# 启动阶段 root 可能仍在 setup children，直接 add_child 会触发 blocked 错误。
	# 此时改为 deferred 挂载，避免报错并保持后续可用性。
	if root.is_node_ready():
		root.add_child(manager)
	else:
		root.call_deferred("add_child", manager)
	# _enter_tree() 和 _ready() 在 add_child 后自动调用

	if DEBUG_MANAGER_LAZY_LOG:
		print("[ManagerLazyLoader] 实例化: ", node_name, " [", config.get("description", ""), "]")
	return manager


## 通过节点名反查 manager_id
func _find_id_by_node_name(node_name: String) -> String:
	for id in _manager_configs:
		if _manager_configs[id].get("node_name", "") == node_name:
			return id
	return ""
