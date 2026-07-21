extends Panel
## v7.x 玩家相位师详细面板（单分量公式）
##
## 展示玩家相位师的总战力、星级、展示等级、相位仪/战斗卡战力分解/符文构成。
## 入口：bottom_instrument_bar 的 PhaseLevelLabel 点击（main.gd 路由）。
##
## v7.x 单分量公式：总战力 = Σ 每张装备卡加成后战力。
## 相位仪/符文/势力/词条的加成已体现在每张卡的战力里，不再单独显示分量。

signal closed()

const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var summary_label: Label = $Margin/VBox/SummaryLabel
@onready var detail_label: Label = $Margin/VBox/ScrollContainer/DetailLabel
@onready var close_btn: Button = $Margin/VBox/TitleBar/CloseButton

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	# v7.x: 装备/符文变化时实时刷新（非战斗场景也能反映养成变化）
	if SignalBus and SignalBus.has_signal("phase_slots_changed"):
		SignalBus.phase_slots_changed.connect(_on_data_changed)
	if SignalBus and SignalBus.has_signal("player_phase_master_power_changed"):
		SignalBus.player_phase_master_power_changed.connect(_on_power_changed)

func open_panel() -> void:
	refresh()
	visible = true

func refresh() -> void:
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pm == null:
		summary_label.text = "相位仪管理器未加载"
		detail_label.text = ""
		return
	var ev: Dictionary = MasterPlayerAssembler.evaluate_player_stars(pm)
	if ev.is_empty():
		summary_label.text = "无法评估玩家相位师"
		detail_label.text = ""
		return
	# ── 标题 ──
	title_label.text = "相位师档案"
	# ── 摘要行 ──
	var lvl: int = int(ev.get("display_level", 15))
	var stars: int = int(ev.get("stars", 3))
	var star_name: String = str(ev.get("star_name", ""))
	var raw: float = float(ev.get("raw_total_score", 0.0))
	summary_label.text = "Lv.%d · %d★ %s\n总战力 %d" % [lvl, stars, star_name, int(raw)]
	# ── 单分量公式：卡战力分解 ──
	var lines: Array[String] = []
	lines.append("═══ 战斗卡战力（Σ=%d）═══" % int(raw))
	var card_breakdown: Array = ev.get("card_breakdown", [])
	if card_breakdown.is_empty():
		# 无卡或 breakdown 未注入：回退到 loadouts 直接显示
		_append_platform_lines_fallback(lines, pm)
	else:
		for cb in card_breakdown:
			var cname: String = String(cb.get("name", "?"))
			var enhance: int = int(cb.get("enhance", 0))
			var power: float = float(cb.get("power", 0.0))
			var enhance_str: String = " +%d强化" % enhance if enhance > 0 else ""
			lines.append("  %s%s → 战力 %d" % [cname, enhance_str, int(power)])
	lines.append("")
	lines.append("═══ 构成明细 ═══")
	_append_instrument_lines(lines, pm)
	_append_rune_lines(lines, pm)
	_append_ability_lines(lines, pm)
	detail_label.text = "\n".join(lines)

func _append_platform_lines_fallback(lines: Array, pm: Node) -> void:
	# card_breakdown 未注入时的兜底（直接从 loadouts 读卡）
	var loadouts: Array = pm.get_loadouts() if pm.has_method("get_loadouts") else []
	if loadouts.is_empty():
		lines.append("  （未装备战斗卡）")
		return
	for ld in loadouts:
		if not (ld is Dictionary):
			continue
		var plat = ld.get("platform", null)
		if plat == null or not (plat is CardResource):
			continue
		var card: CardResource = plat
		var display_name: String = String(card.display_name) if "display_name" in card else card.card_id
		var enhance: int = int(card.enhance_level) if "enhance_level" in card else 0
		var enhance_str: String = " +%d强化" % enhance if enhance > 0 else ""
		lines.append("  %s%s" % [display_name, enhance_str])

func _append_instrument_lines(lines: Array, pm: Node) -> void:
	var cfg: Dictionary = pm.get_current_instrument() if pm.has_method("get_current_instrument") else {}
	if cfg.is_empty():
		lines.append("相位仪：未装备")
		return
	var inst_name: String = String(cfg.get("name", "?"))
	var star: int = int(cfg.get("star", 0))
	lines.append("相位仪：%s ★%d" % [inst_name, star])
	# 相位场属性点（展示玩家投入的养成，数值加成已体现在上方卡战力里）
	var pf_bonus: Dictionary = pm.get_phase_field_total_bonus() if pm.has_method("get_phase_field_total_bonus") else {}
	if not pf_bonus.is_empty():
		var pf_parts: Array[String] = []
		for key in pf_bonus.keys():
			var pct := int(round(float(pf_bonus[key]) * 100.0))
			if pct != 0:
				pf_parts.append("%s:+%d%%" % [key, pct])
			if not pf_parts.is_empty():
				lines.append("  相位场：" + " ".join(pf_parts))

func _append_rune_lines(lines: Array, pm: Node) -> void:
	var rune_slots: Array = pm.get_rune_slots() if pm.has_method("get_rune_slots") else []
	var active_count: int = 0
	for slot_v in rune_slots:
		if slot_v != null and not str(slot_v).is_empty():
			active_count += 1
	lines.append("符文：%d / %d 槽位" % [active_count, rune_slots.size()])
	var active_rw: Array = pm.get_active_runewords() if pm.has_method("get_active_runewords") else []
	if not active_rw.is_empty():
		var rw_names: Array[String] = []
		for rw in active_rw:
			var rw_name: String = String(rw.get("name", String(rw.get("id", ""))))
			if not rw_name.is_empty():
				rw_names.append(rw_name)
		if not rw_names.is_empty():
			lines.append("  符文之语：" + " / ".join(rw_names))

func _append_ability_lines(lines: Array, pm: Node) -> void:
	var ability: Dictionary = pm.get_active_ability() if pm.has_method("get_active_ability") else {}
	if ability.is_empty():
		lines.append("主动能力：无")
		return
	var ability_name: String = String(ability.get("name", ""))
	var ability_desc: String = String(ability.get("description", ""))
	lines.append("主动能力：%s" % ability_name)
	if not ability_desc.is_empty():
		lines.append("  %s" % ability_desc)

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _on_data_changed(_slots: Variant) -> void:
	if visible:
		refresh()

func _on_power_changed(_raw: float, _compressed: float, _stars: int, _star_name: String, _level: int) -> void:
	if visible:
		refresh()

func _input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
