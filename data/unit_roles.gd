extends RefCounted
class_name UnitRoles
## v21 P2: 战场角色归一化（P2-0）
##
## 目的：搭档协同（PAIR_SYNERGIES）需要稳定的"角色"语义，而战场侧单位身份散落在
## 三个数据源里——combat_kind（0轻/1甲/2支/3空/4堡）、unit_subtype（NONE/炮兵/支援/
## 堡垒/防空，game_constants.gd）、card_id 前缀（侦察系）/card_tags（工程系）。
## 本文件把三源归一成 9 角色；规则全部保守（不确定时回退 UNIVERSAL），注释逐条声明。
##
## 使用：战斗侧一律走 resolve_role_cached(stats)（结果缓存到 stats meta "_unit_role"，
## 建卡后属性不变 → 缓存安全，无每帧开销）；数据侧（测试/配置）可直接调 resolve_role。

# ── 角色枚举（int 常量，避免跨类枚举时序问题，同 combo_tactics 范式）──
const ROLE_INFANTRY  := 0   # 步兵（轻装基线）
const ROLE_ARMOR     := 1   # 装甲
const ROLE_ARTILLERY := 2   # 火炮（含支援主类下的炮兵子类）
const ROLE_ANTI_AIR  := 3   # 防空
const ROLE_AIR       := 4   # 空中
const ROLE_RECON     := 5   # 侦察（前缀判定）
const ROLE_ENGINEER  := 6   # 工程（支援子类 + 工程证据）
const ROLE_FORT      := 7   # 堡垒
const ROLE_UNIVERSAL := 8   # 兜底（无法判定/支援类非工程）

## CombatKind 整数（对齐 game_constants.gd CombatKind）
const KIND_LIGHT   := 0
const KIND_ARMOR   := 1
const KIND_SUPPORT := 2
const KIND_AIR     := 3
const KIND_FORT    := 4

## UnitSubType 整数（对齐 game_constants.gd UnitSubType）
const SUB_NONE      := 0
const SUB_ARTILLERY := 1
const SUB_SUPPORT   := 2
const SUB_FORT      := 3
const SUB_ANTI_AIR  := 4

## v21 P2: 侦察卡前缀表——从 unit_stats_table._RECON_PREFIXES 升格迁移至此
##（单一真身搬到家；原文件改为引用本常量，语义不变）
const RECON_PREFIXES := [
	"ww1_inf_cavalry", "cold_spetsnaz", "mod_ranger",
	"fut_spectre", "fut_inf_scout_mech", "mod_inf_scout_drone",
]

## 工程卡硬前缀（支援主类下 ww1_sup_engineer 系）
const ENGINEER_PREFIX := "ww1_sup_engineer"

## stats meta 键（角色缓存）
const META_UNIT_ROLE := "_unit_role"


## 归一化规则主体。
## 参数：
##   card_id       卡牌 id（前缀判定用，可为空）
##   combat_kind   CombatKind 整数
##   unit_subtype  UnitSubType 整数
##   opts          可选证据 {is_engineer: bool, card_tags: Array[String]}
## 规则（顺序即优先级）：
##   1. combat_kind 直映射：ARMOR→ARMOR、AIR→AIR、FORT→FORT（子类不覆盖主类身份）
##   2. 轻装/支援主类 + subtype：
##      ARTILLERY→ARTILLERY；ANTI_AIR→ANTI_AIR；
##      SUPPORT→有工程证据（is_engineer meta / card_tags 含 engineer / 前缀）→ ENGINEER，否则 UNIVERSAL；
##      NONE→前缀命中 RECON_PREFIXES → RECON，否则 INFANTRY。
##   3. 其余（含未知 kind/subtype 值）→ UNIVERSAL（保守兜底）。
## 注：计划角色表无独立"支援"角色——支援主类按子类分流（炮/防空/工程/兜底），
##     这是有意的窄化（搭档协同只消费上述 9 角色），在此注释声明。
static func resolve_role(card_id: String, combat_kind: int, unit_subtype: int, opts: Dictionary = {}) -> int:
	# 1. 主类直映射
	if combat_kind == KIND_ARMOR:
		return ROLE_ARMOR
	if combat_kind == KIND_AIR:
		return ROLE_AIR
	if combat_kind == KIND_FORT:
		return ROLE_FORT
	# 2. 轻装/支援主类按子类分流
	if combat_kind == KIND_LIGHT or combat_kind == KIND_SUPPORT:
		match unit_subtype:
			SUB_ARTILLERY:
				return ROLE_ARTILLERY
			SUB_ANTI_AIR:
				return ROLE_ANTI_AIR
			SUB_SUPPORT:
				if _has_engineer_evidence(card_id, opts):
					return ROLE_ENGINEER
				return ROLE_UNIVERSAL
			_:
				# NONE / 未知子类：前缀侦察判定，否则步兵
				if _is_recon_card(card_id):
					return ROLE_RECON
				return ROLE_INFANTRY
	# 3. 保守兜底
	return ROLE_UNIVERSAL


## 战斗侧入口：从 UnitStats 解析角色并缓存（meta "_unit_role"）。
## stats 需携带 card_id / platform_card_id、combat_kind、unit_subtype；
## 工程证据读 meta is_engineer 与 meta card_tags。
## 无 stats 或缺字段时返回 ROLE_UNIVERSAL（不写缓存）。
static func resolve_role_cached(stats: Variant) -> int:
	if stats == null or not (stats is Resource):
		return ROLE_UNIVERSAL
	var st := stats as Resource
	if st.has_meta(META_UNIT_ROLE):
		return int(st.get_meta(META_UNIT_ROLE, ROLE_UNIVERSAL))
	# 采集三源
	var card_id: String = ""
	if "platform_card_id" in st:
		card_id = String(st.get("platform_card_id"))
	if card_id.is_empty() and "card_id" in st:
		card_id = String(st.get("card_id"))
	var combat_kind: int = int(st.get("combat_kind")) if "combat_kind" in st else -1
	var unit_subtype: int = int(st.get("unit_subtype")) if "unit_subtype" in st else int(SUB_NONE)
	var opts: Dictionary = {}
	if st.has_meta("is_engineer"):
		opts["is_engineer"] = bool(st.get_meta("is_engineer", false))
	if st.has_meta("card_tags"):
		opts["card_tags"] = st.get_meta("card_tags", [])
	var role: int = resolve_role(card_id, combat_kind, unit_subtype, opts)
	st.set_meta(META_UNIT_ROLE, role)
	return role


## 前缀侦察判定（与 unit_stats_table._is_recon_card 同口径）
static func _is_recon_card(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	for p in RECON_PREFIXES:
		if card_id.begins_with(String(p)):
			return true
	return false


## 工程证据：显式 meta / card_tags 标签 / 硬前缀，任一命中即可
static func _has_engineer_evidence(card_id: String, opts: Dictionary) -> bool:
	if bool(opts.get("is_engineer", false)):
		return true
	var tags: Array = opts.get("card_tags", [])
	for t in tags:
		var ts := String(t).to_lower()
		if ts == "engineer" or ts == "工程" or ts == "工兵":
			return true
	if not card_id.is_empty() and card_id.begins_with(ENGINEER_PREFIX):
		return true
	return false
