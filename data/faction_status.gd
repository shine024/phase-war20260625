extends RefCounted
class_name FactionStatus
## v6.10: 势力状态机（派生标签，不存储）
##
## 设计理念：
## - 势力状态从"占领关卡数 + 声望"实时派生，避免独立存储导致的"双源真理"
## - 状态本身是 UI 标签 + 配色，影响势力面板的视觉呈现（不强加数值加成）
## - 5 档状态反映势力的兴衰：
##     濒亡 EXTINCT     — 无领地且声望极低（几乎被消灭）
##     衰落 DECLINING   — 领地稀少或声望低（苟延残喘）
##     稳定 STABLE      — 中等领地/声望（正常运营）
##     扩张 EXPANDING   — 领地较多或声望较高（正在崛起）
##     威赫 DOMINANT    — 领地很多或声望极高（霸主地位）
##
## 领地参考：7势力初始领地 10-20 关（nova/aether/quantum 各20，helix/void 各10）
## 占领转移后领地会变化，状态随之派生变化

enum Status { EXTINCT, DECLINING, STABLE, EXPANDING, DOMINANT }

const STATUS_NAMES: Dictionary = {
	Status.EXTINCT: "濒亡",
	Status.DECLINING: "衰落",
	Status.STABLE: "稳定",
	Status.EXPANDING: "扩张",
	Status.DOMINANT: "威赫",
}

## 状态配色（UI 用，暖色=强势，冷色=弱势）
const STATUS_COLORS: Dictionary = {
	Status.EXTINCT: Color(0.45, 0.45, 0.48, 0.9),    # 灰：濒亡
	Status.DECLINING: Color(0.82, 0.5, 0.4, 0.95),   # 暗红橙：衰落
	Status.STABLE: Color(0.5, 0.72, 0.95, 0.95),     # 蓝：稳定
	Status.EXPANDING: Color(0.4, 0.92, 0.6, 1.0),    # 绿：扩张
	Status.DOMINANT: Color(1.0, 0.84, 0.3, 1.0),     # 金：威赫
}

## 派生状态：领地×声望双维度组合判定
## [param territory_count] 占领关卡数（动态，来自 get_territory_count）
## [param reputation] 声望值（0-10000，来自 get_faction_reputation）
## [return] Status 枚举值
static func derive_status(territory_count: int, reputation: int) -> int:
	# 濒亡：无领地且声望极低
	if territory_count == 0 and reputation < 2000:
		return Status.EXTINCT
	# 威赫：领地很多或声望极高（任一维度达顶峰）
	if territory_count >= 18 or reputation >= 8500:
		return Status.DOMINANT
	# 扩张：领地较多或声望较高
	if territory_count >= 10 or reputation >= 6500:
		return Status.EXPANDING
	# 衰落：领地稀少或声望低
	if territory_count <= 2 or reputation < 3000:
		return Status.DECLINING
	# 稳定：中间状态
	return Status.STABLE

## 获取状态中文名
static func get_status_name(status: int) -> String:
	return String(STATUS_NAMES.get(status, "未知"))

## 获取状态配色
static func get_status_color(status: int) -> Color:
	return STATUS_COLORS.get(status, Color(0.7, 0.7, 0.7, 0.9))
