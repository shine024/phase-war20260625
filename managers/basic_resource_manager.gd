extends Node
## 基础资源管理：记录全局的基本纳米颗粒与能量块总量
##
## - 具体背包格子由 BackpackPanel 按总量拆分为多堆显示

const BasicResources = preload("res://data/basic_resources.gd")

signal resources_changed
## P1-6: 单资源变动明细（id 为规范化ID，applied 为实际入账增量，可正可负）。
## resources_changed 是无参信号，此前资源栏只能整体重读——飘字反馈需要知道"谁变了多少"。
signal resource_delta(id: String, applied: int)

# 统一的资源变量
var total_nano_materials: int = 0
var total_alloy: int = 0
var total_crystal: int = 0
var total_energy_block: int = 0
var custom_totals: Dictionary = {}

# 兼容性变量（映射到新的资源系统）
var total_basic_nano: int = 0  # 映射到 total_nano_materials

func add_resource(id: String, amount: int) -> void:
	if amount == 0:
		resources_changed.emit()
		return
	var before_total: int = get_total(id)
	match id:
		BasicResources.ID_NANO_MATERIALS, "basic_nano", "nano":  # 兼容旧ID
			total_nano_materials = max(0, total_nano_materials + amount)
			# 同步更新兼容变量
			total_basic_nano = total_nano_materials
		BasicResources.ID_ALLOY:
			total_alloy = max(0, total_alloy + amount)
		BasicResources.ID_CRYSTAL:
			total_crystal = max(0, total_crystal + amount)
		BasicResources.ID_ENERGY_BLOCK:
			total_energy_block = max(0, total_energy_block + amount)
		# v9.x（P2-7范围C）：research_points 已退役——旧代码传入落入 custom_totals 静默忽略
		_:
			# 动态资源（如专属改造许可函 permit_card_xxx）
			custom_totals[id] = max(0, int(custom_totals.get(id, 0)) + amount)
	resources_changed.emit()
	var applied: int = get_total(id) - before_total
	if applied != 0:
		resource_delta.emit(_normalize_id(id), applied)

## add_basic_resource 与 add_resource 语义完全一致（ID 常量与字符串字面量同值），收敛为委托
func add_basic_resource(id: String, amount: int) -> void:
	add_resource(id, amount)

## 别名ID → 规范化ID（nano/basic_nano → nano_materials），供 resource_delta 消费方对键
func _normalize_id(id: String) -> String:
	match id:
		"basic_nano", "nano":
			return BasicResources.ID_NANO_MATERIALS
		"alloy":
			return BasicResources.ID_ALLOY
		"crystal":
			return BasicResources.ID_CRYSTAL
		"energy_block", "energy":
			return BasicResources.ID_ENERGY_BLOCK
		_:
			return id

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
		_:
			return int(custom_totals.get(id, 0))

func get_all_totals() -> Dictionary:
	var out: Dictionary = {
		BasicResources.ID_NANO_MATERIALS: total_nano_materials,
		BasicResources.ID_ALLOY: total_alloy,
		BasicResources.ID_CRYSTAL: total_crystal,
		BasicResources.ID_ENERGY_BLOCK: total_energy_block,
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
	# v9.x（P2-7范围C）：旧档 total_research_points key 静默跳过（科研点退役）
	custom_totals = data.get("custom_totals", {})
	if not (custom_totals is Dictionary):
		custom_totals = {}
	# 同步兼容变量
	total_basic_nano = total_nano_materials
	resources_changed.emit()

## 检查资源是否足够（用于BlueprintManager调用）
## 检查资源是否足够（用于BlueprintManager调用）
func can_afford(id: String, amount: int) -> bool:
	return get_total(id) >= amount

## 消耗资源（用于BlueprintManager调用）
func consume(id: String, amount: int) -> void:
	add_resource(id, -amount)
