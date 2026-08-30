class_name SaveMigrationV9
extends RefCounted
## v8 → v9 存档迁移：改造解锁集 + 产能点（v21 P3-B，计划 C1/A4）
##
## 新增字段：
##   mod_unlock_state  — 账号级改造解锁集（dict: mod_id→true，另含 "first_kill_<master_id>" 首杀标记）
##                       由 ModificationRegistry 持有，SaveManager 经 CRITICAL_MANAGER_LOADS 挂载。
##   basic_resources.production_points — 产能点（DayClock 按天结算、打造消耗），
##                       由 BasicResourceManager 持有（嵌在其存档段内，非根键）。
##
## 兼容惯例（与 v5/v6/v7/v8 一致）：旧档缺 key 静默补默认值；已有值不覆盖；
## 类型异常（非 Dictionary / 非 int）回退默认值，不抛错不丢档。

## v8 → v9 迁移：补默认字段
static func migrate_v8_to_v9(data: Dictionary, debug_log: bool = false) -> void:
	var added: Array = []

	# 1. 账号级改造解锁集：缺 key / 类型异常 → 静默补空字典
	if not data.has(SaveConstants.SK_MOD_UNLOCK_STATE) or not (data[SaveConstants.SK_MOD_UNLOCK_STATE] is Dictionary):
		data[SaveConstants.SK_MOD_UNLOCK_STATE] = {}
		added.append("mod_unlock_state")

	# 2. 产能点：basic_resources 段存在且缺 key → 静默补 0；
	#    段整体缺失时不造空段（新游戏走管理器默认值，与既有字段级跳过惯例一致）
	if data.has(SaveConstants.SK_BASIC_RESOURCES) and data[SaveConstants.SK_BASIC_RESOURCES] is Dictionary:
		var br: Dictionary = data[SaveConstants.SK_BASIC_RESOURCES]
		if not br.has("production_points") or not (br["production_points"] is int):
			br["production_points"] = int(br.get("production_points", 0))
			added.append("basic_resources.production_points")

	if debug_log and not added.is_empty():
		push_warning("[SaveMigrationV9] v8→v9: 补默认字段 %s" % ", ".join(added))
