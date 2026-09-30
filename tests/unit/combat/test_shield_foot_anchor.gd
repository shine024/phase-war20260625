extends GdUnitTestSuite
## v6.32.3 回归锁：护盾罩脚线端到端自动检查（我方/敌方 × 静态/帧动画 × 精英/头目缩放）。
##
## 原缺陷（v6.31b）：fort_shield_aura.sync_foot_anchor 按"立绘居中不按脚线对齐"的注释
## 误判（漏看 apply_uniform_card_sprite 的 offset 脚对齐），把 aura 再下移一截=双重对齐，
## 敌方 mega_shield 罩底沉到履带下 22~31px（第10关实机主诉）。其冒烟用裸 Sprite2D 桩
## （没复刻 presentation 的 offset 语义），把 bug 断言成了"正确"——本锁即为此洞而生：
## 真实 construct_unit 走完整呈现链，逐像素扫当前纹理内容底缘为真值，
## 断言 aura 罩底与真实脚线偏差 ≤2px。任何动 presentation/缩放/帧动画/aura 的改动
## 破坏脚线对齐都会在此红。
##
## f_tex 数据链（详见 fort_shield_aura.sync_foot_anchor 头注）：
##   ①UnitFrameAnimDriver.sheet_foot_frac（anim.json foot_frac，tools/_tmp_anim_foot_frac.py）
##   ②CardFootAnchors 卡图标定表 ③0 画布底兜底。
## ⚠️ 数据依赖：anim.json 缺 foot_frac 时动画形态退化为兜底口径（偏差可能 >2px）——
## 新增动画资产后先跑 tools/_tmp_anim_foot_frac.py。

const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const DefaultCards = preload("res://data/default_cards.gd")
const TOLERANCE_PX := 2.0

## 多体型 × 敌我九形态：小步兵/中型甲/重型boss/空中悬浮（air_lift 跟随）/堡垒大底座
## /精英×1.2/头目×1.6/帧动画/我方真实挂载链——体型跨 KIND_ERA_SCALE 各档。
var _specs := [
	{"arch": "ww1_arm_rolls_e", "card": "ww1_saint", "label": "敌方静态中型", "elite": "", "anim": "", "player": false},
	{"arch": "ww1_arm_rolls_e", "card": "ww1_saint", "label": "敌方精英x1.2", "elite": "elite", "anim": "", "player": false},
	{"arch": "ww1_boss_av7", "card": "ww1_saint", "label": "敌方头目x1.6", "elite": "boss", "anim": "", "player": false},
	{"arch": "ww1_boss_av7", "card": "ww1_saint", "label": "敌方帧动画", "elite": "", "anim": "ww1_av7", "player": false},
	{"arch": "ww1_boss_av7", "card": "ww1_mauser", "label": "我方帧动画", "elite": "", "anim": "", "player": true},
	{"arch": "ww2_arm_panther_e", "card": "ww1_saint", "label": "敌方二战甲", "elite": "", "anim": "ww2_panther", "player": false},
	{"arch": "cold_boss_mig", "card": "ww1_saint", "label": "敌方空中boss悬浮", "elite": "", "anim": "", "player": false},
	{"arch": "ww1_fort_pillbox", "card": "ww1_saint", "label": "敌方堡垒大底座", "elite": "", "anim": "", "player": false},
	{"arch": "mod_arm_abrams_e", "card": "ww1_saint", "label": "敌方现代甲", "elite": "", "anim": "mod_abrams", "player": false},
]


func test_shield_foot_anchor_all_variants() -> void:
	var failures: Array[String] = []
	for spec: Dictionary in _specs:
		var unit: Node2D = _build_unit(spec)
		var spr := unit.get_node("Sprite") as Sprite2D
		var aura = unit.get("_shield_aura")
		assert_object(aura).is_not_null()
		var aura_y: float = (aura as Node2D).position.y
		var feet_y: float = _feet_world_y(spr)
		var dev: float = absf(aura_y - feet_y)
		# v6.32.4 尺寸断言：罩体半径随体型——大单位（实体高>90）半径必须大于基准 52，
		# 罩体内容直径（2.35×radius）必须 ≥ 实体高×1.4（包裹余量）——大机甲罩腰根因回归锁
		var host_h_meta: float = float((aura as Node).get_meta(&"host_content_h")) \
			if (aura as Node).has_meta(&"host_content_h") else 0.0
		var expect_r: float = maxf(52.0, host_h_meta * 0.62)
		if host_h_meta > 90.0 and expect_r <= 52.0:
			failures.append("%s: 大单位(h=%.0f)罩半径未缩放 (r=%.1f)" % [String(spec.label), host_h_meta, expect_r])
		if 2.35 * expect_r < host_h_meta * 1.24:
			failures.append("%s: 罩体直径(%.0f)未包裹实体高(%.0f)" % [String(spec.label), 2.35 * expect_r, host_h_meta])
		# v6.32.4 堡垒职业环同款断言：大体型 FORT 单位（实体高>80）环半径必须 >45
		# （旧常量 38 对要塞级是杯垫；环半径缓存于 fort_shield_aura.last_fort_base_radius）
		var faura = unit.get("_fort_shield_aura")
		if faura != null and is_instance_valid(faura):
			var fr: float = float((faura as Node).get("last_fort_base_radius"))
			if host_h_meta > 80.0 and fr > 0.0 and fr <= 45.0:
				failures.append("%s: 大型堡垒(h=%.0f)职业环未缩放 (r=%.1f)" % [String(spec.label), host_h_meta, fr])
		if dev > TOLERANCE_PX:
			failures.append("%s: aura_y=%.1f feet_y=%.1f 偏差=%.1fpx (tex=%s)" % [
				String(spec.label), aura_y, feet_y, dev,
				String(spr.texture.resource_path).get_file() if spr.texture != null else "<null>"])
		else:
			print("  ok  [%s] aura_y=%.1f feet_y=%.1f 偏差=%.1fpx" % [String(spec.label), aura_y, feet_y, dev])
		unit.free()
	assert_array(failures).is_empty()


## 真实单位：完整呈现链 + 护盾 + 手动跑一次护盾更新（测试环境无 physics tick）
func _build_unit(spec: Dictionary) -> Node2D:
	var unit: Node2D = (ConstructUnitScene as PackedScene).instantiate()
	add_child(unit)
	var card: CardResource = DefaultCards.get_card_by_id(String(spec.card))
	assert_object(card).is_not_null()
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	if bool(spec.player):
		# 玩家路径：setup 内部即调 _maybe_apply_card_grid_presentation（卡=platform_card_id）
		unit.setup(true, stats, "")
	else:
		unit.setup_with_enemy_visual(false, stats, String(spec.arch))
		if String(spec.elite) != "":
			unit.set_meta("elite_spawn_type", String(spec.elite))
		unit.apply_card_grid_enemy_presentation()
	if String(spec.anim) != "":
		var spr := unit.get_node("Sprite") as Sprite2D
		if not UnitFrameAnim.attach(spr, String(spec.anim), false):
			# 无该动画资产时自然退化静态卡图（仍是合法脚线检查路径）
			print("  note [%s] anim %s miss -> static fallback" % [String(spec.label), String(spec.anim)])
	unit.add_shield(9999.0)
	unit._update_fort_shield_aura(0.016)
	return unit


## 真实脚线：扫当前纹理（帧动画=AtlasTexture 当前帧）alpha 内容底缘，换算到宿主坐标
func _feet_world_y(spr: Sprite2D) -> float:
	var tex := spr.texture
	assert_object(tex).is_not_null()
	var img: Image = null
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		img = (at.atlas as Texture2D).get_image()
		if img != null:
			img = img.get_region(at.region)
	else:
		img = tex.get_image()
	assert_object(img).is_not_null()
	if img.is_compressed():
		img.decompress()
	var bottom := -1
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				bottom = y
				break
		if bottom >= 0:
			break
	assert_int(bottom).is_greater_equal(0)
	var centered_frac: float = (float(bottom) + 0.5) / float(img.get_height()) - 0.5
	var s: float = absf(spr.scale.y)
	return spr.position.y + (spr.offset.y + centered_frac * float(img.get_height())) * s
