extends RefCounted
class_name UnitStatusCollector
## 单位血条状态图标收集器：从单位 meta 收集当前激活的 buff/debuff，
## 返回有序 entries + signature（供 unit_hp_bar.gd 的 _draw 轮询渲染）。
##
## 数据源（全部是挂在单位节点上的 meta，无统一注册表、无 SignalBus 信号）：
##   module_effect_handler.gd —— 破甲/标记/暴击标注/化学/燃烧/电磁/纳米/减速/堡垒庇护/指挥光环/无人机标记
##   faction_skill_effect_handler.gd —— 势力攻速/防御 debuff、周期无敌
##   光环系统（与 card_grid_buff_strip.gd 对齐）—— radar/scout/fortress/command/carrier/mod_aura
##   construct_unit.gd —— 电子干扰(_jammed_until)
##
## v10(C4) 起时间戳已全局统一为秒制（Time.get_ticks_msec()/1000.0 基准；含 _ecm_debuffed_until
## 与 _jammed_until——原毫秒写入方已全部改秒）。无时间戳：_armor_break_stacks、光环 *_buffed bool、
## mod_aura_applied Array、_faction_* Dictionary（remaining 由 process_debuff_expirations 按 delta 递减）。

enum StatusKind {
	# ── DEBUFF（负向，kind < FIRST_BUFF）──
	ARMOR_BREAK,   # 破甲（可叠加层数）
	MARK,          # 标记易伤
	CRIT_MARK,     # 暴击眼
	COUNTER_MARK,  # 反炮标记
	CHEM,          # 化学/毒（可叠加层数）
	BURN,          # 燃烧（可叠加层数）
	ECM,           # 电磁/EMP
	NANO,          # 纳米病毒
	SLOW_AURA,     # 减速光环
	JAMMED,        # 电子干扰
	DRONE_MARK,    # 无人机标记
	FACTION_ASPD,  # 势力攻速 debuff
	FACTION_DEF,   # 势力防御 debuff
	FIRST_BUFF,    # ── 分界哨兵（不含实际状态，仅用于 is_buff 判定）──
	# ── BUFF（正向）──
	RADAR,         # 雷达光环
	SCOUT,         # 侦察光环
	FORTRESS,      # 堡垒防御光环
	COMMAND,       # 指挥光环（command_buffed 或 _command_aura_until 任一）
	               # v10(M7) 声明：二者是**两个不同来源**的指挥加成，非同一 buff 双表达——
	               # command_buffed = 平台 COMMAND 光环（CardAbilityManager，存活期持续）
	               # _command_aura_until = 改造 for_13_command_bunker 定时光环（MEH，1s 刷新）
	               # 仅显示层合并；战斗层各自独立消费（后者由 bullet.gd 暴击结算读取）
	CARRIER,       # 航母维修光环
	MOD_AURA,      # 改造光环
	FORT_SHELTER,  # 堡垒庇护（减伤）
	FACTION_INVULN,# 势力周期无敌
}

## 颜色字典：debuff 红/紫/橙/绿毒，buff 暖/绿/蓝/金
const STATUS_COLORS: Dictionary = {
	StatusKind.ARMOR_BREAK:   Color(1.00, 0.55, 0.20),  # 破甲-橙
	StatusKind.MARK:          Color(0.95, 0.45, 0.95),  # 标记-品红
	StatusKind.CRIT_MARK:     Color(1.00, 0.85, 0.30),  # 暴击眼-金
	StatusKind.COUNTER_MARK:  Color(0.80, 0.60, 1.00),  # 反炮-紫
	StatusKind.CHEM:          Color(0.55, 1.00, 0.35),  # 毒-绿
	StatusKind.BURN:          Color(1.00, 0.45, 0.20),  # 火-橙红
	StatusKind.ECM:           Color(0.40, 0.85, 1.00),  # 电-青
	StatusKind.NANO:          Color(0.75, 1.00, 0.40),  # 病毒-黄绿
	StatusKind.SLOW_AURA:     Color(0.45, 0.70, 1.00),  # 减速-蓝
	StatusKind.JAMMED:        Color(0.70, 0.55, 0.95),  # 干扰-淡紫
	StatusKind.DRONE_MARK:    Color(1.00, 0.60, 0.80),  # 无人机-粉
	StatusKind.FACTION_ASPD:  Color(1.00, 0.40, 0.35),  # 势攻速-红
	StatusKind.FACTION_DEF:   Color(1.00, 0.50, 0.30),  # 势防御-红橙
	StatusKind.RADAR:         Color(0.35, 0.88, 1.00),  # 与 card_grid_buff_strip 一致
	StatusKind.SCOUT:         Color(0.45, 1.00, 0.55),
	StatusKind.FORTRESS:      Color(1.00, 0.68, 0.28),
	StatusKind.COMMAND:       Color(0.92, 0.72, 1.00),
	StatusKind.CARRIER:       Color(0.30, 0.85, 1.00),
	StatusKind.MOD_AURA:      Color(0.85, 0.55, 1.00),
	StatusKind.FORT_SHELTER:  Color(0.50, 0.85, 1.00),  # 庇护-蓝
	StatusKind.FACTION_INVULN:Color(1.00, 0.85, 0.40),  # 无敌-金
}

## 状态中文名（情报卡"当前状态"区用）
const STATUS_NAMES: Dictionary = {
	StatusKind.ARMOR_BREAK:   "破甲",
	StatusKind.MARK:          "标记",
	StatusKind.CRIT_MARK:     "暴击眼",
	StatusKind.COUNTER_MARK:  "反炮标记",
	StatusKind.CHEM:          "化学毒伤",
	StatusKind.BURN:          "燃烧",
	StatusKind.ECM:           "电磁干扰",
	StatusKind.NANO:          "纳米病毒",
	StatusKind.SLOW_AURA:     "减速光环",
	StatusKind.JAMMED:        "电子屏蔽",
	StatusKind.DRONE_MARK:    "无人机标记",
	StatusKind.FACTION_ASPD:  "攻速削弱",
	StatusKind.FACTION_DEF:   "防御削弱",
	StatusKind.RADAR:         "雷达侦测",
	StatusKind.SCOUT:         "侦查暴击",
	StatusKind.FORTRESS:      "堡垒防御",
	StatusKind.COMMAND:       "指挥全局",
	StatusKind.CARRIER:       "运输维修",
	StatusKind.MOD_AURA:      "改造光环",
	StatusKind.FORT_SHELTER:  "堡垒庇护",
	StatusKind.FACTION_INVULN:"周期无敌",
}

## 可叠加状态（右下角显示层数数字）
const _STACKABLE: Array[int] = [
	StatusKind.ARMOR_BREAK,
	StatusKind.CHEM,
	StatusKind.BURN,
]


## 从单位 meta 收集当前激活状态，返回有序 entries：
##   debuff 组（按枚举序）在前 → buff 组（按枚举序）在后。
##   元素：{kind:int, stacks:int, color:Color, is_buff:bool}
static func collect(unit: Node) -> Array:
	var entries: Array = []
	if unit == null or not is_instance_valid(unit):
		return entries
	var now_sec: float = Time.get_ticks_msec() / 1000.0

	# ── DEBUFF 组 ──
	if unit.has_meta("_armor_break_stacks"):
		var st: int = int(unit.get_meta("_armor_break_stacks", 0))
		if st > 0:
			entries.append(_entry(StatusKind.ARMOR_BREAK, st))
	if unit.has_meta("_marked_until"):
		if float(unit.get_meta("_marked_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.MARK, 0))
	if unit.has_meta("_crit_marked_until"):
		if float(unit.get_meta("_crit_marked_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.CRIT_MARK, 0))
	if unit.has_meta("_counter_marked_by"):
		var src = unit.get_meta("_counter_marked_by")
		if is_instance_valid(src):
			entries.append(_entry(StatusKind.COUNTER_MARK, 0))
	if unit.has_meta("_chem_until"):
		if float(unit.get_meta("_chem_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.CHEM, int(unit.get_meta("_chem_stacks", 0))))
	if unit.has_meta("_burn_until"):
		if float(unit.get_meta("_burn_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.BURN, int(unit.get_meta("_burn_stacks", 0))))
	if unit.has_meta("_ecm_debuffed_until"):
		if float(unit.get_meta("_ecm_debuffed_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.ECM, 0))
	if unit.has_meta("_nano_until"):
		if float(unit.get_meta("_nano_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.NANO, 0))
	if unit.has_meta("_slow_aura_until"):
		if float(unit.get_meta("_slow_aura_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.SLOW_AURA, 0))
	if unit.has_meta("_jammed_until"):
		if float(unit.get_meta("_jammed_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.JAMMED, 0))
	if unit.has_meta("_drone_marked_until"):
		if float(unit.get_meta("_drone_marked_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.DRONE_MARK, 0))
	if unit.has_meta("_faction_aspd_debuff"):
		var d = unit.get_meta("_faction_aspd_debuff")
		if d is Dictionary and float(d.get("remaining", 0.0)) > 0.0:
			entries.append(_entry(StatusKind.FACTION_ASPD, 0))
	if unit.has_meta("_faction_def_debuff"):
		var d2 = unit.get_meta("_faction_def_debuff")
		if d2 is Dictionary and float(d2.get("remaining", 0.0)) > 0.0:
			entries.append(_entry(StatusKind.FACTION_DEF, 0))

	# ── BUFF 组 ──
	if bool(unit.get_meta("radar_buffed", false)):
		entries.append(_entry(StatusKind.RADAR, 0))
	if bool(unit.get_meta("scout_crit_buffed", false)):
		entries.append(_entry(StatusKind.SCOUT, 0))
	if bool(unit.get_meta("fortress_def_buffed", false)):
		entries.append(_entry(StatusKind.FORTRESS, 0))
	# COMMAND：command_buffed 或 _command_aura_until 任一为真（同一 buff 两种表达，合并显示）
	var cmd: bool = bool(unit.get_meta("command_buffed", false))
	if not cmd and unit.has_meta("_command_aura_until"):
		if float(unit.get_meta("_command_aura_until", 0.0)) > now_sec:
			cmd = true
	if cmd:
		entries.append(_entry(StatusKind.COMMAND, 0))
	if bool(unit.get_meta("carrier_repair_buffed", false)):
		entries.append(_entry(StatusKind.CARRIER, 0))
	if unit.has_meta("mod_aura_applied"):
		var applied = unit.get_meta("mod_aura_applied")
		if applied is Array and not applied.is_empty():
			entries.append(_entry(StatusKind.MOD_AURA, 0))
	if unit.has_meta("_fort_shelter_until"):
		if float(unit.get_meta("_fort_shelter_until", 0.0)) > now_sec:
			entries.append(_entry(StatusKind.FORT_SHELTER, 0))
	if bool(unit.get_meta("_faction_invuln_active", false)):
		entries.append(_entry(StatusKind.FACTION_INVULN, 0))
	return entries


## 由 entries 生成 signature（"kind:stacks" 用 '|' 连接），供血条去重判断是否需要重绘。
static func signature(entries: Array) -> String:
	var parts := PackedStringArray()
	for e in entries:
		var d: Dictionary = e
		parts.append("%d:%d" % [int(d.get("kind", -1)), int(d.get("stacks", 0))])
	return "|".join(parts)


## 该状态是否可叠加（需显示层数）
static func is_stackable(kind: int) -> bool:
	return _STACKABLE.has(kind)


# ============================================================================
#  情报卡"当前状态"区：名称 + 效果说明（读取 meta 实际数值）
# ============================================================================

## 安全读取 float meta
static func _fv(unit: Node, key: String, default: float) -> float:
	if unit == null or not is_instance_valid(unit) or not unit.has_meta(key):
		return default
	return float(unit.get_meta(key))


## 状态效果说明（带实际数值；无单位引用时退化为定性描述）
static func describe(kind: int, stacks: int, unit: Node) -> String:
	match kind:
		StatusKind.ARMOR_BREAK:
			return "每层降低 %.0f%% 防御" % (_fv(unit, "_armor_break_ratio", 0.0) * 100.0)
		StatusKind.MARK:
			return "受到伤害 +%.0f%%" % (_fv(unit, "_mark_vuln_bonus", 0.0) * 100.0)
		StatusKind.CRIT_MARK:
			return "被暴击率 +%.0f%%" % (_fv(unit, "_crit_mark_bonus", 0.0) * 100.0)
		StatusKind.COUNTER_MARK:
			return "被反炮火力锁定，承受额外反击伤害"
		StatusKind.CHEM:
			return "每秒受到 %d 毒伤" % int(_fv(unit, "_chem_dps", 0.0))
		StatusKind.BURN:
			return "每秒受到 %d 燃烧伤害" % int(_fv(unit, "_burn_base_dps", 0.0) * float(maxi(stacks, 1)))
		StatusKind.ECM:
			return "攻速 / 暴击 / 闪避降低"
		StatusKind.NANO:
			return "每秒按最大生命 %.1f%% 流失" % (_fv(unit, "_nano_pct", 0.0) * 100.0)
		StatusKind.SLOW_AURA:
			return "攻速降低 %.0f%%" % ((1.0 - _fv(unit, "_slow_aura_mult", 1.0)) * 100.0)
		StatusKind.JAMMED:
			return "电子屏蔽，攻击大幅受限"
		StatusKind.DRONE_MARK:
			return "受到无人机伤害 +%.0f%%" % (_fv(unit, "_drone_mark_vuln", 0.0) * 100.0)
		StatusKind.FACTION_ASPD:
			return "攻击速度降低"
		StatusKind.FACTION_DEF:
			return "防御属性降低"
		StatusKind.RADAR:
			return "命中与攻击范围提升"
		StatusKind.SCOUT:
			return "暴击率提升"
		StatusKind.FORTRESS:
			return "防御属性提升"
		StatusKind.COMMAND:
			var b := _fv(unit, "_command_aura_bonus", 0.0)
			if b > 0.0:
				return "暴击率 +%.0f%%" % (b * 100.0)
			return "全局指挥暴击加成"
		StatusKind.CARRIER:
			return "持续恢复生命"
		StatusKind.MOD_AURA:
			return "友军改造光环属性加成"
		StatusKind.FORT_SHELTER:
			return "受到伤害降低 %.0f%%" % (_fv(unit, "_fort_shelter_bonus", 0.0) * 100.0)
		StatusKind.FACTION_INVULN:
			return "周期性免疫伤害"
	return ""


## 格式化单条状态行："[正面/负面] 名称[ ×N]：效果说明"
static func format_status_line(entry: Dictionary, unit: Node) -> String:
	var kind: int = int(entry.get("kind", -1))
	var stacks: int = int(entry.get("stacks", 0))
	var is_buff: bool = bool(entry.get("is_buff", false))
	var tag: String = "[color=#7ee787][正面][/color]" if is_buff else "[color=#ff7b72][负面][/color]"
	var n: String = STATUS_NAMES.get(kind, "未知状态")
	if stacks > 1:
		n = "%s ×%d" % [n, stacks]
	var desc: String = describe(kind, stacks, unit)
	if desc.is_empty():
		return "%s %s" % [tag, n]
	return "%s %s：%s" % [tag, n, desc]


static func _entry(kind: int, stacks: int) -> Dictionary:
	return {
		"kind": kind,
		"stacks": stacks,
		"color": STATUS_COLORS.get(kind, Color.WHITE),
		"is_buff": kind >= int(StatusKind.FIRST_BUFF),
	}


# ============================================================================
#  矢量图标绘制（全部静态，由血条 _draw 调用；s 为半尺寸 ≈ min(w,h)*0.42）
#  6 个光环图标几何复用自 card_grid_buff_strip.gd（原为实例方法，此处改为静态）
# ============================================================================

## dispatch
static func draw_status_icon(kind: int, c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	match kind:
		StatusKind.ARMOR_BREAK:    _draw_armor_break(c, cx, cy, s, col)
		StatusKind.MARK:           _draw_mark(c, cx, cy, s, col)
		StatusKind.CRIT_MARK:      _draw_crit_mark(c, cx, cy, s, col)
		StatusKind.COUNTER_MARK:   _draw_counter_mark(c, cx, cy, s, col)
		StatusKind.CHEM:           _draw_chem(c, cx, cy, s, col)
		StatusKind.BURN:           _draw_burn(c, cx, cy, s, col)
		StatusKind.ECM:            _draw_ecm(c, cx, cy, s, col)
		StatusKind.NANO:           _draw_nano(c, cx, cy, s, col)
		StatusKind.SLOW_AURA:      _draw_slow_aura(c, cx, cy, s, col)
		StatusKind.JAMMED:         _draw_jammed(c, cx, cy, s, col)
		StatusKind.DRONE_MARK:     _draw_drone_mark(c, cx, cy, s, col)
		StatusKind.FACTION_ASPD:   _draw_faction_aspd(c, cx, cy, s, col)
		StatusKind.FACTION_DEF:    _draw_faction_def(c, cx, cy, s, col)
		StatusKind.RADAR:          _draw_radar(c, cx, cy, s, col)
		StatusKind.SCOUT:          _draw_scout(c, cx, cy, s, col)
		StatusKind.FORTRESS:       _draw_fortress(c, cx, cy, s, col)
		StatusKind.COMMAND:        _draw_command(c, cx, cy, s, col)
		StatusKind.CARRIER:        _draw_carrier(c, cx, cy, s, col)
		StatusKind.MOD_AURA:       _draw_mod_aura(c, cx, cy, s, col)
		StatusKind.FORT_SHELTER:   _draw_fort_shelter(c, cx, cy, s, col)
		StatusKind.FACTION_INVULN: _draw_faction_invuln(c, cx, cy, s, col)


# ── DEBUFF 图标 ──

# 破甲：盾形 + 裂纹
static func _draw_armor_break(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - s),
		Vector2(cx + s * 0.8, cy - s * 0.2),
		Vector2(cx + s * 0.6, cy + s * 0.9),
		Vector2(cx - s * 0.6, cy + s * 0.9),
		Vector2(cx - s * 0.8, cy - s * 0.2),
	])
	c.draw_colored_polygon(pts, Color(col.r, col.g, col.b, col.a * 0.55))
	c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), col, 1.2, true)
	# 裂纹（锯齿）
	c.draw_line(Vector2(cx - s * 0.2, cy - s * 0.4), Vector2(cx + s * 0.1, cy), col, 1.2, true)
	c.draw_line(Vector2(cx + s * 0.1, cy), Vector2(cx - s * 0.15, cy + s * 0.5), col, 1.2, true)


# 标记：完整环 + 粗十字穿过中心圆（与 radar 的断弧+细十字区分）
static func _draw_mark(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_arc(Vector2(cx, cy), s * 0.92, 0.0, TAU, 24, col, 1.2, true)
	c.draw_line(Vector2(cx - s, cy), Vector2(cx + s, cy), col, 1.6, true)
	c.draw_line(Vector2(cx, cy - s), Vector2(cx, cy + s), col, 1.6, true)
	c.draw_circle(Vector2(cx, cy), s * 0.16, col)


# 暴击眼：上下两段弧（眼睑）+ 中心瞳孔
static func _draw_crit_mark(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_arc(Vector2(cx, cy), s * 0.85, PI * 0.15, PI * 0.85, 10, col, 1.4, true)
	c.draw_arc(Vector2(cx, cy), s * 0.85, PI * 1.15, PI * 1.85, 10, col, 1.4, true)
	c.draw_circle(Vector2(cx, cy), s * 0.26, col)


# 反炮：环形箭头（弧 + 末端三角箭头）
static func _draw_counter_mark(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var a_end: float = PI * 1.9
	c.draw_arc(Vector2(cx, cy), s * 0.8, PI * 0.3, a_end, 16, col, 1.4, true)
	var ax: float = cx + cos(a_end) * s * 0.8
	var ay: float = cy + sin(a_end) * s * 0.8
	var tri := PackedVector2Array([
		Vector2(ax, ay),
		Vector2(ax + s * 0.45, ay - s * 0.05),
		Vector2(ax - s * 0.05, ay - s * 0.45),
	])
	c.draw_colored_polygon(tri, col)


# 化学：三滴圆液滴（三角排列）
static func _draw_chem(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_circle(Vector2(cx, cy - s * 0.55), s * 0.32, col)
	c.draw_circle(Vector2(cx - s * 0.55, cy + s * 0.4), s * 0.32, col)
	c.draw_circle(Vector2(cx + s * 0.55, cy + s * 0.4), s * 0.32, col)


# 燃烧：火焰尖头 + 内嵌小三角
static func _draw_burn(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var flame := PackedVector2Array([
		Vector2(cx, cy - s),
		Vector2(cx + s * 0.7, cy + s * 0.3),
		Vector2(cx + s * 0.3, cy + s * 0.9),
		Vector2(cx - s * 0.3, cy + s * 0.9),
		Vector2(cx - s * 0.7, cy + s * 0.3),
	])
	c.draw_colored_polygon(flame, col)
	var inner := PackedVector2Array([
		Vector2(cx, cy - s * 0.35),
		Vector2(cx + s * 0.28, cy + s * 0.35),
		Vector2(cx - s * 0.28, cy + s * 0.35),
	])
	c.draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, col.a * 0.5))


# 电磁/EMP：闪电（Z 形折线多边形）
static func _draw_ecm(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var bolt := PackedVector2Array([
		Vector2(cx + s * 0.05, cy - s),
		Vector2(cx - s * 0.4, cy - s * 0.05),
		Vector2(cx - s * 0.05, cy - s * 0.05),
		Vector2(cx - s * 0.15, cy + s),
		Vector2(cx + s * 0.4, cy + s * 0.05),
		Vector2(cx + s * 0.05, cy + s * 0.05),
	])
	c.draw_colored_polygon(bolt, col)


# 纳米：六边形轮廓 + 中心点
static func _draw_nano(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var hex := PackedVector2Array()
	for i in range(6):
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		hex.append(Vector2(cx + cos(a) * s * 0.92, cy + sin(a) * s * 0.92))
	c.draw_polyline(PackedVector2Array([hex[0], hex[1], hex[2], hex[3], hex[4], hex[5], hex[0]]), col, 1.3, true)
	c.draw_circle(Vector2(cx, cy), s * 0.2, col)


# 减速：双下箭头（雪佛兰×2）
static func _draw_slow_aura(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_line(Vector2(cx - s * 0.75, cy - s * 0.35), Vector2(cx, cy + s * 0.3), col, 1.4, true)
	c.draw_line(Vector2(cx, cy + s * 0.3), Vector2(cx + s * 0.75, cy - s * 0.35), col, 1.4, true)
	c.draw_line(Vector2(cx - s * 0.75, cy + s * 0.2), Vector2(cx, cy + s * 0.85), col, 1.4, true)
	c.draw_line(Vector2(cx, cy + s * 0.85), Vector2(cx + s * 0.75, cy + s * 0.2), col, 1.4, true)


# 电子干扰：三段同心信号弧 + 斜杠划掉
static func _draw_jammed(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_arc(Vector2(cx, cy), s * 0.4, -PI * 0.75, -PI * 0.25, 8, col, 1.1, true)
	c.draw_arc(Vector2(cx, cy), s * 0.7, -PI * 0.75, -PI * 0.25, 10, col, 1.1, true)
	c.draw_arc(Vector2(cx, cy), s * 1.0, -PI * 0.75, -PI * 0.25, 12, col, 1.1, true)
	c.draw_line(Vector2(cx - s * 0.85, cy + s * 0.85), Vector2(cx + s * 0.85, cy - s * 0.85), col, 1.4, true)


# 无人机标记：上方三角（无人机）+ 连线 + 下方目标点
static func _draw_drone_mark(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var drone := PackedVector2Array([
		Vector2(cx, cy - s),
		Vector2(cx - s * 0.45, cy - s * 0.3),
		Vector2(cx + s * 0.45, cy - s * 0.3),
	])
	c.draw_colored_polygon(drone, col)
	c.draw_line(Vector2(cx, cy - s * 0.3), Vector2(cx, cy + s * 0.4), col, 1.1, true)
	c.draw_circle(Vector2(cx, cy + s * 0.65), s * 0.26, col)


# 势力攻速 debuff：粗下箭头 + 顶部横档
static func _draw_faction_aspd(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_line(Vector2(cx - s * 0.6, cy - s * 0.8), Vector2(cx + s * 0.6, cy - s * 0.8), col, 1.3, true)
	c.draw_line(Vector2(cx, cy - s * 0.8), Vector2(cx, cy + s * 0.55), col, 1.6, true)
	c.draw_line(Vector2(cx - s * 0.5, cy - s * 0.05), Vector2(cx, cy + s * 0.55), col, 1.5, true)
	c.draw_line(Vector2(cx + s * 0.5, cy - s * 0.05), Vector2(cx, cy + s * 0.55), col, 1.5, true)


# 势力防御 debuff：方盾 + 裂纹（与破甲五边形盾区分）
static func _draw_faction_def(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var sq := PackedVector2Array([
		Vector2(cx - s * 0.7, cy - s * 0.9),
		Vector2(cx + s * 0.7, cy - s * 0.9),
		Vector2(cx + s * 0.7, cy + s * 0.5),
		Vector2(cx, cy + s),
		Vector2(cx - s * 0.7, cy + s * 0.5),
	])
	c.draw_colored_polygon(sq, Color(col.r, col.g, col.b, col.a * 0.45))
	c.draw_polyline(PackedVector2Array([sq[0], sq[1], sq[2], sq[3], sq[4], sq[0]]), col, 1.2, true)
	c.draw_line(Vector2(cx - s * 0.2, cy - s * 0.3), Vector2(cx + s * 0.2, cy + s * 0.4), col, 1.2, true)


# ── BUFF 图标 ──

# 雷达：四段断弧 + 细十字 + 中心点（复用 buff_strip 几何）
static func _draw_radar(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_arc(Vector2(cx, cy), s * 0.95, -PI * 0.75, -PI * 0.25, 12, col, 1.6, true)
	c.draw_line(Vector2(cx - s, cy), Vector2(cx + s, cy), col, 1.4, true)
	c.draw_line(Vector2(cx, cy - s), Vector2(cx, cy + s), col, 1.4, true)
	c.draw_circle(Vector2(cx, cy), s * 0.14, col)


# 侦察：圆 + 四向断刻度 + 中心点
static func _draw_scout(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_arc(Vector2(cx, cy), s * 0.72, 0.0, TAU, 24, col, 1.4, true)
	c.draw_line(Vector2(cx - s, cy), Vector2(cx - s * 0.22, cy), col, 1.4, true)
	c.draw_line(Vector2(cx + s * 0.22, cy), Vector2(cx + s, cy), col, 1.4, true)
	c.draw_line(Vector2(cx, cy - s), Vector2(cx, cy - s * 0.22), col, 1.4, true)
	c.draw_line(Vector2(cx, cy + s * 0.22), Vector2(cx, cy + s), col, 1.4, true)
	c.draw_circle(Vector2(cx, cy), s * 0.12, col)


# 堡垒：五边形堡垒（复用 buff_strip 几何）
static func _draw_fortress(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - s * 0.95),
		Vector2(cx + s * 0.82, cy - s * 0.2),
		Vector2(cx + s * 0.62, cy + s * 0.9),
		Vector2(cx - s * 0.62, cy + s * 0.9),
		Vector2(cx - s * 0.82, cy - s * 0.2),
	])
	c.draw_colored_polygon(pts, col)
	var inset := PackedVector2Array([
		Vector2(cx, cy - s * 0.45),
		Vector2(cx + s * 0.28, cy + s * 0.05),
		Vector2(cx, cy + s * 0.42),
		Vector2(cx - s * 0.28, cy + s * 0.05),
	])
	c.draw_colored_polygon(inset, Color(col.r, col.g, col.b, col.a * 0.35))


# 指挥：五角星（复用 buff_strip 几何）
static func _draw_command(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(5):
		var outer_a: float = -PI * 0.5 + TAU * float(i) / 5.0
		var inner_a: float = outer_a + TAU / 10.0
		pts.append(Vector2(cx + cos(outer_a) * s, cy + sin(outer_a) * s))
		pts.append(Vector2(cx + cos(inner_a) * s * 0.42, cy + sin(inner_a) * s * 0.42))
	c.draw_colored_polygon(pts, col)


# 航母：十字 + 圆 + 四角点（复用 buff_strip 几何）
static func _draw_carrier(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_line(Vector2(cx - s * 0.85, cy), Vector2(cx + s * 0.85, cy), col, 1.6, true)
	c.draw_line(Vector2(cx, cy - s * 0.85), Vector2(cx, cy + s * 0.85), col, 1.6, true)
	c.draw_arc(Vector2(cx, cy), s * 0.78, 0.0, TAU, 20, col, 1.2, true)
	var dot_r: float = s * 0.15
	c.draw_circle(Vector2(cx, cy - s * 0.85), dot_r, col)
	c.draw_circle(Vector2(cx, cy + s * 0.85), dot_r, col)
	c.draw_circle(Vector2(cx - s * 0.85, cy), dot_r, col)
	c.draw_circle(Vector2(cx + s * 0.85, cy), dot_r, col)


# 改造光环：辐射波纹（复用 buff_strip 几何）
static func _draw_mod_aura(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_circle(Vector2(cx, cy), s * 0.15, col)
	c.draw_arc(Vector2(cx, cy), s * 0.5, -PI, 0.0, 12, col, 1.4, true)
	c.draw_arc(Vector2(cx, cy), s * 0.85, -PI, 0.0, 16, col, 1.2, true)
	c.draw_line(Vector2(cx - s * 0.95, cy), Vector2(cx + s * 0.95, cy), col, 1.0, true)


# 堡垒庇护：屋顶（倒 V + 底线 + 门）
static func _draw_fort_shelter(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_line(Vector2(cx - s, cy + s * 0.2), Vector2(cx, cy - s), col, 1.6, true)
	c.draw_line(Vector2(cx, cy - s), Vector2(cx + s, cy + s * 0.2), col, 1.6, true)
	c.draw_line(Vector2(cx - s * 0.8, cy + s * 0.2), Vector2(cx + s * 0.8, cy + s * 0.2), col, 1.3, true)
	c.draw_line(Vector2(cx, cy + s * 0.2), Vector2(cx, cy + s * 0.8), col, 1.2, true)
	c.draw_line(Vector2(cx - s * 0.25, cy + s * 0.8), Vector2(cx + s * 0.25, cy + s * 0.8), col, 1.2, true)


# 势力无敌：8 角闪光星 + 淡光晕
static func _draw_faction_invuln(c: CanvasItem, cx: float, cy: float, s: float, col: Color) -> void:
	c.draw_arc(Vector2(cx, cy), s * 0.98, 0.0, TAU, 20, Color(col.r, col.g, col.b, col.a * 0.5), 1.0, true)
	var star := PackedVector2Array([
		Vector2(cx, cy - s),
		Vector2(cx + s * 0.25, cy - s * 0.25),
		Vector2(cx + s, cy),
		Vector2(cx + s * 0.25, cy + s * 0.25),
		Vector2(cx, cy + s),
		Vector2(cx - s * 0.25, cy + s * 0.25),
		Vector2(cx - s, cy),
		Vector2(cx - s * 0.25, cy - s * 0.25),
	])
	c.draw_colored_polygon(star, col)
