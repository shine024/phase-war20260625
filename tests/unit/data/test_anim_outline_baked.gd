extends GdUnitTestSuite
## v6.15 描边预烘焙回归锁（deploy_unit_anims.py --bake-existing / --bake-boss-frames / 发布流程接入）
## 覆盖：anim.json outline.baked 标记存在 / is_outline_baked 查询链（key 解析+json 缓存）/
## boss 逐帧资产（BossIdleAnim 消费）--bake-boss-frames 烘焙标记与 shader 跳过链。

var FrameAnim := preload("res://scripts/battle/unit_frame_anim.gd")

const ANIM_ROOT := "res://assets/effects/unit_anims/"

func _sheet_dirs() -> Array:
	var out: Array = []
	var d := DirAccess.open(ANIM_ROOT)
	if d == null:
		return out
	for sub in d.get_directories():
		if sub.begins_with("boss_") or sub.begins_with("enemy_master"):
			continue
		if ResourceLoader.exists(ANIM_ROOT + sub + "/anim.json") \
				and ResourceLoader.exists(ANIM_ROOT + sub + "/sheet_idle.png"):
			out.append(sub)
	return out

func _boss_frame_dirs() -> Array:
	## boss/相位师逐帧资产目录：有 idle_f0.png 即算（与 BossIdleAnim._load_frames 同口径）
	var out: Array = []
	var d := DirAccess.open(ANIM_ROOT)
	if d == null:
		return out
	for sub in d.get_directories():
		if ResourceLoader.exists(ANIM_ROOT + sub + "/idle_f0.png"):
			out.append(sub)
	return out

func test_baked_sheets_have_outline_meta() -> void:
	# 烘焙过的 sheet 目录 anim.json 必须带 outline.baked=true（Godot 侧跳 shader 的唯一依据）
	var missing: Array = []
	for key in _sheet_dirs():
		var meta: Dictionary = FrameAnim._load_json(ANIM_ROOT + key + "/anim.json")
		if not bool(meta.get("outline", {}).get("baked", false)):
			missing.append(key)
	assert_array(missing).override_failure_message(
		"缺 outline.baked 标记：%s（重跑 python tools/deploy_unit_anims.py --bake-existing）" % str(missing.slice(0, 10))).is_empty()

func test_is_outline_baked_query_chain() -> void:
	# 有动画资产且已烘焙 → true（走 cold_ak 固定样张，deploy 排除名单不含它）
	assert_bool(FrameAnim.is_outline_baked("cold_ak")).is_true()
	# 不存在的 id → false（静态卡图单位继续走 shader）
	assert_bool(FrameAnim.is_outline_baked("__no_such_unit__")).is_false()
	assert_bool(FrameAnim.is_outline_baked("")).is_false()

func test_boss_frame_baked_and_shader_skipped() -> void:
	# v6.15.1: boss 逐帧目录必须全量烘焙（is_outline_baked=true → 呈现层跳 shader，
	# BossIdleAnim 换帧不吃二次外扩）；新增 boss 帧未烘焙 = 半烘焙态，直接在此报错
	var unbaked: Array = []
	for sub in _boss_frame_dirs():
		if not FrameAnim.is_outline_baked(String(sub)):
			unbaked.append(sub)
	assert_array(unbaked).override_failure_message(
		"boss 逐帧未烘焙/缺标记：%s（重跑 python tools/deploy_unit_anims.py --bake-boss-frames）" % str(unbaked)).is_empty()

func test_captured_boss_follows_base_card_baked_flag() -> void:
	# v6.57 记录3#7 起缴获单位继承本体卡帧资产（修"缴获经典单位战场永静画"）——
	# 旧断言"缴获 boss 无帧资产走静态卡图+shader"过时：本体资产已烘焙（v6.6x 美术批，
	# 与上一用例"boss 逐帧必须全量烘焙"同源），captured_* 的 baked 旗标跟随本体卡
	# anim.json=true → 呈现层跳 shader（防双重描边），"静态卡图丢描边"前提不再成立。
	assert_bool(FrameAnim.is_outline_baked("captured_cold_boss_mig")).is_true()
	# 真无帧资产的 id（缴获目录与剥前缀本体都不存在）→ false，静态卡图继续走 shader
	assert_bool(FrameAnim.is_outline_baked("captured___no_such_unit__")).is_false()
