extends SceneTree
## R4 叙事批次（设计审查 F-08，v30.2）验证脚本——纯源码断言（--script 安全）。
## 运行：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_r4_narrative_check.gd
## 注意：CampaignNarrative 依赖链经 enemy_phase_masters → master_power_evaluator 触及
## autoload 引用，--script 下 load 即挂起（本轮实证）——故本脚本只做 FileAccess 源码
## 断言；API 实测/宪法扫描/横幅队列时序在 boot 场景 tests/_tmp_r4_narr_boot.tscn 跑。

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
	print("=== R4 narrative check (source-level) ===")
	var cn := _src("res://data/campaign_narrative.gd")

	# ── 1. 数据文件结构：全量批齐全（20 驻守 master / 4 仪式 / 副句关键节点）──
	for mid in ["enemy_master_005", "enemy_master_006", "enemy_master_007", "enemy_master_008",
			"enemy_master_009", "enemy_master_011", "enemy_master_012", "enemy_master_013",
			"enemy_master_014", "enemy_master_015", "enemy_master_016", "enemy_master_018",
			"enemy_master_019", "enemy_master_020", "enemy_master_022", "enemy_master_024",
			"enemy_master_025", "enemy_master_026", "enemy_master_028", "enemy_master_030"]:
		_check(cn.contains('"%s": {' % mid), "驻守台词缺 %s" % mid)
	_check(cn.contains('"pre": ['), "战前台词键缺失")
	_check(cn.contains('"post":'), "战后遗言键缺失")
	for rite in ["21: {", "41: {", "61: {", "81: {"]:
		_check(cn.contains(rite), "时代仪式缺 %s" % rite)
	_check(cn.contains('"banner": "二 战"'), "时代横幅缺失")
	for lv in ["1:", "10:", "21:", "41:", "61:", "81:", "100:"]:
		_check(cn.contains("\t%s " % lv) or cn.contains("\t%s\n" % lv), "副句关键节点缺 L%s" % lv)
	_check(cn.contains('"credits":'), "结局致谢键缺失")
	_check(cn.contains('"hook":'), "结局黑门钩子键缺失")

	# ── 2. 查询 API 与降级守门 ──
	for fn in ["get_pre_battle_lines", "get_post_battle_line", "get_post_battle_master_name",
			"get_era_rite_lines", "get_level_echo", "get_ending"]:
		_check(cn.contains("static func %s(" % fn), "API 缺失：%s" % fn)
	_check(cn.contains("_era_rite_shown"), "时代仪式会话去重态缺失")

	# ── 3. 挂载点接入 ──
	var mbs := _src("res://scripts/systems/main_battle_setup.gd")
	_check(mbs.contains("StageBanner.post_queue(unveil_seq)"), "揭幕串未接队列横幅")
	_check(mbs.contains("CampaignNarrative.get_era_rite_lines(lvl)"), "揭幕串未接时代仪式")
	_check(mbs.contains("CampaignNarrative.get_pre_battle_lines(lvl)"), "揭幕串未接驻守台词")
	_check(mbs.contains('"交战开始"'), "揭幕串丢失交战开始结尾")

	var sb := _src("res://scripts/ui/stage_banner.gd")
	_check(sb.contains("static func post_queue("), "横幅队列入口缺失")
	_check(sb.contains("static func _pump()"), "横幅队列泵缺失")
	_check(sb.contains("func _exit_tree()"), "横幅 _exit_tree 缺失（续泵点）")

	var mvp := _src("res://scenes/ui/mvp_panel.gd")
	_check(mvp.contains("func _render_master_epilogue("), "遗言段函数缺失")
	_check(mvp.contains("_render_master_epilogue(vbox)"), "遗言段未挂接战报页")
	_check(mvp.contains("func _render_ending("), "结局段函数缺失")
	_check(mvp.contains("_render_ending(vbox)"), "结局段未挂接战报页")
	_check(mvp.contains("同伴档案"), "遗言段缺同伴档案指引")
	_check(mvp.contains("if _is_afk or not player_won:"), "结局段缺胜利/挂机守门")

	var wm := _src("res://scenes/world_map.gd")
	_check(wm.contains("CampaignNarrative.get_level_echo(level_index)"), "说明牌副句未接入")

	# ── 6. 帮助面板叙事/经济口径（F-08 第 5 项，v30.4）──
	var hp := _src("res://scenes/ui/help_panel.gd")
	_check(hp.contains("迷失在时代里的同伴"), "帮助缺迷失者叙事锚点")
	_check(hp.contains("其力量将随你同行"), "帮助缺战胜=带回力量口径")
	_check(hp.contains("◆ 功勋（商店消费货币）"), "帮助缺功勋说明段")
	_check(hp.contains("购买不再拉低声望"), "帮助功勋口径未同步")
	_check(hp.contains("纳米材料与晶体"), "帮助洗练计费未含晶体")
	_check(hp.contains("深航计划"), "帮助地图缺深航锚点")
	_check(hp.contains("锚定裂隙坐标"), "帮助黑门缺门票口径")
	for banned in ["指挥官", "玩家", "用户", "勇士", "旅行者", "黑暗之门"]:
		_check(not hp.contains(banned), "帮助面板含禁用词：%s" % banned)

	# ── 4. 注入纪律标注（反目标 6）──
	_check(cn.contains("过目"), "数据文件缺过目纪律标注")
	_check(cn.contains("全量批"), "数据文件缺全量批标注")

	if _fails.is_empty():
		print("ALL PASS (%d checks)" % _passes)
		quit(0)
	else:
		for f in _fails:
			push_error("[R4-CHECK] " + f)
		print("FAILED: %d / passed %d" % [_fails.size(), _passes])
		quit(1)
