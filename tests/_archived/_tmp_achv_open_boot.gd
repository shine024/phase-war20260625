extends SceneTree
## 临时验证（2026-09-11）：成就面板 E1 服务区块的可见打开路径。
## b2_panel_boot 只验证实例化+标题；本脚本把面板真实挂树可见（触发 refresh 全链），
## 断言：服务区块存在且两行内容非空，退出码 0/1。

func _initialize() -> void:
	_process_boot()

func _process_boot() -> void:
	var panel = load("res://scenes/ui/achievement_panel.tscn").instantiate()
	root.add_child(panel)
	# 等 @onready + _ready + 首帧布局
	await process_frame
	await process_frame
	if not panel.is_visible_in_tree():
		panel.visible = true
	await process_frame
	print("[achv-open] mgr=%s root_mgr=%s" % [
		str(panel.achievement_manager != null),
		str(root.get_node_or_null("/root/AchievementManager") != null)])
	var found_block: bool = false
	var recent_txt: String = ""
	var reco_txt: String = ""
	for child in panel.get_node("Margin/VBox").get_children():
		if child is VBoxContainer:
			found_block = true
			var rows: Array = child.get_children()
			for r in rows:
				if r is HBoxContainer:
					var parts: Array[String] = []
					for c in r.get_children():
						parts.append(String(c.text))
					if recent_txt.is_empty():
						recent_txt = "｜".join(parts)
					else:
						reco_txt = "｜".join(parts)
	print("[achv-open] service_block=%s" % found_block)
	print("[achv-open] recent: %s" % recent_txt)
	print("[achv-open] reco:   %s" % reco_txt)
	var ok: bool = found_block and not recent_txt.is_empty() and not reco_txt.is_empty()
	print("[achv-open] %s" % ("OK" if ok else "FAIL"))
	quit(0 if ok else 1)
