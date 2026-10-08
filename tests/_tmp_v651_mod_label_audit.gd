extends SceneTree
## v6.51 临时探针：改造情报英文审计——
## 1) 全注册表 effect keys（含 level_effects 三档）对 ModEffectLabels.translate 差集
## 2) 全 slot_type 对 resource_slot_item._SLOT_TYPE_CN 差集
## 输出未覆盖键清单（修复后应全空）。跑法：godot --headless --script tests/_tmp_v643_mod_label_audit.gd

const ModRegistryScript = preload("res://scripts/systems/modification_registry.gd")
const LabelsScript = preload("res://scripts/ui/mod_effect_labels.gd")
const SlotItemScript = preload("res://scenes/ui/resource_slot_item.gd")

func _init() -> void:
	var registry := ModRegistryScript.new()
	registry.register_all()
	var labels := LabelsScript.new()
	var slot_cn: Dictionary = SlotItemScript._SLOT_TYPE_CN

	var effect_keys := {}
	var slot_types := {}
	var flat: Dictionary = ModRegistryScript._flat_index
	for mod_id in flat.keys():
		var data: Dictionary = ModRegistryScript.get_data(String(mod_id))
		if data.is_empty():
			continue
		var st := String(data.get("slot_type", ""))
		if not st.is_empty():
			slot_types[st] = true
		var effects: Dictionary = data.get("effects", {})
		for k in effects.keys():
			var ks := String(k)
			if ks.begins_with("_") or ks == "grant_slot":
				continue
			effect_keys[ks] = true
		var le: Dictionary = data.get("level_effects", {})
		for lv in le.keys():
			var lev: Dictionary = le[lv] if le[lv] is Dictionary else {}
			for k2 in lev.keys():
				var ks2 := String(k2)
				if ks2.begins_with("_") or ks2 == "grant_slot":
					continue
				effect_keys[ks2] = true

	var untranslated: Array[String] = []
	for k in effect_keys.keys():
		var t := labels.translate(String(k))
		if t == String(k):
			untranslated.append(String(k))
	untranslated.sort()

	var unknown_slots: Array[String] = []
	for st in slot_types.keys():
		if not slot_cn.has(String(st)):
			unknown_slots.append(String(st))
	unknown_slots.sort()

	print("=== effect_keys total: %d ===" % effect_keys.size())
	print("=== untranslated effect keys (%d) ===" % untranslated.size())
	for k in untranslated:
		print("  ", k)
	print("=== slot_types total: %d ===" % slot_types.size())
	print("=== slot_types missing CN map (%d) ===" % unknown_slots.size())
	for s in unknown_slots:
		print("  ", s)
	print("=== AUDIT DONE ===")
	quit(0)
