# 单文件语法/加载检查（v21.x 星点移除 + 费用角标竞态修复验证）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_stars_removal_check.gd
extends SceneTree

const TARGETS := [
	"res://scenes/ui/backpack_card_item.gd",
	"res://scripts/card_frame_ui.gd",
	"res://scripts/cost_badge.gd",
	"res://scenes/ui/card_info_panel.gd",
]

var _fails: int = 0

func _initialize() -> void:
	# 1) 加载即编译：解析错误时 load() 返回 null 并向 stderr 打错
	for path in TARGETS:
		var scr: GDScript = load(path)
		if scr == null:
			push_error("[stars_check] 脚本加载失败（解析错误）: " + path)
			_fails += 1
		else:
			print("OK load: " + path)

	# 2) 背包卡物品：实例化后检查方法表（Script 资源级 has_method 在 --script 模式恒 false，假阴性）
	var bci: GDScript = load("res://scenes/ui/backpack_card_item.gd")
	var bci_inst: PanelContainer = bci.new()
	for gone in ["_ensure_stars_overlay", "_build_star_prefix"]:
		if bci_inst.has_method(gone):
			push_error("[stars_check] 应删除的方法仍存在: " + gone)
			_fails += 1
	for kept in ["_ensure_evolution_mark", "_ensure_equipped_mark", "_ensure_instance_no",
			"_ensure_rarity_top_strip", "_hide_decoration", "set_card"]:
		if not bci_inst.has_method(kept):
			push_error("[stars_check] 应保留的方法缺失: " + kept)
			_fails += 1
	bci_inst.free()

	# 3) 费用角标竞态回归（上轮修复的本体验证）
	var host := PanelContainer.new()
	root.add_child(host)
	var CardFrameUi = load("res://scripts/card_frame_ui.gd")
	var b1: Control = CardFrameUi.ensure_cost_corner_badge(host, false)
	b1.energy_value = 5
	CardFrameUi.clear_cost_corner_badge(host)
	if not b1.is_queued_for_deletion():
		push_error("[stars_check] clear 后旧角标未标记释放")
		_fails += 1
	var b2: Control = CardFrameUi.ensure_cost_corner_badge(host, false)
	if b2 == null or b2 == b1:
		push_error("[stars_check] 同帧复用拿到垂死节点（竞态仍在）")
		_fails += 1
	elif host.get_node_or_null("CostCornerBadge") != b2:
		push_error("[stars_check] 按名查询未命中新角标")
		_fails += 1
	else:
		b2.energy_value = 7
		print("OK cost_badge race: fresh badge takes over")

	if _fails == 0:
		print("stars_removal_check: ALL PASS")
	else:
		print("stars_removal_check: %d FAIL" % _fails)
	quit(0 if _fails == 0 else 1)
