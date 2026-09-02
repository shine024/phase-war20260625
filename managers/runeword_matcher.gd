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
