extends Node
## 情报库管理器：记录和管理玩家解锁的所有情报资料

const DEBUG_LOG := false

signal lore_unlocked(lore_id: String, lore_name: String)

## 情报数据库定义
const LORE_DATABASE: Dictionary = {
	# 一战情报
	"lore_ww1_trench": {
		"id": "lore_ww1_trench",
		"name": "堑壕战术手册",
		"era": 0,
		"category": "tactics",
		"description": "记录了一战时期堑壕战的战术细节，包括地道挖掘、突击队战术等。",
		"flavor_text": "\"在泥泞与铁丝网之间，勇气与绝望并存。\"",
	},
	"lore_ww1_gas": {
		"id": "lore_ww1_gas",
		"name": "化学武器报告",
		"era": 0,
		"category": "technology",
		"description": "关于首次在战场上使用化学武器的详细报告和应对措施。",
		"flavor_text": "\"风改变方向，死亡便不分敌我。\"",
	},
	"lore_ww1_tank": {
		"id": "lore_ww1_tank",
		"name": "早期坦克设计图",
		"era": 0,
		"category": "technology",
		"description": "世界上第一批坦克的设计草图和实战性能评估。",
		"flavor_text": "\"陆地巡洋舰——一个钢铁怪兽的诞生。\"",
	},

	# 二战情报
	"lore_ww2_blitzkrieg": {
		"id": "lore_ww2_blitzkrieg",
		"name": "闪电战档案",
		"era": 1,
		"category": "tactics",
		"description": "德军闪电战战术的完整分析，包括装甲部队与空军的协同作战。",
		"flavor_text": "\"速度就是一切——在敌人反应之前击溃他们。\"",
	},
	"lore_ww2_enigma": {
		"id": "lore_ww2_enigma",
		"name": "恩尼格玛密码机",
		"era": 1,
		"category": "technology",
		"description": "盟军破解德军恩尼格玛密码机的历程和其对战争进程的影响。",
		"flavor_text": "\"数学是战场之外最致命的武器。\"",
	},
	"lore_ww2_manhattan": {
		"id": "lore_ww2_manhattan",
		"name": "曼哈顿计划档案",
		"era": 1,
		"category": "technology",
		"description": "美国原子弹研发项目的绝密档案片段。",
		"flavor_text": "\"释放太阳的力量——人类命运的转折点。\"",
	},

	# 冷战情报
	"lore_cold_berlin": {
		"id": "lore_cold_berlin",
		"name": "柏林墙日记",
		"era": 2,
		"category": "history",
		"description": "柏林墙修建与倒塌期间的个人记录。",
		"flavor_text": "\"一堵墙，分割了整整一代人。\"",
	},
	"lore_cold_cuban": {
		"id": "lore_cold_cuban",
		"name": "古巴导弹危机纪要",
		"era": 2,
		"category": "history",
		"description": "人类最接近核毁灭的13天详细记录。",
		"flavor_text": "\"按钮就在指尖，只等待一个错误的判断。\"",
	},
	"lore_cold_kgb": {
		"id": "lore_cold_kgb",
		"name": "冷战谍报手册",
		"era": 2,
		"category": "tactics",
		"description": "东西方情报机构在冷战期间的谍战技术。",
		"flavor_text": "\"真相是战争的第一批伤亡者。\"",
	},

	# 现代情报
	"lore_modern_drone": {
		"id": "lore_modern_drone",
		"name": "无人机作战手册",
		"era": 3,
		"category": "tactics",
		"description": "现代战争中无人机的使用战术和技术规范。",
		"flavor_text": "\"千里之外，决胜于无形。\"",
	},
	"lore_modern_cyber": {
		"id": "lore_modern_cyber",
		"name": "网络战白皮书",
		"era": 3,
		"category": "technology",
		"description": "21世纪新型战争形态——网络攻击与防御的理论与实践。",
		"flavor_text": "\"键盘比枪炮更能改变世界。\"",
	},

	# 近未来情报
	"lore_future_phase": {
		"id": "lore_future_phase",
		"name": "相位技术纲要",
		"era": 4,
		"category": "technology",
		"description": "关于相位位移和相位驱动器的基础理论与应用。",
		"flavor_text": "\"现实不过是另一种频率的振动。\"",
	},
	"lore_future_nano": {
		"id": "lore_future_nano",
		"name": "纳米工程导论",
		"era": 4,
		"category": "technology",
		"description": "纳米技术在军事领域的应用前景与伦理讨论。",
		"flavor_text": "\"最小的机器，最大的变革。\"",
	},
}

## 已解锁的情报ID列表
var unlocked_lore_ids: Array[String] = []

func _ready() -> void:
	# 注册为自动加载单例（如果还未注册）
	pass

## 解锁情报
func unlock_lore(lore_id: String) -> void:
	if not LORE_DATABASE.has(lore_id):
		push_error("[LoreManager] 未知的情报ID: %s" % lore_id)
		return

	if unlocked_lore_ids.has(lore_id):
		return  # 已解锁

	unlocked_lore_ids.append(lore_id)
	var lore_data = LORE_DATABASE[lore_id]
	lore_unlocked.emit(lore_id, lore_data.get("name", lore_id))
	if DEBUG_LOG:
		print("[LoreManager] 解锁情报: ", lore_data.get("name", lore_id))

## 检查情报是否已解锁
func is_lore_unlocked(lore_id: String) -> bool:
	return unlocked_lore_ids.has(lore_id)

## 获取情报数据
func get_lore_data(lore_id: String) -> Dictionary:
	return LORE_DATABASE.get(lore_id, {})

## 获取所有已解锁的情报
func get_unlocked_lore() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lore_id in unlocked_lore_ids:
		result.append(LORE_DATABASE.get(lore_id, {}))
	return result

## 获取指定时代的所有情报
func get_lore_by_era(era: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lore_id in LORE_DATABASE:
		var lore_data = LORE_DATABASE[lore_id]
		if lore_data.get("era", -1) == era:
			result.append(lore_data)
	return result

## 获取指定时代的已解锁情报
func get_unlocked_lore_by_era(era: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lore_id in unlocked_lore_ids:
		var lore_data = LORE_DATABASE.get(lore_id, {})
		if lore_data.get("era", -1) == era:
			result.append(lore_data)
	return result

## 获取解锁进度
func get_unlock_progress() -> Dictionary:
	var total = LORE_DATABASE.size()
	var unlocked = unlocked_lore_ids.size()
	var era_progress = {}

	for era in range(5):
		var era_lore = get_lore_by_era(era)
		var era_unlocked = get_unlocked_lore_by_era(era).size()
		era_progress[era] = {
			"total": era_lore.size(),
			"unlocked": era_unlocked,
			"percentage": float(era_unlocked) / float(era_lore.size()) * 100.0 if era_lore.size() > 0 else 0.0
		}

	return {
		"total": total,
		"unlocked": unlocked,
		"percentage": float(unlocked) / float(total) * 100.0 if total > 0 else 0.0,
		"era_progress": era_progress
	}

## 保存状态
func save_state() -> Dictionary:
	return {
		"unlocked_lore_ids": unlocked_lore_ids
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	unlocked_lore_ids.clear()
	var saved_ids = data.get("unlocked_lore_ids", [])
	for lore_id in saved_ids:
		if LORE_DATABASE.has(lore_id):
			unlocked_lore_ids.append(lore_id)
	if DEBUG_LOG:
		print("[LoreManager] 加载情报状态，已解锁: ", unlocked_lore_ids.size(), "/", LORE_DATABASE.size())
