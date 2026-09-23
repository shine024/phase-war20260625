extends RefCounted
class_name LevelBattleLayouts
## v26.2 每关战场布局表——"可布置范围"数据真身。
## 缺省（表内无条目 / GameConfig.battle_layouts_enabled=false）= 3 行 3 列无禁放，
## 与 v26.1 前行为逐像素一致。battle_manager.start_battle 经
## CardGridBattleLayout.apply_for_level(level) 读本表激活；end_battle 复位。
##
## 条目字段（全部可选）：
##   rows             行数（仅 2/3；2 行沿用 3 行的上下边线，行距加宽）
##   player_cols      我方每行格数（2-4）
##   enemy_cols       敌方每行格数（2-4；敌方在场数仍受 era field cap 钳制）
##   player_excluded  我方废墟格（行主序槽位号数组，不可部署）
##   enemy_excluded   敌方废墟格（敌方出生避开）
##
## 槽位编号（行主序，与 3×3 相同）：row r 第 c 格 = r*cols + c；
## row0=上行 / row1=中行 / row2=下行，col0=靠我方外缘。
##
## 首版 15 关（题面=环境同题）：环境显式关 5（10/25/45/68/90）+ 时代边界 4（21/41/61/81）
## + 驻守/中段代表 6（16/33/55/77/96）。扩展=加数据行，零代码。

const LAYOUT_BY_LEVEL: Dictionary = {
	# ── 环境显式关（battle_environments.ENV_BY_LEVEL 五关，题面与环境同题） ──
	10: {"player_excluded": [2, 6], "note": "雨巷废墟——上右/下左瓦砾堵位"},
	25: {"enemy_cols": 4, "note": "低能量场宽正面——敌 4 列 12 槽压迫"},
	45: {"player_cols": 2, "enemy_cols": 3, "note": "雪城巷战——我方窄门 6 格守 9 格"},
	68: {"rows": 2, "player_cols": 2, "enemy_cols": 2, "note": "夜战窄巷——4v4 决斗场"},
	90: {"player_cols": 4, "enemy_cols": 4, "note": "沙暴全宽会战——12v12 大场面"},
	# ── 时代边界关（era 切换处，新棋面宣告新时代） ──
	21: {"player_cols": 2, "enemy_cols": 2, "note": "二战窄路——6v6 遭遇战"},
	41: {"player_excluded": [4], "note": "冷战铁幕——中行中央弹坑堵主战线"},
	61: {"player_cols": 4, "enemy_cols": 3, "note": "现代宽阵——12 格机动展开"},
	81: {"player_cols": 3, "enemy_cols": 4, "note": "近未来宽敌阵——敌 12 槽泛光灯海"},
	# ── 驻守/中段代表 ──
	16: {"player_cols": 4, "enemy_cols": 3, "note": "堡垒攻坚——宽阵包抄驻守相位师"},
	33: {"rows": 2, "player_cols": 3, "enemy_cols": 3, "note": "平原速决——双行 6v6"},
	55: {"enemy_excluded": [0, 8], "note": "敌方废墟——敌上右/下左塌陷，趁机突击"},
	77: {"player_excluded": [1, 7], "note": "废墟走廊——上中/下中堵死，只余两翼与中行"},
	96: {"rows": 2, "player_cols": 3, "enemy_cols": 4, "note": "终局前夜——窄守 6 格抗 8 格"},
	# ── v26.13(B1)：机制多样性扩充（与新规则/环境联动成"题面+棋面"复合关） ──
	3: {"player_excluded": [3], "note": "限时首秀——下右塌方堵角，通路收窄"},
	8: {"enemy_cols": 4, "note": "先手突袭——敌宽 4 列 12 槽抢攻"},
	19: {"player_excluded": [1, 4], "note": "限时+先手——我方两角废墟，开局压力大"},
	27: {"rows": 2, "enemy_cols": 4, "note": "禁改造——双行 8 槽对冲，拼基础兵"},
	35: {"player_cols": 2, "note": "限时+禁疗——我方窄门 6 格死守"},
	47: {"enemy_excluded": [2], "note": "先手+枯竭——敌方中列弹坑，两翼快攻"},
	52: {"player_cols": 4, "enemy_cols": 4, "note": "270 秒——12v12 全宽对攻"},
	62: {"enemy_cols": 4, "player_excluded": [5], "note": "先手+我方中下堵位"},
	70: {"rows": 2, "enemy_cols": 3, "note": "限时——双行 6 格快节奏"},
	88: {"enemy_cols": 4, "note": "先手+枯竭——终局宽阵抢攻"},
	# ── v30.5 R5（设计审查 F-11）：覆盖 24→60 关。分三组——规则联动（题面+棋面
	#    复合：能量类配窄门/先手配敌宽阵/限时配双行/禁疗配废墟角）、Boss 关棋面
	#    （20/40/60/80/100 五 Boss 战辨识度）、纯地形（描述地名取题面） ──
	# ── 规则联动 20（一战）：山脊窄省放 / 机枪死角诱导 / 巷战步兵窄街 / 伏击宽出 / 总攻夜 ──
	5: {"player_cols": 2, "note": "山脊单通道——窄门 6 格，回复减半省着放"},
	12: {"enemy_excluded": [0, 8], "note": "机枪死角——敌上左/下右塌陷，中路是火网"},
	15: {"player_cols": 2, "note": "巷战窄街——6 格只容步兵展开"},
	17: {"enemy_cols": 4, "note": "林线伏击——精英波次自宽正面压出"},
	20: {"player_excluded": [0, 8], "note": "总攻夜——我方两角弹坑，中门对轰"},
	# ── 规则联动 22-40（二战）：冬季突袭 / 装甲宽野 / 精英死守 / 核影窄门 / 终战洪流 ──
	23: {"enemy_cols": 4, "note": "冬季突袭——敌 4 列抢攻，寒风里的宽正面"},
	30: {"player_cols": 4, "note": "冻土宽野——装甲展开线"},
	32: {"enemy_cols": 4, "note": "国会大厦——精英守军宽阵死守"},
	38: {"player_cols": 2, "note": "核影之下——窄门 6 格，省着打"},
	40: {"enemy_cols": 4, "note": "新时代门槛——敌 12 槽终战洪流"},
	# ── 规则联动 41-60（冷战）：血账废墟 / 帝国坟场窄门 / 危机双行 / 落幕塌陷 ──
	42: {"player_excluded": [0, 8], "note": "半岛血账——上左/下右废墟，无处疗伤"},
	50: {"player_cols": 2, "note": "帝国坟场——山口窄门，回复减半"},
	57: {"rows": 2, "note": "危机线——双行对峙，拼裸装"},
	60: {"enemy_excluded": [4], "note": "落幕——敌中列塌陷，正面收窄"},
	# ── 规则联动 61-80（现代）：反恐窄守 / 乱局四线 / 虚拟双行 / 补给外露 / 风暴眼 ──
	65: {"player_cols": 2, "note": "反恐泥潭——窄门 6 格双压死守"},
	67: {"enemy_cols": 4, "note": "乱局四线——敌宽 12 槽，且战且退"},
	72: {"rows": 2, "note": "虚拟战线——双行对冲，裸装互拼"},
	75: {"enemy_excluded": [0, 8], "note": "补给线外——敌两角塌陷，中央突破"},
	80: {"player_cols": 3, "enemy_cols": 4, "note": "风暴眼——9 守 12 的世纪决战"},
	# ── 规则联动 81-100（近未来）：折叠角 / 门前宽守 / 扭曲波 / 跳跃窗口 / 蜂群走廊 / 终局 ──
	82: {"player_excluded": [2, 6], "note": "折叠角——上右/下左相位裂缝，无处回复"},
	85: {"player_cols": 4, "enemy_cols": 3, "note": "门前三百米——工兵宽守窄攻"},
	87: {"enemy_cols": 4, "note": "扭曲波——精英自宽阵溢出"},
	92: {"rows": 2, "player_cols": 3, "enemy_cols": 3, "note": "跳跃窗口——双行速决"},
	95: {"enemy_cols": 4, "player_excluded": [0, 8], "note": "蜂群走廊——我方两角堵死，敌宽阵涌来"},
	100: {"player_cols": 3, "enemy_cols": 4, "note": "终局棋盘——9 守 12 的最后一局"},
	# ── 纯地形 11（描述地名取题面，无规则联动） ──
	2: {"player_excluded": [0, 2], "note": "泥沼——上排两格陷泥"},
	6: {"rows": 2, "note": "林间双道——双行渗透"},
	9: {"enemy_cols": 4, "note": "骑海——敌宽 4 列冲锋"},
	13: {"player_cols": 2, "note": "堑壕——我方窄列纵深"},
	22: {"enemy_excluded": [3, 5], "note": "沙丘——敌中行两格沙陷"},
	29: {"player_cols": 2, "enemy_cols": 4, "note": "滩头——6 格登陆场对 12 格折钵山"},
	34: {"rows": 2, "player_cols": 2, "enemy_cols": 3, "note": "丛林走廊——4 对 6 的消耗"},
	44: {"player_excluded": [6, 8], "note": "雨林沼泽——下排两角泥陷"},
	53: {"enemy_cols": 4, "note": "山地反击——敌宽正面压上"},
	58: {"player_cols": 2, "enemy_cols": 2, "note": "红线——6v6 走钢丝"},
	98: {"rows": 2, "player_cols": 3, "enemy_cols": 3, "note": "临界双行——终章前的窄路"}
}


static func get_for_level(level: int) -> Dictionary:
	if LAYOUT_BY_LEVEL.has(level):
		return (LAYOUT_BY_LEVEL[level] as Dictionary).duplicate(true)
	return {}


static func has_custom_layout(level: int) -> bool:
	return LAYOUT_BY_LEVEL.has(level)


## 布局题面（战前简报/HUD 可展示）
static func get_note(level: int) -> String:
	return String(LAYOUT_BY_LEVEL.get(level, {}).get("note", ""))
