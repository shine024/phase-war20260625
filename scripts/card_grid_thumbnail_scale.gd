extends RefCounted
class_name CardGridThumbnailScale
## 卡牌格子战术：缩略图缩放（军衔档位 + 档内战力插值 + 相对「列兵」封顶 2 倍）

const RankRules = preload("res://data/rank_rules.gd")
const _GameConstants = preload("res://resources/game_constants.gd")
const _CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")

## 各军衔相对「尉档基准」的倍数（士/尉/校各一档基准；将档单独拉高）
const _TIER_MUL: Dictionary = {
	"private": 0.58,
	"corporal": 0.72,
	"sergeant": 1.0,
	"lieutenant": 1.0,
	"captain": 1.05,
	"major": 1.08,
	"colonel": 1.12,
}

const POWER_THRESH_GENERAL := 920.0

## 与 BlueprintManager 战力同量级（无 autoload 依赖）
static func estimate_power_from_unit_stats(stats: UnitStats) -> float:
	if stats == null:
		return 0.0
	var interval: float = maxf(float(stats.attack_interval), 0.05)
	var dps: float = float(stats.attack_damage) / interval
	var hp: float = maxf(float(stats.max_hp), 0.0)
	var range_f: float = maxf(float(stats.attack_range), 0.0)
	var spd: float = maxf(float(stats.move_speed), 0.0)
	return maxf(
		hp * 0.28 + dps * 2.2 + range_f * 0.22 + spd * 0.08
		+ float(stats.damage_reduction) * 80.0
		+ float(stats.crit_chance) * 120.0
		+ float(stats.armor_penetration) * 60.0,
		1.0
	)

static func compute_visual_scale(rank_id: String, power_score: float) -> float:
	var rid := rank_id if rank_id in RankRules.RANK_ORDER else "corporal"
	var mul: float = float(_TIER_MUL.get(rid, 1.0))
	if rid == "colonel" and power_score >= POWER_THRESH_GENERAL:
		mul = 3.0
	var band_low := 0.85
	var band_high := 1.08
	var t := inverse_lerp(band_low, band_high, clampf((power_score / 500.0), 0.0, 2.0))
	t = clampf(t, 0.0, 1.0)
	var fine := lerpf(0.92, 1.08, t)
	var raw := mul * fine
	var cap_private := float(_TIER_MUL.get("private", 0.58))
	raw = minf(raw, cap_private * 2.0)
	return clampf(raw * 0.14, 0.06, 0.28)


## 战场立绘：在军衔/战力缩放基础上按贴图最大边归一；士级（中士档 @ 代表性战力）对齐「1280×720 设计屏竖向 18cm → 单位高 1.5cm」
const _BASELINE_ENLISTED_RANK_ID: String = "sergeant"
const _BASELINE_ENLISTED_POWER: float = 500.0


static func _reference_screen_height_px_for_cm_scale() -> float:
	## 按固定设计分辨率换算立绘像素高（与 `GameConstants.CARD_GRID_REFERENCE_SCREEN_*` 一致）
	return float(_GameConstants.CARD_GRID_REFERENCE_SCREEN_HEIGHT_PX)


static func _battlefield_art_ref_px(screen_height_px: float = -1.0) -> float:
	var vh: float = screen_height_px if screen_height_px > 1.0 else _reference_screen_height_px_for_cm_scale()
	var target_px: float = vh * (
		float(_GameConstants.CARD_GRID_ENLISTED_BASE_HEIGHT_CM)
		/ maxf(float(_GameConstants.CARD_GRID_SCREEN_REF_HEIGHT_CM), 0.001)
	)
	target_px *= float(_GameConstants.CARD_GRID_BATTLEFIELD_DRAW_SCALE_MULTIPLIER)
	var b0: float = compute_visual_scale(_BASELINE_ENLISTED_RANK_ID, _BASELINE_ENLISTED_POWER)
	return target_px / maxf(b0, 0.0001)


static func _texture_max_side_px(tex: Texture2D) -> float:
	if tex == null:
		return 256.0
	var sz: Vector2i = tex.get_size()
	var m_raw: float = maxf(float(sz.x), float(sz.y))
	if m_raw <= 1.0:
		m_raw = maxf(float(tex.get_width()), float(tex.get_height()))
	return maxf(m_raw, 1.0)


static func compute_battlefield_art_scale(rank_id: String, power_score: float, tex: Texture2D, screen_height_px: float = -1.0) -> float:
	var base: float = compute_visual_scale(rank_id, power_score)
	if tex == null:
		return base
	var m: float = _texture_max_side_px(tex)
	return base * (_battlefield_art_ref_px(screen_height_px) / m)


## 格子战立绘：固定卡宽，不随军衔/战力变化（敌我同规则）
static func compute_battlefield_uniform_width_scale(tex: Texture2D) -> float:
	if tex == null:
		return 0.1
	var tw: float = maxf(float(tex.get_width()), 1.0)
	return _CardGridBattleLayout.battle_card_width_px() / tw
