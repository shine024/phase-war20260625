extends PanelContainer
## 暂停时查看战场单位信息的卡牌式面板（使用设计令牌）

const DefaultCards = preload("res://data/default_cards.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const DT = preload("res://resources/design_tokens.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
@onready var name_label: Label = $Margin/VBox/HeaderPanel/NameLabel
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var summary_label: Label = $Margin/VBox/StatsBox/SummaryLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var flavor_label: Label = $Margin/VBox/FlavorLabel
@onready var stance_row: HBoxContainer = $Margin/VBox/StanceRow
@onready var stance_attack_btn: Button = $Margin/VBox/StanceRow/StanceAttackBtn
@onready var stance_defend_btn: Button = $Margin/VBox/StanceRow/StanceDefendBtn

var _rank_badge_host: HBoxContainer

func _ready() -> void:
	_apply_design_tokens()
	_setup_rank_badge_host()
	visible = false
	z_index = 50
	if stance_row:
		stance_row.visible = false
	if stance_attack_btn and not stance_attack_btn.pressed.is_connected(_on_stance_attack_pressed):
		stance_attack_btn.pressed.connect(_on_stance_attack_pressed)
	if stance_defend_btn and not stance_defend_btn.pressed.is_connected(_on_stance_defend_pressed):
		stance_defend_btn.pressed.connect(_on_stance_defend_pressed)
	if SignalBus:
		SignalBus.unit_selected.connect(_on_unit_selected)

func _setup_rank_badge_host() -> void:
	var vbox: VBoxContainer = $Margin/VBox as VBoxContainer
	if vbox == null:
		return
	_rank_badge_host = HBoxContainer.new()
	_rank_badge_host.name = "RankBadgeHost"
	_rank_badge_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_rank_badge_host.add_theme_constant_override("separation", 6)
	_rank_badge_host.visible = false
	vbox.add_child(_rank_badge_host)
	vbox.move_child(_rank_badge_host, 2)


func _refresh_rank_badge(unit: Node) -> void:
	if _rank_badge_host == null:
		return
	if unit == null or not is_instance_valid(unit) or unit.is_in_group("enemy_phase_driver"):
		RankDisplayUi.clear_host(_rank_badge_host)
		_rank_badge_host.visible = false
		return
	var info: Dictionary = RankDisplayUi.resolve_from_unit(unit)
	RankDisplayUi.apply_to_host(_rank_badge_host, info, 24)
	if info.is_empty():
		return
	var name_lbl: Label = _rank_badge_host.get_node_or_null("RankName") as Label
	if name_lbl:
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1))
		name_lbl.add_theme_font_size_override("font_size", 13)
	var power: float = float(info.get("power_score", 0.0))
	if power > 0.0 and name_lbl:
		name_lbl.text = "%s（战力 %.0f）" % [str(info.get("rank_name", "")), power]


func _apply_design_tokens(high_contrast: bool = DT.HIGH_CONTRAST_ENABLED, large_type: bool = DT.LARGE_TYPE_ENABLED) -> void:
	# 使用 tscn 中的样式，主要通过代码设置颜色
	if name_label:
		name_label.add_theme_color_override("font_color", Color(0, 0.9, 1, 1))
		name_label.add_theme_font_size_override("font_size", 16)
	if type_label:
		type_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5, 1))
		type_label.add_theme_font_size_override("font_size", 13)
	if summary_label:
		summary_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1))
		summary_label.add_theme_font_size_override("font_size", 12)
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if desc_label:
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1))
		desc_label.add_theme_font_size_override("font_size", 12)
	if flavor_label:
		flavor_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
		flavor_label.add_theme_font_size_override("font_size", 11)

func _on_unit_selected(unit: Node, is_player: bool, at_position: Vector2 = Vector2.ZERO) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if SignalBus:
		BattleInputState.current_selected_unit = unit
	visible = true
	# 若传入点击位置，在点击处显示并避免超出边界
	if at_position != Vector2.ZERO:
		var container = get_parent()
		# 等待一帧确保尺寸已计算
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var panel_w := size.x
		var panel_h := size.y
		if container is Control:
			var cw := (container as Control).size.x
			var ch := (container as Control).size.y
			position = Vector2(
				clampf(at_position.x, 8.0, maxf(8.0, cw - panel_w - 8.0)),
				clampf(at_position.y, 8.0, maxf(8.0, ch - panel_h - 8.0))
			)
		else:
			position = at_position
	var is_ally: bool = _resolve_unit_is_player(unit, is_player)
	if unit.is_in_group("enemy_phase_driver"):
		_show_enemy_phase_driver(unit)
		_set_stance_row_for_unit(null)
		_refresh_rank_badge(null)
	elif is_ally and "stats" in unit:
		_show_player_unit(unit)
		_set_stance_row_for_unit(unit)
		_refresh_rank_badge(unit)
	else:
		_show_enemy_unit(unit)
		_set_stance_row_for_unit(null)
		_refresh_rank_badge(unit)


func _resolve_unit_is_player(unit: Node, hinted: bool) -> bool:
	if unit == null or not is_instance_valid(unit):
		return hinted
	if unit.is_in_group("player_units") or unit.is_in_group("phase_driver"):
		return true
	if unit.is_in_group("enemy_units") or unit.is_in_group("enemy_phase_driver"):
		return false
	if "is_player" in unit:
		return bool(unit.is_player)
	return hinted

func _is_vehicle_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if "stats" in unit:
		var stats: UnitStats = unit.stats
		if stats != null:
			return stats.platform_type >= 0
	return true

func _law_targets_this_unit(rt: Dictionary, unit: Node, is_player_side: bool) -> bool:
	var target_side: String = String(rt.get("target_side", "ALLY"))
	if target_side == "ALLY" and not is_player_side:
		return false
	if target_side == "ENEMY" and is_player_side:
		return false
	var target_type: String = String(rt.get("target_type", "ALL"))
	if target_type == "ALL":
		return true
	if target_type == "VEHICLE":
		return _is_vehicle_unit(unit)
	return false

func _format_effect_line(law_name: String, effect: String, value: float, duration: float, radius: float) -> String:
	match effect:
		"armor_buff":
			return "%s：最大生命 +%d%%" % [law_name, int(value * 100.0)]
		"aegis_link":
			return "%s：最大生命 +%d%%（护阵联结）" % [law_name, int(value * 100.0)]
		"fortify_protocol":
			return "%s：最大生命 +%d%%（固壁）" % [law_name, int(value * 100.0)]
		"resonant_plate":
			return "%s：最大生命 +%d%%（共振）" % [law_name, int(value * 100.0)]
		"regen_out_of_combat":
			return "%s：脱战回复 %.1f/秒" % [law_name, value]
		"afterburn":
			return "%s：伤害 +%d%%" % [law_name, int(value * 100.0)]
		"entropy_lens":
			return "%s：伤害 +%d%%（熵镜）" % [law_name, int(value * 100.0)]
		"arc_beacon":
			return "%s：攻速提升（约 +%d%%）" % [law_name, int(value * 100.0)]
		"burn_on_hit":
			return "%s：受击伤害提高（系数 +%.0f%%）" % [law_name, value * 5.0]
		"aoe_emp":
			return "%s：范围EMP 伤害 %.1f，半径 %.0f，持续 %.1fs" % [law_name, value, radius, duration]
		"line_bombard":
			return "%s：线性轰炸 伤害 %.1f，长度 %.0f" % [law_name, value, radius]
		"chain_lightning":
			return "%s：链式放电 总伤害 %.1f，半径 %.0f" % [law_name, value, radius]
		"burn_mark":
			return "%s：灼烧标记 %.1f/s，持续 %.1fs，半径 %.0f" % [law_name, value, duration, radius]
		"global_time_slow":
			return "%s：全局时缓 %.0f%%，持续 %.1fs" % [law_name, value * 100.0, duration]
		"spawn_shield_wall":
			return "%s：护盾墙 减伤 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"hp_shield_shift":
			return "%s：护盾转移 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"anchor_field":
			return "%s：锚定减速 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"scorch_wave":
			return "%s：灼浪伤害 %.1f，半径 %.0f" % [law_name, value, radius]
		"ember_screen":
			return "%s：灰烬护幕 护盾 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"core_rupture":
			return "%s：核心破裂 伤害 %.1f，半径 %.0f" % [law_name, value, radius]
		"ion_net":
			return "%s：离子网 减速 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"surge_drive":
			return "%s：激涌驱动 速度/攻速 +%.0f%%，持续 %.1fs" % [law_name, value * 100.0, duration]
		"static_domain":
			return "%s：静电域 伤害 %.1f，持续 %.1fs，半径 %.0f" % [law_name, value, duration, radius]
		"phase_cloak":
			return "%s：相位披幕 护盾 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"gravity_well":
			return "%s：引力井 束缚 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		_:
			return "%s：效果 %s，数值 %.2f" % [law_name, effect, value]

func _is_construct_unit_script(unit: Node) -> bool:
	var sc: Variant = unit.get_script()
	if sc == null:
		return false
	return String(sc.resource_path).ends_with("construct_unit.gd")

## EnemyUnit 用根节点战斗属性；ConstructUnit 攻/射程/攻速在 stats 上
func _rank_line_for_card_id(card_id: String) -> String:
	var cid: String = String(card_id).strip_edges()
	if cid.is_empty():
		return ""
	if BlueprintManager and BlueprintManager.has_method("get_rank_info"):
		var ri: Dictionary = BlueprintManager.get_rank_info(cid)
		var rank_name: String = str(ri.get("rank_name", "")).strip_edges()
		var power: float = float(ri.get("power_score", 0.0))
		if not rank_name.is_empty():
			return "军衔 %s（战力 %.0f）" % [rank_name, power]
	return ""

func _rank_line_for_stats(stats: UnitStats) -> String:
	if stats == null:
		return ""
	return _rank_line_for_card_id(String(stats.platform_card_id))

## 统一的三维攻防格式：轻甲空攻击/防御
func _format_unit_stats_summary(stats: UnitStats, cur_hp: float = -1.0, extra_suffix: String = "") -> String:
	if stats == null:
		return ""
	var hp_text: String
	if cur_hp >= 0.0:
		hp_text = "HP %.0f/%.0f" % [cur_hp, stats.max_hp]
	else:
		hp_text = "HP %.0f" % stats.max_hp
	
	# 三维攻击/防御：轻/甲/空
	var atk_light: float = stats.attack_light if stats.attack_light > 0.001 else 0.0
	var atk_armor: float = stats.attack_armor if stats.attack_armor > 0.001 else 0.0
	var atk_air: float = stats.attack_air if stats.attack_air > 0.001 else 0.0
	
	var def_light: float = stats.defense_light if stats.defense_light > 0.001 else 0.0
	var def_armor: float = stats.defense_armor if stats.defense_armor > 0.001 else 0.0
	var def_air: float = stats.defense_air if stats.defense_air > 0.001 else 0.0
	
	# 格式：HP 100｜攻 10/5/8｜防 3/5/2｜射程 120｜攻速 1.0
	var line: String = "%s｜攻 %.0f/%.0f/%.0f｜防 %.0f/%.0f/%.0f｜射程 %.0f｜攻速 %.2f%s" % [
		hp_text,
		atk_light, atk_armor, atk_air,
		def_light, def_armor, def_air,
		stats.attack_range,
		stats.attack_interval,
		extra_suffix,
	]
	return line

func _enemy_surface_combat_stats(unit: Node) -> Array:
	var hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var dmg: float = float(unit.get("attack_damage")) if "attack_damage" in unit else 0.0
	var rng: float = float(unit.get("attack_range")) if "attack_range" in unit else 0.0
	var itv: float = float(unit.get("attack_interval")) if "attack_interval" in unit else 1.0
	var def: float = 0.0
	if "stats" in unit and unit.stats != null:
		var st: UnitStats = unit.stats
		if dmg == 0.0:
			dmg = st.attack_damage
		if rng == 0.0:
			rng = st.attack_range
		if _is_construct_unit_script(unit):
			itv = st.attack_interval
		def = st.defense
	return [hp, dmg, rng, itv, def]

func _format_enemy_combat_summary(unit: Node, scombat: Array, extra_suffix: String = "") -> String:
	var hp: float = float(scombat[0]) if scombat.size() > 0 else 0.0
	var dmg: float = float(scombat[1]) if scombat.size() > 1 else 0.0
	var rng: float = float(scombat[2]) if scombat.size() > 2 else 0.0
	var itv: float = float(scombat[3]) if scombat.size() > 3 else 1.0
	var def: float = float(scombat[4]) if scombat.size() > 4 else 0.0
	if "stats" in unit and unit.stats != null:
		return _format_unit_stats_summary(unit.stats as UnitStats, hp, extra_suffix)
	var line1: String = "HP %.0f｜防 %.0f｜攻 %.0f｜射程 %.0f｜攻速 %.2f%s" % [hp, def, dmg, rng, itv, extra_suffix]
	return line1

func _show_enemy_phase_driver(unit: Node) -> void:
	var mname: String = str(unit.get("master_name")) if "master_name" in unit else "相位师"
	name_label.text = "敌方相位师基地"
	type_label.text = "【%s】· 相位场驱动器" % mname
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var mx_hp: float = float(unit.get("max_hp")) if "max_hp" in unit else 1.0
	summary_label.text = "基地 HP %.0f / %.0f" % [cur_hp, mx_hp]
	var lines: Array[String] = []
	lines.append("摧毁敌方相位场驱动器即可获胜；对方会持续生产战斗单位。")
	if GameManager and GameManager.has_method("get_current_phase_master"):
		var cfg: Dictionary = GameManager.get_current_phase_master()
		if not cfg.is_empty():
			var disp: String = str(cfg.get("name", mname))
			if disp != mname and not disp.is_empty():
				lines.append("档案名：%s" % disp)
			var fac: String = str(cfg.get("faction", ""))
			if not fac.is_empty():
				lines.append("所属势力：%s" % fac)
			var title: String = str(cfg.get("title", ""))
			if not title.is_empty():
				lines.append("称号：%s" % title)
			var eq: Dictionary = cfg.get("equipment", {}) as Dictionary
			var plats: Array = eq.get("platforms", []) as Array
			var weps: Array = eq.get("weapons", []) as Array
			if not plats.is_empty() or not weps.is_empty():
				lines.append("上场装备：平台种类 %d · 武器种类 %d（由其基地持续部署）" % [plats.size(), weps.size()])
	desc_label.text = "\n".join(lines)
	flavor_label.text = "“相位师的意志锚定在这片场上。”"

func _show_enemy_construct_unit(unit: Node) -> void:
	var stats: UnitStats = unit.stats
	var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
	if card_res != null and not card_res.display_name.is_empty():
		name_label.text = card_res.display_name
	else:
		name_label.text = "敌方构装单位"
	var platform_name := card_res.display_name if card_res != null and not card_res.display_name.is_empty() else DefaultCards.get_platform_display_name(stats.platform_type)
	var weapon_label_text: String = ""
	if stats.weapons.size() > 0:
		var weapon_names: Array = []
		for w in stats.weapons:
			if not (w is Dictionary):
				continue
			var cfg: Dictionary = w
			if not cfg.has("weapon_type"):
				continue
			var wt: int = int(cfg["weapon_type"])
			var wn := DefaultCards.get_weapon_display_name(wt)
			if not weapon_names.has(wn):
				weapon_names.append(wn)
		if weapon_names.size() > 0:
			weapon_label_text = " / ".join(weapon_names)
	if weapon_label_text.is_empty():
		weapon_label_text = DefaultCards.get_weapon_display_name(stats.weapon_type)
	type_label.text = "相位师部署 · %s / %s" % [platform_name, weapon_label_text]
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else stats.max_hp
	summary_label.text = _format_unit_stats_summary(stats, cur_hp)
	var base_desc := "由敌方相位师基地生产的构装单位，自动推进并攻击我方。"
	var passive_desc := _build_phase_law_effects_for_unit(unit, false)
	var active_desc := _build_active_law_effects_for_unit(unit, false)
	var star_desc := _build_star_enhancement_effects_for_stats(stats)
	if passive_desc.is_empty() and active_desc.is_empty() and star_desc.is_empty():
		desc_label.text = base_desc
	else:
		var full_desc := base_desc
		if not star_desc.is_empty():
			full_desc += "\n\n【星级强化】\n" + star_desc
		if not passive_desc.is_empty():
			full_desc += "\n\n【受到的相位法则影响】\n" + passive_desc
		if not active_desc.is_empty():
			full_desc += "\n\n【相关主动法则】\n" + active_desc
		desc_label.text = full_desc
	flavor_label.text = "“同一套装甲，站在战场的另一侧。”"

func _show_player_unit(unit: Node) -> void:
	var stats: UnitStats = unit.stats
	var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
	if card_res != null and not card_res.display_name.is_empty():
		name_label.text = card_res.display_name
	else:
		name_label.text = "我方单位"
	var platform_name := card_res.display_name if card_res != null and not card_res.display_name.is_empty() else DefaultCards.get_platform_display_name(stats.platform_type)
	var weapon_label_text: String = ""
	# 多武器：优先从 stats.weapons 里取出所有武器名称
	if stats.weapons.size() > 0:
		var weapon_names: Array = []
		for w in stats.weapons:
			if not (w is Dictionary):
				continue
			var cfg: Dictionary = w
			if not cfg.has("weapon_type"):
				continue
			var wt: int = int(cfg["weapon_type"])
			var wn := DefaultCards.get_weapon_display_name(wt)
			if not weapon_names.has(wn):
				weapon_names.append(wn)
		if weapon_names.size() > 0:
			weapon_label_text = " / ".join(weapon_names)
	# 退回到单武器显示
	if weapon_label_text.is_empty():
		weapon_label_text = DefaultCards.get_weapon_display_name(stats.weapon_type)
	type_label.text = "%s / %s" % [platform_name, weapon_label_text]
	summary_label.text = _format_unit_stats_summary(stats)
	var base_desc := "可选「进攻」向敌侧推进，或「防守」固守原位（仍可射击）；选中后点地面可沿 X 轴微调站位。"
	
	# 显示被动法则影响
	var passive_desc := _build_phase_law_effects_for_unit(unit, true)
	
	# 显示主动法则（我方装备的）
	var active_desc := _build_active_law_effects_for_unit(unit, true)
	
	var star_desc := _build_star_enhancement_effects_for_stats(stats)
	if passive_desc.is_empty() and active_desc.is_empty() and star_desc.is_empty():
		desc_label.text = base_desc
	else:
		var full_desc := base_desc
		if not star_desc.is_empty():
			full_desc += "\n\n【星级强化】\n" + star_desc
		if not passive_desc.is_empty():
			full_desc += "\n\n【被动法则加成】\n" + passive_desc
		if not active_desc.is_empty():
			full_desc += "\n\n【主动法则】\n" + active_desc
		desc_label.text = full_desc
	
	flavor_label.text = "“装甲军团永不疲倦。”"

func _set_stance_row_for_unit(unit: Node) -> void:
	if stance_row == null:
		return
	var ok: bool = (
		unit != null
		and is_instance_valid(unit)
		and unit.is_in_group("player_units")
		and _is_construct_unit_script(unit)
		and bool(unit.get("is_deploy_ghost")) == false
		and bool(unit.get("is_preview_mode")) == false
	)
	stance_row.visible = ok
	if not ok:
		return
	_sync_stance_buttons(unit)

func _sync_stance_buttons(unit: Node) -> void:
	if stance_attack_btn == null or stance_defend_btn == null:
		return
	var attacking: bool = true
	if unit.has_method("is_field_stance_attack"):
		attacking = unit.is_field_stance_attack()
	stance_attack_btn.disabled = attacking
	stance_defend_btn.disabled = not attacking

func _on_stance_attack_pressed() -> void:
	var u: Node = BattleInputState.current_selected_unit
	if u == null or not is_instance_valid(u) or not u.has_method("set_field_stance_attack"):
		return
	u.set_field_stance_attack()
	_sync_stance_buttons(u)

func _on_stance_defend_pressed() -> void:
	var u: Node = BattleInputState.current_selected_unit
	if u == null or not is_instance_valid(u) or not u.has_method("set_field_stance_defend"):
		return
	u.set_field_stance_defend()
	_sync_stance_buttons(u)

func _show_enemy_unit(unit: Node) -> void:
	# 检查是否是相位师单位
	var is_phase_master: bool = false
	var master_name: String = ""
	if "archetype_id" in unit and unit.archetype_id is String:
		if unit.archetype_id.begins_with("phase_master_"):
			is_phase_master = true
			master_name = unit.archetype_id.substr(13)  # 去掉 "phase_master_" 前缀
	
	if is_phase_master:
		# 相位师单位：显示平台+武器配置+相位师档案
		var master_cfg: Dictionary = {}
		var master_disp_name: String = ""
		var master_title: String = ""
		var master_level: int = 0
		var master_faction: String = ""
		var trait_lines: Array[String] = []
		if GameManager and GameManager.has_method("get_current_phase_master"):
			master_cfg = GameManager.get_current_phase_master()
		if master_cfg.is_empty():
			# 尝试从 id 反查
			var pm_id := "enemy_master_" + master_name.replace("unit_", "").lstrip("0")
			master_cfg = EnemyPhaseMasters.get_master_by_id(pm_id)
		if not master_cfg.is_empty():
			master_disp_name = str(master_cfg.get("name", ""))
			master_title = str(master_cfg.get("title", ""))
			master_level = int(master_cfg.get("level", 0))
			master_faction = str(master_cfg.get("faction", ""))
			# 提取特性
			var traits: Array = master_cfg.get("traits", []) as Array
			for t in traits:
				if t is Dictionary:
					var tn: String = str(t.get("name", ""))
					var td: String = str(t.get("description", ""))
					if not tn.is_empty():
						if not td.is_empty():
							trait_lines.append("◆ %s：%s" % [tn, td])
						else:
							trait_lines.append("◆ %s" % tn)

		# 名称栏
		if not master_disp_name.is_empty():
			name_label.text = master_disp_name
		else:
			name_label.text = "敌方相位师"
		# 称号+等级+势力
		var type_parts: Array[String] = []
		if not master_title.is_empty():
			type_parts.append(master_title)
		if master_level > 0:
			type_parts.append("Lv.%d" % master_level)
		var faction_names := {"steel": "钢铁", "thunder": "雷霆", "frost": "霜寒", "void": "虚空", "shadow": "暗影", "inferno": "炼狱"}
		if not master_faction.is_empty():
			var fn: String = faction_names.get(master_faction, master_faction)
			type_parts.append(fn)
		var type_text := " · ".join(type_parts)
		if type_text.is_empty():
			type_text = "【%s】" % master_name
		else:
			type_text = "【%s】%s" % [master_name, type_text]
		
		# 获取平台和武器信息
		var platform_name := "未知平台"
		var weapon_label_text := "未知武器"
		if "stats" in unit:
			var stats: UnitStats = unit.stats
			var pm_card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
			if pm_card_res != null and not pm_card_res.display_name.is_empty():
				platform_name = pm_card_res.display_name
			else:
				platform_name = DefaultCards.get_platform_display_name(stats.platform_type)
			if stats.weapons.size() > 0:
				var weapon_names: Array = []
				for w in stats.weapons:
					if not (w is Dictionary):
						continue
					var cfg: Dictionary = w
					if not cfg.has("weapon_type"):
						continue
					var wt: int = int(cfg["weapon_type"])
					var wn := DefaultCards.get_weapon_display_name(wt)
					if not weapon_names.has(wn):
						weapon_names.append(wn)
				if weapon_names.size() > 0:
					weapon_label_text = "/ ".join(weapon_names)
			else:
				weapon_label_text = DefaultCards.get_weapon_display_name(stats.weapon_type)
		
		type_label.text = "%s\n%s / %s" % [type_text, platform_name, weapon_label_text]
		
		var scombat: Array = _enemy_surface_combat_stats(unit)
		summary_label.text = _format_enemy_combat_summary(unit, scombat)
		
		# 显示被动法则影响
		var base_desc := "敌方相位师单位，拥有强大的战斗力。"
		if not trait_lines.is_empty():
			base_desc += "\n\n【相位师特性】\n" + "\n".join(trait_lines)
		var passive_desc := _build_phase_law_effects_for_unit(unit, false)
		var active_desc := _build_active_law_effects_for_unit(unit, false)
		if not passive_desc.is_empty():
			base_desc += "\n\n【被动法则影响】\n" + passive_desc
		if not active_desc.is_empty():
			base_desc += "\n\n【敌方被动法则】\n" + active_desc
		desc_label.text = base_desc
		
		flavor_label.text = "\u201c相位师的威严不容侵犯。\u201d"
	elif _is_construct_unit_script(unit) and "stats" in unit and unit.stats != null:
		_show_enemy_construct_unit(unit)
	else:
		# 普通敌方单位
		name_label.text = "敌方单位"
		var type_text := "敌方单位"
		var era_text := ""
		var tags_text := ""
		var speed_val: float = 0.0
		var weapon_type_val: int = -1
		if "archetype_id" in unit and unit.archetype_id is String:
			var cfg = EnemyArchetypes.get_config(unit.archetype_id)
			if not cfg.is_empty():
				type_text = cfg.get("display_name", type_text)
				era_text = str(cfg.get("era", ""))
				speed_val = float(cfg.get("speed", 0.0))
				weapon_type_val = int(cfg.get("weapon_type", -1))
				var tags: Array = cfg.get("tags", []) as Array
				if not tags.is_empty():
					var tag_names: Array = []
					for t in tags:
						var ts: String = str(t)
						match ts:
							"infantry": tag_names.append("步兵")
							"vehicle": tag_names.append("载具")
							"turret": tag_names.append("炮塔")
							"sustained": tag_names.append("持续射击")
							"frontline": tag_names.append("前排")
							"backline": tag_names.append("后排")
							"fast": tag_names.append("高速")
							"heavy": tag_names.append("重型")
							"elite": tag_names.append("精英")
							"boss": tag_names.append("Boss")
							_: tag_names.append(ts)
					tags_text = " · ".join(tag_names)
		if "wave_index" in unit:
			type_text += " · 波次 %d" % unit.wave_index
		# 时代标签
		var era_names := ["一战", "二战", "冷战", "现代", "近未来"]
		if not era_text.is_empty():
			var ei: int = int(era_text)
			if ei >= 0 and ei < era_names.size():
				type_text += " · %s" % era_names[ei]
		if not tags_text.is_empty():
			type_text += "\n类型：%s" % tags_text
		if weapon_type_val >= 0:
			type_text += "\n武装：%s" % DefaultCards.get_weapon_display_name(weapon_type_val)
		type_label.text = type_text
		var s2: Array = _enemy_surface_combat_stats(unit)
		# 补充移速显示
		var speed_display: float = float(unit.get("speed")) if "speed" in unit else speed_val
		var speed_text: String = ""
		if speed_display < -0.1:
			speed_text = "｜移速 %.0f" % absf(speed_display)
		elif speed_display > 0.1:
			speed_text = "｜移速 %.0f" % speed_display
		summary_label.text = _format_enemy_combat_summary(unit, s2, speed_text)
		var base_desc := "向左推进的敌方单位，会优先攻击我方单位，其次攻击相位场驱动器。"
		var law_desc := _build_phase_law_effects_for_unit(unit, false)
		if law_desc.is_empty():
			desc_label.text = base_desc
		else:
			desc_label.text = base_desc + "\n\n受到的相位法则影响：\n" + law_desc
		flavor_label.text = "\u201c相位裂隙的另一侧，总有人在看着你。\u201d"

func _build_phase_law_effects_for_unit(unit: Node, is_player_side: bool) -> String:
	if not PhaseLawManager or not ("equipped_passive_laws" in PhaseLawManager):
		return ""
	var law_ids: Array = PhaseLawManager.equipped_passive_laws
	if law_ids.is_empty():
		return ""
	var lines: Array[String] = []
	for law_id in law_ids:
		var cfg: Dictionary = PhaseLaws.get_by_id(String(law_id))
		if cfg.is_empty():
			continue
		var rt: Dictionary = cfg.get("runtime_tags", {})
		if rt.is_empty():
			continue
		var affects_unit: bool = _law_targets_this_unit(rt, unit, is_player_side)
		if not affects_unit:
			continue
		var effect: String = String(rt.get("effect", ""))
		var value: float = float(rt.get("value", 0.0))
		var duration: float = float(rt.get("duration", 0.0))
		var radius: float = float(rt.get("radius", 0.0))
		var law_name: String = String(cfg.get("name", law_id))
		var line := _format_effect_line(law_name, effect, value, duration, radius)
		lines.append(line)
	var result: String = "\n".join(lines)
	return result

## 构建主动法则效果描述（仅显示会影响该单位的法则）
func _build_active_law_effects_for_unit(unit: Node, is_player_side: bool) -> String:
	if not PhaseLawManager or not ("equipped_active_laws" in PhaseLawManager):
		return ""
	var law_ids: Array = PhaseLawManager.equipped_active_laws
	if law_ids.is_empty():
		return ""
	
	var lines: Array[String] = []
	for law_id in law_ids:
		var cfg: Dictionary = PhaseLaws.get_by_id(String(law_id))
		if cfg.is_empty():
			continue
		var rt: Dictionary = cfg.get("runtime_tags", {})
		var affects_unit: bool = _law_targets_this_unit(rt, unit, is_player_side)
		if not affects_unit:
			continue
		var law_name: String = String(cfg.get("name", law_id))
		var desc: String = String(cfg.get("description", ""))
		var cost: Dictionary = cfg.get("battle_cost", {})
		var nano_cost: int = int(cost.get("nano", 0))
		var energy_cost: float = float(cost.get("energy", 0))
		var value: float = float(rt.get("value", 0.0))
		var duration: float = float(rt.get("duration", 0.0))
		var radius: float = float(rt.get("radius", 0.0))
		
		var line := _format_effect_line(law_name, String(rt.get("effect", "")), value, duration, radius)
		if nano_cost > 0:
			line += " (消耗%d纳米)" % nano_cost
		if energy_cost > 0:
			line += " (消耗%.0f能量)" % energy_cost
		if not desc.is_empty():
			line += "：%s" % desc
		lines.append(line)
	
	if lines.is_empty():
		return ""
	return "\n".join(lines)

func _build_star_enhancement_effects_for_stats(stats: UnitStats) -> String:
	if stats == null or BlueprintManager == null or not BlueprintManager.has_method("get_star_enhancement_lines"):
		return ""
	var lines: Array[String] = []
	if not String(stats.platform_card_id).is_empty():
		var plat_star: int = 1
		if BlueprintManager.has_method("get_blueprint_star"):
			plat_star = maxi(1, BlueprintManager.get_blueprint_star(stats.platform_card_id))
		var p_enh: Array[String] = BlueprintManager.get_star_enhancement_lines(stats.platform_card_id, plat_star)
		for line in p_enh:
			lines.append("平台 %s" % line)
	for wid_raw in stats.weapon_card_ids:
		var wid: String = String(wid_raw)
		if wid.is_empty():
			continue
		var w_star: int = 1
		if BlueprintManager.has_method("get_blueprint_star"):
			w_star = maxi(1, BlueprintManager.get_blueprint_star(wid))
		var w_enh: Array[String] = BlueprintManager.get_star_enhancement_lines(wid, w_star)
		for line in w_enh:
			lines.append("武器 %s" % line)
	return "\n".join(lines)
