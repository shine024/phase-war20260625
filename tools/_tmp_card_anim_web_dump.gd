extends SceneTree

## 卡图+待机/攻击动画 总审网页 数据导出（headless）
## 用法: Godot --headless --script res://tools/_tmp_card_anim_web_dump.gd
## 输出: res://_anim_review/card_anim_dump.json
## 口径与游戏完全一致:
##   我方卡   = DefaultCards.create_all()（统一表非 enemy_only + 势力专属14张）
##   缴获卡   = UnifiedCardTable.get_enemy_only_entries()（缴获/敌方专属）
##   敌方卡   = EnemyUnitManifest.get_entries()（A-F 全段含星冥）
##   战争平台 = data/json/enemy_phase_platforms.json（相位师出战单位，直以平台 id 出生）
##   卡图     = 我方/缴获: UiAssetLoader.card_icon_path_for；敌方: manifest.get_unit_icon_path_for_archetype
##   动画     = UnitFrameAnim._resolve_key（雪碧图）+ BossIdleAnim 帧 + AttackPoseAnim 攻击帧

const DefaultCards := preload("res://data/default_cards.gd")
const UnifiedCardTable := preload("res://data/unified_card_table.gd")
const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
const GC := preload("res://resources/game_constants.gd")
const UnitFrameAnim := preload("res://scripts/battle/unit_frame_anim.gd")

const ANIM_ROOT := "res://assets/effects/unit_anims/"


func _init() -> void:
	var out := {
		"generated": Time.get_datetime_string_from_system().replace("T", " "),
		"players": [],
		"captured": [],
		"enemies": [],
		"platforms": [],
	}
	for c in DefaultCards.create_all():
		if c == null:
			continue
		out["players"].append(_card_rec(c))
	for entry in UnifiedCardTable.get_enemy_only_entries():
		var card: Resource = UnifiedCardTable.build_card_resource(String(entry.get("card_id", "")))
		if card != null:
			out["captured"].append(_card_rec(card))
	for row in EnemyUnitManifest.get_entries():
		if row is Dictionary:
			out["enemies"].append(_enemy_rec(row))
	out["platforms"] = _platform_recs()

	var dir := DirAccess.open("res://_anim_review")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://_anim_review")
	var f := FileAccess.open("res://_anim_review/card_anim_dump.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("DUMP_OK players=%d captured=%d enemies=%d" % [
		out["players"].size(), out["captured"].size(), out["enemies"].size()])
	quit(0)


## ── 玩家口径卡（我方/缴获共用）─────────────────────────────
func _card_rec(c: Resource) -> Dictionary:
	var id := String(c.get("card_id"))
	var rec := {
		"id": id,
		"name": String(c.get("display_name")),
		"era": int(c.get("era")),
		"kind": int(c.get("combat_kind")),
		"ctype": int(c.get("card_type")),
		"icon": String(UiAssetLoader.card_icon_path_for(c)),
	}
	_fill_anim(rec, id)
	return rec


## ── 敌方口径卡 ────────────────────────────────────────────
func _enemy_rec(row: Dictionary) -> Dictionary:
	var aid := String(row.get("archetype_id", ""))
	var cfg: Dictionary = row.get("archetype_config", {})
	var rec := {
		"id": aid,
		"name": String(row.get("display_name", "")),
		"era": int(cfg.get("era", row.get("era", -1))),
		"kind": int(cfg.get("combat_kind", -1)),
		"ctype": -1,
		"visual_id": String(row.get("visual_id", "")),
		"icon": String(EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, false)),
		"icon_player": String(EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, true)),
	}
	# 战场 anim_id = card.card_id（foe_ 前缀）或裸 archetype_id——两个都解析，分叉即记录
	_fill_anim(rec, aid)
	return rec


## ── 相位师战争平台（enemy_phase_platforms.json 直读，id 即出战 anim_id）──
func _platform_recs() -> Array:
	var out: Array = []
	var txt := FileAccess.get_file_as_string("res://data/json/enemy_phase_platforms.json")
	var parsed: Variant = JSON.parse_string(txt)
	var data: Dictionary = {}
	if parsed is Dictionary:
		data = parsed.get("data", {})
	for pid in data.keys():
		var cfg: Dictionary = data.get(pid, {})
		var rec := {
			"id": String(pid),
			"name": String(cfg.get("name", "")),
			"era": -2,
			"kind": -1,
			"ctype": -1,
			"faction": String(cfg.get("faction", "")),
			"icon": "",  # 平台无独立卡图，页面展示其动画解析结果
		}
		_fill_anim(rec, String(pid))
		out.append(rec)
	return out


## ── 动画三体系解析（雪碧图 / boss 逐帧 / 攻击姿态帧）──────────
func _fill_anim(rec: Dictionary, id: String) -> void:
	# 1) 雪碧图（UnitFrameAnim 主路）
	var key := UnitFrameAnim._resolve_key(id)
	rec["anim_key"] = key
	if not key.is_empty():
		var meta: Dictionary = UnitFrameAnim._load_json(ANIM_ROOT + key + "/anim.json")
		var counts: Dictionary = meta.get("counts", {})
		rec["anim"] = {
			"fps": float(meta.get("fps", 8.0)),
			"fs": int(meta.get("frame_size", 256)),
			"idle": int(counts.get("idle", 0)),
			"attack": int(counts.get("attack", 0)),
			"sheet_idle": ANIM_ROOT + key + "/sheet_idle.png",
			"sheet_attack": ANIM_ROOT + key + "/sheet_attack.png",
		}
	# 2) boss 逐帧待机（BossIdleAnim._load_frames 同口径: idle_f0..7 直查目录）
	rec["boss_frames"] = 0
	rec["boss_dir"] = ""
	var bn := _boss_frame_count(id)
	if bn > 0:
		rec["boss_frames"] = bn
		rec["boss_dir"] = id
	elif id.begins_with("captured_"):
		var vis_fb: String = EnemyUnitManifest.visual_id_for_archetype(id.trim_prefix("captured_"))
		if not vis_fb.is_empty() and vis_fb != id:
			bn = _boss_frame_count(vis_fb)
			if bn > 0:
				rec["boss_frames"] = bn
				rec["boss_dir"] = vis_fb
	# 3) 攻击姿态帧（AttackPoseAnim: attack_f0 + 可选 f1）
	rec["pose_frames"] = _pose_frame_count(id)
	rec["pose_dir"] = id if rec["pose_frames"] > 0 else ""


func _boss_frame_count(dir_id: String) -> int:
	var n := 0
	for i in range(8):
		if ResourceLoader.exists(ANIM_ROOT + dir_id + "/idle_f%d.png" % i):
			n += 1
		else:
			break
	return n


func _pose_frame_count(dir_id: String) -> int:
	var n := 0
	for i in range(2):
		if ResourceLoader.exists(ANIM_ROOT + dir_id + "/attack_f%d.png" % i):
			n += 1
		else:
			break
	return n
