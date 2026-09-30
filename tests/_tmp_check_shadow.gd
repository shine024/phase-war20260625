extends SceneTree
## 临时检查：6 个 f0 升级单位的 fallback 解析链——若绕过直连目录后仍能解析出
## 其他真实动画目录，说明新目录遮蔽了既有动画，需要逐单位裁决。

func _initialize() -> void:
	var uf := load("res://scripts/battle/unit_frame_anim.gd")
	var ecm := load("res://data/enemy_card_mod_map.gd")
	var m := load("res://data/enemy_unit_manifest.gd")
	var mi: Object = m.new()
	var ids := ["cold_inf_ak", "cold_inf_spetsnaz_e", "fut_inf_cyborg", "fut_inf_spectre_e",
			"mod_inf_delta_e", "mod_inf_marine"]
	for id in ids:
		var via_map := String(ecm.call("get_player_card_id", id))
		var via_vis := String(mi.call("visual_id_for_archetype", id))
		var alias := ""
		if uf.get("ANIM_ALIAS") != null:
			var tbl: Dictionary = uf.get("ANIM_ALIAS")
			alias = String(tbl.get(id, ""))
		var now := String(uf.call("_resolve_key", id))
		print("UNIT %s | map->%s | vis->%s | alias->%s | now-resolve->%s" % [id, via_map, via_vis, alias, now])
	quit(0)
