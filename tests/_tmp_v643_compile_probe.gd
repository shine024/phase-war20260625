extends SceneTree
## 记录7 临时探针：引擎侧编译检查 affix_display_format.gd / card_info_panel.gd

func _init() -> void:
	var adf: GDScript = load("res://scripts/affix_display_format.gd")
	print("ADF loaded: ", adf)
	if adf != null and adf.can_instantiate():
		var inst: Object = adf.new()
		print("has fmt_player_affix_tags: ", inst.has_method("fmt_player_affix_tags"))
		print("has fmt_affix_value: ", inst.has_method("fmt_affix_value"))
		# 数值短串冒烟（鸭子对象）
		var fake := {
			"current_value": 0.08, "effect_key": "platform_hp_up",
		}
		print("fmt_affix_value(fake): ", adf.call("fmt_affix_value", fake))
		inst.free()
	var cip: GDScript = load("res://scenes/ui/card_info_panel.gd")
	print("card_info_panel loaded: ", cip)
	print("PROBE DONE")
	quit(0)
