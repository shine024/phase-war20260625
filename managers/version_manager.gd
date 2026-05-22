extends Node
## 版本管理器：处理游戏版本更新和兼容性

## 信号定义
signal update_available(update_info: Dictionary)
signal update_downloaded(progress: float)
signal update_installed()
signal version_checked(current_version: String, latest_version: String)

## 版本信息
var current_version: Dictionary = {
	"major": 1,
	"minor": 0,
	"patch": 0,
	"build": 1000,
	"version_string": "1.0.0",
	"build_date": "2026-03-30",
	"release_type": "stable"  # stable, beta, alpha
}

## 更新配置
var update_config: Dictionary = {
	"auto_check_enabled": true,
	"auto_download_enabled": false,
	"check_interval_hours": 24,
	"update_server": "",
	"beta_updates": false
}

## 更新状态
var update_status: Dictionary = {
	"is_checking": false,
	"update_available": false,
	"download_progress": 0.0,
	"latest_version": ""
}

func _ready() -> void:
	_load_version_info()
	_setup_auto_check()

## 加载版本信息
func _load_version_info() -> void:
	# 从项目配置读取版本信息
	var project_version = ProjectSettings.get_setting("application/config/version", "1.0.0")
	current_version["version_string"] = project_version

	var version_parts = project_version.split(".")
	if version_parts.size() >= 3:
		current_version["major"] = version_parts[0].to_int()
		current_version["minor"] = version_parts[1].to_int()
		current_version["patch"] = version_parts[2].to_int()

	print("[VersionManager] 当前版本: ", current_version["version_string"])

## 设置自动检查
func _setup_auto_check() -> void:
	if not update_config["auto_check_enabled"]:
		return

	var interval_seconds = update_config["check_interval_hours"] * 3600.0
	var check_timer = Timer.new()
	check_timer.wait_time = interval_seconds
	check_timer.autostart = true
	check_timer.timeout.connect(_on_auto_check_timeout)
	add_child(check_timer)

## 自动检查超时处理
func _on_auto_check_timeout() -> void:
	check_updates()

## 检查更新
func check_updates() -> void:
	if update_status["is_checking"]:
		print("[VersionManager] 正在检查更新，请稍候...")
		return

	update_status["is_checking"] = true
	print("[VersionManager] 检查游戏更新...")

	# 模拟更新检查（实际实现中应该连接到更新服务器）
	_perform_update_check()

## 执行更新检查
func _perform_update_check() -> void:
	# 这里实现实际的更新检查逻辑
	# 可能包括HTTP请求、版本比较等

	# 模拟检查延迟
	await get_tree().create_timer(2.0).timeout

	# 模拟无新版本
	update_status["is_checking"] = false
	update_status["update_available"] = false
	update_status["latest_version"] = current_version["version_string"]

	version_checked.emit(current_version["version_string"], current_version["version_string"])

	print("[VersionManager] 已是最新版本: ", current_version["version_string"])

## 比较版本
func compare_versions(version1: String, version2: String) -> int:
	var v1_parts = version1.split(".")
	var v2_parts = version2.split(".")

	for i in range(min(v1_parts.size(), v2_parts.size())):
		var v1_num = v1_parts[i].to_int()
		var v2_num = v2_parts[i].to_int()

		if v1_num < v2_num:
			return -1
		elif v1_num > v2_num:
			return 1

	if v1_parts.size() < v2_parts.size():
		return -1
	elif v1_parts.size() > v2_parts.size():
		return 1

	return 0

## 检查版本兼容性
func is_version_compatible(target_version: String) -> bool:
	# 简单的兼容性检查：主版本号必须相同
	var target_parts = target_version.split(".")
	var current_parts = current_version["version_string"].split(".")

	if target_parts.is_empty() or current_parts.is_empty():
		return false

	return target_parts[0] == current_parts[0]

## 获取版本信息
func get_version_info() -> Dictionary:
	return current_version.duplicate()

## 获取更新状态
func get_update_status() -> Dictionary:
	return update_status.duplicate()

## 获取版本历史
func get_version_history() -> Array[Dictionary]:
	return [
		{
			"version": "1.0.0",
			"release_date": "2026-03-30",
			"changes": [
				"初始正式版发布",
				"完整的战役模式",
				"30位敌方相位师",
				"100+成就系统",
				"增强存档系统"
			]
		},
		{
			"version": "0.9.0",
			"release_date": "2026-03-15",
			"changes": [
				"公测版本",
				"基础游戏系统",
				"卡牌系统",
				"装备系统"
			]
		}
	]

## 下载更新
func download_update() -> void:
	if not update_status["update_available"]:
		print("[VersionManager] 没有可用的更新")
		return

	print("[VersionManager] 开始下载更新...")
	# 实现更新下载逻辑

## 安装更新
func install_update() -> void:
	print("[VersionManager] 安装更新...")
	# 实现更新安装逻辑

	update_installed.emit()

## 获取系统信息
func get_system_info() -> Dictionary:
	return {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"memory": OS.get_memory_info(),
		"game_version": current_version["version_string"]
	}

## 生成诊断报告
func generate_diagnostic_report() -> Dictionary:
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"version_info": current_version,
		"update_status": update_status,
		"system_info": get_system_info(),
		"configuration": update_config
	}

## 导出诊断报告
func export_diagnostic_report(file_path: String) -> void:
	var report = generate_diagnostic_report()
	var json_str = JSON.stringify(report, "\t")

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()
		print("[VersionManager] 诊断报告已导出")

## 检查数据迁移需求
func check_migration_required() -> bool:
	# 检查是否需要数据迁移
	var last_version = _get_last_version()
	if last_version.is_empty():
		return false

	return compare_versions(last_version, current_version["version_string"]) < 0

## 获取上次运行的版本
func _get_last_version() -> String:
	var save_path = "user://last_version.json"
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var json_str = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_str) == OK:
				var data = json.get_data()
				if data is Dictionary and data.has("version"):
					return data["version"]

	return ""

## 保存当前版本
func save_current_version() -> void:
	var save_path = "user://last_version.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		var data = {"version": current_version["version_string"]}
		file.store_string(JSON.stringify(data))
		file.close()

## 获取更新配置
func get_update_config() -> Dictionary:
	return update_config.duplicate()

## 设置更新配置
func set_update_config(key: String, value: Variant) -> void:
	if update_config.has(key):
		update_config[key] = value
		_save_update_config()

## 保存更新配置
func _save_update_config() -> void:
	var save_path = "user://update_config.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(update_config))
		file.close()
