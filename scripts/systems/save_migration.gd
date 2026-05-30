class_name SaveMigration
extends RefCounted
## 存档迁移、校验、清洗工具（从 save_manager.gd 提取）

const SAVE_SCHEMA_VERSION := 3

## 存档数据迁移（链式执行：逐步从 from_version 升级到 SAVE_SCHEMA_VERSION）
static func migrate_save_data(data: Dictionary, from_version: int, debug_log: bool = false) -> void:
	var ver: int = from_version
	while ver < SAVE_SCHEMA_VERSION:
		match ver:
			1:  # v1 → v2: 合并旧公司声望到势力系统
				if data.has("company"):
					var legacy := data["company"].get("company_rep", {}) as Dictionary
					if not legacy.is_empty() and data.has(SaveConstants.SK_FACTION_SYSTEM):
						data[SaveConstants.SK_FACTION_SYSTEM][SaveConstants.SK_LEGACY_COMPANY_REP] = legacy
				ver = 2
				data[SaveConstants.SK_SCHEMA_VERSION] = 2
			2:  # v2 → v3: 从SaveUtils独立文件迁移数据到save.json
				_migrate_v2_to_v3(data, debug_log)
				ver = 3
				data[SaveConstants.SK_SCHEMA_VERSION] = 3
			_:  # 未知版本，停止迁移
				push_warning("Unknown save schema version: %d" % ver)
				break

## v2 → v3 数据迁移：从SaveUtils独立文件合并数据
static func _migrate_v2_to_v3(data: Dictionary, debug_log: bool) -> void:
	if debug_log:
		print("[SaveMigration] 开始v2→v3数据迁移...")

	# 定义需要迁移的文件和对应的数据键
	var files_to_migrate = {
		"daily_tasks": SaveConstants.SK_DAILY_TASK,
		"tutorial_progress": SaveConstants.SK_TUTORIAL_PROGRESS,
		"card_collection": SaveConstants.SK_CARD_COLLECTION,
		"story_progress": SaveConstants.SK_STORY_PROGRESS,
		"characters": SaveConstants.SK_CHARACTERS,
		"challenge_records": SaveConstants.SK_CHALLENGE_RECORDS,
		"leaderboard_data": SaveConstants.SK_LEADERBOARD
	}

	# 迁移每个文件
	for file_name in files_to_migrate:
		var data_key = files_to_migrate[file_name]
		var migrated_data = _load_and_migrate_file(file_name, debug_log)
		if not migrated_data.is_empty():
			data[data_key] = migrated_data
			if debug_log:
				print("[SaveMigration] 已迁移文件 %s 到键 %s" % [file_name, data_key])

	if debug_log:
		print("[SaveMigration] v2→v3数据迁移完成")

## 从文件加载并迁移数据（一次性操作）
static func _load_and_migrate_file(file_name: String, debug_log: bool) -> Dictionary:
	## 从SaveUtils格式的文件加载数据，然后删除文件
	var save_dir = OS.get_user_data_dir()
	if save_dir.is_empty():
		return {}

	var save_path = save_dir + "/" + file_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}  # 文件不存在，跳过

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		if debug_log:
			print("[SaveMigration] 跳过损坏的文件: %s" % file_name)
		return {}

	var data = json.data
	if data is Dictionary:
		# 删除旧文件
		DirAccess.remove_absolute(save_path)
		if debug_log:
			print("[SaveMigration] 已删除旧文件: %s" % save_path)
		return data
	else:
		return {}

## 校验存档数据完整性（容错模式：缺失字段自动补全，仅致命错误拒绝加载）
static func validate_save_data(data: Dictionary, debug_log: bool = false) -> bool:
	## 校验存档数据完整性，防止损坏数据导致崩溃。
	## 缺失字段补默认值，仅数值类致命错误（负数/超范围）拒绝加载并打印详细信息。
	var errors: Array[String] = []
	var warnings: Array[String] = []

	# 校验必要字段（缺少时补默认值，不直接拒绝加载）
	if not data.has(SaveConstants.SK_BLUEPRINT):
		warnings.append("缺少 blueprint 字段（已补空字典）")
		data[SaveConstants.SK_BLUEPRINT] = {}
	if not data.has(SaveConstants.SK_GAME):
		warnings.append("缺少 game 字段（已补 current_level=1）")
		data[SaveConstants.SK_GAME] = {SaveConstants.SK_CURRENT_LEVEL: 1}

	# 校验蓝图碎片数量
	if data.has(SaveConstants.SK_BLUEPRINT) and data[SaveConstants.SK_BLUEPRINT] is Dictionary:
		var bp: Dictionary = data[SaveConstants.SK_BLUEPRINT]
		if bp.has("blueprint_counts"):
			var counts: Dictionary = bp["blueprint_counts"]
			for bp_id in counts.keys():
				var cnt: int = int(counts[bp_id])
				if cnt < 0:
					errors.append("蓝图 '%s' 数量为负: %d" % [bp_id, cnt])
	elif data.has(SaveConstants.SK_BLUEPRINT):
		warnings.append("blueprint 字段类型错误: %s（已覆盖为空字典）" % type_string(typeof(data[SaveConstants.SK_BLUEPRINT])))
		data[SaveConstants.SK_BLUEPRINT] = {}

	# 校验关卡等级范围
	if data.has(SaveConstants.SK_GAME) and data[SaveConstants.SK_GAME] is Dictionary:
		var gd: Dictionary = data[SaveConstants.SK_GAME]
		if gd.has(SaveConstants.SK_CURRENT_LEVEL):
			var level: int = int(gd[SaveConstants.SK_CURRENT_LEVEL])
			if level < 1 or level > 100:
				errors.append("关卡等级超出范围: %d (应为1-100)，已修正为1" % level)
				gd[SaveConstants.SK_CURRENT_LEVEL] = 1
				data[SaveConstants.SK_GAME] = gd
		else:
			warnings.append("game 字段缺少 current_level（已补1）")
			data[SaveConstants.SK_GAME][SaveConstants.SK_CURRENT_LEVEL] = 1
	elif data.has(SaveConstants.SK_GAME):
		warnings.append("game 字段类型错误: %s（已覆盖为默认值）" % type_string(typeof(data[SaveConstants.SK_GAME])))
		data[SaveConstants.SK_GAME] = {SaveConstants.SK_CURRENT_LEVEL: 1}

	# 校验基础资源不能为负
	if data.has(SaveConstants.SK_BASIC_RESOURCES) and data[SaveConstants.SK_BASIC_RESOURCES] is Dictionary:
		var br: Dictionary = data[SaveConstants.SK_BASIC_RESOURCES]
		for key in br:
			if br[key] is int and br[key] < 0:
				errors.append("基础资源为负: %s = %d（已修正为0）" % [key, br[key]])
				br[key] = 0

	# 打印校验摘要
	if not warnings.is_empty():
		var msg := "[SaveManager] 存档校验警告 (%d): %s" % [warnings.size(), "; ".join(warnings)]
		push_warning(msg)
	if not errors.is_empty():
		var msg := "[SaveManager] 存档校验错误 (%d): %s" % [errors.size(), "; ".join(errors)]
		push_error(msg)
	if warnings.is_empty() and errors.is_empty():
		if debug_log:
			print("[SaveManager] 存档校验通过")

	return errors.is_empty()

## 轻量加载归一化（性能模式）
static func apply_fast_load_normalization(data: Dictionary) -> void:
	if not data.has(SaveConstants.SK_BLUEPRINT) or not (data[SaveConstants.SK_BLUEPRINT] is Dictionary):
		data[SaveConstants.SK_BLUEPRINT] = {}
	if not data.has(SaveConstants.SK_GAME) or not (data[SaveConstants.SK_GAME] is Dictionary):
		data[SaveConstants.SK_GAME] = {SaveConstants.SK_CURRENT_LEVEL: 1}
	var gd: Dictionary = data[SaveConstants.SK_GAME] as Dictionary
	var level: int = int(gd.get(SaveConstants.SK_CURRENT_LEVEL, 1))
	if level < 1 or level > 100:
		level = 1
	gd[SaveConstants.SK_CURRENT_LEVEL] = level
	data[SaveConstants.SK_GAME] = gd

## 递归清洗存档数据中的非法浮点值（inf/-inf/nan → 0.0）
static func sanitize_save_variant(v: Variant) -> Variant:
	if v is Dictionary:
		var src: Dictionary = v
		var out: Dictionary = {}
		for k in src.keys():
			out[k] = sanitize_save_variant(src[k])
		return out
	if v is Array:
		var src_arr: Array = v
		var out_arr: Array = []
		out_arr.resize(src_arr.size())
		for i in range(src_arr.size()):
			out_arr[i] = sanitize_save_variant(src_arr[i])
		return out_arr
	if v is float:
		var f: float = v
		if is_nan(f) or is_inf(f):
			return 0.0
	return v

## 修复 JSON 字符串中的非有限数值标记（inf/-inf/nan → 0）
static func repair_non_finite_json_tokens(json_str: String) -> String:
	var s := json_str
	# 常见模式：对象值和数组值中的 inf/-inf/nan
	s = s.replace(":inf", ":0")
	s = s.replace(":-inf", ":0")
	s = s.replace(":nan", ":0")
	s = s.replace(",inf", ",0")
	s = s.replace(",-inf", ",0")
	s = s.replace(",nan", ",0")
	s = s.replace("[inf", "[0")
	s = s.replace("[-inf", "[0")
	s = s.replace("[nan", "[0")
	# 含空白分隔的变体
	s = s.replace(": inf", ": 0")
	s = s.replace(": -inf", ": 0")
	s = s.replace(": nan", ": 0")
	s = s.replace(", inf", ", 0")
	s = s.replace(", -inf", ", 0")
	s = s.replace(", nan", ", 0")
	s = s.replace("[ inf", "[ 0")
	s = s.replace("[ -inf", "[ 0")
	s = s.replace("[ nan", "[ 0")
	return s
