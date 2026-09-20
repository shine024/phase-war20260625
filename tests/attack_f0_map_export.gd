extends SceneTree
## 导出 {archetype_id: 敌方卡图路径} 对——attack_f0 归一管线输入（归一器
## tools/normalize_attack_f0.py 消费；新做攻击姿态资产的工作流见 AGENTS.md 动画部署节）
const MANIFEST := preload("res://data/enemy_unit_manifest.gd")

func _initialize() -> void:
	var out := {}
	for row in MANIFEST.get_entries():
		if row is not Dictionary:
			continue
		var aid := String(row.get("archetype_id", ""))
		if aid.is_empty() or not ResourceLoader.exists("res://assets/effects/unit_anims/%s/attack_f0.png" % aid):
			continue
		var card_p: String = MANIFEST.get_unit_icon_path_for_archetype(aid, false)
		if card_p.is_empty() or not ResourceLoader.exists(card_p):
			continue
		out[aid] = card_p
	var f := FileAccess.open("res://.godot/attack_f0_map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("EXPORTED %d pairs" % out.size())
	quit(0)
