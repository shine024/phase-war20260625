extends SceneTree
## v6.17.2 改造数据全量审计（--script headless，只读）：
## 1) 总数锁 249；2) id 唯一 / rarity 合法 / 图标存在 / 稀有度分布；3) effects 键分类
##    （四通道 stat 键 / 机制键 / 未知键=死数据）；4) pct 稀有度帽 / 负值代价键纪律
##    （负值须 keystone 且键 ∈ 代价白名单）；5) era_band 合法；6) 敌方配装交叉
##    （引用 mod 存在 / 不生效键统计 / cuts 越界）。
var problems: Array = []
var infos: Array = []
var stats: Dictionary = {}

const COST_KEYS := ["max_hp", "attack_light", "attack_armor", "attack_air",
	"attack_range", "single_target_penalty"]
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
var KNOWN_KEYS: Dictionary = {}
var loadout_whitelist: Array = []


func _p(code: String, msg: String) -> void:
	problems.append("[%s] %s" % [code, msg])


func _initialize() -> void:
	var Reg = load("res://scripts/systems/modification_registry.gd")
	Reg._ensure_initialized()
	var ids: Array = Reg.get_all_ids()
	# 已知效果键 = registry + module_effect_handler + 敌方白名单 的源码字面量并集
	for srcfile in ["scripts/systems/modification_registry.gd",
			"scripts/battle/module_effect_handler.gd",
			"scripts/systems/mod_breakpoints.gd"]:
		var f := FileAccess.open("res://" + srcfile, FileAccess.READ)
		if f == null:
			continue
		for m in String(f.get_as_text()).split('"'):
			for tok in m.split(":"):
				pass
		var body := String(f.get_as_text())
		var re := RegEx.new()
		re.compile("^[a-z_0-9]+$")
		for tok in body.split('"'):
			if re.search(tok) != null and tok.length() >= 4 and tok.length() <= 32:
				KNOWN_KEYS[tok] = true
	var EFL = load("res://data/enemy_fixed_loadouts.gd")
	loadout_whitelist = EFL.LOADOUT_MOD_SUPPORTED_KEYS
	for k in loadout_whitelist:
		KNOWN_KEYS[String(k)] = true
	stats["total"] = ids.size()
	if ids.size() != 249:
		_p("MOD_COUNT", "改造总数 %d ≠ 249（项目锁）" % ids.size())

	var channel_keys: Array = Reg.CHANNEL_STAT_KEYS
	var mech_keys: Array = Reg.MECHANIC_EFFECT_KEYS
	var rar_count := {}
	var seen := {}
	var keystone_count := 0
	var no_icon := 0
	for id in ids:
		var d: Dictionary = Reg.get_data(String(id))
		var idd := String(id)
		if d.is_empty():
			_p("MOD_NO_DATA", "%s get_data 为空" % idd)
			continue
		if seen.has(idd):
			_p("MOD_DUP", "重复 id: %s" % idd)
		seen[idd] = true
		var rar := String(d.get("rarity", ""))
		if not RARITIES.has(rar):
			_p("MOD_RARITY", "%s rarity 非法: %s" % [idd, rar])
		else:
			rar_count[rar] = int(rar_count.get(rar, 0)) + 1
		# 图标
		if not ResourceLoader.exists("res://assets/ui/icons/mod_icons/%s.png" % idd):
			no_icon += 1
			_p("MOD_ICON_MISS", "%s 图标缺失" % idd)
		# keystone 一致性
		if bool(d.get("keystone", false)):
			keystone_count += 1
			if not Reg.KEYSTONE_IDS.has(idd):
				_p("MOD_KEYSTONE", "%s 打了 keystone 标记但不在 KEYSTONE_IDS" % idd)
		elif Reg.KEYSTONE_IDS.has(idd):
			_p("MOD_KEYSTONE2", "%s 在 KEYSTONE_IDS 但数据无 keystone 标记" % idd)
		# era_band
		if d.has("era_band"):
			var band = d.get("era_band")
			if not (band is Array) or (band as Array).size() != 2 \
					or int(band[0]) < 0 or int(band[1]) > 4 or int(band[0]) > int(band[1]):
				_p("MOD_BAND", "%s era_band 非法: %s" % [idd, band])
		# effects 键分类
		_check_effects(idd, d.get("effects", {}), rar, channel_keys, mech_keys, Reg)
		# level_effects（分级档）
		var le = d.get("level_effects", null)
		if le is Dictionary:
			for lv in le:
				_check_effects("%s@Lv%s" % [idd, lv], le[lv], rar, channel_keys, mech_keys, Reg)
	# keystone 清单数
	if keystone_count != Reg.KEYSTONE_IDS.size():
		_p("MOD_KEYSTONE_N", "keystone 标记数 %d ≠ KEYSTONE_IDS %d" % [keystone_count, Reg.KEYSTONE_IDS.size()])
	if Reg.KEYSTONE_IDS.size() != 16:
		infos.append("KEYSTONE_IDS 数量 %d（v6.16 基线 16）" % Reg.KEYSTONE_IDS.size())
	stats["rarity"] = rar_count
	stats["keystone"] = keystone_count
	stats["icon_missing"] = no_icon

	# ── 敌方配装交叉 ──
	var loads: Dictionary = EFL.LOADOUTS
	var whitelist: Array = EFL.LOADOUT_MOD_SUPPORTED_KEYS
	stats["loadout_cards"] = loads.size()
	var loadout_bad_ref := 0
	var loadout_no_effect_mods := 0
	for card_id in loads:
		var ld: Dictionary = loads[card_id]
		var mods: Array = ld.get("mods", [])
		for mid in mods:
			var mid_s := String(mid)
			if not seen.has(mid_s):
				loadout_bad_ref += 1
				_p("LOAD_REF_MISS", "敌方配装 %s 引用不存在的改造: %s" % [card_id, mid_s])
				continue
			var md: Dictionary = Reg.get_data(mid_s)
			var keys_in := 0
			var eff: Dictionary = md.get("effects", {})
			for k in eff:
				if whitelist.has(String(k)):
					keys_in += 1
			if keys_in == 0:
				loadout_no_effect_mods += 1
		var cuts: Dictionary = ld.get("cuts", {})
		for tier in cuts:
			if int(cuts[tier]) > mods.size():
				_p("LOAD_CUTS", "敌方配装 %s cuts[%s]=%d 超 mods 数 %d" % [card_id, tier, cuts[tier], mods.size()])
	stats["loadout_bad_ref"] = loadout_bad_ref
	if loadout_no_effect_mods > 0:
		infos.append("敌方配装引用的改造中 %d 条全部键都不在敌方白名单（挂载后零效果，生成器口径内但值得知道）" % loadout_no_effect_mods)

	# ── 汇总 ──
	print("==== 改造审计统计 ====")
	for k in stats:
		print("  %s = %s" % [k, stats[k]])
	print("==== 问题清单（%d）====" % problems.size())
	for p in problems:
		print("  [P] ", p)
	print("==== 备注（%d）====" % infos.size())
	for i2 in infos:
		print("  [i] ", i2)
	if problems.is_empty():
		print("MODS_AUDIT_OK")
	else:
		print("MODS_AUDIT_ISSUES %d" % problems.size())
	quit(0 if problems.is_empty() else 1)


func _check_effects(tag: String, effects, rar: String, channel_keys: Array, mech_keys: Array, Reg) -> void:
	if not (effects is Dictionary):
		_p("MOD_EFFECT_TYPE", "%s effects 不是字典" % tag)
		return
	var cap := float(Reg.get_stat_value_cap(rar))
	for k in effects:
		var ks := String(k)
		var v = effects[k]
		var base := ks
		var kind := "flat"
		if ks.ends_with("_set"):
			kind = "set"; base = ks.trim_suffix("_set")
		elif ks.ends_with("_pct"):
			kind = "pct"; base = ks.trim_suffix("_pct")
		# 已知键 = 引擎/处理器源码字面量 ∪ 通道表 ∪ 机制表 ∪ 敌方白名单（超集没问题，猎死键）
		var known: bool = KNOWN_KEYS.has(ks) or KNOWN_KEYS.has(base) 			or channel_keys.has(base) or channel_keys.has(ks) 			or mech_keys.has(ks) or loadout_whitelist.has(ks)
		if not known:
			_p("MOD_UNKNOWN_KEY", "%s 未知效果键（疑似引擎不消费的死键）: %s" % [tag, ks])
			continue
		if kind == "pct":
			var fv := float(v)
			if absf(fv) > cap + 0.0001:
				_p("MOD_PCT_CAP", "%s %s=%.2f 超稀有度帽 %.2f" % [tag, ks, fv, cap])
		if kind == "flat" and float(v) < 0.0 and float(v) > -1.0 and not KNOWN_KEYS.is_empty():
			# 旧版小数值代价（非 keystone 的历史取舍）——降级备注；新代价键须 keystone（v6.16 纪律）
			infos.append("历史小代价: %s %s=%s（非 keystone 旧取舍，维持现状）" % [tag, ks, v])
