## v17 武器视觉档案注册表 smoke test
## 验证：① 解析器三优先级（精确表/关键词/域感知兜底）② UCT 全量武器名解析
## ③ 档案表 PROFILES 完整性 ④ 档案分类标签与 VFX 层分派域一致性（含激光枪口火修复）
## 运行：Godot --headless --path . --script tests/weapon_visual_profiles_smoke.gd
## 注：用 _initialize()（autoload 就绪后）而非 _init()——依赖 autoload 的脚本在 _init() 时编译失败。
extends SceneTree

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	print("=== v17 武器视觉档案注册表 smoke test ===")
	_test_resolver_exact()
	_test_resolver_keywords()
	_test_resolver_domain_fallback()
	_test_uct_full_resolution()
	_test_profiles_integrity()
	_test_dispatch_consistency()
	_summary()
	quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ✅ PASS: " + label)
	else:
		_fail += 1
		print("  ❌ FAIL: " + label)

## [1] 第1优先级：签名武器精确表（与 card_resource 弹道覆盖表同源）
func _test_resolver_exact() -> void:
	print("\n[1] 精确表命中")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	_ok(WVP != null, "weapon_visual_profiles.gd 编译加载成功")
	if WVP == null:
		return
	_ok(WVP.resolve_visual_wt("霰弹枪", 0, true) == 5, "霰弹枪 → SHOTGUN(5)")
	_ok(WVP.resolve_visual_wt("攻城电磁炮", 0, true) == 11, "攻城电磁炮 → RAIL(11)")
	_ok(WVP.resolve_visual_wt("重型等离子加农炮", 0, true) == 10, "重型等离子加农炮 → OMEGA(10)")
	_ok(WVP.resolve_visual_wt("全装型导弹巢", 0, true) == 9, "全装型导弹巢 → MISSILE(9)")
	_ok(WVP.resolve_visual_wt("磁轨狙击炮", 0, true) == 6, "磁轨狙击炮 → SNIPER_BEAM(6)")
	# 敌方域同样命中（名字优先与域无关）
	_ok(WVP.resolve_visual_wt("攻城电磁炮", 0, false) == 11, "敌方 攻城电磁炮 → RAIL(11)")

## [2] 第2优先级：视觉关键词（按特征性从强到弱）
func _test_resolver_keywords() -> void:
	print("\n[2] 视觉关键词命中")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	_ok(WVP.resolve_visual_wt("激光步枪", 0, true) == 8, "激光步枪 → LASER(8) 烧灼签名")
	_ok(WVP.resolve_visual_wt("雷射炮", 0, true) == 8, "雷射炮 → LASER(8)")
	_ok(WVP.resolve_visual_wt("磁轨炮", 0, true) == 11, "磁轨炮 → RAIL(11) 穿透签名")
	_ok(WVP.resolve_visual_wt("等离子机炮", 0, true) == 10, "等离子机炮 → OMEGA(10) 放电签名")
	_ok(WVP.resolve_visual_wt("防空导弹", 0, true) == 9, "防空导弹 → MISSILE(9)（导弹先于防空炮判定）")
	_ok(WVP.resolve_visual_wt("萨姆-7防空导弹", 0, false) == 9, "敌方 萨姆-7防空导弹 → MISSILE(9)")
	_ok(WVP.resolve_visual_wt("122mm火箭炮", 1, true) == 3, "122mm火箭炮 → ROCKET(3)")
	_ok(WVP.resolve_visual_wt("37mm高射炮", 0, true) == 7, "37mm高射炮 → FLAK(7)")
	_ok(WVP.resolve_visual_wt("81mm迫击炮", 1, true) == 1, "81mm迫击炮 → INDIRECT_ARTY(1)")
	_ok(WVP.resolve_visual_wt("粒子束步枪", 0, true) == 6, "粒子束步枪 → SNIPER_BEAM(6) 其余光束")
	_ok(WVP.resolve_visual_wt("毛瑟G98步枪", 0, true) == 0, "毛瑟G98步枪 → LIGHT_KINETIC(0)")
	_ok(WVP.resolve_visual_wt("12.7mm重机枪", 2, false) == 0, "敌方 12.7mm重机枪 → LIGHT_KINETIC(0)")

## [3] 第3优先级：域感知兜底（名字无信号，保持解析器出现前行为）
func _test_resolver_domain_fallback() -> void:
	print("\n[3] 域感知兜底")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	# 我方域：新枚举优先——1/2 = 曲射/空射（重型），原样透传
	_ok(WVP.resolve_visual_wt("", 1, true) == 1, "我方 wt=1 → INDIRECT(1) 保持")
	_ok(WVP.resolve_visual_wt("", 2, true) == 2, "我方 wt=2 → AERIAL(2) 保持")
	_ok(WVP.resolve_visual_wt("", 11, true) == 11, "我方 wt=11 → RAIL(11) 保持")
	# 敌方域：legacy 解释——1/2 = 步枪/机枪 → 归一 0（等价 normalize_light_kinetic_wt）
	_ok(WVP.resolve_visual_wt("", 1, false) == 0, "敌方 wt=1(RIFLE) → 归一 0")
	_ok(WVP.resolve_visual_wt("", 2, false) == 0, "敌方 wt=2(MG) → 归一 0")
	_ok(WVP.resolve_visual_wt("", 7, false) == 7, "敌方 wt=7(FLAK) → 7 保持")
	_ok(WVP.resolve_visual_wt("", 9, false) == 9, "敌方 wt=9(MISSILE) → 9 保持")
	# 越界钳制
	_ok(WVP.resolve_visual_wt("", 99, true) == 11, "wt=99 越界钳制 → 11")
	# 溯源字段
	var traced: Dictionary = WVP.resolve_traced("激光步枪", 0, true)
	_ok(String(traced.get("via", "")) == "keyword", "resolve_traced 溯源 via=keyword")
	traced = WVP.resolve_traced("霰弹枪", 0, true)
	_ok(String(traced.get("via", "")) == "exact", "resolve_traced 溯源 via=exact")
	traced = WVP.resolve_traced("", 1, false)
	_ok(String(traced.get("via", "")) == "wt_fallback", "resolve_traced 溯源 via=wt_fallback")

## [4] UCT 全量武器名解析——226 个 display_name 无一崩溃、全部落在合法族；
##     统计 wt_fallback 占比（=视觉身份未由名字确定的武器，是后续补配的清单）
func _test_uct_full_resolution() -> void:
	print("\n[4] UCT 全量武器名解析审计")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	var UCT: GDScript = load("res://data/unified_card_table.gd")
	if UCT == null:
		_ok(false, "unified_card_table.gd 编译加载成功")
		return
	_ok(true, "unified_card_table.gd 编译加载成功")
	var entries: Array = UCT.get_all_entries()
	var names: Dictionary = {}  # 去重集合（只审完整武器名——运行时传的就是完整 display_name，
	# 按"/"拆分的纯口径碎片如"81mm"是采样伪影，不参与统计）
	for e in entries:
		for key in ["w_light", "w_armor", "w_air"]:
			var raw: String = String(e.get(key, ""))
			if not raw.is_empty():
				names[raw] = true
	var all_valid: bool = true
	var fallback_names: Array = []
	for n in names.keys():
		var vwt: int = WVP.resolve_visual_wt(n, 0, true)
		if vwt < 0 or vwt > 11:
			all_valid = false
			print("    ❌ 非法族值: %s → %d" % [n, vwt])
		if String(WVP.resolve_traced(n, 0, true).get("via", "")) == "wt_fallback":
			fallback_names.append(n)
	_ok(all_valid, "全部 %d 个去重武器名解析到合法族(0-11)" % names.size())
	var fb_ratio: float = float(fallback_names.size()) / float(maxi(names.size(), 1))
	print("    📊 名字信号覆盖: %d/%d (%.0f%%) 有明确视觉信号；%d 个仅靠 wt 兜底" % [
		names.size() - fallback_names.size(), names.size(), fb_ratio * 100.0, fallback_names.size()])
	if not fallback_names.is_empty():
		print("    📋 wt_fallback 清单(前20): " + ", ".join(PackedStringArray(fallback_names.slice(0, 20))))
	# 兜底名单应只剩真正无法识别的新武器（枪/炮语义词已由轻动能捕获关键词吸收）——
	# 阈值 10%：新增武器若无任何可识别语义，会在此暴露提醒补关键词
	_ok(fb_ratio <= 0.10, "wt_fallback 占比 ≤10%%（实际 %.0f%%）" % (fb_ratio * 100.0))

## [5] 档案表完整性——12 族齐全、字段齐全
func _test_profiles_integrity() -> void:
	print("\n[5] PROFILES 完整性")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	var families: Array = WVP.all_families()
	_ok(families.size() == 12, "12 个武器族齐全（实际 %d）" % families.size())
	var complete: bool = true
	for f in families:
		var p: Dictionary = WVP.profile_of(f)
		for key in ["label", "muzzle", "impact", "projectile", "shake", "spec"]:
			if not p.has(key) or String(p[key]).is_empty():
				complete = false
				print("    ❌ 族 %d 缺字段 %s" % [f, key])
	_ok(complete, "每族档案 6 字段齐全（label/muzzle/impact/projectile/shake/spec）")
	_ok(not WVP.family_label(0).is_empty() and WVP.family_label(99).begins_with("未知族"),
		"family_label 正常/未知族兜底")

## [6] 档案分类标签 ↔ VFX 层分派域一致性（防两套定义漂移）
func _test_dispatch_consistency() -> void:
	print("\n[6] 档案标签与 VFX 分派域一致性")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	var Factory: GDScript = load("res://scripts/battle/vfx_impact_factory.gd")
	var heavy_wt: Array = Factory.HEAVY_MUZZLE_WT
	# muzzle=heavy/energy 的族必须在 HEAVY_MUZZLE_WT（否则枪口火拿轻型档=档案与实现割裂）
	# 例外：SNIPER_BEAM(6) 档案标 energy 但实现保持轻型（族内多为动能狙击，见工厂注释）
	var consistent: bool = true
	for f in WVP.all_families():
		var muzzle: String = String(WVP.profile_of(f).get("muzzle", ""))
		if (muzzle == "heavy" or muzzle == "energy") and not (f in heavy_wt):
			if f != 6:
				consistent = false
				print("    ❌ 族 %d(%s) 档案 muzzle=%s 但不在 HEAVY_MUZZLE_WT" % [f, WVP.family_label(f), muzzle])
	_ok(consistent, "档案 muzzle=heavy/energy 的族全部在 HEAVY_MUZZLE_WT（SNIPER_BEAM 除外，动能狙击主导）")
	# v17 修复回归锁定：LASER(8) 必须在重型域（原漏——激光命中灼烧签名但枪口是橙点轻型火）
	_ok(8 in heavy_wt, "LASER(8) 在 HEAVY_MUZZLE_WT（v17 修复回归锁定）")

func _summary() -> void:
	print("\n=== 汇总: %d PASS / %d FAIL ===" % [_pass, _fail])
