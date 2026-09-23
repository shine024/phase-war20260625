extends Node2D
## v28 T3 战场地面 dressing：弹坑/碎石堆/履带印/枯草丛撒点（纯视觉，零玩法）。
## 由 battlefield._apply_background_texture 尾部调 setup()：贴片撒在车道地板带内，
## 避开两侧驱动器平台区（x<240 / x>1040）；同级同布局可复现（level 做种子）；
## modulate 对齐背景的 时代 tint × BG_DIM。黑门裂隙地板不撒枯草（石面语义不符）。
## 总开关 GameConfig.ground_dressing_enabled（false=清空不撒，回退 v27 前行为）。

const _TEX_CRATER := preload("res://assets/battle/decals/ground_decal_crater.png")
const _TEX_RUBBLE := preload("res://assets/battle/decals/ground_decal_rubble.png")
const _TEX_TRACKS := preload("res://assets/battle/decals/ground_decal_tracks.png")
const _TEX_GRASS := preload("res://assets/battle/decals/ground_decal_grass.png")

const GameConfigScript = preload("res://resources/game_config.gd")

## 撒点带横向安全区：避开左右驱动器平台（含 aura 圈/核心血条视觉区）
const _SAFE_X_MIN := 250.0
const _SAFE_X_MAX := 1030.0
const _COUNT := 12
const _MIN_DIST := 140.0

var _setup_key := ""


## era: 时代索引（仅作 tint 由调用方灌入 modulate，这里不重复算）
## level: 关卡号（撒点种子）；lane_top/bottom_y: 车道地板带（战场行带）世界坐标
func setup(level: int, lane_top_y: float, lane_bottom_y: float, is_endless: bool) -> void:
	var key := "%d|%s" % [level, is_endless]
	if key == _setup_key:
		return
	_setup_key = key
	for c in get_children():
		c.queue_free()
	if not bool(GameConfigScript.get_default().ground_dressing_enabled):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ground_dressing_%d" % level)
	var pts: Array[Vector2] = []
	var placed := 0
	var attempts := 0
	var y_lo := lane_top_y - 12.0
	var y_hi := minf(lane_bottom_y + 95.0, 712.0)
	while placed < _COUNT and attempts < 80:
		attempts += 1
		var p := Vector2(rng.randf_range(_SAFE_X_MIN, _SAFE_X_MAX), rng.randf_range(y_lo, y_hi))
		var ok := true
		for q in pts:
			if p.distance_to(q) < _MIN_DIST:
				ok = false
				break
		if not ok:
			continue
		pts.append(p)
		placed += 1
		# 类型权重：弹坑 0.28 / 碎石 0.25 / 履带印 0.22 / 枯草 0.25（无尽无草）
		# 尺寸标定（v28 验收：L20 沙漠亮底首版 370px 巨坑压过步兵，整体缩 ~45%）
		var roll := rng.randf()
		var tex: Texture2D
		var base_scale := 0.24
		var alpha := 0.40
		if is_endless:
			roll *= 0.75  # 无草池重归一
		if roll < 0.28:
			tex = _TEX_CRATER
			base_scale = 0.28
			alpha = 0.36
		elif roll < 0.53:
			tex = _TEX_RUBBLE
			base_scale = 0.20
			alpha = 0.44
		elif roll < 0.75:
			tex = _TEX_TRACKS
			base_scale = 0.26
			alpha = 0.30
		else:
			tex = _TEX_GRASS
			base_scale = 0.17
			alpha = 0.52
		# 纵深：越靠下（越近镜头）越大
		var t := clampf((p.y - lane_top_y) / maxf(1.0, lane_bottom_y - lane_top_y), 0.0, 1.6)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = p
		spr.flip_h = rng.randf() < 0.5
		spr.scale = Vector2.ONE * (base_scale * lerpf(0.75, 1.30, clampf(t, 0.0, 1.0)) * rng.randf_range(0.9, 1.12))
		spr.modulate = Color(1, 1, 1, alpha)
		spr.rotation = rng.randf_range(-0.06, 0.06)
		add_child(spr)
