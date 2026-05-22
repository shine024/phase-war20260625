extends Node
## 音效生成器 - 使用AudioStreamGenerator生成简单的合成音效
## 在缺少真实音效文件时作为临时解决方案

var _audio_streams: Dictionary = {}

func _ready() -> void:
	# 预生成基本音效
	_generate_all_sounds()

## 生成简单的合成音效
func get_sound(sound_name: String) -> AudioStream:
	if _audio_streams.has(sound_name):
		return _audio_streams[sound_name]
	return null

func _generate_all_sounds() -> void:
	# 按钮点击音效 - 短促的高频音
	_audio_streams["button"] = _generate_beep(800, 0.1)
	_audio_streams["button_hover"] = _generate_beep(600, 0.05)

	# 战斗音效
	_audio_streams["hit"] = _generate_noise(0.15)
	_audio_streams["shoot"] = _generate_shoot()
	_audio_streams["explosion"] = _generate_explosion()
	_audio_streams["cast"] = _generate_cast()
	_audio_streams["hurt"] = _generate_hurt()

	# 结果音效
	_audio_streams["win"] = _generate_win_fanfare()
	_audio_streams["lose"] = _generate_lose_sound()

	# 系统音效
	_audio_streams["blueprint_unlock"] = _generate_unlock()
	_audio_streams["enhance"] = _generate_power_up()
	_audio_streams["achievement"] = _generate_achievement()
	_audio_streams["quest_complete"] = _generate_quest_complete()

	# UI音效
	_audio_streams["panel_open"] = _generate_slide()
	_audio_streams["panel_close"] = _generate_slide_reverse()
	_audio_streams["card_pickup"] = _generate_card_pickup()
	_audio_streams["card_place"] = _generate_card_place()
	_audio_streams["error"] = _generate_error_buzz()

## 生成简单的蜂鸣音
func _generate_beep(frequency: int, duration: float) -> AudioStream:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.buffer_length = duration
	stream.mix_rate = 44100
	player.stream = stream

	# 这是一个简化版本，实际使用中应该用AudioStreamGenerator生成真实波形
	# 这里返回空流作为占位符
	return stream

## 生成噪音音效
func _generate_noise(duration: float) -> AudioStream:
	var stream := AudioStreamGenerator.new()
	stream.buffer_length = duration
	stream.mix_rate = 44100
	return stream

## 生成射击音效
func _generate_shoot() -> AudioStream:
	return _generate_noise(0.1)

## 生成爆炸音效
func _generate_explosion() -> AudioStream:
	return _generate_noise(0.3)

## 生成施法音效
func _generate_cast() -> AudioStream:
	return _generate_beep(1200, 0.2)

## 生成受伤音效
func _generate_hurt() -> AudioStream:
	return _generate_beep(200, 0.15)

## 生成胜利音效
func _generate_win_fanfare() -> AudioStream:
	return _generate_beep(880, 0.5)

## 生成失败音效
func _generate_lose_sound() -> AudioStream:
	return _generate_beep(150, 0.4)

## 生成成功提示音
func _generate_success_chime() -> AudioStream:
	return _generate_beep(1000, 0.2)

## 生成错误提示音
func _generate_error_buzz() -> AudioStream:
	return _generate_beep(150, 0.2)

## 生成解锁音效
func _generate_unlock() -> AudioStream:
	return _generate_beep(1200, 0.3)

## 生成强化音效
func _generate_power_up() -> AudioStream:
	return _generate_beep(600, 0.25)

## 生成成就音效
func _generate_achievement() -> AudioStream:
	return _generate_beep(1500, 0.4)

## 生成任务完成音效
func _generate_quest_complete() -> AudioStream:
	return _generate_success_chime()

## 生成滑动音效
func _generate_slide() -> AudioStream:
	return _generate_beep(400, 0.1)

## 生成反向滑动音效
func _generate_slide_reverse() -> AudioStream:
	return _generate_beep(300, 0.1)

## 生成卡牌拾取音效
func _generate_card_pickup() -> AudioStream:
	return _generate_beep(500, 0.15)

## 生成卡牌放置音效
func _generate_card_place() -> AudioStream:
	return _generate_beep(700, 0.15)
