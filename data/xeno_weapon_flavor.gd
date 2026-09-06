extends RefCounted
class_name XenoWeaponFlavor
## 星冥武器视觉 flavor 单一真身（v27.x 黑门无限模式）
##
## 问题：星冥 20 单位的 weapon_label（"双光刃""棱光束""灵能风暴"等）不含任何
## 人类武器关键词，开火/弹道/命中全部与人类单位同源——近战挥刀单位发射坦克式
## 曳光弹，命中一律橙红火光。本表把 20 个武器名分成 5 个星冥 flavor，供
## 解析层（WeaponVisualProfiles）/ 命中层（spawn_impact_with_kind）/ 弹体层
## （bullet + 三 projectile batch）做专属视觉分派。
##
## 设计要点：
## 1. 按武器名分流而非阵营——玩家缴获卡（captured_xeno_*）与敌方共用同款视觉，
##    与 DirectWeaponFlavor/WeaponVisualProfiles 的武器名分派架构同构。
## 2. 伤害时序零改动：近战（MELEE_EDGE）仍走弹道路由（射程 100-300px、飞行
##    0.1-0.4s），只换视觉皮——弹体=紫青光片、命中=爪痕爆裂、枪口=出刀弧光。
## 3. visual_wt 映射只影响视觉（弹体形态/命中签名），不改战斗路由（曲射/空射
##    的 is_indirect_weapon_type 判定仍用原始 wt）——棱光束借 wt6 光束签名、
##    相位炮/湮灭光炮借 wt8 激光灼烧签名，弧线/直线的弹道语义保持原域。
## 4. 配色与黑门氛围层同源：endless_rift_ambience._ENV_LOOK 的 vein 双色
##    （青=默认晶脉 / 紫=灵能风暴），星冥特效用同两色，战场视觉语言统一。
##
## 回退开关：GameConfig.xeno_vfx_enabled（false=全部消费方短路回人类通用视觉）。
## 数据锁：tests/xeno_weapon_flavor_smoke.gd（20 名单全覆盖 + 分组断言）。

enum Flavor {
	NONE = -1,
	MELEE_EDGE = 0,    ## 近战刃光（蚀爪/双光刃/利爪/虚空折刃/拟形触刃）
	PSI_BOLT = 1,      ## 灵能弹（晶钻/灵能冲击波/时棘/肩炮/脉冲机炮/拦截机群）
	PRISM_BEAM = 2,    ## 棱镜光束（折射棱镜/棱光束/热射线）→ 借 wt6 光束签名
	PHASE_CANNON = 3,  ## 相位/湮灭重炮（相位炮/聚能主炮/湮灭光炮）→ 借 wt8 激光灼烧
	PLASMA_LOB = 4,    ## 等离子曲射（等离子抛射/蠕虫弹药/灵能风暴）→ 保持弧线+能量爆炸帧
}

## 青金晶髓（与 endless_rift_ambience._ENV_LOOK 默认 vein 同源）
const COLOR_EDGE := Color(0.25, 0.9, 0.85)
## 灵能紫（与 _ENV_LOOK.psi_storm vein 同源；刻意区别于欧米茄族的 0.75,0.40,1.0）
const COLOR_PSI := Color(0.66, 0.52, 1.0)

## 武器名 → flavor 精确表。名单以 data/xeno_units.gd UNITS 的 weapon_label 为准，
## 新增星冥单位必须同步本表（smoke 锁会暴露漏配）。
const FLAVOR_MAP: Dictionary = {
	# ── MELEE_EDGE：近战刃光（射程 ≤300 的刃/爪族）──
	"蚀爪": Flavor.MELEE_EDGE,
	"双光刃": Flavor.MELEE_EDGE,
	"利爪": Flavor.MELEE_EDGE,
	"虚空折刃": Flavor.MELEE_EDGE,
	"拟形触刃": Flavor.MELEE_EDGE,
	# ── PSI_BOLT：灵能弹（保持原始弹道域，只做颜色/命中层覆盖）──
	"晶钻": Flavor.PSI_BOLT,
	"灵能冲击波": Flavor.PSI_BOLT,
	"时棘": Flavor.PSI_BOLT,
	"肩炮": Flavor.PSI_BOLT,
	"脉冲机炮": Flavor.PSI_BOLT,
	"拦截机群": Flavor.PSI_BOLT,
	# ── PRISM_BEAM：棱镜光束 → wt6 光束/狙击签名 ──
	"折射棱镜": Flavor.PRISM_BEAM,
	"棱光束": Flavor.PRISM_BEAM,
	"热射线": Flavor.PRISM_BEAM,
	# ── PHASE_CANNON：相位/湮灭重炮 → wt8 激光灼烧签名（命中侧）──
	"相位炮": Flavor.PHASE_CANNON,
	"聚能主炮": Flavor.PHASE_CANNON,
	"湮灭光炮": Flavor.PHASE_CANNON,
	# ── PLASMA_LOB：等离子曲射 → 钉住 wt1（防 OMEGA_KEYWORDS"等离子"抢占误归 wt10）──
	"等离子抛射": Flavor.PLASMA_LOB,
	"蠕虫弹药": Flavor.PLASMA_LOB,
	"灵能风暴": Flavor.PLASMA_LOB,
}

## flavor → 视觉 wt 覆盖（弹体形态/命中签名层）。-1 = 不覆盖，保持调用方原始域
## （PSI_BOLT 组整体 -1：轻动能/空射弹道不变，颜色层负责区分）。
const _FLAVOR_VISUAL_WT: Dictionary = {
	Flavor.MELEE_EDGE: 0,
	Flavor.PSI_BOLT: -1,
	Flavor.PRISM_BEAM: 6,
	Flavor.PHASE_CANNON: 8,
	Flavor.PLASMA_LOB: 1,
}

## 武器名 → 视觉 wt 精确表（供 WeaponVisualProfiles.resolve_traced 第 1 优先级
## 与签名精确表并列消费）。仅收录需要换签名的武器；PSI_BOLT 组不入表
## （wt0 保持轻动能、wt2 保持空射，域感知兜底自然处理）。
const VISUAL_WT_MAP: Dictionary = {
	"蚀爪": 0, "双光刃": 0, "利爪": 0, "虚空折刃": 0, "拟形触刃": 0,
	"折射棱镜": 6, "棱光束": 6, "热射线": 6,
	"相位炮": 8, "聚能主炮": 8, "湮灭光炮": 8,
	"等离子抛射": 1, "蠕虫弹药": 1, "灵能风暴": 1,
}


## 武器名 → flavor。零分配静态精确匹配；空名/未命中 → NONE（调用方走原路径）。
static func classify(weapon_name: String) -> int:
	if weapon_name.is_empty():
		return Flavor.NONE
	return int(FLAVOR_MAP.get(weapon_name, Flavor.NONE))


## 回退开关查询。⚠️ GDScript 的 autoload 标识符（GameConfig.xxx）不能在 static
## 函数中引用（无实例上下文，编译期解析失败会丢整个函数表）——所有消费方（含
## 静态路径）统一经本方法取开关。运行时解析 /root/GameConfig；节点不存在
## （--script 模式测试）默认 true，测试不受开关影响。结果按会话缓存（设置无
## 运行期改道场景；如将来要做设置热切换，清 _switch_cache 即可）。
static var _switch_cache: int = -1  ## -1=未查询 0=关 1=开
static func enabled() -> bool:
	if _switch_cache < 0:
		var v: bool = true
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			var gc: Node = (ml as SceneTree).root.get_node_or_null("GameConfig")
			if gc != null and "xeno_vfx_enabled" in gc:
				v = bool(gc.get("xeno_vfx_enabled"))
		_switch_cache = 1 if v else 0
	return _switch_cache == 1


static func is_xeno_weapon(weapon_name: String) -> bool:
	return classify(weapon_name) != Flavor.NONE


## flavor → 主色（近战/棱镜=青金晶髓，其余=灵能紫）。
static func flavor_color(flavor: int) -> Color:
	if flavor == Flavor.MELEE_EDGE or flavor == Flavor.PRISM_BEAM:
		return COLOR_EDGE
	return COLOR_PSI


## flavor → 视觉 wt 覆盖值。-1 = 保持原始域（调用方跳过覆盖）。
static func visual_wt_override(flavor: int) -> int:
	return int(_FLAVOR_VISUAL_WT.get(flavor, -1))


## 武器名 → 视觉 wt 精确查表。-1 = 无覆盖（不进解析优先链）。
static func visual_wt_exact(weapon_name: String) -> int:
	if weapon_name.is_empty():
		return -1
	return int(VISUAL_WT_MAP.get(weapon_name, -1))
