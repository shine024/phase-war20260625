extends Node
## 音效生成器 v8.3 — 真实合成波形
## 在缺少真实音效文件时作为临时解决方案：用采样合成（方波/噪声/正弦扫频）
## 生成 AudioStreamWAV（16-bit PCM），预渲染并缓存，零运行时合成开销。
##
## 合成原语：
##   - 方波 + 噪声混合 → 枪械（_gen_gunfire）
##   - 低频噪声扫降    → 爆炸（_gen_explosion）
##   - 正弦扫频        → 能量武器（_gen_laser）
##   - 短噪声 + 高频   → 命中（_gen_impact）
##   - 短促蜂鸣        → UI/系统（_gen_beep_tone）

const SAMPLE_RATE: int = 44100

var _audio_streams: Dictionary = {}

func _ready() -> void:
	_generate_all_sounds()

## 生成简单的合成音效（按名取，缺失返回 null）
func get_sound(sound_name: String) -> AudioStream:
	if _audio_streams.has(sound_name):
		return _audio_streams[sound_name]
	return null

func _generate_all_sounds() -> void:
	# ── UI / 系统音效（短蜂鸣） ──
	_audio_streams["button"] = _gen_beep_tone(800, 0.08)
	_audio_streams["button_hover"] = _gen_beep_tone(600, 0.05)
	_audio_streams["panel_open"] = _gen_beep_tone(400, 0.10)
	_audio_streams["panel_close"] = _gen_beep_tone(300, 0.10)
	_audio_streams["card_pickup"] = _gen_beep_tone(500, 0.12)
	_audio_streams["card_place"] = _gen_beep_tone(700, 0.12)
	_audio_streams["error"] = _gen_beep_tone(150, 0.18)
	_audio_streams["enhance"] = _gen_sweep(400, 900, 0.25)  # 上升扫频=强化
	_audio_streams["blueprint_unlock"] = _gen_sweep(600, 1200, 0.30)
	_audio_streams["achievement"] = _gen_sweep(800, 1500, 0.40)
	_audio_streams["quest_complete"] = _gen_sweep(700, 1400, 0.35)
	# 战斗结果
	_audio_streams["win"] = _gen_sweep(600, 1000, 0.50)
	_audio_streams["lose"] = _gen_sweep(400, 150, 0.50)
	# ── 通用战斗音效 ──
	_audio_streams["hit"] = _gen_impact(0.12)
	_audio_streams["hurt"] = _gen_beep_tone(200, 0.15)
	_audio_streams["cast"] = _gen_sweep(900, 1300, 0.20)
	_audio_streams["explosion"] = _gen_explosion(0.35)
	_audio_streams["shoot"] = _gen_gunfire(900, 0.10, 0.35)
	_audio_streams["unit_death"] = _gen_explosion(0.25)

	# ── v8.3: 按武器类型（WeaponTypeLegacy）合成攻击音效 ──
	# SMG=0,RIFLE=1,MG=2,ROCKET=3,PISTOL=4,SHOTGUN=5,SNIPER=6,FLAK=7,LASER=8,MISSILE=9,OMEGA=10,RAIL=11
	_audio_streams["gun_smg"]    = _gen_gunfire(1000, 0.08, 0.40)   # 高频连发
	_audio_streams["gun_rifle"]  = _gen_gunfire(850, 0.10, 0.35)    # 中频单发
	_audio_streams["gun_mg"]     = _gen_gunfire(700, 0.12, 0.45)    # 低频连发
	_audio_streams["rocket_launch"] = _gen_explosion(0.40)          # 火箭呼啸+爆
	_audio_streams["gun_pistol"] = _gen_gunfire(1100, 0.06, 0.30)   # 短促高频
	_audio_streams["gun_shotgun"]= _gen_gunfire(280, 0.18, 0.65)    # 低频轰鸣（噪声占比高）
	_audio_streams["gun_sniper"] = _gen_gunfire(1600, 0.14, 0.25)   # 清脆高频
	_audio_streams["flak_fire"]  = _gen_gunfire(320, 0.20, 0.55)    # 中低频空爆
	_audio_streams["laser_fire"] = _gen_laser(3000, 4500, 0.18)     # 高频扫频
	_audio_streams["missile_hum"] = _gen_laser(500, 800, 0.30)      # 中频嗡鸣
	_audio_streams["omega_cannon"] = _gen_laser(180, 120, 0.35)     # 低频脉冲（下降扫频）
	_audio_streams["rail_cannon"] = _gen_laser(2200, 3500, 0.22)    # 高频充能+击穿
	_audio_streams["impact_generic"] = _gen_impact(0.10)


# ============================================================
# 合成原语
# ============================================================

## 蜂鸣音（纯方波/正弦）— UI/系统音
func _gen_beep_tone(freq: float, dur: float) -> AudioStream:
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)  # 16-bit mono
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = _envelope(i, n)  # 快速起音+线性衰减
		# 正弦波，加一点二次谐波让音色不空洞
		var s: float = sin(t * freq * TAU) * 0.7 + sin(t * freq * TAU * 2.0) * 0.2
		s *= env * 0.6
		_store_sample(data, i, s)
	return _build_stream(data)

## 频率扫频（正弦 freq_start→freq_end）— 能量上升/下降、UI 成功音
func _gen_sweep(freq_start: float, freq_end: float, dur: float) -> AudioStream:
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = lerpf(freq_start, freq_end, float(i) / float(n))
		phase += f * TAU / float(SAMPLE_RATE)
		var env: float = _envelope(i, n)
		var s: float = sin(phase) * env * 0.55
		_store_sample(data, i, s)
	return _build_stream(data)

## 枪械音 = 方波（基频）+ 白噪声（noise_mix 比例混合）
func _gen_gunfire(freq: float, dur: float, noise_mix: float) -> AudioStream:
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	var prev_noise: float = 0.0
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		phase += freq * TAU / float(SAMPLE_RATE)
		# 方波（取正弦符号位近似）
		var square: float = 1.0 if sin(phase) >= 0.0 else -1.0
		# 过滤噪声（低通，让噪声更"厚"而非"沙"）
		var raw: float = randf_range(-1.0, 1.0)
		prev_noise = lerpf(prev_noise, raw, 0.5)
		var env: float = _envelope_exp(i, n, 6.0)  # 指数快速衰减，模拟枪声瞬态
		var s: float = (square * (1.0 - noise_mix) + prev_noise * noise_mix) * env * 0.5
		_store_sample(data, i, s)
	return _build_stream(data)

## 爆炸音 = 低频过滤噪声 + 缓慢指数衰减
func _gen_explosion(dur: float) -> AudioStream:
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low: float = 0.0  # 低通滤波状态
	for i in n:
		var raw: float = randf_range(-1.0, 1.0)
		# 强低通（让噪声变成"轰"而非"沙"）
		low = lerpf(low, raw, 0.08)
		var env: float = _envelope_exp(i, n, 3.0)  # 比枪声衰减慢
		var s: float = low * env * 0.7
		_store_sample(data, i, s)
	return _build_stream(data)

## 命中音 = 短噪声 + 轻微高频金属感
func _gen_impact(dur: float) -> AudioStream:
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337  # 固定种子让命中音一致（避免每次不同）
	var phase: float = 0.0
	for i in n:
		var raw: float = rng.randf_range(-1.0, 1.0)
		phase += 1800.0 * TAU / float(SAMPLE_RATE)  # 高频金属成分
		var metallic: float = sin(phase) * 0.15
		var env: float = _envelope_exp(i, n, 8.0)
		var s: float = (raw * 0.6 + metallic) * env * 0.5
		_store_sample(data, i, s)
	return _build_stream(data)

## 激光/能量武器 = 正弦扫频（freq_start→freq_end）+ 轻微噪声
func _gen_laser(freq_start: float, freq_end: float, dur: float) -> AudioStream:
	var n: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in n:
		var f: float = lerpf(freq_start, freq_end, float(i) / float(n))
		phase += f * TAU / float(SAMPLE_RATE)
		var env: float = _envelope(i, n)
		var noise: float = randf_range(-1.0, 1.0) * 0.08  # 微量噪声加质感
		var s: float = (sin(phase) * 0.8 + noise) * env * 0.45
		_store_sample(data, i, s)
	return _build_stream(data)


# ============================================================
# 工具函数
# ============================================================

## 线性包络：前 5% 快速起音，剩余线性衰减
func _envelope(i: int, n: int) -> float:
	var attack: int = max(1, n / 20)
	if i < attack:
		return float(i) / float(attack)
	return 1.0 - float(i - attack) / float(n - attack)

## 指数包络：快速起音 + 指数衰减（decay_rate 越大衰减越快，适合瞬态音）
func _envelope_exp(i: int, n: int, decay_rate: float) -> float:
	var attack: int = max(1, n / 30)
	if i < attack:
		return float(i) / float(attack)
	var t: float = float(i - attack) / float(SAMPLE_RATE)
	return exp(-decay_rate * t)

## 把 float 样本（-1.0~1.0）写入 16-bit PCM byte 数组
func _store_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var clamped: float = clampf(sample, -1.0, 1.0)
	var ival: int = int(clamped * 32767.0)
	# little-endian 16-bit
	data[index * 2] = ival & 0xFF
	data[index * 2 + 1] = (ival >> 8) & 0xFF

## 从 PCM byte 数组构建 AudioStreamWAV（Godot 4.x：AudioStreamSample 已更名为 AudioStreamWAV）
func _build_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
