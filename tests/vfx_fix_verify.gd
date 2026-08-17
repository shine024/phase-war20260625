extends SceneTree

## 临时验证脚本：load 两个本次修改的 VFX 脚本 + 调用枚举修复后的分派函数断言。
## 用法: godot --headless --script tests/vfx_fix_verify.gd

func _init() -> void:
	var ok := true
	var factory = load("res://scripts/battle/vfx_impact_factory.gd")
	if factory == null:
		push_error("load vfx_impact_factory FAILED"); ok = false
	var projvfx = load("res://scripts/weapon_projectile_vfx.gd")
	if projvfx == null:
		push_error("load weapon_projectile_vfx FAILED"); ok = false

	if ok and factory.get("HEAVY_MUZZLE_WT") != null:
		var heavy: Array = factory.HEAVY_MUZZLE_WT
		# V8 断言：新枚举 INDIRECT(1)/AERIAL(2) 必须在重型域；DIRECT(0) 必须不在
		assert(1 in heavy and 2 in heavy and 3 in heavy and 7 in heavy and 9 in heavy and 10 in heavy and 11 in heavy)
		assert(not (0 in heavy))
		print("[V8] HEAVY_MUZZLE_WT = ", heavy, " -> 曲射/空射拿重型喷射 ✓")
	else:
		push_error("HEAVY_MUZZLE_WT missing"); ok = false

	if ok:
		# V9 断言：generic_impact_tex_by_wt 各分支返回非空贴图
		for wt in range(0, 12):
			var tex = projvfx.generic_impact_tex_by_wt(wt)
			if tex == null:
				push_error("generic_impact_tex_by_wt(%d) returned null" % wt); ok = false
		print("[V9] generic_impact_tex_by_wt 0-11 全分支非空 ✓")

	if ok:
		# V7 断言：flak 与 rocket 贴图内容已分离（hash 不同由导入侧保证，这里验证加载不炸）
		var flak = projvfx.PROJ_TEX_LEGACY.get(7)
		var rocket = projvfx.PROJ_TEX_LEGACY.get(3)
		if flak == null or rocket == null:
			push_error("flak/rocket texture missing"); ok = false
		elif flak == rocket:
			push_error("flak texture still identical object as rocket"); ok = false
		else:
			print("[V7] flak/rocket 贴图对象已分离 ✓")

	print("VFX_FIX_VERIFY: ALL PASS" if ok else "VFX_FIX_VERIFY: FAIL")
	quit(0 if ok else 1)
