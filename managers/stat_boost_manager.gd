extends Node
## 属性提升管理器：记录和管理玩家获得的所有属性提升效果

signal stat_boost_applied(boost_id: String, boost_name: String, total_count: int)

## 属性提升类型定义
enum BoostType {
	HP_MAX,           # 最大生命值提升
	DAMAGE,           # 伤害提升
	SPEED,            # 移动速度提升
	DEFENSE,          # 防御力提升
	ATTACK_SPEED,     # 攻击速度提升
	CRIT_RATE,        # 暴击率提升
	CRIT_DAMAGE,      # 暴击伤害提升
}

## 属性提升数据库
const BOOST_DATABASE: Dictionary = {
	# 生命提升
	"stat_boost_hp": {
		"id": "stat_boost_hp",
		"name": "生命强化",
		"type": BoostType.HP_MAX,
		"description": "单位最大生命值 +5%",
		"bonus_per_stack": 0.05,  # 每层提升5%
		"max_stacks": 20,         # 最多20层，即+100%
	},
	"stat_boost_hp_major": {
		"id": "stat_boost_hp_major",
		"name": "生命强化·大",
		"type": BoostType.HP_MAX,
		"description": "单位最大生命值 +10%",
		"bonus_per_stack": 0.10,
		"max_stacks": 10,
	},

	# 伤害提升
	"stat_boost_damage": {
		"id": "stat_boost_damage",
		"name": "攻击强化",
		"type": BoostType.DAMAGE,
		"description": "单位造成的伤害 +3%",
		"bonus_per_stack": 0.03,
		"max_stacks": 25,
	},
	"stat_boost_damage_major": {
		"id": "stat_boost_damage_major",
		"name": "攻击强化·大",
		"type": BoostType.DAMAGE,
		"description": "单位造成的伤害 +7%",
		"bonus_per_stack": 0.07,
		"max_stacks": 12,
	},

	# 速度提升
	"stat_boost_speed": {
		"id": "stat_boost_speed",
		"name": "速度强化",
		"type": BoostType.SPEED,
		"description": "单位移动速度 +4%",
		"bonus_per_stack": 0.04,
		"max_stacks": 15,
	},

	# 防御提升
	"stat_boost_defense": {
		"id": "stat_boost_defense",
		"name": "防御强化",
		"type": BoostType.DEFENSE,
		"description": "单位受到的伤害 -3%",
		"bonus_per_stack": -0.03,
		"max_stacks": 20,
	},

	# 攻速提升
	"stat_boost_attack_speed": {
		"id": "stat_boost_attack_speed",
		"name": "攻速强化",
		"type": BoostType.ATTACK_SPEED,
		"description": "单位攻击速度 +5%",
		"bonus_per_stack": 0.05,
		"max_stacks": 15,
	},

	# 暴击提升
	"stat_boost_crit": {
		"id": "stat_boost_crit",
		"name": "暴击强化",
		"type": BoostType.CRIT_RATE,
		"description": "单位暴击率 +2%",
		"bonus_per_stack": 0.02,
		"max_stacks": 20,
	},
	"stat_boost_crit_damage": {
		"id": "stat_boost_crit_damage",
		"name": "暴伤强化",
		"type": BoostType.CRIT_DAMAGE,
		"description": "单位暴击伤害 +10%",
		"bonus_per_stack": 0.10,
		"max_stacks": 10,
	},
}

## 已获得的属性提升记录 [boost_id] = count
var boost_counts: Dictionary = {}

func _ready() -> void:
	pass

## 应用属性提升
func apply_boost(boost_id: String) -> void:
	if not BOOST_DATABASE.has(boost_id):
		push_error("[StatBoostManager] 未知的属性提升ID: %s" % boost_id)
		return

	var boost_data = BOOST_DATABASE[boost_id]
	var current_count = boost_counts.get(boost_id, 0)
	var max_stacks = boost_data.get("max_stacks", 999)

	if current_count >= max_stacks:
		print("[StatBoostManager] 属性提升已达上限: ", boost_data.get("name", boost_id))
		return

	boost_counts[boost_id] = current_count + 1
	stat_boost_applied.emit(boost_id, boost_data.get("name", boost_id), boost_counts[boost_id])
	print("[StatBoostManager] 应用属性提升: ", boost_data.get("name", boost_id), " (", boost_counts[boost_id], "/", max_stacks, ")")

## 获取指定属性提升的层数
func get_boost_count(boost_id: String) -> int:
	return boost_counts.get(boost_id, 0)

## 获取指定属性提升的总加成
func get_boost_bonus(boost_id: String) -> float:
	if not BOOST_DATABASE.has(boost_id):
		return 0.0

	var boost_data = BOOST_DATABASE[boost_id]
	var count = boost_counts.get(boost_id, 0)
	var bonus_per_stack = boost_data.get("bonus_per_stack", 0.0)
	var max_stacks = boost_data.get("max_stacks", 999)

	var actual_count = mini(count, max_stacks)
	return actual_count * bonus_per_stack

## 应用所有属性提升到单位属性
func apply_all_boosts_to_stats(stats: UnitStats) -> void:
	if not stats:
		return

	# HP 提升
	var hp_bonus = get_total_bonus_for_type(BoostType.HP_MAX)
	if hp_bonus != 0.0:
		stats.max_hp *= (1.0 + hp_bonus)

	# 伤害提升
	var damage_bonus = get_total_bonus_for_type(BoostType.DAMAGE)
	if damage_bonus != 0.0:
		stats.attack_damage *= (1.0 + damage_bonus)

	# 速度提升
	var speed_bonus = get_total_bonus_for_type(BoostType.SPEED)
	if speed_bonus != 0.0:
		stats.move_speed *= (1.0 + speed_bonus)

	# 防御提升（负值表示减伤）
	var defense_bonus = get_total_bonus_for_type(BoostType.DEFENSE)
	if defense_bonus != 0.0:
		stats.damage_reduction += defense_bonus

	# 攻速提升
	var attack_speed_bonus = get_total_bonus_for_type(BoostType.ATTACK_SPEED)
	if attack_speed_bonus != 0.0:
		stats.attack_interval *= (1.0 + attack_speed_bonus)

	# 暴击率提升
	var crit_rate_bonus = get_total_bonus_for_type(BoostType.CRIT_RATE)
	if crit_rate_bonus != 0.0:
		stats.crit_chance += crit_rate_bonus

	# 暴击伤害提升
	var crit_damage_bonus = get_total_bonus_for_type(BoostType.CRIT_DAMAGE)
	if crit_damage_bonus != 0.0:
		stats.crit_damage_bonus += crit_damage_bonus

## 获取指定类型的所有加成总和
func get_total_bonus_for_type(boost_type: BoostType) -> float:
	var total_bonus = 0.0
	for boost_id in boost_counts:
		var boost_data = BOOST_DATABASE.get(boost_id, {})
		if boost_data.get("type", -1) == boost_type:
			var count = boost_counts[boost_id]
			var max_stacks = boost_data.get("max_stacks", 999)
			var bonus_per_stack = boost_data.get("bonus_per_stack", 0.0)
			total_bonus += mini(count, max_stacks) * bonus_per_stack
	return total_bonus

## 获取所有已获得的属性提升
func get_all_boosts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for boost_id in boost_counts:
		var boost_data = BOOST_DATABASE.get(boost_id, {})
		if not boost_data.is_empty():
			var entry = boost_data.duplicate()
			entry["count"] = boost_counts[boost_id]
			entry["current_bonus"] = get_boost_bonus(boost_id)
			result.append(entry)
	return result

## 重置所有属性提升
func reset_all_boosts() -> void:
	boost_counts.clear()
	print("[StatBoostManager] 已重置所有属性提升")

## 获取属性提升数据
func get_boost_data(boost_id: String) -> Dictionary:
	return BOOST_DATABASE.get(boost_id, {})

## 保存状态
func save_state() -> Dictionary:
	return {
		"boost_counts": boost_counts
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	boost_counts.clear()
	var saved_counts = data.get("boost_counts", {})
	for boost_id in saved_counts:
		if BOOST_DATABASE.has(boost_id):
			boost_counts[boost_id] = saved_counts[boost_id]
	print("[StatBoostManager] 加载属性提升状态")
