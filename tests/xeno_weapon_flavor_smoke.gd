## v27.x 星冥武器 flavor smoke test（xeno_weapon_flavor.gd 数据锁）
## 验证：① 20 武器名 classify 全覆盖 ② flavor 分组计数 ③ 近战名单锁定
## ④ visual_wt 精确表（含"等离子抛射"防 OMEGA 关键词抢占的回归锁）
## ⑤ 经 WeaponVisualProfiles.resolve_traced 的 xeno 优先级 ⑥ 开关/层键常量存在性
## 运行：Godot --headless --path . --script tests/xeno_weapon_flavor_smoke.gd
## 注：用 _initialize()（autoload 就绪后）而非 _init()——依赖 autoload 的脚本在 _init() 时编译失败。
extends SceneTree

const XenoWeaponFlavor = preload("res://data/xeno_weapon_flavor.gd")
const WeaponVisuals = preload("res://data/weapon_visual_profiles.gd")
const WPV = preload("res://scripts/weapon_projectile_vfx.gd")

## 20 武器名权威名单（与 data/xeno_units.gd UNITS 的 weapon_label 一一对应）
const ALL_20 := [
	"蚀爪", "晶钻", "双光刃", "折射棱镜", "灵能冲击波", "棱光束", "相位炮",
	"等离子抛射", "热射线", "肩炮", "时棘", "利爪", "虚空折刃", "蠕虫弹药",
	"脉冲机炮", "拦截机群", "聚能主炮", "灵能风暴", "拟形触刃", "湮灭光炮",
]
const MELEE_5 := ["蚀爪", "双光刃", "利爪", "虚空折刃", "拟形触刃"]

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	print("=== v27.x 星冥武器 flavor smoke test ===")
	_test_full_coverage()
	_test_group_counts()
	_test_melee_lock()
	_test_visual_wt_map()
	_test_resolver_priority()
	_test_switch_and_layers()
	_summary()
	quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ✓ " + label)
	else:
		_fail += 1
		print("  [FAIL] " + label)

func _test_full_coverage() -> void:
	print("── 1. 20 武器名 classify 全覆盖 ──")
	for wn: String in ALL_20:
		_ok(XenoWeaponFlavor.classify(wn) != XenoWeaponFlavor.Flavor.NONE,
			"'" + wn + "' classify 命中")
	_ok(XenoWeaponFlavor.classify("") == XenoWeaponFlavor.Flavor.NONE, "空名 → NONE")
	_ok(XenoWeaponFlavor.classify("120mm主炮") == XenoWeaponFlavor.Flavor.NONE, "人类武器名 → NONE")
	_ok(XenoWeaponFlavor.is_xeno_weapon("双光刃") and not XenoWeaponFlavor.is_xeno_weapon("AK-47突击步枪"),
		"is_xeno_weapon 判定")

func _test_group_counts() -> void:
	print("── 2. flavor 分组计数（5/6/3/3/3=20）──")
	var counts := {}
	for wn: String in ALL_20:
		var f: int = XenoWeaponFlavor.classify(wn)
		counts[f] = int(counts.get(f, 0)) + 1
	_ok(int(counts.get(XenoWeaponFlavor.Flavor.MELEE_EDGE, 0)) == 5, "MELEE_EDGE = 5")
	_ok(int(counts.get(XenoWeaponFlavor.Flavor.PSI_BOLT, 0)) == 6, "PSI_BOLT = 6")
	_ok(int(counts.get(XenoWeaponFlavor.Flavor.PRISM_BEAM, 0)) == 3, "PRISM_BEAM = 3")
	_ok(int(counts.get(XenoWeaponFlavor.Flavor.PHASE_CANNON, 0)) == 3, "PHASE_CANNON = 3")
	_ok(int(counts.get(XenoWeaponFlavor.Flavor.PLASMA_LOB, 0)) == 3, "PLASMA_LOB = 3")

func _test_melee_lock() -> void:
	print("── 3. 近战名单锁定 ──")
	for wn: String in MELEE_5:
		_ok(XenoWeaponFlavor.classify(wn) == XenoWeaponFlavor.Flavor.MELEE_EDGE,
			"'" + wn + "' = MELEE_EDGE")

func _test_visual_wt_map() -> void:
	print("── 4. visual_wt 精确表 ──")
	_ok(XenoWeaponFlavor.visual_wt_exact("棱光束") == 6, "棱光束 → 6（光束签名）")
	_ok(XenoWeaponFlavor.visual_wt_exact("相位炮") == 8, "相位炮 → 8（激光灼烧签名）")
	_ok(XenoWeaponFlavor.visual_wt_exact("湮灭光炮") == 8, "湮灭光炮 → 8")
	# 回归锁：等离子抛射必须钉在 1（曲射族）——不进表会被 OMEGA_KEYWORDS"等离子"抢占误归 10
	_ok(XenoWeaponFlavor.visual_wt_exact("等离子抛射") == 1, "等离子抛射 → 1（防 OMEGA 抢占）")
	_ok(XenoWeaponFlavor.visual_wt_exact("灵能风暴") == 1, "灵能风暴 → 1")
	_ok(XenoWeaponFlavor.visual_wt_exact("蚀爪") == 0, "蚀爪 → 0（近战保持轻动能域）")
	_ok(XenoWeaponFlavor.visual_wt_exact("晶钻") == -1, "晶钻不入表（PSI_BOLT 保持原域）")
	_ok(XenoWeaponFlavor.visual_wt_exact("拦截机群") == -1, "拦截机群不入表（空射保持原域）")
	_ok(XenoWeaponFlavor.visual_wt_override(XenoWeaponFlavor.Flavor.PSI_BOLT) == -1,
		"PSI_BOLT override = -1（保持原域）")

func _test_resolver_priority() -> void:
	print("── 5. WeaponVisualProfiles 优先级（xeno 在关键词前）──")
	# 回归锁：改动前"等离子抛射"被 OMEGA_KEYWORDS 抢占误归 wt10
	var r: Dictionary = WeaponVisuals.resolve_traced("等离子抛射", 1, false)
	_ok(int(r["visual_wt"]) == 1 and String(r["via"]) == "xeno",
		"等离子抛射 resolve → 1 via xeno（修复 OMEGA 误捕）")
	r = WeaponVisuals.resolve_traced("棱光束", 0, true)
	_ok(int(r["visual_wt"]) == 6 and String(r["via"]) == "xeno", "棱光束 resolve → 6 via xeno")
	r = WeaponVisuals.resolve_traced("AK-47突击步枪", 0, true)
	_ok(String(r["via"]) != "xeno", "人类武器名不经 xeno 分支")

func _test_switch_and_layers() -> void:
	print("── 6. 开关与层键常量 ──")
	var gc = load("res://resources/game_config.gd").new()
	_ok("xeno_vfx_enabled" in gc, "GameConfig.xeno_vfx_enabled 字段存在")
	_ok(bool(gc.xeno_vfx_enabled) == true, "开关默认 true")
	_ok(WPV.FLAVOR_LAYER_XENO_MELEE == 104, "近战层键 = 104")
	_ok(WPV.XENO_EDGE_TEX != null, "刃光贴图已挂")
	_ok(WPV.layer_tint(WPV.FLAVOR_LAYER_XENO_MELEE, Color.WHITE) == XenoWeaponFlavor.COLOR_EDGE,
		"近战层 tint = 青金晶髓")
	_ok(WPV.tracer_len_for(WPV.FLAVOR_LAYER_XENO_MELEE) == 46.0, "近战曳光长度 46")

func _summary() -> void:
	print("=== 结果: %d pass / %d fail ===" % [_pass, _fail])
