extends RefCounted
class_name RunewordMatcher
## 符文之语匹配引擎（纯数据驱动，无状态）
##
## 职责：
##   输入：当前相位仪上装备的符文ID列表 + 相位仪槽位总数
##   输出：匹配成功的符文之语列表 + 合并后的效果字典
##
## 匹配规则（参考暗黑2）：
##   1. 符文之语要求的所有符文都必须在装备列表中
##   2. 重复符文不共用：required_runes 中如果有重复ID，装备列表也必须有对应数量的同ID符文
##   3. 相位仪槽位总数必须 >= 符文之语的 min_slot_count
##   4. 多个符文之语可同时激活，效果叠加
##
## 效果合并规则：
##   - 数值加成（attack/hp/...）：同类属性百分比叠加
##   - 特殊效果（on_kill_regen_energy/...）：独立触发，不叠加概率

const RunewordDefinitions = preload("res://data/runewords.gd")
const RuneDefinitions = preload("res://data/runes.gd")

# ── 核心匹配函数 ───────────────────────────────────────────────────

## 检查当前装备的符文激活了哪些符文之语
## 参数：
##   active_rune_ids — 当前装备的符文ID列表（可能含 null 空槽）
##   slot_count      — 相位仪符文槽位总数
## 返回：Array[Dictionary] 激活的符文之语定义列表
static func check_active_runewords(active_rune_ids: Array, slot_count: int) -> Array[Dictionary]:
	var clean_ids := _clean_rune_ids(active_rune_ids)
	if clean_ids.is_empty():
		return []
	var results: Array[Dictionary] = []
	for rw in RunewordDefinitions.ALL_RUNEWORDS:
		var required: Array = rw.get("required_runes", [])
		var min_slots: int = rw.get("min_slot_count", required.size())
		if slot_count < min_slots:
			continue
		if _matches_exact(clean_ids, required):
			results.append(rw)
	return results

## 合并多个激活符文之语的效果
## 返回：
##   {
##     "stats": {attack: 0.5, hp: 0.3, ...},         # 数值加成（同类叠加）
##     "specials": [{special: "...", chance:..., value:...}, ...]  # 特殊效果（独立，不叠加）
##   }
static func merge_effects(active_runewords: Array[Dictionary]) -> Dictionary:
	var merged_stats: Dictionary = {}
	var merged_specials: Array[Dictionary] = []
	for rw in active_runewords:
		for effect in rw.get("effects", []):
			if effect.has("stat"):
				var key: String = effect["stat"]
				merged_stats[key] = merged_stats.get(key, 0.0) + float(effect["value"])
			elif effect.has("special"):
				merged_specials.append({
					"special": effect["special"],
					"chance": float(effect.get("chance", 1.0)),
					"value": effect.get("value", 0),
				})
	return {"stats": merged_stats, "specials": merged_specials}

## 便捷函数：一步到位获取当前完整加成
## 返回：{"stats": {...}, "specials": [...]}
static func get_active_bonus(active_rune_ids: Array, slot_count: int) -> Dictionary:
	var matched := check_active_runewords(active_rune_ids, slot_count)
	return merge_effects(matched)

# ── UI 预览辅助 ────────────────────────────────────────────────────

## 预览：列出某符文组合潜在可激活的符文之语（不考虑槽位数）
## 用于UI提示"如果装备这些符文，可以激活什么"
## 参数：active_rune_ids — 已装备或打算装备的符文ID列表
## 返回：Array[Dictionary] 潜在符文之语列表
static func preview_potential_runewords(active_rune_ids: Array) -> Array[Dictionary]:
	var clean_ids := _clean_rune_ids(active_rune_ids)
	if clean_ids.is_empty():
		return []
	var results: Array[Dictionary] = []
	for rw in RunewordDefinitions.ALL_RUNEWORDS:
		if _is_subset(rw.get("required_runes", []), clean_ids):
			results.append(rw)
	return results

## 预览：检查如果新增某个符文，会激活哪些符文之语
## 参数：
##   current_rune_ids — 当前已装备符文
##   candidate_rune_id — 候选新增符文ID
##   slot_count — 槽位总数
## 返回：Array[Dictionary] 新增此符文后会激活的符文之语（增量）
static func preview_runewords_on_add(current_rune_ids: Array, candidate_rune_id: String, slot_count: int) -> Array[Dictionary]:
	var before := check_active_runewords(current_rune_ids, slot_count)
	var after_ids := current_rune_ids.duplicate()
	after_ids.append(candidate_rune_id)
	var after := check_active_runewords(after_ids, slot_count)
	var before_ids: Dictionary = {}
	for rw in before:
		before_ids[rw["id"]] = true
	var delta: Array[Dictionary] = []
	for rw in after:
		if not before_ids.has(rw["id"]):
			delta.append(rw)
	return delta

# ── 内部辅助 ───────────────────────────────────────────────────────

## 清理符文ID列表：移除 null/空字符串
static func _clean_rune_ids(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		if item == null:
			continue
		var s := str(item).strip_edges()
		if s.is_empty():
			continue
		result.append(s)
	return result

## 精确匹配：required 中的每个符文都必须在 available 中出现对应次数
## 例如 required=["a","a"] 则 available 必须至少有2个"a"
static func _matches_exact(available: Array[String], required: Array) -> bool:
	if required.is_empty():
		return false
	var pool: Array[String] = available.duplicate()
	for req in required:
		var idx := pool.find(str(req))
		if idx == -1:
			return false
		pool.remove_at(idx)
	return true

## 子集检查：required 中每个元素都在 available 中存在（不考虑重复）
static func _is_subset(required: Array, available: Array[String]) -> bool:
	for req in required:
		if not available.has(str(req)):
			return false
	return true

# ── 调试与统计 ─────────────────────────────────────────────────────

## 获取符文之语激活报告（调试用）
static func debug_report(active_rune_ids: Array, slot_count: int) -> String:
	var matched := check_active_runewords(active_rune_ids, slot_count)
	var bonus := merge_effects(matched)
	var lines: PackedStringArray = []
	lines.append("=== 符文之语激活报告 ===")
	lines.append("装备符文: %s" % str(_clean_rune_ids(active_rune_ids)))
	lines.append("槽位总数: %d" % slot_count)
	lines.append("激活符文之语(%d):" % matched.size())
	for rw in matched:
			lines.append("  - [%s] %s (tier %d)" % [rw["id"], RunewordDefinitions.get_runeword_name(rw["id"]), rw["tier"]])
	lines.append("数值加成:")
	for key in bonus["stats"]:
		lines.append("  %s: +%d%%" % [key, int(bonus["stats"][key] * 100)])
	lines.append("特殊效果(%d):" % bonus["specials"].size())
	for sp in bonus["specials"]:
		lines.append("  %s (%d%%概率)" % [sp["special"], int(sp["chance"] * 100)])
	return "\n".join(lines)
