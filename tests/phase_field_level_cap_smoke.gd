# 无 GdUnit 依赖的快速校验：相位场等级上限 16→30 扩展（v8.x）
# 验证：XP 阈值表 / 技能点表 长度、满级数值、旧档兼容性、clamp 防越界、2-3交替累计
# 技能点表用 preload（phase_master_skill_tree.gd 是纯 extends RefCounted，无 autoload 依赖）；
# XP 阈值表用源文件文本解析（phase_instrument_manager.gd 依赖 SignalBus，--script 模式无法 preload）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/phase_field_level_cap_smoke.gd
extends SceneTree

const SkillTree = preload("res://data/phase_master_skill_tree.gd")


func _initialize() -> void:
	var code := 0
	var errs: Array[String] = []

	# ── ① 技能点查表（preload，纯静态）──
	var pts_table: Array = SkillTree.POINTS_BY_PHASE_FIELD_LEVEL
	# 长度应为 31（索引 0-30，含 Lv0 占位）
	if pts_table.size() != 31:
		errs.append("技能点表长度 expected 31 got %d" % pts_table.size())
	# 满 Lv30 = 70 点（累计）
	var max_pts_30 := SkillTree.max_skill_points_at_phase_field_level(30)
	if max_pts_30 != 70:
		errs.append("满级Lv30 技能点 expected 70 got %d" % max_pts_30)
	# Lv0 占位 = 0
	if int(pts_table[0]) != 0:
		errs.append("Lv0 占位应为 0 got %d" % int(pts_table[0]))
	# Lv1-2 = 0（起步）
	if int(pts_table[1]) != 0 or int(pts_table[2]) != 0:
		errs.append("Lv1-2 应为 0 点 got %d,%d" % [int(pts_table[1]), int(pts_table[2])])
	# Lv16 = 35（旧档兼容：原30→新35）
	var max_pts_16 := SkillTree.max_skill_points_at_phase_field_level(16)
	if max_pts_16 != 35:
		errs.append("Lv16 技能点 expected 35(旧档兼容) got %d" % max_pts_16)
	# clamp 防越界：越界等级应 clamp 到末元素 = 70
	var over := SkillTree.max_skill_points_at_phase_field_level(99)
	if over != 70:
		errs.append("越界Lv99 应 clamp 到 70 got %d" % over)

	# ── ② Lv3-30 每级累计增量均为 2 或 3（2-3 交替）──
	for lv in range(3, 31):
		var delta := int(pts_table[lv]) - int(pts_table[lv - 1])
		if delta != 2 and delta != 3:
			errs.append("Lv%d 累计增量应为 2 或 3 got %d" % [lv, delta])
			break

	# ── ③ XP 阈值表（文本解析，避开 autoload 依赖）──
	var xp_thresh: Array = _parse_int_array("res://managers/phase_instrument_manager.gd", "PHASE_FIELD_XP_THRESHOLDS")
	if xp_thresh.is_empty():
		errs.append("无法解析 PHASE_FIELD_XP_THRESHOLDS")
	else:
		# 长度应为 30（Lv1-30，索引 0-29；范围判断语义：THRESHOLDS[i] → Lv(i+1)）
		if xp_thresh.size() != 30:
			errs.append("XP阈值表长度 expected 30 got %d" % xp_thresh.size())
		# 满级 Lv30 = 29900 XP（索引 29）
		if int(xp_thresh[29]) != 29900:
			errs.append("满级Lv30 XP expected 29900 got %d" % int(xp_thresh[29]))
		# Lv16 阈值不变（向后兼容）= 7500（索引 15）
		if int(xp_thresh[15]) != 7500:
			errs.append("Lv16 XP expected 7500 got %d（旧档会降级！）" % int(xp_thresh[15]))
		# 严格递增
		for i in range(1, xp_thresh.size()):
			if int(xp_thresh[i]) <= int(xp_thresh[i - 1]):
				errs.append("XP阈值非递增 @ idx %d" % i)
				break

		# ── ④ 旧档兼容性模拟（get_phase_field_level 遍历逻辑）──
		# 旧满级玩家 xp=7500 应仍为 Lv16（不降级）
		var lv_at_old := _compute_level(7500, xp_thresh)
		if lv_at_old != 16:
			errs.append("旧档 xp=7500 应仍为 Lv16（不降级）got Lv%d" % lv_at_old)
		# xp=15000 应为 Lv22
		var lv_at_15k := _compute_level(15000, xp_thresh)
		if lv_at_15k != 22:
			errs.append("xp=15000 应为 Lv22 got Lv%d" % lv_at_15k)
		# 满级 xp=29900 应为 Lv30
		var lv_at_max := _compute_level(29900, xp_thresh)
		if lv_at_max != 30:
			errs.append("xp=29900 应为 Lv30(满级) got Lv%d" % lv_at_max)

	# 输出结果
	if errs.is_empty():
		print("")
		print("╔══════════════════════════════════════════════════════╗")
		print("║  ✅ phase_field_level_cap_smoke: ALL PASS            ║")
		print("╠══════════════════════════════════════════════════════╣")
		print("║  技能点表: 31项, 满级Lv30=70点, Lv16=35(旧档兼容)   ║")
		print("║  XP阈值表: 30项, 满级Lv30=29900XP, Lv16=7500不变    ║")
		print("║  旧档兼容: xp=7500 → Lv16 不降级 ✅                 ║")
		print("║  clamp防越界: Lv99→70, Lv0→0 ✅                     ║")
		print("║  Lv3-30 累计增量: 均为 2 或 3 (2-3交替) ✅          ║")
		print("╚══════════════════════════════════════════════════════╝")
	else:
		print("")
		print("❌ phase_field_level_cap_smoke: FAILED (%d errors)" % errs.size())
		for e in errs:
			push_error(e)
			print("  - ", e)
		code = 1
	quit(code)


## 从 GDScript 源文件解析某个 const 整数数组（避开 preload/autoload 依赖）
## 匹配规则：定位 const NAME := [ ... ]，取块内「行首 数字」的纯数组元素，
## 跳过行内注释（# 之后）和纯注释行，避免误提取注释里的数字。
func _parse_int_array(path: String, const_name: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("无法打开文件: %s" % path)
		return []
	var content := f.get_as_text()
	f.close()
	var idx := content.find(const_name)
	if idx < 0:
		return []
	var bracket_start := content.find("[", idx)
	var bracket_end := content.find("]", bracket_start)
	if bracket_start < 0 or bracket_end < 0:
		return []
	var block := content.substr(bracket_start + 1, bracket_end - bracket_start - 1)
	var result: Array = []
	# 行首的「可选空白 + 可选负号 + 数字」——只匹配真正的数组元素，忽略行内注释
	var rg := RegEx.new()
	rg.compile("(?m)^\\s*(-?\\d+)")
	for m in rg.search_all(block):
		result.append(int(m.get_string(1)))
	return result


## 模拟 PhaseInstrumentManager.get_phase_field_level 的遍历逻辑
func _compute_level(xp: int, thresh: Array) -> int:
	var level := 1
	for i in range(thresh.size()):
		if xp >= int(thresh[i]):
			level = i + 1
	return level
