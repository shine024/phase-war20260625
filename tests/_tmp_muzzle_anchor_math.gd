extends SceneTree
## _tmp 探针：开火点 Y 换算 ff 口径回归（配合 player_muzzle_anchors / muzzle_anchors 修复）
## 契约：get_fire_offset 的 Y 原点是脚线（apply_uniform_card_sprite 的 foot offset 对齐），
## fireY_pct 从纹理顶部量 → px_y = -(1 - ff - fireY_pct/100) × 图高 × scale.y。
## 跑法：godot --headless --rendering-driver opengl3 --script tests/_tmp_muzzle_anchor_math.gd

class StubSprite:
	var texture: Texture2D = null
	var scale: Vector2 = Vector2.ONE

func _init() -> void:
	var PlayerAnchors := load("res://data/player_muzzle_anchors.gd")
	var EnemyAnchors := load("res://data/muzzle_anchors.gd")
	var FootAnchors := load("res://data/card_foot_anchors.gd")
	var Manifest := load("res://data/enemy_unit_manifest.gd")
	var tex := GradientTexture2D.new()
	tex.width = 512
	tex.height = 512
	var spr := StubSprite.new()
	spr.texture = tex
	spr.scale = Vector2(2.0, 2.0)  # 帧动画 ×2 补偿同口径：px 偏移应等比放大
	var fails: int = 0
	# ── 玩家 ww1_105mm：ff=0.3933, fireY_pct=41.33, fireX=0.9156（期望值硬编码）
	var a: Vector2 = PlayerAnchors.get_fire_offset("ww1_105mm", spr)
	var expect_y: float = -(1.0 - 0.3933 - 0.4133) * 512.0 * 2.0
	var expect_x: float = (0.9156 - 0.5) * 512.0 * 2.0
	if not _near(a.y, expect_y):
		fails += 1
		print("FAIL player y: got %.2f expect %.2f" % [a.y, expect_y])
	if not _near(a.x, expect_x):
		fails += 1
		print("FAIL player x: got %.2f expect %.2f" % [a.x, expect_x])
	# ── 敌方同名卡图 ww1_sup_vickers：ff 反查 FOOT_FRAC（同键直查）
	# fireY 从表内锚点现读（核对轮会修正，硬编码会过期）——只验公式。
	var ff_v: float = FootAnchors.get_foot_frac("ww1_sup_vickers")
	var anchor_v: Dictionary = EnemyAnchors.get_anchor("ww1_sup_vickers")
	var fy_v: float = float(anchor_v.get("fireY_pct", 50.0)) / 100.0
	var b: Vector2 = EnemyAnchors.get_fire_offset("ww1_sup_vickers", spr)
	var expect_by: float = -(1.0 - ff_v - fy_v) * 512.0 * 2.0
	if not _near(b.y, expect_by):
		fails += 1
		print("FAIL enemy named y: got %.2f expect %.2f (ff=%.4f)" % [b.y, expect_by, ff_v])
	# ── 敌方 vis 图源 ww1_inf_mp18（icon=vis_enemy_036）：icon 反查链 + foe_ 前缀剥除
	var icon: String = Manifest.visual_id_for_archetype("ww1_inf_mp18")
	var ff_m: float = FootAnchors.get_foot_frac(icon if not icon.is_empty() else "ww1_inf_mp18")
	print("INFO ww1_inf_mp18 icon=%s ff=%.4f (icon 反查%s)" % [icon, ff_m, "生效" if ff_m > 0.0 else "未命中→回退0.0"])
	# 期望值从表内锚点现读（开火核对轮会修正 fireY/fireX，硬编码会过期）——本探针只验公式。
	var anchor_m: Dictionary = EnemyAnchors.get_anchor("ww1_inf_mp18")
	var fx_m: float = float(anchor_m.get("fireX", 0.5))
	var fy_m: float = float(anchor_m.get("fireY_pct", 50.0)) / 100.0
	var c: Vector2 = EnemyAnchors.get_fire_offset("ww1_inf_mp18", spr)
	var expect_cy: float = -(1.0 - ff_m - fy_m) * 512.0 * 2.0
	var expect_cx: float = (fx_m - 0.5) * 512.0 * 2.0
	if not _near(c.y, expect_cy):
		fails += 1
		print("FAIL enemy vis y: got %.2f expect %.2f (icon=%s ff=%.4f fy=%.3f)" % [c.y, expect_cy, icon, ff_m, fy_m])
	if not _near(c.x, expect_cx):
		fails += 1
		print("FAIL enemy vis x: got %.2f expect %.2f (fx=%.3f)" % [c.x, expect_cx, fx_m])
	var d: Vector2 = EnemyAnchors.get_fire_offset("foe_ww1_inf_mp18", spr)
	if d != c:
		fails += 1
		print("FAIL foe_ prefix: got %s expect %s" % [d, c])
	# ── 无标注回退 ZERO（调用方走 entity_top_y*0.5）
	if PlayerAnchors.get_fire_offset("no_such_card_xyz", spr) != Vector2.ZERO:
		fails += 1
		print("FAIL player unknown not ZERO")
	if EnemyAnchors.get_fire_offset("no_such_card_xyz", spr) != Vector2.ZERO:
		fails += 1
		print("FAIL enemy unknown not ZERO")
	# ── 空纹理不崩（兜底 100×100、s=1）
	var bare := StubSprite.new()
	var e: Vector2 = PlayerAnchors.get_fire_offset("ww1_105mm", bare)
	if not _near(e.y, -(1.0 - 0.3933 - 0.4133) * 100.0):
		fails += 1
		print("FAIL bare sprite y: got %.2f" % e.y)
	if fails == 0:
		print("MUZZLE_ANCHOR_MATH_OK")
	else:
		print("MUZZLE_ANCHOR_MATH_FAIL fails=%d" % fails)
	quit(fails)

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.51
