class_name GarrisonAnimAliasTest
extends GdUnitTestSuite
## v6.21 回归锁：相位师编成单位分帧动画解析全覆盖。
## 实机反馈：相位师敌方卡有些单位站桩无动画（C 段卡目录名错位 + 平台 id 无落点）。
## 修复：UnitFrameAnim.ANIM_ALIAS 视觉别名表（链尾兜底）。
## 例外：cold_boss_mig / fut_boss_nexus 走 BossIdleAnim 单帧系统（idle_f*.png），
## 不在 UnitFrameAnim 解析链，允许 resolve 为空。

const UnitFrameAnim := preload("res://scripts/battle/unit_frame_anim.gd")
const BOSS_SINGLE_FRAME := ["cold_boss_mig", "fut_boss_nexus"]


func _all_platform_ids() -> Array[String]:
	var out: Array[String] = []
	var txt := FileAccess.get_file_as_string("res://data/json/enemy_phase_masters.json")
	var parsed: Variant = JSON.parse_string(txt)
	assert_bool(typeof(parsed) == TYPE_DICTIONARY).is_true()
	for m: Dictionary in (parsed as Dictionary).get("data", []):
		for p: Variant in m.get("equipment", {}).get("platforms", []):
			var s := String(p)
			if not out.has(s):
				out.append(s)
	return out


func test_garrison_platforms_resolve_animation() -> void:
	var ids := _all_platform_ids()
	assert_int(ids.size()).is_greater(0)
	for uid in ids:
		var key := String(UnitFrameAnim._resolve_key(uid))
		if uid in BOSS_SINGLE_FRAME:
			continue  # BossIdleAnim 单帧系统管辖
		assert_str(key).override_failure_message("相位师平台 %s 无动画落点（站桩）" % uid).is_not_empty()


func test_alias_targets_are_complete_sheets() -> void:
	for uid: String in UnitFrameAnim.ANIM_ALIAS.keys():
		var alias := String(UnitFrameAnim.ANIM_ALIAS[uid])
		assert_bool(ResourceLoader.exists("res://assets/effects/unit_anims/%s/sheet_idle.png" % alias)) \
			.override_failure_message("别名 %s → %s 缺 sheet_idle.png" % [uid, alias]).is_true()
		assert_bool(ResourceLoader.exists("res://assets/effects/unit_anims/%s/anim.json" % alias)) \
			.override_failure_message("别名 %s → %s 缺 anim.json" % [uid, alias]).is_true()


func test_boss_single_frame_dirs_have_frame_seq() -> void:
	for uid in BOSS_SINGLE_FRAME:
		assert_bool(ResourceLoader.exists("res://assets/effects/unit_anims/%s/anim.json" % uid)) \
			.override_failure_message("%s 缺 BossIdleAnim anim.json" % uid).is_true()
