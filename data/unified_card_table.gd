extends RefCounted
class_name UnifiedCardTable
## ════════════════════════════════════════════════════════════════════════
## 统一卡牌表（v8.0 单一真值源）
##
## 背景：原有三套并行卡牌数据源（玩家原生卡 default_cards / 缴获卡
## captured_card_stats / 敌方原型 enemy_archetypes+manifest），数值量级严重
## 不统一——缴获卡复刻敌方低量级（虚空领主 240 血）进玩家背包后只有 240 血，
## 而同名原生卡 2200 血，差近 10 倍。
##
## 本表是唯一数据源，消灭三套数据的量级混乱：
##   - 玩家原生卡：直接读本表构造 CardResource
##   - 敌方原型：读本表 + 字段转换（格→像素等），战场叠 wave/level/master 难度乘区
##   - 缴获卡：克隆本表同名卡（与商店买的卡数值完全一致）
##
## base_hp 标定原则（中间值）：
##   - 取原三套数据的中位数向上靠档，避免缴获卡太脆 / 玩家裸卡太肉
##   - 按档次：普通80-200 / 精英300-600 / boss800-1500 / 终极1200-1800 / 堡垒600-2500
##   - 攻击/防御同步等比缩放，保持 DPS/HP 比率
##
## 字段口径 = 玩家卡口径（CardResource 三维攻防 + range_value格数 + attack_speed次/秒）
## ════════════════════════════════════════════════════════════════════════

const GC = preload("res://resources/game_constants.gd")

## 单位档次（用于标定和掉落梯度）
enum Tier {
	GRUNT,     # 普通杂兵
	VETERAN,   # 老练单位
	ELITE,     # 精英
	CHAMPION,  # 精英头目
	BOSS,      # 时代Boss/守护者
	ULTIMATE,  # 终极单位（虚空领主等）
	FORT       # 堡垒
}

## ════════════════════════════════════════════════════════════════════════
## 数据表
## 每条记录字段说明：
##   card_id:       唯一ID（与原 default_cards card_id 一致，敌方独有单位用其 enemy_id）
##   display_name:  显示名
##   era:           时代 0-4
##   combat_kind:   战斗定位 0=轻装/1=装甲/2=支援/3=空中/4=堡垒
##   tier:          档次（Tier 枚举）
##   base_hp:       标定后生命值
##   range_value:   射程（格数，99=全图）
##   deploy_speed:  部署速度 0-7
##   base_speed:    移动速度（0=固定）
##   power:         战力
##   weapon_type:   武器类型（4值新枚举 0=直射/1=曲射/2=空射/3=支援）
##   weapon_label:  武器显示名
##   atk_l/a/air:   三维攻击（对轻装/装甲/空中）
##   atk_l_speed:   对轻装攻速（次/秒）
##   atk_l_windup/active: 对轻装前摇/动作时间
##   atk_a_speed/windup/active:  对装甲攻速参数
##   atk_air_speed/windup/active: 对空中攻速参数
##   def_l/a/air:   三维防御
##   w_light/armor/air: 三槽武器名
##   enemy_only:    是否仅敌方出现（true=不在玩家商店出售，仅靠缴获/掉落获得）
## ════════════════════════════════════════════════════════════════════════

const _TABLE: Array = [

	# ══════════════ 一战时代 (era=0) ══════════════
	# --- 玩家卡 ---
	{"card_id":"ww1_mp18","display_name":"MP18突击班","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":109,"range_value":2,"deploy_speed":4,"base_speed":80,"power":18,"weapon_type":0,
	 "weapon_label":"MP18冲锋枪",
	 "atk_l":33,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":15,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":8,"def_a":4,"def_air":2,
	 "w_light":"MP18冲锋枪","w_armor":"","w_air":""},

	{"card_id":"ww1_mauser","display_name":"毛瑟步枪班","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":105,"range_value":3,"deploy_speed":3,"base_speed":80,"power":18,"weapon_type":0,
	 "weapon_label":"毛瑟G98步枪",
	 "atk_l":32,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":14,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":7,"def_a":4,"def_air":2,
	 "w_light":"毛瑟G98步枪","w_armor":"","w_air":""},

	{"card_id":"ww1_enfield","display_name":"李恩菲尔德班","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":105,"range_value":3,"deploy_speed":3,"base_speed":80,"power":18,"weapon_type":0,
	 "weapon_label":"李恩菲尔德步枪",
	 "atk_l":32,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":14,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":7,"def_a":4,"def_air":2,
	 "w_light":"李恩菲尔德步枪","w_armor":"","w_air":""},

	{"card_id":"ww1_mg08","display_name":"MG08机枪巢","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":170,"range_value":4,"deploy_speed":0,"base_speed":0,"power":28,"weapon_type":0,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":41,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":136,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":8,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":5,"def_a":7,"def_air":3,
	 "w_light":"81mm/105mm火炮","w_armor":"","w_air":"7.62mm/12.7mm高机枪"},

	{"card_id":"ww1_vickers","display_name":"维克斯机枪巢","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":162,"range_value":4,"deploy_speed":0,"base_speed":0,"power":28,"weapon_type":0,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":39,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":130,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":8,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":5,"def_a":7,"def_air":3,
	 "w_light":"81mm/105mm火炮","w_armor":"","w_air":"7.62mm/12.7mm高机枪"},

	{"card_id":"ww1_arty_m81","display_name":"81mm迫击炮组","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":139,"range_value":99,"deploy_speed":1,"base_speed":0,"power":28,"weapon_type":1,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":33,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":111,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":7,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":4,"def_a":6,"def_air":3,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":""},

	{"card_id":"ww1_m76","display_name":"76mm迫击炮组","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":131,"range_value":99,"deploy_speed":1,"base_speed":0,"power":28,"weapon_type":1,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":31,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":105,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":6,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":4,"def_a":6,"def_air":2,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":""},

	{"card_id":"ww1_storm","display_name":"暴风突击队","era":0,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":201,"range_value":2,"deploy_speed":5,"base_speed":90,"power":24,"weapon_type":0,
	 "weapon_label":"暴风冲锋枪",
	 "atk_l":54,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":24,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":14,"def_a":7,"def_air":4,
	 "w_light":"暴风冲锋枪","w_armor":"73mm/90mm反坦克炮","w_air":""},

	{"card_id":"ww1_arm_rolls","display_name":"罗尔斯装甲车","era":0,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":309,"range_value":3,"deploy_speed":5,"base_speed":100,"power":54,"weapon_type":0,
	 "weapon_label":"57mm/75mm坦克炮",
	 "atk_l":55,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":247,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":22,"def_a":31,"def_air":19,
	 "w_light":"57mm/75mm坦克炮","w_armor":"57mm/75mm坦克炮","w_air":"14.5mm车载机枪"},

	{"card_id":"ww1_lanchest","display_name":"兰彻斯特装甲车","era":0,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":294,"range_value":3,"deploy_speed":5,"base_speed":100,"power":54,"weapon_type":0,
	 "weapon_label":"37mm/57mm坦克炮",
	 "atk_l":53,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":235,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":21,"def_a":29,"def_air":18,
	 "w_light":"37mm/57mm坦克炮","w_armor":"57mm/75mm坦克炮","w_air":"14.5mm车载机枪"},

	{"card_id":"ww1_arm_ft17","display_name":"FT-17轻型坦克","era":0,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":340,"range_value":3,"deploy_speed":3,"base_speed":60,"power":54,"weapon_type":0,
	 "weapon_label":"57mm/75mm坦克炮",
	 "atk_l":61,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":272,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":24,"def_a":34,"def_air":20,
	 "w_light":"57mm/75mm坦克炮","w_armor":"75mm/76mm坦克炮","w_air":""},

	{"card_id":"ww1_saint","display_name":"圣沙蒙坦克","era":0,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":321,"range_value":4,"deploy_speed":2,"base_speed":50,"power":60,"weapon_type":0,
	 "weapon_label":"37mm/57mm坦克炮",
	 "atk_l":55,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":244,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":22,"def_a":32,"def_air":19,
	 "w_light":"37mm/57mm坦克炮","w_armor":"85mm主炮","w_air":""},

	{"card_id":"ww1_a7v","display_name":"A7V重型坦克","era":0,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":343,"range_value":4,"deploy_speed":2,"base_speed":50,"power":60,"weapon_type":0,
	 "weapon_label":"37mm/57mm坦克炮",
	 "atk_l":58,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":261,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":24,"def_a":34,"def_air":21,
	 "w_light":"37mm/57mm坦克炮","w_armor":"85mm主炮","w_air":""},

	{"card_id":"ww1_mark4","display_name":"马克IV型坦克","era":0,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":300,"range_value":3,"deploy_speed":2,"base_speed":55,"power":58,"weapon_type":0,
	 "weapon_label":"37mm/57mm坦克炮",
	 "atk_l":51,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":228,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":21,"def_a":30,"def_air":18,
	 "w_light":"37mm/57mm坦克炮","w_armor":"75mm/76mm坦克炮","w_air":""},

	{"card_id":"ww1_arty_77mm","display_name":"77mm野战炮","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":124,"range_value":99,"deploy_speed":0,"base_speed":0,"power":28,"weapon_type":1,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":30,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":99,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":6,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":4,"def_a":5,"def_air":2,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":""},

	{"card_id":"ww1_105mm","display_name":"105mm榴弹炮","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":116,"range_value":99,"deploy_speed":0,"base_speed":0,"power":28,"weapon_type":1,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":28,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":93,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":6,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":5,"def_air":2,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":""},

	{"card_id":"ww1_37mm","display_name":"37mm高射炮","era":0,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":139,"range_value":5,"deploy_speed":0,"base_speed":0,"power":28,"weapon_type":0,
	 "weapon_label":"迫击炮/野战炮",
	 "atk_l":33,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":111,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":7,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":4,"def_a":6,"def_air":3,
	 "w_light":"迫击炮/野战炮","w_armor":"迫击炮/野战炮","w_air":"23mm/30mm高射炮"},

	{"card_id":"ww1_inf_cavalry","display_name":"骑兵斥候","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":91,"range_value":1,"deploy_speed":6,"base_speed":120,"power":18,"weapon_type":0,
	 "weapon_label":"骑兵卡宾枪/马刀",
	 "atk_l":27,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":12,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":6,"def_a":3,"def_air":2,
	 "w_light":"骑兵卡宾枪/马刀","w_armor":"","w_air":""},

	{"card_id":"ww1_flame","display_name":"火焰喷射兵","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":100,"range_value":1,"deploy_speed":3,"base_speed":80,"power":22,"weapon_type":0,
	 "weapon_label":"暴风冲锋枪",
	 "atk_l":30,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":14,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":7,"def_a":4,"def_air":2,
	 "w_light":"暴风冲锋枪","w_armor":"73mm/90mm反坦克炮","w_air":""},

	{"card_id":"ww1_sup_engineer","display_name":"工兵班","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":91,"range_value":2,"deploy_speed":3,"base_speed":80,"power":24,"weapon_type":0,
	 "weapon_label":"迫击炮/野战炮",
	 "atk_l":25,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":82,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":5,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":4,"def_air":2,
	 "w_light":"迫击炮/野战炮","w_armor":"迫击炮/野战炮","w_air":""},

	# --- 一战敌方独有单位（enemy_only，玩家只能缴获）---
	{"card_id":"ww1_inf_mp18","display_name":"步兵班·MP18","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":91,"range_value":1,"deploy_speed":4,"base_speed":80,"power":52,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":27,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":12,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":6,"def_a":3,"def_air":2,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},

	{"card_id":"ww1_inf_rifle","display_name":"步兵班·步枪","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":100,"range_value":2,"deploy_speed":3,"base_speed":70,"power":73,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":30,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":14,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":7,"def_a":4,"def_air":2,
	 "w_light":"步枪","w_armor":"","w_air":""},

	{"card_id":"ww1_sup_mg_nest","display_name":"机枪巢","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":109,"range_value":1,"deploy_speed":0,"base_speed":0,"power":60,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":29,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":98,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":6,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":5,"def_air":2,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"ww1_arty_mortar","display_name":"迫击炮组","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":82,"range_value":3,"deploy_speed":0,"base_speed":0,"power":55,"weapon_type":1,
	 "weapon_label":"迫击炮","enemy_only":true,
	 "atk_l":22,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":74,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":4,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":2,"def_a":3,"def_air":1,
	 "w_light":"迫击炮","w_armor":"迫击炮","w_air":""},

	{"card_id":"ww1_inf_storm_e","display_name":"暴风突击队·精锐","era":0,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":150,"range_value":2,"deploy_speed":5,"base_speed":90,"power":85,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":38,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":17,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":11,"def_a":5,"def_air":3,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},

	{"card_id":"ww1_arm_rolls_e","display_name":"装甲车·精锐","era":0,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":214,"range_value":3,"deploy_speed":4,"base_speed":90,"power":150,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":36,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":163,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":15,"def_a":21,"def_air":13,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"ww1_boss_av7","display_name":"圣沙蒙坦克·Boss","era":0,"combat_kind":1,"tier":Tier.BOSS,
	 "base_hp":650,"range_value":4,"deploy_speed":1,"base_speed":40,"power":400,"weapon_type":0,
	 "weapon_label":"75mm主炮","enemy_only":true,
	 "atk_l":131,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":585,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":46,"def_a":65,"def_air":39,
	 "w_light":"75mm主炮","w_armor":"75mm主炮","w_air":"机枪"},

	# --- 一战堡垒 ---
	{"card_id":"ww1_fort_pillbox","display_name":"混凝土机枪碉堡","era":0,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":646,"range_value":5,"deploy_speed":0,"base_speed":0,"power":80,"weapon_type":0,
	 "weapon_label":"150mm要塞炮/88mm防空炮",
	 "atk_l":136,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":465,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":48,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":67,"def_a":67,"def_air":62,
	 "w_light":"150mm要塞炮/88mm防空炮","w_armor":"","w_air":"MG42/双联防空炮"},

	{"card_id":"ww1_fort_artillery","display_name":"要塞炮台","era":0,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":554,"range_value":99,"deploy_speed":0,"base_speed":0,"power":100,"weapon_type":1,
	 "weapon_label":"150mm要塞炮/88mm防空炮",
	 "atk_l":116,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":399,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":42,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":58,"def_a":58,"def_air":53,
	 "w_light":"150mm要塞炮/88mm防空炮","w_armor":"150mm要塞炮/88mm防空炮","w_air":""},

	# --- 一战 D段补充池（enemy_only）---
	{"card_id":"ww1_inf_enfield","display_name":"李-恩菲尔德志愿兵排","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":100,"range_value":3,"deploy_speed":3,"base_speed":75,"power":55,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":30,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":14,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":7,"def_a":4,"def_air":2,
	 "w_light":"步枪","w_armor":"","w_air":""},

	{"card_id":"ww1_arm_rolls_mk2","display_name":"劳斯莱斯 Mk.II 装甲车","era":0,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":325,"range_value":3,"deploy_speed":4,"base_speed":95,"power":120,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":58,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":260,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":23,"def_a":32,"def_air":20,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"ww1_sup_vickers","display_name":"维克斯 .303 机枪阵地","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":109,"range_value":1,"deploy_speed":0,"base_speed":0,"power":58,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":29,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":98,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":6,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":5,"def_air":2,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"ww1_sup_ford_ambulance","display_name":"福特 T 型战地救护车","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":91,"range_value":1,"deploy_speed":4,"base_speed":90,"power":40,"weapon_type":3,
	 "weapon_label":"无","enemy_only":true,
	 "atk_l":25,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":82,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":5,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":4,"def_air":2,
	 "w_light":"无","w_armor":"","w_air":""},

	{"card_id":"ww1_inf_mp18_x","display_name":"MP18 突击队","era":0,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":201,"range_value":2,"deploy_speed":5,"base_speed":85,"power":80,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":54,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":24,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":14,"def_a":7,"def_air":4,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},


	# ══════════════ 二战时代 (era=1) ══════════════
	# --- 玩家卡 ---
	{"card_id":"ww2_thompson","display_name":"汤普森班","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":267,"range_value":2,"deploy_speed":4,"base_speed":85,"power":72,"weapon_type":0,
	 "weapon_label":"冲锋枪/步枪",
	 "atk_l":71,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":32,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":19,"def_a":9,"def_air":6,
	 "w_light":"冲锋枪/步枪","w_armor":"","w_air":""},

	{"card_id":"ww2_garand","display_name":"加兰德班","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":258,"range_value":3,"deploy_speed":3,"base_speed":80,"power":72,"weapon_type":0,
	 "weapon_label":"冲锋枪/步枪",
	 "atk_l":69,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":31,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":18,"def_a":9,"def_air":5,
	 "w_light":"冲锋枪/步枪","w_armor":"","w_air":""},

	{"card_id":"ww2_mp40","display_name":"MP40班","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":250,"range_value":2,"deploy_speed":4,"base_speed":85,"power":72,"weapon_type":0,
	 "weapon_label":"冲锋枪/步枪",
	 "atk_l":67,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":30,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":18,"def_a":9,"def_air":5,
	 "w_light":"冲锋枪/步枪","w_armor":"","w_air":""},

	{"card_id":"ww2_ppsh","display_name":"波波沙班","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":258,"range_value":2,"deploy_speed":4,"base_speed":85,"power":72,"weapon_type":0,
	 "weapon_label":"冲锋枪/步枪",
	 "atk_l":69,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":31,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":18,"def_a":9,"def_air":5,
	 "w_light":"冲锋枪/步枪","w_armor":"","w_air":""},

	{"card_id":"ww2_mg42","display_name":"MG42机枪组","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":233,"range_value":4,"deploy_speed":0,"base_speed":0,"power":108,"weapon_type":0,
	 "weapon_label":"105mm/120mm榴弹炮",
	 "atk_l":56,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":186,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":11,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":7,"def_a":10,"def_air":4,
	 "w_light":"105mm/120mm榴弹炮","w_armor":"","w_air":"20mm/25mm高炮"},

	{"card_id":"ww2_browning","display_name":"勃朗宁机枪组","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":250,"range_value":4,"deploy_speed":0,"base_speed":0,"power":108,"weapon_type":0,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":60,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":200,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":12,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":8,"def_a":10,"def_air":4,
	 "w_light":"81mm/105mm火炮","w_armor":"","w_air":"20mm/25mm高炮"},

	{"card_id":"ww2_inf_panzerschrek","display_name":"铁拳反坦克组","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":233,"range_value":2,"deploy_speed":3,"base_speed":80,"power":78,"weapon_type":0,
	 "weapon_label":"毛瑟G98步枪",
	 "atk_l":62,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":28,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":16,"def_a":8,"def_air":5,
	 "w_light":"毛瑟G98步枪","w_armor":"88mm/105mm反坦克炮","w_air":""},

	{"card_id":"ww2_inf_bazooka","display_name":"巴祖卡组","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":225,"range_value":2,"deploy_speed":3,"base_speed":80,"power":78,"weapon_type":0,
	 "weapon_label":"加兰德M1步枪",
	 "atk_l":60,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":27,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":16,"def_a":8,"def_air":5,
	 "w_light":"加兰德M1步枪","w_armor":"85mm/105mm反坦克炮","w_air":""},

	{"card_id":"ww2_arty_m81","display_name":"81mm迫击炮","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":167,"range_value":99,"deploy_speed":1,"base_speed":0,"power":108,"weapon_type":1,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":40,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":134,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":8,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":5,"def_a":7,"def_air":3,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":""},

	{"card_id":"ww2_m120","display_name":"120mm重迫击炮","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":158,"range_value":99,"deploy_speed":1,"base_speed":0,"power":108,"weapon_type":1,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":38,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":126,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":8,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":5,"def_a":7,"def_air":3,
	 "w_light":"81mm/105mm火炮","w_armor":"81mm/105mm火炮","w_air":""},

	{"card_id":"ww2_pz3","display_name":"三号坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":419,"range_value":3,"deploy_speed":3,"base_speed":70,"power":216,"weapon_type":0,
	 "weapon_label":"75mm/76mm坦克炮",
	 "atk_l":71,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":318,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":29,"def_a":42,"def_air":25,
	 "w_light":"75mm/76mm坦克炮","w_armor":"105mm主炮","w_air":""},

	{"card_id":"ww2_pz4","display_name":"四号坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":450,"range_value":3,"deploy_speed":3,"base_speed":70,"power":216,"weapon_type":0,
	 "weapon_label":"75mm/76mm坦克炮",
	 "atk_l":77,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":342,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":31,"def_a":45,"def_air":27,
	 "w_light":"75mm/76mm坦克炮","w_armor":"105mm/120mm主炮","w_air":""},

	{"card_id":"ww2_panther","display_name":"黑豹坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":503,"range_value":4,"deploy_speed":3,"base_speed":70,"power":216,"weapon_type":0,
	 "weapon_label":"75mm/76mm坦克炮",
	 "atk_l":86,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":382,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":35,"def_a":50,"def_air":30,
	 "w_light":"75mm/76mm坦克炮","w_armor":"105mm/120mm主炮","w_air":""},

	{"card_id":"ww2_arm_tiger","display_name":"虎式坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":576,"range_value":4,"deploy_speed":2,"base_speed":55,"power":216,"weapon_type":0,
	 "weapon_label":"57mm/75mm坦克炮",
	 "atk_l":98,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":438,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":40,"def_a":58,"def_air":35,
	 "w_light":"57mm/75mm坦克炮","w_armor":"122mm主炮","w_air":""},

	{"card_id":"ww2_kingtiger","display_name":"虎王坦克","era":1,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":620,"range_value":4,"deploy_speed":1,"base_speed":45,"power":216,"weapon_type":0,
	 "weapon_label":"57mm/75mm坦克炮",
	 "atk_l":117,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":521,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":43,"def_a":62,"def_air":37,
	 "w_light":"57mm/75mm坦克炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"ww2_t34_76","display_name":"T-34/76坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":430,"range_value":3,"deploy_speed":4,"base_speed":75,"power":216,"weapon_type":0,
	 "weapon_label":"75mm/76mm坦克炮",
	 "atk_l":73,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":327,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":30,"def_a":43,"def_air":26,
	 "w_light":"75mm/76mm坦克炮","w_armor":"105mm/120mm主炮","w_air":""},

	{"card_id":"ww2_t34_85","display_name":"T-34/85坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":471,"range_value":3,"deploy_speed":4,"base_speed":75,"power":216,"weapon_type":0,
	 "weapon_label":"75mm/76mm坦克炮",
	 "atk_l":80,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":358,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":33,"def_a":47,"def_air":28,
	 "w_light":"75mm/76mm坦克炮","w_armor":"105mm/120mm主炮","w_air":""},

	{"card_id":"ww2_is2","display_name":"IS-2重型坦克","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":587,"range_value":4,"deploy_speed":2,"base_speed":50,"power":216,"weapon_type":0,
	 "weapon_label":"57mm/75mm坦克炮",
	 "atk_l":100,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":446,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":41,"def_a":59,"def_air":35,
	 "w_light":"57mm/75mm坦克炮","w_armor":"122mm主炮","w_air":""},

	{"card_id":"ww2_arm_sherman","display_name":"M4谢尔曼","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":409,"range_value":3,"deploy_speed":4,"base_speed":70,"power":216,"weapon_type":0,
	 "weapon_label":"75mm/76mm坦克炮",
	 "atk_l":70,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":311,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":29,"def_a":41,"def_air":25,
	 "w_light":"75mm/76mm坦克炮","w_armor":"105mm主炮","w_air":""},

	{"card_id":"ww2_inf_hellcat","display_name":"M18地狱猫","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":335,"range_value":3,"deploy_speed":5,"base_speed":90,"power":204,"weapon_type":0,
	 "weapon_label":"57mm/75mm坦克炮",
	 "atk_l":57,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":255,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":23,"def_a":34,"def_air":20,
	 "w_light":"57mm/75mm坦克炮","w_armor":"105mm/120mm主炮","w_air":""},

	# --- 二战敌方独有单位（enemy_only）---
	{"card_id":"ww2_inf_thompson","display_name":"步兵班·汤普森","era":1,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":150,"range_value":1,"deploy_speed":4,"base_speed":80,"power":65,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":45,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":20,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":11,"def_a":5,"def_air":3,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},

	{"card_id":"ww2_inf_garand","display_name":"步枪班·加兰德","era":1,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":156,"range_value":2,"deploy_speed":3,"base_speed":75,"power":70,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":47,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":21,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":11,"def_a":5,"def_air":3,
	 "w_light":"步枪","w_armor":"","w_air":""},

	{"card_id":"ww2_sup_mg42","display_name":"MG42机枪组·敌方","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":233,"range_value":1,"deploy_speed":0,"base_speed":0,"power":95,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":56,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":186,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":11,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":7,"def_a":10,"def_air":4,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"ww2_inf_panzerschreck_e","display_name":"反坦克组·精锐","era":1,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":157,"range_value":2,"deploy_speed":3,"base_speed":75,"power":120,"weapon_type":0,
	 "weapon_label":"火箭筒","enemy_only":true,
	 "atk_l":40,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":18,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":11,"def_a":5,"def_air":3,
	 "w_light":"火箭筒","w_armor":"","w_air":""},

	{"card_id":"ww2_inf_para_e","display_name":"伞兵精英","era":1,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":178,"range_value":2,"deploy_speed":4,"base_speed":85,"power":140,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":45,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":20,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":12,"def_a":6,"def_air":4,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},

	{"card_id":"ww2_arm_panther_e","display_name":"黑豹坦克·精锐","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":471,"range_value":3,"deploy_speed":3,"base_speed":70,"power":280,"weapon_type":0,
	 "weapon_label":"75mm坦克炮","enemy_only":true,
	 "atk_l":80,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":358,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":33,"def_a":47,"def_air":28,
	 "w_light":"75mm坦克炮","w_armor":"","w_air":""},

	{"card_id":"ww2_boss_kingtiger","display_name":"虎王坦克·Boss","era":1,"combat_kind":1,"tier":Tier.BOSS,
	 "base_hp":1000,"range_value":4,"deploy_speed":1,"base_speed":40,"power":500,"weapon_type":0,
	 "weapon_label":"88mm主炮","enemy_only":true,
	 "atk_l":201,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":900,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":70,"def_a":100,"def_air":60,
	 "w_light":"88mm主炮","w_armor":"88mm主炮","w_air":"机枪"},

	# --- 二战 D段补充池（enemy_only）---
	{"card_id":"ww2_arm_garand_para","display_name":"M1 加兰德伞兵班","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":258,"range_value":2,"deploy_speed":4,"base_speed":85,"power":100,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":69,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":31,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":18,"def_a":9,"def_air":5,
	 "w_light":"步枪","w_armor":"","w_air":""},

	{"card_id":"ww2_arty_hummel","display_name":"黄蜂 Hummel 自行火炮","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":300,"range_value":99,"deploy_speed":1,"base_speed":50,"power":200,"weapon_type":1,
	 "weapon_label":"150mm榴弹炮","enemy_only":true,
	 "atk_l":72,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":240,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":14,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":9,"def_a":13,"def_air":5,
	 "w_light":"150mm榴弹炮","w_armor":"150mm榴弹炮","w_air":""},

	{"card_id":"ww2_arty_pak40","display_name":"PaK 40 反坦克炮组","era":1,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":267,"range_value":3,"deploy_speed":0,"base_speed":0,"power":180,"weapon_type":0,
	 "weapon_label":"75mm反坦克炮","enemy_only":true,
	 "atk_l":64,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":214,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":13,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":8,"def_a":11,"def_air":5,
	 "w_light":"75mm反坦克炮","w_armor":"","w_air":""},

	{"card_id":"ww2_sup_gmc_truck","display_name":"GMC 2.5t 补给卡车","era":1,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":150,"range_value":1,"deploy_speed":4,"base_speed":90,"power":60,"weapon_type":3,
	 "weapon_label":"无","enemy_only":true,
	 "atk_l":40,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":135,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":8,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":4,"def_a":6,"def_air":3,
	 "w_light":"无","w_armor":"","w_air":""},

	{"card_id":"ww2_inf_kar98k","display_name":"毛瑟 Kar98k 狙击组","era":1,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":233,"range_value":3,"deploy_speed":3,"base_speed":75,"power":110,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":62,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":28,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":16,"def_a":8,"def_air":5,
	 "w_light":"步枪","w_armor":"","w_air":""},

	# --- 二战堡垒 ---
	{"card_id":"ww2_fort_bunker","display_name":"混凝土碉堡","era":1,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":990,"range_value":5,"deploy_speed":0,"base_speed":0,"power":200,"weapon_type":0,
	 "weapon_label":"150mm要塞炮/88mm防空炮",
	 "atk_l":208,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":713,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":74,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":103,"def_a":103,"def_air":95,
	 "w_light":"150mm要塞炮/88mm防空炮","w_armor":"","w_air":"150mm要塞炮/88mm防空炮"},

	{"card_id":"ww2_fort_flak","display_name":"88mm防空塔","era":1,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":810,"range_value":6,"deploy_speed":0,"base_speed":0,"power":220,"weapon_type":0,
	 "weapon_label":"MG42/双联防空炮",
	 "atk_l":170,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":583,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":61,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":84,"def_a":84,"def_air":78,
	 "w_light":"MG42/双联防空炮","w_armor":"MG42/双联防空炮","w_air":"离子炮"},


	# ══════════════ 冷战时代 (era=2) ══════════════
	# --- 玩家卡 ---
	{"card_id":"cold_rpg","display_name":"RPG火箭筒组","era":2,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":288,"range_value":2,"deploy_speed":3,"base_speed":80,"power":204,"weapon_type":0,
	 "weapon_label":"AK-47突击步枪",
	 "atk_l":77,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":35,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":20,"def_a":10,"def_air":6,
	 "w_light":"AK-47突击步枪","w_armor":"RPG-7火箭筒","w_air":""},

	{"card_id":"cold_ak47","display_name":"AK-47步兵班","era":2,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":331,"range_value":2,"deploy_speed":4,"base_speed":85,"power":192,"weapon_type":0,
	 "weapon_label":"AK-47突击步枪",
	 "atk_l":88,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":40,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":23,"def_a":12,"def_air":7,
	 "w_light":"AK-47突击步枪","w_armor":"","w_air":""},

	{"card_id":"cold_m14","display_name":"M14步兵班","era":2,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":324,"range_value":3,"deploy_speed":4,"base_speed":80,"power":192,"weapon_type":0,
	 "weapon_label":"M14步枪",
	 "atk_l":86,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":39,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":23,"def_a":11,"def_air":7,
	 "w_light":"M14步枪","w_armor":"","w_air":""},

	{"card_id":"cold_m60","display_name":"M60机枪班","era":2,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":346,"range_value":4,"deploy_speed":3,"base_speed":75,"power":204,"weapon_type":0,
	 "weapon_label":"M14步枪",
	 "atk_l":92,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":42,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":24,"def_a":12,"def_air":7,
	 "w_light":"M14步枪","w_armor":"","w_air":"12.7mm重机枪"},

	{"card_id":"cold_rpk","display_name":"RPK机枪班","era":2,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":338,"range_value":3,"deploy_speed":3,"base_speed":80,"power":204,"weapon_type":0,
	 "weapon_label":"AK-74突击步枪",
	 "atk_l":90,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":41,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":24,"def_a":12,"def_air":7,
	 "w_light":"AK-74突击步枪","w_armor":"","w_air":"12.7mm重机枪"},

	{"card_id":"cold_inf_btr60","display_name":"BTR-60装甲车","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":525,"range_value":3,"deploy_speed":4,"base_speed":100,"power":576,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":89,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":399,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":37,"def_a":52,"def_air":32,
	 "w_light":"100mm主炮","w_armor":"100mm主炮","w_air":"14.5mm车载机枪"},

	{"card_id":"cold_sup_m113","display_name":"M113装甲车","era":2,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":461,"range_value":2,"deploy_speed":4,"base_speed":90,"power":288,"weapon_type":0,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":111,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":369,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":22,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":14,"def_a":19,"def_air":8,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":"7.62mm/12.7mm高机枪"},

	{"card_id":"cold_inf_bmp1","display_name":"BMP-1步战车","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":572,"range_value":99,"deploy_speed":4,"base_speed":90,"power":576,"weapon_type":1,
	 "weapon_label":"100mm主炮",
	 "atk_l":97,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":435,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":40,"def_a":57,"def_air":34,
	 "w_light":"100mm主炮","w_armor":"122mm主炮","w_air":"14.5mm车载机枪"},

	{"card_id":"cold_bradley","display_name":"M2布雷德利","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":620,"range_value":99,"deploy_speed":4,"base_speed":90,"power":576,"weapon_type":1,
	 "weapon_label":"105mm主炮",
	 "atk_l":105,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":471,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":43,"def_a":62,"def_air":37,
	 "w_light":"105mm主炮","w_armor":"122mm主炮","w_air":"14.5mm车载机枪"},

	{"card_id":"cold_arm_t55","display_name":"T-55坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":668,"range_value":3,"deploy_speed":3,"base_speed":65,"power":576,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":114,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":508,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":47,"def_a":67,"def_air":40,
	 "w_light":"100mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_t62","display_name":"T-62坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":715,"range_value":4,"deploy_speed":3,"base_speed":65,"power":576,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":122,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":543,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":50,"def_a":72,"def_air":43,
	 "w_light":"100mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_t72","display_name":"T-72坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":763,"range_value":4,"deploy_speed":3,"base_speed":65,"power":576,"weapon_type":0,
	 "weapon_label":"85mm主炮",
	 "atk_l":130,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":580,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":53,"def_a":76,"def_air":46,
	 "w_light":"85mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_m60t","display_name":"M60坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":687,"range_value":3,"deploy_speed":3,"base_speed":65,"power":576,"weapon_type":0,
	 "weapon_label":"85mm主炮",
	 "atk_l":117,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":522,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":48,"def_a":69,"def_air":41,
	 "w_light":"85mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_m1","display_name":"M1主战坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":811,"range_value":4,"deploy_speed":3,"base_speed":65,"power":576,"weapon_type":0,
	 "weapon_label":"85mm主炮",
	 "atk_l":138,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":616,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":57,"def_a":81,"def_air":49,
	 "w_light":"85mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_leo1","display_name":"豹1坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":620,"range_value":3,"deploy_speed":4,"base_speed":75,"power":576,"weapon_type":0,
	 "weapon_label":"85mm主炮",
	 "atk_l":105,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":471,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":43,"def_a":62,"def_air":37,
	 "w_light":"85mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_chieftain","display_name":"酋长坦克","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":782,"range_value":4,"deploy_speed":2,"base_speed":55,"power":576,"weapon_type":0,
	 "weapon_label":"85mm主炮",
	 "atk_l":133,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":594,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":55,"def_a":78,"def_air":47,
	 "w_light":"85mm主炮","w_armor":"125mm滑膛炮","w_air":""},

	{"card_id":"cold_sup_zsu23","display_name":"ZSU-23-4自行高炮","era":2,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":504,"range_value":5,"deploy_speed":3,"base_speed":70,"power":288,"weapon_type":0,
	 "weapon_label":"迫击炮/野战炮",
	 "atk_l":121,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":403,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":24,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":15,"def_a":21,"def_air":9,
	 "w_light":"迫击炮/野战炮","w_armor":"迫击炮/野战炮","w_air":"23mm/30mm高射炮"},

	{"card_id":"cold_sam7","display_name":"萨姆-7防空组","era":2,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":245,"range_value":99,"deploy_speed":3,"base_speed":70,"power":198,"weapon_type":1,
	 "weapon_label":"AK-47突击步枪",
	 "atk_l":59,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":196,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":12,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":7,"def_a":10,"def_air":4,
	 "w_light":"AK-47突击步枪","w_armor":"RPG-7火箭筒","w_air":"萨姆-7防空导弹"},

	{"card_id":"cold_mig21","display_name":"米格-21战机","era":2,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":238,"range_value":99,"deploy_speed":6,"base_speed":150,"power":480,"weapon_type":2,
	 "weapon_label":"空空导弹/20mm机炮",
	 "atk_l":54,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":67,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":90,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":9,"def_a":6,"def_air":14,
	 "w_light":"空空导弹/20mm机炮","w_armor":"空空导弹/20mm机炮","w_air":"地狱火导弹/127mm舰炮"},

	{"card_id":"cold_f4","display_name":"F-4鬼怪战机","era":2,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":267,"range_value":99,"deploy_speed":6,"base_speed":150,"power":480,"weapon_type":2,
	 "weapon_label":"空空导弹/20mm机炮",
	 "atk_l":61,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":76,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":101,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":10,"def_a":6,"def_air":16,
	 "w_light":"空空导弹/20mm机炮","w_armor":"空空导弹/20mm机炮","w_air":"地狱火导弹/127mm舰炮"},

	{"card_id":"cold_spetsnaz","display_name":"阿尔法特种部队","era":2,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":238,"range_value":2,"deploy_speed":5,"base_speed":90,"power":216,"weapon_type":0,
	 "weapon_label":"M16A4步枪",
	 "atk_l":60,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":27,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":17,"def_a":8,"def_air":5,
	 "w_light":"M16A4步枪","w_armor":"85mm/105mm主炮","w_air":"便携式防空导弹"},

	# --- 冷战敌方独有单位（enemy_only）---
	{"card_id":"cold_inf_m60","display_name":"美军步兵·M60","era":2,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":210,"range_value":3,"deploy_speed":3,"base_speed":80,"power":85,"weapon_type":0,
	 "weapon_label":"M60机枪","enemy_only":true,
	 "atk_l":63,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":28,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":15,"def_a":7,"def_air":4,
	 "w_light":"M60机枪","w_armor":"","w_air":""},

	{"card_id":"cold_inf_ak","display_name":"苏军步兵","era":2,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":197,"range_value":2,"deploy_speed":4,"base_speed":80,"power":80,"weapon_type":0,
	 "weapon_label":"突击步枪","enemy_only":true,
	 "atk_l":59,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":27,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":14,"def_a":7,"def_air":4,
	 "w_light":"突击步枪","w_armor":"","w_air":""},

	{"card_id":"cold_arm_btr_e","display_name":"BTR装甲车·敌方","era":2,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":403,"range_value":2,"deploy_speed":4,"base_speed":90,"power":200,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":72,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":322,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":28,"def_a":40,"def_air":24,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"cold_air_m113_e","display_name":"M113装甲车·敌方","era":2,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":374,"range_value":2,"deploy_speed":3,"base_speed":85,"power":180,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":67,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":299,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":26,"def_a":37,"def_air":22,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"cold_inf_spetsnaz_e","display_name":"特种部队·精锐","era":2,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":210,"range_value":2,"deploy_speed":5,"base_speed":90,"power":160,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":53,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":24,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":15,"def_a":7,"def_air":4,
	 "w_light":"步枪","w_armor":"","w_air":""},

	{"card_id":"cold_arm_t72_e","display_name":"T-72坦克·精锐","era":2,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":477,"range_value":3,"deploy_speed":3,"base_speed":65,"power":400,"weapon_type":0,
	 "weapon_label":"125mm滑膛炮","enemy_only":true,
	 "atk_l":81,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":363,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":33,"def_a":48,"def_air":29,
	 "w_light":"125mm滑膛炮","w_armor":"","w_air":""},

	{"card_id":"cold_boss_mig","display_name":"米格-29·Boss","era":2,"combat_kind":3,"tier":Tier.BOSS,
	 "base_hp":1400,"range_value":99,"deploy_speed":5,"base_speed":160,"power":450,"weapon_type":2,
	 "weapon_label":"空空导弹","enemy_only":true,
	 "atk_l":380,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":470,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":630,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":50,"def_a":34,"def_air":84,
	 "w_light":"空空导弹","w_armor":"机炮","w_air":"空空导弹"},

	# --- 冷战 D段补充池（enemy_only）---
	{"card_id":"cold_arty_bmd1","display_name":"BMD-1 空降战车","era":2,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":432,"range_value":99,"deploy_speed":3,"base_speed":80,"power":250,"weapon_type":1,
	 "weapon_label":"73mm低压滑膛炮","enemy_only":true,
	 "atk_l":104,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":346,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":21,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":13,"def_a":18,"def_air":8,
	 "w_light":"73mm低压滑膛炮","w_armor":"","w_air":""},

	{"card_id":"cold_sup_bmp1_x","display_name":"BMP-1 步兵战车·改","era":2,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":605,"range_value":99,"deploy_speed":4,"base_speed":85,"power":300,"weapon_type":1,
	 "weapon_label":"73mm炮","enemy_only":true,
	 "atk_l":108,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":484,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":42,"def_a":60,"def_air":36,
	 "w_light":"73mm炮","w_armor":"","w_air":""},

	{"card_id":"cold_inf_metis","display_name":"9K111 法特导弹组","era":2,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":259,"range_value":3,"deploy_speed":3,"base_speed":70,"power":180,"weapon_type":0,
	 "weapon_label":"反坦克导弹","enemy_only":true,
	 "atk_l":69,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":31,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":18,"def_a":9,"def_air":5,
	 "w_light":"反坦克导弹","w_armor":"","w_air":""},

	{"card_id":"cold_arm_p18","display_name":"P-18 雷达警戒车","era":2,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":289,"range_value":99,"deploy_speed":3,"base_speed":80,"power":120,"weapon_type":3,
	 "weapon_label":"无","enemy_only":true,
	 "atk_l":78,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":260,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":16,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":9,"def_a":12,"def_air":5,
	 "w_light":"无","w_armor":"","w_air":""},

	{"card_id":"cold_arty_brem1","display_name":"BREM-1 装甲抢修车","era":2,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":648,"range_value":2,"deploy_speed":2,"base_speed":60,"power":280,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":116,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":518,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":45,"def_a":65,"def_air":39,
	 "w_light":"机枪","w_armor":"","w_air":""},

	# --- 冷战堡垒 ---
	{"card_id":"cold_fort_missile","display_name":"导弹发射井","era":2,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":1477,"range_value":99,"deploy_speed":0,"base_speed":0,"power":500,"weapon_type":1,
	 "weapon_label":"多管近防炮/88mm防空炮",
	 "atk_l":310,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":1063,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":111,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":154,"def_a":154,"def_air":142,
	 "w_light":"多管近防炮/88mm防空炮","w_armor":"离子炮","w_air":"多管近防炮/88mm防空炮"},

	{"card_id":"cold_fort_radar","display_name":"雷达站","era":2,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":1023,"range_value":99,"deploy_speed":0,"base_speed":0,"power":300,"weapon_type":3,
	 "weapon_label":"无",
	 "atk_l":215,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":737,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":77,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":106,"def_a":106,"def_air":98,
	 "w_light":"","w_armor":"","w_air":""},


	# ══════════════ 现代时代 (era=3) ══════════════
	# --- 玩家卡 ---
	{"card_id":"mod_marine","display_name":"海军陆战队","era":3,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":800,"range_value":2,"deploy_speed":4,"base_speed":90,"power":384,"weapon_type":0,
	 "weapon_label":"M4卡宾枪/SCAR-H",
	 "atk_l":203,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":91,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":56,"def_a":28,"def_air":17,
	 "w_light":"M4卡宾枪/SCAR-H","w_armor":"","w_air":""},

	{"card_id":"mod_ranger","display_name":"游骑兵","era":3,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":850,"range_value":2,"deploy_speed":5,"base_speed":95,"power":408,"weapon_type":0,
	 "weapon_label":"M4卡宾枪/SCAR-H",
	 "atk_l":215,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":97,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":60,"def_a":30,"def_air":18,
	 "w_light":"M4卡宾枪/SCAR-H","w_armor":"火箭筒/轻型装甲武器","w_air":"便携式防空导弹"},

	{"card_id":"mod_javelin","display_name":"标枪导弹兵","era":3,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":600,"range_value":99,"deploy_speed":3,"base_speed":80,"power":396,"weapon_type":1,
	 "weapon_label":"M4卡宾枪",
	 "atk_l":152,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":68,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":42,"def_a":21,"def_air":13,
	 "w_light":"M4卡宾枪","w_armor":"标枪反坦克导弹","w_air":"便携式防空导弹"},

	{"card_id":"mod_stinger","display_name":"毒刺导弹兵","era":3,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":407,"range_value":99,"deploy_speed":3,"base_speed":80,"power":384,"weapon_type":1,
	 "weapon_label":"M4卡宾枪",
	 "atk_l":98,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":326,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":20,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":12,"def_a":17,"def_air":7,
	 "w_light":"M4卡宾枪","w_armor":"M4卡宾枪","w_air":"毒刺防空导弹"},

	{"card_id":"mod_inf_technical","display_name":"武装皮卡","era":3,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":500,"range_value":3,"deploy_speed":5,"base_speed":110,"power":336,"weapon_type":0,
	 "weapon_label":"AK-47突击步枪",
	 "atk_l":133,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":60,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":35,"def_a":18,"def_air":10,
	 "w_light":"AK-47突击步枪","w_armor":"RPG-7火箭筒","w_air":"便携式防空导弹"},

	{"card_id":"mod_stryker_mgs","display_name":"斯特赖克MGS","era":3,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":2250,"range_value":4,"deploy_speed":4,"base_speed":80,"power":1080,"weapon_type":0,
	 "weapon_label":"105mm主炮",
	 "atk_l":383,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1710,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":158,"def_a":225,"def_air":135,
	 "w_light":"105mm主炮","w_armor":"120mm/125mm主炮","w_air":""},

	{"card_id":"mod_stryker_m2","display_name":"斯特赖克M2","era":3,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":2125,"range_value":3,"deploy_speed":4,"base_speed":85,"power":1056,"weapon_type":0,
	 "weapon_label":"105mm/120mm主炮",
	 "atk_l":362,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1615,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":149,"def_a":212,"def_air":128,
	 "w_light":"105mm/120mm主炮","w_armor":"122mm主炮","w_air":"20mm机炮"},

	{"card_id":"mod_hummer_tow","display_name":"悍马·陶式","era":3,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":481,"range_value":99,"deploy_speed":5,"base_speed":110,"power":396,"weapon_type":1,
	 "weapon_label":"M4卡宾枪",
	 "atk_l":128,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":58,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":34,"def_a":17,"def_air":10,
	 "w_light":"M4卡宾枪","w_armor":"陶式反坦克导弹","w_air":"便携式防空导弹"},

	{"card_id":"mod_hummer_m2","display_name":"悍马·M2","era":3,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":519,"range_value":3,"deploy_speed":5,"base_speed":110,"power":360,"weapon_type":0,
	 "weapon_label":"M4卡宾枪",
	 "atk_l":138,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":62,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":36,"def_a":18,"def_air":11,
	 "w_light":"M4卡宾枪","w_armor":"M4卡宾枪","w_air":"12.7mm重机枪"},

	{"card_id":"mod_arm_m1a1","display_name":"M1A1坦克","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1086,"range_value":4,"deploy_speed":3,"base_speed":70,"power":1140,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":204,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":912,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":76,"def_a":109,"def_air":65,
	 "w_light":"100mm主炮","w_armor":"120mm主炮","w_air":""},

	{"card_id":"mod_m1a2","display_name":"M1A2艾布拉姆斯","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1185,"range_value":4,"deploy_speed":3,"base_speed":70,"power":1152,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":223,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":995,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":83,"def_a":118,"def_air":71,
	 "w_light":"100mm主炮","w_armor":"120mm L55主炮","w_air":""},

	{"card_id":"mod_arm_m1a2sep","display_name":"M1A2 SEP","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1234,"range_value":4,"deploy_speed":3,"base_speed":70,"power":1152,"weapon_type":0,
	 "weapon_label":"105mm主炮",
	 "atk_l":232,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1037,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":86,"def_a":123,"def_air":74,
	 "w_light":"105mm主炮","w_armor":"双联装电磁炮","w_air":""},

	{"card_id":"mod_t90","display_name":"T-90坦克","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1135,"range_value":4,"deploy_speed":3,"base_speed":70,"power":1140,"weapon_type":0,
	 "weapon_label":"105mm主炮",
	 "atk_l":213,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":953,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":79,"def_a":114,"def_air":68,
	 "w_light":"105mm主炮","w_armor":"120mm主炮","w_air":""},

	{"card_id":"mod_leo2a6","display_name":"豹2A6坦克","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1165,"range_value":4,"deploy_speed":3,"base_speed":70,"power":1152,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":219,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":979,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":82,"def_a":116,"def_air":70,
	 "w_light":"100mm主炮","w_armor":"120mm L55主炮","w_air":""},

	{"card_id":"mod_challenger2","display_name":"挑战者2坦克","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1283,"range_value":4,"deploy_speed":2,"base_speed":60,"power":1140,"weapon_type":0,
	 "weapon_label":"100mm主炮",
	 "atk_l":241,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1078,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":90,"def_a":128,"def_air":77,
	 "w_light":"100mm主炮","w_armor":"120mm主炮","w_air":""},

	{"card_id":"mod_ah64","display_name":"AH-64阿帕奇","era":3,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":950,"range_value":99,"deploy_speed":5,"base_speed":130,"power":960,"weapon_type":2,
	 "weapon_label":"地狱火导弹/127mm舰炮",
	 "atk_l":217,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":269,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":361,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":34,"def_a":23,"def_air":57,
	 "w_light":"地狱火导弹/127mm舰炮","w_armor":"地狱火导弹/127mm舰炮","w_air":"空空导弹/20mm机炮"},

	{"card_id":"mod_ah1","display_name":"AH-1眼镜蛇","era":3,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":875,"range_value":99,"deploy_speed":5,"base_speed":130,"power":936,"weapon_type":2,
	 "weapon_label":"地狱火导弹/127mm舰炮",
	 "atk_l":200,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":248,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":332,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":32,"def_a":21,"def_air":52,
	 "w_light":"地狱火导弹/127mm舰炮","w_armor":"地狱火导弹/127mm舰炮","w_air":"空空导弹/20mm机炮"},

	{"card_id":"mod_uh60","display_name":"UH-60黑鹰","era":3,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":593,"range_value":99,"deploy_speed":5,"base_speed":130,"power":840,"weapon_type":2,
	 "weapon_label":"7.62mm舱门机枪/轻型机炮",
	 "atk_l":143,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":177,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":237,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":21,"def_a":14,"def_air":36,
	 "w_light":"7.62mm舱门机枪/轻型机炮","w_armor":"7.62mm舱门机枪/轻型机炮","w_air":"7.62mm舱门机枪/轻型机炮"},

	{"card_id":"mod_arty_m270","display_name":"M270火箭炮","era":3,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":900,"range_value":99,"deploy_speed":1,"base_speed":50,"power":576,"weapon_type":1,
	 "weapon_label":"227mm火箭炮",
	 "atk_l":205,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":684,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":41,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":27,"def_a":38,"def_air":16,
	 "w_light":"227mm火箭炮","w_armor":"105mm/120mm榴弹炮","w_air":""},

	{"card_id":"mod_sup_m6","display_name":"自行高炮M6","era":3,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":741,"range_value":5,"deploy_speed":3,"base_speed":70,"power":576,"weapon_type":0,
	 "weapon_label":"81mm/105mm火炮",
	 "atk_l":178,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":593,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":36,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":22,"def_a":31,"def_air":13,
	 "w_light":"81mm/105mm火炮","w_armor":"迫击炮/野战炮","w_air":"25mm近防炮"},

	{"card_id":"mod_inf_scout_drone","display_name":"侦察无人机","era":3,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":333,"range_value":99,"deploy_speed":7,"base_speed":140,"power":1100,"weapon_type":2,
	 "weapon_label":"7.62mm舱门机枪/轻型机炮",
	 "atk_l":80,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":99,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":133,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":12,"def_a":8,"def_air":20,
	 "w_light":"7.62mm舱门机枪/轻型机炮","w_armor":"7.62mm舱门机枪/轻型机炮","w_air":"7.62mm舱门机枪/轻型机炮"},

	# --- 现代敌方独有单位（enemy_only）---
	{"card_id":"mod_inf_marine","display_name":"海军陆战队·敌方","era":3,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":463,"range_value":2,"deploy_speed":4,"base_speed":90,"power":180,"weapon_type":0,
	 "weapon_label":"M4卡宾枪","enemy_only":true,
	 "atk_l":123,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":56,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":32,"def_a":16,"def_air":10,
	 "w_light":"M4卡宾枪","w_armor":"","w_air":""},

	{"card_id":"mod_air_technical_e","display_name":"皮卡武装·敌方","era":3,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":280,"range_value":2,"deploy_speed":5,"base_speed":110,"power":120,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":84,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":38,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":20,"def_a":10,"def_air":6,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"mod_arm_stryker_e","display_name":"斯特赖克装甲车·敌方","era":3,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":648,"range_value":2,"deploy_speed":4,"base_speed":85,"power":250,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":116,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":518,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":45,"def_a":65,"def_air":39,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"mod_arty_mlrs_e","display_name":"火箭炮车·敌方","era":3,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":463,"range_value":99,"deploy_speed":1,"base_speed":50,"power":220,"weapon_type":1,
	 "weapon_label":"火箭炮","enemy_only":true,
	 "atk_l":111,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":370,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":22,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":14,"def_a":19,"def_air":8,
	 "w_light":"火箭炮","w_armor":"火箭炮","w_air":""},

	{"card_id":"mod_inf_delta_e","display_name":"三角洲部队·精锐","era":3,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":750,"range_value":2,"deploy_speed":5,"base_speed":95,"power":250,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":190,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":86,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":53,"def_a":26,"def_air":16,
	 "w_light":"步枪","w_armor":"","w_air":""},

	{"card_id":"mod_arm_abrams_e","display_name":"M1A2坦克·精锐","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":592,"range_value":3,"deploy_speed":3,"base_speed":70,"power":500,"weapon_type":0,
	 "weapon_label":"120mm主炮","enemy_only":true,
	 "atk_l":111,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":497,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":41,"def_a":59,"def_air":36,
	 "w_light":"120mm主炮","w_armor":"","w_air":""},

	{"card_id":"mod_air_apache_e","display_name":"阿帕奇直升机·精锐","era":3,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":950,"range_value":99,"deploy_speed":5,"base_speed":130,"power":350,"weapon_type":2,
	 "weapon_label":"地狱火导弹","enemy_only":true,
	 "atk_l":217,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":269,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":361,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":34,"def_a":23,"def_air":57,
	 "w_light":"地狱火导弹","w_armor":"","w_air":"空空导弹"},

	{"card_id":"mod_boss_command","display_name":"指挥中枢·Boss","era":3,"combat_kind":4,"tier":Tier.BOSS,
	 "base_hp":1800,"range_value":6,"deploy_speed":0,"base_speed":0,"power":600,"weapon_type":0,
	 "weapon_label":"指挥系统","enemy_only":true,
	 "atk_l":567,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":1944,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":202,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":187,"def_a":187,"def_air":173,
	 "w_light":"指挥系统","w_armor":"指挥系统","w_air":"防空导弹"},

	# --- 现代 D段补充池（enemy_only）---
	{"card_id":"mod_sup_m4_carbine","display_name":"M4 卡宾特遣班","era":3,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":556,"range_value":2,"deploy_speed":5,"base_speed":95,"power":280,"weapon_type":0,
	 "weapon_label":"卡宾枪","enemy_only":true,
	 "atk_l":148,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":67,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":39,"def_a":19,"def_air":12,
	 "w_light":"卡宾枪","w_armor":"","w_air":""},

	{"card_id":"mod_inf_patriot","display_name":"爱国者 PAC-3 发射车","era":3,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":1000,"range_value":99,"deploy_speed":1,"base_speed":50,"power":350,"weapon_type":1,
	 "weapon_label":"防空导弹","enemy_only":true,
	 "atk_l":228,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":760,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":46,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":30,"def_a":42,"def_air":18,
	 "w_light":"防空导弹","w_armor":"","w_air":"防空导弹"},

	{"card_id":"mod_arm_himars","display_name":"HIMARS 火箭炮组","era":3,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":800,"range_value":99,"deploy_speed":2,"base_speed":70,"power":320,"weapon_type":1,
	 "weapon_label":"227mm火箭炮","enemy_only":true,
	 "atk_l":182,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":608,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":36,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":24,"def_a":34,"def_air":14,
	 "w_light":"227mm火箭炮","w_armor":"227mm火箭炮","w_air":""},

	{"card_id":"mod_arty_rq7","display_name":"RQ-7 影子无人机班","era":3,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":370,"range_value":99,"deploy_speed":6,"base_speed":140,"power":220,"weapon_type":2,
	 "weapon_label":"无人机","enemy_only":true,
	 "atk_l":89,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":110,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":148,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":13,"def_a":9,"def_air":22,
	 "w_light":"无人机","w_armor":"","w_air":""},

	{"card_id":"mod_sup_growler","display_name":"EA-18G 电子战小组","era":3,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":519,"range_value":99,"deploy_speed":4,"base_speed":90,"power":240,"weapon_type":3,
	 "weapon_label":"电子战系统","enemy_only":true,
	 "atk_l":125,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":415,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":25,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":16,"def_a":22,"def_air":9,
	 "w_light":"电子战系统","w_armor":"","w_air":""},

	# --- 现代特殊精英（B段，enemy_only）---
	{"card_id":"mod_arm_abrams_mk2","display_name":"艾布拉姆斯Mk.II","era":3,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":691,"range_value":3,"deploy_speed":3,"base_speed":70,"power":769,"weapon_type":0,
	 "weapon_label":"轨道炮","enemy_only":true,
	 "atk_l":130,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":580,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":48,"def_a":69,"def_air":41,
	 "w_light":"轨道炮","w_armor":"","w_air":""},

	# --- 现代堡垒 ---
	{"card_id":"mod_fort_citadel","display_name":"要塞核心","era":3,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":2267,"range_value":6,"deploy_speed":0,"base_speed":0,"power":800,"weapon_type":0,
	 "weapon_label":"多管近防炮/88mm防空炮",
	 "atk_l":476,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":1632,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":170,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":236,"def_a":236,"def_air":218,
	 "w_light":"多管近防炮/88mm防空炮","w_armor":"多管近防炮/88mm防空炮","w_air":"150mm要塞炮/88mm防空炮"},

	{"card_id":"mod_fort_phalanx","display_name":"近防炮系统","era":3,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":1133,"range_value":5,"deploy_speed":0,"base_speed":0,"power":600,"weapon_type":0,
	 "weapon_label":"150mm要塞炮/88mm防空炮",
	 "atk_l":238,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":816,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":85,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":118,"def_a":118,"def_air":109,
	 "w_light":"150mm要塞炮/88mm防空炮","w_armor":"MG42/双联防空炮","w_air":"离子炮阵列"},


	# ══════════════ 近未来时代 (era=4) ══════════════
	# --- 玩家卡 ---
	{"card_id":"fut_swarm","display_name":"蜂群无人机","era":4,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":640,"range_value":99,"deploy_speed":6,"base_speed":150,"power":1325,"weapon_type":2,
	 "weapon_label":"空空导弹/20mm机炮",
	 "atk_l":154,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":191,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":256,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":23,"def_a":15,"def_air":38,
	 "w_light":"空空导弹/20mm机炮","w_armor":"空空导弹/20mm机炮","w_air":"空空导弹/20mm机炮"},

	{"card_id":"fut_attack_drone","display_name":"攻击无人机","era":4,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":1000,"range_value":99,"deploy_speed":6,"base_speed":150,"power":1300,"weapon_type":2,
	 "weapon_label":"地狱火导弹/127mm舰炮",
	 "atk_l":229,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":284,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":380,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":36,"def_a":24,"def_air":60,
	 "w_light":"地狱火导弹/127mm舰炮","w_armor":"地狱火导弹/127mm舰炮","w_air":"空空导弹/20mm机炮"},

	{"card_id":"fut_cyborg","display_name":"机械步兵","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":1125,"range_value":3,"deploy_speed":4,"base_speed":95,"power":500,"weapon_type":0,
	 "weapon_label":"植入式自动步枪/重型粒子炮",
	 "atk_l":285,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":128,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":79,"def_a":39,"def_air":24,
	 "w_light":"植入式自动步枪/重型粒子炮","w_armor":"","w_air":""},

	{"card_id":"fut_heavy_trooper","display_name":"重装机兵","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":1200,"range_value":3,"deploy_speed":3,"base_speed":85,"power":520,"weapon_type":0,
	 "weapon_label":"植入式自动步枪/重型粒子炮",
	 "atk_l":304,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":137,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":84,"def_a":42,"def_air":25,
	 "w_light":"植入式自动步枪/重型粒子炮","w_armor":"电磁炮","w_air":"便携式防空导弹"},

	{"card_id":"fut_inf_scout_mech","display_name":"侦察机甲","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":1050,"range_value":3,"deploy_speed":5,"base_speed":100,"power":500,"weapon_type":0,
	 "weapon_label":"粒子束步枪",
	 "atk_l":266,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":120,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":74,"def_a":37,"def_air":22,
	 "w_light":"粒子束步枪","w_armor":"电磁炮","w_air":"点防御激光"},

	{"card_id":"fut_assault_mech","display_name":"突击机甲","era":4,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1829,"range_value":4,"deploy_speed":4,"base_speed":75,"power":1500,"weapon_type":0,
	 "weapon_label":"122mm主炮",
	 "atk_l":344,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1536,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":128,"def_a":183,"def_air":110,
	 "w_light":"122mm主炮","w_armor":"双联装电磁炮","w_air":"20mm机炮"},

	{"card_id":"fut_arm_heavy_mech","display_name":"重装机甲","era":4,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":2220,"range_value":4,"deploy_speed":2,"base_speed":55,"power":1580,"weapon_type":0,
	 "weapon_label":"105mm主炮",
	 "atk_l":417,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1865,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":155,"def_a":222,"def_air":133,
	 "w_light":"105mm主炮","w_armor":"重型等离子加农炮","w_air":"20mm机炮"},

	{"card_id":"fut_arm_hovertank","display_name":"悬浮坦克","era":4,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1698,"range_value":4,"deploy_speed":5,"base_speed":110,"power":1500,"weapon_type":0,
	 "weapon_label":"105mm/120mm主炮",
	 "atk_l":319,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1426,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":119,"def_a":170,"def_air":102,
	 "w_light":"105mm/120mm主炮","w_armor":"重型等离子加农炮","w_air":"20mm机炮"},

	{"card_id":"fut_howitzer","display_name":"悬浮自行火炮","era":4,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":875,"range_value":99,"deploy_speed":4,"base_speed":80,"power":795,"weapon_type":1,
	 "weapon_label":"电磁轨道炮",
	 "atk_l":200,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":665,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":40,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":26,"def_a":37,"def_air":16,
	 "w_light":"电磁轨道炮","w_armor":"电磁轨道炮","w_air":""},

	{"card_id":"fut_arm_prism","display_name":"光棱坦克","era":4,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1502,"range_value":5,"deploy_speed":3,"base_speed":80,"power":1550,"weapon_type":0,
	 "weapon_label":"125mm滑膛炮",
	 "atk_l":282,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":1262,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":105,"def_a":150,"def_air":90,
	 "w_light":"125mm滑膛炮","w_armor":"双联装电磁炮","w_air":"25mm M242大毒蛇"},

	{"card_id":"fut_aa_hover","display_name":"防空悬浮车","era":4,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":950,"range_value":5,"deploy_speed":5,"base_speed":110,"power":780,"weapon_type":0,
	 "weapon_label":"迫击炮/野战炮",
	 "atk_l":217,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":722,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":43,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":28,"def_a":40,"def_air":17,
	 "w_light":"迫击炮/野战炮","w_armor":"迫击炮/野战炮","w_air":"点防御激光"},

	{"card_id":"fut_stealth_bomber","display_name":"隐形轰炸机","era":4,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":1050,"range_value":99,"deploy_speed":6,"base_speed":150,"power":1400,"weapon_type":2,
	 "weapon_label":"轨道炮/激光",
	 "atk_l":240,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":298,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":399,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":38,"def_a":25,"def_air":63,
	 "w_light":"轨道炮/激光","w_armor":"轨道炮/激光","w_air":"7.62mm舱门机枪/轻型机炮"},

	{"card_id":"fut_space_fighter","display_name":"空天战斗机","era":4,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":1175,"range_value":99,"deploy_speed":7,"base_speed":160,"power":1325,"weapon_type":2,
	 "weapon_label":"地狱火导弹/127mm舰炮",
	 "atk_l":269,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":333,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":446,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":42,"def_a":28,"def_air":70,
	 "w_light":"地狱火导弹/127mm舰炮","w_armor":"空空导弹/20mm机炮","w_air":"轨道炮/激光"},

	{"card_id":"fut_spectre","display_name":"幽灵特工","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":950,"range_value":3,"deploy_speed":5,"base_speed":100,"power":530,"weapon_type":0,
	 "weapon_label":"植入式自动步枪/重型粒子炮",
	 "atk_l":241,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":108,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":66,"def_a":33,"def_air":20,
	 "w_light":"植入式自动步枪/重型粒子炮","w_armor":"85mm/105mm主炮","w_air":"12.7mm重机枪"},

	{"card_id":"fut_nano_drone","display_name":"纳米修复机","era":4,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":440,"range_value":99,"deploy_speed":5,"base_speed":120,"power":1000,"weapon_type":3,
	 "weapon_label":"",
	 "atk_l":106,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":131,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":176,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":16,"def_a":11,"def_air":26,
	 "w_light":"","w_armor":"","w_air":""},

	{"card_id":"fut_shield","display_name":"力场发生器","era":4,"combat_kind":2,"tier":Tier.FORT,
	 "base_hp":600,"range_value":0,"deploy_speed":0,"base_speed":0,"power":750,"weapon_type":3,
	 "weapon_label":"",
	 "atk_l":108,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":360,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":22,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":18,"def_a":25,"def_air":11,
	 "w_light":"","w_armor":"","w_air":""},

	{"card_id":"fut_colossus","display_name":"巨神机甲","era":4,"combat_kind":1,"tier":Tier.ULTIMATE,
	 "base_hp":3000,"range_value":5,"deploy_speed":1,"base_speed":50,"power":1590,"weapon_type":0,
	 "weapon_label":"105mm/120mm主炮",
	 "atk_l":470,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":2100,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":210,"def_a":300,"def_air":180,
	 "w_light":"105mm/120mm主炮","w_armor":"攻城电磁炮","w_air":"25mm M242大毒蛇"},

	{"card_id":"fut_stormcore","display_name":"风暴核心原型","era":4,"combat_kind":2,"tier":Tier.ULTIMATE,
	 "base_hp":1105,"range_value":99,"deploy_speed":0,"base_speed":0,"power":800,"weapon_type":1,
	 "weapon_label":"电磁轨道炮",
	 "atk_l":232,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":774,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":46,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":33,"def_a":46,"def_air":20,
	 "w_light":"电磁轨道炮","w_armor":"电磁轨道炮","w_air":"25mm近防炮"},

	{"card_id":"fut_arm_nexus","display_name":"虚空领主","era":4,"combat_kind":1,"tier":Tier.ULTIMATE,
	 "base_hp":3158,"range_value":99,"deploy_speed":2,"base_speed":60,"power":1590,"weapon_type":0,
	 "weapon_label":"125mm滑膛炮",
	 "atk_l":495,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":2211,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":221,"def_a":316,"def_air":189,
	 "w_light":"125mm滑膛炮","w_armor":"重型等离子加农炮","w_air":"40mm榴弹"},

	{"card_id":"fut_arm_omega","display_name":"全装型机动舱","era":4,"combat_kind":1,"tier":Tier.ULTIMATE,
	 "base_hp":3000,"range_value":5,"deploy_speed":1,"base_speed":50,"power":1590,"weapon_type":0,
	 "weapon_label":"105mm/120mm主炮",
	 "atk_l":470,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":2100,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":210,"def_a":300,"def_air":180,
	 "w_light":"105mm/120mm主炮","w_armor":"攻城电磁炮","w_air":"25mm M242大毒蛇"},

	# --- 近未来敌方独有单位（enemy_only）---
	{"card_id":"fut_inf_cyborg","display_name":"机械步兵·敌方","era":4,"combat_kind":0,"tier":Tier.VETERAN,
	 "base_hp":640,"range_value":2,"deploy_speed":4,"base_speed":95,"power":280,"weapon_type":0,
	 "weapon_label":"粒子束步枪","enemy_only":true,
	 "atk_l":171,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":77,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":45,"def_a":22,"def_air":13,
	 "w_light":"粒子束步枪","w_armor":"","w_air":""},

	{"card_id":"fut_air_drone","display_name":"无人机群","era":4,"combat_kind":3,"tier":Tier.GRUNT,
	 "base_hp":324,"range_value":99,"deploy_speed":6,"base_speed":150,"power":90,"weapon_type":2,
	 "weapon_label":"无人机","enemy_only":true,
	 "atk_l":88,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":109,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":146,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":12,"def_a":8,"def_air":19,
	 "w_light":"无人机","w_armor":"","w_air":""},

	{"card_id":"fut_arm_mech_e","display_name":"机甲步兵·敌方","era":4,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":700,"range_value":2,"deploy_speed":3,"base_speed":80,"power":300,"weapon_type":0,
	 "weapon_label":"粒子炮","enemy_only":true,
	 "atk_l":125,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":560,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":49,"def_a":70,"def_air":42,
	 "w_light":"粒子炮","w_armor":"","w_air":""},

	{"card_id":"fut_arm_hovertank_e","display_name":"悬浮坦克·精锐","era":4,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":1250,"range_value":3,"deploy_speed":4,"base_speed":100,"power":450,"weapon_type":0,
	 "weapon_label":"等离子炮","enemy_only":true,
	 "atk_l":213,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":950,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":88,"def_a":125,"def_air":75,
	 "w_light":"等离子炮","w_armor":"","w_air":""},

	{"card_id":"fut_inf_spectre_e","display_name":"幽灵特工·精锐","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":800,"range_value":2,"deploy_speed":5,"base_speed":100,"power":280,"weapon_type":0,
	 "weapon_label":"粒子束步枪","enemy_only":true,
	 "atk_l":203,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":91,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":56,"def_a":28,"def_air":17,
	 "w_light":"粒子束步枪","w_armor":"","w_air":""},

	{"card_id":"fut_arm_colossus_e","display_name":"巨神机甲·精锐","era":4,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":1045,"range_value":4,"deploy_speed":1,"base_speed":50,"power":600,"weapon_type":0,
	 "weapon_label":"攻城电磁炮","enemy_only":true,
	 "atk_l":197,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":878,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":73,"def_a":104,"def_air":63,
	 "w_light":"攻城电磁炮","w_armor":"","w_air":""},

	{"card_id":"fut_boss_nexus","display_name":"风暴核心·Boss","era":4,"combat_kind":1,"tier":Tier.BOSS,
	 "base_hp":2500,"range_value":99,"deploy_speed":1,"base_speed":50,"power":800,"weapon_type":0,
	 "weapon_label":"重型等离子加农炮","enemy_only":true,
	 "atk_l":504,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":2250,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":175,"def_a":250,"def_air":150,
	 "w_light":"重型等离子加农炮","w_armor":"重型等离子加农炮","w_air":"40mm榴弹"},

	# --- 近未来特殊精英（B段，enemy_only）---
	{"card_id":"fut_sup_bulwark","display_name":"壁垒","era":4,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":1500,"range_value":1,"deploy_speed":0,"base_speed":0,"power":181,"weapon_type":0,
	 "weapon_label":"霰弹枪","enemy_only":true,
	 "atk_l":342,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":1140,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":68,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":45,"def_a":63,"def_air":27,
	 "w_light":"霰弹枪","w_armor":"","w_air":""},

	{"card_id":"fut_arm_titan_mk2","display_name":"泰坦Mk.II","era":4,"combat_kind":1,"tier":Tier.CHAMPION,
	 "base_hp":914,"range_value":2,"deploy_speed":2,"base_speed":65,"power":202,"weapon_type":1,
	 "weapon_label":"导弹","enemy_only":true,
	 "atk_l":172,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":768,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":64,"def_a":91,"def_air":55,
	 "w_light":"导弹","w_armor":"","w_air":""},

	{"card_id":"fut_inf_storm_rider","display_name":"暴风骑士","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":750,"range_value":2,"deploy_speed":5,"base_speed":120,"power":125,"weapon_type":0,
	 "weapon_label":"狙击枪","enemy_only":true,
	 "atk_l":190,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":86,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":53,"def_a":26,"def_air":16,
	 "w_light":"狙击枪","w_armor":"","w_air":""},

	{"card_id":"fut_air_heavy_carrier","display_name":"重装母舰","era":4,"combat_kind":3,"tier":Tier.ELITE,
	 "base_hp":1250,"range_value":2,"deploy_speed":2,"base_speed":100,"power":92,"weapon_type":2,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":286,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":354,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":475,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":45,"def_a":30,"def_air":75,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"fut_air_regen_frame","display_name":"再生骨架","era":4,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":700,"range_value":1,"deploy_speed":3,"base_speed":120,"power":79,"weapon_type":2,
	 "weapon_label":"手枪","enemy_only":true,
	 "atk_l":169,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":209,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":280,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":25,"def_a":17,"def_air":42,
	 "w_light":"手枪","w_armor":"","w_air":""},

	# --- 近未来 D段补充池（enemy_only）---
	{"card_id":"fut_inf_neural","display_name":"神经接口突击兵","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":1000,"range_value":2,"deploy_speed":5,"base_speed":100,"power":450,"weapon_type":0,
	 "weapon_label":"神经接口步枪","enemy_only":true,
	 "atk_l":253,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":114,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":70,"def_a":35,"def_air":21,
	 "w_light":"神经接口步枪","w_armor":"","w_air":""},

	{"card_id":"fut_arm_hk07","display_name":"HK-07 量产机兵","era":4,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":900,"range_value":2,"deploy_speed":3,"base_speed":80,"power":350,"weapon_type":0,
	 "weapon_label":"粒子炮","enemy_only":true,
	 "atk_l":161,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":720,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":63,"def_a":90,"def_air":54,
	 "w_light":"粒子炮","w_armor":"","w_air":""},

	{"card_id":"fut_arty_hel30","display_name":"HEL-30 激光炮阵列","era":4,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":950,"range_value":99,"deploy_speed":0,"base_speed":0,"power":400,"weapon_type":1,
	 "weapon_label":"激光炮","enemy_only":true,
	 "atk_l":217,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":722,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":43,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":28,"def_a":40,"def_air":17,
	 "w_light":"激光炮","w_armor":"激光炮","w_air":""},

	{"card_id":"fut_sup_nrepair","display_name":"N-Repair 纳米工程车","era":4,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":640,"range_value":1,"deploy_speed":3,"base_speed":90,"power":200,"weapon_type":3,
	 "weapon_label":"纳米修复","enemy_only":true,
	 "atk_l":154,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":512,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":31,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":19,"def_a":27,"def_air":12,
	 "w_light":"纳米修复","w_armor":"","w_air":""},

	{"card_id":"fut_inf_x9","display_name":"X-9 猎杀者渗透组","era":4,"combat_kind":0,"tier":Tier.ELITE,
	 "base_hp":875,"range_value":2,"deploy_speed":6,"base_speed":110,"power":380,"weapon_type":0,
	 "weapon_label":"相位刃","enemy_only":true,
	 "atk_l":222,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":100,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":61,"def_a":31,"def_air":18,
	 "w_light":"相位刃","w_armor":"","w_air":""},

	{"card_id":"fut_inf_c96","display_name":"毛瑟 C96 征召兵排","era":4,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":360,"range_value":2,"deploy_speed":4,"base_speed":95,"power":120,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":108,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":49,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":25,"def_a":13,"def_air":8,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},

	{"card_id":"fut_arm_sdkfz","display_name":"Sd.Kfz.251/1 半履带车","era":4,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":800,"range_value":2,"deploy_speed":3,"base_speed":85,"power":250,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":143,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":640,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":56,"def_a":80,"def_air":48,
	 "w_light":"机枪","w_armor":"","w_air":""},

	{"card_id":"fut_arty_ssc1","display_name":"SS-C-1 岸防导弹组","era":4,"combat_kind":2,"tier":Tier.ELITE,
	 "base_hp":1125,"range_value":99,"deploy_speed":0,"base_speed":0,"power":380,"weapon_type":1,
	 "weapon_label":"岸防导弹","enemy_only":true,
	 "atk_l":256,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":855,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":51,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":34,"def_a":47,"def_air":20,
	 "w_light":"岸防导弹","w_armor":"岸防导弹","w_air":""},

	{"card_id":"fut_sup_ps9","display_name":"PS-9 相位中继站","era":4,"combat_kind":2,"tier":Tier.VETERAN,
	 "base_hp":760,"range_value":99,"deploy_speed":0,"base_speed":0,"power":220,"weapon_type":3,
	 "weapon_label":"相位中继","enemy_only":true,
	 "atk_l":182,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":608,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":36,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":23,"def_a":32,"def_air":14,
	 "w_light":"相位中继","w_armor":"","w_air":""},

	# --- 近未来堡垒 ---
	{"card_id":"fut_fort_ion","display_name":"离子炮台","era":4,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":2500,"range_value":7,"deploy_speed":0,"base_speed":0,"power":1200,"weapon_type":0,
	 "weapon_label":"离子炮",
	 "atk_l":525,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":1800,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":188,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":260,"def_a":260,"def_air":240,
	 "w_light":"离子炮","w_armor":"离子炮阵列","w_air":"多管近防炮/88mm防空炮"},

	{"card_id":"fut_fort_shield","display_name":"能量护盾发生器","era":4,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":2800,"range_value":0,"deploy_speed":0,"base_speed":0,"power":1000,"weapon_type":3,
	 "weapon_label":"",
	 "atk_l":588,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":2016,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":210,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":291,"def_a":291,"def_air":269,
	 "w_light":"","w_armor":"","w_air":""},

	# ══════════════ A段平台卡（enemy_only，敌方部署用）v8.1 新增 ══════════════
	{"card_id":"platform_ww1_light","display_name":"一战轻型平台","era":0,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":100,"range_value":1,"deploy_speed":5,"base_speed":115,"power":151,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":30,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":14,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":7,"def_a":4,"def_air":2,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww1_medium","display_name":"一战中型平台","era":0,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":170,"range_value":2,"deploy_speed":3,"base_speed":80,"power":253,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":30,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":136,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":12,"def_a":17,"def_air":10,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww1_fort","display_name":"一战炮台平台","era":0,"combat_kind":2,"tier":Tier.FORT,
	 "base_hp":600,"range_value":2,"deploy_speed":0,"base_speed":0,"power":621,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":108,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":360,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":22,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":18,"def_a":25,"def_air":11,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww1_radar","display_name":"一战雷达平台","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":100,"range_value":2,"deploy_speed":0,"base_speed":0,"power":133,"weapon_type":3,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":27,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":90,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":5,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":4,"def_air":2,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww1_medic","display_name":"一战医疗平台","era":0,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":100,"range_value":1,"deploy_speed":4,"base_speed":75,"power":141,"weapon_type":3,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":27,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":90,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":5,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":3,"def_a":4,"def_air":2,
	 "w_light":"步枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_light","display_name":"二战轻型平台","era":1,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":150,"range_value":1,"deploy_speed":5,"base_speed":135,"power":222,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":45,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":20,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":11,"def_a":5,"def_air":3,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_medium","display_name":"二战中型平台","era":1,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":250,"range_value":2,"deploy_speed":4,"base_speed":75,"power":369,"weapon_type":0,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":45,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":200,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":18,"def_a":25,"def_air":15,
	 "w_light":"步枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_heavy","display_name":"二战重型平台","era":1,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":440,"range_value":2,"deploy_speed":2,"base_speed":40,"power":621,"weapon_type":1,
	 "weapon_label":"坦克炮","enemy_only":true,
	 "atk_l":75,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":334,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":31,"def_a":44,"def_air":26,
	 "w_light":"坦克炮","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_raider","display_name":"二战突袭平台","era":1,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":150,"range_value":2,"deploy_speed":5,"base_speed":100,"power":218,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":45,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":20,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":11,"def_a":5,"def_air":3,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_radar","display_name":"二战雷达平台","era":1,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":150,"range_value":2,"deploy_speed":0,"base_speed":0,"power":199,"weapon_type":3,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":40,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":135,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":8,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":4,"def_a":6,"def_air":3,
	 "w_light":"步枪","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_siege","display_name":"二战攻城平台","era":1,"combat_kind":2,"tier":Tier.FORT,
	 "base_hp":900,"range_value":2,"deploy_speed":0,"base_speed":0,"power":931,"weapon_type":1,
	 "weapon_label":"火炮","enemy_only":true,
	 "atk_l":162,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":540,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":32,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":27,"def_a":38,"def_air":16,
	 "w_light":"火炮","w_armor":"","w_air":""},
	{"card_id":"platform_ww2_fortress","display_name":"二战要塞平台","era":1,"combat_kind":4,"tier":Tier.FORT,
	 "base_hp":900,"range_value":2,"deploy_speed":0,"base_speed":0,"power":1221,"weapon_type":0,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":189,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":648,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":68,"atk_air_speed":2.0,"atk_air_windup":0.1,"atk_air_active":0.05,
	 "def_l":94,"def_a":94,"def_air":86,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_cold_light","display_name":"冷战轻型平台","era":2,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":210,"range_value":1,"deploy_speed":5,"base_speed":115,"power":302,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":63,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":28,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":15,"def_a":7,"def_air":4,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},
	{"card_id":"platform_cold_medium","display_name":"冷战中型平台","era":2,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":360,"range_value":2,"deploy_speed":3,"base_speed":80,"power":528,"weapon_type":1,
	 "weapon_label":"火炮","enemy_only":true,
	 "atk_l":64,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":288,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":25,"def_a":36,"def_air":22,
	 "w_light":"火炮","w_armor":"","w_air":""},
	{"card_id":"platform_cold_ifv","display_name":"冷战步战车平台","era":2,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":360,"range_value":2,"deploy_speed":4,"base_speed":90,"power":471,"weapon_type":2,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":87,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":107,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":144,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":13,"def_a":9,"def_air":22,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_cold_scout","display_name":"冷战侦察平台","era":2,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":210,"range_value":1,"deploy_speed":6,"base_speed":135,"power":304,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":63,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":28,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":15,"def_a":7,"def_air":4,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},
	{"card_id":"platform_cold_radar","display_name":"冷战雷达平台","era":2,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":210,"range_value":2,"deploy_speed":0,"base_speed":0,"power":280,"weapon_type":3,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":57,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":189,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":11,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":6,"def_a":9,"def_air":4,
	 "w_light":"步枪","w_armor":"","w_air":""},
	{"card_id":"platform_cold_carrier","display_name":"冷战运输平台","era":2,"combat_kind":3,"tier":Tier.VETERAN,
	 "base_hp":360,"range_value":2,"deploy_speed":3,"base_speed":90,"power":471,"weapon_type":2,
	 "weapon_label":"机枪","enemy_only":true,
	 "atk_l":87,"atk_l_speed":0.83,"atk_l_windup":0.241,"atk_l_active":0.12,
	 "atk_a":107,"atk_a_speed":0.67,"atk_a_windup":0.299,"atk_a_active":0.149,
	 "atk_air":144,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":13,"def_a":9,"def_air":22,
	 "w_light":"机枪","w_armor":"","w_air":""},
	{"card_id":"platform_modern_light","display_name":"现代轻型平台","era":3,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":280,"range_value":1,"deploy_speed":5,"base_speed":115,"power":401,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":84,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":38,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":20,"def_a":10,"def_air":6,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},
	{"card_id":"platform_modern_medium","display_name":"现代中型平台","era":3,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":500,"range_value":2,"deploy_speed":3,"base_speed":75,"power":730,"weapon_type":1,
	 "weapon_label":"火炮","enemy_only":true,
	 "atk_l":90,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":400,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":35,"def_a":50,"def_air":30,
	 "w_light":"火炮","w_armor":"","w_air":""},
	{"card_id":"platform_modern_radar","display_name":"现代雷达平台","era":3,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":280,"range_value":2,"deploy_speed":0,"base_speed":0,"power":373,"weapon_type":3,
	 "weapon_label":"步枪","enemy_only":true,
	 "atk_l":76,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":252,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":15,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":8,"def_a":12,"def_air":5,
	 "w_light":"步枪","w_armor":"","w_air":""},
	{"card_id":"platform_modern_spg","display_name":"现代自行火炮平台","era":3,"combat_kind":2,"tier":Tier.FORT,
	 "base_hp":1700,"range_value":2,"deploy_speed":0,"base_speed":0,"power":1759,"weapon_type":1,
	 "weapon_label":"火炮","enemy_only":true,
	 "atk_l":306,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":1020,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":61,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":51,"def_a":71,"def_air":31,
	 "w_light":"火炮","w_armor":"","w_air":""},
	{"card_id":"platform_modern_stealth","display_name":"现代隐形平台","era":3,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":280,"range_value":1,"deploy_speed":6,"base_speed":115,"power":401,"weapon_type":0,
	 "weapon_label":"冲锋枪","enemy_only":true,
	 "atk_l":84,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":38,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":20,"def_a":10,"def_air":6,
	 "w_light":"冲锋枪","w_armor":"","w_air":""},
	{"card_id":"platform_modern_guard_heavy","display_name":"现代重型卫戍平台","era":3,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":900,"range_value":3,"deploy_speed":2,"base_speed":75,"power":1272,"weapon_type":1,
	 "weapon_label":"轨道炮","enemy_only":true,
	 "atk_l":153,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":684,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":63,"def_a":90,"def_air":54,
	 "w_light":"轨道炮","w_armor":"","w_air":""},
	{"card_id":"platform_future_light","display_name":"近未来轻型平台","era":4,"combat_kind":0,"tier":Tier.GRUNT,
	 "base_hp":370,"range_value":2,"deploy_speed":5,"base_speed":115,"power":526,"weapon_type":0,
	 "weapon_label":"光束步枪","enemy_only":true,
	 "atk_l":111,"atk_l_speed":1.5,"atk_l_windup":0.133,"atk_l_active":0.067,
	 "atk_a":50,"atk_a_speed":1.0,"atk_a_windup":0.2,"atk_a_active":0.1,
	 "atk_air":0,"atk_air_speed":1.0,"atk_air_windup":0.2,"atk_air_active":0.1,
	 "def_l":26,"def_a":13,"def_air":8,
	 "w_light":"光束步枪","w_armor":"","w_air":""},
	{"card_id":"platform_future_medium","display_name":"近未来中型平台","era":4,"combat_kind":1,"tier":Tier.VETERAN,
	 "base_hp":720,"range_value":2,"deploy_speed":4,"base_speed":100,"power":1049,"weapon_type":0,
	 "weapon_label":"光束步枪","enemy_only":true,
	 "atk_l":129,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":576,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":50,"def_a":72,"def_air":43,
	 "w_light":"光束步枪","w_armor":"","w_air":""},
	{"card_id":"platform_future_radar","display_name":"近未来雷达平台","era":4,"combat_kind":2,"tier":Tier.GRUNT,
	 "base_hp":370,"range_value":2,"deploy_speed":0,"base_speed":0,"power":495,"weapon_type":3,
	 "weapon_label":"光束步枪","enemy_only":true,
	 "atk_l":100,"atk_l_speed":1.0,"atk_l_windup":0.2,"atk_l_active":0.1,
	 "atk_a":333,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":20,"atk_air_speed":2.5,"atk_air_windup":0.08,"atk_air_active":0.04,
	 "def_l":11,"def_a":16,"def_air":7,
	 "w_light":"光束步枪","w_armor":"","w_air":""},
	{"card_id":"platform_future_heavy","display_name":"近未来重型平台","era":4,"combat_kind":1,"tier":Tier.ELITE,
	 "base_hp":1300,"range_value":3,"deploy_speed":1,"base_speed":50,"power":1831,"weapon_type":1,
	 "weapon_label":"粒子炮","enemy_only":true,
	 "atk_l":221,"atk_l_speed":0.67,"atk_l_windup":0.299,"atk_l_active":0.149,
	 "atk_a":988,"atk_a_speed":0.5,"atk_a_windup":0.4,"atk_a_active":0.2,
	 "atk_air":0,"atk_air_speed":0.5,"atk_air_windup":0.4,"atk_air_active":0.2,
	 "def_l":91,"def_a":130,"def_air":78,
	 "w_light":"粒子炮","w_armor":"","w_air":""},

]


## ════════════════════════════════════════════════════════════════════════
## 查询接口
## ════════════════════════════════════════════════════════════════════════

static var _lookup: Dictionary = {}
static var _built: bool = false


static func _build_lookup() -> void:
	if _built:
		return
	_lookup.clear()
	for entry in _TABLE:
		var cid: String = String(entry.get("card_id", ""))
		if not cid.is_empty():
			_lookup[cid] = entry
	_built = true


## 根据 card_id 获取原始数据字典（玩家卡口径）。不存在返回 {}。
static func get_entry(card_id: String) -> Dictionary:
	_build_lookup()
	return _lookup.get(card_id, {})


## 是否存在该 card_id
static func has_card(card_id: String) -> bool:
	_build_lookup()
	return _lookup.has(card_id)


## 获取所有卡牌条目（数组，每项为字典）
static func get_all_entries() -> Array:
	_build_lookup()
	return _TABLE.duplicate(true)


## 获取所有 card_id
static func get_all_card_ids() -> Array:
	_build_lookup()
	return _lookup.keys()


## 获取指定时代的所有卡
static func get_entries_by_era(era: int) -> Array:
	_build_lookup()
	var out: Array = []
	for entry in _TABLE:
		if int(entry.get("era", -1)) == era:
			out.append(entry)
	return out


## 获取非 enemy_only 的卡（玩家可购买的卡）
static func get_player_card_entries() -> Array:
	_build_lookup()
	var out: Array = []
	for entry in _TABLE:
		if not bool(entry.get("enemy_only", false)):
			out.append(entry)
	return out


## 获取 enemy_only 的卡（仅敌方出现/缴获获得）
static func get_enemy_only_entries() -> Array:
	_build_lookup()
	var out: Array = []
	for entry in _TABLE:
		if bool(entry.get("enemy_only", false)):
			out.append(entry)
	return out


## 获取指定档次的所有卡
static func get_entries_by_tier(tier: int) -> Array:
	_build_lookup()
	var out: Array = []
	for entry in _TABLE:
		if int(entry.get("tier", -1)) == tier:
			out.append(entry)
	return out


## ════════════════════════════════════════════════════════════════════════
## CardResource 构造（玩家卡口径）
## ════════════════════════════════════════════════════════════════════════

## 从统一表条目构造 CardResource（含完整三维攻防/per-target攻速/武器名）
## card_id 不存在返回 null
static func build_card_resource(card_id: String) -> CardResource:
	var entry: Dictionary = get_entry(card_id)
	if entry.is_empty():
		return null
	return _entry_to_card(entry)


## 内部：字典 → CardResource
static func _entry_to_card(entry: Dictionary) -> CardResource:
	var c = CardResource.new()
	c.card_id = String(entry.get("card_id", ""))
	c.display_name = String(entry.get("display_name", c.card_id))
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = int(entry.get("era", 0))
	c.combat_kind = int(entry.get("combat_kind", 0))
	c.base_hp = float(entry.get("base_hp", 100.0))
	c.range_value = int(entry.get("range_value", 3))
	c.deploy_speed = int(entry.get("deploy_speed", 3))
	c.base_speed = float(entry.get("base_speed", 80.0))
	c.power = int(entry.get("power", 10))
	c.weapon_type = int(entry.get("weapon_type", 0))
	c.weapon_label = String(entry.get("weapon_label", ""))
	# 三维攻击
	c.attack_light = float(entry.get("atk_l", 0.0))
	c.attack_armor = float(entry.get("atk_a", 0.0))
	c.attack_air = float(entry.get("atk_air", 0.0))
	# per-target 攻速
	c.attack_light_speed = float(entry.get("atk_l_speed", 1.0))
	c.attack_light_windup = float(entry.get("atk_l_windup", 0.2))
	c.attack_light_active = float(entry.get("atk_l_active", 0.1))
	c.attack_armor_speed = float(entry.get("atk_a_speed", 1.0))
	c.attack_armor_windup = float(entry.get("atk_a_windup", 0.2))
	c.attack_armor_active = float(entry.get("atk_a_active", 0.1))
	c.attack_air_speed = float(entry.get("atk_air_speed", 1.0))
	c.attack_air_windup = float(entry.get("atk_air_windup", 0.2))
	c.attack_air_active = float(entry.get("atk_air_active", 0.1))
	# 三维防御
	c.defense_light = float(entry.get("def_l", 0.0))
	c.defense_armor = float(entry.get("def_a", 0.0))
	c.defense_air = float(entry.get("def_air", 0.0))
	# 综合攻速后备
	c.attack_speed = _calc_main_attack_speed(c)
	# 武器名
	var wl: String = String(entry.get("w_light", ""))
	var wa: String = String(entry.get("w_armor", ""))
	var wai: String = String(entry.get("w_air", ""))
	# weapon_names 为 Array[String] 类型，必须先构造强类型数组再赋值，
	# 否则普通无类型数组字面量赋值给类型属性会在运行期失败。
	var names: Array[String] = [wl, wa, wai]
	c.weapon_names = names
	# 标记 enemy_only（缴获卡用）
	c.is_dropped_card = bool(entry.get("enemy_only", false))
	# 类型行
	c.type_line = _make_type_line(c.era, c.combat_kind, c.is_dropped_card)
	return c


static func _calc_main_attack_speed(c: CardResource) -> float:
	# 取主要攻击维度的攻速（与 default_cards._calculate_attack_speed 一致）
	if c.attack_light >= c.attack_armor and c.attack_light >= c.attack_air:
		return c.attack_light_speed
	elif c.attack_armor >= c.attack_light and c.attack_armor >= c.attack_air:
		return c.attack_armor_speed
	else:
		return c.attack_air_speed


static func _make_type_line(era: int, combat_kind: int, is_dropped: bool) -> String:
	var era_label: String = ["一战", "二战", "冷战", "现代", "近未来"][clampi(era, 0, 4)]
	var kind_label: String = CardResource.get_combat_kind_name(combat_kind)
	if is_dropped:
		return "%s — 缴获%s" % [era_label, kind_label]
	return "%s — %s" % [era_label, kind_label]


## ════════════════════════════════════════════════════════════════════════
## 敌方 archetype_config 转换（敌方消费方用）
## 把玩家卡口径的统一表条目 → 敌方 archetype_config 口径
## （range_value格→attack_range像素, attack_speed次/秒→attack_interval秒）
## ════════════════════════════════════════════════════════════════════════

## 从统一表条目生成敌方 archetype_config 字典（供 enemy_unit_manifest / enemy_archetypes 用）
## 返回空字典表示 card_id 不存在
static func build_enemy_archetype_config(card_id: String) -> Dictionary:
	var entry: Dictionary = get_entry(card_id)
	if entry.is_empty():
		return {}
	var era: int = int(entry.get("era", 0))
	var ck: int = int(entry.get("combat_kind", 0))
	# 射程：格 → 像素（1格=100px）
	var rng_px: float = float(entry.get("range_value", 3)) * 100.0
	# 攻速：次/秒 → 秒/次（取主攻速作为 attack_interval，三维 interval 各自派生）
	var main_spd: float = float(entry.get("atk_l_speed", 1.0))
	if ck == 1 and float(entry.get("atk_a_speed", 0.0)) > 0.0:
		main_spd = float(entry.get("atk_a_speed", 1.0))
	elif ck == 3 and float(entry.get("atk_air_speed", 0.0)) > 0.0:
		main_spd = float(entry.get("atk_air_speed", 1.0))
	var ivl: float = (1.0 / main_spd) if main_spd > 0.0 else 1.0
	# v8.1: 三维 interval（防空特化单位对空高频对地低频）
	var spd_l: float = float(entry.get("atk_l_speed", main_spd))
	var spd_a: float = float(entry.get("atk_a_speed", main_spd))
	var spd_air: float = float(entry.get("atk_air_speed", main_spd))
	var ivl_l: float = (1.0 / spd_l) if spd_l > 0.0 else ivl
	var ivl_a: float = (1.0 / spd_a) if spd_a > 0.0 else ivl
	var ivl_air: float = (1.0 / spd_air) if spd_air > 0.0 else ivl
	# 移速：正值 → 负值像素（向左）
	var spd_neg: float = 0.0
	var bs: float = float(entry.get("base_speed", 0.0))
	if bs > 0.0:
		spd_neg = -maxf(40.0, bs * 0.65)
	# tags
	var tags: Array = _tags_for_combat_kind(ck)
	var tier_val: int = int(entry.get("tier", Tier.GRUNT))
	if tier_val >= Tier.BOSS:
		tags.append("boss")
	elif tier_val >= Tier.ELITE:
		tags.append("elite")
	return {
		"era": era,
		"display_name": String(entry.get("display_name", card_id)),
		"hp": float(entry.get("base_hp", 100.0)),
		"speed": spd_neg,
		"attack_light": float(entry.get("atk_l", 0.0)),
		"attack_armor": float(entry.get("atk_a", 0.0)),
		"attack_air": float(entry.get("atk_air", 0.0)),
		"attack_range": rng_px,
		"attack_interval": ivl,
		"attack_light_interval": ivl_l,
		"attack_armor_interval": ivl_a,
		"attack_air_interval": ivl_air,
		"combat_kind": ck,
		"weapon_label": String(entry.get("weapon_label", "")),
		"weapon_type": int(entry.get("weapon_type", 0)),
		"defense_light": float(entry.get("def_l", 0.0)),
		"defense_armor": float(entry.get("def_a", 0.0)),
		"defense_air": float(entry.get("def_air", 0.0)),
		"tags": tags,
		"swarm_unit": (ck == 0 and tier_val <= Tier.GRUNT),
	}


static func _tags_for_combat_kind(ck: int) -> Array:
	match ck:
		0: return ["infantry"]
		1: return ["vehicle", "armored"]
		2: return ["support"]
		3: return ["aircraft"]
		4: return ["fortress", "immobile"]
		_: return []


## 清空缓存（测试用）
static func clear_cache() -> void:
	_lookup.clear()
	_built = false
