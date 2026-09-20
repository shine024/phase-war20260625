extends SceneTree

## 排查编辑器启动报错的 --script 冒烟(秒级,零 autoload 依赖):
## 1) vfx_impact_factory.gd 当前能否编译(vfx_showcase "Could not find script" 级联根因)
## 2) vfx_showcase.gd 本身能否编译
## 3) 4 张损坏图标经 load() 走导入链是否仍失败(重导入前后对照)

func _initialize() -> void:
	var targets := [
		"res://scripts/battle/vfx_impact_factory.gd",
		"res://scenes/tools/vfx_showcase.gd",
		"res://scripts/weapon_projectile_vfx.gd",
		"res://assets/ui/icons/mod_icons/art_07_ammo_supply.png",
		"res://assets/ui/icons/mod_icons/art_08_uav.png",
		"res://assets/ui/icons/mod_icons/art_10_auto_nav.png",
		"res://assets/ui/icons/mod_icons/art_12_fortification.png",
	]
	var ok := {}
	var fail := []
	for p in targets:
		var res := load(p)
		if res != null:
			ok[p] = true
		else:
			fail.append(p)
	print("SMOKE_OK_COUNT=", ok.size())
	for p in fail:
		print("SMOKE_FAIL=", p)
	print("STARTUP_ERRORS_SMOKE_DONE")
	quit(0)
