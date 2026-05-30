class_name BattleAudioSystem
extends RefCounted
## 战斗音效系统（从 battle_effects_system.gd 拆分）
## 负责：攻击音效、死亡音效、音效配置

## 宿主引用（由 battle_effects_system 在 _ready 设置）
var _host: Node = null  # BattleEffectsSystem

func setup(host: Node) -> void:
	_host = host

## 获取音效集成开关（从宿主 effect_config 读取）
func _sound_enabled() -> bool:
	if _host and "effect_config" in _host:
		return bool(_host.effect_config.get("sound_integration", true))
	return true

## 播放攻击音效
func play_attack_sound(attack_type: String) -> void:
	if not _sound_enabled():
		return
	if AudioManager and AudioManager.has_method("play_sfx"):
		match attack_type:
			"melee":
				AudioManager.play_sfx("sword_hit")
			"ranged":
				AudioManager.play_sfx("arrow_hit")
			"magic":
				AudioManager.play_sfx("magic_cast")

## 播放死亡音效
func play_death_sound() -> void:
	if not _sound_enabled():
		return
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("unit_death")
