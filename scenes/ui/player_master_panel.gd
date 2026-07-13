extends Panel
## v7.x 玩家相位师详细面板
##
## 展示玩家相位师的 9 维战力分解、星级、展示等级、相位仪/战斗卡/符文构成。
## 入口：bottom_instrument_bar 的 PhaseLevelLabel 点击（main.gd 路由）。
##
## 类比敌方 card_info_panel._show_enemy_phase_driver 的展示风格，
## 但玩家侧数据来自 MasterPlayerAssembler.evaluate_player_stars(PhaseInstrumentManager)。

signal closed()

const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")

@onready var title_label: Label = $Margin/VBox/TitleBar/TitleLabel
@onready var summary_label: Label = $Margin/VBox/SummaryLabel
@onready var detail_label: Label = $Margin/VBox/ScrollContainer/DetailLabel
@onready var close_btn: Button = $Margin/VBox/TitleBar/CloseButton

const DIM_ORDER: Array = [
	"instrument", "equipment_slots", "runes",
]
const DIM_LABELS: Dictionary = {
	"instrument": "相位仪战力", "equipment_slots": "装备卡战力", "runes": "符文战力",
}
const DIM_WEIGHTS: Dictionary = {
	"instrument": "直接相加", "equipment_slots": "直接相加", "runes": "直接相加",
}

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
	var compressed: float = 0.0  # v7.x: 已移除压缩
	summary_label.text = "Lv.%d · %d★ %s\n总战力 %d" % [lvl, stars, star_name, int(raw)]
	# ── 9 维分解 ──
	var lines: Array[String] = []
	lines.append("═══ 3 分量战力分解 ═══")
	var scores: Dictionary = ev.get("scores", {})
	for key in DIM_ORDER:
		var s: float = float(scores.get(key, 0.0))
		var label: String = String(DIM_LABELS.get(key, key))
		var weight: String = String(DIM_WEIGHTS.get(key, ""))
		var weighted: float = s * _weight_value(key)
		lines.append("  %-14s %6d × %s = %6d" % [label, int(s), weight, int(weighted)])
	lines.append("")
	lines.append("═══ 构成明细 ═══")
	_append_instrument_lines(lines, pm)
	_append_platform_lines(lines, pm)
	_append_rune_lines(lines, pm)
	_append_ability_lines(lines, pm)
	detail_label.text = "\n".join(lines)

func _weight_value(key: String) -> float:
	# v7.x: 3 分量直接相加，无权重系数（权重=1.0）
	return 1.0

func _append_instrument_lines(lines: Array, pm: Node) -> void:
	var cfg: Dictionary = pm.get_current_instrument() if pm.has_method("get_current_instrument") else {}
	if cfg.is_empty():
		lines.append("相位仪：未装备")
		return
	var inst_name: String = String(cfg.get("name", "?"))
	var star: int = int(cfg.get("star", 0))
	lines.append("相位仪：%s ★%d" % [inst_name, star])
	# 相位场属性点
	var pf_bonus: Dictionary = pm.get_phase_field_total_bonus() if pm.has_method("get_phase_field_total_bonus") else {}
	if not pf_bonus.is_empty():
		var pf_parts: Array[String] = []
		for key in pf_bonus.keys():
			var pct := int(round(float(pf_bonus[key]) * 100.0))
			if pct != 0:
				pf_parts.append("%s:+%d%%" % [key, pct])
		if not pf_parts.is_empty():
			lines.append("  相位场：" + " ".join(pf_parts))

func _append_platform_lines(lines: Array, pm: Node) -> void:
	lines.append("战斗卡：")
	var loadouts: Array = pm.get_loadouts() if pm.has_method("get_loadouts") else []
	if loadouts.is_empty():
		lines.append("  （空）")
		return
	# 预计算每张卡的真实战力（含相位仪加成）
	var master: Dictionary = MasterPlayerAssembler.build_player_master_dict(pm)
	var powers: Array = master.get("_player_platform_powers", [])
	for i in range(loadouts.size()):
		var ld: Dictionary = loadouts[i] if loadouts[i] is Dictionary else {}
		var plat = ld.get("platform", null)
		if plat == null or not (plat is CardResource):
			continue
		var card: CardResource = plat
		var display_name: String = String(card.display_name) if "display_name" in card else card.card_id
		var power: float = float(powers[i]) if i < powers.size() else 0.0
		var enhance: int = int(card.enhance_level) if "enhance_level" in card else 0
		var enhance_str: String = " +%d强化" % enhance if enhance > 0 else ""
		lines.append("  %s%s → 战力 %d" % [display_name, enhance_str, int(power)])

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
