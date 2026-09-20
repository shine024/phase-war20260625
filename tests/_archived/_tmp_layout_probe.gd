extends SceneTree
## _tmp 探针（2026-09-XX 槽位错位排查）：逐关激活布局 → 实例化真实 BattleSlotGrid
## 重建槽心 → 打印敌我槽位 X 范围/间距/中缝，验证"敌方是否可能落进我方 3×3 区域"。
## 跑法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_layout_probe.gd

const LevelLayouts = preload("res://data/level_battle_layouts.gd")
const Layout = preload("res://scripts/card_grid_battle_layout.gd")
const GridScript = preload("res://scenes/battlefield/battle_slot_grid.gd")

func _init() -> void:
	print("=== 每关布局槽位坐标探针 ===")
	_check_default()
	for level in LevelLayouts.LAYOUT_BY_LEVEL.keys():
		_check_level(int(level))
	print("=== 探针结束 ===")
	quit()

func _check_default() -> void:
	Layout.reset_to_default()
	var g := _make_grid()
	var p := _extents(g.player_slot_centers)
	var e := _extents(g.enemy_slot_centers)
	print("[default 3x3] cols=%d/%d rows=%d | 我方 X %.1f..%.1f | 敌方 X %.1f..%.1f | 中缝 %.1f | 敌col0=%.1f" % [
		Layout.active_player_cols(), Layout.active_enemy_cols(), Layout.active_rows(),
		p.x, p.y, e.x, e.y, e.x - p.y, g.enemy_slot_centers[0].x])
	# 历史逐像素校验（v9.5 默认几何）：列宽 171.43；敌带左缘 670；
	# 敌 col0 row0 槽心 = 670 + 卡宽/2 - 斜阵错位 = 670 + 71.43 - 34.29 = 707.14
	var cw: float = Layout.column_width_px()
	var expect_c0: float = 670.0 + Layout.battle_card_width_px(true) * 0.5 - Layout.slot_row_x_stagger(0, true)
	if absf(cw - 1200.0 / 7.0) > 0.01 or absf(g.enemy_slot_centers[0].x - expect_c0) > 0.01:
		push_error("[default] 几何与历史不一致! col_w=%.2f e0=%.2f expect=%.2f" % [
			cw, g.enemy_slot_centers[0].x, expect_c0])
	else:
		print("  默认几何与 v9.5 历史一致 ✓")
	g.free()

func _check_level(level: int) -> void:
	Layout.apply_for_level(level)
	var g := _make_grid()
	var p := _extents(g.player_slot_centers)
	var e := _extents(g.enemy_slot_centers)
	var gap: float = e.x - p.y
	var flag: String = "OK"
	if gap < 40.0:
		flag = "!! 中缝过窄"
	if e.x < p.y:
		flag = "!!! 敌我重叠"
	print("L%-3d pc=%d ec=%d rows=%d | 我方 X %6.1f..%6.1f | 敌方 X %6.1f..%6.1f | 中缝 %5.1f | %s" % [
		level, Layout.active_player_cols(), Layout.active_enemy_cols(), Layout.active_rows(),
		p.x, p.y, e.x, e.y, gap, flag])
	g.free()

func _make_grid() -> Node2D:
	var g: Node2D = GridScript.new()
	root.add_child(g)
	g.rebuild_slot_centers_now()  # --script 模式 _init 阶段 _ready 不触发，显式重建
	return g

func _extents(centers: Array[Vector2]) -> Vector2:
	var mn := 1e9
	var mx := -1e9
	for c in centers:
		mn = minf(mn, c.x)
		mx = maxf(mx, c.x)
	return Vector2(mn, mx)
