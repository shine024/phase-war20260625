extends SceneTree
## 成长面板加载验证脚本

func _init() -> void:
	print("=== GrowthPanel Load Check ===")

	# 1. 检查场景文件是否存在
	var tscn_path := "res://scenes/ui/growth_panel.tscn"
	if not ResourceLoader.exists(tscn_path):
		print("FAIL: %s does not exist" % tscn_path)
		quit(1)
		return
	print("OK: scene file exists")

	# 2. 尝试加载场景
	var scene := load(tscn_path) as PackedScene
	if scene == null:
		print("FAIL: load() returned null for %s" % tscn_path)
		quit(1)
		return
	print("OK: scene loaded as PackedScene")

	# 3. 尝试实例化
	var instance := scene.instantiate()
	if instance == null:
		print("FAIL: instantiate() returned null")
		quit(1)
		return
	print("OK: scene instantiated, type=%s name=%s" % [instance.get_class(), instance.name])

	# 4. 检查脚本是否加载
	var script := instance.get_script() as GDScript
	if script == null:
		print("WARN: no script attached")
	else:
		print("OK: script loaded: %s" % script.resource_path)

	# 5. 检查子节点数量
	var child_count := instance.get_child_count()
	print("OK: root has %d children" % child_count)

	# 6. 检查关键子节点
	var checks := {
		"RootVBox": false,
	}
	for child_name in checks:
		var found := instance.find_child(child_name, true, false)
		if found:
			print("OK: found child '%s'" % child_name)
		else:
			print("WARN: child '%s' not found" % child_name)

	# 7. 检查 mod_slot_item 预加载
	var mod_path := "res://scenes/ui/mod_slot_item.tscn"
	if ResourceLoader.exists(mod_path):
		var mod_scene := load(mod_path) as PackedScene
		if mod_scene:
			print("OK: mod_slot_item.tscn loads fine")
		else:
			print("FAIL: mod_slot_item.tscn load() returned null")
	else:
		print("FAIL: mod_slot_item.tscn does not exist")

	# 8. 检查 unique_name_in_owner 节点
	# 8. 检查 unique_name_in_owner（需要进树才能解析 %）
	# 不加进树，只检查 unique_name_in_owner 标记
	var all_nodes := _collect_all_nodes(instance)
	var unique_found := 0
	for n in all_nodes:
		if n.unique_name_in_owner:
			unique_found += 1
	print("OK: %d nodes have unique_name_in_owner=true" % unique_found)

	print("=== All checks complete ===")
	quit(0)

func _collect_all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_collect_all_nodes(child))
	return result
