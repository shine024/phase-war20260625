extends Resource
class_name WeaponResource
## 武器槽位资源：定义单个武器的完整属性
## 用于战斗卡的三个武器槽位（轻装/装甲/对空）

# ═══════════════════════════════════════════════════════════════
# 基础标识
# ═══════════════════════════════════════════════════════════════

## 武器唯一ID，格式如："card_id_slot_light" 或预设模板ID
@export var weapon_id: String = ""

## 槽位类型：0=轻装, 1=装甲, 2=对空
## 与 GameConstants.CombatKind 对应：LIGHT=0, ARMOR=1, AIR=2
@export var slot_type: int = 0

## 武器显示名称（如："步枪"、"坦克炮"、"防空导弹"）
@export var display_name: String = ""

## 武器外观标签（短标签，用于UI显示）
@export var weapon_label: String = ""

## 是否启用（false表示空槽位）
@export var enabled: bool = true

# ═══════════════════════════════════════════════════════════════
# 攻击属性
# ═══════════════════════════════════════════════════════════════

## 伤害值（针对槽位对应的目标类型）
@export var damage: float = 0.0

## 攻击速度（次/秒）
@export var attack_speed: float = 1.0

## 攻击前摇时间（秒）
@export var windup: float = 0.2

## 攻击动作时间（秒）
@export var active: float = 0.1

# ═══════════════════════════════════════════════════════════════
# 弹道与射程
# ═══════════════════════════════════════════════════════════════

## 弹道类型（GameConstants.WeaponType：DIRECT=0, INDIRECT=1, AERIAL=2）
@export var weapon_type: int = 0

## 射程（格）
@export var range_value: int = 3

# ═══════════════════════════════════════════════════════════════
# 视觉效果
# ═══════════════════════════════════════════════════════════════

## 弹道场景路径（res://scenes/effects/projectiles/...）
@export var projectile_scene: String = ""

## 击中特效场景路径（res://scenes/effects/impact/...）
@export var hit_effect_scene: String = ""

## 攻击音效ID（对应 AudioManager 中的音效）
@export var sound_id: String = ""

# ═══════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════

## 获取攻击周期（秒）
func get_attack_cycle() -> float:
	if attack_speed > 0:
		return 1.0 / attack_speed
	return 1.0

## 获取攻击冷却时间（秒）= 周期 - 前摇 - 动作
func get_cooldown() -> float:
	return maxf(0.0, get_attack_cycle() - windup - active)

## 创建空槽位武器
static func create_empty_slot(slot_idx: int) -> WeaponResource:
	var w = WeaponResource.new()
	w.weapon_id = ""
	w.slot_type = slot_idx
	w.display_name = ""
	w.enabled = false
	return w

## 从现有数据创建槽位武器（向后兼容）
static func create_from_legacy(
	slot_idx: int,
	base_damage: float,
	base_speed: float,
	base_windup: float,
	base_active: float,
	weapon_t: int = 0,
	range_v: int = 3
) -> WeaponResource:
	var w = WeaponResource.new()
	w.slot_type = slot_idx
	w.damage = base_damage
	w.attack_speed = base_speed if base_speed > 0 else 1.0
	w.windup = base_windup
	w.active = base_active
	w.weapon_type = weapon_t
	w.range_value = range_v
	w.enabled = base_damage > 0

	# 设置默认显示名称
	match slot_idx:
		0: w.display_name = "轻装武器"
		1: w.display_name = "装甲武器"
		2: w.display_name = "对空武器"

	return w

## 复制武器（用于改造/进化）
func clone() -> WeaponResource:
	var w = WeaponResource.new()
	w.weapon_id = weapon_id
	w.slot_type = slot_type
	w.display_name = display_name
	w.weapon_label = weapon_label
	w.enabled = enabled
	w.damage = damage
	w.attack_speed = attack_speed
	w.windup = windup
	w.active = active
	w.weapon_type = weapon_type
	w.range_value = range_value
	w.projectile_scene = projectile_scene
	w.hit_effect_scene = hit_effect_scene
	w.sound_id = sound_id
	return w
