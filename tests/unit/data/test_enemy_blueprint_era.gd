extends GdUnitTestSuite
## 蓝图卡 era 回归锁（v6.21.3，2026-09-22 美术质检报告发现 #2）
## 契约：`_create_generated_blueprints()` 按五个时代生成 bp_* 卡，卡的 era 字段
## 必须等于生成时代——否则 UiAssetLoader.ERA_KIND_FALLBACK_ICON 的 25 桶
## （时代_兵种）坍缩进二战行 4 桶：54 张蓝图同脸 + 类型错位（防空塔→迫击炮图）
## + 图标时代与 id 前缀（ww1/ww2/cold/modern/near）脱节。
## 同时锁定：6 张手写特殊卡（bulwark/titan_mk2/storm_rider/heavy_carrier/
## regen_frame/abrams_mk2）保持 era=1 原设计值不变（_p 默认参数路径）。

const EnemyBlueprints := preload("res://data/enemy_blueprints.gd")

const _PREFIX_TO_ERA := {"ww1": 0, "ww2": 1, "cold": 2, "modern": 3, "near": 4}
const _SPECIALS_ERA1 := ["bulwark", "titan_mk2", "storm_rider", "heavy_carrier", "regen_frame", "abrams_mk2"]

func _card(id: String) -> CardResource:
	var c: CardResource = EnemyBlueprints.get_card_by_id(id)
	return c

func test_generated_blueprint_era_matches_id_prefix() -> void:
	var checked := 0
	for id in EnemyBlueprints.get_all_enemy_blueprint_ids():
		var cid := String(id)
		if not cid.begins_with("bp_"):
			continue
		var parts := cid.split("_")
		if parts.size() < 2:
			continue
		var prefix := String(parts[1])
		if not _PREFIX_TO_ERA.has(prefix):
			continue
		var c := _card(cid)
		assert_object(c).is_not_null()
		assert_int(c.era).is_equal(int(_PREFIX_TO_ERA[prefix]))
		checked += 1
	assert_int(checked).is_equal(48)  # GENERATED_PLATFORM_COUNTS = 10+10+9+9+10

func test_special_handwritten_cards_keep_era1() -> void:
	for sid in _SPECIALS_ERA1:
		var c := _card(String(sid))
		assert_object(c).is_not_null()
		assert_int(c.era).is_equal(1)

func test_era_kind_fallback_bucket_no_longer_collapses() -> void:
	# 二战行四桶（1_0/1_1/1_2/1_3）此前各被 ≥18 张卡共用；修复后 bp_ 卡分散，
	# 仍落在二战行的只能是本时代真卡/设计内映射，不允许再出现蓝图大军。
	const UiAssetLoader := preload("res://scripts/ui_asset_loader.gd")
	var ww2_row := 0
	for id in EnemyBlueprints.get_all_enemy_blueprint_ids():
		var c := _card(String(id))
		if c != null and c.card_id.begins_with("bp_") and c.era == 1:
			ww2_row += 1
	assert_int(ww2_row).is_equal(10)  # 只有 bp_ww2_* 的 10 张
