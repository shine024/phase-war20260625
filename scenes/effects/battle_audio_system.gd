class_name BattleAudioSystem
extends RefCounted
## 战斗音效系统（从 battle_effects_system.gd 拆分）
## 负责：攻击音效、死亡音效、音效配置
## v8.3: 新增按 WeaponTypeLegacy 分流的武器攻击/命中音效（原 play_attack_sound 保留给技能/施法路径）

## 宿主引用（由 battle_effects_system 在 _ready 设置）
var _host: Node = null  # BattleEffectsSystem

func setup(host: Node) -> void:
	_host = host

## 获取音效集成开关（从宿主 effect_config 读取）
func _sound_enabled() -> bool:
	if _host and "effect_config" in _host:
		return bool(_host.effect_config.get("sound_integration", true))
	return true

## 播放攻击音效（旧路径：技能/施法用 melee/ranged/magic 标签）
func play_attack_sound(attack_type: String) -> void:
	if not _sound_enabled():
		return
	if AudioManager and AudioManager.has_method("play_sfx"):
		match attack_type:
			"melee":
				AudioManager.play_sfx("hit")
			"ranged":
				AudioManager.play_sfx("shoot")
			"magic":
				AudioManager.play_sfx("cast")

## v8.3: 按武器类型（WeaponTypeLegacy）播放攻击音效
## SMG=0,RIFLE=1,MG=2,ROCKET=3,PISTOL=4,SHOTGUN=5,SNIPER=6,FLAK=7,LASER=8,MISSILE=9,OMEGA=10,RAIL=11
func play_weapon_sound(weapon_type: int, is_player: bool) -> void:
	if not _sound_enabled():
		return
	if not (AudioManager and AudioManager.has_method("play_sfx")):
		return
	var pitch := randf_range(0.9, 1.1)
	# 敌方音量略低 + 轻微降调，让玩家潜意识区分敌我
	var vol: float = 0.7 if not is_player else 1.0
	if not is_player:
		pitch *= 0.92
	match weapon_type:
		0:       AudioManager.play_sfx("gun_smg", vol * 0.6, pitch)            # SMG
		1:       AudioManager.play_sfx("gun_rifle", vol * 0.6, pitch)          # RIFLE
		2:       AudioManager.play_sfx("gun_mg", vol * 0.7, pitch * 0.9)       # MG
		3:       AudioManager.play_sfx("rocket_launch", vol * 1.0, pitch * 0.8)  # ROCKET
		4:       AudioManager.play_sfx("gun_pistol", vol * 0.5, pitch * 1.1)   # PISTOL
		5:       AudioManager.play_sfx("gun_shotgun", vol * 0.9, pitch)        # SHOTGUN
		6:       AudioManager.play_sfx("gun_sniper", vol * 0.7, pitch * 1.2)   # SNIPER
		7:       AudioManager.play_sfx("flak_fire", vol * 0.9, pitch * 0.9)    # FLAK
		8:       AudioManager.play_sfx("laser_fire", vol * 0.5, pitch * 2.0)   # LASER
		9:       AudioManager.play_sfx("missile_hum", vol * 0.8, pitch)        # MISSILE
		10:      AudioManager.play_sfx("omega_cannon", vol * 0.8, pitch * 0.5) # OMEGA
		11:      AudioManager.play_sfx("rail_cannon", vol * 0.7, pitch * 1.5)  # RAIL
		_:
			push_warning("[BattleAudio] unknown weapon_type %d" % weapon_type)

## v8.3: 按武器类型播放命中音效
func play_impact_sound(weapon_type: int, is_crit: bool) -> void:
	if not _sound_enabled():
		return
	if not (AudioManager and AudioManager.has_method("play_sfx")):
		return
	var vol: float = 0.6
	var pitch: float = randf_range(0.95, 1.05)
	match weapon_type:
		3, 9:    vol = 1.0                              # ROCKET/MISSILE 爆炸最响
		8:       vol = 0.4; pitch = randf_range(3.0, 5.0)  # LASER 高频
		7:       vol = 0.8                              # FLAK 空爆
		5:       vol = 0.7                              # SHOTGUN 碎屑
		6:       vol = 0.7; pitch *= 1.3                # SNIPER 清脆
		_:       vol = 0.6
	if is_crit:
		vol = minf(vol * 1.5, 1.0)  # 暴击加响
		pitch *= 0.8                # 暴击降调（沉闷重击感）
	AudioManager.play_sfx("impact_generic", vol, pitch)

## 播放死亡音效
func play_death_sound() -> void:
	if not _sound_enabled():
		return
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("unit_death")
