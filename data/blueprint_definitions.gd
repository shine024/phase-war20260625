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
	var rest = blueprint_id.substr(15)  # 去掉 "blueprint_evol_" 前缀
	# 格式: blueprint_evol_<from_card_id>_<to_card_id>
	# card_id可能的格式: ww1_mp18, cold_ak47, fort_ww1_pillbox, mod_marine, fut_colossus
	# 策略: 使用已知前缀来找到from和to的分界点
	# 已知前缀（按优先级排序，长的在前）
	var known_prefixes = ["fort_", "ww1_", "ww2_", "cold_", "mod_", "fut_", "fe_", "ac"]
	var parts = rest.split("_")
	if parts.size() < 2:
		print("[BlueprintDefinitions] 解析失败：parts太少 %s" % [parts])
		return {}

	# 从后往前找最后一个已知前缀的位置（找到第一个就停止）
	var last_prefix_idx = -1
	for i in range(parts.size() - 1, -1, -1):  # 从后往前，包括第一个
		var part = parts[i]
		for prefix in known_prefixes:
			if part == prefix.rstrip("_"):  # 检查是否匹配前缀
				last_prefix_idx = i
				break
		if last_prefix_idx >= 0:
			break  # 找到后立即停止

	if last_prefix_idx <= 0:
		# 如果找不到明确的前缀，使用简单策略：最后两个部分为to，其余为from
		if parts.size() < 4:
			print("[BlueprintDefinitions] 解析失败：无法找到分界点 %s" % [parts])
			return {}
		var to_card = parts[parts.size() - 2] + "_" + parts[parts.size() - 1]
		var from_parts = parts.slice(0, parts.size() - 2)
		var from_card = ""
		for i in range(from_parts.size()):
			if i > 0:
				from_card += "_"
			from_card += from_parts[i]
		print("[BlueprintDefinitions] 简单解析: from=%s to=%s" % [from_card, to_card])
		return {"from": from_card, "to": to_card}

	# 找到了前缀，从该位置开始构建to_card
	var to_parts = parts.slice(last_prefix_idx)
	var to_card = ""
	for i in range(to_parts.size()):
		if i > 0:
			to_card += "_"
		to_card += to_parts[i]

	# from_card是剩余部分
	var from_parts = parts.slice(0, last_prefix_idx)
	var from_card = ""
	for i in range(from_parts.size()):
		if i > 0:
			from_card += "_"
		from_card += from_parts[i]

	print("[BlueprintDefinitions] 前缀解析: from=%s to=%s" % [from_card, to_card])
	return {"from": from_card, "to": to_card}

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
