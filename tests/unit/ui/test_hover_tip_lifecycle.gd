extends GdUnitTestSuite
## v6.51 回归锁：HoverTip 生命周期。
##
## 修复前行为（实机主诉"在相位仪面板移动鼠标还会出现符文的情报；在移动基地界面
## 还在跳出符文情报"）：_tip_owner 只在 _dismiss 置 null、从未赋值 → _hide_for 的
## 归属校验恒 false → 提示一旦弹出永不消失，跟着鼠标走遍所有面板。
## 叠加主诉"马上出情报太急"：加 SHOW_DELAY 延迟显示（已有提示切换控件立即换内容）。
##
## 契约（scripts/ui/hover_tip.gd）：
## ① mouse_entered 后不立即显示（延迟窗内不可见）；
## ② 延迟到期后显示且 _tip_owner 归属该控件；
## ③ mouse_exited（_hide_for）按归属收起——归属错位时不得误收别的控件的提示；
## ④ 已显示时悬停新控件立即切换内容并转移归属；
## ⑤ meta 清空（对象池复用）后 _show_for 取消待显且收起自己的旧提示。

const HoverTipScript := preload("res://scripts/ui/hover_tip.gd")
const SHOW_DELAY: float = 0.45


func _mounted_ctrl(p_name: String) -> Control:
	var c := Control.new()
	c.name = p_name
	c.position = Vector2(0, 0)
	c.size = Vector2(200, 100)
	get_tree().root.add_child(c)
	return c


func after_test() -> void:
	var inst := HoverTipScript.instance()
	if inst != null:
		inst._dismiss()
		inst._pending_ctrl = null


## ①+② 延迟显示 + 归属记录（修 _tip_owner 恒 null 的存量 bug）
func test_delayed_show_then_owner_assigned() -> void:
	var c1 := _mounted_ctrl("HTC1")
	HoverTipScript.bind_control(c1)
	HoverTipScript.set_tip(c1, "测试提示A")
	HoverTipScript._show_for(c1)
	var inst := HoverTipScript.instance()
	assert_bool(inst.visible).is_false()  # ① 延迟窗内不得立即弹出
	await get_tree().create_timer(SHOW_DELAY + 0.25).timeout
	assert_bool(inst.visible).is_true()   # ② 到期弹出
	assert_object(inst._tip_owner).is_equal(c1)
	c1.free()


## ③ mouse_exited 按归属收起；别的控件退出不误收
func test_hide_for_owner_dismisses() -> void:
	var c1 := _mounted_ctrl("HTC2")
	HoverTipScript.bind_control(c1)
	HoverTipScript.set_tip(c1, "测试提示B")
	HoverTipScript._show_for(c1)
	await get_tree().create_timer(SHOW_DELAY + 0.25).timeout
	var inst := HoverTipScript.instance()
	assert_bool(inst.visible).is_true()
	HoverTipScript._hide_for(c1)
	assert_bool(inst.visible).is_false()
	assert_object(inst._tip_owner).is_null()
	c1.free()


## ④ 已显示时切换控件立即换内容（列表扫读零延迟）
func test_switch_control_when_visible_transfers_owner() -> void:
	var c1 := _mounted_ctrl("HTC3a")
	var c2 := _mounted_ctrl("HTC3b")
	HoverTipScript.bind_control(c1)
	HoverTipScript.bind_control(c2)
	HoverTipScript.set_tip(c1, "提示一")
	HoverTipScript.set_tip(c2, "提示二")
	HoverTipScript._show_for(c1)
	await get_tree().create_timer(SHOW_DELAY + 0.25).timeout
	var inst := HoverTipScript.instance()
	assert_bool(inst.visible).is_true()
	HoverTipScript._show_for(c2)
	assert_bool(inst.visible).is_true()
	assert_str(inst._label.text).is_equal("提示二")
	assert_object(inst._tip_owner).is_equal(c2)
	# 旧控件退出不得收起新提示（旧 bug 场景的反向保护）
	HoverTipScript._hide_for(c1)
	assert_bool(inst.visible).is_true()
	HoverTipScript._hide_for(c2)
	assert_bool(inst.visible).is_false()
	c1.free()
	c2.free()


## ⑤ meta 清空：待显取消 + 已显示的自己人收起
func test_empty_tip_cancels_pending_and_hides_own() -> void:
	var c1 := _mounted_ctrl("HTC4")
	HoverTipScript.bind_control(c1)
	HoverTipScript.set_tip(c1, "会清空的提示")
	HoverTipScript._show_for(c1)
	var inst := HoverTipScript.instance()
	assert_object(inst._pending_ctrl).is_equal(c1)
	HoverTipScript.set_tip(c1, "")
	HoverTipScript._show_for(c1)
	assert_object(inst._pending_ctrl).is_null()
	await get_tree().create_timer(SHOW_DELAY + 0.25).timeout
	assert_bool(inst.visible).is_false()
	c1.free()
