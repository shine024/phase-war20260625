extends SceneTree
## R2b + R3 批次（设计审查 2026-09-13，v30）验证脚本
## 运行：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_r2b_r3_check.gd
## 原则：不实例化任何引用 autoload 的脚本（--script 模式编译失败会中断 _init 导致挂起），
## 静态断言走 FileAccess；纯逻辑（GameConfig）直接单测。

var _fails: Array = []
var _passes: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails.append(label)

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _init() -> void:
	print("=== R2b+R3 check ===")
	var GC = load("res://resources/game_config.gd")

	# ── 1. GameConfig 新参默认值 + reset 保全 ──
	var cfg = GC.new()
	_check(cfg.affix_reroll_crystal_enabled == true, "洗练晶体开关默认未开")
	_check(cfg.blackgate_energy_cost == 50, "黑门门票默认非 50")
	cfg.affix_reroll_crystal_enabled = false
	cfg.blackgate_energy_cost = 0
	cfg.reset_to_defaults()
	_check(cfg.affix_reroll_crystal_enabled == true, "reset 后洗练晶体开关未复位")
	_check(cfg.blackgate_energy_cost == 50, "reset 后黑门门票未复位")

	# ── 2. 功勋分离（fsm 源码断言：镜像/扣款/存档三链路）──
	var fsm := _src("res://managers/faction_system_manager.gd")
	_check(fsm.contains("var merit_points: int = DEFAULT_STARTING_MERIT"), "功勋字段缺失")
	_check(fsm.contains("const DEFAULT_STARTING_MERIT := 500"), "功勋起步值常量缺失")
	_check(fsm.contains("merit_points += delta"), "正增量镜像功勋缺失")
	_check(fsm.contains("merit_points -= eff_cost"), "购买扣功勋缺失")
	_check(fsm.contains('"faction_merit": merit_points'), "save_state 功勋键缺失")
	_check(fsm.contains('data.get("faction_merit", DEFAULT_STARTING_MERIT)'), "load_state 功勋缺省读缺失")
	_check(fsm.contains("func spend_merit("), "spend_merit 缺失")
	# 购买路径不再扣声望（旧调用 add_faction_reputation(fid, -eff_cost) 应已移除）
	_check(not fsm.contains("add_faction_reputation(faction_id, -eff_cost)"), "购买仍扣声望")

	# ── 3. 商店 UI 功勋化 ──
	var sp := _src("res://scenes/ui/store_panel.gd")
	_check(sp.contains("%d功勋"), "符文/特购价格标签未功勋化")
	_check(sp.contains("功勋不足：需要 %d（当前 %d）"), "购买失败文案未功勋化")
	_check(sp.contains("功勋特购"), "特购区标题未功勋化")
	_check(sp.contains("fsm.spend_merit(rep_cost)"), "符文购买未走功勋")

	# ── 4. 晶体洗练（AffixManager 源码断言 + 计费公式静态核算）──
	var am := _src("res://managers/affix_manager.gd")
	_check(am.contains("REROLL_CRYSTAL_RATIO := 0.02"), "晶体比例常量缺失")
	_check(am.contains("func get_reroll_crystal_cost("), "晶体计费函数缺失")
	_check(am.contains("ID_CRYSTAL, -crystal_cost"), "晶体扣款缺失")
	_check(am.contains("func get_batch_crystal_cost("), "批量晶体计费缺失")
	_check(am.contains("can_pay_reroll(affix_key, total_cost, crystal_total)"), "批量前置校验缺失")
	var forge := _src("res://scenes/ui/affix_forge_panel.gd")
	_check(forge.contains("纳米材料：%d ｜ 晶体：%d"), "工坊顶栏未显示晶体余额")
	_check(forge.contains("纳米+%d晶体"), "工坊计费文案未含晶体")

	# ── 5. 黑门能量门票 ──
	var wm := _src("res://scenes/world_map.gd")
	_check(wm.contains("blackgate_energy_cost"), "黑门门票未接 GameConfig")
	_check(wm.contains("ID_ENERGY_BLOCK, -_ticket"), "黑门门票未扣能量块")

	# ── 6. 指令额度 2→4 ──
	var bco := _src("res://scenes/ui/battle_click_overlay.gd")
	_check(bco.contains("_MAX_ACTIVE_COMMANDS := 4"), "指令额度未提至 4")

	# ── 7. 组合条弹跳 + 结算协同小结 ──
	var css := _src("res://scenes/ui/combo_status_strip.gd")
	_check(css.contains("func _pop_button("), "组合条弹跳函数缺失")
	_check(css.contains('entry["prev"] = level'), "组合条档位追踪缺失")
	var mvp := _src("res://scenes/ui/mvp_panel.gd")
	_check(mvp.contains("func _render_synergy_summary("), "结算协同小结缺失")
	_check(mvp.contains("_render_synergy_summary(vbox)"), "协同小结未挂接")
	_check(mvp.contains("_SYNERGY_COMBO_ORDER"), "协同检阅表缺失")
	_check(mvp.contains("_SYNERGY_PAIR_ORDER"), "搭档检阅表缺失")

	# ── 8. 面板首开打点 ──
	var tb := _src("res://scenes/bunker/truck_base.gd")
	_check(tb.contains("const PANEL_INTROS :="), "面板打点表缺失")
	_check(tb.contains('"panel_intro_" + panel_id'), "首开打点未挂接")
	for pid in ["quest", "achievement", "intelligence", "collection", "leaderboard", "affix"]:
		_check(tb.contains('"%s": [' % pid), "打点表缺 %s" % pid)

	# ── 9. 结算面板三页签（F-13，v30.1）──
	_check(mvp.contains("TabContainer.new()"), "结算面板未用 TabContainer")
	_check(mvp.contains('_make_result_tab("战报"'), "战报页缺失")
	_check(mvp.contains('_make_result_tab("缴获"'), "缴获页缺失")
	_check(mvp.contains('_make_result_tab("养成"'), "养成页缺失")
	_check(mvp.contains("_bunker_body.visible = false"), "基地状态未默认折叠")
	_check(mvp.contains("func _toggle_bunker_body("), "折叠切换函数缺失")
	_check(mvp.contains("PanelAnim.fade_content_in(page)"), "切页淡入缺失")
	_check(mvp.contains("set_tab_hidden"), "空页隐藏缺失")

	if _fails.is_empty():
		print("ALL PASS (%d checks)" % _passes)
		quit(0)
	else:
		for f in _fails:
			push_error("[R2B-R3-CHECK] " + f)
		print("FAILED: %d / passed %d" % [_fails.size(), _passes])
		quit(1)
