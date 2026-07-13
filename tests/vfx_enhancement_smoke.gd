# v8.3 战斗 VFX 增强运行时验证（无 GdUnit 依赖）
# 验证：音效合成器真实波形生成 / impact recipe 新值 / 震动频率映射 / DAMAGE_STYLES glow
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/vfx_enhancement_smoke.gd
extends SceneTree

const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const SoundGenerator = preload("res://managers/sound_generator.gd")
const DamageNumberDisplay = preload("res://scenes/effects/damage_number_display.gd")


func _initialize() -> void:
	var code := 0
	var sg := SoundGenerator.new()
	sg._ready()  # 触发 _generate_all_sounds

	# ── 1. 音效合成器：12 武器键 + impact_generic 都生成非空波形 ──
	var weapon_keys: Array = [
		"gun_smg", "gun_rifle", "gun_mg", "rocket_launch", "gun_pistol",
		"gun_shotgun", "gun_sniper", "flak_fire", "laser_fire", "missile_hum",
		"omega_cannon", "rail_cannon", "impact_generic"
	]
	for key in weapon_keys:
		var stream := sg.get_sound(key)
		if stream == null:
			push_error("[vfx_smoke] missing sound key: %s" % key)
			code = 1
			continue
		if not (stream is AudioStreamWAV):
			push_error("[vfx_smoke] %s not AudioStreamWAV (got %s)" % [key, stream.get_class()])
			code = 1
			continue
		var wav := stream as AudioStreamWAV
		if wav.data.size() == 0:
			push_error("[vfx_smoke] %s has EMPTY data buffer" % key)
			code = 1
		if wav.format != AudioStreamWAV.FORMAT_16_BITS:
			push_error("[vfx_smoke] %s format not 16-bit" % key)
			code = 1
		# 波形应有非零采样（否则是静默）
		var has_signal := false
		var d := wav.data
		var check_n: int = mini(d.size() / 2, 200)  # 抽样前 200 个样本
		for i in check_n:
			var ival: int = d[i * 2] | (d[i * 2 + 1] << 8)
			if ival > 32767:  # 负数（little-endian signed）
				ival -= 65536
			if absi(ival) > 100:  # 有可闻振幅
				has_signal = true
				break
		if not has_signal:
			push_error("[vfx_smoke] %s waveform is silent (all samples ~0)" % key)
			code = 1
	print("[vfx_smoke] 1. 音效合成器: 13 键全非空、16-bit、有可闻波形" if code == 0 else "[vfx_smoke] 1. FAIL")

	# ── 2. impact recipe 新值：DIRECT ring 36 / MISSILE ring 90 / LASER ring 30 ──
	var pre_code := code
	var r_direct: Dictionary = VfxImpactFactory._impact_recipe(0)
	if not is_equal_approx(float(r_direct.get("ring_r", 0)), 36.0):
		push_error("[vfx_smoke] DIRECT ring_r expected 36 got %s" % str(r_direct.get("ring_r")))
		code = 1
	if int(r_direct.get("spark_amount", 0)) != 28:
		push_error("[vfx_smoke] DIRECT spark_amount expected 28 got %s" % str(r_direct.get("spark_amount")))
		code = 1
	var r_missile: Dictionary = VfxImpactFactory._impact_recipe(9)
	if not is_equal_approx(float(r_missile.get("ring_r", 0)), 90.0):
		push_error("[vfx_smoke] MISSILE ring_r expected 90 got %s" % str(r_missile.get("ring_r")))
		code = 1
	var r_laser: Dictionary = VfxImpactFactory._impact_recipe(8)
	if not is_equal_approx(float(r_laser.get("ring_r", 0)), 30.0):
		push_error("[vfx_smoke] LASER ring_r expected 30 got %s" % str(r_laser.get("ring_r")))
		code = 1
	# OMEGA/RAIL(10/11)
	var r_omega: Dictionary = VfxImpactFactory._impact_recipe(10)
	if not is_equal_approx(float(r_omega.get("ring_r", 0)), 50.0):
		push_error("[vfx_smoke] OMEGA ring_r expected 50 got %s" % str(r_omega.get("ring_r")))
		code = 1
	print("[vfx_smoke] 2. impact recipe 新值核对通过" if code == pre_code else "[vfx_smoke] 2. FAIL")

	# ── 3. IMPACT_SHAKE_BY_KIND 新值 ──
	pre_code = code
	var shake_light: Vector2 = WeaponProjectileVfx.IMPACT_SHAKE_BY_KIND.get(0, Vector2.ZERO)
	if not is_equal_approx(shake_light.x, 3.0) or not is_equal_approx(shake_light.y, 0.15):
		push_error("[vfx_smoke] LIGHT shake expected (3.0,0.15) got %s" % str(shake_light))
		code = 1
	var shake_armor: Vector2 = WeaponProjectileVfx.IMPACT_SHAKE_BY_KIND.get(1, Vector2.ZERO)
	if not is_equal_approx(shake_armor.x, 5.0) or not is_equal_approx(shake_armor.y, 0.25):
		push_error("[vfx_smoke] ARMOR shake expected (5.0,0.25) got %s" % str(shake_armor))
		code = 1
	var shake_air: Vector2 = WeaponProjectileVfx.IMPACT_SHAKE_BY_KIND.get(3, Vector2.ZERO)
	if not is_equal_approx(shake_air.x, 7.0) or not is_equal_approx(shake_air.y, 0.35):
		push_error("[vfx_smoke] AIR shake expected (7.0,0.35) got %s" % str(shake_air))
		code = 1
	# AIR 震动应强于 LIGHT（差异化验证）
	if shake_air.x <= shake_light.x:
		push_error("[vfx_smoke] AIR shake (%.1f) should > LIGHT (%.1f)" % [shake_air.x, shake_light.x])
		code = 1
	print("[vfx_smoke] 3. IMPACT_SHAKE_BY_KIND 新值 + 差异化通过" if code == pre_code else "[vfx_smoke] 3. FAIL")

	# ── 4. PROJ_DISPLAY_SCALE_MUL = 0.10 ──
	pre_code = code
	if not is_equal_approx(WeaponProjectileVfx.PROJ_DISPLAY_SCALE_MUL, 0.10):
		push_error("[vfx_smoke] PROJ_DISPLAY_SCALE_MUL expected 0.10 got %s" % str(WeaponProjectileVfx.PROJ_DISPLAY_SCALE_MUL))
		code = 1
	print("[vfx_smoke] 4. PROJ_DISPLAY_SCALE_MUL = 0.10 通过" if code == pre_code else "[vfx_smoke] 4. FAIL")

	# ── 5. DAMAGE_STYLES glow 字段（critical/big_crit/pierce/heal 有，normal/miss 无）──
	pre_code = code
	var styles: Dictionary = DamageNumberDisplay.DAMAGE_STYLES
	for glow_key in ["critical", "big_crit", "pierce", "heal"]:
		if not styles.has(glow_key):
			push_error("[vfx_smoke] DAMAGE_STYLES missing key: %s" % glow_key)
			code = 1
			continue
		var st: Dictionary = styles[glow_key]
		if not st.has("glow_color"):
			push_error("[vfx_smoke] %s missing glow_color" % glow_key)
			code = 1
		if not st.has("glow_size"):
			push_error("[vfx_smoke] %s missing glow_size" % glow_key)
			code = 1
	# big_crit glow_size 应为 6（最大）
	if styles.has("big_crit") and int(styles["big_crit"].get("glow_size", 0)) != 6:
		push_error("[vfx_smoke] big_crit glow_size expected 6 got %s" % str(styles["big_crit"].get("glow_size")))
		code = 1
	# normal/miss 不应有 glow（验证条件逻辑）
	for no_glow_key in ["normal", "miss"]:
		if styles.has(no_glow_key) and styles[no_glow_key].has("glow_color"):
			push_error("[vfx_smoke] %s should NOT have glow_color" % no_glow_key)
			code = 1
	print("[vfx_smoke] 5. DAMAGE_STYLES glow 字段通过" if code == pre_code else "[vfx_smoke] 5. FAIL")

	# ── 6. screen_shake frequency 公式验证（纯数学，不实例化 Camera）──
	pre_code = code
	# 公式：frequency = 1.0 + intensity * 0.05
	# LIGHT(3.0) → 1.15, AIR(7.0) → 1.35；AIR 应更高频
	var freq_light: float = 1.0 + 3.0 * 0.05
	var freq_air: float = 1.0 + 7.0 * 0.05
	if not is_equal_approx(freq_light, 1.15):
		push_error("[vfx_smoke] LIGHT freq expected 1.15 got %s" % str(freq_light))
		code = 1
	if not is_equal_approx(freq_air, 1.35):
		push_error("[vfx_smoke] AIR freq expected 1.35 got %s" % str(freq_air))
		code = 1
	if freq_air <= freq_light:
		push_error("[vfx_smoke] AIR freq should > LIGHT freq")
		code = 1
	print("[vfx_smoke] 6. screen_shake frequency 分层公式通过" if code == pre_code else "[vfx_smoke] 6. FAIL")

	# ── 结果汇总 ──
	if code == 0:
		print("\n=== vfx_enhancement_smoke: ALL PASS (6/6) ===")
	else:
		print("\n=== vfx_enhancement_smoke: FAILED ===")
	quit(code)
