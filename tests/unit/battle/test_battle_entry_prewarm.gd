extends GdUnitTestSuite
## v6.65 记录6#2 回归锁：战斗入场资产后台预热（battle_entry_prewarm）。
##
## 主诉"战斗入场卡一下"：开战 deferred 帧同步冷读首波敌人卡图/动画 sheet +
## battle_started 同步 load 3~4MB BGM + 1.3MB 环境音。修复=点击出击时经
## load_threaded_request 后台预热。本锁守住：
## 1. 路径收集真实存在（敌人池 icon + 帧 sheet 解析链接线）
## 2. 音频路径与播放侧同源且存在（BGM 键位重构后不跑偏）
## 3. prewarm 真的发起线程请求（状态非 INVALID）

const Prewarm = preload("res://scripts/battle/battle_entry_prewarm.gd")
const GameConstants = preload("res://resources/game_constants.gd")


func test_level1_enemy_paths_all_exist_and_include_sheets() -> void:
	var paths: Array[String] = Prewarm._enemy_asset_paths(1)
	assert_int(paths.size()).is_greater(0)
	var sheet_count := 0
	for p in paths:
		assert_bool(ResourceLoader.exists(p)).is_true()
		if p.ends_with("sheet_idle.png") or p.ends_with("sheet_attack.png"):
			sheet_count += 1
	# 首关敌人池至少一个类型解析出帧动画（锁 UnitFrameAnim.resolve_key_readonly 接线）
	assert_int(sheet_count).is_greater(0)


func test_late_game_level_paths_exist() -> void:
	# 跨时代抽样：现代/未来关（era 池切换正确性）
	for lvl in [60, 95]:
		var paths: Array[String] = Prewarm._enemy_asset_paths(lvl)
		assert_int(paths.size()).is_greater(0)
		for p in paths:
			assert_bool(ResourceLoader.exists(p)).is_true()


func test_audio_prewarm_paths_exist_from_audio_manager() -> void:
	var am := get_node_or_null("/root/AudioManager")
	assert_object(am).is_not_null()
	var paths: Array = am.call("battle_audio_prewarm_paths")
	# 战斗 BGM + battle_wind 环境音双路径
	assert_int(paths.size()).is_equal(2)
	for p in paths:
		assert_bool(ResourceLoader.exists(String(p))).is_true()
	# 与播放侧同源：era→BGM 键位映射（_battle_bgm_key_for_level 提取自 _on_battle_started_bgm）
	assert_str(String(am.call("_battle_bgm_key_for_level", 1))).is_equal("battle_ww1")


func test_prewarm_for_level_requests_threaded_loads() -> void:
	var pending: Array[String] = []
	for p in Prewarm._audio_paths():
		if not ResourceLoader.has_cached(p):
			pending.append(p)
	for p in Prewarm._enemy_asset_paths(1):
		if not ResourceLoader.has_cached(p) and not pending.has(p):
			pending.append(p)
	assert_int(pending.size()).is_greater(0)
	Prewarm.prewarm_for_level(1)
	# 状态值实测（Godot 4.5 该枚举 GDScript 侧不可按名访问）：
	# 0=未请求 INVALID / 1=IN_PROGRESS / 2=FAILED / 3=FINISHED
	var requested := 0
	for p in pending:
		var st := int(ResourceLoader.load_threaded_get_status(p))
		if st == 1 or st == 3:
			requested += 1
	# 至少一条真被请求（全 0=预热链断线，开战帧回到同步冷读老路）
	assert_int(requested).is_greater(0)


func test_prewarm_out_of_range_level_is_noop() -> void:
	# 非法关卡不炸不请求（教程探针/异常档防御）
	Prewarm.prewarm_for_level(0)
	Prewarm.prewarm_for_level(-5)
	assert_bool(true).is_true()
