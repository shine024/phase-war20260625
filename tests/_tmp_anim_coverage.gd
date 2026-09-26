extends SceneTree
## 记录4 美术盘点（终版口径）：战斗 anim_id 全集 = UCT 全卡 id ∪ manifest 各段可视 id，
## 全部过 UnitFrameAnim._resolve_key 真身。输出最终未覆盖名单。

const UCT = preload("res://data/unified_card_table.gd")
const UFA = preload("res://scripts/battle/unit_frame_anim.gd")
const Manifest = preload("res://data/enemy_unit_manifest.gd")

func _init() -> void:
	var all: Dictionary = {}
	for cid in UCT.get_all_card_ids():
		all[String(cid)] = true
	for vid in Manifest.FOE_PLATFORM_CARD_IDS:
		all[String(vid)] = true
	for vid in Manifest.FOE_SPECIAL_CARD_IDS:
		all[String(vid)] = true
	for vid in Manifest.CAPTURED_ENEMY_IDS:
		all[String(vid)] = true
	for vid in Manifest.FORT_ENEMY_IDS:
		all[String(vid)] = true
	for vid in Manifest.FIXED_ENEMY_IDS:
		all[String(vid)] = true
	for vid in Manifest.POOL_ENEMY_IDS:
		all[String(vid)] = true
	var covered: Array[String] = []
	var uncovered: Array[String] = []
	for id in all.keys():
		if String(UFA._resolve_key(String(id))).is_empty():
			uncovered.append(String(id))
		else:
			covered.append(String(id))
	print("ANIMFINAL total=%d covered=%d uncovered=%d" % [all.size(), covered.size(), uncovered.size()])
	uncovered.sort()
	print("ANIMFINAL uncovered=", str(uncovered))
	quit(0)
