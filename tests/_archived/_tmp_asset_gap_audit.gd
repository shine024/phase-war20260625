extends SceneTree
## tests/_tmp_asset_gap_audit.gd — 2026-09-03 资产缺口综合审计
## 覆盖三类运行时动态解析资产：
##   1) manifest 全条目敌方卡图（for_player=false → enemy/ 目录）
##   2) 符文图标（icon_path_for 跨稀有度回退链）
##   3) 相位仪图标（全 pi_id → assets/ui/instruments/{id}.png + _thumb128）
## 运行：Godot --headless --rendering-driver opengl3 --path . -s res://tests/_tmp_asset_gap_audit.gd

const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
const Runes := preload("res://data/runes.gd")
const PhaseInstruments := preload("res://data/phase_instruments.gd")

func _initialize() -> void:
	var fails: int = 0

	# ── 1) manifest 敌方卡图 ──
	var entries: Array = EnemyUnitManifest.get_entries()
	var no_icon: Array = []
	for row in entries:
		var aid: String = String(row.get("archetype_id", row.get("id", "")))
		var p: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, false)
		if p.is_empty() or not ResourceLoader.exists(p):
			no_icon.append("%s -> %s" % [aid, p])
	print("[MANIFEST] entries=%d  missing_enemy_icon=%d" % [entries.size(), no_icon.size()])
	for l in no_icon:
		print("  MISS " + l)
	fails += no_icon.size()

	# ── 2) 符文图标 ──
	var rune_ids: Array[String] = Runes.get_all_ids()
	var rune_miss: Array = []
	var rune_thumb_miss: Array = []
	for rid in rune_ids:
		var ip: String = Runes.icon_path_for(rid)
		if ip.is_empty():
			rune_miss.append(rid)
		else:
			var thumb: String = "res://assets/runes/_thumb128/" + ip.substr("res://assets/runes/".length())
			if not ResourceLoader.exists(thumb):
				rune_thumb_miss.append("%s (%s)" % [rid, ip.get_file().get_basename()])
	print("[RUNES] ids=%d  missing_icon=%d  missing_thumb128=%d" % [rune_ids.size(), rune_miss.size(), rune_thumb_miss.size()])
	for l in rune_miss:
		print("  MISS_ICON " + l)
	for l in rune_thumb_miss:
		print("  MISS_THUMB " + l)
	fails += rune_miss.size()

	# ── 3) 相位仪图标 ──
	var inst_ids: Array = []
	for d in PhaseInstruments.get_all():
		var iid: String = String(d.get("id", ""))
		if not iid.is_empty() and not inst_ids.has(iid):
			inst_ids.append(iid)
	var inst_miss: Array = []
	var inst_thumb_miss: Array = []
	for iid in inst_ids:
		var full: String = "res://assets/ui/instruments/%s.png" % iid
		if not ResourceLoader.exists(full):
			inst_miss.append(iid)
			continue
		var th: String = "res://assets/ui/instruments/_thumb128/%s.png" % iid
		if not ResourceLoader.exists(th):
			# 128x128 小图无需缩略图（回退等价），只对 1024 大图报缺
			var t: Texture2D = load(full) as Texture2D
			if t != null and t.get_width() > 256:
				inst_thumb_miss.append(iid)
	print("[INSTRUMENTS] ids=%d  missing_icon=%d  missing_thumb128(1024 only)=%d" % [inst_ids.size(), inst_miss.size(), inst_thumb_miss.size()])
	for l in inst_miss:
		print("  MISS_ICON " + l)
	for l in inst_thumb_miss:
		print("  MISS_THUMB " + l)

	print("==== asset gap audit done, hard fails=%d ====" % fails)
	quit(0)
