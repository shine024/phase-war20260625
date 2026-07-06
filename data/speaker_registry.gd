## speaker 注册表（v7.x 剧情面板规范化）
##
## 集中维护剧情对话中每个 speaker 的元数据：阵营、方位、立绘路径、配色、显示名。
## 对话数据（quest_definitions.gd 的 pre/post_battle_dialogues）只写 speaker 中文名字符串，
## 由本注册表反查渲染细节，新增/调整 speaker 只改本表一处。
##
## 阵营（faction）四档：
##   - player  我方（主角陈末），固定左侧立绘位
##   - npc     中性 NPC（林薇/扎克/洛克/海伦/真实者等），固定右侧立绘位
##   - enemy   敌方 Boss（铁血男爵/钢铁元帅/相位之主/虚空领主/镜像），固定右侧立绘位
##   - neutral 中立叙述（旁白），无阵营归属，两侧立绘都暗化
##
## 方位（side）由阵营派生：player→left, npc→right, enemy→right, neutral→center
##
## 立绘资产规格（参见 ui/portraits/README.md）：
##   - 全身立绘 540×720，PNG 透明背景
##   - 命名：角色英文小写.png（player/linwei/locke/...），Boss 用 boss_xxx.png
##   - 旧图任意尺寸可继续用（TextureRect 自动适配），新图按规格产出
##
## 别名机制：历史遗留 speaker（指挥官/参谋长/情报官/镜像守护者）映射到对应主条目
extends RefCounted

const DesignTokens = preload("res://resources/design_tokens.gd")

## speaker 元数据主表
## key = speaker 中文名（与 quest_definitions.gd 的 speaker 字段一致）
## value = {display_name, faction, portrait_path, color}
const SPEAKER_REGISTRY := {
	# ── 我方（player，左立绘位）──
	"陈末": {
		"display_name": "陈末",
		"faction": "player",
		"portrait_path": "res://ui/portraits/player.png",
		"color": DesignTokens.COLOR_ACCENT_CYAN,  # 主角青
	},
	# ── 中性 NPC（npc，右立绘位）──
	"林薇": {
		"display_name": "林薇",
		"faction": "npc",
		"portrait_path": "res://ui/portraits/linwei.png",
		"color": Color(0.95, 0.55, 0.7),  # 粉（温柔）
	},
	"扎克": {
		"display_name": "扎克",
		"faction": "npc",
		"portrait_path": "res://ui/portraits/zack.png",
		"color": Color(0.95, 0.65, 0.2),  # 橙（刚毅）
	},
	"洛克": {
		"display_name": "洛克",
		"faction": "npc",
		"portrait_path": "res://ui/portraits/locke.png",
		"color": Color(0.2, 0.8, 0.65),  # 青绿（沉稳）
	},
	"海伦": {
		"display_name": "海伦",
		"faction": "npc",
		"portrait_path": "res://ui/portraits/helen.png",
		"color": Color(0.9, 0.8, 0.3),  # 金（权威/中性）
	},
	"真实者": {
		"display_name": "真实者",
		"faction": "npc",
		"portrait_path": "res://ui/portraits/realist.png",
		"color": Color(0.55, 0.25, 0.75),  # 深紫（神秘/危险）
	},
	# ── 敌方 Boss（enemy，右立绘位）──
	"铁血男爵": {
		"display_name": "铁血男爵",
		"faction": "enemy",
		"portrait_path": "res://ui/portraits/boss_baron.png",
		"color": DesignTokens.COLOR_DANGER,  # 红
	},
	"钢铁元帅": {
		"display_name": "钢铁元帅",
		"faction": "enemy",
		"portrait_path": "res://ui/portraits/boss_marshall.png",
		"color": DesignTokens.COLOR_DANGER,
	},
	"相位之主": {
		"display_name": "相位之主",
		"faction": "enemy",
		"portrait_path": "res://ui/portraits/boss_phase_lord.png",
		"color": DesignTokens.COLOR_DANGER,
	},
	"虚空领主": {
		"display_name": "虚空领主",
		"faction": "enemy",
		"portrait_path": "res://ui/portraits/boss_void_lord.png",
		"color": Color(0.7, 0.2, 0.6),  # 深紫红（区别普通红 Boss）
	},
	"镜像": {
		"display_name": "镜像",
		"faction": "enemy",
		"portrait_path": "res://ui/portraits/boss_mirror.png",
		"color": Color(0.75, 0.78, 0.85),  # 冷银（虚幻）
	},
	# ── 中立叙述（neutral，无阵营）──
	"旁白": {
		"display_name": "旁白",
		"faction": "neutral",
		"portrait_path": "",  # 无立绘，走首字徽章
		"color": Color(0.5, 0.5, 0.55),  # 灰
	},
	"守护者": {
		"display_name": "守护者",
		"faction": "neutral",  # 中立引导者（既非我方也非纯粹敌方）
		"portrait_path": "res://ui/portraits/boss_guardian.png",
		"color": Color(0.3, 0.7, 0.9),  # 青蓝（神秘）
	},
}

## speaker 别名（历史遗留/同义 speaker → 主 speaker）
## 用 _resolve_alias 还原后再查主表
const SPEAKER_ALIASES := {
	"指挥官": "陈末",       # 主角代号，与"陈末"同身份
	"镜像守护者": "镜像",   # 别名
	"参谋长": "旁白",       # 历史遗留，归中立叙述（无立绘）
	"情报官": "旁白",       # 历史遗留，归中立叙述（无立绘）
	# v6.x 历史数据中曾出现的 speaker 别名（保留兼容，未来剧情若用到自动归位）
	"托马斯": "洛克",       # 旧 NPC 名（与引导者洛克合并）
	"soldier_thomas": "洛克",
	"索菲亚": "林薇",       # 旧 NPC 名
	"维克多": "扎克",       # 旧 NPC 名
	"艾莉亚": "海伦",       # 旧 NPC 名
	"诺瓦": "真实者",       # 旧 NPC 名
}

## 还原别名到主 speaker
static func _resolve_alias(speaker: String) -> String:
	var resolved: String = SPEAKER_ALIASES.get(speaker, "")
	if not resolved.is_empty():
		return resolved
	return speaker

## 取 speaker 完整条目（含 display_name/faction/portrait_path/color）
## 未注册的 speaker 返回空字典（调用方走 fallback）
static func get_entry(speaker: String) -> Dictionary:
	var key: String = _resolve_alias(speaker)
	return SPEAKER_REGISTRY.get(key, {})

## 取阵营（player/npc/enemy/neutral），未注册默认 neutral
static func get_faction(speaker: String) -> String:
	var entry: Dictionary = get_entry(speaker)
	return entry.get("faction", "neutral")

## 取方位（"left"/"right"/"center"），由阵营派生
## player→left, npc/enemy→right, neutral→center
static func get_side(speaker: String) -> String:
	var faction: String = get_faction(speaker)
	match faction:
		"player":
			return "left"
		"npc", "enemy":
			return "right"
		_:
			return "center"

## 取立绘路径（未注册或无立绘返回空串）
static func get_portrait_path(speaker: String) -> String:
	var entry: Dictionary = get_entry(speaker)
	return entry.get("portrait_path", "")

## 取配色（未注册默认红色，与历史 fallback 行为一致）
static func get_color(speaker: String) -> Color:
	var entry: Dictionary = get_entry(speaker)
	return entry.get("color", DesignTokens.COLOR_DANGER)

## 取显示名（未注册时回退到原 speaker 字符串）
static func get_display_name(speaker: String) -> String:
	var entry: Dictionary = get_entry(speaker)
	return entry.get("display_name", speaker)

## 判断是否是已注册 speaker（含别名）
static func is_registered(speaker: String) -> bool:
	return not get_entry(speaker).is_empty()
