extends GdUnitTestSuite
## v6.55 回归锁：战斗界面动画/立绘尺寸链「身高锚定」端到端检查。
##
## 原缺陷（量测实证 2026-10-10）：旧链只做「帧画布 256 ↔ 卡图画布 512」的画布 ×2 补偿，
## 主体在画布里的占比从未进公式——步兵 sheet 主体占画布高 ~0.93、坦克只有 0.25~0.42，
## ×2 直接上屏 = 步兵比坦克高大（xeno_mimic 168px vs mod_t90 24.7px，6.8 倍倒挂）；
## 挂动画瞬间最大跳变 3.07 倍（platform_future_heavy）。
##
## 修复结构（本锁四层，动任何一层都会红）：
##   ① 语义表 CardFootAnchors.TARGET_CONTENT_H / MAX_CONTENT_W（身高锚定档位）
##   ② 适配函数 scale_for_content_rect（min(宽适配,高适配) + MIN_CONTENT_W 托底）
##   ③ 真实呈现链端到端（静态卡图 + 帧动画 attach，断言屏上主体落在目标矩形内，
##      且装甲屏高 > 步兵屏高——视觉预期主不变量）
##   ④ subject 部署门（271 目录全量：无 subject 块 = 资产过期）+ entity_top / 脚线契约
##
## ⚠️ 资产纪律：再生成 sheet 后必须重跑 tools/anim_subject_normalize.py
##（备份先例 D:/godotplay/_art_backup/unit_anims_pre_subject_20261010/）。

const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const UnitFrameAnim = preload("res://scripts/battle/unit_frame_anim.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ANIM_ROOT := "res://assets/effects/unit_anims/"


# ─────────────────────────────────────────────────────────────
#  ① 语义表数据锁：档位次序 = 视觉预期（步兵最矮 < 支援/空中 < 装甲 < 堡垒）
# ─────────────────────────────────────────────────────────────
func test_target_height_table_ordering_matches_visual_expectation() -> void:
	for era in range(5):
		var inf: float = _target_h(0, era)
		var arm: float = _target_h(1, era)
		var sup: float = _target_h(2, era)
		var air: float = _target_h(3, era)
		var fort: float = _target_h(4, era)
		# 主不变量：装甲必须显著高于步兵（1.15×+），堡垒为全场最大
		assert_float(arm).is_greater_equal(inf * 1.15)
		assert_float(fort).is_greater(arm)
		assert_float(sup).is_greater(inf)
		assert_float(air).is_greater_equal(inf - 2.0)
	# 跨时代单调不降（同兵种越时代越大/不变）
	for kind in range(5):
		for era in range(4):
			assert_float(_target_h(kind, era + 1)).is_greater_equal(_target_h(kind, era))
	# 宽度封顶在列宽内（171px）
	for kind in range(5):
		assert_float(CardFootAnchors.MAX_CONTENT_W.get(kind, 999.0) as float).is_less(171.0)


func _target_h(kind: int, era: int) -> float:
	var row: Dictionary = CardFootAnchors.TARGET_CONTENT_H.get(kind) as Dictionary
	return float(row.get(era, 0.0))


# ─────────────────────────────────────────────────────────────
#  ② 适配函数锁：min(宽,高) 绑定 + 窄主体托底 + 零内容守卫
# ─────────────────────────────────────────────────────────────
func test_scale_for_content_rect_binds_min_side() -> void:
	var rect := Vector2(132, 54)
	# 宽扁主体（坦克 3:1）：宽绑定 → 屏宽=rect.x，屏高 < rect.y
	var s: float = CardFootAnchors.scale_for_content_rect(300.0, 100.0, rect)
	assert_float(300.0 * s).is_equal_approx(rect.x, 0.5)
	assert_float(100.0 * s).is_less(rect.y)
	# 竖高主体（步兵 1:1.25）：高绑定 → 屏高=rect.y，且宽度不触发托底
	var s2: float = CardFootAnchors.scale_for_content_rect(80.0, 100.0, rect)
	assert_float(100.0 * s2).is_equal_approx(rect.y, 0.5)
	# 细长主体触发 MIN_CONTENT_W 托底（宽 10px 源按高绑定仅 5.4px → 托到 34px，高越过 rect.y 属预期）
	var s3: float = CardFootAnchors.scale_for_content_rect(10.0, 200.0, rect)
	assert_float(10.0 * s3).is_greater_equal(CardFootAnchors.MIN_CONTENT_W - 0.01)
	# 零内容守卫
	assert_float(CardFootAnchors.scale_for_content_rect(0.0, 0.0, rect)).is_equal_approx(0.1, 0.001)


# ─────────────────────────────────────────────────────────────
#  ③ 真实呈现链端到端：真实卡图 + 真实 sheet，屏上主体必须落进目标矩形
# ─────────────────────────────────────────────────────────────
const _SPEC := [
	{"card": "ww1_enfield", "label": "步兵(动画)"},
	{"card": "ww1_a7v", "label": "装甲A7V(动画)"},
]

func test_presentation_chain_subject_fits_target_rect() -> void:
	var screen_h: Dictionary = {}
	for spec: Dictionary in _SPEC:
		var card: CardResource = DefaultCards.get_card_by_id(String(spec.card))
		assert_object(card).is_not_null()
		var host := Node2D.new()
		var spr := Sprite2D.new()
		host.add_child(spr)
		add_child(host)
		var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card, card.card_id, {}, true)
		assert_object(tex).is_not_null()
		var ok: bool = CardGridUnitVisuals.apply_battle_unit_presentation(host, spr, card, tex, true, 1, null)
		assert_bool(ok).is_true()
		await get_tree().process_frame
		# 帧动画单位：驱动器已按 _visual_rect 适配；当前纹理=idle f0 AtlasTexture
		var driver: Node = spr.get_node_or_null(UnitFrameAnim.DRIVER_NAME)
		assert_object(driver).is_not_null()
		var m: Dictionary = UnitFrameAnim._idle_content_frac(
				UnitFrameAnim._resolve_key(card.card_id), int(driver.idle_frames[0].get_width()))
		assert_dict(m).is_not_empty()
		var rect: Vector2 = spr.get_meta("_visual_rect")
		var disp_w: float = float(m.w) * float(driver.idle_frames[0].get_width()) * absf(spr.scale.x)
		var disp_h: float = float(m.h) * float(driver.idle_frames[0].get_height()) * absf(spr.scale.y)
		# 主体必须装进目标矩形（±2px），且至少一边贴到绑定值
		assert_float(disp_w).is_less_equal(rect.x + 2.0)
		assert_float(disp_h).is_less_equal(rect.y + 2.0)
		var binds: bool = absf(disp_w - rect.x) <= 2.0 or absf(disp_h - rect.y) <= 2.0
		assert_bool(binds).is_true()
		# 窄主体托底下限
		assert_float(disp_w).is_greater_equal(CardFootAnchors.MIN_CONTENT_W - 2.0)
		screen_h[String(spec.card)] = disp_h
		host.queue_free()
	# 主不变量：装甲屏高 > 步兵屏高（旧链倒挂的根；同为 era0 档位差 54 vs 42）
	assert_float(screen_h["ww1_a7v"]).is_greater(screen_h["ww1_enfield"] + 5.0)


# ─────────────────────────────────────────────────────────────
#  ④ subject 部署门 + entity_top / 脚线契约
# ─────────────────────────────────────────────────────────────
func test_subject_block_deployment_gate() -> void:
	var missing: Array[String] = []
	var dir := DirAccess.open(ANIM_ROOT)
	assert_object(dir).is_not_null()
	for d in dir.get_directories():
		if not ResourceLoader.exists(ANIM_ROOT + d + "/sheet_idle.png"):
			continue
		var txt := FileAccess.get_file_as_string(ANIM_ROOT + d + "/anim.json")
		var parsed = JSON.parse_string(txt)
		var subject: Variant = (parsed as Dictionary).get("subject", {}) if parsed is Dictionary else {}
		if not (subject is Dictionary) or float((subject as Dictionary).get("idle_h", 0.0)) <= 0.0:
			missing.append(d)
	assert_array(missing).is_empty()


func test_entity_top_and_foot_contract_after_attach() -> void:
	var card: CardResource = DefaultCards.get_card_by_id("ww1_enfield")
	assert_object(card).is_not_null()
	var host := Node2D.new()
	var spr := Sprite2D.new()
	host.add_child(spr)
	add_child(host)
	var tex: Texture2D = CardGridUnitVisuals.resolve_battle_icon_texture(card, card.card_id, {}, true)
	CardGridUnitVisuals.apply_battle_unit_presentation(host, spr, card, tex, true, 1, null)
	await get_tree().process_frame
	var driver: Node = spr.get_node_or_null(UnitFrameAnim.DRIVER_NAME)
	var fs: float = float(driver.idle_frames[0].get_width())
	var foot: float = float(driver.sheet_foot_frac)
	var content_h: float = float(driver.idle_content.y)
	# 脚线契约：内容底缘（含描边）显示位置必须落在节点原点（±2px）
	var bottom_display: float = (0.5 - foot) * fs * absf(spr.scale.y) + spr.offset.y * absf(spr.scale.y)
	assert_float(bottom_display).is_equal_approx(0.0, 2.0)
	# entity_top 契约：实体顶 = -(foot + 主体高) × fs × scale
	var expected_top: float = -(foot + content_h) * fs * absf(spr.scale.y)
	assert_float(CardFootAnchors.entity_top_y_for_sprite(spr)).is_equal_approx(expected_top, 2.0)
	host.queue_free()
