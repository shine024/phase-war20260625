extends Node
## R4 叙事批次 boot 冒烟（全 autoload 环境）：
##  ① CampaignNarrative API 实测（驻守台词/时代仪式去重/副句/结局 + 宪法禁用词扫描）
##  ② StageBanner.post_queue 串行时序（采样横幅文本序列，断言严格串行不互相打断）
##  ③ mvp_panel 遗言段（L10 胜）/结局段（L100 胜）实测渲染 + 非驻守关降级
##  ④ 实拍：L10 遗言面板 / L100 结局面板
## 跑法（实拍需非 headless）：
##   godot --rendering-driver opengl3 --path . res://tests/_tmp_r4_narr_boot.tscn

var _fails: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_api_checks()
	await _banner_queue_checks()
	await _panel_checks()
	if _fails.is_empty():
		print("[R4Narr] ALL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			printerr("[R4Narr] FAIL: " + f)
		get_tree().quit(1)

func _chk(cond: bool, label: String) -> void:
	if cond:
		print("[R4Narr] PASS: " + label)
	else:
		_fails.append(label)

# ── ① API 实测 + 宪法扫描（全量批口径）──
const GARRISON_LEVELS := [10, 15, 20, 25, 30, 35, 40, 45, 49, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]
const ECHO_LEVELS := [1, 10, 15, 20, 21, 25, 30, 35, 40, 41, 45, 49, 50, 55, 60, 61, 65, 70, 75, 80, 81, 85, 90, 95, 100]

func _api_checks() -> void:
	var pre10: Array = CampaignNarrative.get_pre_battle_lines(10)
	_chk(pre10.size() == 2, "L10 战前台词非 2 句（%d）" % pre10.size())
	_chk(String(pre10[0]).contains("霍北望"), "L10 台词未带 master 名")
	_chk(CampaignNarrative.get_pre_battle_lines(11).is_empty(), "L11 非驻守关应无台词")
	_chk(not CampaignNarrative.get_post_battle_line(20).is_empty(), "L20 遗言缺失")
	_chk(CampaignNarrative.get_post_battle_master_name(20) == "秦引路", "L20 署名错误")
	_chk(CampaignNarrative.get_post_battle_line(11).is_empty(), "L11 应无遗言")

	# 全量批：20 驻守点 × (战前 2 句 + 战后 1 句) 全覆盖
	for lv in GARRISON_LEVELS:
		_chk(CampaignNarrative.get_pre_battle_lines(lv).size() == 2, "驻守 L%d 台词非全量（战前 2 句）" % lv)
		_chk(not CampaignNarrative.get_post_battle_line(lv).is_empty(), "驻守 L%d 遗言缺失" % lv)
		_chk(not CampaignNarrative.get_post_battle_master_name(lv).is_empty(), "驻守 L%d 署名缺失" % lv)

	# 全量批仪式断言先跑（会话去重后 rite21 复核块只能消费一次 21）
	for first_lv in [21, 41, 61, 81]:
		var rite: Array = CampaignNarrative.get_era_rite_lines(first_lv)
		_chk(rite.size() == 4, "时代 L%d 仪式非全量（4 条，实际 %d）" % [first_lv, rite.size()])
		_chk(not String(rite[rite.size() - 1]).is_empty(), "时代 L%d 横幅为空" % first_lv)
	_chk(CampaignNarrative.get_era_rite_lines(1).is_empty(), "L1 非时代首关应为空")
	# 会话去重复核：21 已消费，再取应为空
	_chk(CampaignNarrative.get_era_rite_lines(21).is_empty(), "L21 仪式未会话去重")

	for lv in ECHO_LEVELS:
		_chk(not String(CampaignNarrative.get_level_echo(lv)).is_empty(), "副句 L%d 缺失" % lv)
	_chk(String(CampaignNarrative.get_level_echo(2)).is_empty(), "L2 未注入应为空")

	var ending: Dictionary = CampaignNarrative.get_ending()
	_chk(ending.get("monologue", []).size() >= 3, "结局独白不足 3 句")
	_chk(not String(ending.get("credits", "")).is_empty(), "结局致谢缺失")
	_chk(not String(ending.get("hook", "")).is_empty(), "结局钩子缺失")

	# 宪法禁用词扫描（LANGUAGE_BIBLE 五章）——全量文本
	var all_text := ""
	for lv in GARRISON_LEVELS:
		for line in CampaignNarrative.get_pre_battle_lines(lv):
			all_text += String(line)
		all_text += CampaignNarrative.get_post_battle_line(lv)
	for first_lv in [21, 41, 61, 81]:
		# 直读常量（get_era_rite_lines 有会话去重，二次取会漏文本）
		var rite_def: Dictionary = CampaignNarrative.ERA_RITES.get(first_lv, {})
		for line in rite_def.get("monologue", []):
			all_text += String(line)
		all_text += String(rite_def.get("banner", ""))
	for lv in ECHO_LEVELS:
		all_text += String(CampaignNarrative.get_level_echo(lv))
	all_text += String(ending.get("credits", "")) + String(ending.get("hook", ""))
	for line in ending.get("monologue", []):
		all_text += String(line)
	for banned in ["伙伴", "指挥官", "玩家", "用户", "勇士", "旅行者", "黑暗之门", "魔门"]:
		_chk(not all_text.contains(banned), "叙事文本含禁用词：%s" % banned)

# ── ② 横幅队列串行时序 ──
func _banner_queue_checks() -> void:
	StageBanner.post_queue(["R4队列甲", "R4队列乙", "R4队列丙"])
	var seen: Array[String] = []
	for i in range(60):   # 采样 6s：3 条 × ~1s 生命周期 + 裕量
		await get_tree().create_timer(0.1).timeout
		var active = StageBanner._active
		if active != null and is_instance_valid(active):
			var text: String = String(active.get("_text"))
			if seen.is_empty() or seen[seen.size() - 1] != text:
				if not seen.has(text):
					seen.append(text)
	_chk(seen.size() == 3, "队列串行播放数量 != 3（%d：%s）" % [seen.size(), "→".join(PackedStringArray(seen))])
	_chk(seen == ["R4队列甲", "R4队列乙", "R4队列丙"], "队列顺序错误：%s" % "→".join(PackedStringArray(seen)))

# ── ③ mvp_panel 遗言/结局段 + 实拍 ──
func _panel_checks() -> void:
	var mvp_script = load("res://scenes/ui/mvp_panel.gd")
	var saved_level := int(GameManager.current_level)

	# L10 驻守关胜利 → 遗言段
	GameManager.set_current_level(10) if GameManager.has_method("set_current_level") else GameManager.set("current_level", 10)
	var p10: Node = mvp_script.create(get_tree().root, true, [], 100, 2, _fake_summary(), false)
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(_has_label_text_containing(p10, "🕯 来自 霍北望 的讯息"), "L10 遗言段未渲染")
	_chk(_has_label_text_containing(p10, "盾放下了"), "L10 遗言正文未渲染")
	await _shot("r4_epilogue_l10.png")
	p10.queue_free()
	await get_tree().process_frame

	# L100 通关 → 结局段（+ 遗言：030 驻守）
	GameManager.set_current_level(100) if GameManager.has_method("set_current_level") else GameManager.set("current_level", 100)
	var p100: Node = mvp_script.create(get_tree().root, true, [], 100, 2, _fake_summary(), false)
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(_has_label_text_containing(p100, "🕯 来自 贺同舟 的讯息"), "L100 遗言段未渲染")
	_chk(_has_label_text_containing(p100, "致谢"), "L100 结局致谢未渲染")
	_chk(_has_label_text_containing(p100, "黑门·无限 已开启"), "L100 黑门钩子未渲染")
	await _shot("r4_ending_l100.png")
	p100.queue_free()
	await get_tree().process_frame

	# L5 非驻守关胜利 → 无遗言段（降级守门）
	GameManager.set_current_level(5) if GameManager.has_method("set_current_level") else GameManager.set("current_level", 5)
	var p5: Node = mvp_script.create(get_tree().root, true, [], 100, 2, _fake_summary(), false)
	await get_tree().process_frame
	await get_tree().process_frame
	_chk(not _has_label_text_containing(p5, "🕯"), "L5 不应渲染遗言段")
	p5.queue_free()

	# 复位
	if GameManager.has_method("set_current_level"):
		GameManager.set_current_level(saved_level)

func _fake_summary() -> Dictionary:
	return {"energy_block_gain": 12, "basic_nano_gain": 240, "fragment_gain_total": 3}

func _has_label_text_containing(node: Node, frag: String) -> bool:
	if node is Label and String((node as Label).text).contains(frag):
		return true
	for c in node.get_children():
		if _has_label_text_containing(c, frag):
			return true
	return false

func _shot(fname: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("res://.godot/agent_tools/" + fname)
		print("[R4Narr] shot saved: " + fname)
