## tests/_tmp_v2717_feature_check.gd — v27.17 三件套逻辑断言（boot tscn 模式，autoload 可用）：
## ① hero_archive/memorial 面板经 truck_base._open_panel 可开（.gd 双路径包装）
## ② 归仓气泡：注入 escrow 后 truck_base 气泡层有泡；collect 后清空
## ③ 通用缴获：pick_capture_card_id 兵种过滤回退 + battle_damage_system 掉率/上限常量
## 跑法：godot --headless --path . res://tests/_tmp_v2717_feature_boot.tscn
extends Node

var _fails: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[v2717] PASS: " + msg)
	else:
		_fails.append(msg)
		printerr("[v2717] FAIL: " + msg)

func _ready() -> void:
	await _run()
	print("[v2717] " + ("ALL PASS" if _fails.is_empty() else "FAILS=%d" % _fails.size()))
	await _wait(5)
	get_tree().quit(0 if _fails.is_empty() else 1)

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _run() -> void:
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if mll != null:
		mll.call("ensure_loaded", "drop")
		mll.call("ensure_loaded", "bunker")
	var dm: Node = get_node_or_null("/root/DropManager")
	var DC = load("res://data/default_cards.gd")

	# ── ③ 缴获卡挑选（纯逻辑）──
	_check(dm != null, "DropManager 加载")
	if dm != null:
		var pick_all: String = dm.call("pick_capture_card_id", 1, -1)   # -1 无兵种命中 → 回退全池
		var pick_kind: String = dm.call("pick_capture_card_id", 1, 0)   # 步兵
		_check(not pick_all.is_empty() and DC.get_card_by_id(pick_all) != null,
			"缴获卡 id 兵种过滤回退全池可解析: %s" % pick_all)
		var kind_card = DC.get_card_by_id(pick_kind) if not pick_kind.is_empty() else null
		_check(kind_card != null, "缴获卡 id 兵种命中可解析: %s" % pick_kind)
	var DS = load("res://managers/battle/battle_damage_system.gd")
	var ds = DS.new()
	_check(int(ds.get("GENERIC_CAPTURE_MAX_PER_BATTLE")) == 2, "每场缴获上限=2")
	_check(absf(float(ds.get("GENERIC_CAPTURE_NORMAL_CHANCE")) - 0.02) < 0.0001, "普通缴获率=2%")
	_check(absf(float(ds.get("GENERIC_CAPTURE_ELITE_CHANCE")) - 0.15) < 0.0001, "精英缴获率=15%")

	# ── ① 面板打开 ──
	var tb_scene: PackedScene = load("res://scenes/bunker/truck_base.tscn")
	var tb: Control = tb_scene.instantiate()
	# ⚠️ 采集编排器铁律（AGENTS.md #8）：驱动 _ready 期 root.add_child 撞 Parent busy
	# ——必须 call_deferred；场景挂上后等布局帧再操作
	get_tree().root.add_child.call_deferred(tb)
	await _wait(6)
	await get_tree().create_timer(0.8).timeout

	for pid in ["hero_archive", "memorial"]:
		tb.call("_open_panel", pid)
		await _wait(2)
		var wrappers: Dictionary = tb.get("_embed_wrappers")
		var has_it: bool = wrappers.has(pid)
		var panel_vis: bool = false
		if has_it:
			var p: Control = wrappers[pid]["panel"]
			panel_vis = p != null and is_instance_valid(p) and p.visible
		_check(has_it, "面板包装已建 %s" % pid)
		_check(panel_vis, "面板本体可见 %s" % pid)
		if has_it:
			var p2: Control = wrappers[pid]["panel"]
			if p2.has_signal("closed"):
				p2.emit_signal("closed")
			await _wait(2)

	# ── ② 归仓气泡 ──
	var bubble_layer: Control = tb.get("_bubble_layer")
	_check(bubble_layer != null and is_instance_valid(bubble_layer), "气泡层已建")
	if dm != null and bubble_layer != null:
		if dm.has_method("collect_escrow"):
			dm.call("collect_escrow", [])
		dm.call("generate_battle_drops", 1, 25, true, 3)
		dm.call("claim_drops")
		# 伪造 pending → 归仓
		var DT = load("res://resources/drop_tables.gd")
		var entry = DT.DropEntry.new("alloy", DT.DropType.MATERIAL, 1.0, 5, 5)
		var result = DT.DropResult.new(entry, 5, "测试归仓")
		var pend: Array = dm.get("pending_drops")
		pend.append(result)
		dm.set("pending_drops", pend)
		var moved: int = dm.call("deposit_pending_to_escrow")
		_check(moved > 0, "归仓存入 moved=%d" % moved)
		tb.call("_refresh_reward_bubbles")
		await _wait(2)
		_check(bubble_layer.get_child_count() >= 1, "气泡生成 count=%d" % bubble_layer.get_child_count())
		if bubble_layer.get_child_count() >= 1:
			var bubble: Control = bubble_layer.get_child(0)
			bubble.emit_signal("collected", bubble.get("_categories"))
			await _wait(2)
			await get_tree().create_timer(0.3).timeout
			var total_left: int = dm.call("get_escrow_total_count") if dm.has_method("get_escrow_total_count") else -1
			_check(total_left == 0, "收取后归仓清零 left=%d" % total_left)
