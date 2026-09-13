extends SceneTree
## R1 批次（设计审查 2026-09-13）验证脚本：改动文件编译 + 关键行为断言
## 运行：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_r1_design_fix_check.gd
## 覆盖：R1-3 声望门槛换算 / R1-4 图纸价目 / R1-5 情报奖励改向 / R1-6 倍速档 /
##       R1-8 组合条新六套装 / R1-1+R1-9 改动脚本编译

var _fails: Array = []
var _passes: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails.append(label)

func _compile(path: String, label: String) -> GDScript:
	var s: GDScript = load(path)
	_check(s != null, "%s 编译失败: %s" % [label, path])
	return s

func _init() -> void:
	print("=== R1 design-fix check ===")

	# ── R1-5：情报 28 条事件全部无 unlock 奖励；7 系 tier-3 均为 hint ──
	var ire: GDScript = _compile("res://data/intel_reveal_events.gd", "intel_reveal_events")
	if ire:
		var events: Dictionary = ire.REVEAL_EVENTS
		_check(events.size() == 28, "reveal 事件数 %d ≠ 28" % events.size())
		var unlock_cnt := 0
		var hint_t3_cnt := 0
		for key in events.keys():
			for r in events[key].get("rewards", []):
				if String(r.get("type", "")) == "intel_branch_unlock":
					unlock_cnt += 1
		for t in ["infantry", "flame", "heavy_armor", "artillery", "stealth", "boss_nano", "air"]:
			var ev: Dictionary = events.get("%s_3" % t, {})
			var has_hint := false
			for r in ev.get("rewards", []):
				if String(r.get("type", "")) == "intel_branch_hint":
					has_hint = true
			if has_hint:
				hint_t3_cnt += 1
		_check(unlock_cnt == 0, "仍有 %d 条 intel_branch_unlock 奖励" % unlock_cnt)
		_check(hint_t3_cnt == 7, "tier-3 hint 覆盖 %d/7" % hint_t3_cnt)

	# ── R1-4：图纸商店价目（common 120 / uncommon 225 / rare 420 / epic 1500 / legendary 3500）──
	var imi: GDScript = _compile("res://data/intel_manual_items.gd", "intel_manual_items")
	if imi:
		var src: String = imi.source_code
		_check(src.contains('"common": return 120'), "common 价目非 120")
		_check(src.contains('"uncommon": return 225'), "uncommon 价目非 225")
		_check(src.contains('"rare": return 420'), "rare 价目非 420")

	# ── R1-6：倍速三档 ──
	var thb: GDScript = _compile("res://scenes/ui/top_hud_bar.gd", "top_hud_bar")
	if thb:
		var opts: Array = thb._SPEED_OPTIONS
		_check(opts.size() == 3 and opts[0] == 1.0 and opts[1] == 2.0 and opts[2] == 3.0,
			"倍速档位错误: %s" % str(opts))

	# ── R1-8：组合条新六套装常量与 tooltip 构建 ──
	var css: GDScript = _compile("res://scenes/ui/combo_status_strip.gd", "combo_status_strip")
	var ct: GDScript = _compile("res://data/combo_tactics.gd", "combo_tactics")
	if css and ct:
		var suit_order: Array = css._SUIT_ORDER
		_check(suit_order.size() == 6, "套装顺序表 %d ≠ 6" % suit_order.size())
		var missing: Array = []
		for cid in suit_order:
			if ct.get_combo_def(String(cid)).is_empty():
				missing.append(String(cid))
		_check(missing.is_empty(), "套装定义缺失: %s" % str(missing))
		# 机制反推覆盖 12 套：抽查 armor_phalanx 的 mechanisms 至少 1 条
		var phalanx: Dictionary = ct.get_combo_def(String(ct.COMBO_ARMOR_PHALANX))
		_check(not phalanx.get("mechanisms", []).is_empty(), "armor_phalanx 无 mechanisms")

	# ── R1-3：声望等级函数存在且阈值正确（换算依赖）──
	var fr: GDScript = _compile("res://managers/faction/faction_reputation.gd", "faction_reputation")
	if fr:
		_check(fr.get_level_from_reputation(0) == 1, "Lv(0)≠1")
		_check(fr.get_level_from_reputation(5000) == 7, "Lv(5000)≠7")
		_check(fr.get_level_from_reputation(9000) == 10, "Lv(9000)≠10")
		_check(fr.get_level_from_reputation(70 * 100) == 8, "Lv(7000)≠8（商店 70 旧轴→真轴门槛档）")

	# ── R1-1 / R1-9 / R1-7：改动脚本编译（面板键/序章路由/地图 BGM 属运行期行为，headless 编译验证）──
	_compile("res://scenes/ui/store_panel.gd", "store_panel")
	_compile("res://scenes/bunker/truck_base.gd", "truck_base")
	_compile("res://scenes/title_screen.gd", "title_screen")
	_compile("res://scenes/world_map.gd", "world_map")
	# truck_base PANEL_SCENES 补键断言（const 可直接读）
	var tb: GDScript = load("res://scenes/bunker/truck_base.gd")
	if tb:
		var panels: Dictionary = tb.PANEL_SCENES
		_check(String(panels.get("quest", "")).ends_with("quest_panel.tscn"), "PANEL_SCENES 缺 quest")
		_check(String(panels.get("achievement", "")).ends_with("achievement_panel.tscn"), "PANEL_SCENES 缺 achievement")

	# ── 汇总 ──
	if _fails.is_empty():
		print("ALL PASS (%d checks)" % _passes)
		quit(0)
	else:
		for f in _fails:
			push_error("[R1-CHECK] " + f)
		print("FAILED: %d / passed %d" % [_fails.size(), _passes])
		quit(1)
