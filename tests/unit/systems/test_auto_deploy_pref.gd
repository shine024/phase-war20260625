extends GdUnitTestSuite
## v32.3 A3 回归锁：自动部署偏好持久化（user://battle_speed.cfg [deploy] 段）。
## 两条不变式：①默认开；②speed/deploy 两段互不抹除（v31 settings.cfg 整文件覆写教训同源）。

const BattleTimeState = preload("res://scripts/battle/battle_time_state.gd")


func test_default_enabled() -> void:
	# 默认开——"战术构筑放置"定位：自动上阵是特性，手动部署留给熟练玩家
	assert_bool(BattleTimeState.AUTO_DEPLOY_DEFAULT).is_true()


func test_deploy_roundtrip() -> void:
	var original_deploy := BattleTimeState.load_auto_deploy_pref()
	BattleTimeState.save_auto_deploy_pref(false)
	assert_bool(BattleTimeState.load_auto_deploy_pref()).is_false()
	BattleTimeState.save_auto_deploy_pref(true)
	assert_bool(BattleTimeState.load_auto_deploy_pref()).is_true()
	# 还原（防御：不污染后续用例/玩家偏好）
	BattleTimeState.save_auto_deploy_pref(original_deploy)


func test_speed_and_deploy_sections_coexist() -> void:
	# speed 段写入不得抹掉 deploy 段（save_pref 读-改-写回归锁）
	var cf := ConfigFile.new()
	cf.set_value("deploy", "auto_deploy", false)
	cf.save(BattleTimeState.PREF_PATH)
	BattleTimeState.user_scale = 3.0
	BattleTimeState.save_pref()
	var cf2 := ConfigFile.new()
	assert_bool(cf2.load(BattleTimeState.PREF_PATH) == OK).is_true()
	assert_bool(bool(cf2.get_value("deploy", "auto_deploy", true))).is_false()
	assert_float(float(cf2.get_value("speed", "user_scale", 0.0))).is_equal(3.0)
	# deploy 写入不得抹掉 speed 段
	BattleTimeState.save_auto_deploy_pref(true)
	var cf3 := ConfigFile.new()
	cf3.load(BattleTimeState.PREF_PATH)
	assert_float(float(cf3.get_value("speed", "user_scale", 0.0))).is_equal(3.0)
	assert_bool(bool(cf3.get_value("deploy", "auto_deploy", false))).is_true()
	# 清理测试文件（该 cfg 只承载玩家偏好，测试不落痕）
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BattleTimeState.PREF_PATH))
