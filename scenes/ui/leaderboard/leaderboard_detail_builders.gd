class_name LeaderboardDetailBuilders
extends RefCounted
## 排行排行榜详情构建器（D2 2026-08-22 抽取）
## 此前 leaderboard_panel.gd 与 leaderboard_presenter.gd 各持一份逐字节相同的拷贝
## （_make_stat_label/_create_stats_display/_create_skills_section/_create_skill_box/
##   _get_skill_panel_style/_translate_special_tag），改一处必漂移。
## 现统一为单一来源，两个调用方以同名薄委托保留（调用点零改动）。
## 注：_create_equipment_section 未合并——我方/敌方详情存在真实语义差异
## （防御行 vs 速度行），各自保留；special 标签汉化在此共享。
## 字号说明：中文标签 11→12（2026-08-22 C3 规则：中文 ≥12）；
## "%dMP %.1fs" 行保留 10（纯数字/英文角标）。

const DT = preload("res://resources/design_tokens.gd")


static func make_stat_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


static func create_stats_display(stats: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(make_stat_label("战斗属性", 14, DT.COLOR_ICE_TEXT))

	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 15)
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(stats_row)

	stats_row.add_child(make_stat_label("HP: %d" % stats.get("max_hp", 0), 12, Color(0.8, 0.4, 0.4, 1)))
	stats_row.add_child(make_stat_label("攻击: %d" % stats.get("attack_power", 0), 12, Color(0.4, 0.8, 0.4, 1)))
	stats_row.add_child(make_stat_label("防御: %d" % stats.get("defense", 0), 12, Color(0.4, 0.4, 0.8, 1)))
	stats_row.add_child(make_stat_label("能量: %.1f/s" % stats.get("energy_regen", 0), 12, Color(0.4, 0.8, 0.8, 1)))

	return container


static func create_skills_section(section_title: String, skills: Array) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(make_stat_label(section_title, 14, DT.COLOR_ICE_TEXT))

	for skill in skills:
		container.add_child(create_skill_box(skill))

	return container


static func create_skill_box(skill: Dictionary) -> Control:
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", get_skill_panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(panel)

	var skill_container = VBoxContainer.new()
	skill_container.add_theme_constant_override("separation", 3)
	skill_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(skill_container)

	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	skill_container.add_child(header_row)

	var name_label = Label.new()
	name_label.text = skill.get("name", "未知技能")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", DT.COLOR_GOLD_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	var mana_cost = skill.get("mana_cost", 0)
	var cooldown = skill.get("cooldown", 0.0)
	header_row.add_child(make_stat_label(
		"%dMP  %.1fs" % [mana_cost, cooldown], 10, Color(0.6, 0.7, 0.8, 1)))

	var desc_label = Label.new()
	desc_label.text = skill.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_container.add_child(desc_label)

	return outer


static func get_skill_panel_style() -> StyleBox:
	if not ResourceLoader.exists("res://scenes/ui/leaderboard/skill_panel_style.tres"):
		return StyleBoxFlat.new()
	return load("res://scenes/ui/leaderboard/skill_panel_style.tres") as StyleBox


## 翻译敌方相位师装备的 raw 英文 special tag 为中文（4 势力家族 + 梯度后缀）
static func translate_special_tag(tag: String) -> String:
	# 已知完整翻译表（覆盖 enemy_equipment_specials.gd 全部 56 个 tag）
	const TAG_ZH: Dictionary = {
		# 钢铁（防御系）
		"steel_skin_basic": "钢肤·初", "steel_skin_advanced": "钢肤·进",
		"steel_skin_expert": "钢肤·精", "steel_skin_master": "钢肤·极",
		"fortress_aura": "堡垒光环", "fortress_mastery": "堡垒精通",
		"immortal_fortress": "不朽堡垒", "steel_mountain": "钢山之躯",
		"industrial_aura": "工业光环", "tempered_skin": "淬火之肤",
		"storm_forged": "风暴锻造", "divine_protection": "神圣庇护",
		# 火焰（燃烧系）
		"burning_aura_basic": "焚光·初", "burning_aura_advanced": "焚光·进",
		"burning_aura_expert": "焚光·精", "heat_wave": "热浪",
		"hellfire": "狱火", "immolation": "自焚",
		"eternal_flame": "永恒之焰", "world_burning": "焚世",
		"phoenix_aura": "凤凰光环", "immortal_flame": "不朽之焰",
		"molten_aura": "熔岩光环", "dimensional_burn": "维度灼烧",
		"entropy_flame_passive": "熵焰", "hell_on_earth": "人间炼狱",
		# 雷电（电流系）
		"static_field_basic": "静电场·初", "static_field_advanced": "静电场·进",
		"static_field_expert": "静电场·精", "chain_lightning_passive": "连锁闪电",
		"lightning_speed": "雷电之速", "overcharge": "过载",
		"omnipresent_lightning": "无处不在之雷", "conductive_world": "导通世界",
		"thunder_god_aura": "雷神光环", "conductive_armor": "导能装甲",
		"god_of_thunder": "雷霆之神", "thunder_dome_passive": "雷穹",
		"infinite_energy": "无尽能量",
		# 虚空（熵变系）
		"entropy_aura_basic": "熵光·初", "entropy_aura_advanced": "熵光·进",
		"entropy_aura_expert": "熵光·精", "phase_shift": "相位偏移",
		"reality_tear": "现实撕裂", "void_embrace": "虚空拥抱",
		"void_goddess": "虚空女神", "void_lord": "虚空领主",
		"void_mastery_ultimate": "虚空极意", "night_everlasting": "永夜",
		"reality_breakdown": "现实崩溃", "reality_erasure": "现实抹除",
		"chaos_aura": "混沌光环", "godly_aura": "神圣光环",
		"infinite_potential": "无尽潜能", "master_of_all": "万物之主",
		"perfect_harmony": "完美和谐", "energized_shield": "能量护盾",
	}
	return String(TAG_ZH.get(tag, tag))
