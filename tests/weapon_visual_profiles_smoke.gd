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
