extends Node
## 基础资源管理：记录全局的基本纳米颗粒与能量块总量
##
## - 具体背包格子由 BackpackPanel 按总量拆分为多堆显示

const BasicResources = preload("res://data/basic_resources.gd")

signal resources_changed

# 统一的资源变量
var total_nano_materials: int = 0
var total_alloy: int = 0
var total_crystal: int = 0
var total_energy_block: int = 0
var total_research_points: int = 0
var custom_totals: Dictionary = {}

# 兼容性变量（映射到新的资源系统）
var total_basic_nano: int = 0  # 映射到 total_nano_materials

func add_resource(id: String, amount: int) -> void:
	if amount == 0:
		return
	match id:
		BasicResources.ID_NANO_MATERIALS, "basic_nano":  # 兼容旧ID
			var before := total_nano_materials
			total_nano_materials = max(0, total_nano_materials + amount)
			# 同步更新兼容变量
			total_basic_nano = total_nano_materials
		BasicResources.ID_ALLOY:
			var before_a := total_alloy
			total_alloy = max(0, total_alloy + amount)
		BasicResources.ID_CRYSTAL:
			var before_c := total_crystal
			total_crystal = max(0, total_crystal + amount)
		BasicResources.ID_ENERGY_BLOCK:
			var before_e := total_energy_block
			total_energy_block = max(0, total_energy_block + amount)
		BasicResources.ID_RESEARCH_POINTS:
			var before_r := total_research_points
			total_research_points = max(0, total_research_points + amount)
		BasicResources.ID_PERMIT_GENERAL, BasicResources.ID_PERMIT_TYPE_ASSAULT, BasicResources.ID_PERMIT_TYPE_HEAVY, BasicResources.ID_PERMIT_TYPE_SUPPORT, BasicResources.ID_PERMIT_TYPE_LAW:
			custom_totals[id] = max(0, int(custom_totals.get(id, 0)) + amount)
		_:
			# 动态资源（如专属改造许可函 permit_card_xxx）
			custom_totals[id] = max(0, int(custom_totals.get(id, 0)) + amount)
	resources_changed.emit()

func add_basic_resource(id: String, amount: int) -> void:
	if amount == 0:
		return
	match id:
		"nano_materials", "basic_nano":  # 兼容旧ID
			var before := total_nano_materials
			total_nano_materials = max(0, total_nano_materials + amount)
			total_basic_nano = total_nano_materials  # 同步兼容变量
		"alloy":
			var before_a := total_alloy
			total_alloy = max(0, total_alloy + amount)
		"crystal":
			var before_c := total_crystal
			total_crystal = max(0, total_crystal + amount)
		"energy_block":
			var before_e := total_energy_block
			total_energy_block = max(0, total_energy_block + amount)
		"research_points":
			var before_r := total_research_points
			total_research_points = max(0, total_research_points + amount)
		"permit_general", "permit_type_assault", "permit_type_heavy", "permit_type_support", "permit_type_law":
			custom_totals[id] = max(0, int(custom_totals.get(id, 0)) + amount)
		_:
			custom_totals[id] = max(0, int(custom_totals.get(id, 0)) + amount)
	resources_changed.emit()

func get_total(id: String) -> int:
	match id:
		BasicResources.ID_NANO_MATERIALS, "nano_materials", "basic_nano", "nano":  # 兼容旧ID和短名称
			return total_nano_materials
		BasicResources.ID_ALLOY, "alloy":
			return total_alloy
		BasicResources.ID_CRYSTAL, "crystal":
			return total_crystal
		BasicResources.ID_ENERGY_BLOCK, "energy_block", "energy":
			return total_energy_block
		BasicResources.ID_RESEARCH_POINTS, "research_points", "research":
			return total_research_points
		_:
			return int(custom_totals.get(id, 0))

func get_all_totals() -> Dictionary:
	var out: Dictionary = {
		BasicResources.ID_NANO_MATERIALS: total_nano_materials,
		BasicResources.ID_ALLOY: total_alloy,
		BasicResources.ID_CRYSTAL: total_crystal,
		BasicResources.ID_ENERGY_BLOCK: total_energy_block,
		BasicResources.ID_RESEARCH_POINTS: total_research_points,
		# 兼容性映射
		"basic_nano": total_nano_materials,
	}
	for k in custom_totals.keys():
		out[k] = int(custom_totals[k])
	return out

func save_state() -> Dictionary:
	return {
		"total_nano_materials": total_nano_materials,
		"total_alloy": total_alloy,
		"total_crystal": total_crystal,
		"total_energy_block": total_energy_block,
		"total_research_points": total_research_points,
		"custom_totals": custom_totals.duplicate(true),
		# 兼容性字段
		"total_basic_nano": total_nano_materials,
	}

func load_state(data: Dictionary) -> void:
	# 优先加载新字段，回退到兼容字段
	total_nano_materials = int(data.get("total_nano_materials", data.get("total_basic_nano", 0)))
	total_alloy = int(data.get("total_alloy", 0))
	total_crystal = int(data.get("total_crystal", 0))
	total_energy_block = int(data.get("total_energy_block", 0))
	total_research_points = int(data.get("total_research_points", 0))
	custom_totals = data.get("custom_totals", {})
	if not (custom_totals is Dictionary):
		custom_totals = {}
	# 同步兼容变量
	total_basic_nano = total_nano_materials
	resources_changed.emit()

## 检查资源是否足够（用于BlueprintManager调用）
func can_afford(id: String, amount: int) -> bool:
	return get_total(id) >= amount

## 消耗资源（用于BlueprintManager调用）
func consume(id: String, amount: int) -> void:
	add_resource(id, -amount)
