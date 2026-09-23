extends SceneTree
## tests/_tmp_art_audit_task21.gd — 2026-09-22 美术资产质检计划 Task 2.1
## 相位仪图标存在性与引用完整性：
##   1) 以 PhaseInstruments.get_all() 为权威 id 清单，核对主图 + _thumb128 缩略图双向在位
##   2) 反向扫目录找孤儿图（有图无定义——候选孤儿，后续用代码引用 grep 定性）
##   3) 核销 P2-1 挂账 4 张缺口（pi_r_free_deploy、pi_umbra_01~03）
## 证据：tests/evidence/art_audit_2026-09-22/task21_instrument_refs.json
## 运行：Godot --headless --rendering-driver opengl3 --path . -s res://tests/_tmp_art_audit_task21.gd

const PhaseInstruments := preload("res://data/phase_instruments.gd")

const MAIN_DIR := "res://assets/ui/instruments"
const THUMB_DIR := "res://assets/ui/instruments/_thumb128"
const OUT_PATH := "res://tests/evidence/art_audit_2026-09-22/task21_instrument_refs.json"

func _list_pngs(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while not f.is_empty():
		if not d.current_is_dir() and f.ends_with(".png"):
			out.append(f.get_basename())
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _initialize() -> void:
	var defs := PhaseInstruments.get_all()
	var ids: Array = []
	for def in defs:
		ids.append(String(def.get("id", "")))
	ids.sort()
	print("定义相位仪数: %d" % ids.size())

	var id_set: Dictionary = {}
	for i in ids:
		id_set[i] = true

	var main_pngs := _list_pngs(MAIN_DIR)
	var thumb_pngs := _list_pngs(THUMB_DIR)
	print("主图 %d 张 | 缩略图 %d 张" % [main_pngs.size(), thumb_pngs.size()])

	var missing_main: Array = []
	var missing_thumb: Array = []
	for i in ids:
		if not main_pngs.has(i):
			missing_main.append(i)
		if not thumb_pngs.has(i):
			missing_thumb.append(i)

	var orphan_main: Array = []
	for p in main_pngs:
		if not id_set.has(p):
			orphan_main.append(p)
	var orphan_thumb: Array = []
	for p in thumb_pngs:
		if not id_set.has(p):
			orphan_thumb.append(p)

	var gaps_pending := ["pi_r_free_deploy", "pi_umbra_01", "pi_umbra_02", "pi_umbra_03"]
	var gaps_status: Dictionary = {}
	for g in gaps_pending:
		gaps_status[g] = {
			"in_definitions": id_set.has(g),
			"main_png": main_pngs.has(g),
			"thumb_png": thumb_pngs.has(g),
		}

	var payload := {
		"date": "2026-09-22",
		"defined_instruments": ids.size(),
		"main_png_count": main_pngs.size(),
		"thumb_png_count": thumb_pngs.size(),
		"missing_main": missing_main,
		"missing_thumb": missing_thumb,
		"orphan_main": orphan_main,
		"orphan_thumb": orphan_thumb,
		"pending_gaps_status": gaps_status,
	}
	var jf := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	jf.store_string(JSON.stringify(payload, "  ", false))
	jf.close()

	print("缺主图: %d %s" % [missing_main.size(), str(missing_main)])
	print("缺缩略图: %d %s" % [missing_thumb.size(), str(missing_thumb)])
	print("孤儿主图: %d %s" % [orphan_main.size(), str(orphan_main)])
	print("孤儿缩略图: %d %s" % [orphan_thumb.size(), str(orphan_thumb)])
	print("挂账 4 缺口: ")
	for g in gaps_pending:
		print("  %s -> %s" % [g, str(gaps_status[g])])
	print("TASK21_OK")
	quit(0)
