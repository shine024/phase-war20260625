extends SceneTree
## 导出开火+缩放工作台数据（docs/fire_scale_studio.html 的数据源）
## 从运行时真表导出全部单位：id/侧/时代/兵种/图标路径/开火锚点/内容占比/ff-hf
## HTML 端用同套公式算战场预览（内容宽归一 × 兵种×时代档位 × override）。
## 跑法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_export_fire_scale_data.gd
## 卡图或锚点表改动后重跑本脚本刷新 docs/fire_scale_data.js。

const PlayerMuzzleAnchors = preload("res://data/player_muzzle_anchors.gd")
const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const GC = preload("res://resources/game_constants.gd")


func _initialize() -> void:
	var units: Array = []
	# ── 我方（含 fe_）
	for c in DefaultCards.create_all():
		if c == null or int(c.card_type) != int(GC.CardType.COMBAT_UNIT):
			continue
		var id := String(c.card_id)
		var icon: String = UiAssetLoader.card_icon_path_for(c)
		var base: String = String(icon).get_file().get_basename()
		var anchor: Dictionary = PlayerMuzzleAnchors.get_anchor(id)
		units.append({
			"side": "P", "id": id,
			"era": int(c.era), "kind": int(c.combat_kind),
			"icon": _rel(icon),
			"wf": CardFootAnchors.get_content_w_frac(base),
			"hf": CardFootAnchors.get_head_frac(base),
			"ff": CardFootAnchors.get_foot_frac(base),
			"fx": float(anchor.get("fireX", -1.0)) if anchor.has("fireX") else null,
			"fy": float(anchor.get("fireY_pct", -1.0)) if anchor.has("fireY_pct") else null,
			"ff_tbl": float(anchor.get("ff", -1.0)) if anchor.has("ff") else null,
		})
	# ── 敌方（manifest 全段）
	for row in EnemyUnitManifest.get_entries():
		var id := String(row.get("archetype_id", ""))
		if id.is_empty():
			continue
		var icon: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(id, false)
		var base: String = String(icon).get_file().get_basename()
		var anchor: Dictionary = MuzzleAnchors.get_anchor(id)
		var cfg: Dictionary = row.get("archetype_config", {})
		units.append({
			"side": "E", "id": id,
			"era": int(row.get("era", -1)), "kind": int(cfg.get("combat_kind", -1)),
			"icon": _rel(icon),
			"wf": CardFootAnchors.get_content_w_frac(base),
			"hf": CardFootAnchors.get_head_frac(base),
			"ff": CardFootAnchors.get_foot_frac(base),
			"fx": float(anchor.get("fireX", -1.0)) if anchor.has("fireX") else null,
			"fy": float(anchor.get("fireY_pct", -1.0)) if anchor.has("fireY_pct") else null,
			"ff_tbl": null,
		})
	var ke := {}
	for k in CardFootAnchors.KIND_ERA_SCALE:
		var row_d: Dictionary = CardFootAnchors.KIND_ERA_SCALE[k]
		var arr := []
		for e in range(5):
			arr.append(float(row_d.get(e, 1.0)))
		ke[str(k)] = arr
	var data := {
		"ver": Time.get_datetime_string_from_system().replace("T", " "),
		"base_w": CardGridBattleLayoutConst(),
		"kind_era": ke,
		"units": units,
	}
	var f := FileAccess.open("res://docs/fire_scale_data.js", FileAccess.WRITE)
	f.store_string("// 由 tests/_tmp_export_fire_scale_data.gd 自动生成，勿手改；重跑导出器刷新\nwindow.PW_DATA = " + JSON.stringify(data) + ";\n")
	f.close()
	print("EXPORT_DONE units=%d -> docs/fire_scale_data.js" % units.size())
	quit(0)


func CardGridBattleLayoutConst() -> float:
	var lay := load("res://scripts/card_grid_battle_layout.gd")
	return float(lay.BASE_CARD_WIDTH_PX)


func _rel(path: String) -> String:
	var p := String(path)
	if p.begins_with("res://"):
		p = "../" + p.substr(6)
	return p
