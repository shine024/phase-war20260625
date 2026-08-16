## 效果实验室面板 — UI 全在 .tscn 里，本脚本只处理逻辑
extends Control

const USC := preload("res://scripts/battle/unit_status_collector.gd")
const PhaseInstrAbilities := preload("res://managers/battle/phase_instrument_abilities.gd")
const PhaseInstrDefs := preload("res://data/phase_instruments.gd")
const CPS := preload("res://data/card_periodic_skills.gd")
const CPSEngine := preload("res://managers/battle/card_periodic_skill_engine.gd")
const FactionFX := preload("res://scripts/battle/faction_skill_effect_handler.gd")

var _player_getter: Callable = Callable()
var _enemy_getter: Callable = Callable()
var _battlefield: Node = null
var _aura_mgr: Node = null
var _cps_engine: RefCounted = null
var _ability_src_player: Node = null
var _ability_src_enemy: Node = null
var _injected_log: Array = []
var _toggle_states: Dictionary = {}  # "type:id:side" -> Button，跟踪 toggle 激活状态
var _phase_btn_player: BaseButton = null  # 当前激活的玩家侧相位仪 toggle 按钮（生产系统每侧只能一个）
var _phase_btn_enemy: BaseButton = null   # 当前激活的敌方侧相位仪 toggle 按钮

@onready var _overlay: Panel = $Overlay
@onready var _target_opt: OptionButton = $Overlay/LeftPanel/TargetOpt
@onready var _dur_spin: SpinBox = $Overlay/LeftPanel/DurSpin
@onready var _stack_spin: SpinBox = $Overlay/LeftPanel/StackSpin
@onready var _effect_vbox: VBoxContainer = $Overlay/LeftPanel/EffectScroll/EffectVBox
@onready var _player_status: RichTextLabel = $Overlay/LeftPanel/PlayerStatus
@onready var _enemy_status: RichTextLabel = $Overlay/LeftPanel/EnemyStatus
@onready var _check_info: RichTextLabel = $Overlay/RightPanel/CheckInfo
@onready var _review_edit: TextEdit = $Overlay/RightPanel/ReviewEdit
@onready var _save_hint: Label = $Overlay/RightPanel/SaveHint

const _DEBUFF_INFO := {
	0: {"name": "破甲", "short": "每层降低15%防御"},
	1: {"name": "标记", "short": "受到伤害+25%"},
	2: {"name": "暴击眼", "short": "被暴击率+30%"},
	3: {"name": "反炮标记", "short": "被反炮火力锁定"},
	4: {"name": "化学毒伤", "short": "每秒固定毒伤"},
	5: {"name": "燃烧", "short": "每秒=基础x层数"},
	6: {"name": "电磁干扰", "short": "攻速/暴击/闪避降低"},
	7: {"name": "纳米病毒", "short": "每秒按最大血量2%流失"},
	8: {"name": "减速光环", "short": "攻速降低40%"},
	9: {"name": "电子屏蔽", "short": "攻击大幅受限"},
	10: {"name": "无人机标记", "short": "受无人机伤害+30%"},
	11: {"name": "攻速削弱", "short": "势力攻速-50%"},
	12: {"name": "防御削弱", "short": "势力防御-40%"},
}
const _DEBUFF_KINDS := [0,1,2,3,4,5,6,7,8,9,10,11,12]
const _STACKABLE_KINDS := [0,4,5]

const _AURA_INFO := [
	{"cat":0,"name":"医疗治疗光环","short":"每3秒治疗友军8%血量"},
	{"cat":1,"name":"运输维修光环","short":"每3秒维修机械友军12%"},
	{"cat":2,"name":"侦查暴击光环","short":"暴击+8% 命中+5"},
	{"cat":3,"name":"雷达侦测光环","short":"暴击+10%"},
	{"cat":4,"name":"堡垒防御光环","short":"减伤+6% 防御+2"},
	{"cat":5,"name":"指挥全局光环","short":"攻/速/暴全场加成"},
]

const _FACTION_INFO := [
	{"id":"fac_aspd","name":"攻速削弱","short":"攻速-50%"},
	{"id":"fac_def","name":"防御削弱","short":"防御-40%"},
	{"id":"fac_shield","name":"周期护盾","short":"add_shield 30%最大血量"},
	{"id":"fac_heal","name":"周期治疗","short":"heal 30%最大血量"},
	{"id":"fac_invuln","name":"周期无敌","short":"_faction_invuln_active=true"},
	{"id":"fac_deathsave","name":"死亡救赎","short":"接种->hp=0->try_death_save"},
]

const _CLEAR_META_KEYS := [
	"_armor_break_stacks","_armor_break_ratio","_marked_until","_mark_vuln_bonus",
	"_crit_marked_until","_crit_mark_bonus","_counter_marked_by",
	"_chem_until","_chem_dps","_chem_stacks","_burn_until","_burn_base_dps","_burn_stacks",
	"_ecm_debuffed_until","_ecm_attack_speed_penalty","_ecm_crit_penalty","_ecm_dodge_penalty",
	"_nano_until","_nano_pct","_slow_aura_until","_slow_aura_mult","_jammed_until",
	"_drone_marked_until","_drone_mark_vuln","_faction_aspd_debuff","_faction_def_debuff",
	"_faction_invuln_active","_faction_invuln_remaining",
	"radar_buffed","scout_crit_buffed","fortress_def_buffed","command_buffed","carrier_repair_buffed",
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Overlay/LeftPanel/ClearPlayerBtn.pressed.connect(_on_clear_player)
	$Overlay/LeftPanel/ClearEnemyBtn.pressed.connect(_on_clear_enemy)
	$Overlay/LeftPanel/CollapseBtn.pressed.connect(_on_collapse)
	$Overlay/RightPanel/SaveBtn.pressed.connect(_on_save_report)
	_populate_effects()
	_set_open(false)  # 默认收起


func _exit_tree() -> void:
	# 离开检查场时清除相位仪能力状态（防静态状态泄漏到其他场景）
	PhaseInstrAbilities.clear_owner_state(PhaseInstrAbilities.Owner.PLAYER)
	PhaseInstrAbilities.clear_owner_state(PhaseInstrAbilities.Owner.ENEMY)
	if _ability_src_player != null: _ability_src_player.queue_free()
	if _ability_src_enemy != null: _ability_src_enemy.queue_free()


func configure(player_getter: Callable, enemy_getter: Callable, battlefield: Node) -> void:
	_player_getter = player_getter
	_enemy_getter = enemy_getter
	_battlefield = battlefield

func toggle() -> void:
	_set_open(not _overlay.visible)

func notify_units_changed() -> void:
	pass

func _set_open(open: bool) -> void:
	if _overlay != null:
		_overlay.visible = open
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	var hint = get_node_or_null("CollapsedHint")
	if hint != null: hint.visible = not open


# ============================================================
# 填充效果列表
# ============================================================
func _populate_effects() -> void:
	_add_section_title("◆ 负面状态（13种）— 点[我方/敌方]切换注入/取消")
	for kind in _DEBUFF_KINDS:
		var info: Dictionary = _DEBUFF_INFO[kind]
		var desc: String = info["short"]
		if kind in _STACKABLE_KINDS: desc += " [层数生效]"
		_add_toggle_row(info["name"], desc, "debuff", kind)

	_add_section_title("◆ 光环（6种）— 点[我方/敌方]切换注册/注销")
	for entry in _AURA_INFO:
		var cat: int = int(entry["cat"])
		_add_toggle_row(String(entry["name"]), String(entry["short"]), "aura", cat)

	_add_section_title("◆ 相位仪主动技能（9种）— 点[我方/敌方]切换开/关（每侧只能一个）")
	for ab in _collect_phase_defs():
		var atype: String = String(ab.get("type", ""))
		var nm: String = ab.get("name", String(ab.get("id", "")))
		var desc: String = ab.get("description", "")
		var title: String = "%s %s [%s]" % [_phase_emoji(atype), nm, atype]
		if atype == "passive":
			_add_row_disabled(title, desc)
		else:
			_add_phase_toggle_row(title, desc, ab)

	_add_section_title("◆ 卡牌周期技能（20种）— 点[触发]立即施放")
	for sid in CPS.get_all_skill_ids():
		var sid_s: String = String(sid)
		var sk: Dictionary = CPS.get_skill(sid_s)
		if sk.is_empty(): continue
		var nm: String = sk.get("name", sid_s)
		var mark: String = " ★" if bool(sk.get("is_ultimate", false)) else ""
		var title: String = "%s %s%s" % [_family_emoji(sk.get("family", "")), nm, mark]
		var desc: String = "id=%s type=%s" % [sid_s, String(sk.get("effect", {}).get("type", ""))]
		_add_row_btn(title, desc, "触发", Callable(self, "_on_trigger_card_skill").bind(sid_s))

	_add_section_title("◆ 势力技能效果（6种）— 点[我方/敌方]切换注入/取消")
	for entry in _FACTION_INFO:
		_add_toggle_row(String(entry["name"]), String(entry["short"]), "faction", String(entry["id"]))


func _add_section_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	l.custom_minimum_size.y = 22
	_effect_vbox.add_child(l)


## toggle 行：标题 + 描述 + [我方(toggle)] + [敌方(toggle)]
## 点一次=高亮+注入，再点=取消高亮+清除
func _add_toggle_row(title: String, desc: String, etype: String, eid: Variant) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 12)
	tl.custom_minimum_size.x = 130
	row.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 11)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
	# 我方 toggle 按钮（CheckButton 带滑块，直观显示开/关状态）
	var bp := CheckButton.new()
	bp.text = "我方"
	bp.add_theme_font_size_override("font_size", 12)
	bp.custom_minimum_size.x = 72
	bp.pressed.connect(_on_toggle.bind(etype, eid, true, bp))
	row.add_child(bp)
	# 敌方 toggle 按钮
	var be := CheckButton.new()
	be.text = "敌方"
	be.add_theme_font_size_override("font_size", 12)
	be.custom_minimum_size.x = 72
	be.pressed.connect(_on_toggle.bind(etype, eid, false, be))
	row.add_child(be)
	_effect_vbox.add_child(row)


## 相位仪能力 toggle 行：点[我方/敌方]开=触发（高亮），再点=关闭（清除该侧能力）
## 注意：生产系统每侧 owner 只能持有一个 active_ability，所以同侧激活新能力会替换旧能力。
func _add_phase_toggle_row(title: String, desc: String, ab: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 12)
	tl.custom_minimum_size.x = 140
	row.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 11)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
	var bp := CheckButton.new()
	bp.text = "我方"
	bp.add_theme_font_size_override("font_size", 12)
	bp.custom_minimum_size.x = 72
	bp.pressed.connect(_on_toggle_phase.bind(ab, true, bp))
	row.add_child(bp)
	var be := CheckButton.new()
	be.text = "敌方"
	be.add_theme_font_size_override("font_size", 12)
	be.custom_minimum_size.x = 72
	be.pressed.connect(_on_toggle_phase.bind(ab, false, be))
	row.add_child(be)
	_effect_vbox.add_child(row)


## 相位仪能力 toggle 回调：开=触发该能力，关=清除该侧能力状态
func _on_toggle_phase(ab: Dictionary, as_player: bool, btn: BaseButton) -> void:
	var owner: int = PhaseInstrAbilities.Owner.PLAYER if as_player else PhaseInstrAbilities.Owner.ENEMY
	var old_btn: BaseButton = _phase_btn_player if as_player else _phase_btn_enemy
	if btn.button_pressed:
		# 激活：生产系统每侧只能一个能力，先取消旧按钮高亮 + 清旧状态
		if old_btn != null and old_btn != btn and old_btn.button_pressed:
			old_btn.button_pressed = false
		PhaseInstrAbilities.clear_owner_state(owner)
		_trigger_phase_ability(ab, as_player)
		if as_player: _phase_btn_player = btn
		else: _phase_btn_enemy = btn
		_injected_log.append("[相位仪] %s -> %s" % [String(ab.get("name", "")), "我方" if as_player else "敌方"])
	else:
		# 关闭：清除该侧能力状态（停止周期触发 / 纳米虫群 / 狂暴等）
		PhaseInstrAbilities.clear_owner_state(owner)
		if as_player: _phase_btn_player = null
		else: _phase_btn_enemy = null


## toggle 回调：根据按钮状态注入或清除
func _on_toggle(etype: String, eid: Variant, to_player: bool, btn: BaseButton) -> void:
	var unit: Node = _player_unit() if to_player else _enemy_unit()
	if unit == null:
		btn.button_pressed = false  # 无单位时不允许激活
		return
	var key := "%s:%s:%s" % [etype, str(eid), "p" if to_player else "e"]
	if btn.button_pressed:
		# 激亮 → 注入
		_toggle_states[key] = btn
		var stacks := int(_stack_spin.value)
		var dur := float(_dur_spin.value)
		match etype:
			"debuff":
				_apply_debuff(unit, int(eid), stacks, dur)
				_injected_log.append("[负面] %s -> %s" % [_DEBUFF_INFO[int(eid)]["name"], _side(unit)])
			"aura":
				var a := _aura()
				if a != null: a.register_aura(unit, int(eid))
				_apply_aura_meta(unit, int(eid))
				_injected_log.append("[光环] %s -> %s" % [_aura_name(int(eid)), _side(unit)])
			"faction":
				_apply_faction(unit, String(eid), dur)
				_injected_log.append("[势力] %s -> %s" % [_faction_name(String(eid)), _side(unit)])
	else:
		# 取消 → 清除
		_toggle_states.erase(key)
		match etype:
			"debuff": _clear_debuff_meta(unit, int(eid))
			"aura":
				var a := _aura()
				if a != null: a.unregister_aura(unit, int(eid))
				_clear_aura_meta(unit, int(eid))
			"faction": _clear_faction_meta(unit, String(eid))


func _apply_aura_meta(unit: Node, cat: int) -> void:
	match cat:
		1: unit.set_meta("carrier_repair_buffed", true)
		2: unit.set_meta("scout_crit_buffed", true)
		3: unit.set_meta("radar_buffed", true)
		4: unit.set_meta("fortress_def_buffed", true)
		5: unit.set_meta("command_buffed", true)

func _clear_aura_meta(unit: Node, cat: int) -> void:
	match cat:
		1: _safe_rm(unit, "carrier_repair_buffed")
		2: _safe_rm(unit, "scout_crit_buffed")
		3: _safe_rm(unit, "radar_buffed")
		4: _safe_rm(unit, "fortress_def_buffed")
		5: _safe_rm(unit, "command_buffed")

func _clear_debuff_meta(unit: Node, kind: int) -> void:
	match kind:
		0: _safe_rm(unit, "_armor_break_stacks"); _safe_rm(unit, "_armor_break_ratio")
		1: _safe_rm(unit, "_marked_until"); _safe_rm(unit, "_mark_vuln_bonus")
		2: _safe_rm(unit, "_crit_marked_until"); _safe_rm(unit, "_crit_mark_bonus")
		3: _safe_rm(unit, "_counter_marked_by")
		4: _safe_rm(unit, "_chem_until"); _safe_rm(unit, "_chem_dps"); _safe_rm(unit, "_chem_stacks")
		5: _safe_rm(unit, "_burn_until"); _safe_rm(unit, "_burn_base_dps"); _safe_rm(unit, "_burn_stacks")
		6: _safe_rm(unit, "_ecm_debuffed_until"); _safe_rm(unit, "_ecm_attack_speed_penalty"); _safe_rm(unit, "_ecm_crit_penalty"); _safe_rm(unit, "_ecm_dodge_penalty")
		7: _safe_rm(unit, "_nano_until"); _safe_rm(unit, "_nano_pct")
		8: _safe_rm(unit, "_slow_aura_until"); _safe_rm(unit, "_slow_aura_mult")
		9: _safe_rm(unit, "_jammed_until")
		10: _safe_rm(unit, "_drone_marked_until"); _safe_rm(unit, "_drone_mark_vuln")
		11: _safe_rm(unit, "_faction_aspd_debuff")
		12: _safe_rm(unit, "_faction_def_debuff")

func _clear_faction_meta(unit: Node, fid: String) -> void:
	match fid:
		"fac_aspd": _safe_rm(unit, "_faction_aspd_debuff")
		"fac_def": _safe_rm(unit, "_faction_def_debuff")
		"fac_invuln": _safe_rm(unit, "_faction_invuln_active"); _safe_rm(unit, "_faction_invuln_remaining")

func _safe_rm(unit: Node, key: String) -> void:
	if unit != null and is_instance_valid(unit) and unit.has_meta(key):
		unit.remove_meta(key)


func _faction_name(fid: String) -> String:
	for e in _FACTION_INFO:
		if String(e["id"]) == fid: return String(e["name"])
	return fid

func _add_row_btn(title: String, desc: String, btn_text: String, callable: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 12)
	tl.custom_minimum_size.x = 140
	row.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 11)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
	var b := Button.new()
	b.text = btn_text
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size.x = 56
	b.pressed.connect(callable)
	row.add_child(b)
	_effect_vbox.add_child(row)

func _add_row_btns(title: String, desc: String, btns: Array) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 12)
	tl.custom_minimum_size.x = 140
	row.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 11)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
	for bi in btns:
		var b := Button.new()
		b.text = String(bi[0])
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size.x = 48
		b.pressed.connect(bi[1])
		row.add_child(b)
	_effect_vbox.add_child(row)

func _add_row_disabled(title: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26
	row.modulate.a = 0.5
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 12)
	tl.custom_minimum_size.x = 140
	row.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 11)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
	var b := Button.new()
	b.text = "被动"
	b.disabled = true
	row.add_child(b)
	_effect_vbox.add_child(row)


# ============================================================
# 注入逻辑
# ============================================================


func _apply_debuff(unit: Node, kind: int, stacks: int, dur: float) -> void:
	var ns: float = Time.get_ticks_msec() / 1000.0
	var nm: int = Time.get_ticks_msec()
	match kind:
		0: unit.set_meta("_armor_break_stacks", stacks); unit.set_meta("_armor_break_ratio", 0.15)
		1: unit.set_meta("_marked_until", ns + dur); unit.set_meta("_mark_vuln_bonus", 0.25)
		2: unit.set_meta("_crit_marked_until", ns + dur); unit.set_meta("_crit_mark_bonus", 0.30)
		3: unit.set_meta("_counter_marked_by", _other(unit))
		4: unit.set_meta("_chem_until", ns + dur); unit.set_meta("_chem_dps", 30.0); unit.set_meta("_chem_stacks", stacks)
		5: unit.set_meta("_burn_until", ns + dur); unit.set_meta("_burn_base_dps", 50.0); unit.set_meta("_burn_stacks", stacks)
		6: unit.set_meta("_ecm_debuffed_until", ns + dur); unit.set_meta("_ecm_attack_speed_penalty", 0.4)
		7: unit.set_meta("_nano_until", ns + dur); unit.set_meta("_nano_pct", 0.02)
		8: unit.set_meta("_slow_aura_until", ns + dur); unit.set_meta("_slow_aura_mult", 0.6)
		9: unit.set_meta("_jammed_until", ns + dur)
		10: unit.set_meta("_drone_marked_until", ns + dur); unit.set_meta("_drone_mark_vuln", 0.3)
		11: FactionFX._apply_on_hit_debuff(unit, {"attack_speed_reduction": 0.5, "duration": dur})
		12: FactionFX._apply_on_hit_debuff(unit, {"defense_reduction": 0.4, "duration": dur})





func _apply_faction(unit: Node, fid: String, dur: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var stats = unit.get("stats") if "stats" in unit else null
	match fid:
		"fac_aspd": FactionFX._apply_on_hit_debuff(unit, {"attack_speed_reduction": 0.5, "duration": dur})
		"fac_def": FactionFX._apply_on_hit_debuff(unit, {"defense_reduction": 0.4, "duration": dur})
		"fac_shield":
			if unit.has_method("add_shield") and stats != null:
				unit.add_shield(float(stats.max_hp) * 0.3)
		"fac_heal":
			if unit.has_method("heal") and stats != null:
				unit.heal(float(stats.max_hp) * 0.3)
		"fac_invuln":
			unit.set_meta("_faction_invuln_active", true)
			unit.set_meta("_faction_invuln_remaining", dur)
		"fac_deathsave":
			if stats != null:
				FactionFX.apply_setup_effects(stats, [{"death_save": {"pct": 0.5, "once": true}}])
				if "hp" in unit:
					unit.hp = 0.0
				FactionFX.try_death_save(unit)


func _trigger_phase_ability(ab: Dictionary, as_player: bool) -> void:
	if _battlefield == null: return
	var demo: Dictionary = ab.duplicate(true)
	if String(demo.get("type", "")) == "periodic":
		var p: Dictionary = demo.get("params", {})
		p["interval"] = 3.0
		demo["params"] = p
	var owner: int = PhaseInstrAbilities.Owner.PLAYER if as_player else PhaseInstrAbilities.Owner.ENEMY
	var src: Node = _ensure_src(as_player)
	src.set_ability(demo)
	PhaseInstrumentAbilities.on_battle_start(src, _battlefield, owner)

func _on_trigger_card_skill(skill_id: String) -> void:
	if _cps_engine == null: _init_cps()
	if _cps_engine == null: return
	var sk: Dictionary = CPS.get_skill(skill_id)
	if sk.is_empty(): return
	_cps_engine._execute_effect(sk)
	_injected_log.append("[周期技能] %s" % String(sk.get("name", skill_id)))

func _init_cps() -> void:
	if _battlefield == null: return
	var pn: Node = _battlefield.get_node_or_null("PlayerUnits")
	var en: Node = _battlefield.get_node_or_null("EnemyUnits")
	if pn == null or en == null: return
	_cps_engine = CPSEngine.new()
	_cps_engine.setup({"player_units_node": pn, "enemy_units_node": en, "skill_manager": null, "battlefield": _battlefield})



func _on_clear_player() -> void: _clear_unit(_player_unit())
func _on_clear_enemy() -> void: _clear_unit(_enemy_unit())
func _clear_unit(unit: Node) -> void:
	if unit == null: return
	for k in _CLEAR_META_KEYS:
		if unit.has_meta(k): unit.remove_meta(k)
	var a: Node = _aura()
	if a != null:
		for t in a.get_unit_aura_types(unit): a.unregister_aura(unit, int(t))

func _on_collapse() -> void: _set_open(false)


# ============================================================
# 文档保存
# ============================================================
func _on_save_report() -> void:
	var dir := DirAccess.open("res://docs/")
	if dir != null and not dir.dir_exists("effect_check_reports"): dir.make_dir("effect_check_reports")
	var d := Time.get_datetime_dict_from_system()
	var ts := "%04d%02d%02d_%02d%02d%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]
	var readable := "%04d-%02d-%02d %02d:%02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]
	var path := "res://docs/effect_check_reports/effect_check_%s.md" % ts

	var c := "# 效果检查报告\n\n## 基本信息\n"
	c += "- 检查时间：%s\n" % readable
	c += "- 场景：战斗效果检查场（combat_check）\n"
	c += "- 我方单位：%s\n" % _unit_desc(_player_unit())
	c += "- 敌方单位：%s\n" % _unit_desc(_enemy_unit())
	c += "\n## 已注入的效果\n"
	if _injected_log.is_empty():
		c += "（本次未注入任何效果）\n"
	else:
		for i in range(_injected_log.size()):
			c += "%d. %s\n" % [i + 1, String(_injected_log[i])]
	c += "\n## 当前双方激活状态\n"
	c += "**我方：**\n```\n%s\n```\n" % _status_text(_player_unit())
	c += "**敌方：**\n```\n%s\n```\n" % _status_text(_enemy_unit())
	c += "\n## 检查评价\n"
	var review := _review_edit.text if _review_edit != null else ""
	c += review if not review.is_empty() else "（未输入评价）"
	c += "\n"

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_save_hint.text = "保存失败"; _save_hint.visible = true; return
	f.store_string(c); f.close()
	_save_hint.text = "已保存: effect_check_%s.md" % ts; _save_hint.visible = true
	_injected_log.clear()


# ============================================================
# 实时刷新
# ============================================================
func _process(_delta: float) -> void:
	if _overlay == null or not _overlay.visible:
		var hint = get_node_or_null("CollapsedHint")
		if hint != null:
			hint.text = "效果面板已收起 | 我方%d项 敌方%d项 | 再点按钮展开" % [_count(_player_unit()), _count(_enemy_unit())]
		return
	if _player_status == null: return
	_player_status.text = _fmt_status(_player_unit(), "我方", Color(0.3, 0.9, 0.4))
	_enemy_status.text = _fmt_status(_enemy_unit(), "敌方", Color(0.95, 0.4, 0.4))
	if _check_info != null:
		_check_info.text = "检查时间：%s\n我方：%s\n敌方：%s\n已注入：%d项" % [
			Time.get_time_string_from_system(), _unit_short(_player_unit()), _unit_short(_enemy_unit()), _injected_log.size()]


# ============================================================
# 工具
# ============================================================
func _player_unit() -> Node:
	if _player_getter.is_valid():
		var u = _player_getter.call()
		if u != null and is_instance_valid(u): return u
	return null

func _enemy_unit() -> Node:
	if _enemy_getter.is_valid():
		var u = _enemy_getter.call()
		if u != null and is_instance_valid(u): return u
	return null

func _other(unit: Node) -> Node:
	return _enemy_unit() if unit == _player_unit() else _player_unit()

func _target_units() -> Array:
	match _target_opt.selected:
		0: return [_player_unit()]
		1: return [_enemy_unit()]
		_: return [_player_unit(), _enemy_unit()]

func _side(unit: Node) -> String:
	return "我方" if unit == _player_unit() else "敌方"

func _aura() -> Node:
	if _aura_mgr == null or not is_instance_valid(_aura_mgr):
		_aura_mgr = get_node_or_null("/root/AuraManager")
	return _aura_mgr

func _aura_name(cat: int) -> String:
	for e in _AURA_INFO:
		if int(e["cat"]) == cat: return String(e["name"])
	return "光环%d" % cat

func _ensure_src(for_player: bool) -> Node:
	if for_player:
		if _ability_src_player == null: _ability_src_player = _AbilitySource.new()
		return _ability_src_player
	if _ability_src_enemy == null: _ability_src_enemy = _AbilitySource.new()
	return _ability_src_enemy

func _collect_phase_defs() -> Array:
	return [
		PhaseInstrDefs.ability_artillery_barrage(7), PhaseInstrDefs.ability_nuclear_bombardment(7),
		PhaseInstrDefs.ability_nano_swarm(7), PhaseInstrDefs.ability_mega_shield(7),
		PhaseInstrDefs.ability_rage_buff(7), PhaseInstrDefs.ability_phantom_clone(7),
		PhaseInstrDefs.ability_piercing_shot(7), PhaseInstrDefs.ability_free_energy(7),
		PhaseInstrDefs.ability_fortress_bulwark(7),
	]

func _fmt_status(unit: Node, label: String, col: Color) -> String:
	var h := col.to_html(false)
	if unit == null: return "[color=#%s]%s：[/color][color=#888](未生成)[/color]" % [h, label]
	var e: Array = USC.collect(unit)
	if e.is_empty(): return "[color=#%s]%s：[/color][color=#888]无激活状态[/color]" % [h, label]
	var lines: PackedStringArray = ["[color=#%s]%s（%d项）：[/color]" % [h, label, e.size()]]
	for entry in e: lines.append(USC.format_status_line(entry, unit))
	return "\n".join(lines)

func _status_text(unit: Node) -> String:
	if unit == null: return "(未生成)"
	var e: Array = USC.collect(unit)
	if e.is_empty(): return "无激活状态"
	var lines: Array = []
	for entry in e: lines.append(USC.format_status_line(entry, unit))
	return "\n".join(lines)

func _count(unit: Node) -> int:
	if unit == null: return 0
	return USC.collect(unit).size()

func _unit_desc(unit: Node) -> String:
	if unit == null: return "(未选择)"
	var s = unit.get("stats") if "stats" in unit else null
	var hp := float(unit.get("hp")) if "hp" in unit else 0.0
	var mx := float(s.max_hp) if s != null else hp
	return "%s (HP %.0f/%.0f)" % [unit.name, hp, mx]

func _unit_short(unit: Node) -> String:
	return String(unit.name) if unit != null else "(未选择)"

func _phase_emoji(a: String) -> String:
	match a:
		"periodic": return "🔁"
		"on_battle_start": return "💥"
		"passive": return "🛡️"
	return "⚡"

func _family_emoji(f: String) -> String:
	match f:
		"steel": return "⚙️"
		"flame": return "🔥"
		"thunder": return "⚡"
		"void": return "🌀"
	return "•"


class _AbilitySource extends Node:
	var _ab: Dictionary = {}
	func set_ability(ab: Dictionary) -> void: _ab = ab
	func get_active_ability() -> Dictionary: return _ab
