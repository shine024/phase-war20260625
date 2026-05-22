extends Control
## 游戏启动器：处理游戏启动、初始化和主菜单

## 信号定义
signal game_ready()
signal game_exiting()
signal loading_progress_updated(progress: float)
signal critical_error_occurred(error_message: String)

## 启动阶段
enum LaunchPhase {
	INITIALIZING,
	LOADING_ASSETS,
	LOADING_DATA,
	LOADING_SAVE,
	READY,
	ERROR
}

## 当前启动阶段
var current_phase: LaunchPhase = LaunchPhase.INITIALIZING

## 加载进度
var loading_progress: float = 0.0

## 启动配置
var launch_config: Dictionary = {
	"show_splash_screen": true,
	"splash_duration": 3.0,
	"enable_debug_mode": false,
	"skip_intro": false,
	"load_last_save": false,
	"verify_integrity": false,
	"auto_start_tutorial": false
}

## 错误信息
var error_message: String = ""

## UI组件引用
@onready var splash_screen: Control = $SplashScreen
@onready var loading_screen: Control = $LoadingScreen
@onready var progress_bar: ProgressBar = $LoadingScreen/ProgressBar
@onready var status_label: Label = $LoadingScreen/StatusLabel
@onready var main_menu: Control = $MainMenu

func _ready() -> void:
	# 设置全屏
	get_tree().root.set_content_scale_aspect(Window.CONTENT_SCALE_ASPECT_KEEP)

	# 开始启动流程
	_start_launch_sequence()

## 开始启动序列
func _start_launch_sequence() -> void:
	print("[GameLauncher] 开始游戏启动序列...")

	# 显示启动画面
	if launch_config["show_splash_screen"] and splash_screen != null:
		splash_screen.visible = true
		await get_tree().create_timer(launch_config["splash_duration"]).timeout
		splash_screen.visible = false

	# 开始加载流程
	_enter_loading_phase()

## 进入加载阶段
func _enter_loading_phase() -> void:
	if loading_screen != null:
		loading_screen.visible = true

	current_phase = LaunchPhase.LOADING_ASSETS
	loading_progress = 0.0

	# 执行加载步骤
	await _load_assets()
	loading_progress = 0.25
	_update_loading_progress("加载资源完成")

	await _load_game_data()
	loading_progress = 0.5
	_update_loading_progress("加载数据完成")

	await _initialize_systems()
	loading_progress = 0.75
	_update_loading_progress("初始化系统完成")

	await _load_save_data()
	loading_progress = 1.0
	_update_loading_progress("加载完成")

	# 启动完成
	_launch_completed()

## 加载资源
func _load_assets() -> void:
	print("[GameLauncher] 加载游戏资源...")
	current_phase = LaunchPhase.LOADING_ASSETS

	# 预加载关键资源
	var resource_queue = _create_resource_queue()

	# 添加要预加载的资源
	resource_queue.add_resource("res://textures/ui/ui_theme.tres")
	resource_queue.add_resource("res://audio/sfx/interface_sound.tres")
	resource_queue.add_resource("res://models/characters/player_model.tscn")

	# 等待资源加载完成
	while not resource_queue.is_done():
		await get_tree().process_frame
		loading_progress = 0.25 * resource_queue.get_progress()

## 创建资源队列
func _create_resource_queue() -> Node:
	# 创建资源加载队列
	var queue = Node.new()
	queue.name = "ResourceQueue"
	add_child(queue)

# 这里可以实现实际的资源队列逻辑
# 简化版本直接返回完成状态的节点
	return queue

## 加载游戏数据
func _load_game_data() -> void:
	print("[GameLauncher] 加载游戏数据...")
	current_phase = LaunchPhase.LOADING_DATA

	# 加载核心游戏数据
	_preload_data_files()

	# 验证数据完整性
	if launch_config["verify_integrity"]:
		_verify_data_integrity()

## 预加载数据文件
func _preload_data_files() -> void:
	var data_files = [
		"res://data/default_cards.gd",
		"res://data/enemy_phase_masters.gd",
		"res://data/achievement_definitions_extended.gd",
		"res://data/challenge_definitions.gd"
	]

	for file_path in data_files:
		if FileAccess.file_exists(file_path):
			# 预加载数据文件
			load(file_path)
		else:
			push_warning("[GameLauncher] 数据文件不存在: ", file_path)

## 验证数据完整性
func _verify_data_integrity() -> void:
	print("[GameLauncher] 验证数据完整性...")

	# 检查关键数据文件
	var critical_files = [
		"res://data/default_cards.gd",
		"res://managers/save_manager.gd"
	]

	for file_path in critical_files:
		if not FileAccess.file_exists(file_path):
			error_message = "关键文件缺失: " + file_path
			_handle_critical_error(error_message)
			return

## 初始化系统
func _initialize_systems() -> void:
	print("[GameLauncher] 初始化游戏系统...")
	current_phase = LaunchPhase.LOADING_DATA

	# 确保所有管理器都已加载
	var required_managers = [
		"GameApplicationManager",
		"SettingsManager",
		"AchievementManager",
		"SaveManager"
	]

	for manager_name in required_managers:
		var manager = get_node_or_null("/root/" + manager_name)
		if manager == null:
			push_warning("[GameLauncher] 管理器未加载: ", manager_name)

	# 等待应用管理器初始化完成
	var app_mgr = get_node_or_null("/root/GameApplicationManager")
	if app_mgr != null:
		if app_mgr.has_signal("application_ready"):
			await app_mgr.application_ready

## 加载存档数据
func _load_save_data() -> void:
	print("[GameLauncher] 加载存档数据...")
	current_phase = LaunchPhase.LOADING_SAVE

	if launch_config["load_last_save"]:
		if SaveManager != null and SaveManager.has_method("has_save"):
			if SaveManager.has_save():
				SaveManager.load_game()

## 启动完成
func _launch_completed() -> void:
	print("[GameLauncher] 游戏启动完成!")
	current_phase = LaunchPhase.READY

	if loading_screen != null:
		loading_screen.visible = false

	# 显示主菜单
	_show_main_menu()

	game_ready.emit()

## 显示主菜单
func _show_main_menu() -> void:
	if main_menu != null:
		main_menu.visible = true

	# 检查是否需要自动启动教程
	if launch_config["auto_start_tutorial"]:
		_auto_start_tutorial()

## 自动启动教程
func _auto_start_tutorial() -> void:
	var tutorial_mgr = get_node_or_null("/root/TutorialProgressionManager")
	if tutorial_mgr != null and tutorial_mgr.has_method("start_tutorial"):
		tutorial_mgr.start_tutorial("basic_gameplay")

## 更新加载进度
func _update_loading_progress(status: String) -> void:
	if progress_bar != null:
		progress_bar.value = loading_progress

	if status_label != null:
		status_label.text = status

	loading_progress_updated.emit(loading_progress)

## 处理严重错误
func _handle_critical_error(message: String) -> void:
	error_message = message
	current_phase = LaunchPhase.ERROR

	critical_error_occurred.emit(message)

	# 显示错误界面
	_show_error_screen(message)

## 显示错误界面
func _show_error_screen(message: String) -> void:
	# 创建错误显示界面
	var error_panel = AcceptDialog.new()
	error_panel.title = "启动错误"
	error_panel.dialog_text = message + "\n\n请联系技术支持。"

	var retry_button = error_panel.get_ok_button()
	retry_button.text = "重试"

	error_panel.confirmed.connect(_on_retry_launch)

	add_child(error_panel)
	error_panel.popup_centered()

## 重试启动
func _on_retry_launch() -> void:
	print("[GameLauncher] 重试启动...")

	# 重置状态
	current_phase = LaunchPhase.INITIALIZING
	error_message = ""

	# 重新启动
	_start_launch_sequence()

## 开始新游戏
func start_new_game() -> void:
	print("[GameLauncher] 开始新游戏...")

	if main_menu != null:
		main_menu.visible = false

	if SaveManager != null and SaveManager.has_method("start_new_game"):
		SaveManager.start_new_game()

	# 进入游戏主场景
	_enter_game_scene()

## 加载游戏
func load_game() -> void:
	print("[GameLauncher] 加载游戏...")

	if main_menu != null:
		main_menu.visible = false

	# 显示加载界面
	if loading_screen != null:
		loading_screen.visible = true

	if SaveManager != null and SaveManager.has_method("load_game"):
		var success = SaveManager.load_game()

		if loading_screen != null:
			loading_screen.visible = false

		if success:
			_enter_game_scene()
		else:
			_show_error_screen("无法加载存档")

## 进入游戏场景
func _enter_game_scene() -> void:
	print("[GameLauncher] 进入游戏场景...")

	# 切换到主游戏场景
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## 退出游戏
func exit_game() -> void:
	print("[GameLauncher] 退出游戏...")

	# 清理资源
	_cleanup_before_exit()

	game_exiting.emit()

# 退出游戏
	get_tree().quit()

## 退出前清理
func _cleanup_before_exit() -> void:
	print("[GameLauncher] 清理游戏资源...")

	# 保存设置
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	if settings_mgr != null and settings_mgr.has_method("save_settings"):
		settings_mgr.save_settings()

	# 保存统计
	var stats_mgr = get_node_or_null("/root/StatisticsManager")
	if stats_mgr != null and stats_mgr.has_method("save_statistics"):
		stats_mgr.save_statistics()

## 获取启动配置
func get_launch_config() -> Dictionary:
	return launch_config.duplicate()

## 设置启动配置
func set_launch_config(key: String, value: Variant) -> void:
	if launch_config.has(key):
		launch_config[key] = value

## 获取当前启动阶段
func get_current_phase() -> LaunchPhase:
	return current_phase

## 获取加载进度
func get_loading_progress() -> float:
	return loading_progress

## 显示设置
func show_settings() -> void:
	print("[GameLauncher] 显示设置面板...")

	# 使用延迟加载获取设置面板
	var settings_panel = null
	if UILazyLoader:
		settings_panel = UILazyLoader.get_panel("settings")
	else:
		# 回退到直接加载
		settings_panel = preload("res://scenes/ui/settings_panel.tscn").instantiate()
		add_child(settings_panel)

	if settings_panel and settings_panel.has_signal("panel_closed"):
		settings_panel.panel_closed.connect(_on_settings_closed)

## 设置关闭处理
func _on_settings_closed() -> void:
	print("[GameLauncher] 设置面板已关闭")

## 显示成就
func show_achievements() -> void:
	print("[GameLauncher] 显示成就面板...")

	# 使用延迟加载获取成就面板
	var achievement_panel = null
	if UILazyLoader:
		achievement_panel = UILazyLoader.get_panel("achievement")
	else:
		# 回退到直接加载
		achievement_panel = preload("res://scenes/ui/achievement_panel.tscn").instantiate()
		add_child(achievement_panel)

## 显示存档管理
func show_save_management() -> void:
	print("[GameLauncher] 显示存档管理...")

	var save_slot_manager = preload("res://scenes/ui/save_slot_manager.tscn").instantiate()
	add_child(save_slot_manager)

## 显示帮助
func show_help() -> void:
	print("[GameLauncher] 显示帮助...")

	# 使用延迟加载获取帮助面板
	var help_panel = null
	if UILazyLoader:
		help_panel = UILazyLoader.get_panel("help")
	else:
		# 回退到直接加载
		help_panel = preload("res://scenes/ui/help_panel.tscn").instantiate()
		add_child(help_panel)

## 显示关于
func show_about() -> void:
	print("[GameLauncher] 显示关于信息...")

	var version_mgr = get_node_or_null("/root/VersionManager")
	var version_info = "Unknown"
	if version_mgr != null and version_mgr.has_method("get_version_info"):
		var info = version_mgr.get_version_info()
		version_info = info.get("version_string", "Unknown")

	var about_text = "Phase War\n版本: " + version_info + "\n\n© 2026 Phase Studio"

	var about_dialog = AcceptDialog.new()
	about_dialog.title = "关于"
	about_dialog.dialog_text = about_text
	about_dialog.size = Vector2(300, 200)

	add_child(about_dialog)
	about_dialog.popup_centered()

## 检查更新
func check_updates() -> void:
	print("[GameLauncher] 检查更新...")

	var version_mgr = get_node_or_null("/root/VersionManager")
	if version_mgr != null and version_mgr.has_method("check_updates"):
		version_mgr.check_updates()