extends RefCounted
## 蓝图定义系统
## 为每个改造模块和进化路径定义对应的蓝图ID

## ─────────────────────────────────────────────
##  改造蓝图ID前缀
## ─────────────────────────────────────────────

## 改造蓝图ID格式: "blueprint_<mod_id>"
## 例如: "blueprint_inf_01_submachine_gun"

## 进化蓝图ID格式: "blueprint_evol_<from_card_id>_<to_card_id>"
## 例如: "blueprint_evol_omega_platform_mk1_omega_platform_mk2"

## ─────────────────────────────────────────────
##  静态方法
## ─────────────────────────────────────────────

## 获取改造蓝图ID
static func get_mod_blueprint_id(mod_id: String) -> String:
	return "blueprint_" + mod_id

## 获取进化蓝图ID
static func get_evolution_blueprint_id(from_card_id: String, to_card_id: String) -> String:
	return "blueprint_evol_" + from_card_id + "_" + to_card_id

## 从蓝图ID提取改造ID
static func extract_mod_id(blueprint_id: String) -> String:
	if not blueprint_id.begins_with("blueprint_"):
		return ""
	if blueprint_id.begins_with("blueprint_evol_"):
		return ""  # 这是进化蓝图
	return blueprint_id.substr(10)  # 去掉 "blueprint_" 前缀

## 从蓝图ID提取进化信息
static func extract_evolution_info(blueprint_id: String) -> Dictionary:
	if not blueprint_id.begins_with("blueprint_evol_"):
		return {}
	var parts = blueprint_id.substr(15).split("_")  # 去掉 "blueprint_evol_" 前缀
	# 格式: blueprint_evol_<from>_<to>
	# 需要找到两个card_id的分界点
	# 简化处理：假设card_id不包含下划线，或者按已知规则解析
	# 实际项目中card_id可能包含下划线，这里需要更复杂的解析
	# 暂时返回空，由调用者根据实际card_id格式处理
	return {"from": "", "to": ""}

## 检查是否为改造蓝图
static func is_mod_blueprint(blueprint_id: String) -> bool:
	return blueprint_id.begins_with("blueprint_") and not blueprint_id.begins_with("blueprint_evol_")

## 检查是否为进化蓝图
static func is_evolution_blueprint(blueprint_id: String) -> bool:
	return blueprint_id.begins_with("blueprint_evol_")

## ─────────────────────────────────────────────
##  蓝图稀有度（继承自改造/进化定义）
## ─────────────────────────────────────────────

## 获取改造蓝图的稀有度
static func get_mod_blueprint_rarity(mod_id: String) -> String:
	const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
	var mod_data = ModificationRegistry.get_data(mod_id)
	if mod_data.is_empty():
		return "common"
	return mod_data.get("rarity", "common")

## 获取改造蓝图的名称
static func get_mod_blueprint_name(mod_id: String) -> String:
	const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
	var mod_data = ModificationRegistry.get_data(mod_id)
	if mod_data.is_empty():
		return "未知图纸"
	return mod_data.get("name", "未知图纸") + "图纸"
