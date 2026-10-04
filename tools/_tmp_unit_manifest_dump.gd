extends SceneTree

## 单位统一清单（敌我全量·含黑门）数据导出（headless）
## 用法: Godot --headless --script res://tools/_tmp_unit_manifest_dump.gd
## 输出: res://_anim_review/unit_manifest_full.json
## 口径:
##   敌方 = EnemyUnitManifest.get_entries()（A/B/C/D/E 段 + F 段星冥·黑门本体）
##   我方 = DefaultCards.create_all()（统一表非 enemy_only + 势力专属）
##   缴获 = UnifiedCardTable.get_enemy_only_entries()
##   战争平台 = data/json/enemy_phase_platforms.json
##   立绘 = manifest.get_unit_icon_path_for_archetype(aid, for_player) / UiAssetLoader.card_icon_path_for
##   动画 = UnitFrameAnim._resolve_key（雪碧图）+ BossIdleAnim 帧数 + AttackPoseAnim 帧数

const DefaultCards := preload("res://data/default_cards.gd")
const UnifiedCardTable := preload("res://data/unified_card_table.gd")
const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const XenoUnits := preload("res://data/xeno_units.gd")
const UnitFrameAnim := preload("res://scripts/battle/unit_frame_anim.gd")
const EnemyCardModMap := preload("res://data/enemy_card_mod_map.gd")

const ANIM_ROOT := "res://assets/effects/unit_anims/"


func _init() -> void:
	var out := {
		"generated": Time.get_datetime_string_from_system().replace("T", " "),
		"players": [],
		"captured": [],
		"enemies": [],
		"platforms": [],
	}
	for row in EnemyUnitManifest.get_entries():
		if row is Dictionary:
			out["enemies"].append(_enemy_rec(row))
	for c in DefaultCards.create_all():
		if c == null:
			continue
		out["players"].append(_card_rec(c))
	for entry in UnifiedCardTable.get_enemy_only_entries():
		var card: Resource = UnifiedCardTable.build_card_resource(String(entry.get("card_id", "")))
		if card != null:
			out["captured"].append(_card_rec(card))
	out["platforms"] = _platform_recs()

	var dir := DirAccess.open("res://_anim_review")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://_anim_review")
	var f := FileAccess.open("res://_anim_review/unit_manifest_full.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("DUMP_OK enemies=%d players=%d captured=%d platforms=%d" % [
		out["enemies"].size(), out["players"].size(),
		out["captured"].size(), out["platforms"].size()])
	quit(0)


## ── 段位判定（与 manifest 常量表逐一对照）──────────────────
func _segment(aid: String) -> String:
	if aid.begins_with("foe_"):
		var base := aid.trim_prefix("foe_")
		if EnemyUnitManifest.FOE_PLATFORM_CARD_IDS.has(base):
			return "A"
		if EnemyUnitManifest.FOE_SPECIAL_CARD_IDS.has(base):
			return "B"
	if EnemyUnitManifest.FIXED_ENEMY_IDS.has(aid):
		return "C"
	if EnemyUnitManifest.POOL_ENEMY_IDS.has(aid):
		return "D"
	if EnemyUnitManifest.FORT_ENEMY_IDS.has(aid):
		return "E"
	if aid.begins_with("xeno_"):
		return "F"
	return "?"


## ── 敌方（manifest 行）────────────────────────────────────
func _enemy_rec(row: Dictionary) -> Dictionary:
	var aid := String(row.get("archetype_id", ""))
	var cfg: Dictionary = row.get("archetype_config", {})
	var name := String(row.get("display_name", ""))
	if name.is_empty():
		name = String(cfg.get("display_name", ""))
	if name.is_empty():
		name = String(EnemyArchetypes.get_config(aid).get("display_name", ""))
	var seg := _segment(aid)
	var role := ""
	var power := 0
	if seg == "F":
		var x: Dictionary = XenoUnits.get_config(aid)
		role = String(x.get("role", ""))
		power = int(x.get("power", 0))
	var rec := {
		"id": aid,
		"name": name,
		"era": int(cfg.get("era", row.get("era", -1))),
		"kind": int(cfg.get("combat_kind", -1)),
		"seg": seg,
		"role": role,
		"power": power,
		"drop": float(row.get("drop_chance", 0.0)),
		"drop_card_id": String(row.get("drop_card_id", "")),
		"visual_id": String(row.get("visual_id", "")),
		"icon": String(EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, false)),
		"icon_player": String(EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, true)),
	}
	# 特色掉落（敌方 JSON cfg.drops 里的非 captured 卡，如 drop_smg_mk2）
	var specials: Array = []
	var merged_cfg: Dictionary = EnemyArchetypes.get_config(aid)
	for dv in merged_cfg.get("drops", []):
		if dv is Dictionary:
			var did := String(dv.get("card_id", ""))
			if not did.is_empty() and not did.begins_with("captured_"):
				specials.append(did)
	if not specials.is_empty():
		rec["special_drops"] = specials
	_fill_anim(rec, _probe_ids(aid, String(row.get("visual_id", ""))))
	return rec


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
	var vid := ""
	if id.begins_with("captured_"):
		var vis_fb: String = EnemyUnitManifest.visual_id_for_archetype(id.trim_prefix("captured_"))
		if not vis_fb.is_empty() and vis_fb != id:
			vid = vis_fb
	_fill_anim(rec, _probe_ids(id, vid))
	return rec


## ── 相位师战争平台 ────────────────────────────────────────
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
			"icon": "",
		}
		_fill_anim(rec, _probe_ids(String(pid)))
		out.append(rec)
	return out


## ── 动画三体系解析 ───────────────────────────────────────
## probe_ids: 依次尝试的目录/id 列表（雪碧图走 _resolve_key，boss/pose 直接查目录）
func _fill_anim(rec: Dictionary, probe_ids: Array) -> void:
	var key := ""
	for pid in probe_ids:
		key = UnitFrameAnim._resolve_key(String(pid))
		if not key.is_empty():
			break
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
	rec["boss_frames"] = 0
	rec["boss_dir"] = ""
	rec["pose_frames"] = 0
	rec["pose_dir"] = ""
	for pid in probe_ids:
		var bn := _boss_frame_count(String(pid))
		if bn > 0:
			rec["boss_frames"] = bn
			rec["boss_dir"] = String(pid)
			break
	for pid in probe_ids:
		var pn := _pose_frame_count(String(pid))
		if pn > 0:
			rec["pose_frames"] = pn
			rec["pose_dir"] = String(pid)
			break
	rec["anim_cands"] = _anim_cands(probe_ids)


## 候选动画目录全集：解析链逐站探测（含被遮蔽者），供总审网页「选哪套动画」按钮
func _anim_cands(probe_ids: Array) -> Array:
	var cands: Array = []
	for pid in probe_ids:
		_cand_push(cands, String(pid))
		_cand_push(cands, String(pid).trim_prefix("foe_"))
		_cand_push(cands, String(EnemyCardModMap.get_player_card_id(String(pid))))
		_cand_push(cands, String(EnemyUnitManifest.visual_id_for_archetype(String(pid).trim_prefix("captured_"))))
		_cand_push(cands, String(UnitFrameAnim.ANIM_ALIAS.get(String(pid), "")))
	return cands


func _cand_push(cands: Array, c: String) -> void:
	if c.is_empty():
		return
	if not ResourceLoader.exists(ANIM_ROOT + c + "/sheet_idle.png") \
			or not ResourceLoader.exists(ANIM_ROOT + c + "/anim.json"):
		return
	for x in cands:
		if String(x.get("key", "")) == c:
			return
	var meta: Dictionary = UnitFrameAnim._load_json(ANIM_ROOT + c + "/anim.json")
	var counts: Dictionary = meta.get("counts", {})
	cands.append({
		"key": c,
		"fps": float(meta.get("fps", 8.0)),
		"fs": int(meta.get("frame_size", 256)),
		"idle": int(counts.get("idle", 0)),
		"attack": int(counts.get("attack", 0)),
		"sheet_idle": ANIM_ROOT + c + "/sheet_idle.png",
		"sheet_attack": ANIM_ROOT + c + "/sheet_attack.png",
	})


## 探测 id 列表：本名 → 去 foe_ → 视觉id（敌方）；缴获卡附视觉回退
func _probe_ids(id: String, visual_id := "") -> Array:
	var out: Array = []
	for pid in [id, id.trim_prefix("foe_"), visual_id]:
		var s := String(pid)
		if not s.is_empty() and not out.has(s):
			out.append(s)
	return out


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
