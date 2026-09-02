extends SceneTree

## 临时探针：验证 CardMechanismDesc 全局类解析 + 三个消费方脚本可解析。用完即删。

func _init() -> void:
	var n: int = CardMechanismDesc.MECHANISM_DESC.size()
	print("[probe] CardMechanismDesc resolved, MECHANISM_DESC size=", n)
	var lines: Array[String] = CardMechanismDesc.get_mechanism_lines(["radar", "雷达", "bogus"])
	print("[probe] get_mechanism_lines radar-merged=", lines.size())
	for p in [
		"res://data/card_mechanism_desc.gd",
		"res://scenes/ui/card_info_panel.gd",
		"res://scenes/ui/backpack_card_item.gd",
		"res://scenes/ui/bottom_instrument_bar.gd",
	]:
		var s: GDScript = load(p)
		if s == null:
			print("[probe] FAIL load: ", p)
			continue
		var err: int = s.reload()
		if err != OK:
			print("[probe] PARSE FAIL: ", p, " err=", err)
		else:
			print("[probe] OK: ", p)
	quit()
