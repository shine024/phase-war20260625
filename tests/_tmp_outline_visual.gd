extends Node2D
## v26.9 单位描边/贴地投影/背景压暗 视觉验收场景（临时工具，_tmp 前缀）
## 复刻 battlefield 真实着色链：真实关卡背景 × 时代 tint × BG_DIM，
## 单位走完整 apply_battle_unit_presentation（描边 shader + 投影 + 名牌条全真链路）。
## 由 agent_tools run.scene_headless 截图验收。

const Visuals := preload("res://scripts/card_grid_unit_visuals.gd")
const DefaultCards := preload("res://data/default_cards.gd")

## [卡 id, 相对车道中心的 (x, y)]——含用户截图融底同款灰卡（毛瑟班/105榴）+ 空中单位
## ANIM_SHEET_ANY = 依次尝试候选帧动画卡（雪碧图 AtlasTexture 区域裁剪视觉验证）
const CARDS := [
	["ww1_mauser", Vector2(140, -40)],
	["ww1_105mm", Vector2(150, 40)],
	["ANIM_SHEET_ANY", Vector2(320, -42)],
	["fut_arm_hovertank", Vector2(330, 42)],
	["fut_colossus", Vector2(530, 0)],
	["cold_mig21", Vector2(720, -70)],
]

const ANIM_CARD_CANDIDATES := ["cold_t72", "cold_m60", "cold_spetsnaz", "cold_btr", "fut_arm_heavy_mech"]


func _resolve_card(card_id: String) -> CardResource:
	if card_id != "ANIM_SHEET_ANY":
		return DefaultCards.get_card_by_id(card_id)
	for cand in ANIM_CARD_CANDIDATES:
		var c := DefaultCards.get_card_by_id(cand)
		if c != null:
			print("[OutlineVisual] 帧动画卡命中候选: ", cand)
			return c
	return null


func _ready() -> void:
	var bf: Script = load("res://scenes/battlefield/battlefield.gd")
	var cm: Dictionary = bf.get_script_constant_map()
	var bg_dim: Color = cm.get("BG_DIM", Color(0.80, 0.80, 0.87))
	var tex: Texture2D = load("res://assets/backgrounds/bg_level_100.png")
	var battle_bottom: float = 648.0
	var bg := Sprite2D.new()
	bg.texture = tex
	bg.centered = false
	bg.modulate = Color(0.85, 0.95, 1.0) * bg_dim  # era4 时代 tint × BG_DIM（复刻 _apply_background_texture）
	add_child(bg)
	var bg_top: float = battle_bottom - float(tex.get_height())
	var lane_center: float = bg_top + float(tex.get_height()) * float(cm.get("BATTLE_LANE_CENTER_RATIO", 0.80))
	var ok := 0
	for entry: Array in CARDS:
		var card_id: String = String(entry[0])
		var card: CardResource = _resolve_card(card_id)
		if card == null:
			push_error("[OutlineVisual] 找不到卡 " + card_id)
			continue
		var t: Texture2D = Visuals.resolve_battle_icon_texture(card, card_id, {}, true)
		if t == null:
			push_error("[OutlineVisual] 卡图解析失败 " + card_id)
			continue
		var host := Node2D.new()
		host.position = Vector2(float((entry[1] as Vector2).x), lane_center + float((entry[1] as Vector2).y))
		add_child(host)
		var spr := Sprite2D.new()
		host.add_child(spr)
		if Visuals.apply_battle_unit_presentation(host, spr, card, t, true, 5, null):
			ok += 1
	print("[OutlineVisual] 呈现完成 %d/%d, lane_center=%.0f, BG_DIM=%s" % [ok, CARDS.size(), lane_center, str(bg_dim)])
