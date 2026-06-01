extends Node
## 数据统计管理器：记录和追踪玩家的游戏统计数据
##
## 自动加载为单例，用于全局统计

## 统计数据
var _statistics: Dictionary = {
	"total_battles": 0,           # 总战斗场次
	"battles_won": 0,             # 胜利场次
	"battles_lost": 0,            # 失败场次
	"total_kills": 0,             # 总击杀单位数
	"total_damage_dealt": 0,      # 总造成伤害
	"total_damage_taken": 0,      # 总承受伤害
	"cards_collected": 0,         # 收集的卡片数
	"blueprints_unlocked": 0,     # 解锁的蓝图数
	"achievements_unlocked": 0,   # 解锁的成就数
	"levels_cleared": 0,          # 通关的关卡数
	"bosses_defeated": 0,         # 击败的Boss数
	"playtime_seconds": 0,        # 游戏时长（秒）
	"highest_combo": 0,           # 最高连击数
	"perfect_battles": 0,         # 完美战斗（无伤）场次
	"fastest_victory": 999.0,     # 最快胜利时间（秒）
	"total_earned": 0,            # 总获得的纳米材料
	"total_spent": 0,             # 总花费的纳米材料
}

signal statistic_changed(stat_id: String, new_value: int)

## 是否已完成延迟初始化
var _deferred_initialized: bool = false

## 初始化
func _init() -> void:
	# _statistics 字典已在声明处初始化
	# 耗时加载推迟到 _deferred_init()
	pass

func _ready() -> void:
	call_deferred("_deferred_init")

## 延迟初始化：在主循环空闲时加载统计数据
func _deferred_init() -> void:
	if _deferred_initialized:
		return
	_deferred_initialized = true
	_load_statistics()

## 记录战斗开始
func record_battle_start() -> void:
	_statistics["total_battles"] += 1
	_emit_change("total_battles")

## 记录战斗胜利
func record_battle_victory() -> void:
	_statistics["battles_won"] += 1
	_emit_change("battles_won")

## 记录战斗失败
func record_battle_defeat() -> void:
	_statistics["battles_lost"] += 1
	_emit_change("battles_lost")

## 记录击杀
func record_kill(count: int = 1) -> void:
	_statistics["total_kills"] += count
	_emit_change("total_kills")

## 记录造成伤害
func record_damage_dealt(damage: float) -> void:
	_statistics["total_damage_dealt"] += int(damage)
	_emit_change("total_damage_dealt")

## 记录承受伤害
func record_damage_taken(damage: float) -> void:
	_statistics["total_damage_taken"] += int(damage)
	_emit_change("total_damage_taken")

## 记录卡片收集
func record_card_collected() -> void:
	_statistics["cards_collected"] += 1
	_emit_change("cards_collected")

## 记录蓝图解锁
func record_blueprint_unlocked() -> void:
	_statistics["blueprints_unlocked"] += 1
	_emit_change("blueprints_unlocked")

## 记录成就解锁
func record_achievement_unlocked() -> void:
	_statistics["achievements_unlocked"] += 1
	_emit_change("achievements_unlocked")

## 记录关卡通关
func record_level_cleared(is_boss: bool = false) -> void:
	_statistics["levels_cleared"] += 1
	_emit_change("levels_cleared")

	if is_boss:
		_statistics["bosses_defeated"] += 1
		_emit_change("bosses_defeated")

## 记录完美战斗
func record_perfect_battle() -> void:
	_statistics["perfect_battles"] += 1
	_emit_change("perfect_battles")

## 记录最快胜利
func record_fastest_victory(time: float) -> void:
	if time > 0 and time < _statistics["fastest_victory"]:
		_statistics["fastest_victory"] = time
		_emit_change("fastest_victory")

## 记录游戏时长
func record_playtime(seconds: float) -> void:
	_statistics["playtime_seconds"] += int(seconds)
	_emit_change("playtime_seconds")

## 记录资源获得
func record_resource_earned(amount: int) -> void:
	_statistics["total_earned"] += amount
	_emit_change("total_earned")

## 记录资源花费
func record_resource_spent(amount: int) -> void:
	_statistics["total_spent"] += amount
	_emit_change("total_spent")

## 获取统计数据
func get_statistic(stat_id: String) -> int:
	return _statistics.get(stat_id, 0)

## 获取所有统计数据
func get_all_statistics() -> Dictionary:
	return _statistics.duplicate(true)

## 计算胜率
func get_win_rate() -> float:
	var total = _statistics["total_battles"]
	if total == 0:
		return 0.0
	return float(_statistics["battles_won"]) / float(total)

## 计算平均每场击杀
func get_avg_kills_per_battle() -> float:
	var battles = _statistics["total_battles"]
	if battles == 0:
		return 0.0
	return float(_statistics["total_kills"]) / float(battles)

## 获取格式化的游戏时长
func get_formatted_playtime() -> String:
	var total_seconds = _statistics["playtime_seconds"]
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60

	if hours > 0:
		return "%d小时%d分钟" % [hours, minutes]
	else:
		return "%d分钟" % minutes

## 获取统计摘要（用于UI显示）
func get_statistics_summary() -> Dictionary:
	return {
		"总战斗场次": _statistics["total_battles"],
		"胜利场次": _statistics["battles_won"],
		"胜率": "%.1f%%" % (get_win_rate() * 100),
		"总击杀": _statistics["total_kills"],
		"平均击杀/场": "%.1f" % get_avg_kills_per_battle(),
		"收集卡片": _statistics["cards_collected"],
		"解锁蓝图": _statistics["blueprints_unlocked"],
		"解锁成就": _statistics["achievements_unlocked"],
		"通关关卡": _statistics["levels_cleared"],
		"击败Boss": _statistics["bosses_defeated"],
		"完美战斗": _statistics["perfect_battles"],
		"游戏时长": get_formatted_playtime(),
		"最快胜利": "%.1f秒" % _statistics["fastest_victory"],
	}

## 重置统计数据
func reset_statistics() -> void:
	for key in _statistics.keys():
		_statistics[key] = 0
	_statistics["fastest_victory"] = 999.0
	_save_statistics()

## 保存统计数据
func _save_statistics() -> void:
	# 不再直接保存，改为由 SaveManager 统一管理
	pass

## 加载统计数据
func _load_statistics() -> void:
	# 不再直接加载，改为由 SaveManager 统一管理
	pass

## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return _statistics.duplicate()

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		for key in _statistics.keys():
			if data.has(key):
				_statistics[key] = data[key]

## 触发统计变化信号
func _emit_change(stat_id: String) -> void:
	statistic_changed.emit(stat_id, _statistics[stat_id])
	_save_statistics()
