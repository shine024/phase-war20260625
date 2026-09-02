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
