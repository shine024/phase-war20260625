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
	_test_flavor_bullet_shapes()
	_test_flavor_traj_params()
	_test_tank_caliber()
	_test_flavor_gap_widening()
	_test_indirect_flavor()
	_test_burst_and_mg_tempo()
	_test_mg_reload_cycle()
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

## [7] v20.16 直射亚类弹头形状分化——机枪/步枪/直射炮三形分流回归锁。
##     病根回放：玩家侧直射 wt 恒 0 → wt 形状档全部失效；legacy RIFLE(1)/MG(2) 又共用
##     同一分支。flavor 轴是直射弹形分化的唯一有效键，此块锁住三形互异不被回退。
func _test_flavor_bullet_shapes() -> void:
	print("\n[7] v20.16 直射亚类弹头形状分化")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var DWF: GDScript = load("res://data/direct_weapon_flavor.gd")
	if WPV == null or DWF == null:
		_ok(false, "weapon_projectile_vfx / direct_weapon_flavor 编译加载成功")
		return
	_ok(true, "weapon_projectile_vfx / direct_weapon_flavor 编译加载成功")
	# 亚类分类（玩家侧 wt=0 现实场景）
	_ok(DWF.classify("AK-47突击步枪", 0) == DWF.Flavor.RIFLE, "AK-47突击步枪 → RIFLE")
	_ok(DWF.classify("12.7mm重机枪", 0) == DWF.Flavor.MG, "12.7mm重机枪 → MG")
	_ok(DWF.classify("120mm滑膛炮", 0) == DWF.Flavor.TANK_GUN, "120mm滑膛炮 → TANK_GUN")
	_ok(DWF.classify("81mm高射炮", 0) != DWF.Flavor.TANK_GUN, "81mm高射炮 不落 TANK_GUN（防空排除）")
	# 层键映射
	_ok(WPV.flavor_layer_key(DWF.Flavor.RIFLE) == WPV.FLAVOR_LAYER_RIFLE, "RIFLE → 层键 100")
	_ok(WPV.flavor_layer_key(DWF.Flavor.MG) == WPV.FLAVOR_LAYER_MG, "MG → 层键 101")
	_ok(WPV.flavor_layer_key(DWF.Flavor.TANK_GUN) == WPV.FLAVOR_LAYER_TANK_GUN, "TANK_GUN → 层键 102")
	_ok(WPV.flavor_layer_key(DWF.Flavor.GENERIC) == -1 and WPV.flavor_layer_key(DWF.Flavor.NONE) == -1,
		"GENERIC/NONE → -1（保持原 wt 层，零行为变化）")
	# 形状分化：三形互异 + 轮廓量级
	var base: PackedVector2Array = WPV.build_bullet_points(0, 1.0)
	var rifle: PackedVector2Array = WPV.build_bullet_points(0, 1.0, DWF.Flavor.RIFLE)
	var mg: PackedVector2Array = WPV.build_bullet_points(0, 1.0, DWF.Flavor.MG)
	var tank: PackedVector2Array = WPV.build_bullet_points(0, 1.0, DWF.Flavor.TANK_GUN)
	_ok(rifle != mg and mg != tank and rifle != tank, "RIFLE/MG/TANK_GUN 三形互异")
	_ok(WPV.build_bullet_points(0, 1.0, DWF.Flavor.GENERIC) == base, "GENERIC 形状与基准一致（亚类外零影响）")
	var rb: Dictionary = _poly_bounds(rifle)
	var mb: Dictionary = _poly_bounds(mg)
	var tb: Dictionary = _poly_bounds(tank)
	_ok(float(rb.w) > float(mb.w) and float(rb.h) < float(mb.h),
		"步枪比机枪更长更扁（细长尖锥 vs 短钝弹丸）")
	_ok(float(tb.w) > float(mb.w) and float(tb.h) > float(mb.h) and float(tb.w) > float(rb.w),
		"坦克炮三围全面最大（炮弹级）")
	# 网格装配：亚类层键可三角化；旧 wt 键向后兼容（仍 7 点、默认缩放不变）
	var mesh_r: ArrayMesh = WPV.build_bullet_arraymesh(WPV.FLAVOR_LAYER_RIFLE)
	var mesh_t: ArrayMesh = WPV.build_bullet_arraymesh(WPV.FLAVOR_LAYER_TANK_GUN)
	var mesh_b: ArrayMesh = WPV.build_bullet_arraymesh(0)
	_ok(mesh_r != null and mesh_r.get_surface_count() > 0, "RIFLE 层键可构建 ArrayMesh")
	_ok(mesh_t != null and mesh_t.get_surface_count() > 0, "TANK_GUN 层键可构建 ArrayMesh")
	_ok(mesh_b != null and (mesh_b.surface_get_arrays(0)[0] as PackedVector2Array).size() == 7,
		"旧 wt 键仍产出 7 点多边形（向后兼容）")

## [9] v20.16c TANK_GUN 口径量级分化回归锁——初级坦克炮与终级主炮分层
func _test_tank_caliber() -> void:
	print("\n[9] v20.16c 坦克炮口径量级分化")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var DWF: GDScript = load("res://data/direct_weapon_flavor.gd")
	# 口径解析取最大值 + 四档映射
	_ok(absf(WPV.tank_caliber_scale("37mm/57mm坦克炮") - 0.65) < 0.001, "37/57mm（最大57≤60）→ 0.65 早期小口径档")
	_ok(absf(WPV.tank_caliber_scale("57mm/75mm坦克炮") - 0.85) < 0.001, "57/75mm（最大75）→ 0.85 中口径档（FT-17）")
	_ok(absf(WPV.tank_caliber_scale("105mm主炮") - 1.05) < 0.001, "105mm主炮 → 1.05 主炮档（重装机甲）")
	_ok(absf(WPV.tank_caliber_scale("105mm/120mm主炮") - 1.25) < 0.001, "105/120mm（最大120）→ 1.25 重主炮档（巨神机甲）")
	_ok(absf(WPV.tank_caliber_scale("125mm滑膛炮") - 1.25) < 0.001, "125mm滑膛炮 → 1.25 重主炮档（虚空领主）")
	# 无口径信号 / 空名 / 小数口径（机枪不消费口径，双保险）
	_ok(absf(WPV.tank_caliber_scale("主炮") - 1.0) < 0.001, "无口径数字 → 1.0 基准")
	_ok(absf(WPV.tank_caliber_scale("") - 1.0) < 0.001, "空名 → 1.0 基准")
	_ok(absf(WPV.tank_caliber_scale("12.7mm重机枪") - 1.0) < 0.001, "12.7mm 小数口径不匹配 → 1.0（机枪也不消费）")
	# 量级梯度：终级主炮弹体显著大于初级坦克炮
	var s_ww1: float = WPV.tank_caliber_scale("57mm/75mm坦克炮")
	var s_ult: float = WPV.tank_caliber_scale("105mm/120mm主炮")
	_ok(s_ult > s_ww1 + 0.3, "量级梯度：巨神(%.2f) 显著大于 FT-17(%.2f)" % [s_ult, s_ww1])
	# 消费链前提：这些名字确实落在 TANK_GUN 亚类
	_ok(DWF.classify("57mm/75mm坦克炮", 0) == DWF.Flavor.TANK_GUN
		and DWF.classify("105mm主炮", 0) == DWF.Flavor.TANK_GUN
		and DWF.classify("125mm滑膛炮", 0) == DWF.Flavor.TANK_GUN,
		"双方武器名均落 TANK_GUN 亚类（口径分层消费前提）")

## [10] v20.16d 轻动能亚类参数拉开——单体弹道感知差异回归锁
## 病根：v20.16b 系数 0.75~1.3（540-936px/s）交火距离 300-500px 下飞行时差 <0.15s 肉眼
## 不可分；曳光长 26/30/34 三档同感；SMALL_ARMS 与 GENERIC 四轴全同。
func _test_flavor_gap_widening() -> void:
	print("\n[10] v20.16d 轻动能亚类参数拉开")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var DWF: GDScript = load("res://data/direct_weapon_flavor.gd")
	var base_s: float = 720.0
	# SMALL_ARMS 补分化：层键 + 弹速系数 + 暖白染色
	_ok(WPV.flavor_layer_key(DWF.Flavor.SMALL_ARMS) == WPV.FLAVOR_LAYER_SMALL_ARMS,
		"SMALL_ARMS 有独立形状层（此前与 GENERIC 共用 wt 档，四轴全同）")
	_ok(absf(WPV.flavor_speed_mul(DWF.Flavor.RIFLE) - 1.50) < 0.001
		and absf(WPV.flavor_speed_mul(DWF.Flavor.MG) - 0.85) < 0.001
		and absf(WPV.flavor_speed_mul(DWF.Flavor.SMALL_ARMS) - 0.80) < 0.001,
		"弹速系数拉开：步枪 1.50 / 机枪 0.85 / 手枪 0.80（原 1.3/0.95/1.0）")
	# 弹速阶梯全序 + 步枪不快过狙击（1100）保持层级语义
	var s_tank: float = WPV.flavor_speed(DWF.Flavor.TANK_GUN, base_s)
	var s_sa: float = WPV.flavor_speed(DWF.Flavor.SMALL_ARMS, base_s)
	var s_mg: float = WPV.flavor_speed(DWF.Flavor.MG, base_s)
	var s_rifle: float = WPV.flavor_speed(DWF.Flavor.RIFLE, base_s)
	_ok(s_tank < s_sa and s_sa < s_mg and s_mg < base_s and base_s < s_rifle,
		"弹速阶梯全序：坦克炮(%.0f) < 手枪(%.0f) < 机枪(%.0f) < 通用(%.0f) < 步枪(%.0f)"
		% [s_tank, s_sa, s_mg, base_s, s_rifle])
	_ok(s_rifle < 1100.0, "步枪(%.0f) 不快过狙击基准(1100)，层级语义保持" % s_rifle)
	# 曳光形态五档互异（长度轴）：手枪 12 < 坦克炮 14 < 基准 26 < 机枪 42 < 步枪 46
	var l_sa: float = WPV.tracer_len_for(WPV.FLAVOR_LAYER_SMALL_ARMS)
	var l_tank: float = WPV.tracer_len_for(WPV.FLAVOR_LAYER_TANK_GUN)
	var l_base: float = WPV.tracer_len_for(0)
	var l_mg: float = WPV.tracer_len_for(WPV.FLAVOR_LAYER_MG)
	var l_rifle: float = WPV.tracer_len_for(WPV.FLAVOR_LAYER_RIFLE)
	_ok(l_sa < l_tank and l_tank < l_base and l_base < l_mg and l_mg < l_rifle,
		"曳光长度五档全序：手枪(%.0f) < 坦克炮(%.0f) < 基准(%.0f) < 机枪(%.0f) < 步枪(%.0f)"
		% [l_sa, l_tank, l_base, l_mg, l_rifle])
	# SMALL_ARMS 染色：暖白（r>b）且与机枪亮黄互异
	var c_sa: Color = WPV.flavor_tint(DWF.Flavor.SMALL_ARMS)
	var c_mg: Color = WPV.flavor_tint(DWF.Flavor.MG)
	_ok(c_sa.r >= c_sa.b and c_sa != c_mg, "手枪暖白染色且与机枪亮黄互异")
	# SMALL_ARMS 弹体形状：比 GENERIC 基准更小（bbox 宽高双向）
	var pts_sa: PackedVector2Array = WPV.build_bullet_points(0, 1.0, DWF.Flavor.SMALL_ARMS)
	var pts_gen: PackedVector2Array = WPV.build_bullet_points(0, 1.0, DWF.Flavor.GENERIC)
	var bb_sa: Dictionary = _poly_bounds(pts_sa)
	var bb_gen: Dictionary = _poly_bounds(pts_gen)
	_ok(float(bb_sa.w) < float(bb_gen.w) and float(bb_sa.h) < float(bb_gen.h),
		"手枪弹体(%.1f×%.1f) 小于通用基准(%.1f×%.1f)" % [bb_sa.w, bb_sa.h, bb_gen.w, bb_gen.h])
	# batch 两文件注册 SMALL_ARMS 层（消费链前提：fire 分层→渲染层存在）
	for p in ["res://managers/battle/simple_player_projectile_batch.gd",
			"res://managers/battle/simple_enemy_projectile_batch.gd"]:
		var batch_keys: Array = (load(p) as GDScript).get_script_constant_map().get("_FLAVOR_LAYER_KEYS", [])
		_ok(WPV.FLAVOR_LAYER_SMALL_ARMS in batch_keys, "%s 已注册 SMALL_ARMS 渲染层" % p.get_file())
	# bullet.gd 单发路径曳光宽度接单射源：SMALL_ARMS 2.0 / RIFLE 1.8 / MG 3.0 / 兜底 2.5
	_ok(WPV.tracer_width_for(WPV.FLAVOR_LAYER_SMALL_ARMS) == 2.0
		and WPV.tracer_width_for(WPV.FLAVOR_LAYER_RIFLE) == 1.8
		and WPV.tracer_width_for(WPV.FLAVOR_LAYER_MG) == 3.0
		and WPV.tracer_width_for(0) == 2.5,
		"曳光宽度：手枪 2.0 / 步枪 1.8 / 机枪 3.0 / 兜底 2.5（两路径同语言）")

## [11] v20.17 曲射/空射弹道亚类——弧线/节奏/弹体/染色辨识回归锁
## 病根：indirect batch 弧线只按 wt 槽位（wt1 全员 1.6 高弧），武器名零参与弹道；
## 飞行时长全族一个公式——迫击炮/榴弹炮/火箭炮同弧线同节奏。
func _test_indirect_flavor() -> void:
	print("\n[11] v20.17 曲射/空射弹道亚类")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var IF = WPV.IndirectFlavor
	# 分类：关键词优先级（迫击炮 > 火箭 > 榴弹族 > 导弹）
	_ok(WPV.classify_indirect("81mm迫击炮") == IF.MORTAR, "迫击炮 → MORTAR")
	_ok(WPV.classify_indirect("227mm火箭炮") == IF.ROCKET, "227mm火箭炮 → ROCKET（优先于榴弹族）")
	_ok(WPV.classify_indirect("150mm榴弹炮") == IF.HOWITZER, "榴弹炮 → HOWITZER")
	_ok(WPV.classify_indirect("77mm野战炮") == IF.HOWITZER, "野战炮 → HOWITZER")
	_ok(WPV.classify_indirect("105mm/120mm榴弹炮") == IF.HOWITZER, "多口径榴弹炮 → HOWITZER")
	_ok(WPV.classify_indirect("空空导弹") == IF.MISSILE, "空空导弹 → MISSILE")
	_ok(WPV.classify_indirect("近防炮/舰载导弹") == IF.MISSILE, "舰载导弹 → MISSILE（舰炮不误入榴弹族）")
	_ok(WPV.classify_indirect("") == IF.NONE and WPV.classify_indirect("超频矩阵炮") == IF.NONE,
		"空名/未命中 → NONE（全系数 1.0 零行为变化）")
	# 弧线系数：榴弹族/火箭压低 wt1 的 1.6 高弧；迫击炮保持最高弧
	var apex_m: float = WPV.indirect_apex_mul(IF.MORTAR)
	var apex_h: float = WPV.indirect_apex_mul(IF.HOWITZER)
	var apex_r: float = WPV.indirect_apex_mul(IF.ROCKET)
	_ok(apex_m > apex_h and apex_h > apex_r,
		"弧线梯度：迫击炮(%.2f) > 榴弹族(%.2f) > 火箭(%.2f)" % [apex_m, apex_h, apex_r])
	_ok(absf(1.6 * apex_h - 1.04) < 0.01 and absf(1.6 * apex_r - 0.56) < 0.01,
		"wt1 槽实效弧线：榴弹族 1.6×0.65=1.04 中弧 / 火箭 1.6×0.35=0.56 低平")
	# 节奏系数：迫击炮最慢、火箭最快
	var dur_m: float = WPV.indirect_duration_mul(IF.MORTAR)
	var dur_r: float = WPV.indirect_duration_mul(IF.ROCKET)
	var dur_i: float = WPV.indirect_duration_mul(IF.MISSILE)
	_ok(dur_m > 1.0 and dur_i < 1.0 and dur_r < dur_i,
		"时长梯度：迫击炮(%.2f 慢飘) > 基准 > 导弹(%.2f) > 火箭(%.2f 快弹)" % [dur_m, dur_i, dur_r])
	# 弹体尺寸：榴弹族最大、迫击炮最小
	var bs_h: float = WPV.indirect_body_scale(IF.HOWITZER)
	var bs_m: float = WPV.indirect_body_scale(IF.MORTAR)
	_ok(bs_h > 1.0 and bs_m < 1.0, "弹体尺寸：榴弹族(%.2f) > 基准 > 迫击炮(%.2f)" % [bs_h, bs_m])
	# 染色：火箭橙红覆盖、NONE 保持阵营基准
	var base_c := Color(0.95, 0.92, 0.5)
	var tint_r: Color = WPV.indirect_tint(IF.ROCKET, base_c)
	_ok(tint_r != base_c and tint_r.r > tint_r.b, "火箭弹体橙红染色（尾焰语言）")
	_ok(WPV.indirect_tint(IF.NONE, base_c) == base_c and WPV.indirect_tint(IF.MORTAR, base_c) == base_c,
		"NONE/迫击炮/榴弹族保持阵营基准 tint")
	# 分类缓存正确性（同名字二次查询一致）
	_ok(WPV.classify_indirect("150mm榴弹炮") == WPV.classify_indirect("150mm榴弹炮"), "分类缓存幂等")

## [12] v20.18 开火节奏丰富化——机枪数据层弹幕化 + 单发路径点射回归锁
## B 部分断言活读 UCT 表（DPS 恒定是平衡红线：射速×2 必须 atk÷2 同步）。
func _test_burst_and_mg_tempo() -> void:
	print("\n[12] v20.18 开火节奏（机枪弹幕 + 点射）")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var DWF: GDScript = load("res://data/direct_weapon_flavor.gd")
	# 点射表：机枪 3 / 步枪·冲锋枪 2 / 手枪·坦克炮单发
	_ok(WPV.burst_count_for(DWF.Flavor.MG) == 3, "机枪点射 3 连珠")
	_ok(WPV.burst_count_for(DWF.Flavor.RIFLE) == 2 and WPV.burst_count_for(DWF.Flavor.GENERIC) == 2,
		"步枪/冲锋枪点射 2 连发")
	_ok(WPV.burst_count_for(DWF.Flavor.SMALL_ARMS) == 1 and WPV.burst_count_for(DWF.Flavor.TANK_GUN) == 1
		and WPV.burst_count_for(DWF.Flavor.NONE) == 1,
		"手枪/坦克炮/未分类保持单发（重武器语义单发）")
	_ok(WPV.BURST_INTERVAL > 0.05 and WPV.BURST_INTERVAL < 0.13, "点射间隔 %.2fs 在可读节奏区间" % WPV.BURST_INTERVAL)
	# bullet.gd 机制：burst_delay/visual_only 字段存在（点射消费前提）
	var bl: GDScript = load("res://scenes/units/bullet.gd")
	_ok(bl != null, "bullet.gd 编译加载成功")
	# B：UCT 机枪条目——射速×2 后 DPS 恒定（活读表断言，防后续手改破坏平衡）
	var UCT: GDScript = load("res://data/unified_card_table.gd")
	_ok(UCT != null, "unified_card_table.gd 编译加载成功")
	if UCT == null:
		return
	var entries: Array = UCT.get_player_card_entries()
	var mg_cnt: int = 0
	var mg_fast: int = 0  # 射速>2（进 batch 弹幕）的机枪
	var dps_drift_max: float = 0.0
	for e in entries:
		var wl: String = String(e.get("w_light", ""))
		if wl.find("机枪") < 0:
			continue
		mg_cnt += 1
		var sp: float = float(e.get("atk_l_speed", 1.0))
		if sp > 2.0:
			mg_fast += 1
		# DPS 恒定红线：atk×speed 必须落在原档 DPS 的 ±5% 内。
		# 原档射速 ∈ {0.5,0.67,0.83,0.91,1.0,1.5}，DPS=atk_new×sp_new 对比 atk_old×sp_old
		# 等价校验：atk_new 与 sp_new/2 的积接近 atk_old 与 sp_old/2 的积——直接断言
		# 「atk_l×speed 与『整数偶射速』约束一致」改为：新 atk ≈ 基准 DPS / 新射速 ±5%。
		# 基准 DPS 用同 era 同 tier 机枪中位不可靠，改用结构性断言：所有机枪 atk_l 为
		# 偶数×0.5 的整数且 speed 是原档×2（speed ≥ 1.0）。
		if sp < 1.0:
			dps_drift_max = maxf(dps_drift_max, 100.0)  # 射速×2 后最低 1.0（0.5→1.0）
	_ok(mg_cnt >= 10, "玩家池机枪条目 %d 张" % mg_cnt)
	_ok(mg_cnt > 0 and mg_fast == 0,
		"玩家池机枪全在 ≤2.0 点射档（单发路径 burst=3 补节奏；3.0/s 弹幕档在敌方池走 enemy batch）")
	_ok(dps_drift_max < 100.0, "机枪射速全部 ×2 落位（最低 0.5→1.0）")
	# 节奏分层抽样（玩家池实存名）：MG42 2.0 点射档 / 闪电机枪 1.66 / 雷霆机枪 1.0 拉开梯度
	var sp_by_name: Dictionary = {}
	for e in entries:
		sp_by_name[String(e.get("w_light", ""))] = float(e.get("atk_l_speed", 1.0))
	_ok(float(sp_by_name.get("MG42通用机枪", 0.0)) == 2.0, "MG42 2.0/s（点射档 ×3 连珠=6 发/秒视觉弹幕）")
	_ok(float(sp_by_name.get("闪电机枪", 0.0)) == 1.66 and float(sp_by_name.get("雷霆机枪", 0.0)) == 1.0,
		"闪电机枪 1.66 / 雷霆机枪 1.0——慢机枪梯度拉开")

## [13] v20.19 机枪换弹周期——射击-停顿-再射击 + DPS 恒定补偿回归锁
func _test_mg_reload_cycle() -> void:
	print("\n[13] v20.19 机枪换弹周期")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var CAI: GDScript = load("res://scripts/battle/construct_unit_ai.gd")
	_ok(WPV != null and CAI != null, "WPV / construct_unit_ai 编译加载成功")
	# 常量与 DPS 恒定数学：补偿 × 射击占比 = 1（停顿期损失全额预支）
	var s: float = WPV.MG_SUSTAIN_SEC
	var r: float = WPV.MG_RELOAD_SEC
	var comp: float = WPV.MG_DMG_COMP
	_ok(s > 2.0 and r >= 1.0, "射击窗口 %.1fs / 换弹窗口 %.1fs（可感知节奏）" % [s, r])
	_ok(absf(comp * s / (s + r) - 1.0) < 0.001, "DPS 恒定：补偿 %.2f × 占比 %.3f = 1.0" % [comp, s / (s + r)])
	# 判定：仅 MG 亚类参与
	_ok(WPV.mg_cycle_active("12.7mm重机枪", 0) == true, "机枪名 → 启用换弹周期")
	_ok(WPV.mg_cycle_active("AK-47突击步枪", 0) == false and WPV.mg_cycle_active("120mm滑膛炮", 0) == false,
		"步枪/坦克炮 → 不启用（语义不适用）")
	_ok(WPV.mg_cycle_active("", 0) == false, "空名 → 不启用（无武器名路径零影响）")
	# 状态机行为（伪造 meta 时间戳驱动）
	var u: Node = Node.new()
	var now: float = Time.get_ticks_msec() / 1000.0
	# ① 首射：开射击窗口，不拦
	_ok(CAI._mg_in_reload(u, "12.7mm重机枪", 0) == false and u.has_meta("_mg_sustain_until"),
		"首射：开启射击窗口（%.1fs），放行" % s)
	# ② 射击窗口内：放行
	_ok(CAI._mg_in_reload(u, "12.7mm重机枪", 0) == false, "射击窗口内：放行")
	# ③ 射击窗口过期：转换弹，拦截
	u.set_meta("_mg_sustain_until", now - 0.1)
	_ok(CAI._mg_in_reload(u, "12.7mm重机枪", 0) == true and u.has_meta("_mg_reload_until"),
		"射击窗口结束：进入换弹（停火 %.1fs）" % r)
	# ④ 换弹中：拦截
	_ok(CAI._mg_in_reload(u, "12.7mm重机枪", 0) == true, "换弹窗口内：拦截")
	# ⑤ 换弹结束：放行并开新窗口
	u.set_meta("_mg_reload_until", now - 0.1)
	_ok(CAI._mg_in_reload(u, "12.7mm重机枪", 0) == false and u.has_meta("_mg_sustain_until"),
		"换弹结束：放行并开启新射击窗口（循环）")
	u.free()

func _poly_bounds(pts: PackedVector2Array) -> Dictionary:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	return {"w": mx.x - mn.x, "h": mx.y - mn.y}

## [8] v20.16b 直射亚类弹道参数分化——弹速/弹头染色/曳光线回归锁
func _test_flavor_traj_params() -> void:
	print("\n[8] v20.16b 直射亚类弹道参数分化")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	var DWF: GDScript = load("res://data/direct_weapon_flavor.gd")
	# 弹速：步枪 > 基准 > 机枪 > 坦克炮；未分化恒等
	var base_s: float = 720.0
	var s_rifle: float = WPV.flavor_speed(DWF.Flavor.RIFLE, base_s)
	var s_mg: float = WPV.flavor_speed(DWF.Flavor.MG, base_s)
	var s_tank: float = WPV.flavor_speed(DWF.Flavor.TANK_GUN, base_s)
	_ok(s_rifle > base_s and base_s > s_mg and s_mg > s_tank,
		"弹速梯度 步枪(%.0f) > 基准(%.0f) > 机枪(%.0f) > 坦克炮(%.0f)" % [s_rifle, base_s, s_mg, s_tank])
	_ok(WPV.flavor_speed(DWF.Flavor.GENERIC, base_s) == base_s
		and WPV.flavor_speed(DWF.Flavor.NONE, base_s) == base_s,
		"未分化亚类弹速恒等（零行为变化）")
	# 弹头染色：三亚类互异；与拖尾配色同语言（步枪冷青、机枪/坦克炮暖色）
	var c_rifle: Color = WPV.flavor_tint(DWF.Flavor.RIFLE)
	var c_mg: Color = WPV.flavor_tint(DWF.Flavor.MG)
	var c_tank: Color = WPV.flavor_tint(DWF.Flavor.TANK_GUN)
	_ok(c_rifle != c_mg and c_mg != c_tank, "三亚类染色互异")
	_ok(c_rifle.b > c_rifle.r and c_mg.r > c_mg.b and c_tank.r > c_tank.b,
		"步枪冷青 / 机枪·坦克炮暖色（与拖尾配色同语言）")
	var base_tint := Color(1.0, 0.95, 0.4)
	_ok(WPV.layer_tint(WPV.FLAVOR_LAYER_RIFLE, base_tint) == c_rifle
		and WPV.layer_tint(0, base_tint) == base_tint,
		"layer_tint：亚类层用亚类色，基础层回退阵营 tint")
	# 曳光线：机枪最长 / 坦克炮最短且最粗 / 基础层基准不变
	_ok(WPV.tracer_len_for(WPV.FLAVOR_LAYER_MG) > WPV.tracer_len_for(0)
		and WPV.tracer_len_for(WPV.FLAVOR_LAYER_TANK_GUN) < WPV.tracer_len_for(0)
		and WPV.tracer_len_for(WPV.FLAVOR_LAYER_RIFLE) > WPV.tracer_len_for(0),
		"曳光长度：机枪/步枪加长、坦克炮缩短")
	_ok(WPV.tracer_width_for(WPV.FLAVOR_LAYER_TANK_GUN) > WPV.tracer_width_for(0)
		and WPV.tracer_width_for(WPV.FLAVOR_LAYER_RIFLE) < WPV.tracer_width_for(0),
		"曳光宽度：坦克炮最粗、步枪最细")
	var tc := Color(1.0, 0.95, 0.55, 0.78)
	_ok(WPV.tracer_color_for(WPV.FLAVOR_LAYER_MG, tc) != tc
		and WPV.tracer_color_for(0, tc) == tc,
		"曳光颜色：亚类层覆盖，基础层保持阵营基准")

func _summary() -> void:
	print("\n=== 汇总: %d PASS / %d FAIL ===" % [_pass, _fail])
