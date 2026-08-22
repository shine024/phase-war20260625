extends Node
## UI延迟加载管理器
## 按需实例化UI面板，减少内存占用和初始化时间
const DEBUG_UI_LAZY_LOG := false



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
		# v9.x 清理（2026-08-22）：以下注册已移除——面板均静态实例化于 main.tscn，
		# 子节点复用短路使懒加载永不触发（同 v6.6 "map" 先例）：
		# quest / store / faction / occupation / settings / leaderboard / intelligence
		# phase_master_skill（parent_path 节点不存在，真实开启方是 growth_panel 自建 CanvasLayer）
		# reinforcement（无 overlay 开启方；面板活于 card_info_panel 嵌入式实例化）
		"achievement": {
			"scene": "res://scenes/ui/achievement_panel.tscn",
			"parent_path": "PopupLayer/AchievementOverlay/CenterContainer",
			"node_name": "AchievementPanel",
			"autoload": false
		},
		# v8.x: enhancement 注册已移除（强化②停用），养成改为自动经验升星 + 相位师技能树
		# 2026-08-22 死面板清理：drops_inventory 注册已移除——全项目零开启方，
		# 掉落展示走 MvpPanel 结算 + backpack_changed 刷新，场景文件已删。
		# 2026-08-16 关卡设计审查：level_select 配置已移除——全项目零开启方
		# （选关由 world_map 承担），属死配置（同 v6.6 C3 world_map_panel 先例）。
		"help": {
			"scene": "res://scenes/ui/help_panel.tscn",
			"parent_path": "PopupLayer/HelpOverlay/CenterContainer",
			"node_name": "HelpPanel",
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
		"growth": {
			"scene": "res://scenes/ui/growth_panel.tscn",
			"parent_path": "PopupLayer/GrowthOverlay/CenterContainer",
			"node_name": "GrowthPanel",
			"autoload": false
		},
		"collection": {
			"scene": "res://scenes/ui/collection_panel.tscn",
			"parent_path": "PopupLayer/CollectionOverlay/CenterContainer",
			"node_name": "CollectionPanel",
			"autoload": false
		}
	}

	if DEBUG_UI_LAZY_LOG:
		pass
		# [LOG-v5.1] print("[UILazyLoader] 初始化完成，配置面板数: ", _panel_configs.size())


## 获取UI面板（按需加载）
func get_panel(panel_id: String) -> Control:
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
	if scene_path.is_empty():
		push_error("[UILazyLoader] 面板场景路径为空: ", panel_id)
		return null

	# v8.x 性能：优先接管 _preload_common_panels 的后台预热结果。
	# 若 main.gd 在启动末尾调过 ResourceLoader.load_threaded_request(scene_path)，
	# 这里用 load_threaded_get 取已完成的结果（主线程只短暂等待后台线程收尾），
	# 避免 load() 重新触发同步磁盘读+编译。无后台任务时降级为普通 load()。
	var scene: Resource = null
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		scene = ResourceLoader.load_threaded_get(scene_path)
	elif ResourceLoader.has_cached(scene_path):
		scene = ResourceLoader.load(scene_path)
	else:
		scene = load(scene_path)
	if scene == null:
		push_error("[UILazyLoader] 无法加载面板场景: ", scene_path)
		return null

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
	if DEBUG_UI_LAZY_LOG:
		print("[UILazyLoader] Instantiated panel for ", panel_id, " : ", panel)
	var explicit_name: String = config.get("node_name", "")
	if not explicit_name.is_empty():
		panel.name = explicit_name
	else:
		panel.name = panel_id + "_panel"

	# 添加到场景树
	if DEBUG_UI_LAZY_LOG:
		print("[UILazyLoader] Adding panel to: ", parent_path)
	parent_node.add_child(panel)
	if DEBUG_UI_LAZY_LOG:
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
