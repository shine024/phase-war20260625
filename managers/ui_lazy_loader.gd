extends Node
## UI延迟加载管理器
## 按需实例化UI面板，减少内存占用和初始化时间
const DEBUG_UI_LAZY_LOG := false
const DEBUG_LOG_PATH := "debug-22f19e.log"



func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	if not DEBUG_UI_LAZY_LOG:
		return
	var payload := {
		"sessionId": "22f19e",
		"runId": "initial",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(DEBUG_LOG_PATH) else FileAccess.WRITE_READ
	var f := FileAccess.open(DEBUG_LOG_PATH, mode)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()

## UI面板配置
var _panel_configs: Dictionary = {}
var _loaded_panels: Dictionary = {}
var _panel_dependencies: Dictionary = {}

## 初始化面板配置
func _ready() -> void:
	# 定义所有可延迟加载的UI面板
	# 统一使用 parent_path 字段（user_data_path 已废弃）
	_panel_configs = {
		"backpack": {
			"scene": "res://scenes/ui/backpack_panel.tscn",
			"parent_path": "PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter",
			"node_name": "BackpackPanel",
			"autoload": false
		},
		"manufacture": {
			"scene": "res://scenes/ui/manufacture_panel.tscn",
			"parent_path": "PopupLayer/ManufactureOverlay/CenterContainer",
			"node_name": "ManufacturePanel",
			"autoload": false
		},
		"quest": {
			"scene": "res://scenes/ui/quest_panel.tscn",
			"parent_path": "PopupLayer/QuestOverlay/CenterContainer",
			"node_name": "QuestPanel",
			"autoload": false
		},
		"store": {
			"scene": "res://scenes/ui/store_panel.tscn",
			"parent_path": "PopupLayer/StoreOverlay/CenterContainer",
			"node_name": "StorePanel",
			"autoload": false
		},
		"rune": {
			"scene": "res://scenes/ui/rune_panel.tscn",
			"parent_path": "PopupLayer/PhaseLawOverlay/CenterContainer",
			"node_name": "RunePanel",
			"autoload": false
		},
		"story_dialogue": {
			"scene": "res://scenes/ui/story_dialogue_panel.tscn",
			"parent_path": "PopupLayer/StoryOverlay/CenterContainer",
			"node_name": "StoryDialoguePanel",
			"autoload": false
		},
		"story_chapter_select": {
			"scene": "res://scenes/ui/story_chapter_select.tscn",
			"parent_path": "PopupLayer/StoryOverlay/CenterContainer",
			"node_name": "StoryChapterSelect",
			"autoload": false
		},
		"affix": {
			"scene": "res://scenes/ui/affix_panel.tscn",
			"parent_path": "PopupLayer/AffixOverlay/CenterContainer",
			"node_name": "AffixPanel",
			"autoload": false
		},
		"faction": {
			"scene": "res://scenes/ui/faction_panel.tscn",
			"parent_path": "PopupLayer/FactionOverlay/CenterContainer",
			"node_name": "FactionPanel",
			"autoload": false
		},
		"map": {
			"scene": "res://scenes/ui/world_map_panel.tscn",
			"parent_path": "PopupLayer/MapOverlay/CenterContainer",
			"node_name": "WorldMapPanel",
			"autoload": false
		},
		"settings": {
			"scene": "res://scenes/ui/settings_panel.tscn",
			"parent_path": "PopupLayer/SettingsOverlay/CenterContainer",
			"node_name": "SettingsPanel",
			"autoload": false
		},
		"leaderboard": {
			"scene": "res://scenes/ui/leaderboard_panel.tscn",
			"parent_path": "PopupLayer/LeaderboardPanel",
			"node_name": "LeaderboardPanel",
			"autoload": false
		},
		"achievement": {
			"scene": "res://scenes/ui/achievement_panel.tscn",
			"parent_path": "PopupLayer/AchievementOverlay/CenterContainer",
			"node_name": "AchievementPanel",
			"autoload": false
		},
		"statistics": {
			"scene": "res://scenes/ui/statistics_panel.tscn",
			"parent_path": "PopupLayer/StatisticsOverlay/CenterContainer",
			"node_name": "StatisticsPanel",
			"autoload": false
		},
		"enhancement": {
			"scene": "res://scenes/ui/card_enhancement_panel.tscn",
			"parent_path": "PopupLayer/EnhancementOverlay/CenterContainer",
			"node_name": "CardEnhancementPanel",
			"autoload": false
		},
		"drops_inventory": {
			"scene": "res://scenes/ui/drops_inventory_panel.tscn",
			"parent_path": "PopupLayer/DropsInventoryOverlay/CenterContainer",
			"node_name": "DropsInventoryPanel",
			"autoload": false
		},
		"level_select": {
			"scene": "res://scenes/ui/level_select_panel.tscn",
			"parent_path": "PopupLayer/LevelSelectOverlay/CenterContainer",
			"node_name": "LevelSelectPanel",
			"autoload": false
		},
		"help": {
			"scene": "res://scenes/ui/help_panel.tscn",
			"parent_path": "PopupLayer/HelpOverlay/CenterContainer",
			"node_name": "HelpPanel",
			"autoload": false
		},
		"reinforcement": {
			"scene": "res://scenes/ui/reinforcement_panel.tscn",
			"parent_path": "PopupLayer/ReinforcementOverlay/CenterContainer",
			"node_name": "ReinforcementPanel",
			"autoload": false
		},
		"modification": {
			"scene": "res://scenes/ui/modification_panel.tscn",
			"parent_path": "PopupLayer/ModificationOverlay/CenterContainer",
			"node_name": "ModificationPanel",
			"autoload": false
		},
		"evolution": {
			"scene": "res://scenes/ui/evolution_panel.tscn",
			"parent_path": "PopupLayer/EvolutionOverlay/CenterContainer",
			"node_name": "EvolutionPanel",
			"autoload": false
		},
		"intelligence": {
			"scene": "res://scenes/ui/intelligence_hub_panel.tscn",
			"parent_path": "PopupLayer/IntelligenceOverlay/CenterContainer",
			"node_name": "IntelligenceHubPanel",
			"autoload": false
		},
		"growth": {
			"scene": "res://scenes/ui/growth_panel.tscn",
			"parent_path": "PopupLayer/GrowthOverlay/CenterContainer",
			"node_name": "GrowthPanel",
			"autoload": false
		}
	}

	if DEBUG_UI_LAZY_LOG:
		pass
		# [LOG-v5.1] print("[UILazyLoader] 初始化完成，配置面板数: ", _panel_configs.size())


## 获取UI面板（按需加载）
func get_panel(panel_id: String) -> Control:
	# #region agent log
	_debug_log("H1", "ui_lazy_loader.gd:get_panel:entry", "get_panel called", {
		"panel_id": panel_id,
		"has_config": _panel_configs.has(panel_id),
		"is_loaded": _loaded_panels.has(panel_id)
	})
	# #endregion
	# 如果已加载，直接返回
	if _loaded_panels.has(panel_id):
		var panel = _loaded_panels[panel_id]
		if is_instance_valid(panel):
			return panel
		else:
			_loaded_panels.erase(panel_id)

	# 检查配置
	if not _panel_configs.has(panel_id):
		push_error("[UILazyLoader] 未找到面板配置: ", panel_id)
		return null

	var config = _panel_configs[panel_id]

	# 加载场景
	var scene_path = config.get("scene", "")
	# #region agent log
	_debug_log("H2", "ui_lazy_loader.gd:get_panel:scene_path", "about to load scene path", {
		"panel_id": panel_id,
		"scene_path": scene_path,
		"resource_exists": ResourceLoader.exists(scene_path)
	})
	# #endregion
	if scene_path.is_empty():
		push_error("[UILazyLoader] 面板场景路径为空: ", panel_id)
		return null

	var scene = load(scene_path)
	if scene == null:
		# #region agent log
		_debug_log("H2", "ui_lazy_loader.gd:get_panel:load_failed", "scene load returned null", {
			"panel_id": panel_id,
			"scene_path": scene_path
		})
		# #endregion
		push_error("[UILazyLoader] 无法加载面板场景: ", scene_path)
		return null

	# #region agent log
	_debug_log("H2", "ui_lazy_loader.gd:get_panel:scene_loaded", "scene loaded successfully", {
		"panel_id": panel_id,
		"scene_path": scene_path,
		"scene_type": String(scene.resource_path),
		"scene_class": String(scene.get_class())
	})
	# #endregion

	# 查找父节点
	var main_scene = get_tree().current_scene
	if main_scene == null:
		push_error("[UILazyLoader] 当前场景为空")
		return null

	var parent_path = config.get("parent_path", "")
	if parent_path.is_empty():
		push_error("[UILazyLoader] 父节点路径为空: ", panel_id)
		return null

	var parent_node = main_scene.get_node(parent_path)
	if parent_node == null:
		push_error("[UILazyLoader] 找不到父节点: ", parent_path)
		return null

	# 实例化面板
	var panel = scene.instantiate()
	if panel == null:
		print("[UILazyLoader] ERROR: scene.instantiate() returned null for ", panel_id)
		return null
	print("[UILazyLoader] Instantiated panel for ", panel_id, " : ", panel)
	var explicit_name: String = config.get("node_name", "")
	if not explicit_name.is_empty():
		panel.name = explicit_name
	else:
		panel.name = panel_id + "_panel"

	# 添加到场景树
	print("[UILazyLoader] Adding panel to: ", parent_path)
	parent_node.add_child(panel)
	print("[UILazyLoader] Panel added successfully")

	# 存储引用
	_loaded_panels[panel_id] = panel
	if DEBUG_UI_LAZY_LOG:
		pass
		# [LOG-v5.1] print("[UILazyLoader] 加载面板: ", panel_id)
	return panel


## 预加载关键面板（可选）
func preload_panels(panel_ids: Array) -> void:
	for panel_id in panel_ids:
		if _panel_configs.has(panel_id):
			get_panel(panel_id)


## 卸载UI面板
func unload_panel(panel_id: String) -> void:
	if not _loaded_panels.has(panel_id):
		return

	var panel = _loaded_panels[panel_id]
	if panel and is_instance_valid(panel):
		# 发送关闭信号
		if panel.has_signal("close_requested"):
			panel.close_requested.emit()
		elif panel.has_method("queue_free"):
			panel.queue_free()
		else:
			panel.queue_free()

	_loaded_panels.erase(panel_id)
	if DEBUG_UI_LAZY_LOG:
		pass
		# [LOG-v5.1] print("[UILazyLoader] 卸载面板: ", panel_id)


## 卸载所有UI面板
func unload_all_panels() -> void:
	for panel_id in _loaded_panels.keys():
		unload_panel(panel_id)
	if DEBUG_UI_LAZY_LOG:
		pass
		# [LOG-v5.1] print("[UILazyLoader] 已卸载所有面板，总计: ", _loaded_panels.size())


## 获取面板状态
func get_panel_status(panel_id: String) -> Dictionary:
	var is_loaded = _loaded_panels.has(panel_id)
	var is_valid = false
	if is_loaded:
		is_valid = is_instance_valid(_loaded_panels[panel_id])

	return {
		"panel_id": panel_id,
		"is_loaded": is_loaded,
		"is_valid": is_valid,
		"is_configured": _panel_configs.has(panel_id)
	}


## 获取所有面板状态
func get_all_status() -> Dictionary:
	var status: Dictionary = {}
	for panel_id in _panel_configs.keys():
		status[panel_id] = get_panel_status(panel_id)
	return status


## 清理所有面板（场景切换时调用）
func clear_all() -> void:
	unload_all_panels()
	_loaded_panels.clear()
	if DEBUG_UI_LAZY_LOG:
		pass
		# [LOG-v5.1] print("[UILazyLoader] 清理完成")
