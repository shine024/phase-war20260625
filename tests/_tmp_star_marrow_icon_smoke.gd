extends SceneTree
## v6.35 星髓图标收尾冒烟：icon 字段接新图 + 贴图可加载 + 晶体定义未被误改。
## 复跑: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_star_marrow_icon_smoke.gd

func _initialize() -> void:
	var BR = load("res://data/basic_resources.gd")
	assert(BR != null, "basic_resources.gd 加载失败")
	var def: Dictionary = BR.get_def(BR.ID_STAR_MARROW)
	var icon: String = String(def.get("icon", ""))
	assert(icon == "res://assets/resources/star_marrow.png", "icon 字段未接新图: " + icon)
	assert(ResourceLoader.exists(icon), "贴图资源不存在（导入未完成?）: " + icon)
	var tex: Texture2D = load(icon)
	assert(tex != null, "贴图加载失败: " + icon)
	assert(tex.get_width() == 1024 and tex.get_height() == 1024, "尺寸异常: %dx%d" % [tex.get_width(), tex.get_height()])
	# 既有定义不被误伤：晶体仍指晶体、能量块仍指能量块
	assert(String(BR.get_def(BR.ID_CRYSTAL).get("icon")) == "res://assets/resources/crystal.png")
	assert(String(BR.get_def(BR.ID_ENERGY_BLOCK).get("icon")) == "res://assets/resources/energy_block.png")
	# 消费口抽查：resource_slot_item._refresh_resource 读的就是该字段（玩家可见面）
	assert(String(BR.get_def(BR.ID_STAR_MARROW).get("name")) == "星髓")
	# 注释勘误件可加载（只动注释，防手滑）
	var wpv = load("res://scripts/weapon_projectile_vfx.gd")
	assert(wpv != null, "weapon_projectile_vfx.gd 加载失败")
	print("STAR_MARROW_ICON_SMOKE_OK")
	quit(0)
