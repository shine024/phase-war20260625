extends RefCounted
class_name PhaseMasterRoster
## 统一相位师名册 -- 聚合文件 (50名相位师)
## 数据按时代拆分到子文件中，本文件负责聚合查询
##
## 势力映射（敌方旧势力->新势力）：
##   steel->iron_bastion | flame->crimson_blade | thunder->sun_forge | void->void_walkers
##   混合势力保留原名 | neutral/ashen_order/frost_crown 为新增势力
## 星级分界：1*(0-250) 2*(250-600) 3*(600-1200) 4*(1200-2200) 5*(2200-3800) 6*(3800-6000) 7*(6000+)

const _roster_ww1 = preload("res://data/phase_master_roster_ww1.gd")
const _roster_ww2 = preload("res://data/phase_master_roster_ww2.gd")
const _roster_cold = preload("res://data/phase_master_roster_cold.gd")
const _roster_modern = preload("res://data/phase_master_roster_modern.gd")
const _roster_future = preload("res://data/phase_master_roster_future.gd")

## 全部50名相位师（缓存，懒加载）
static var _all_masters_cache: Array[Dictionary] = []
static var _cache_built: bool = false

static func ALL_MASTERS() -> Array[Dictionary]:
	if not _cache_built:
		_all_masters_cache = []
		_all_masters_cache.append_array(_roster_ww1.ALL_MASTERS)
		_all_masters_cache.append_array(_roster_ww2.ALL_MASTERS)
		_all_masters_cache.append_array(_roster_cold.ALL_MASTERS)
		_all_masters_cache.append_array(_roster_modern.ALL_MASTERS)
		_all_masters_cache.append_array(_roster_future.ALL_MASTERS)
		_cache_built = true
	return _all_masters_cache

## 查找相位师 by id
static func find_by_id(master_id: String) -> Dictionary:
	for m in ALL_MASTERS():
		if m.get("id", "") == master_id:
			return m
	return {}

## 获取某方全部相位师
static func get_by_side(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS():
		if m.get("side", "") == side:
			result.append(m)
	return result

## 获取某势力全部相位师
static func get_by_faction(faction: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS():
		if m.get("faction", "") == faction:
			result.append(m)
	return result

## 获取排行榜数据 (id, name, faction, estimated_power)
## 实际战力由 MasterPowerEvaluator 计算
static func get_leaderboard() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS():
		result.append({
			"id": m.get("id", ""),
			"name": m.get("name", ""),
			"title": m.get("title", ""),
			"faction": m.get("faction", ""),
			"side": m.get("side", ""),
		})
	return result
