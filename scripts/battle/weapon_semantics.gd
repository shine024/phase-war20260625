extends RefCounted
## v38.5: 武器命名语义运行时哨兵
##
## 背景与分工（v38.3/v38.4 复盘）：本项目的武器视觉/行为分层（亚类 flavor / 弹道 wt /
## 点射表）全靠「武器名关键词」驱动，匹配不上就静默落 GENERIC 兜底桶——线膛炮吃步枪级
## 点射、敌方激光武器对空打导弹皆属此类静默错位。回归锁（weapon_visual_profiles_smoke.gd
## [14]）已在测试层拦住；本哨兵补最后一层：**测试没人跑时，错位在开火现场也会喊一嗓子**。
##
## 消费方式：construct_unit_ai.gd 以 preload 常量引用（刻意不用全局 class_name——新建
## class 在 headless --script 模式的全局类缓存里不存在，会连锁编译失败，v38.5 踩坑实录）。
##
## 设计约束：
## - 零分配稳态路径：命中过一次的名字进 _warned 缓存，此后纯 dict 查找即返回。
## - 只告警不修改行为：哨兵永不改动 wt/flavor/点射表（与回归锁分工，锁管"拦"哨兵管"喊"）。
## - 降噪：只盯"语义大概率错位"的组合——直射槽 + GENERIC 兜底 +（重武器语义词 or 占位名）。
##   步枪/机枪等具名武器（走 RIFLE/MG 档）与穿甲弹链/爆破装药等有意 GENERIC 的名字不触发。

## 每进程只告警一次的缓存（名字 → true）
static var _warned: Dictionary = {}

## 占位武器名（槽位无具名武器时的回退名）——分类层全失效的最强信号
const PLACEHOLDER_NAMES: Array = ["轻装武器", "装甲武器", "对空武器"]

## 重武器/能量/制导语义词——出现在直射槽 GENERIC 名里即大概率漏配关键词
const SUSPICIOUS_KEYWORDS: Array = [
	"炮", "导弹", "火箭", "激光", "光束", "粒子", "离子", "狙击", "电磁", "轨道", "磁轨",
]

## 开火现场登记（construct_unit_ai.do_attack_with_damage 单发/直射路径调用）。
## [param wname] 槽位武器显示名；[param wt] 本次开火的路由弹道类型。
static func note_direct_weapon(wname: String, wt: int) -> void:
	if wname.is_empty() or wt != 0:
		return  # 只盯直射槽（点射/直射配方/亚类曳光都在这条槽上生效）
	if _warned.has(wname):
		return
	var flv: int = DirectWeaponFlavor.classify(wname, wt)
	if flv != DirectWeaponFlavor.Flavor.GENERIC:
		return
	var suspicious: bool = wname in PLACEHOLDER_NAMES
	if not suspicious:
		for kw in SUSPICIOUS_KEYWORDS:
			if wname.find(kw) >= 0:
				suspicious = true
				break
	if not suspicious:
		return
	_warned[wname] = true
	push_warning("[WeaponSemantics] 武器'%s'落 GENERIC 兜底（直射槽）——重武器/占位名语义与步枪级配方错位。若为单发/重武器语义，请补 direct_weapon_flavor.gd 关键词或 card_resource 弹道覆盖（参照 v38.3 线膛炮案）" % wname)
