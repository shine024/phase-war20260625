extends Node
## 战功簿空容器活体探针（临时工具，可删）：
## 带存档打开战功簿，dump 列表节点树/条目内容/管理器数据，配合截图定位空卡成因。
## 运行：echo "achprobe" > .godot/steam_cap_mode.txt 后窗口化跑本场景。

const SHOT_DIR := "res://_steam_assets/shots/"


func _ready() -> void:
	get_window().always_on_top = true
	var spec := "achprobe"
	if FileAccess.file_exists("res://.godot/steam_cap_mode.txt"):
		spec = FileAccess.get_file_as_string("res://.godot/steam_cap_mode.txt").strip_edges()
	if spec.split(" ", false)[0] != "achprobe":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _wait_frames(20)
	var main: Node = await _boot_main()
	main.call("_toggle_overlay", main.get("achievement_overlay"), "achievement")
	await _wait_frames(90)
	_shot("v3_achievement.png")
	_dump()
	get_tree().quit(0)


func _dump() -> void:
	var m := get_node_or_null("/root/AchievementManager")
	if m != null and m.has_method("get_all_achievements"):
		var all: Array = m.call("get_all_achievements")
		print("[AchProbe] manager total=", all.size())
		for i in range(mini(3, all.size())):
			print("[AchProbe] first[%d] id=%s name=%s" % [i, str(all[i].get("id")), str(all[i].get("name"))])
	var overlay: Node = get_tree().root.get_node_or_null("Main")
	if overlay == null:
		for n in get_tree().root.get_children():
			if n.name == "Main":
				overlay = n
				break
	var lists: Array = []
	_find_named(overlay, "AchievementList", lists)
	for n in lists:
		var c := n as Control
		print("[AchProbe] node=%s class=%s rect=%s children=%d" % [
			str(n.get_path()), n.get_class(),
			str(c.get_global_rect()) if c != null else "?",
			str(n.get_child_count())])
		if n.get_class() == "VBoxContainer":
			for i in range(mini(4, n.get_child_count())):
				var item := n.get_child(i) as Control
				if item == null:
					continue
				var texts: Array = []
				_collect_texts(item, texts, 0)
				print("[AchProbe]   item[%d] class=%s size=%s visible=%s texts=%s" % [
					i, item.get_class(), str(item.size), str(item.visible),
					str(texts.slice(0, 4))])


func _find_named(node: Node, want: String, out: Array) -> void:
	if node.name == want:
		out.append(node)
	for ch in node.get_children():
		_find_named(ch, want, out)


func _collect_texts(node: Node, out: Array, depth: int) -> void:
	if depth > 3:
		return
	if node is Label or node is RichTextLabel:
		var t: String = (node as RichTextLabel).text if node is RichTextLabel else (node as Label).text
		if not t.strip_edges().is_empty():
			out.append(t.strip_edges().left(24))
	for ch in node.get_children():
		_collect_texts(ch, out, depth + 1)


func _shot(fname: String) -> void:
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(SHOT_DIR + fname)
		print("[AchProbe] shot ", fname)


func _boot_main() -> Node:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	await _wait_frames(10)
	var inst: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	await _wait_frames(150)
	var popup: Node = inst.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	return inst


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
