extends GdUnitTestSuite
## v6.51 回归锁：改造模块库低级在上 + 大地图渗透红点可见性。

const BackpackPanelScript := preload("res://scenes/ui/backpack_panel.gd")
const ModificationPanelScript := preload("res://scenes/ui/modification_panel.gd")
const ModRegistryScript := preload("res://scripts/systems/modification_registry.gd")
const WorldMapScene := preload("res://scenes/world_map.tscn")
const WorldMapScript := preload("res://scenes/world_map.gd")

var _wm: Node = null


func after_test() -> void:
	if is_instance_valid(_wm):
		_wm.queue_free()
	_wm = null
	var ebm := get_node_or_null("/root/EndlessBlackgateManager")
	if ebm != null:
		ebm.set("incursions", [])
	WorldMapScript._cached_level_map_template = null
	WorldMapScript._built_window_anchor = -1


# ═══ 改造模块库排序（用户拍板"上边先看到低级改造，越下边越高级"） ═══

## 背包改造模块库比较器：低稀有度在前
func test_backpack_blueprint_sort_low_first() -> void:
	assert_bool(BackpackPanelScript.compare_blueprints_low_first(
		{"rarity": "common", "mod_id": "b"}, {"rarity": "epic", "mod_id": "a"})).is_true()
	assert_bool(BackpackPanelScript.compare_blueprints_low_first(
		{"rarity": "mythic", "mod_id": "a"}, {"rarity": "common", "mod_id": "z"})).is_false()


## 背包：同档按 mod_id 字典序稳定（Godot sort 非稳定，防同档闪序）
func test_backpack_sort_tiebreak_by_mod_id() -> void:
	assert_bool(BackpackPanelScript.compare_blueprints_low_first(
		{"rarity": "rare", "mod_id": "air_01"}, {"rarity": "rare", "mod_id": "air_09"})).is_true()


## 改造舱中栏比较器：低稀有度在前（真实注册表数据）
func test_modification_panel_sort_low_first_with_registry() -> void:
	ModRegistryScript.register_all()
	var ids: Array = []
	for k in ModRegistryScript._flat_index.keys():
		ids.append(String(k))
	assert_int(ids.size()).is_greater(100)
	# 全量排序后稀有度权重必须单调不减（低→高）
	ids.sort_custom(ModificationPanelScript.compare_mods_low_first)
	var prev: int = 0
	for id in ids:
		var w: int = ModificationPanelScript._rarity_sort_value(
			String(ModRegistryScript.get_data(id).get("rarity", "common")))
		assert_int(w).is_greater_equal(prev)
		prev = w


# ═══ 大地图渗透红点可见性（主诉"说会刷新怪物但看不到红点"） ═══

func _build_map() -> Control:
	_wm = WorldMapScene.instantiate()
	get_tree().root.add_child(_wm)
	for i in range(4):
		await get_tree().process_frame
	var scroll: ScrollContainer = _wm.get_node_or_null("Margin/VBox/ScrollContainer")
	return scroll.get_node_or_null("MapCanvas") if scroll != null else null


func _stub_incursions(hosts: Array) -> void:
	var ebm := get_node_or_null("/root/EndlessBlackgateManager")
	if ebm == null:
		var mll := get_node_or_null("/root/ManagerLazyLoader")
		if mll != null and mll.has_method("ensure_loaded"):
			mll.ensure_loaded("endless")
		ebm = get_node_or_null("/root/EndlessBlackgateManager")
	assert_object(ebm).is_not_null()
	ebm.set("gate_cleared_once", false)
	var list: Array = []
	for i in range(hosts.size()):
		list.append({"host_level": int(hosts[i]), "seed": 1000 + i, "spawned_day": 1})
	ebm.set("incursions", list)


func _ensure_bunker_parked(parked: int) -> Node:
	var bm := get_node_or_null("/root/BunkerManager")
	if bm == null:
		var mll := get_node_or_null("/root/ManagerLazyLoader")
		if mll != null and mll.has_method("ensure_loaded"):
			mll.ensure_loaded("bunker")
		bm = get_node_or_null("/root/BunkerManager")
	assert_object(bm).is_not_null()
	bm.set("_parked_level", parked)
	return bm


## 渗透热区：窗外宿主不再被窗口半径 10 过滤（EBM 宿主范围 parked-15..+5，
## v6.51 前半径 10 会吃掉 parked-15..-11 段——主诉"看不到红点"主因）
func test_incursion_marker_beyond_window_radius_visible() -> void:
	_ensure_bunker_parked(30)
	# 停靠 30，宿主 17：|17-30|=13 > 旧窗口半径 10、≤ 新渗透半径 16
	_stub_incursions([17, 32])
	var canvas := await _build_map()
	assert_object(canvas).is_not_null()
	var holder: Control = canvas.get_node_or_null("IncursionMarkers")
	assert_object(holder).is_not_null()
	var marker: BaseButton = holder.get_node_or_null("Incursion_17_1000")
	assert_object(marker).is_not_null()  # 旧代码此处被窗口过滤 → 红


## 渗透热区层级：压在关卡节点之上、卡车光点之下（首建路径旧层级被白盘盖住）
func test_incursion_holder_z_between_level_nodes_and_truck_marker() -> void:
	_ensure_bunker_parked(30)
	_stub_incursions([30])
	var canvas := await _build_map()
	var holder: Control = canvas.get_node_or_null("IncursionMarkers")
	var truck: Control = canvas.get_node_or_null("TruckMarker")
	assert_object(holder).is_not_null()
	assert_object(truck).is_not_null()
	var holder_idx := holder.get_index()
	var truck_idx := truck.get_index()
	assert_int(holder_idx).is_less(truck_idx)      # 在卡车光点之下
	var first_level_idx := 99999
	for c in canvas.get_children():
		if c is Button and String(c.name).begins_with("LevelButton"):
			first_level_idx = mini(first_level_idx, c.get_index())
	assert_int(holder_idx).is_greater(first_level_idx)  # 在关卡节点之上


## EBM 懒加载后首次取到即补接线（_ready 期错过窗口 → 渗透变化永不重建热区）
func test_blackgate_mgr_wires_incursions_signal() -> void:
	_ensure_bunker_parked(1)
	_stub_incursions([5])
	var canvas := await _build_map()
	var ebm := get_node_or_null("/root/EndlessBlackgateManager")
	var wm_ebm: Node = _wm.call("_blackgate_mgr")
	assert_object(wm_ebm).is_equal(ebm)
	assert_bool(wm_ebm.incursions_changed.is_connected(_wm._on_incursions_changed)).is_true()
	# 信号驱动重建：增删后 holder 重铺（防旧快照挂着）
	ebm.set("incursions", [{"host_level": 6, "seed": 7, "spawned_day": 1}])
	ebm.incursions_changed.emit()
	await get_tree().process_frame
	var holder: Control = canvas.get_node_or_null("IncursionMarkers")
	assert_object(holder).is_not_null()
	assert_object(holder.get_node_or_null("Incursion_6_7")).is_not_null()
	assert_object(holder.get_node_or_null("Incursion_5_1000")).is_null()


## current_level 变化即重建"当前关"标示（旧条件"仅锚点迁移才刷新"漏掉同窗到站：
## 青环/▼标/CurDot 残留出发关——主诉"已经移动了，标示还在原关卡"）
## ⚠️ 全量跑时前面套件会改 GameManager.current_level/BunkerManager 停靠关——
## 钉死两者一致再建图（当前关必须落在窗口内才有 CurDot 可断言），完测还原。
func test_truck_level_changed_rebuilds_current_highlight() -> void:
	var saved_cur: int = int(GameManager.current_level) if GameManager else 1
	GameManager.current_level = 30
	_ensure_bunker_parked(30)
	var canvas := await _build_map()
	assert_object(canvas).is_not_null()
	var old_canvas_id: int = canvas.get_instance_id()
	_wm.call("_on_truck_level_changed", 30)
	await get_tree().process_frame
	var scroll: ScrollContainer = _wm.get_node_or_null("Margin/VBox/ScrollContainer")
	var new_canvas: Control = scroll.get_node_or_null("MapCanvas")
	assert_object(new_canvas).is_not_null()
	assert_int(new_canvas.get_instance_id()).is_not_equal(old_canvas_id)
	# 新画布的 CurDot 必须钉在当前 current_level 节点上
	var cur_btn: Control = new_canvas.get_node_or_null("LevelButton30")
	assert_object(cur_btn).is_not_null()
	assert_object(cur_btn.get_node_or_null("CurDot")).is_not_null()
	# 同帧撞名雷锁：重建后画布名必须仍是 MapCanvas（旧 queue_free+add 同名会被
	# 静默改名 @Control@N，_process/滚轮/渗透重建按名查找整链死透）
	assert_str(new_canvas.name).is_equal("MapCanvas")
	if GameManager:
		GameManager.current_level = saved_cur
