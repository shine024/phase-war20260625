class_name WorldMapReadyBuildTest
extends GdUnitTestSuite
## v6.35.2 回归锁：大地图「全黑零报错」根因——_ready 构建链被截断。
##
## 根因复盘（实机"100 关退回移动基地→进大地图全黑"，日志无任何脚本错误）：
## v6.35 往 world_map.gd 插入 `func _on_incursions_changed` 时落在了 `_ready`
## 函数体中段，把原 `_ready` 的后半段（call_deferred("_build_level_map")、
## 返回键接线、标题美化、浮层 chrome/图例）整体截成新函数的孤儿代码。
## 致命闭环：_on_incursions_changed 开头 `if not _map_built: return` 首次进图必早退；
## 即使走到 call_deferred，_build_level_map 开头 `if _map_built: return` 也空转——
## 构建函数在任何路径都不可达，地图只剩场景底色（黑屏），且全程零报错。
##
## 契约（scenes/world_map.gd _ready / _on_incursions_changed）：
## ① _ready 必须 call_deferred("_build_level_map")，约 2 帧后 _map_built==true；
## ② 画布含 VoidBase（底图纹理非空）+ 关卡按钮 >0 + BlackGateEntry 热区；
## ③ 返回键 BackToTitleButton.pressed 必须已接线（_ready 尾段存活的标志）；
## ④ 浮层 chrome（_window_hint_label）必须已建；
## ⑤ incursions_changed 信号消费只重建热区，不得炸掉已建画布。
## ⚠️ 勿把本锁的"插入新函数到 _ready 附近"操作再犯一次：新增函数一律放 _ready 之后。

const WorldMapScene := preload("res://scenes/world_map.tscn")
const WorldMapScript := preload("res://scenes/world_map.gd")

var _wm: Node = null


func before_test() -> void:
	_wm = WorldMapScene.instantiate()
	get_tree().root.add_child(_wm)
	# _build_level_map 走 call_deferred，fit/居中链再各吃一帧——给足 4 帧
	for i in range(4):
		await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(_wm):
		_wm.queue_free()
	_wm = null
	# 静态模板/窗口锚点跨测试进程存活，必须复位防污染其他用例
	WorldMapScript._cached_level_map_template = null
	WorldMapScript._built_window_anchor = -1
	WorldMapScript._s_revealed_levels.clear()


func _canvas() -> Control:
	var scroll: ScrollContainer = _wm.get_node_or_null("Margin/VBox/ScrollContainer")
	return scroll.get_node_or_null("MapCanvas") if scroll != null else null


## ①② 构建链必须从 _ready 自动跑通（回归旧截断此断言必红：_map_built 恒 false）
func test_ready_autobuilds_canvas_with_bg_and_level_nodes() -> void:
	assert_bool(_wm.get("_map_built")).is_true()
	var canvas := _canvas()
	assert_object(canvas).is_not_null()
	var bg: TextureRect = canvas.get_node_or_null("VoidBase")
	assert_object(bg).is_not_null()
	assert_object(bg.texture).is_not_null()
	var buttons := 0
	for c in canvas.get_children():
		if c is Button:
			buttons += 1
	assert_int(buttons).is_greater(0)


## ③ _ready 尾段存活标志：返回键已接线（被截断时 push_warning 且零连接）
func test_back_button_wired_by_ready() -> void:
	var back_btn: Button = _wm.find_child("BackToTitleButton", true, false)
	assert_object(back_btn).is_not_null()
	assert_int(back_btn.pressed.get_connections().size()).is_greater(0)


## ④ 浮层 chrome 必须已建（截断时 _window_hint_label 恒 null）
func test_screen_chrome_built() -> void:
	assert_object(_wm.get("_window_hint_label")).is_not_null()


## ⑤ 渗透信号消费不得破坏已建画布（v6.35 本意：只重建热区）
## 信号真身=EndlessBlackgateManager.incursions_changed（EBM 自有信号，非 SignalBus——
## 旧 has_signal("incursions_changed") 守卫恒 false 曾致该链从未接线，v6.35.2 修正）
func test_incursions_changed_keeps_canvas_alive() -> void:
	var canvas := _canvas()
	assert_object(canvas).is_not_null()
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	assert_object(ebm).is_not_null()
	assert_int(ebm.incursions_changed.get_connections().size()).is_greater(0)
	ebm.incursions_changed.emit()
	assert_bool(_wm.get("_map_built")).is_true()
	assert_object(_canvas()).is_not_null()
	assert_bool(is_instance_valid(canvas)).is_true()


## ⑥ 第100关「关卡情报」弹窗：门开启时黑门区块置顶+踏入按钮在列（v6.35.2 主诉修复：
## 实机"进入黑门显示的还是100关的信息/没显示多少波通关/掉落是关外的"——
## 玩家点 100 关节点时弹窗必须给出无尽口径与入口）
func test_level100_popup_embeds_gate_section_and_entry() -> void:
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	assert_object(lpm).is_not_null()
	var saved_stars: Dictionary = lpm.level_stars.duplicate()
	lpm.level_stars[100] = 1  # 门开启态（真实档：通关 100 有星）
	# v6.51 勘误：v6.42 黑门文案改双档（未通关=首场试炼/通关=无限模式）后，本锁的
	# 无条件"黑门 · 无限模式"断言过期（存量红锁——黑门区块与按钮本身两档都在）。
	# 改为两档各锁一遍，完测后还原 EBM 通关态。
	var ebm := get_node_or_null("/root/EndlessBlackgateManager")
	if ebm == null:
		var mll := get_node_or_null("/root/ManagerLazyLoader")
		if mll != null and mll.has_method("ensure_loaded"):
			mll.ensure_loaded("endless")
		ebm = get_node_or_null("/root/EndlessBlackgateManager")
	var saved_cleared: bool = bool(ebm.get("gate_cleared_once")) if ebm != null else false
	# 未通关档：首场试炼文案（波数口径=FIRST_GATE_CORE_WAVE 试炼）
	if ebm != null:
		ebm.set("gate_cleared_once", false)
	_wm.call("_show_level_info_popup", 100)
	await get_tree().process_frame
	var popup: Window = _wm.get("_level_info_popup")
	assert_object(popup).is_not_null()
	assert_str(popup.title).is_equal("关卡情报")
	assert_object(_find_button_by_text(popup, "踏入黑门")).is_not_null()
	assert_bool(_popup_contains_text(popup, "首场试炼")).is_true()
	assert_bool(_popup_contains_text(popup, "波数")).is_true()
	# 通关档：无限模式文案
	if ebm != null:
		ebm.set("gate_cleared_once", true)
	_wm.call("_show_level_info_popup", 100)
	await get_tree().process_frame
	popup = _wm.get("_level_info_popup")
	assert_object(popup).is_not_null()
	assert_object(_find_button_by_text(popup, "踏入黑门")).is_not_null()
	assert_bool(_popup_contains_text(popup, "黑门 · 无限模式")).is_true()
	if ebm != null:
		ebm.set("gate_cleared_once", saved_cleared)
	lpm.level_stars = saved_stars


## ⑦ 非 100 关弹窗不带黑门区块（防区块泄漏到普通关）
func test_normal_level_popup_has_no_gate_section() -> void:
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	var saved_stars: Dictionary = lpm.level_stars.duplicate()
	lpm.level_stars[100] = 1
	_wm.call("_show_level_info_popup", 5)
	await get_tree().process_frame
	var popup: Window = _wm.get("_level_info_popup")
	assert_object(popup).is_not_null()
	assert_object(_find_button_by_text(popup, "踏入黑门")).is_null()
	lpm.level_stars = saved_stars


## ⑧ v6.52（记录1#13/#30）：模板复用路径家/黑门入口摘旧重建——duplicate 不带
## gui_input 连接，复用副本此前点击全死（"通关 100 黑门还锁着/点家没反应"）；
## 解锁态/文案也随重建刷新（解锁后 modulate 1.0 + label 不再是"通关第 100 关开启"）。
func test_template_reuse_rebuilds_home_and_blackgate() -> void:
	var canvas := _canvas()
	assert_object(canvas).is_not_null()
	var home: Control = canvas.get_node_or_null("Lighthouse")
	var gate: Button = canvas.get_node_or_null("BlackGateEntry")
	assert_object(home).is_not_null()
	assert_object(gate).is_not_null()
	assert_int(home.gui_input.get_connections().size()).is_greater(0)
	assert_int(gate.gui_input.get_connections().size()).is_greater(0)
	# 未解锁档：门暗淡 + 锁定文案
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	var saved_stars: Dictionary = lpm.level_stars.duplicate()
	lpm.level_stars.erase(100)
	# 强制走复用分支：同锚点重建（_map_built 置 false 后 _build_level_map 重入）
	_wm.set("_map_built", false)
	_wm.call("_build_level_map")
	await get_tree().process_frame
	var canvas2 := _canvas()
	assert_object(canvas2).is_not_null()
	var gate2: Button = canvas2.get_node_or_null("BlackGateEntry")
	var home2: Control = canvas2.get_node_or_null("Lighthouse")
	assert_object(gate2).is_not_null()
	assert_object(home2).is_not_null()
	assert_int(home2.gui_input.get_connections().size()).is_greater(0)
	assert_int(gate2.gui_input.get_connections().size()).is_greater(0)
	assert_bool(gate2.modulate.a < 0.6).is_true()
	assert_str(gate2.tooltip_text).contains("通关第 100 关")
	# 解锁档：重建后门亮起 + 文案切试炼/无限
	lpm.level_stars[100] = 1
	_wm.set("_map_built", false)
	_wm.call("_build_level_map")
	await get_tree().process_frame
	var gate3: Button = _canvas().get_node_or_null("BlackGateEntry")
	assert_object(gate3).is_not_null()
	assert_bool(gate3.modulate.a > 0.9).is_true()
	assert_bool(gate3.tooltip_text.contains("通关第 100 关")).is_false()
	lpm.level_stars = saved_stars


func _find_button_by_text(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and String(root.text).contains(text):
		return root
	for c in root.get_children():
		var r := _find_button_by_text(c, text)
		if r != null:
			return r
	return null


func _popup_contains_text(root: Node, needle: String) -> bool:
	if root is Label and String(root.text).contains(needle):
		return true
	for c in root.get_children():
		if _popup_contains_text(c, needle):
			return true
	return false
