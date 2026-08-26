# 无 GdUnit 依赖的快速校验：v20.x 限定兵种关修复回归
#   - restrict_platforms 白名单 × combat_kind 放行/拦截语义（用 DefaultCards 真实卡对象）
#   - CardResource.platform_type == combat_kind 不变量（UCT 模板 + clone 实例两路径）
#   - 战场缩放兜底 0-4 键按兵种语义重映射（装甲>1.2/空中>1.0，防 legacy 撞值回退）
# 背景：v8.0 UCT 切数据源漏设 platform_type + clone() 漏拷，全卡恒 -1，
#   第 15/30/55/85 关 restrict_platforms 白名单判定全拦（"本关限定兵种"误伤全部兵种）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/restrict_levels_card_kind_smoke.gd
extends SceneTree

const LevelInformation = preload("res://data/level_information.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const CardResource = preload("res://resources/card_resource.gd")


func _initialize() -> void:
	# 失败标志用 Dictionary（引用类型）：GDScript lambda 按值捕获局部变量，
	# `var code := 0` + lambda 内赋值写不回外部（首版测试因此 14 卡失败仍报 ALL PASS）。
	var st := {"code": 0}
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		st["code"] = 1

	var li := LevelInformation.new()
	var restrict_map: Dictionary = {15: [0], 30: [1], 55: [2, 3], 85: [2]}

	# ══════════ 1. 真实卡对象 × 白名单放行/拦截语义 ══════════
	print("=== 限定兵种关 × 真实卡 combat_kind 判定 ===")
	var combat_cards: Array = []
	for cid in DefaultCards.get_all_blueprint_ids():
		var c = DefaultCards.get_card_by_id(String(cid))
		if c != null and c.card_type == GC.CardType.COMBAT_UNIT:
			combat_cards.append(c)
	if combat_cards.is_empty():
		fail.call("DefaultCards 无战斗卡（缓存构建失败？）")
	# 按兵种各取样一张（优先非 enemy_only 掉落卡）
	var sample_by_kind: Dictionary = {}
	for c in combat_cards:
		var ck: int = int(c.combat_kind)
		if not sample_by_kind.has(ck) or (not bool(c.is_dropped_card) and bool(sample_by_kind[ck].is_dropped_card)):
			sample_by_kind[ck] = c
	for kind in range(5):
		if not sample_by_kind.has(kind):
			fail.call("缺 combat_kind=%d 的样例卡" % kind)
	for lv in restrict_map.keys():
		var restrict: Array = li.get_special_rules(int(lv)).get("restrict_platforms", [])
		for kind in range(5):
			if not sample_by_kind.has(kind):
				continue
			var card = sample_by_kind[kind]
			# 模拟修复后的 battle_spawn_system / bottom_instrument_bar 判定（读 combat_kind）
			var allowed: bool = restrict.is_empty() or restrict.has(int(card.combat_kind))
			var expect_allowed: bool = restrict.has(kind)
			if allowed != expect_allowed:
				fail.call("第%d关 kind=%d 卡 %s 放行=%s 期望=%s" % [int(lv), kind, card.card_id, str(allowed), str(expect_allowed)])
		print("  第%d关 白名单=%s × 5 兵种判定 ✓" % [int(lv), str(restrict)])

	# ══════════ 2. platform_type == combat_kind 不变量（模板路径） ══════════
	print("=== platform_type == combat_kind 不变量（UCT 模板） ===")
	var bad_tpl: int = 0
	for c in combat_cards:
		if int(c.platform_type) != int(c.combat_kind):
			bad_tpl += 1
			if bad_tpl <= 5:
				push_error("  模板 %s platform_type=%d != combat_kind=%d" % [c.card_id, int(c.platform_type), int(c.combat_kind)])
	if bad_tpl > 0:
		fail.call("%d 张模板卡 platform_type != combat_kind" % bad_tpl)
	else:
		print("  全部 %d 张战斗卡模板不变量成立 ✓" % combat_cards.size())

	# ══════════ 3. clone() 不变量（实例路径——部署判定读的就是实例卡） ══════════
	print("=== clone() 保序 platform_type（实例路径） ===")
	var bad_clone: int = 0
	var checked: int = 0
	for kind in sample_by_kind.keys():
		var src = sample_by_kind[kind]
		var cl = src.clone()
		checked += 1
		if int(cl.platform_type) != int(src.combat_kind):
			bad_clone += 1
			push_error("  clone(%s) platform_type=%d != combat_kind=%d" % [src.card_id, int(cl.platform_type), int(src.combat_kind)])
	if bad_clone > 0:
		fail.call("%d/%d 张 clone 卡 platform_type 失序" % [bad_clone, checked])
	else:
		print("  %d 兵种样例 clone 不变量成立 ✓" % checked)

	# ══════════ 4. 战场缩放兜底 0-4 键语义（v20.x 重映射回归锁） ══════════
	print("=== 缩放兜底 0-4 键兵种语义 ===")
	# 期望区间（按兵种体量）：轻装小 / 装甲·堡垒大 / 空中·支援中
	var scale_range: Dictionary = {0: [0.5, 0.95], 1: [1.2, 1.8], 2: [0.6, 1.05], 3: [1.0, 1.5], 4: [1.2, 1.8]}
	for kind in scale_range.keys():
		var rep: String = String(CardFootAnchors.PLAYER_PLATFORM_TO_SCALE_ARCHETYPE.get(kind, ""))
		if rep.is_empty():
			fail.call("缩放兜底表缺 %d 键" % kind)
			continue
		# 代表 id 必须能解析出非默认缩放（防代表 id 拼错静默回退 1.0）
		var rep_scale: float = CardFootAnchors.get_visual_scale_by_id(rep)
		if rep_scale <= 0.0 or is_equal_approx(rep_scale, 1.0):
			fail.call("kind=%d 代表 %s 未在 VISUAL_SCALE 解析（%.2f）" % [kind, rep, rep_scale])
			continue
		# 合成短名我方卡（不在 VISUAL_SCALE 表内）→ 走 platform_type 兜底路径
		var fake := CardResource.new()
		fake.card_id = "plain_player_probe_card"
		fake.platform_type = int(kind)
		var vs: float = CardFootAnchors.get_visual_scale(fake)
		var rng: Array = scale_range[kind]
		if vs < float(rng[0]) or vs > float(rng[1]):
			fail.call("kind=%d 缩放 %.2f 超出兵种语义区间 [%s, %s]（代表 %s）" % [kind, vs, str(rng[0]), str(rng[1]), rep])
	print("  5 兵种缩放兜底语义区间 ✓")

	# ══════════ 5. 编译验证：本轮改动文件可加载 ══════════
	# 注：--script 模式下 autoload 全局标识符（如 ModificationRegistry）在部分加载
	# 顺序中不可解析，属已知启动噪音（正常游戏运行不受影响）；此处仅验证 load() 不返回 null。
	print("=== 改动文件编译加载 ===")
	var changed_files: Array = [
		"res://managers/battle/battle_spawn_system.gd",
		"res://scenes/ui/bottom_instrument_bar.gd",
		"res://scenes/ui/card_info_panel.gd",
		"res://scenes/units/construct_unit.gd",
		"res://data/unified_card_table.gd",
		"res://resources/card_resource.gd",
		"res://data/faction_exclusive_cards.gd",
		"res://data/captured_unit_cards.gd",
		"res://data/enemy_blueprints.gd",
		"res://data/card_periodic_skills.gd",
		"res://data/card_foot_anchors.gd",
		"res://scripts/rank_display_ui.gd",
		"res://scripts/battle/construct_unit_ai.gd",
	]
	for p in changed_files:
		var s = load(p)
		if s == null:
			fail.call("改动文件加载失败: %s" % p)
	print("  %d 个改动文件全部可加载 ✓" % changed_files.size())

	var code: int = int(st["code"])
	if code == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code)
