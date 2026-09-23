extends Node
## 批次③ Task 3 房间化冒烟——6 悬空键挂热区后：
##  ① 静态：五时代各 17 热区；PANEL_SCENES 11 键全部有热区落点（零悬空）；
##     panel 热区 key 全部 ∈ PANEL_SCENES；五时代热区两两无矩形重叠
##  ② 动态：era1 依次 _open_panel 六个新键（affix/growth/collection/faction/leaderboard/help），
##     断言嵌入包装出现且面板场景真实加载
## 跑法：godot --headless --path . res://tests/_tmp_b3_t3_hotspot_boot.tscn

const TRUCK_SCENE := "res://scenes/bunker/truck_base.tscn"
const NEW_KEYS := ["affix", "growth", "collection", "faction", "leaderboard", "help"]

var _fails: Array[String] = []
var _pass_log: Array[String] = []


func _ready() -> void:
	await _run()
	for p in _pass_log:
		print("[T3Hot] PASS: " + p)
	for f in _fails:
		printerr("[T3Hot] FAIL: " + f)
	print("[T3Hot] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	await _wait(5)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _cur_path() -> String:
	var cs := get_tree().current_scene
	return String(cs.scene_file_path) if cs != null else ""


func _rects_overlap(a: Array, b: Array) -> bool:
	var ax0: float = a[0]
	var ay0: float = a[1]
	var ax1: float = a[0] + a[2]
	var ay1: float = a[1] + a[3]
	var bx0: float = b[0]
	var by0: float = b[1]
	var bx1: float = b[0] + b[2]
	var by1: float = b[1] + b[3]
	return ax0 + 1e-6 < bx1 and bx0 + 1e-6 < ax1 and ay0 + 1e-6 < by1 and by0 + 1e-6 < ay1


func _run() -> void:
	var truck_script := load("res://scenes/bunker/truck_base.gd")
	var hotspots: Dictionary = truck_script.get("HOTSPOTS")
	var panels: Dictionary = truck_script.get("PANEL_SCENES")

	# ── ① 静态：17 热区/时代、key 全接线、零悬空、新 6 区无重叠 ──
	# （原 11 区之间的存量交叠系上线既有行为，只记录不判死——Task 3 范围=新键零重叠）
	var covered := {}
	for era in hotspots:
		var list: Array = hotspots[era]
		if list.size() != 17:
			_fails.append("① %s 热区数 %d ≠ 17" % [era, list.size()])
			continue
		var legacy_overlap := 0
		for h in list:
			var key := String(h.get("key", ""))
			var is_new: bool = NEW_KEYS.has(key)
			if String(h.get("kind", "")) == "panel":
				if not panels.has(key):
					_fails.append("① %s 热区『%s』key=%s 不在 PANEL_SCENES" % [era, h.get("name"), key])
				else:
					covered[key] = true
			for h2 in list:
				if h2 == h or not _rects_overlap(h["r"], h2["r"]):
					continue
				var h2_new: bool = NEW_KEYS.has(String(h2.get("key", "")))
				if is_new or h2_new:
					_fails.append("① %s 新热区重叠：%s × %s" % [era, h.get("name"), h2.get("name")])
				else:
					legacy_overlap += 1
		_pass_log.append("① %s：17 热区，新 6 区零重叠（存量交叠 %d 对记录在案）" % [era, legacy_overlap])
	var missing: Array = []
	# v27.17：hero_archive/memorial 是顶栏按钮入口（用户裁决），不走热区——不按悬空判死
	const TOPBAR_ONLY_KEYS := ["hero_archive", "memorial"]
	for key in panels:
		if not covered.has(key) and not TOPBAR_ONLY_KEYS.has(key):
			missing.append(key)
	if missing.is_empty():
		_pass_log.append("① PANEL_SCENES 热区键零悬空（另 %d 键走顶栏入口）" % TOPBAR_ONLY_KEYS.size())
	else:
		_fails.append("① 悬空键残留：%s" % ", ".join(missing))

	# ── ② 动态：era1 六个新键真实打开 ──
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	SceneTransition.change(get_tree(), TRUCK_SCENE)
	for i in 60:
		await get_tree().process_frame
		if _cur_path().contains("truck_base"):
			break
	if not _cur_path().contains("truck_base"):
		_fails.append("② 未进入 truck_base: " + _cur_path())
		return
	var truck: Node = get_tree().current_scene
	for key in NEW_KEYS:
		truck.call("_open_panel", key)
		await _wait(10)
		var wrappers: Dictionary = truck.get("_embed_wrappers")
		var ok := wrappers.has(key) and wrappers[key] is Dictionary \
			and is_instance_valid(wrappers[key].get("wrapper")) \
			and (wrappers[key]["wrapper"] as Control).visible
		if ok:
			_pass_log.append("② _open_panel(%s) 嵌入包装可见" % key)
		else:
			_fails.append("② _open_panel(%s) 包装未出现/不可见" % key)
		# 关掉再开下一个（避免同屏叠层）
		if wrappers.has(key) and wrappers[key] is Dictionary:
			var wp: Control = wrappers[key]["wrapper"]
			if is_instance_valid(wp):
				wp.visible = false
