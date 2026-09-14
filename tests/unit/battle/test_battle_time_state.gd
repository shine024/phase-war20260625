extends GdUnitTestSuite
## v32.0 B1-1 战斗时间状态单测（定位转向"战术构筑放置"批1）
## 覆盖：倍速档就近吸附 / 偏好持久化往返 / 越档值吸附 /
## 极速推演引擎态进出（time_scale + 物理步进产能）/ 中性复位。
## 注意：BattleTimeState 是静态状态 + Engine 全局属性，before/after 强制复位，
## 并备份/还原真实偏好文件 user://battle_speed.cfg。

const BTS = preload("res://scripts/battle/battle_time_state.gd")
const _PREF_PATH := "user://battle_speed.cfg"

var _pref_existed := false
var _pref_backup := ""


func before_test() -> void:
	BTS.restore_neutral()
	BTS.user_scale = 1.0
	BTS.reset_pref_cache()
	_pref_existed = FileAccess.file_exists(_PREF_PATH)
	if _pref_existed:
		_pref_backup = FileAccess.get_file_as_string(_PREF_PATH)


func after_test() -> void:
	BTS.restore_neutral()
	BTS.user_scale = 1.0
	BTS.reset_pref_cache()
	if _pref_existed:
		var f := FileAccess.open(_PREF_PATH, FileAccess.WRITE)
		f.store_string(_pref_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PREF_PATH))


func test_snap_scale_nearest_option() -> void:
	assert_float(BTS.snap_scale(0.0)).is_equal(1.0)
	assert_float(BTS.snap_scale(1.4)).is_equal(1.0)
	assert_float(BTS.snap_scale(2.6)).is_equal(3.0)
	assert_float(BTS.snap_scale(9.9)).is_equal(4.0)


func test_save_load_roundtrip() -> void:
	BTS.user_scale = 3.0
	BTS.save_pref()
	BTS.user_scale = 1.0
	BTS.reset_pref_cache()
	assert_float(BTS.load_pref()).is_equal(3.0)


func test_load_pref_snapes_out_of_range() -> void:
	var f := FileAccess.open(_PREF_PATH, FileAccess.WRITE)
	f.store_string("[speed]\n\nuser_scale=9.9\n")
	f.close()
	BTS.reset_pref_cache()
	assert_float(BTS.load_pref()).is_equal(4.0)


func test_load_pref_absent_defaults_to_1x() -> void:
	if FileAccess.file_exists(_PREF_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PREF_PATH))
	BTS.reset_pref_cache()
	assert_float(BTS.load_pref()).is_equal(1.0)


func test_fast_forward_enter_exit() -> void:
	BTS.enter_fast_forward()
	assert_bool(BTS.ff_active).is_true()
	assert_float(Engine.time_scale).is_equal(BTS.FF_TIME_SCALE)
	assert_int(Engine.max_physics_steps_per_frame).is_equal(BTS.FF_MAX_PHYSICS_STEPS)
	BTS.exit_fast_forward(2.0)
	assert_bool(BTS.ff_active).is_false()
	assert_float(Engine.time_scale).is_equal(2.0)
	assert_int(Engine.max_physics_steps_per_frame).is_equal(BTS.DEFAULT_MAX_PHYSICS_STEPS)


func test_restore_neutral() -> void:
	BTS.enter_fast_forward()
	BTS.restore_neutral()
	assert_bool(BTS.ff_active).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_int(Engine.max_physics_steps_per_frame).is_equal(BTS.DEFAULT_MAX_PHYSICS_STEPS)


func test_speed_options_have_four_tiers() -> void:
	# v32.0 B1-1: 1x/2x/3x/4x 四档（R1-6 的 ×3 保留，新增 ×4）
	assert_int(BTS.SPEED_OPTIONS.size()).is_equal(4)
	assert_float(BTS.SPEED_OPTIONS[0]).is_equal(1.0)
	assert_float(BTS.SPEED_OPTIONS[3]).is_equal(4.0)
