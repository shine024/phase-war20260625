extends RefCounted
class_name RankDisplayUi
## 军衔图标 + 名称：背包卡面、相位仪槽、战场单位信息共用

const RankRules = preload("res://data/rank_rules.gd")
const RankIcons = preload("res://scripts/rank_icons.gd")
const DefaultCards = preload("res://data/default_cards.gd")


static func resolve_from_card(card_id: String) -> Dictionary:
	var cid: String = String(card_id).strip_edges()
	if cid.is_empty():
		return {}
	if BlueprintManager and BlueprintManager.has_method("get_rank_info"):
		return (BlueprintManager.get_rank_info(cid) as Dictionary).duplicate(true)
	return {}


static func resolve_from_card_resource(card: CardResource) -> Dictionary:
	if card == null:
		return {}
	return resolve_from_card(String(card.card_id))


static func power_score_from_combat(max_hp: float, attack_damage: float, attack_interval: float) -> float:
	return maxf(50.0, max_hp * 0.28 + (attack_damage / maxf(attack_interval, 0.05)) * 2.2)


static func resolve_from_combat(max_hp: float, attack_damage: float, attack_interval: float, platform_type: int = -1) -> Dictionary:
	var base_rank: String = RankRules.get_base_rank(platform_type) if platform_type >= 0 else "corporal"
	var power: float = power_score_from_combat(max_hp, attack_damage, attack_interval)
	var rank_id: String = RankRules.get_rank_by_power(base_rank, power)
	return {
		"rank_id": rank_id,
		"rank_name": RankRules.get_rank_display_name(rank_id),
		"power_score": power,
	}


static func resolve_from_unit(unit: Node) -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	if "stats" in unit and unit.stats is UnitStats:
		var st: UnitStats = unit.stats as UnitStats
		if not String(st.platform_card_id).is_empty():
			var from_card: Dictionary = resolve_from_card(st.platform_card_id)
			if not from_card.is_empty():
				return from_card
		var dmg: float = st.attack_damage
		var itv: float = st.attack_interval
		if dmg <= 0.0 and st.weapons.size() > 0 and st.weapons[0] is Dictionary:
			var w0: Dictionary = st.weapons[0] as Dictionary
			dmg = float(w0.get("damage", dmg))
			itv = float(w0.get("fire_interval", w0.get("interval", itv)))
		return resolve_from_combat(st.max_hp, dmg, itv, st.platform_type)
	var hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var dmg2: float = float(unit.get("attack_damage")) if "attack_damage" in unit else 0.0
	var itv2: float = float(unit.get("attack_interval")) if "attack_interval" in unit else 1.0
	var mx: float = float(unit.get("max_hp")) if "max_hp" in unit else hp
	if hp > 0.0 or dmg2 > 0.0:
		return resolve_from_combat(maxi(mx, hp), dmg2, itv2)
	return {}


static func format_line(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	var rank_name: String = str(info.get("rank_name", "")).strip_edges()
	var power: float = float(info.get("power_score", 0.0))
	if rank_name.is_empty():
		return ""
	if power > 0.0:
			return "军衔 %s（战力 %d）" % [rank_name, int(power)]
	return "军衔 %s" % rank_name


static func append_tooltip_line(tooltip: String, card_id: String) -> String:
	var line: String = format_line(resolve_from_card(card_id))
	if line.is_empty():
		return tooltip
	if tooltip.is_empty():
		return line
	return tooltip + "\n" + line


static func create_badge(rank_id: String, show_name: bool = true, icon_px: int = 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = RankIcons.get_icon(rank_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.name = "RankIcon"
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	if show_name:
		var lbl := Label.new()
		lbl.name = "RankName"
		lbl.text = RankRules.get_rank_display_name(rank_id)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
	return row


static func clear_host(host: Control) -> void:
	if host == null:
		return
	for c in host.get_children():
		if is_instance_valid(c):
			c.queue_free()


static func apply_to_host(host: Control, info: Dictionary, icon_px: int = 18) -> void:
	clear_host(host)
	if host == null:
		return
	var rank_id: String = str(info.get("rank_id", "")).strip_edges()
	host.visible = not rank_id.is_empty()
	if rank_id.is_empty():
		return
	var badge: HBoxContainer = create_badge(rank_id, true, icon_px)
	host.add_child(badge)


static func attach_corner_badge(panel: Control, info: Dictionary, icon_px: int = 14, top_right: bool = false) -> void:
	if panel == null:
		return
	var old: Node = panel.get_node_or_null("RankCornerBadge")
	if old != null:
		old.queue_free()
	var rank_id: String = str(info.get("rank_id", "")).strip_edges()
	if rank_id.is_empty():
		return
	var badge: Control = create_badge(rank_id, false, icon_px)
	badge.name = "RankCornerBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v7.x：费用角标占左上角，段位移右上角（top_right=true）避免遮挡。
	if top_right:
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -2.0 - float(icon_px) - 2.0
		badge.offset_top = 2.0
		badge.offset_right = -2.0
		badge.offset_bottom = 2.0 + float(icon_px) + 2.0
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = 2.0
		badge.offset_top = 2.0
		badge.offset_right = 2.0 + float(icon_px) + 2.0
		badge.offset_bottom = 2.0 + float(icon_px) + 2.0
	panel.add_child(badge)
