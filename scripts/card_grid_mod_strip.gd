extends Node2D
class_name CardGridModStrip
## v7.x 改造图标迷你条：装备了改造模块的单位在卡图下方显示彩色矢量图标。
##
## 与 buff_strip（光环 buff）区分：
##   - buff_strip：读 meta（radar_buffed 等），表示"被光环影响"
##   - mod_strip：读 card.mods / archetype tags，表示"自身装备的改造"
##
## 我方：读 source_instance_id → InstanceRegistry 实例卡 .mods（带养成）
## 敌方：无 mods 字段，从 archetype tags 推断改造倾向（粗略分类）

const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")

enum ModKind {
	ATTACK,    # 攻击类（穿甲/暴击/对X加成）
	DEFENSE,   # 防御类（减伤/护盾/闪避）
	SPEED,     # 速度类（攻速/移速）
	SPECIAL,   # 特殊类（溅射/吸血/燃烧）
	AURA,      # 光环类（指挥/侦查）
}

const ICON_WIDTH_FRAC: float = 0.18
const ICON_GAP_FRAC: float = 0.05

const _MOD_ORDER: Array[ModKind] = [
	ModKind.ATTACK,
	ModKind.DEFENSE,
	ModKind.SPEED,
	ModKind.SPECIAL,
	ModKind.AURA,
]

const _MOD_COLORS: Dictionary = {
	ModKind.ATTACK: Color(1.0, 0.42, 0.35, 0.95),
	ModKind.DEFENSE: Color(0.35, 0.88, 1.0, 0.95),
	ModKind.SPEED: Color(0.45, 1.0, 0.55, 0.95),
	ModKind.SPECIAL: Color(1.0, 0.68, 0.28, 0.95),
	ModKind.AURA: Color(0.92, 0.72, 1.0, 0.95),
}

var _card_art_width: float = 0.0
var _active_kinds: Array[ModKind] = []
var _icon_layout: Array[Dictionary] = []
var _total_height: float = 0.0


## 从单位收集改造类型（我方读 mods，敌方读 tags 推断）
static func collect_mod_kinds(unit: Node) -> Array[ModKind]:
	var kinds: Array[ModKind] = []
	if unit == null or not is_instance_valid(unit):
		return kinds
	# 我方：读 source_instance_id → InstanceRegistry 实例卡 .mods
	var instance_id: String = ""
	if unit.has_meta("source_instance_id"):
		instance_id = String(unit.get_meta("source_instance_id"))
	if not instance_id.is_empty():
		var reg: Node = Engine.get_main_loop().root.get_node_or_null("InstanceRegistry")
		if reg != null and reg.has_method("get_instance"):
			var inst = reg.get_instance(instance_id)
			if inst != null and "mods" in inst:
				var mods: Array = inst.mods
				for m in mods:
					if m is Dictionary:
						kinds.append_array(_classify_mod_effect(m))
			# 去重
		return _dedup(kinds)
	# 敌方：从 archetype tags 推断改造倾向
	if unit.has_method("get") and "archetype_id" in unit:
		var aid: String = String(unit.get("archetype_id"))
		if not aid.is_empty():
			return _infer_mod_kinds_from_archetype(aid)
	return _dedup(kinds)


## 按改造 effect 字段分类
static func _classify_mod_effect(m: Dictionary) -> Array[ModKind]:
	var out: Array[ModKind] = []
	var effects: Dictionary = m.get("effects", {})
	for key in effects:
		var k := String(key)
		# 攻击类
		if k.find("attack") >= 0 or k.find("crit") >= 0 or k.find("penetration") >= 0 or k.find("armor_pen") >= 0:
			if ModKind.ATTACK not in out:
				out.append(ModKind.ATTACK)
			continue
		# 防御类
		if k.find("defense") >= 0 or k.find("damage_reduction") >= 0 or k.find("dodge") >= 0 or k.find("shield") >= 0:
			if ModKind.DEFENSE not in out:
				out.append(ModKind.DEFENSE)
			continue
		# 速度类
		if k.find("speed") >= 0 or k.find("interval") >= 0 or k.find("move") >= 0:
			if ModKind.SPEED not in out:
				out.append(ModKind.SPEED)
			continue
		# 光环类
		if k.find("ally_") >= 0 or k.find("aura") >= 0 or k.find("formation") >= 0 or k.find("command") >= 0:
			if ModKind.AURA not in out:
				out.append(ModKind.AURA)
			continue
		# 其余归特殊
		if ModKind.SPECIAL not in out:
			out.append(ModKind.SPECIAL)
	return out


## 敌方 archetype 推断：按 archetype_id 关键词粗分类
static func _infer_mod_kinds_from_archetype(aid: String) -> Array[ModKind]:
	var out: Array[ModKind] = []
	var lower := aid.to_lower()
	# 精英/boss 默认有攻击+防御
	if lower.find("elite") >= 0 or lower.find("boss") >= 0:
		out.append(ModKind.ATTACK)
		out.append(ModKind.DEFENSE)
	# 装甲单位有防御
	if lower.find("armor") >= 0 or lower.find("tank") >= 0 or lower.find("heavy") >= 0:
		if ModKind.DEFENSE not in out:
			out.append(ModKind.DEFENSE)
	# 侦察/快速单位有速度
	if lower.find("recon") >= 0 or lower.find("scout") >= 0 or lower.find("fast") >= 0:
		out.append(ModKind.SPEED)
	return out


static func _dedup(kinds: Array[ModKind]) -> Array[ModKind]:
	var seen: Dictionary = {}
	var out: Array[ModKind] = []
	for k in kinds:
		if not seen.has(k):
			seen[k] = true
			out.append(k)
	return out


static func mod_signature(unit: Node) -> String:
	var parts: PackedStringArray = []
	for kind: ModKind in collect_mod_kinds(unit):
		parts.append(str(int(kind)))
	return "|".join(parts)


func get_total_height() -> float:
	return _total_height


func rebuild(active_kinds: Array[ModKind], card_art_width: float = -1.0) -> void:
	_card_art_width = card_art_width if card_art_width > 1.0 else CardGridBattleLayout.battle_card_width_px()
	_active_kinds = active_kinds.duplicate()
	_icon_layout.clear()
	_total_height = 0.0
	if _active_kinds.is_empty():
		visible = false
		queue_redraw()
		return
	visible = true
	var count: int = _active_kinds.size()
	var icon_width_frac: float = ICON_WIDTH_FRAC
	var icon_gap_frac: float = ICON_GAP_FRAC
	var total_frac: float = float(count) * icon_width_frac + float(maxi(count - 1, 0)) * icon_gap_frac
	if total_frac > 0.90:
		var s: float = 0.90 / total_frac
		icon_width_frac *= s
		icon_gap_frac *= s
	var icon_size: float = _card_art_width * icon_width_frac
	var icon_gap: float = _card_art_width * icon_gap_frac
	var row_w: float = float(count) * icon_size + float(maxi(count - 1, 0)) * icon_gap
	var x0: float = -row_w * 0.5
	for i: int in range(count):
		var kind: ModKind = _active_kinds[i]
		_icon_layout.append({
			"kind": kind,
			"rect": Rect2(x0 + float(i) * (icon_size + icon_gap), 0.0, icon_size, icon_size),
			"color": _MOD_COLORS.get(kind, Color.WHITE),
		})
	_total_height = icon_size
	queue_redraw()


func _draw() -> void:
	for entry: Dictionary in _icon_layout:
		var r: Rect2 = entry["rect"] as Rect2
		var kind: ModKind = entry["kind"] as ModKind
		var col: Color = entry["color"] as Color
		var cx: float = r.position.x + r.size.x * 0.5
		var cy: float = r.position.y + r.size.y * 0.5
		var s: float = minf(r.size.x, r.size.y) * 0.40
		match kind:
			ModKind.ATTACK:
				_draw_attack_icon(cx, cy, s, col)
			ModKind.DEFENSE:
				_draw_defense_icon(cx, cy, s, col)
			ModKind.SPEED:
				_draw_speed_icon(cx, cy, s, col)
			ModKind.SPECIAL:
				_draw_special_icon(cx, cy, s, col)
			ModKind.AURA:
				_draw_aura_icon(cx, cy, s, col)


# 攻击：向上箭头（红）
func _draw_attack_icon(cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - s),
		Vector2(cx + s * 0.7, cy + s * 0.4),
		Vector2(cx + s * 0.3, cy + s * 0.4),
		Vector2(cx + s * 0.3, cy + s * 0.9),
		Vector2(cx - s * 0.3, cy + s * 0.9),
		Vector2(cx - s * 0.3, cy + s * 0.4),
		Vector2(cx - s * 0.7, cy + s * 0.4),
	])
	draw_colored_polygon(pts, col)


# 防御：盾牌（蓝）
func _draw_defense_icon(cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - s * 0.95),
		Vector2(cx + s * 0.75, cy - s * 0.5),
		Vector2(cx + s * 0.6, cy + s * 0.5),
		Vector2(cx, cy + s * 0.9),
		Vector2(cx - s * 0.6, cy + s * 0.5),
		Vector2(cx - s * 0.75, cy - s * 0.5),
	])
	draw_colored_polygon(pts, col)


# 速度：闪电（绿）
func _draw_speed_icon(cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx + s * 0.2, cy - s),
		Vector2(cx - s * 0.5, cy + s * 0.15),
		Vector2(cx - s * 0.05, cy + s * 0.15),
		Vector2(cx - s * 0.2, cy + s),
		Vector2(cx + s * 0.5, cy - s * 0.15),
		Vector2(cx + s * 0.05, cy - s * 0.15),
	])
	draw_colored_polygon(pts, col)


# 特殊：星形（橙）
func _draw_special_icon(cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(5):
		var outer_a: float = -PI * 0.5 + TAU * float(i) / 5.0
		var inner_a: float = outer_a + TAU / 10.0
		pts.append(Vector2(cx + cos(outer_a) * s, cy + sin(outer_a) * s))
		pts.append(Vector2(cx + cos(inner_a) * s * 0.42, cy + sin(inner_a) * s * 0.42))
	draw_colored_polygon(pts, col)


# 光环：同心圆（紫）
func _draw_aura_icon(cx: float, cy: float, s: float, col: Color) -> void:
	draw_arc(Vector2(cx, cy), s * 0.95, 0.0, TAU, 20, col, 1.4, true)
	draw_arc(Vector2(cx, cy), s * 0.55, 0.0, TAU, 16, col, 1.2, true)
	draw_circle(Vector2(cx, cy), s * 0.18, col)
