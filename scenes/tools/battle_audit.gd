extends Node

## ============================================================
## 战斗画面审计 (Phase 2) — 真实战斗自动截图
## 实例化 main.tscn → 按目标时代给绿槽装战斗卡 → 调 main 的
## world_map 挂机入口(_auto_start_afk_from_world_map)自动布阵开打
## → 定时截屏,写 user://battle_shots/ + manifest.json。
##
## 截图计划(每关 6 张):
##   formation  开战初期(阵型+背景同屏)
##   engage     交火峰值(弹道+命中满屏)
##   engage_b   交火+0.5s(与 engage 对比 → 单位待机动效验证:除子弹/VFX外单位本体动没动)
##   mid        中盘(战况胶着)
##   late       尾盘(焦痕/尸体/清场)
##   end        收官
##
## 用法:
##   godot --path . res://scenes/tools/battle_audit.tscn -- level=5
## 关卡→时代: 1-20一战 / 21-40二战 / 41-60冷战 / 61-80现代 / 81-100近未来
## 注意: 会走真实存档的 AFK 推图流程,跑之前备份 user://save.json。
## ============================================================

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUT_DIR := "user://battle_shots/"

const CAPTURE_PLAN := [
	{"delay": 2.0, "tag": "formation"},
	{"delay": 9.0, "tag": "engage"},
	{"delay": 9.5, "tag": "engage_b"},
	{"delay": 22.0, "tag": "mid"},
	{"delay": 45.0, "tag": "late"},
	{"delay": 70.0, "tag": "end"},
]
const QUIT_AFTER := 75.0

var _level: int = 5
var _era: int = 0
var _shots: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			_level = clampi(int(a.substr(6)), 1, 100)
	_era = GC.get_era_for_level(_level)
	var d := DirAccess.open("user://")
	if d != null:
		d.make_dir_recursive("battle_shots")
	print("[BattleAudit] level=%d era=%s(%d)" % [_level, GC.get_era_name(_era), _era])
	var main_node: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main_node)
	# 等 main._ready(autoload 已就绪、存档槽位已恢复)完成再动槽位
	await get_tree().process_frame
	await get_tree().process_frame
	var equipped: int = _equip_era_deck()
	print("[BattleAudit] equipped %d era combat cards into green slots" % equipped)
	# 手动驱动 AFK(不走 world_map 入口): 存档异步未加载完时其解锁钳制会把
	# 目标关压回 1,故 start_afk 后直写 _pending_level 再开打,确保目标关生效。
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("set_current_level"):
		gm.call("set_current_level", _level)
	var afk: RefCounted = main_node.get("_afk_manager")
	if afk == null:
		push_error("[BattleAudit] main._afk_manager 不存在,无法自动布阵")
		get_tree().quit()
		return
	afk.set_mode(1)  # Mode.PUSH
	afk.set("push_level", _level)
	afk.call("start_afk")
	afk.set("_pending_level", _level)
	afk.call("enter_next_battle")
	print("[BattleAudit] afk battle started at level=%d" % _level)
	# 挂机入口内部有 call_deferred 链,给 1s 稳定期再开始计时截屏
	await get_tree().create_timer(1.0).timeout
	for cap in CAPTURE_PLAN:
		_shot_at(float(cap["delay"]), String(cap["tag"]))
	await get_tree().create_timer(QUIT_AFTER).timeout
	_write_manifest()
	print("[BattleAudit] done: %d shots" % _shots.size())
	get_tree().quit()


## 按目标时代挑战斗卡装满绿槽: combat_kind 轮转取,保证兵种多样性(步/甲/炮/防空/空)。
## 绿槽扁平索引 = red + blue 槽数(槽序 red,blue,green,yellow,rune)。
func _equip_era_deck() -> int:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null:
		push_error("[BattleAudit] PhaseInstrumentManager 不存在")
		return 0
	var counts: Dictionary = {}
	if pim.has_method("get_current_instrument"):
		counts = pim.get_current_instrument().get("slot_counts", {})
	var green_off: int = int(counts.get("red", 0)) + int(counts.get("blue", 0))
	var green_cnt: int = int(counts.get("green", 0))
	if green_cnt <= 0:
		push_error("[BattleAudit] 当前相位仪绿槽数为 0")
		return 0
	# 按兵种分组收集本时代战斗卡,每组内按 power 降序(取各组最强,火力足)
	var by_kind: Dictionary = {}
	for id in DefaultCards.get_all_blueprint_ids():
		var c: CardResource = DefaultCards.get_card_by_id(String(id))
		if c == null or c.card_type != GC.CardType.COMBAT_UNIT or c.era != _era:
			continue
		var kind: int = c.combat_kind
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(c)
	var pool: Array = []
	for kind in by_kind:
		var arr: Array = by_kind[kind]
		arr.sort_custom(func(a, b): return a.power > b.power)
		pool.append(arr[0])
	# 兜底: 若兵种不够填满绿槽,补同时代其他强力卡
	if pool.size() < green_cnt:
		var extra: Array = []
		for kind in by_kind:
			for i in range(1, by_kind[kind].size()):
				extra.append(by_kind[kind][i])
		extra.sort_custom(func(a, b): return a.power > b.power)
		for c in extra:
			if pool.size() >= green_cnt:
				break
			pool.append(c)
	var ok_count: int = 0
	for i in range(mini(green_cnt, pool.size())):
		if pim.has_method("equip_card") and pim.call("equip_card", green_off + i, pool[i]):
			ok_count += 1
	return ok_count


func _shot_at(delay: float, tag: String) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var fname := "lvl%02d_%s.png" % [_level, tag]
	img.save_png(OUT_DIR + fname)
	_shots.append({"file": fname, "tag": tag, "level": _level, "era": GC.get_era_name(_era)})
	print("[BattleAudit] shot %s" % fname)


func _write_manifest() -> void:
	var f := FileAccess.open(OUT_DIR + "manifest.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"level": _level, "era": GC.get_era_name(_era), "shots": _shots}, "\t"))
	f.close()
