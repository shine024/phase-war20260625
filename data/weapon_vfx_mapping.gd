extends RefCounted
class_name WeaponVfxMapping
## 武器名称 -> 弹道/命中贴图映射表 (v6.0)

const TEXTURE_DIR := "res://assets/effects/projectiles/weapons_realistic/"

## 武器名 -> safe_id 映射
const WEAPON_ID_MAP: Dictionary = {
	"100mm主炮": "34636ba0",
	"105mm/120mm主炮": "b0a6a384",
	"105mm/120mm榴弹炮": "05008121",
	"105mm主炮": "32033ff1",
	"12.7mm重机枪": "b709fc57",
	"120mm L55主炮": "678afd48",
	"120mm/125mm主炮": "98b27588",
	"120mm主炮": "646e2ccf",
	"120mm滑膛炮": "f2116a3e",
	"122mm主炮": "b5323b36",
	"125mm滑膛炮": "a7f4662a",
	"14.5mm车载机枪": "a27da07f",
	"150mm要塞炮/88mm防空炮": "1db2cb1b",
	"20mm/25mm高炮": "8ef725f7",
	"20mm机炮": "c0ff7d76",
	"227mm火箭炮": "a2cb5064",
	"23mm/30mm高射炮": "d11df42c",
	"25mm M242大毒蛇": "962a6cd6",
	"25mm近防炮": "eb5febdb",
	"37mm/57mm坦克炮": "82a8d6fe",
	"40mm榴弹": "c5d6011e",
	"57mm/75mm坦克炮": "3afb2dc7",
	"7.62mm/12.7mm高机枪": "0d669269",
	"7.62mm舱门机枪/轻型机炮": "7bf54018",
	"73mm/90mm反坦克炮": "38bab7ad",
	"75mm/76mm坦克炮": "8c79c173",
	"81mm/105mm火炮": "8a4b5679",
	"85mm/105mm主炮": "0d999b39",
	"85mm主炮": "ce7dd74f",
	"AK-47突击步枪": "c57465bb",
	"M16A4步枪": "58c4ccc3",
	"M4卡宾枪/SCAR-H": "05e7a10d",
	"MG42/双联防空炮": "a823396f",
	"MP18冲锋枪": "f2df5e50",
	"便携式防空导弹": "e676771a",
	"冲锋枪/步枪": "777e08b6",
	"双联装电磁炮": "1d0092d1",
	"地狱火导弹/127mm舰炮": "93d43e5e",
	"多管近防炮/88mm防空炮": "7805fcb4",
	"攻城电磁炮": "7f0670fb",
	"暴风冲锋枪": "510b47a9",
	"植入式自动步枪/重型粒子炮": "ed65aab9",
	"毛瑟G98步枪": "421c33d2",
	"火箭筒/轻型装甲武器": "084e62ad",
	"点防御激光": "81334e6c",
	"电磁轨道炮": "7755baff",
	"离子炮": "46b0d3db",
	"离子炮阵列": "581aff33",
	"空空导弹/20mm机炮": "24b45a0c",
	"萨姆-7导弹/防空导弹": "70912efd",
	"轨道炮/激光": "4a46bf81",
	"迫击炮/野战炮": "66c9913a",
	"重型等离子加农炮": "a6b9c8a9",
	"防空机枪": "5cf65f67",
	"骑兵卡宾枪/马刀": "cf369e42",
}

## 安全ID -> 弹道贴图
static func proj_texture(safe_id: String) -> Texture2D:
	var path := TEXTURE_DIR + safe_id + "_proj.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## 安全ID -> 命中贴图
static func impact_texture(safe_id: String) -> Texture2D:
	var path := TEXTURE_DIR + safe_id + "_impact.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## 获取武器的安全ID
static func get_weapon_safe_id(weapon_name: String) -> String:
	if weapon_name in WEAPON_ID_MAP:
		return WEAPON_ID_MAP[weapon_name]
	return ""

## 获取武器分类
static func get_category(weapon_name: String) -> String:
	if weapon_name in WEAPON_ID_MAP:
		return WEAPON_ID_MAP[weapon_name]["category"] if WEAPON_ID_MAP[weapon_name] is Dictionary else "generic"
	return "generic"
