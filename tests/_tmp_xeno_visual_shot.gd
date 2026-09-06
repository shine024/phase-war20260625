extends Node
## v27.3 星冥专属美术实机验收截图 v2：等自然波次进场（不摆拍不清场）
## 产出：.godot/agent_tools/xeno_shot_idle.png / xeno_shot_attack.png

const OUT_IDLE := "res://.godot/agent_tools/xeno_shot_idle.png"
const OUT_ATK := "res://.godot/agent_tools/xeno_shot_attack.png"


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()


func _count_enemies(bf: Node) -> int:
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu == null:
		return 0
	var n := 0
	for c in eu.get_children():
		if is_instance_valid(c):
			n += 1
	return n


func _run() -> void:
	await _wait_frames(20)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	await _wait_frames(10)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _wait_frames(150)
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	var gm: Node = get_node_or_null("/root/GameManager")
	var bm: Node = get_node_or_null("/root/BattleManager")
	gm.call("set_current_level", 100)
	gm.call("start_endless_battle")
	gm.call("go_to_battle")
	# 自动部署玩家（防守支撑战斗更久）
	await _wait_frames(45)
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
	# 官方 driver 同款：强制刷一波常规 xeno（不等自然波次计时器）
	var bf: Node = gm.get("battle_scene")
	var bss = bm.get("_spawn_system")
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu != null:
		for c in eu.get_children():
			c.queue_free()
	await _wait_frames(4)
	bss.call("sync_enemy_unit_count_from_field")
	bss.call("spawn_card_grid_enemy_wave", 100)
	await _wait_frames(30)
	# 终极诊断：把一只单位钉到屏幕中央、放大、置顶，冻结全场防败北
	get_tree().paused = true
	await _wait_frames(2)
	var eu2: Node = bf.get_node_or_null("EnemyUnits")
	var moved := false
	if eu2 != null:
		for c in eu2.get_children():
			if is_instance_valid(c):
				c.global_position = Vector2(640, 380)
				var spr: Node2D = null
				for cc in c.get_children():
					if cc is Sprite2D:
						spr = cc
						break
				if spr != null:
					spr.scale = spr.scale * 3.0
					spr.z_index = 200
					print("[XenoShot] pinned ", c.get("archetype_id"), " mat=", spr.material, " selfmodA=", spr.self_modulate.a, " g=", spr.global_position)
					# shader 嫌疑验证：摘掉材质再画
					spr.material = null
				moved = true
				break
	print("[XenoShot] pinned unit: ", moved)
	# ── 三组渲染对照实验 ──
	var tex_a: Texture2D = load("res://assets/card_icons/enemy/vis_xeno_zealot.png")
	var sheet_t: Texture2D = load("res://assets/effects/unit_anims/vis_xeno_zealot/sheet_idle.png")
	print("[XenoShot] tex_a=", tex_a, " sheet=", sheet_t)
	var at := AtlasTexture.new()
	at.atlas = sheet_t
	at.region = Rect2(0, 0, 256, 256)
	# A: 完整卡图 @ root
	var sA := Sprite2D.new()
	sA.texture = tex_a
	sA.position = Vector2(300, 300)
	sA.z_index = 300
	add_child(sA)
	# B: 完整卡图 @ EnemyUnits 层
	var sB := Sprite2D.new()
	sB.texture = tex_a
	sB.position = Vector2(640, 300)
	sB.z_index = 300
	(bf.get_node("EnemyUnits")).add_child(sB)
	# C: 星冥 AtlasTexture 帧 @ root
	var sC := Sprite2D.new()
	sC.texture = at
	sC.position = Vector2(980, 300)
	sC.z_index = 300
	add_child(sC)
	print("[XenoShot] control sprites added A@(300,300) B@(640,300) C@(980,300)")
	# H: known png 二分——fresh Node2D vs EnemyUnits
	var tex_h: Texture2D = load("res://assets/card_icons/enemy/vis_xeno_probe.png")
	var sH1 := Sprite2D.new()
	sH1.texture = tex_h
	sH1.position = Vector2(200, 400)
	sH1.z_index = 300
	var fresh2 := Node2D.new()
	bf.add_child(fresh2)
	fresh2.add_child(sH1)
	var sH2 := Sprite2D.new()
	sH2.texture = tex_h
	sH2.position = Vector2(800, 400)
	sH2.z_index = 300
	(bf.get_node("EnemyUnits")).add_child(sH2)
	print("[XenoShot] H1 knownpng@fresh(200,400) H2 knownpng@EnemyUnits(800,400)")
	# 二分：可见的背景节点下 vs Ambience 下
	var bgN: Node = bf.get_node_or_null("Level10Background")
	if bgN is Node2D:
		var sG := Sprite2D.new()
		sG.texture = tex_h
		sG.position = Vector2(150, 500)
		sG.z_index = 300
		bgN.add_child(sG)
		print("[XenoShot] G knownpng@Level10Background(150,500) bgTex=", bgN.texture != null, " bgMod=", bgN.modulate, " bgMat=", bgN.get("material"), " bgScale=", bgN.scale)
	var ambN: Node = bf.get_node_or_null("BattlefieldAmbience")
	if ambN is Node2D:
		var sI := Sprite2D.new()
		sI.texture = tex_h
		sI.position = Vector2(1100, 500)
		sI.z_index = 300
		ambN.add_child(sI)
		print("[XenoShot] I knownpng@Ambience(1100,500) ambMod=", ambN.modulate, " ambMat=", ambN.get("material"))
	# F: 新建普通 Node2D（非 y-sort）挂 bf，把第二只单位 reparent 进去
	var fresh := Node2D.new()
	bf.add_child(fresh)
	var eu3: Node = bf.get_node_or_null("EnemyUnits")
	var kids := eu3.get_children() if eu3 != null else []
	if kids.size() >= 2:
		var victim: Node = kids[1]
		victim.get_parent().remove_child(victim)
		fresh.add_child(victim)
		victim.set("position", Vector2(500, 300))
		print("[XenoShot] reparented ", victim.get("archetype_id"), " to fresh Node2D @ (500,300)")
	# 背景节点类型探查（它能画，我画不了——差在哪）
	for c in bf.get_children():
		var vtxt := "?"
		if c is CanvasItem:
			vtxt = str(c.is_visible_in_tree())
		print("[XenoShot] bf child: ", c.get_class(), " ", c.name, " vis=", vtxt)
	var euN: Node = bf.get_node_or_null("EnemyUnits")
	if euN != null:
		print("[XenoShot] EnemyUnits class=", euN.get_class(), " modulate=", euN.modulate, " selfmod=", euN.self_modulate,
			" mat=", euN.get("material"), " ysort=", euN.get("y_sort_enabled"),
			" visible=", euN.visible, " pos=", euN.position, " scale=", euN.scale)
	var puN: Node = bf.get_node_or_null("PlayerUnits")
	if puN != null:
		print("[XenoShot] PlayerUnits class=", puN.get_class(), " modulate=", puN.modulate, " mat=", puN.get("material"))
	# 全子树扫 CanvasModulate / 材质 / 特殊 canvas 节点
	var stack: Array[Node] = [bf]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is CanvasModulate:
				print("[XenoShot] CanvasModulate at ", n.name, "/", c.name, " color=", c.color)
			if c is CanvasGroup:
				print("[XenoShot] CanvasGroup at ", n.name, "/", c.name)
			stack.append(c)
	# battlefield 自身属性
	print("[XenoShot] bf self: class=", bf.get_class(), " modulate=", bf.modulate, " mat=", bf.get("material"))
	# D: 纯色 Polygon2D @ root（区分纹理 vs Node2D 渲染）
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(200, 150), Vector2(400, 150), Vector2(400, 250), Vector2(200, 250)])
	poly.color = Color(1, 0, 0)
	poly.z_index = 300
	add_child(poly)
	print("[XenoShot] polygon added")
	await _wait_frames(10)
	print("[XenoShot] enemies after forced wave=", _count_enemies(bf))
	# 直接截 SubViewport 自己的纹理（战场真身所在）
	var svp: SubViewport = main.get_node("BattleContainer/SubViewportContainer/SubViewport")
	var tex := svp.get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(OUT_IDLE))
		print("[XenoShot] subviewport shot saved, size=", img.get_size())
	await _wait_frames(35)
	img = tex.get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(OUT_ATK))
		print("[XenoShot] second subviewport shot saved")
	get_tree().quit(0)
