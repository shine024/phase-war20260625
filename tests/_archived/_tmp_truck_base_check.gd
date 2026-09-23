extends SceneTree
## v26.12 移动基地接线 smoke（不进树、不依赖 autoload）
## 断言：脚本资源在位 / 场景可加载 / 首页 3v3 演练按钮已移除 / 移动基地按钮接线存在 /
##       五时代热区表完整（每时代必有 sortie+terminal+sleep，矩形 4 元）/ 贴图已导入可加载
## ⚠️ 编译验证归 --check-only/编辑器：场景脚本引用 autoload 全局名，--script 裸模式
##    恒编译失败且 load() 对编译失败仍返回非 null——本测试不做也无法做编译断言。

func _init() -> void:
	var fails: Array = []

	# 1) 脚本资源在位（load()==null 断言测不出编译失败，只能验证资源存在）
	for p in ["res://scenes/title_screen.gd", "res://scenes/bunker/truck_base.gd"]:
		if not FileAccess.file_exists(p):
			fails.append("脚本缺失: " + p)

	# 2) 场景可加载
	var ts = load("res://scenes/title_screen.tscn")
	if ts == null:
		fails.append("title_screen.tscn 加载失败")
	var tb = load("res://scenes/bunker/truck_base.tscn")
	if tb == null:
		fails.append("truck_base.tscn 加载失败")

	# 3) 首页 arena 按钮已移除 + 移动基地接线存在
	if ts != null:
		var ts_node = ts.instantiate()  # 不进树，_ready/@onready 不执行
		if ts_node.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/Arena3v3Button") != null:
			fails.append("Arena3v3Button 仍存在于 title_screen.tscn")
		ts_node.free()
	var src := FileAccess.get_file_as_string("res://scenes/title_screen.gd")
	if src.contains("_on_arena_3v3"):
		fails.append("title_screen.gd 仍残留 _on_arena_3v3")
	if not src.contains("_add_mobile_base_button") or not src.contains("EnterTruckBaseButton"):
		fails.append("title_screen.gd 缺少移动基地按钮接线")

	# 4) 热区表完整性
	var tbs: Script = load("res://scenes/bunker/truck_base.gd")
	var cmap: Dictionary = tbs.get_script_constant_map()
	var hs: Dictionary = cmap.get("HOTSPOTS", {})
	var eras: Array = cmap.get("ERAS", [])
	if eras.size() != 5:
		fails.append("ERAS 应为 5 时代，实际 %d" % eras.size())
	var hot_total := 0
	for e in eras:
		var id := String(e["id"])
		if not hs.has(id):
			fails.append("HOTSPOTS 缺时代: " + id)
			continue
		var kinds := {}
		for h in hs[id]:
			hot_total += 1
			kinds[String(h["kind"])] = true
			var r: Array = h["r"]
			if r.size() != 4:
				fails.append("%s 热区矩形非4元: %s" % [id, String(h["name"])])
		for must in ["sortie", "terminal", "sleep"]:
			if not kinds.has(must):
				fails.append("%s 缺必要工位类型: %s" % [id, must])

	# 5) 贴图可用性——与 truck_base.gd 运行时同契约：load() 优先，Image.load_from_file 兜底
	#    （headless 导入管线对这批 jpeg 不落地，GUI 编辑器打开项目后会自动补导）
	for e in eras:
		var tex_path := String(e["tex"])
		var t: Texture2D = load(tex_path)
		if t == null:
			var img := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
			if img != null:
				t = ImageTexture.create_from_image(img)
		if t == null:
			fails.append("贴图双通道均不可用: " + tex_path)

	# 6) v26.12b 接线：内嵌面板路径存在 + 新方法存在
	var panels: Dictionary = cmap.get("PANEL_SCENES", {})
	if panels.is_empty():
		fails.append("PANEL_SCENES 缺失")
	for pid in panels:
		var pp := String(panels[pid])
		if not FileAccess.file_exists(pp):
			fails.append("面板场景不存在: %s (%s)" % [pid, pp])
	var tsrc := FileAccess.get_file_as_string("res://scenes/bunker/truck_base.gd")
	for fn in ["_open_panel", "_open_terminal", "_on_sleep", "_get_display_level", "_attach_embed_instrument_bar", "_close_briefing"]:
		if not tsrc.contains("func " + fn):
			fails.append("truck_base.gd 缺方法: " + fn)
	var bar_path := String(cmap.get("INSTRUMENT_BAR_SCENE", ""))
	if bar_path == "" or not FileAccess.file_exists(bar_path):
		fails.append("相位仪栏场景不存在: " + bar_path)

	# 7) v26.12b BunkerManager 战斗日志（源级断言——--script 模式无 autoload，方法运行时验证）
	var bmsrc := FileAccess.get_file_as_string("res://managers/bunker_manager.gd")
	for frag in ["func get_battle_log", "\"battle_log\"", "battle_started.connect", "_pending_battle_level", "_pending_battle_endless"]:
		if not bmsrc.contains(frag):
			fails.append("bunker_manager.gd 缺战斗日志片段: " + frag)

	# 8) v26.12c 大地图卡车：精灵贴图 + 双视图 + world_map 标记
	for era in range(1, 6):
		var sp := "res://assets/ui/truck_base/truck_sprite_era%d.png" % era
		var st: Texture2D = load(sp)
		if st == null:
			fails.append("卡车精灵未导入: " + sp)
	if not FileAccess.file_exists("res://assets/backgrounds/bg_level_01.png"):
		fails.append("关卡战场背景缺失: bg_level_01.png")
	var tbsrc := FileAccess.get_file_as_string("res://scenes/bunker/truck_base.gd")
	for fn2 in ["_build_exterior_area", "_set_view", "_refresh_exterior", "_ext_bg_path"]:
		if not tbsrc.contains("func " + fn2):
			fails.append("truck_base.gd 缺外景方法: " + fn2)
	var wmsrc := FileAccess.get_file_as_string("res://scenes/world_map.gd")
	for fn3 in ["_add_truck_marker", "_on_truck_level_changed", "_update_truck_marker_snap", "_truck_marker_tooltip_refresh"]:  # v26.30：_on_truck_gui_input 已随光点穿透化删除
		if not wmsrc.contains("func " + fn3):
			fails.append("world_map.gd 缺卡车标记方法: " + fn3)
	# world_map.gd 真实引擎解析（gdtoolkit 对其存量的多行字符串误报，以引擎为准）
	var wm_script: Script = load("res://scenes/world_map.gd")
	if wm_script == null:
		fails.append("world_map.gd 引擎加载失败")

	if fails.is_empty():
		print("TRUCK_BASE_SMOKE ALL PASS (5 eras / %d hotspots)" % hot_total)
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: " + f)
		quit(1)
