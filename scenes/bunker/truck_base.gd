extends Control
## v26.12 移动基地（MVP 视觉壳）——装甲卡车剖面驻地，五时代地域切换
## 边界（用户 2026-09-04 口径）：旧基地 bunker_main 与战斗系统零改动，对战方式仍为 3v3 对 3v3；
## 本场景：剖面常驻视图 + 地域到达演出 + 工位热区 + 出击简报（复用 bunker 的 launch_from_bunker 链）。
## v26.12b 接线轮：工位面板真调 EMBEDDED_PANELS（复刻 bunker_main 539-615 链）、
## 统计终端接真数据（LevelProgressManager/BasicResourceManager/InstanceRegistry/IntelItemBag）、
## 睡觉接 BunkerManager.sleep()（与基地同一存档日状态）。战绩页仍占位（战斗统计无跨战持久化）。

const SCENE_TITLE := "res://scenes/title_screen.tscn"
const SCENE_MAIN := "res://scenes/main.tscn"
const INSTRUMENT_BAR_SCENE := "res://scenes/ui/bottom_instrument_bar.tscn"
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const DT = preload("res://resources/design_tokens.gd")
const TruckTravel = preload("res://data/truck_travel.gd")          # v26.19: 行军数值真身
const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")   # v26.19: cost_text 价目文案

const COLOR_CYAN := Color(0.0, 0.9, 1.0)
const COLOR_AMBER := Color(1.0, 0.71, 0.37)
const COLOR_LINE := Color(0.23, 0.21, 0.16)

# ── 五时代地域表（图=图生图定稿 truck_cutN：全部从用户原版 1734 剖面 img2img 派生，构图/工位对齐）──
## accent = 时代主题色源：chips 高亮/caption/热区描边/简报强调/终端字色共用（切时代=换驻地氛围）
const ERAS := [
	{"id": "era1", "tex": "res://assets/ui/truck_base/truck_cut1.png",
		"label": "I 一战", "zone": "索姆战壕", "level": 5,
		"accent": Color(0.85, 0.66, 0.32),
		"env": ["天气 寒雾", "地形 战壕", "能量场 —", "时段 晨"]},
	{"id": "era2", "tex": "res://assets/ui/truck_base/truck_cut2.png",
		"label": "II 二战", "zone": "东部砖镇", "level": 25,
		"accent": Color(0.65, 0.72, 0.40),
		"env": ["天气 阴雨", "地形 城镇", "能量场 —", "时段 昼"]},
	{"id": "era3", "tex": "res://assets/ui/truck_base/truck_cut3.png",
		"label": "III 冷战", "zone": "沙漠前哨", "level": 45,
		"accent": Color(0.45, 0.93, 0.62),
		"env": ["天气 晴热", "地形 沙丘", "能量场 —", "时段 昼"]},
	{"id": "era4", "tex": "res://assets/ui/truck_base/truck_cut4.png",
		"label": "IV 现代", "zone": "浮岩荒原", "level": 65,
		"accent": Color(0.0, 0.9, 1.0),
		"env": ["天气 磁暴", "地形 浮岩", "能量场 全队+15%", "时段 夜"]},
	{"id": "era5", "tex": "res://assets/ui/truck_base/truck_cut5.png",
		"label": "V 近未来", "zone": "极光冻原", "level": 85,
		"accent": Color(0.74, 0.58, 1.0),
		"env": ["天气 极光磁暴", "地形 浮岩", "能量场 全队+15%", "时段 夜"]},
]

# ── 每时代热区表（[l,t,w,h] 占画面比例，按各图 50px 网格实测；kind: sortie/terminal/panel/sleep/info）──
const HOTSPOTS := {
	"era1": [
		{"r": [0.018, 0.160, 0.210, 0.530], "name": "驾驶室", "hint": "出击简报", "kind": "sortie"},
		{"r": [0.255, 0.393, 0.139, 0.208], "name": "指挥电脑桌", "hint": "战术统计终端", "kind": "terminal", "rooms": "war_room + entry_hall"},
		{"r": [0.282, 0.254, 0.107, 0.138], "name": "世界地图墙", "hint": "情报舱", "kind": "panel", "key": "intelligence", "rooms": "archive"},
		{"r": [0.398, 0.312, 0.067, 0.323], "name": "补给售货机", "hint": "补给舱·联络台", "kind": "panel", "key": "store", "rooms": "comms"},
		{"r": [0.470, 0.277, 0.103, 0.185], "name": "卡牌展示墙", "hint": "卡仓", "kind": "panel", "key": "backpack", "rooms": "dormitory（挂靠）"},
		{"r": [0.506, 0.277, 0.138, 0.323], "name": "工具工作台", "hint": "改造·词条", "kind": "panel", "key": "modification", "rooms": "workshop"},
		{"r": [0.680, 0.335, 0.040, 0.260], "name": "3D 打印机", "hint": "制造舱·卡仓", "kind": "panel", "key": "evolution", "rooms": "depot"},
		{"r": [0.450, 0.650, 0.040, 0.100], "name": "医疗柜", "hint": "医疗·配给", "kind": "info", "rooms": "medical + mess_hall"},
		{"r": [0.925, 0.660, 0.055, 0.170], "name": "发电机", "hint": "全车电力·配给", "kind": "info", "rooms": "reactor + mess_hall"},
		{"r": [0.792, 0.462, 0.152, 0.140], "name": "铺位", "hint": "睡眠·存档", "kind": "sleep", "rooms": "dormitory"},
		{"r": [0.940, 0.327, 0.055, 0.400], "name": "尾门跳板", "hint": "出击口", "kind": "sortie"},
		{"r": [0.255, 0.610, 0.139, 0.080], "name": "通讯架", "hint": "成长规划", "kind": "panel", "key": "growth"},
		{"r": [0.506, 0.610, 0.138, 0.080], "name": "词缀工具车", "hint": "词缀·洗练", "kind": "panel", "key": "affix"},
		{"r": [0.470, 0.180, 0.174, 0.090], "name": "资料柜", "hint": "图鉴·收藏档案", "kind": "panel", "key": "collection"},
		{"r": [0.398, 0.180, 0.067, 0.100], "name": "电台", "hint": "势力联络", "kind": "panel", "key": "faction"},
		{"r": [0.792, 0.610, 0.130, 0.070], "name": "战功板", "hint": "战功记录", "kind": "panel", "key": "leaderboard"},
		{"r": [0.852, 0.327, 0.080, 0.080], "name": "告示板", "hint": "车长手册", "kind": "panel", "key": "help"},
	],
	"era2": [
		{"r": [0.009, 0.140, 0.222, 0.530], "name": "驾驶室", "hint": "出击简报", "kind": "sortie"},
		{"r": [0.244, 0.371, 0.146, 0.209], "name": "指挥电脑桌", "hint": "战术统计终端", "kind": "terminal", "rooms": "war_room + entry_hall"},
		{"r": [0.284, 0.232, 0.106, 0.139], "name": "世界地图墙", "hint": "情报舱", "kind": "panel", "key": "intelligence", "rooms": "archive"},
		{"r": [0.394, 0.267, 0.066, 0.348], "name": "补给售货机", "hint": "补给舱·联络台", "kind": "panel", "key": "store", "rooms": "comms"},
		{"r": [0.465, 0.244, 0.106, 0.220], "name": "卡牌展示墙", "hint": "卡仓", "kind": "panel", "key": "backpack", "rooms": "dormitory（挂靠）"},
		{"r": [0.580, 0.452, 0.128, 0.160], "name": "工具工作台", "hint": "改造·词条", "kind": "panel", "key": "modification", "rooms": "workshop"},
		{"r": [0.700, 0.278, 0.040, 0.325], "name": "3D 打印机", "hint": "制造舱·卡仓", "kind": "panel", "key": "evolution", "rooms": "depot"},
		{"r": [0.447, 0.661, 0.036, 0.104], "name": "医疗柜", "hint": "医疗·配给", "kind": "info", "rooms": "medical + mess_hall"},
		{"r": [0.918, 0.661, 0.070, 0.174], "name": "发电机", "hint": "全车电力·配给", "kind": "info", "rooms": "reactor + mess_hall"},
		{"r": [0.780, 0.452, 0.141, 0.139], "name": "铺位", "hint": "睡眠·存档", "kind": "sleep", "rooms": "dormitory"},
		{"r": [0.922, 0.220, 0.060, 0.452], "name": "尾门跳板", "hint": "出击口", "kind": "sortie"},
		{"r": [0.244, 0.590, 0.146, 0.080], "name": "通讯架", "hint": "成长规划", "kind": "panel", "key": "growth"},
		{"r": [0.580, 0.620, 0.128, 0.080], "name": "词缀工具车", "hint": "词缀·洗练", "kind": "panel", "key": "affix"},
		{"r": [0.465, 0.150, 0.275, 0.085], "name": "资料柜", "hint": "图鉴·收藏档案", "kind": "panel", "key": "collection"},
		{"r": [0.394, 0.150, 0.066, 0.100], "name": "电台", "hint": "势力联络", "kind": "panel", "key": "faction"},
		{"r": [0.780, 0.600, 0.130, 0.055], "name": "战功板", "hint": "战功记录", "kind": "panel", "key": "leaderboard"},
		{"r": [0.830, 0.300, 0.085, 0.090], "name": "告示板", "hint": "车长手册", "kind": "panel", "key": "help"},
	],
	"era3": [
		{"r": [0.009, 0.357, 0.260, 0.430], "name": "驾驶室", "hint": "出击简报", "kind": "sortie"},
		{"r": [0.264, 0.513, 0.123, 0.120], "name": "指挥雷达台", "hint": "战术统计终端", "kind": "terminal", "rooms": "war_room + entry_hall"},
		{"r": [0.272, 0.403, 0.101, 0.110], "name": "世界地图屏", "hint": "情报舱", "kind": "panel", "key": "intelligence", "rooms": "archive"},
		{"r": [0.431, 0.394, 0.044, 0.211], "name": "补给售货机", "hint": "补给舱·联络台", "kind": "panel", "key": "store", "rooms": "comms"},
		{"r": [0.584, 0.394, 0.097, 0.240], "name": "物资货架", "hint": "卡仓", "kind": "panel", "key": "backpack", "rooms": "dormitory（挂靠）"},
		{"r": [0.606, 0.632, 0.062, 0.100], "name": "工坊工具台", "hint": "改造·词条", "kind": "panel", "key": "modification", "rooms": "workshop"},
		{"r": [0.677, 0.485, 0.053, 0.147], "name": "钻床打印机", "hint": "制造舱·卡仓", "kind": "panel", "key": "evolution", "rooms": "depot"},
		{"r": [0.479, 0.733, 0.048, 0.092], "name": "医疗柜", "hint": "医疗·配给", "kind": "info", "rooms": "medical + mess_hall"},
		{"r": [0.844, 0.420, 0.060, 0.240], "name": "配电柜", "hint": "全车电力·配给", "kind": "info", "rooms": "reactor + mess_hall"},
		{"r": [0.751, 0.550, 0.124, 0.100], "name": "铺位", "hint": "睡眠·存档", "kind": "sleep", "rooms": "dormitory"},
		{"r": [0.920, 0.450, 0.065, 0.350], "name": "尾门跳板", "hint": "出击口", "kind": "sortie"},
		{"r": [0.272, 0.645, 0.115, 0.070], "name": "通讯台", "hint": "成长规划", "kind": "panel", "key": "growth"},
		{"r": [0.676, 0.640, 0.062, 0.092], "name": "词缀工具台", "hint": "词缀·洗练", "kind": "panel", "key": "affix"},
		{"r": [0.584, 0.290, 0.097, 0.095], "name": "档案屏", "hint": "图鉴·收藏档案", "kind": "panel", "key": "collection"},
		{"r": [0.431, 0.280, 0.044, 0.100], "name": "通讯阵列", "hint": "势力联络", "kind": "panel", "key": "faction"},
		{"r": [0.751, 0.450, 0.085, 0.090], "name": "战功屏", "hint": "战功记录", "kind": "panel", "key": "leaderboard"},
		{"r": [0.838, 0.670, 0.075, 0.080], "name": "电子告示牌", "hint": "车长手册", "kind": "panel", "key": "help"},
	],
	"era4": [
		{"r": [0.009, 0.374, 0.200, 0.490], "name": "驾驶室", "hint": "出击简报", "kind": "sortie"},
		{"r": [0.250, 0.545, 0.123, 0.160], "name": "全息指挥台", "hint": "战术统计终端", "kind": "terminal", "rooms": "war_room + entry_hall"},
		{"r": [0.254, 0.417, 0.088, 0.139], "name": "全息地图墙", "hint": "情报舱", "kind": "panel", "key": "intelligence", "rooms": "archive"},
		{"r": [0.818, 0.417, 0.050, 0.374], "name": "补给货架", "hint": "补给舱·联络台", "kind": "panel", "key": "store", "rooms": "comms"},
		{"r": [0.412, 0.449, 0.079, 0.257], "name": "卡牌展示墙", "hint": "卡仓", "kind": "panel", "key": "backpack", "rooms": "dormitory（挂靠）"},
		{"r": [0.710, 0.587, 0.096, 0.180], "name": "机械臂工位", "hint": "改造·词条", "kind": "panel", "key": "modification", "rooms": "workshop"},
		{"r": [0.727, 0.705, 0.066, 0.075], "name": "3D 打印机", "hint": "制造舱·卡仓", "kind": "panel", "key": "evolution", "rooms": "depot"},
		{"r": [0.438, 0.705, 0.053, 0.182], "name": "医疗冰箱", "hint": "医疗·配给", "kind": "info", "rooms": "medical + mess_hall"},
		{"r": [0.692, 0.812, 0.190, 0.145], "name": "聚变缆线", "hint": "全车电力·配给", "kind": "info", "rooms": "reactor + mess_hall"},
		{"r": [0.565, 0.652, 0.127, 0.150], "name": "铺位", "hint": "睡眠·存档", "kind": "sleep", "rooms": "dormitory"},
		{"r": [0.885, 0.380, 0.080, 0.530], "name": "尾门跳板", "hint": "出击口", "kind": "sortie"},
		{"r": [0.250, 0.715, 0.123, 0.070], "name": "全息通讯塔", "hint": "成长规划", "kind": "panel", "key": "growth"},
		{"r": [0.710, 0.500, 0.096, 0.080], "name": "词缀机械臂", "hint": "词缀·洗练", "kind": "panel", "key": "affix"},
		{"r": [0.412, 0.330, 0.079, 0.080], "name": "全息档案柜", "hint": "图鉴·收藏档案", "kind": "panel", "key": "collection"},
		{"r": [0.254, 0.300, 0.088, 0.080], "name": "外交全息台", "hint": "势力联络", "kind": "panel", "key": "faction"},
		{"r": [0.565, 0.540, 0.127, 0.080], "name": "战功光墙", "hint": "战功记录", "kind": "panel", "key": "leaderboard"},
		{"r": [0.806, 0.290, 0.070, 0.080], "name": "全息手册架", "hint": "车长手册", "kind": "panel", "key": "help"},
	],
	"era5": [
		{"r": [0.017, 0.393, 0.190, 0.488], "name": "驾驶室", "hint": "出击简报", "kind": "sortie"},
		{"r": [0.224, 0.552, 0.170, 0.170], "name": "全息指挥台", "hint": "战术统计终端", "kind": "terminal", "rooms": "war_room + entry_hall"},
		{"r": [0.250, 0.435, 0.060, 0.117], "name": "全息地图投影", "hint": "情报舱", "kind": "panel", "key": "intelligence", "rooms": "archive"},
		{"r": [0.392, 0.414, 0.047, 0.265], "name": "补给售货机", "hint": "补给舱·联络台", "kind": "panel", "key": "store", "rooms": "comms"},
		{"r": [0.444, 0.414, 0.112, 0.202], "name": "卡牌展示墙", "hint": "卡仓", "kind": "panel", "key": "backpack", "rooms": "dormitory（挂靠）"},
		{"r": [0.565, 0.488, 0.108, 0.190], "name": "相位机械臂", "hint": "改造·词条", "kind": "panel", "key": "modification", "rooms": "workshop"},
		{"r": [0.596, 0.616, 0.060, 0.117], "name": "相位打印机", "hint": "制造舱·卡仓", "kind": "panel", "key": "evolution", "rooms": "depot"},
		{"r": [0.255, 0.695, 0.040, 0.090], "name": "医疗柜", "hint": "医疗·配给", "kind": "info", "rooms": "medical + mess_hall"},
		{"r": [0.695, 0.775, 0.115, 0.200], "name": "相位能源盘", "hint": "全车电力·配给", "kind": "info", "rooms": "reactor + mess_hall"},
		{"r": [0.752, 0.672, 0.135, 0.165], "name": "铺位", "hint": "睡眠·存档", "kind": "sleep", "rooms": "dormitory"},
		{"r": [0.900, 0.420, 0.085, 0.340], "name": "尾门跳板", "hint": "出击口", "kind": "sortie"},
		{"r": [0.300, 0.735, 0.094, 0.070], "name": "相位通讯塔", "hint": "成长规划", "kind": "panel", "key": "growth"},
		{"r": [0.565, 0.745, 0.108, 0.070], "name": "词缀相位台", "hint": "词缀·洗练", "kind": "panel", "key": "affix"},
		{"r": [0.444, 0.320, 0.112, 0.085], "name": "相位档案柜", "hint": "图鉴·收藏档案", "kind": "panel", "key": "collection"},
		{"r": [0.392, 0.300, 0.047, 0.100], "name": "相位外交台", "hint": "势力联络", "kind": "panel", "key": "faction"},
		{"r": [0.565, 0.395, 0.187, 0.080], "name": "战功光廊", "hint": "战功记录", "kind": "panel", "key": "leaderboard"},
		{"r": [0.895, 0.320, 0.080, 0.080], "name": "相位手册架", "hint": "车长手册", "kind": "panel", "key": "help"},
	],
}

const PANEL_LABELS := {
	"store": "补给舱 EMBEDDED_PANELS['store']",
	"modification": "改造舱 EMBEDDED_PANELS['modification']",
	"evolution": "制造舱 EMBEDDED_PANELS['evolution']",
	"backpack": "卡仓 EMBEDDED_PANELS['backpack']",
	"intelligence": "情报舱 EMBEDDED_PANELS['intelligence']",
}

## 与 bunker_main.EMBEDDED_PANELS 同源（只取本场景会用的键；路径改动两处同步）
## v26.33：+help——战斗屏帮助入口已随 v25.3 收敛删除、旧基地停用后帮助面板全项目
## 零入口，移动基地顶栏接管（ui-review 便捷性：帮助必须在玩家找得到的地方）
const PANEL_SCENES := {
	"store": "res://scenes/ui/store_panel.tscn",
	"modification": "res://scenes/ui/modification_panel.tscn",
	"affix": "res://scenes/ui/affix_forge_panel.tscn",
	"evolution": "res://scenes/ui/evolution_panel.tscn",
	"growth": "res://scenes/ui/growth_panel.tscn",
	"backpack": "res://scenes/ui/backpack_panel.tscn",
	"intelligence": "res://scenes/ui/intelligence_hub_panel.tscn",
	"collection": "res://scenes/ui/collection_panel.tscn",
	"faction": "res://scenes/ui/faction_panel.tscn",
	"leaderboard": "res://scenes/ui/leaderboard_panel.tscn",
	"help": "res://scenes/ui/help_panel.tscn",
}

const RES_LABELS := [
	["nano_materials", "纳米材料"], ["alloy", "合金"], ["crystal", "晶体"],
	["energy_block", "能量块"], ["star_marrow", "星髓"],
]
const ERA_NAMES := ["I 一战", "II 二战", "III 冷战", "IV 现代", "V 近未来"]

var _era_idx := 3  # 默认 IV 现代；_ready 按战线进度折算覆盖
var _textures := {}
var _era_buttons: Array = []
var _topbar: HBoxContainer
var _image_holder: Control
var _int_bg: TextureRect
var _tex_rect: TextureRect
var _hot_layer: Control
var _caption: Label
var _modal_layer: Control
var _modal_card: PanelContainer = null      # CRT 覆盖层/开机闪挂靠（v26.13 氛围）
var _briefing_layer: Control = null
var _embed_layer: Control
var _embed_wrappers: Dictionary = {}
var _sortie_btn: Button = null              # 出击主按钮（时代主题色跟随）
var _pulse_tween: Tween = null              # 热区呼吸（v26.13）
var _int_shadow: Control = null             # 剖面车底软投影
var _ext_shadow: Control = null             # 外景车底软投影
var _lb_top: Control = null                 # 外景电影黑边（上）
var _lb_bot: Control = null                 # 外景电影黑边（下）

# ── v26.12c 外景/剖面双视图 ──
const EXT_BG_FMT := "res://assets/backgrounds/bg_level_%02d.png"
const TRUCK_SPRITE_FMT := "res://assets/ui/truck_base/truck_tier%d.png"
var _view_mode: String = "interior"
var _view_buttons: Array = []
var _ext_holder: Control
var _ext_bg: TextureRect
var _ext_truck: TextureRect
var _ext_caption: Label
var _caption_base := ""   # v26.19：caption 静态段（行军状态段动态拼接）

# ── v27.13 开场链移植（自废弃 bunker_main.gd 879-1141 平移，深航计划版醒来演出）──
## 漫画开场（comic_intro.tscn）收尾携 META_WAKEUP 切入本场景：
## 黑幕梦呓 → 睁眼见雪原（回眨）→ 三拍闪回 → 画外音 → 钻进基地车 → 相位仪教学三拍。
## 无标记（续档/直进）= 零感知直进基地。
const META_WAKEUP := "bunker_intro_wakeup_pending"
const SNOW_BG_PATH := "res://assets/intro/wakeup_snowfield.png"   # 雪原+基地车+远处黑门（缺图退化）
var _wakeup_active := false
var _wakeup_root: Control = null
var _wakeup_tween: Tween = null

## v26.19 基地管理器入口（行军状态真身；bunker 是懒加载管理器，先 ensure 再取）
func _bunker_mgr() -> Node:
	if ManagerLazyLoader and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	return get_node_or_null("/root/BunkerManager")

func _refresh_caption(_day: int = 0) -> void:
	if _caption == null or not is_instance_valid(_caption):
		return
	_caption.text = _caption_base + _caption_status()

## caption 行军状态段：停靠点 + 燃料 / 行驶中倒计时
func _caption_status() -> String:
	var bm := _bunker_mgr()
	if bm == null:
		return ""
	if bm.is_traveling():
		return " ｜ 行驶中 → 第%d关 · 剩%d天 ｜ 燃料 %d/%d" % [
			int(bm.get_travel_dest()), int(bm.get_travel_days_left()),
			int(bm.get_fuel()), int(bm.get_fuel_cap())]
	return " ｜ 停靠 第%d关 ｜ 燃料 %d/%d" % [
		int(bm.get_parked_level()), int(bm.get_fuel()), int(bm.get_fuel_cap())]

func _ready() -> void:
	DesignTokens.ensure_cjk_fallback()
	# v26.12c：从世界地图切来时未经标题入口的 flush——战线号/资源读数先排空延迟批次
	if SaveManager and SaveManager.has_method("flush_deferred_manager_loads"):
		SaveManager.flush_deferred_manager_loads()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = DesignTokens.COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_topbar()
	_build_image_area()
	_build_exterior_area()
	# 内嵌面板层（真面板容器，位于图区之上、弹层之下）
	_embed_layer = Control.new()
	_embed_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_embed_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_embed_layer)
	# v26.13：入场时代跟战线进度走（进度在哪个时代带，车就停哪个时代）
	_era_idx = clampi((_get_display_level() - 1) / 20, 0, ERAS.size() - 1)
	set_era(_era_idx, false)
	# v26.12c：世界地图卡车点击进入时默认外景（Engine meta "truck_base_view"）
	var initial_view := "interior"
	if Engine.has_meta("truck_base_view"):
		initial_view = String(Engine.get_meta("truck_base_view"))
		Engine.remove_meta("truck_base_view")
	_set_view(initial_view, false)
	# v26.19：行军状态变化（启程/到站/回充/引擎升级）→ caption 燃料段即时刷新
	if not SignalBus.truck_travel_changed.is_connected(_refresh_caption):
		SignalBus.truck_travel_changed.connect(_refresh_caption)
	if not SignalBus.bunker_day_ended.is_connected(_refresh_caption):
		SignalBus.bunker_day_ended.connect(_refresh_caption)
	# 批次③ Task 5：教程按需点播触达面（进入移动基地 = TRUCK_BASE 步）
	var _tpm := get_node_or_null("/root/TutorialProgressionManager")
	if _tpm != null and _tpm.has_method("notify_surface_opened"):
		_tpm.notify_surface_opened("truck_base")
	# v27.13：漫画开场收尾携 wakeup 标记切入 → 播醒来演出（deferred 等全 UI 落位）
	call_deferred("_maybe_play_wakeup")

# ── 顶栏 ──
func _build_topbar() -> void:
	# v26.13：顶栏换战斗 HUD 同款浮板（圆角半透明底板），告别"网页导航条"观感
	var plate := PanelContainer.new()
	plate.set_anchors_preset(Control.PRESET_TOP_WIDE)
	plate.offset_left = 8.0
	plate.offset_right = -8.0
	plate.offset_top = 6.0
	plate.offset_bottom = 46.0
	plate.add_theme_stylebox_override("panel", PanelStyles.make_hud_panel(0.36))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	_topbar = HBoxContainer.new()
	_topbar.add_theme_constant_override("separation", 8)
	plate.add_child(_topbar)

	var title := Label.new()
	title.text = "移动基地 · 装甲卡车驻地"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.91, 0.86, 0.75))
	_topbar.add_child(title)

	# v26.12c：外景/剖面视图切换
	var vg := ButtonGroup.new()
	for vm in [["exterior", "外景"], ["interior", "剖面"]]:
		var vb := Button.new()
		vb.text = String(vm[1])
		vb.toggle_mode = true
		vb.button_group = vg
		vb.focus_mode = Control.FOCUS_NONE
		vb.set_meta("view_mode", String(vm[0]))
		vb.add_theme_font_size_override("font_size", 13)
		_style_chip(vb)
		vb.pressed.connect(_on_view_pressed.bind(String(vm[0])))
		_topbar.add_child(vb)
		_view_buttons.append(vb)

	var era_note := Label.new()
	era_note.text = "驻地："
	era_note.add_theme_font_size_override("font_size", 13)
	era_note.add_theme_color_override("font_color", Color(0.56, 0.53, 0.45))
	_topbar.add_child(era_note)

	var group := ButtonGroup.new()
	for i in ERAS.size():
		var e: Dictionary = ERAS[i]
		var b := Button.new()
		b.text = String(e["label"])
		b.tooltip_text = String(e["zone"])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 13)
		_style_chip(b)
		b.pressed.connect(_on_era_pressed.bind(i))
		_topbar.add_child(b)
		_era_buttons.append(b)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar.add_child(sp)

	# v26.18：战区地图入口——基地此前无法选关（时代 chips 只是换驻地观感，不切关卡），
	# 地图侧本就支持滚轮缩放/拖拽平移/点关卡就地出击，缺的只是这条通路
	var map_btn := Button.new()
	map_btn.text = "🗺 战区地图"
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.add_theme_font_size_override("font_size", 13)
	map_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_btn.tooltip_text = "打开战区地图：滚轮缩放、拖拽移动，点关卡直接出击"
	_style_btn(map_btn, COLOR_CYAN)
	map_btn.pressed.connect(_open_world_map)
	_topbar.add_child(map_btn)

	var sortie := Button.new()
	sortie.text = "▶ 出击"
	sortie.focus_mode = Control.FOCUS_NONE
	sortie.add_theme_font_size_override("font_size", 14)
	sortie.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# v26.30 出击=进战场：顶栏出击直达战斗（战前简报在驾驶室工位，选关在战区地图）
	sortie.tooltip_text = "直接出击当前停靠关；行驶中会提示。战前简报：驾驶室工位"
	_style_btn(sortie, COLOR_CYAN)
	sortie.pressed.connect(_launch_battle)
	_topbar.add_child(sortie)
	_sortie_btn = sortie

	var back := Button.new()
	back.text = "返回标题"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 13)
	_style_btn(back, Color(0.6, 0.56, 0.48))
	back.pressed.connect(_on_back_to_title)
	_topbar.add_child(back)

	# v26.33：帮助入口——移动基地是帮助面板的唯一活入口（战斗屏 v25.3 已收敛删除）
	var help_btn := Button.new()
	help_btn.text = "❓ 车长手册"
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.add_theme_font_size_override("font_size", 13)
	help_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	help_btn.tooltip_text = "系统说明：战斗 / 卡牌成长 / 相位仪 / 势力 / 移动基地 / 地图行军"
	_style_btn(help_btn, Color(0.6, 0.56, 0.48))
	help_btn.pressed.connect(func() -> void: _open_panel("help"))
	_topbar.add_child(help_btn)
	_topbar.move_child(help_btn, back.get_index())

# ── 图区：剖面底图 + 热区层 + 到达字幕 ──
func _build_image_area() -> void:
	_image_holder = Control.new()
	_image_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_holder.offset_top = 48.0
	_image_holder.offset_bottom = -8.0
	_image_holder.offset_left = 8.0
	_image_holder.offset_right = -8.0
	_image_holder.resized.connect(_layout_hotspots)
	add_child(_image_holder)

	# v26.12e：剖面车也要坐在场景里——垫当前时代 zone 的关卡战场背景（与外景同源回退链）
	_int_bg = TextureRect.new()
	_int_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_int_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_int_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_int_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_holder.add_child(_int_bg)

	# v26.13：车底软投影（在车图之下）——车"坐"进背景而不是浮在图上
	_int_shadow = _make_soft_shadow()
	_image_holder.add_child(_int_shadow)

	_tex_rect = TextureRect.new()
	# v6.14: 用自由锚点——布局真身在 _layout_hotspots 手写 position/size（车带 letterbox），
	# PRESET_FULL_RECT 的对边不等锚点会在 _ready 期把手写 size 顶掉并刷引擎警告
	_tex_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_holder.add_child(_tex_rect)

	_hot_layer = Control.new()
	_hot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_holder.add_child(_hot_layer)

	# v26.13：氛围层——全屏暗角 + 漂浮尘埃（动效减弱则不加尘埃）
	_image_holder.add_child(_make_vignette())
	if not DT.is_motion_reduce():
		_image_holder.add_child(_make_dust())

	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_caption.offset_left = 14.0
	_caption.offset_top = -34.0
	_caption.offset_bottom = -10.0
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.89, 0.69))
	_image_holder.add_child(_caption)

	# v26.13(ui-review)：首次进入一句话引导（便捷性：新界面零说明=流失点）
	_maybe_show_truck_intro.call_deferred()

## 首次见到移动基地的一句话说明（show_once 随存档持久化）。
## ⚠️ deferred：_ready 期间 tree.root.add_child 会因"Parent node is busy"失败
##（bunker_main._refresh_reward_bubbles 同款踩坑），key 会被提前标记 seen。
func _maybe_show_truck_intro() -> void:
	# v27.13：醒来演出期间不弹（否则盖在眼睑动画上）；演出收场由 _finish_wakeup 补弹
	if _wakeup_active or Engine.has_meta(META_WAKEUP):
		return
	FeatureUnlockPopup.show_once("truck_base_intro", "移动基地 · 指南",
		"外景看驻地，剖面干活——车厢里每个发光框都挂着常显工位牌，一眼直达。行军规则：顶栏「战区地图」点任意节点出车（耗燃料×地形，回程半价），出发后实时行军（1 天≈12 秒，离线也计时）；燃料自动回复（离线也涨），睡觉快充、或在发电机工位用能量块 1:1 充能；停哪才能打哪，行驶中无法出击。")

# ── 时代切换 ──
## 贴图双通道：优先走导入管线 load()；未导入（headless 首跑/新机克隆）时
## 用 Image.load_from_file 直读文件兜底——剖面图 1312×736 静态底图，无需压缩纹理收益
func _load_era_texture(path: String) -> Texture2D:
	var t: Texture2D = load(path)
	if t == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			t = ImageTexture.create_from_image(img)
	return t

func _on_era_pressed(i: int) -> void:
	if i == _era_idx:
		return
	set_era(i, true)

func set_era(i: int, animate: bool) -> void:
	_era_idx = clampi(i, 0, ERAS.size() - 1)
	var e: Dictionary = ERAS[_era_idx]
	var id: String = String(e["id"])
	if not _textures.has(id):
		_textures[id] = _load_era_texture(String(e["tex"]))
	_tex_rect.texture = _textures[id]
	if _int_bg != null:
		# v27.12: 内背景先查 _textures 缓存（key=路径），未命中才加载并存入
		# （原每次切时代直调 _load_era_texture 重读，与上方主图同款缓存写法）
		var int_bg_path := _ext_bg_path(int(e["level"]))
		if not _textures.has(int_bg_path):
			_textures[int_bg_path] = _load_era_texture(int_bg_path)
		_int_bg.texture = _textures[int_bg_path]
	for b_i in _era_buttons.size():
		_era_buttons[b_i].set_pressed_no_signal(b_i == _era_idx)
	_caption_base = "驻防地域 · %s（%s）· 战线第 %d 关" % [String(e["zone"]), String(e["label"]), _get_display_level()]
	_refresh_caption()
	_rebuild_hotspots()
	_apply_era_theme()
	if _view_mode == "exterior":
		_refresh_exterior(false)
	if animate:
		_play_sfx("panel_open", 0.7, 1.15)
		_image_holder.modulate.a = 0.0
		_image_holder.position.x = 90.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_image_holder, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)
		tw.tween_property(_image_holder, "position:x", 0.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## v26.13 时代主题：accent 一处换，chips/出击/热区/caption/外景 caption 全跟
func _era_accent() -> Color:
	return ERAS[_era_idx].get("accent", COLOR_CYAN)

func _apply_era_theme() -> void:
	var accent: Color = _era_accent()
	# 时代 chips 选中态染主题色
	for b in _era_buttons:
		var sb_on: StyleBoxFlat = b.get_theme_stylebox("pressed") as StyleBoxFlat
		if sb_on != null:
			sb_on = sb_on.duplicate()
			sb_on.border_color = accent
			sb_on.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
			b.add_theme_stylebox_override("pressed", sb_on)
		b.add_theme_color_override("font_pressed_color", accent.lerp(Color.WHITE, 0.35))
	# 出击主按钮 = 时代色实心
	if _sortie_btn != null:
		var styles: Dictionary = PanelStyles.make_button_styles(accent, "solid")
		for key in ["normal", "hover", "pressed", "disabled", "focus"]:
			_sortie_btn.add_theme_stylebox_override(key, styles[key])
		_sortie_btn.add_theme_color_override("font_color", Color(0.06, 0.08, 0.09))
		_sortie_btn.add_theme_color_override("font_hover_color", Color(0.03, 0.05, 0.06))
		_sortie_btn.add_theme_color_override("font_pressed_color", Color(0.03, 0.05, 0.06))
	# 双 caption 染主题色（向白混 30% 保暗底可读）
	var cap_col := accent.lerp(Color.WHITE, 0.30)
	_caption.add_theme_color_override("font_color", cap_col)
	_ext_caption.add_theme_color_override("font_color", cap_col)
	# 热区呼吸（动效减弱则静态常显）
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	_hot_layer.modulate.a = 1.0
	if not DT.is_motion_reduce():
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_hot_layer, "modulate:a", 0.80, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(_hot_layer, "modulate:a", 1.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _rebuild_hotspots() -> void:
	for c in _hot_layer.get_children():
		# remove_child 立即出树：queue_free 的节点要等帧末才消失，会把新按钮挤出
		# _layout_hotspots 的对位循环（症状：切时代后新热区 size=0，点不到）
		_hot_layer.remove_child(c)
		c.queue_free()
	var id: String = String(ERAS[_era_idx]["id"])
	var hs: Array = HOTSPOTS.get(id, [])
	for h in hs:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s · %s" % [String(h["name"]), String(h["hint"])]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_on_hotspot.bind(h))
		_hot_layer.add_child(b)
		_style_hotspot(b)
		# v26.13：悬停工位牌 + v26.17：常显短牌——玩家不悬停也要一眼认出工位功能
		#（ui-review 便捷性：短牌=功能关键词常驻，悬停展开"全名 · 功能"完整情报）
		var tag := Label.new()
		var full_text := "%s · %s" % [String(h["name"]), String(h["hint"])]
		var short_text := _hotspot_tag(h)
		tag.text = short_text
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.96, 0.97, 0.93))
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.03, 0.05, 0.06, 0.92)
		tsb.border_color = _era_accent()
		tsb.set_border_width_all(1)
		tsb.set_corner_radius_all(4)
		tsb.content_margin_left = 7
		tsb.content_margin_right = 7
		tsb.content_margin_top = 3
		tsb.content_margin_bottom = 3
		tag.add_theme_stylebox_override("normal", tsb)
		tag.position = Vector2(2, 2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		b.set_meta("hot_tag", tag)
		b.mouse_entered.connect(func() -> void:
			tag.text = full_text
			_play_sfx("button_hover", 0.5))
		b.mouse_exited.connect(func() -> void:
			tag.text = short_text)
	_layout_hotspots()

## 工位常显短牌文案：从 kind/key/name 语义字段推导，五时代同功能同叫法（勿逐时代手抄）
func _hotspot_tag(h: Dictionary) -> String:
	match String(h.get("kind", "info")):
		"sortie":
			return "出击"
		"terminal":
			return "统计"
		"sleep":
			return "睡觉"
		"panel":
			return {
				"intelligence": "情报", "store": "补给", "backpack": "卡仓",
				"modification": "改造", "evolution": "制造",
			}.get(String(h.get("key", "")), "工位")
		_:
			return "医疗" if String(h.get("name", "")).contains("医疗") else "电力"

func _layout_hotspots() -> void:
	if _tex_rect == null or _tex_rect.texture == null:
		return
	var ts: Vector2 = _tex_rect.texture.get_size()
	var area: Vector2 = _image_holder.size
	if area.x <= 0.0 or area.y <= 0.0 or ts.x <= 0.0 or ts.y <= 0.0:
		return
	# v26.12e：剖面车在背景场景中占位——只占 holder 中下部一条带（x 8%~92%、y 30%~92%），
	# 不再铺满整屏（用户：在背景中不要太大）；_tex_rect 与热区都按这条带定位
	var band_x: float = area.x * 0.08
	var band_y: float = area.y * 0.30
	var band_w: float = area.x * 0.84
	var band_h: float = area.y * 0.62
	var s: float = minf(band_w / ts.x, band_h / ts.y)
	var dw: float = ts.x * s
	var dh: float = ts.y * s
	var ox: float = band_x + (band_w - dw) * 0.5
	var oy: float = band_y + (band_h - dh) * 0.5
	_tex_rect.position = Vector2(ox, oy)
	_tex_rect.size = Vector2(dw, dh)
	var buttons := _hot_layer.get_children()
	var id: String = String(ERAS[_era_idx]["id"])
	var hs: Array = HOTSPOTS.get(id, [])
	for i in mini(buttons.size(), hs.size()):
		var r: Array = hs[i]["r"]
		var b: Button = buttons[i]
		b.position = Vector2(ox + float(r[0]) * dw, oy + float(r[1]) * dh)
		b.size = Vector2(float(r[2]) * dw, float(r[3]) * dh)
	_resolve_tag_overlaps(buttons)
	# v26.13：车底软投影跟随车带（贴图尺寸在本次布局里刚算好）
	if _int_shadow != null:
		_int_shadow.position = Vector2(ox + dw * 0.06, oy + dh - 14.0)
		_int_shadow.size = Vector2(dw * 0.88, 30.0)

## v26.17：常显短牌防重叠——工位框允许交叠（卡牌墙×工作台），牌撞牌时后者向下让位。
## 每次布局先归位 (2,2) 再重算，窗口缩放/换时代都收敛到同一结果。
func _resolve_tag_overlaps(buttons: Array) -> void:
	var placed: Array[Rect2] = []
	for b in buttons:
		if not b.has_meta("hot_tag"):
			continue
		var tag: Label = b.get_meta("hot_tag") as Label
		if tag == null:
			continue
		tag.position = Vector2(2, 2)
		var ms := tag.get_combined_minimum_size()
		for _step in 6:
			var rect := Rect2((b as Control).position + tag.position, ms)
			var hit := false
			for pr in placed:
				if rect.intersects(pr):
					hit = true
					break
			if not hit:
				break
			tag.position.y += ms.y + 4.0
		placed.append(Rect2((b as Control).position + tag.position, ms))

# ── v26.13 氛围小件 ──

## 径向渐变软投影（黑心→透明），压扁即"车底影子"
func _make_soft_shadow() -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 64
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## 全屏暗角（shader 压边缘，视线收中间）
func _make_vignette() -> Control:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/screen_vignette.gdshader")
	rect.material = mat
	return rect

## 漂浮尘埃（极淡暖白微粒缓慢上飘，画面有"空气"）
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 16
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(620, 300)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(1.0, 0.95, 0.8, 0.15)
	p.position = Vector2(632, 400)
	return p

# ── 热区点击 ──
func _on_hotspot(h: Dictionary) -> void:
	_play_sfx("button")
	match String(h.get("kind", "info")):
		"sortie":
			_open_sortie()
		"terminal":
			_open_terminal()
		"panel":
			_open_panel(String(h.get("key", "")))
		"sleep":
			_on_sleep()
		_:
			# v26.19：发电机/动力类工位 → 燃料/引擎管理卡（行军经济主界面）
			if String(h.get("rooms", "")).contains("reactor"):
				_open_fuel_station_card()
			else:
				_open_card("%s · %s" % [String(h["name"]), String(h["hint"])], String(h.get("rooms", "")),
					"工位卡片占位（info 类工位无常驻面板，正式版在基地 HUD 呈现产出/状态）。")

# ── 出击简报 ──
func _open_sortie() -> void:
	_close_modal()
	_close_briefing()
	# v26.19 停靠门控：行驶中锁定出击；出击对象=停靠关（停哪打哪）
	var bm := _bunker_mgr()
	if bm != null and bm.is_traveling():
		_play_sfx("error", 0.7)
		_open_card("行驶中", "—", "卡车正在前往第 %d 关（剩 %d 天 ≈ %d 分钟，实时行军、离线也计时）。\n到站停靠后才能出击。" % [
			int(bm.get_travel_dest()), int(bm.get_travel_days_left()),
			int(bm.get_travel_days_left())])
		return
	if bm != null and GameManager != null:
		GameManager.set_current_level(int(bm.get_parked_level()))
	_play_sfx("panel_open", 0.6)
	var level := _get_display_level()
	var era_i := clampi((level - 1) / 20 + 1, 1, 5)
	var in_era := (level - 1) % 20 + 1
	var e: Dictionary = ERAS[era_i - 1]
	var lname := String(LevelInformation.get_shared().get_level_display_name(level))
	if lname == "":
		lname = String(e["zone"])
	var desc := String(LevelInformation.get_shared().get_level_info(level).get("description", ""))
	var theme: Dictionary = LevelTacticalThemes.get_theme_display(level)
	# 敌方档位（时代内 1-5 新兵 / 6-11 老兵 / 12-17 精英 / 18-20 传奇）
	var tier_name := "新兵"
	if in_era >= 18:
		tier_name = "传奇"
	elif in_era >= 12:
		tier_name = "精英"
	elif in_era >= 6:
		tier_name = "老兵"
	# 敌我兵力（自定义布局 rows×enemy_cols；缺省 3×3）
	var layout: Dictionary = LevelBattleLayouts.get_for_level(level)
	var rows := int(layout.get("rows", 3))
	var e_cols := int(layout.get("enemy_cols", 3))
	var enemy_slots := rows * e_cols
	var layout_note := LevelBattleLayouts.get_note(level)
	var my_slots := 1
	var my_cards := 0
	var card_names: Array = []
	if PhaseInstrumentManager:
		my_slots = maxi(int(PhaseInstrumentManager.get_green_slot_count()), 1)
		for lo in PhaseInstrumentManager.get_loadouts():
			my_cards += 1
			if card_names.size() < 5:
				card_names.append(String(lo["platform"].display_name))
	var day := 1
	if DayClock:
		day = int(DayClock.current_day)

	_briefing_layer = Control.new()
	_briefing_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_briefing_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing_layer.add_child(dim)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 28.0
	frame.offset_right = -28.0
	frame.offset_top = 18.0
	frame.offset_bottom = -18.0
	# v26.13：游戏同款纹理底 + 主题色（替代手写平灰框）
	var fsb: StyleBoxTexture = PanelStyles.make_panel_frame_textured(_era_accent())
	fsb.content_margin_left = 18
	fsb.content_margin_right = 18
	fsb.content_margin_top = 14
	fsb.content_margin_bottom = 14
	frame.add_theme_stylebox_override("panel", fsb)
	_briefing_layer.add_child(frame)
	# v26.13：四角 L 形军用角标（AC7 简报语言的第一识别件）
	var brackets := Control.new()
	brackets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brackets.draw.connect(_draw_brief_brackets.bind(brackets))
	frame.add_child(brackets)
	brackets.resized.connect(func() -> void: brackets.queue_redraw())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	# v26.13：顶部警示斜纹条（军用简报语言）
	var hazard := Control.new()
	hazard.custom_minimum_size = Vector2(0, 6)
	hazard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hazard.draw.connect(_draw_hazard_strip.bind(hazard))
	hazard.resized.connect(func() -> void: hazard.queue_redraw())
	root.add_child(hazard)

	# ── 顶栏：作战简报 · 关卡 · 时代 · 天数 ──
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var h3 := Label.new()
	h3.text = "▍作战简报 · 第 %d 关「%s」 · %s · 第 %d 天" % [level, lname, String(e["label"]), day]
	h3.add_theme_font_size_override("font_size", 18)
	h3.add_theme_color_override("font_color", _era_accent().lerp(Color.WHITE, 0.25))
	top.add_child(h3)
	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tsp)
	var back := Button.new()
	back.text = "返回基地"
	back.focus_mode = Control.FOCUS_NONE
	_style_btn(back, Color(0.6, 0.56, 0.48))
	back.pressed.connect(_close_briefing)
	top.add_child(back)

	root.add_child(HSeparator.new())

	# ── 中区三栏 ──
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)

	# 左栏：任务目标 + 环境四维 + 战术主题
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override("separation", 6)
	mid.add_child(left)
	left.add_child(_brief_section("任务目标"))
	var dl := Label.new()
	dl.text = desc if desc != "" else "击溃敌军，推进战线。"
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.add_theme_font_size_override("font_size", 13)
	left.add_child(dl)
	left.add_child(_brief_section("环境四维（本场实际乘区）"))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	var envs: Array = BattleEnvEffects.describe_level_env(level)
	if envs.is_empty():
		chips.add_child(_make_chip("无特殊环境乘区"))
	else:
		for env in envs:
			chips.add_child(_make_chip(String(env)))
	left.add_child(chips)
	left.add_child(_brief_section("战术主题"))
	var tl := Label.new()
	tl.text = "%s\n威胁：%s\n%s" % [String(theme.get("name", "")), String(theme.get("threat", "")), String(theme.get("advice", ""))]
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	left.add_child(tl)

	mid.add_child(VSeparator.new())

	# 中栏：战线沙盘（五时代进度 + 本关红标）
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	mid.add_child(center)
	center.add_child(_brief_section("战线沙盘"))
	if LevelProgressManager and LevelProgressManager.has_method("get_era_progress"):
		for era in range(1, 6):
			var pr: Dictionary = LevelProgressManager.get_era_progress(era)
			var done := int(pr.get("completed", 0))
			var total := int(pr.get("total", 20))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var nm := Label.new()
			nm.text = ERA_NAMES[era - 1]
			nm.custom_minimum_size = Vector2(72, 0)
			nm.add_theme_font_size_override("font_size", 12)
			nm.add_theme_color_override("font_color", Color(0.56, 0.53, 0.45))
			row.add_child(nm)
			var bar := ProgressBar.new()
			bar.min_value = 0
			bar.max_value = total
			bar.value = done
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(180, 12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var num := Label.new()
			num.text = "%d/%d" % [done, total]
			num.add_theme_font_size_override("font_size", 12)
			row.add_child(num)
			if level >= (era - 1) * 20 + 1 and level <= era * 20:
				var mk := Label.new()
				mk.text = "◀ 本关 · 第 %d 关" % level
				mk.add_theme_font_size_override("font_size", 12)
				mk.add_theme_color_override("font_color", _era_accent())
				row.add_child(mk)
			center.add_child(row)
	var arrow := Label.new()
	arrow.text = "我方箭头 ──▶ 红标阵地（波次来向见战内预警）"
	arrow.add_theme_font_size_override("font_size", 12)
	arrow.add_theme_color_override("font_color", Color(0.45, 0.42, 0.36))
	center.add_child(arrow)
	# v26.13(gameplay)：出击编队卡行——本场带什么卡/等级一目了然（补决策信息+中部空置）
	center.add_child(_brief_section("出击编队"))
	var load_flow := HFlowContainer.new()
	load_flow.add_theme_constant_override("h_separation", 6)
	load_flow.add_theme_constant_override("v_separation", 4)
	center.add_child(load_flow)
	var _loadouts: Array = PhaseInstrumentManager.get_loadouts() if PhaseInstrumentManager != null else []
	for lo2 in _loadouts:
		var plat = lo2.get("platform")
		var nm2 := "?"
		var lv2 := 0
		if plat != null:
			var dn = plat.get("display_name")
			if dn != null:
				nm2 = String(dn)
			var lvv = plat.get("card_level")
			if lvv != null:
				lv2 = maxi(int(lvv), 1)  # 未上阵卡 level 存 0，显示钳 1（等级轴 Lv1-30）
		load_flow.add_child(_loadout_chip("%s Lv.%d" % [nm2, lv2], false))
	var empty_n: int = maxi(my_slots - _loadouts.size(), 0)
	for e_i in range(mini(empty_n, 9)):
		load_flow.add_child(_loadout_chip("空槽", true))
	if _loadouts.is_empty():
		var none_l := Label.new()
		none_l.text = "（未装备任何平台卡——点「更换装备」去背包绿槽装机）"
		none_l.add_theme_font_size_override("font_size", 12)
		none_l.add_theme_color_override("font_color", Color(0.8, 0.5, 0.4))
		load_flow.add_child(none_l)

	mid.add_child(VSeparator.new())

	# 右栏：敌情预告 + 兵力对比
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 6)
	mid.add_child(right)
	right.add_child(_brief_section("敌情预告"))
	var tier_l := Label.new()
	tier_l.text = "敌方档位：%s档（时代内第 %d 关）" % [tier_name, in_era]
	tier_l.add_theme_font_size_override("font_size", 13)
	right.add_child(tier_l)
	var slot_l := Label.new()
	slot_l.text = "敌方阵地：%d 行 × %d 列 = %d 槽" % [rows, e_cols, enemy_slots]
	slot_l.add_theme_font_size_override("font_size", 13)
	right.add_child(slot_l)
	if layout_note != "":
		var ln := Label.new()
		ln.text = "题面：" + layout_note
		ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ln.add_theme_font_size_override("font_size", 12)
		ln.add_theme_color_override("font_color", Color(0.56, 0.72, 0.56))
		right.add_child(ln)
	right.add_child(_brief_section("兵力对比"))
	var cmp := HBoxContainer.new()
	cmp.custom_minimum_size = Vector2(0, 14)
	cmp.add_theme_constant_override("separation", 2)
	var mine := ColorRect.new()
	mine.color = Color(0.0, 0.9, 1.0, 0.75)
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine.size_flags_stretch_ratio = float(my_slots)
	cmp.add_child(mine)
	var theirs := ColorRect.new()
	theirs.color = Color(1.0, 0.48, 0.18, 0.7)
	theirs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theirs.size_flags_stretch_ratio = float(enemy_slots)
	cmp.add_child(theirs)
	right.add_child(cmp)
	var cmp_l := Label.new()
	cmp_l.text = "我方 %d 槽 ▏敌 %d 槽" % [my_slots, enemy_slots]
	cmp_l.add_theme_font_size_override("font_size", 12)
	right.add_child(cmp_l)

	root.add_child(HSeparator.new())

	# ── 底栏：出击配置 + 更换装备 + 出击 ──
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	var cfg := Label.new()
	var cfg_cards := "，".join(card_names) if not card_names.is_empty() else "（空——先去背包装备平台卡）"
	cfg.text = "出击配置 %d/%d：%s" % [my_cards, my_slots, cfg_cards]
	cfg.add_theme_font_size_override("font_size", 13)
	cfg.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	bottom.add_child(cfg)
	var bsp := Control.new()
	bsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bsp)
	# v26.18：简报内就地换关——省"返回基地→战区地图"两步（便捷性：一步直达）
	var pick := Button.new()
	pick.text = "选关"
	pick.focus_mode = Control.FOCUS_NONE
	pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_btn(pick, COLOR_CYAN)
	pick.pressed.connect(func() -> void:
		_close_briefing()
		_open_world_map())
	bottom.add_child(pick)
	var swap := Button.new()
	swap.text = "更换装备"
	swap.focus_mode = Control.FOCUS_NONE
	_style_btn(swap, Color(0.6, 0.56, 0.48))
	swap.pressed.connect(func() -> void:
		_close_briefing()
		_open_panel("backpack"))
	bottom.add_child(swap)
	var go := Button.new()
	go.text = "▶ 出 击 ◀"
	go.focus_mode = Control.FOCUS_NONE
	_style_btn(go, COLOR_AMBER)
	go.add_theme_font_size_override("font_size", 14)
	go.pressed.connect(_launch_battle)
	bottom.add_child(go)

func _brief_section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", _era_accent())
	return l

## v26.13：简报四角 L 形角标（bind 挂 control 自身，resize 由调用侧 queue_redraw）
func _draw_brief_brackets(ctrl: Control) -> void:
	var s := ctrl.size
	var L := 26.0
	var col := _era_accent()
	col.a = 0.85
	ctrl.draw_polyline(PackedVector2Array([Vector2(1, L), Vector2(1, 1), Vector2(L, 1)]), col, 2.5)
	ctrl.draw_polyline(PackedVector2Array([Vector2(s.x - L, 1), Vector2(s.x - 1, 1), Vector2(s.x - 1, L)]), col, 2.5)
	ctrl.draw_polyline(PackedVector2Array([Vector2(1, s.y - L), Vector2(1, s.y - 1), Vector2(L, s.y - 1)]), col, 2.5)
	ctrl.draw_polyline(PackedVector2Array([Vector2(s.x - L, s.y - 1), Vector2(s.x - 1, s.y - 1), Vector2(s.x - 1, s.y - L)]), col, 2.5)

## v26.13：警示斜纹条（主题色 45° 斜纹，军用简报封条语言）
func _draw_hazard_strip(ctrl: Control) -> void:
	var s := ctrl.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	ctrl.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.05, 1.0))
	var col := _era_accent()
	col.a = 0.45
	var w := 7.0
	var x := -s.y
	while x < s.x:
		var pts := PackedVector2Array([
			Vector2(x, s.y), Vector2(x + s.y, 0.0),
			Vector2(x + s.y + w, 0.0), Vector2(x + w, s.y)])
		ctrl.draw_colored_polygon(pts, col)
		x += w * 3.0

func _close_briefing() -> void:
	if _briefing_layer != null:
		_briefing_layer.queue_free()
		_briefing_layer = null

func _launch_battle() -> void:
	_play_sfx("button")
	# v26.19：出击=停靠关（停哪打哪；简报路径已同步，此处防御兜底）
	var bm := _bunker_mgr()
	# v26.30：行驶中拦截——出击=进战场或明确提示，不落地歧义分支
	if bm != null and bm.is_traveling():
		_play_sfx("error", 0.7)
		_open_card("行驶中", "—", "卡车正在前往第 %d 关（剩 %d 天，实时行军、离线也计时）。\n到站停靠后才能出击。" % [
			int(bm.get_travel_dest()), int(bm.get_travel_days_left())])
		return
	if bm != null and GameManager != null and not bm.is_traveling():
		GameManager.set_current_level(int(bm.get_parked_level()))
	# 与 bunker_main._on_go_to_battle 同链：main 场景读 launch_from_bunker 直入当前关卡战斗
	# （v26.30：main 侧落地即开打——_auto_battle_from_truck_sortie）
	Engine.set_meta("launch_from_bunker", true)
	# 批次③ Task 1：出征过场拍点——main 侧 run_start_battle_sequence 头部消费（一次性）
	Engine.set_meta(SortieInterstitial.META_PENDING, true)
	SceneTransition.change(get_tree(), SCENE_MAIN)

## v26.18：打开战区地图选关（自由缩放/拖拽 + 点击关卡就地操作）。
## 从卡车进图的标记让地图的 ESC/返回键回本基地，而不是 main 战斗场景。
func _open_world_map() -> void:
	# 批次③ Task 5：教程按需点播触达面（战区地图步）
	var _tpm := get_node_or_null("/root/TutorialProgressionManager")
	if _tpm != null and _tpm.has_method("notify_surface_opened"):
		_tpm.notify_surface_opened("world_map")
	_play_sfx("button")
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	Engine.set_meta("world_map_from_truck", true)
	SceneTransition.change(get_tree(), "res://scenes/world_map.tscn")

func _on_back_to_title() -> void:
	_play_sfx("button")
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	SceneTransition.change(get_tree(), SCENE_TITLE)

# ── 弹层壳 ──
func _modal_shell() -> VBoxContainer:
	_close_modal()
	_modal_layer = Control.new()
	_modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_modal())
	_modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(center)
	var card := PanelContainer.new()
	# v26.13：换游戏同款九宫格渐变纹理底（时代主题色），替代手写平灰 StyleBox
	var sb: StyleBoxTexture = PanelStyles.make_panel_frame_textured(_era_accent())
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	_modal_card = card
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	# 开机闪：亮起入场 + 面板音（动效减弱则直接出现）
	_play_sfx("panel_open", 0.6)
	if not DT.is_motion_reduce():
		card.modulate = Color(1.5, 1.5, 1.5, 0.0)
		var tw := create_tween()
		tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return v

## v26.13：弹卡标题行（签名竖条 + 亮标题 + 主题色分隔线），替代裸 Label
func _modal_header(v: VBoxContainer, title_text: String, subtitle := "") -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", PanelStyles.make_title_accent_bar(_era_accent()))
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_FILL
	head.add_child(bar)
	var hbox := VBoxContainer.new()
	head.add_child(hbox)
	var h3 := Label.new()
	h3.text = title_text
	h3.add_theme_font_size_override("font_size", 16)
	h3.add_theme_color_override("font_color", _era_accent().lerp(Color.WHITE, 0.25))
	hbox.add_child(h3)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(0.55, 0.58, 0.60))
		hbox.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(_era_accent().r, _era_accent().g, _era_accent().b, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)

func _open_card(title_text: String, rooms: String, body_text: String) -> void:
	var v := _modal_shell()
	_modal_header(v, title_text)
	if rooms != "":
		var sub := Label.new()
		sub.text = "对应基地房间：" + rooms
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(0.50, 0.55, 0.52))
		v.add_child(sub)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(460, 0)
	body.add_theme_font_size_override("font_size", 13)
	v.add_child(body)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	_style_btn(close, Color(0.6, 0.56, 0.48))
	close.pressed.connect(_close_modal)
	foot.add_child(close)
	v.add_child(foot)

func _close_modal() -> void:
	if _modal_layer != null:
		_modal_layer.queue_free()
		_modal_layer = null
		_modal_card = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# v26.13(ui-review)：ESC 关最上层弹层——模态卡 > 简报 > 内嵌面板
		#（不能默认玩家知道要去找 X，包容性铁律）
		if _modal_layer != null:
			_close_modal()
			get_viewport().set_input_as_handled()
		elif _briefing_layer != null:
			_close_briefing()
			get_viewport().set_input_as_handled()
		elif _close_top_embed_panel():
			get_viewport().set_input_as_handled()

## v26.13(ui-review)：ESC 关闭最上层可见的内嵌面板；有则 true
func _close_top_embed_panel() -> bool:
	var top: Control = null
	for key in _embed_wrappers:
		var wr: Control = _embed_wrappers[key]["wrapper"]
		if wr.visible:
			top = wr  # 字典按插入序，最后一个可见的即最上层
	if top != null:
		top.visible = false
		return true
	return false

# ── 样式小件 ──
func _make_chip(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.53, 0.66, 0.51))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.07)
	sb.border_color = Color(0.24, 0.35, 0.24)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", sb)
	return l

## v26.13(gameplay)：简报出击编队 chip（有卡=青字亮框 / 空槽=暗灰）
func _loadout_chip(text: String, empty: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	if empty:
		l.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
		sb.bg_color = Color(0.06, 0.06, 0.06, 0.8)
		sb.border_color = Color(0.3, 0.28, 0.24, 0.6)
	else:
		l.add_theme_color_override("font_color", Color(0.74, 0.94, 0.96))
		sb.bg_color = Color(0.05, 0.14, 0.16, 0.85)
		sb.border_color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.55)
	l.add_theme_stylebox_override("normal", sb)
	return l

func _style_btn(b: Button, accent: Color) -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	sb_n.border_color = accent
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(6)
	sb_n.content_margin_left = 12
	sb_n.content_margin_right = 12
	sb_n.content_margin_top = 5
	sb_n.content_margin_bottom = 5
	b.add_theme_stylebox_override("normal", sb_n)
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(accent.r, accent.g, accent.b, 0.30)
	b.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb_n.duplicate()
	sb_p.bg_color = Color(accent.r, accent.g, accent.b, 0.40)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9))

func _style_chip(b: Button) -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.10, 0.10, 0.08)
	sb_n.border_color = COLOR_LINE
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(5)
	sb_n.content_margin_left = 9
	sb_n.content_margin_right = 9
	sb_n.content_margin_top = 3
	sb_n.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb_n)
	var sb_on := sb_n.duplicate()
	sb_on.border_color = COLOR_CYAN
	sb_on.bg_color = Color(0.05, 0.16, 0.18)
	b.add_theme_stylebox_override("pressed", sb_on)
	var sb_h := sb_n.duplicate()
	sb_h.border_color = Color(0.48, 0.40, 0.22)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70))
	b.add_theme_color_override("font_pressed_color", Color(0.74, 0.94, 0.96))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85))

func _style_hotspot(b: Button) -> void:
	# v26.13：热区可见化——常显主题色描边（原 0.30 alpha 实测不可见，玩家无从发现可点）
	var accent: Color = _era_accent()
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(accent.r, accent.g, accent.b, 0.06)
	sb_n.border_color = Color(accent.r, accent.g, accent.b, 0.50)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", sb_n)
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	sb_h.border_color = accent
	sb_h.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb_n.duplicate()
	sb_p.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
	b.add_theme_stylebox_override("pressed", sb_p)

func _play_sfx(sound_name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(sound_name, volume, pitch)

# ───────────────────── v26.12b 接线：真战线号 ─────────────────────

## 显示用战线号：与出击同源——GameManager.current_level（地图标记/简报/外景三处一致）
func _get_display_level() -> int:
	var lv := 0
	if GameManager != null:
		lv = int(GameManager.get("current_level"))
	if lv < 1 and LevelProgressManager and LevelProgressManager.has_method("get_max_unlocked_level"):
		lv = int(LevelProgressManager.get_max_unlocked_level())
	return maxi(lv, 1)

# ───────────────────── v26.12b 接线：内嵌真面板（复刻 bunker_main 539-615 链） ─────────────────────

func _open_panel(panel_id: String) -> void:
	# 批次③ Task 5：教程按需点播触达面（工位面板首触，键名与 SURFACE_FOR_STEP 对齐）
	var _tpm_panel := get_node_or_null("/root/TutorialProgressionManager")
	if _tpm_panel != null and _tpm_panel.has_method("notify_surface_opened"):
		_tpm_panel.notify_surface_opened(panel_id)
	var wrapper := _ensure_panel_wrapper(panel_id)
	if wrapper == null:
		_open_card("面板不可用", "", "EMBEDDED_PANELS['%s'] 加载失败（见日志）。" % panel_id)
		return
	wrapper.visible = true
	# 批次1：收口统一开合（原 visible 硬切无声）——wrapper 结构与 main overlay 同构
	#（全屏 wrapper + EmbedCenter 内容层），PanelAnim 直接适用；开合音对齐 main。
	PanelAnim.open(wrapper)
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("panel_open")
	var p: Control = _embed_wrappers[panel_id]["panel"]
	# 与 main.gd _open_overlay 同约定：on_overlay_opened → refresh 顺序尝试
	# （store 等面板的商品列表在 on_overlay_opened 拆帧构建，_ready 只建骨架）
	if p.has_method("on_overlay_opened"):
		p.call("on_overlay_opened")
	elif p.has_method("refresh"):
		p.call("refresh")
	# v26.33：自隐藏面板（help_panel 在 _ready 里 visible=false + modulate 归零，
	# 嵌入包装链只切 wrapper 可见性）——首次打开补调 show_panel 才真显示
	#（旧基地 help 嵌入即栽在此：wrapper 亮了面板本体还黑着）
	# v6.14 修复：原"零参签名"检测 args.is_empty() 把 help_panel.show_panel(_card=null)
	# 这类"1 个可选参"误判成需参签名，show_panel 永不执行 → 车长手册打开后恒黑屏空壳。
	# 现按真实参数个数分流：零参直接调；有参（可选/必填）一律传 null（两场景面板
	# 的既有契约，main.gd _notify_panel_opened 同款）。守卫 not p.visible 保留：
	# 只补自隐藏面板，非自隐藏面板行为与 v26.33 前完全一致。
	if p.has_method("show_panel") and not p.visible:
		for _m in p.get_method_list():
			if _m["name"] != "show_panel":
				continue
			if (_m.get("args", []) as Array).is_empty():
				p.call("show_panel")
			else:
				p.call("show_panel", null)
			break

func _ensure_panel_wrapper(panel_id: String) -> Control:
	if _embed_wrappers.has(panel_id):
		return _embed_wrappers[panel_id]["wrapper"]
	var path: String = String(PANEL_SCENES.get(panel_id, ""))
	if path == "" or not path.ends_with(".tscn"):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[TruckBase] 嵌入面板加载失败: " + path)
		return null
	var panel: Control = packed.instantiate()
	var wrapper := Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(dim)
	var center := CenterContainer.new()
	center.name = "EmbedCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(center)
	center.add_child(panel)
	if panel.has_signal("closed"):
		# 批次1：统一淡出 + 关闭音（与 _open_panel 开侧对称）
		panel.closed.connect(func() -> void:
			PanelAnim.close(wrapper)
			if SignalBus and SignalBus.has_signal("play_sound"):
				SignalBus.play_sound.emit("panel_close")
		)
	_embed_layer.add_child(wrapper)
	_embed_wrappers[panel_id] = {"wrapper": wrapper, "panel": panel}
	# 背包内嵌随行相位仪栏（bunker_main 619 的简化版：固定内容带 -86，无动态重排）
	if panel_id == "backpack":
		_attach_embed_instrument_bar(wrapper, center, panel)
	return wrapper

func _attach_embed_instrument_bar(wrapper: Control, center: Control, bp: Control) -> void:
	if wrapper.has_node("EmbedInstrumentBar"):
		return
	var packed: PackedScene = load(INSTRUMENT_BAR_SCENE)
	if packed == null:
		push_error("[TruckBase] 相位仪栏场景加载失败: " + INSTRUMENT_BAR_SCENE)
		return
	var bar: Control = packed.instantiate()
	bar.name = "EmbedInstrumentBar"
	wrapper.add_child(bar)
	var menu_btn: Node = bar.get_node_or_null("Margin/HBox/MenuBtn")
	if menu_btn != null:
		menu_btn.visible = false
	center.offset_bottom = -86.0
	if bar.has_signal("phase_level_label_clicked"):
		bar.phase_level_label_clicked.connect(func() -> void:
			if bp != null and is_instance_valid(bp) and bp.has_method("switch_to_phase_instruments_tab"):
				bp.switch_to_phase_instruments_tab())
	# v26.13 修复：贴底锚定此前缺失——栏按场景默认锚点落在左上角，盖住背包标题/关闭按钮。
	# 与 bunker_main._layout_embed_instrument_bar 同构：栏贴底全出血，内容带按实测高让位。
	_layout_embed_instrument_bar.call_deferred(bar, wrapper)
	if not bar.minimum_size_changed.is_connected(_on_embed_bar_min_size_changed):
		bar.minimum_size_changed.connect(_on_embed_bar_min_size_changed.bind(bar, wrapper))

func _on_embed_bar_min_size_changed(bar: Control, wrapper: Control) -> void:
	_layout_embed_instrument_bar(bar, wrapper)

func _layout_embed_instrument_bar(bar: Control, wrapper: Control) -> void:
	if not is_instance_valid(bar) or not bar.is_inside_tree():
		return
	var ms: Vector2 = bar.get_combined_minimum_size()
	var band: float = maxf(ms.y, 64.0) + 22.0  # 底边距 22 与主场景一致；64 = 栏固定高
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 16.0
	bar.offset_right = -16.0
	bar.offset_top = -band
	bar.offset_bottom = -22.0
	var center: Control = wrapper.get_node_or_null("EmbedCenter")
	if center != null:
		center.offset_bottom = -band

# ───────────────────── v26.12b 接线：统计终端（真数据） ─────────────────────

func _open_terminal() -> void:
	var v := _modal_shell()
	var card_box: VBoxContainer = v
	_modal_header(card_box, "战术统计终端", "TACT-STAT · 战地情报终端")

	# 战线（LevelProgressManager 真进度）
	card_box.add_child(_terminal_section("─ 战线进度 ─"))
	var max_lv := _get_display_level()
	var head := Label.new()
	head.text = "当前战线：第 %d 关（已解锁最远）" % max_lv
	head.add_theme_font_size_override("font_size", 13)
	card_box.add_child(head)
	if LevelProgressManager and LevelProgressManager.has_method("get_era_progress"):
		for era in range(1, 6):
			var pr: Dictionary = LevelProgressManager.get_era_progress(era)
			var done := int(pr.get("completed", 0))
			var total := int(pr.get("total", 20))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var nm := Label.new()
			nm.text = ERA_NAMES[era - 1]
			nm.custom_minimum_size = Vector2(70, 0)
			nm.add_theme_font_size_override("font_size", 12)
			nm.add_theme_color_override("font_color", Color(0.56, 0.53, 0.45))
			row.add_child(nm)
			var bar := ProgressBar.new()
			bar.min_value = 0
			bar.max_value = total
			bar.value = done
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(220, 12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var num := Label.new()
			num.text = "%d/%d" % [done, total]
			num.add_theme_font_size_override("font_size", 12)
			row.add_child(num)
			card_box.add_child(row)

	# 资源（BasicResourceManager 真库存）
	card_box.add_child(_terminal_section("─ 资源库存 ─"))
	if BasicResourceManager and BasicResourceManager.has_method("get_total"):
		var res_parts: Array = []
		for pair in RES_LABELS:
			res_parts.append("%s %d" % [String(pair[1]), int(BasicResourceManager.get_total(String(pair[0])))])
		var rl := Label.new()
		rl.text = "  ".join(res_parts)
		rl.add_theme_font_size_override("font_size", 13)
		card_box.add_child(rl)

	# 收集（InstanceRegistry 拥有种数 + IntelItemBag 见过种数）
	card_box.add_child(_terminal_section("─ 收集 ─"))
	var coll_parts: Array = []
	if InstanceRegistry and InstanceRegistry.has_method("get_all_instance_ids"):
		var uniq := {}
		for iid in InstanceRegistry.get_all_instance_ids():
			uniq[String(iid).split("#")[0]] = true
		coll_parts.append("拥有卡种 %d" % uniq.size())
	if IntelItemBag and IntelItemBag.has_method("get_seen_item_ids"):
		coll_parts.append("情报/图纸见过 %d 种" % IntelItemBag.get_seen_item_ids().size())
	var cl := Label.new()
	cl.text = "  ".join(coll_parts)
	cl.add_theme_font_size_override("font_size", 13)
	card_box.add_child(cl)

	# 战绩（v26.12b：BunkerManager 战斗日志——开打抓关卡号，结束记胜负；击杀曲线待 BattleInfoDisplay 落库）
	card_box.add_child(_terminal_section("─ 战绩 ─"))
	if ManagerLazyLoader and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	var log: Array = bm.get_battle_log() if bm != null and bm.has_method("get_battle_log") else []
	if log.is_empty():
		var empty := Label.new()
		empty.text = "还没有战斗记录——出击一场后回来看。"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.52, 0.50, 0.44))
		card_box.add_child(empty)
	else:
		var wins := 0
		var kills_sum := 0
		for entry in log:
			if bool(entry.get("won", false)):
				wins += 1
			kills_sum += int(entry.get("kills", 0))
		var streak := 0
		for i in range(log.size() - 1, -1, -1):
			if not bool(log[i].get("won", false)):
				break
			streak += 1
		var stat := Label.new()
		stat.text = "总场次 %d · 胜率 %d%% · 当前连胜 %d · 总击杀 %d" % [log.size(), int(round(100.0 * wins / log.size())), streak, kills_sum]
		stat.add_theme_font_size_override("font_size", 13)
		card_box.add_child(stat)
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 3)
		var recent: Array = log.slice(maxi(0, log.size() - 10))
		for entry2 in recent:
			var w := bool(entry2.get("won", false))
			var cell := Label.new()
			cell.text = "胜" if w else "负"
			cell.custom_minimum_size = Vector2(26, 20)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_theme_font_size_override("font_size", 12)
			cell.add_theme_color_override("font_color", Color(0.62, 0.91, 0.6) if w else Color(0.88, 0.42, 0.35))
			var csb := StyleBoxFlat.new()
			csb.bg_color = Color(0.16, 0.24, 0.16) if w else Color(0.24, 0.13, 0.11)
			csb.border_color = Color(0.24, 0.35, 0.24) if w else Color(0.35, 0.2, 0.18)
			csb.set_border_width_all(1)
			csb.set_corner_radius_all(3)
			cell.add_theme_stylebox_override("normal", csb)
			strip.add_child(cell)
		card_box.add_child(strip)
		var recent_l := Label.new()
		var parts: Array = []
		for i in range(recent.size()):
			var en: Dictionary = recent[i]
			parts.append("第%d天·%d关·%s" % [int(en.get("day", 0)), int(en.get("level", 0)), "胜" if bool(en.get("won", false)) else "负"])
		recent_l.text = "  ".join(parts)
		recent_l.add_theme_font_size_override("font_size", 12)
		recent_l.add_theme_color_override("font_color", Color(0.52, 0.50, 0.44))
		card_box.add_child(recent_l)
		# v26.12c：击杀曲线（日志含 kills——BattleInfoDisplay 落库）
		var kill_vals: Array = []
		for entry3 in recent:
			kill_vals.append(int(entry3.get("kills", 0)))
		var kmax := 1
		for kv in kill_vals:
			kmax = maxi(kmax, int(kv))
		var curve := HBoxContainer.new()
		curve.custom_minimum_size = Vector2(0, 38)
		curve.add_theme_constant_override("separation", 3)
		for kv in kill_vals:
			var kbar := ColorRect.new()
			kbar.color = Color(1.0, 0.71, 0.37, 0.85)
			kbar.custom_minimum_size = Vector2(26, 4 + 32.0 * float(kv) / float(kmax))
			kbar.size_flags_vertical = Control.SIZE_SHRINK_END
			curve.add_child(kbar)
		card_box.add_child(curve)
		var curve_l := Label.new()
		curve_l.text = "击杀曲线（近 %d 场 · 单场峰 %d）" % [kill_vals.size(), kmax]
		curve_l.add_theme_font_size_override("font_size", 12)
		curve_l.add_theme_color_override("font_color", Color(0.52, 0.50, 0.44))
		card_box.add_child(curve_l)
		# v26.13：伤害曲线（青色，独立归一；日志已落 damage 字段）
		var dmg_vals: Array = []
		var dur_sum := 0
		for entry4 in recent:
			dmg_vals.append(int(entry4.get("damage", 0)))
			dur_sum += int(entry4.get("duration", 0))
		var dmax: int = 1
		for dv in dmg_vals:
			dmax = maxi(dmax, int(dv))
		var dcurve := HBoxContainer.new()
		dcurve.custom_minimum_size = Vector2(0, 38)
		dcurve.add_theme_constant_override("separation", 3)
		for dv2 in dmg_vals:
			var dbar := ColorRect.new()
			dbar.color = Color(0.0, 0.9, 1.0, 0.8)
			dbar.custom_minimum_size = Vector2(26, 4 + 32.0 * float(dv2) / float(dmax))
			dbar.size_flags_vertical = Control.SIZE_SHRINK_END
			dcurve.add_child(dbar)
		card_box.add_child(dcurve)
		var dcurve_l := Label.new()
		dcurve_l.text = "伤害曲线（近 %d 场 · 单场峰 %d）" % [dmg_vals.size(), dmax]
		dcurve_l.add_theme_font_size_override("font_size", 12)
		dcurve_l.add_theme_color_override("font_color", Color(0.52, 0.50, 0.44))
		card_box.add_child(dcurve_l)
		if dur_sum > 0:
			var dur_l := Label.new()
			dur_l.text = "场均时长 %d 秒" % (dur_sum / maxi(dmg_vals.size(), 1))
			dur_l.add_theme_font_size_override("font_size", 12)
			dur_l.add_theme_color_override("font_color", Color(0.52, 0.50, 0.44))
			card_box.add_child(dur_l)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	_style_btn(close, Color(0.6, 0.56, 0.48))
	close.pressed.connect(_close_modal)
	foot.add_child(close)
	card_box.add_child(foot)
	# v26.13：CRT 扫描线覆盖层（磷光屏质感；时代主题色已由 _modal_header/分节字色承担）
	if _modal_card != null:
		var scan := ColorRect.new()
		scan.set_anchors_preset(Control.PRESET_FULL_RECT)
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/crt_scanlines.gdshader")
		scan.material = mat
		_modal_card.add_child(scan)

func _terminal_section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", _era_accent())
	return l

## v26.19：发电机工位 = 燃料/引擎管理卡（回充规则/安全储备/引擎升级；行军经济主界面）
func _open_fuel_station_card() -> void:
	var bm := _bunker_mgr()
	if bm == null:
		_open_card("燃料 · 引擎", "reactor", "基地管理系统未就绪——从标题页进入一次后重试。")
		return
	var v := _modal_shell()
	_modal_header(v, "燃料 · 引擎", "移动基地动力段 · 发电机工位")
	var cap := int(bm.get_fuel_cap())
	var eng := int(bm.get_engine_level())
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = cap
	bar.value = bm.get_fuel()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(360, 22)
	v.add_child(bar)
	var main_l := Label.new()
	main_l.text = "燃料 %d/%d ｜ 引擎 Lv%d（速度 %d/天 · 回复 +%.0f/分钟 · 油罐 +%d/级）" % [
		int(bm.get_fuel()), cap, eng, int(TruckTravel.speed_for(eng)),
		TruckTravel.regen_per_minute(eng), TruckTravel.TANK_PER_LV]
	main_l.add_theme_font_size_override("font_size", 13)
	v.add_child(main_l)
	var rule_l := Label.new()
	rule_l.text = "自动回复 +%.0f/分钟（实时，离线也涨）· 睡觉快充 +%d/晚 · 安全储备 %d 以下不予出车 · 行驶期间无法出击\n在战区地图点任意节点即可规划行军（目的地地形影响油耗，回程走熟路半价）。" % [
		TruckTravel.regen_per_minute(eng), TruckTravel.SLEEP_REFUEL, TruckTravel.RESERVE_FLOOR]
	rule_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_l.custom_minimum_size = Vector2(360, 0)
	rule_l.add_theme_font_size_override("font_size", 12)
	rule_l.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	v.add_child(rule_l)
	# v26.25 能量块 → 燃料 1:1 充能行（余额 + 补满按钮）
	var charge_row := HBoxContainer.new()
	charge_row.add_theme_constant_override("separation", 10)
	var energy_have := 0
	if BasicResourceManager != null:
		energy_have = int(BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("energy")))
	var charge_l := Label.new()
	charge_l.text = "能量块余额 %d ｜ 充入燃料 1:1" % energy_have
	charge_l.add_theme_font_size_override("font_size", 12)
	charge_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charge_row.add_child(charge_l)
	var fill_btn := Button.new()
	fill_btn.focus_mode = Control.FOCUS_NONE
	fill_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fill_btn.text = "⚡ 充能补满（需 %d）" % TruckTravel.fuel_needed_to_fill(bm.get_fuel(), cap)
	fill_btn.tooltip_text = "消耗能量块补满油罐（不足时充入全部余额）；能量块：战斗掉落/挂机可获得"
	fill_btn.disabled = energy_have <= 0 or int(bm.get_fuel()) >= cap
	_style_btn(fill_btn, COLOR_AMBER)
	fill_btn.pressed.connect(func() -> void:
		var res: Dictionary = bm.charge_fuel_to_full()
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit(str(res.get("reason", "")))
		if bool(res.get("ok", false)):
			_play_sfx("achievement")
			_close_modal()
			_open_fuel_station_card())
	charge_row.add_child(fill_btn)
	v.add_child(charge_row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	var up_btn := Button.new()
	up_btn.focus_mode = Control.FOCUS_NONE
	up_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var up_cost: Dictionary = TruckTravel.upgrade_cost(eng)
	if up_cost.is_empty():
		up_btn.text = "引擎已满级 Lv%d" % eng
		up_btn.disabled = true
		_style_btn(up_btn, Color(0.6, 0.56, 0.48))
	else:
		up_btn.text = "升级引擎 Lv%d→%d（%s）" % [eng, eng + 1, BunkerRoomDefs.cost_text(up_cost)]
		up_btn.tooltip_text = "提升行驶速度与燃料罐容量"
		_style_btn(up_btn, COLOR_AMBER)
		up_btn.pressed.connect(func() -> void:
			var res: Dictionary = bm.upgrade_engine()
			if bool(res.get("ok", false)):
				_play_sfx("achievement")
				if SignalBus.has_signal("show_toast"):
					SignalBus.show_toast.emit(str(res.get("reason", "")))
				_close_modal()
				_open_fuel_station_card()
			else:
				# v26.25 修复：show_error 信号不存在（守卫恒假→失败零反馈），改走 toast
				if SignalBus.has_signal("show_toast"):
					SignalBus.show_toast.emit(str(res.get("reason", ""))))
	foot.add_child(up_btn)
	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	_style_btn(close, Color(0.6, 0.56, 0.48))
	close.pressed.connect(_close_modal)
	foot.add_child(close)
	v.add_child(foot)

# ───────────────────── v26.12b 接线：睡觉（BunkerManager.sleep，与基地同一存档状态） ─────────────────────

func _on_sleep() -> void:
	if ManagerLazyLoader and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm == null or not bm.has_method("sleep"):
		_open_card("充能舱 · 睡觉", "dormitory", "BunkerManager 未就绪——请先从标题页进入一次（读档/开档后重试）。")
		return
	_close_modal()
	var summary: Dictionary = bm.sleep()
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	var txt := "醒来时是第 %d 天。\n精神 %.0f → %.0f（睡觉回复）" % [
		int(summary.get("day", 0)), float(summary.get("sanity_before", 0)), float(summary.get("sanity_after", 0))]
	# v26.21：燃料回充（行程实时推进，睡觉不再到站）
	txt += "\n燃料回充 → %d/%d" % [int(float(summary.get("fuel", 0.0))), int(summary.get("fuel_cap", 0))]
	var loot: Dictionary = summary.get("loot_printed", {})
	if not loot.is_empty():
		var loot_name := String(loot.get("name", ""))
		txt += "\n仓库打印：缴获卡「%s」已入包" % (loot_name if loot_name != "" else "1 张")
	var completed: int = (summary.get("completed_today", []) as Array).size()
	if completed > 0:
		txt += "\n今日完成事项：%d 项已结算" % completed
	_open_card("充能舱 · 睡觉结算", "dormitory（同一存档，与旧基地共享天数/精神）", txt)

# ───────────────────── v26.12c 外景视图：那关地图 + 卡车停靠 ─────────────────────

func _build_exterior_area() -> void:
	_ext_holder = Control.new()
	_ext_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ext_holder.offset_top = 48.0
	_ext_holder.offset_bottom = -8.0
	_ext_holder.offset_left = 8.0
	_ext_holder.offset_right = -8.0
	_ext_holder.visible = false
	add_child(_ext_holder)
	_ext_bg = TextureRect.new()
	_ext_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ext_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ext_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ext_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ext_holder.add_child(_ext_bg)
	# v26.13：外景车底投影（锚同卡车、贴地一条带）
	_ext_shadow = _make_soft_shadow()
	_ext_shadow.anchor_left = 0.16
	_ext_shadow.anchor_right = 0.88
	_ext_shadow.anchor_top = 0.905
	_ext_shadow.anchor_bottom = 0.965
	_ext_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ext_holder.add_child(_ext_shadow)
	_ext_truck = TextureRect.new()
	_ext_truck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ext_truck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ext_truck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ext_truck.anchor_left = 0.16
	_ext_truck.anchor_right = 0.88
	_ext_truck.anchor_top = 0.38
	_ext_truck.anchor_bottom = 0.96
	_ext_holder.add_child(_ext_truck)
	# v26.13：全屏暗角
	_ext_holder.add_child(_make_vignette())
	# v26.13：电影黑边（切外景时滑入，"抵达战地"的观感）
	_lb_top = ColorRect.new()
	_lb_top.color = Color(0, 0, 0, 0.96)
	_lb_top.anchor_left = 0.0
	_lb_top.anchor_right = 1.0
	_lb_top.anchor_top = 0.0
	_lb_top.anchor_bottom = 0.0
	_lb_top.offset_bottom = 0.0
	_lb_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ext_holder.add_child(_lb_top)
	_lb_bot = ColorRect.new()
	_lb_bot.color = Color(0, 0, 0, 0.96)
	_lb_bot.anchor_left = 0.0
	_lb_bot.anchor_right = 1.0
	_lb_bot.anchor_top = 1.0
	_lb_bot.anchor_bottom = 1.0
	_lb_bot.offset_top = 0.0
	_lb_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ext_holder.add_child(_lb_bot)
	_ext_caption = Label.new()
	_ext_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_ext_caption.offset_left = 14.0
	_ext_caption.offset_top = -34.0
	_ext_caption.offset_bottom = -10.0
	_ext_caption.add_theme_font_size_override("font_size", 13)
	_ext_caption.add_theme_color_override("font_color", Color(1.0, 0.89, 0.69))
	_ext_holder.add_child(_ext_caption)

func _on_view_pressed(mode: String) -> void:
	_set_view(mode, true)

func _set_view(mode: String, animate: bool) -> void:
	_view_mode = mode
	var ext := mode == "exterior"
	_ext_holder.visible = ext
	_image_holder.visible = not ext
	for vb in _view_buttons:
		vb.set_pressed_no_signal(String(vb.get_meta("view_mode")) == mode)
	if ext:
		_refresh_exterior(animate)
	# v26.13：外景电影黑边滑入/收起（动效减弱直接归位）
	var bar_h := 52.0
	if _lb_top != null and _lb_bot != null:
		if not animate or DT.is_motion_reduce():
			_lb_top.offset_bottom = bar_h if ext else 0.0
			_lb_bot.offset_top = -bar_h if ext else 0.0
		else:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(_lb_top, "offset_bottom", bar_h if ext else 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(_lb_bot, "offset_top", -bar_h if ext else 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 外景刷新：背景=当前进度那关的战场地图（与战斗同源），卡车精灵=时代匹配
func _refresh_exterior(animate: bool) -> void:
	var level := _get_display_level()
	# v27.12: 两张贴图先查 _textures 缓存（key=路径），未命中才加载并存入
	# （原每次切外景直调 _load_era_texture 重读；Image 兜底路径还会重建 ImageTexture）
	var ext_bg_path := _ext_bg_path(level)
	if not _textures.has(ext_bg_path):
		_textures[ext_bg_path] = _load_era_texture(ext_bg_path)
	_ext_bg.texture = _textures[ext_bg_path]
	var era := clampi((level - 1) / 20 + 1, 1, 5)
	var truck_path: String = TRUCK_SPRITE_FMT % era
	if not _textures.has(truck_path):
		_textures[truck_path] = _load_era_texture(truck_path)
	_ext_truck.texture = _textures[truck_path]
	var lname := _display_level_name(level)
	_ext_caption.text = "驻地 · 第 %d 关「%s」 · %s" % [level, lname if lname != "" else String(ERAS[_era_idx]["zone"]), String(ERAS[era - 1]["label"])]
	if animate:
		await get_tree().process_frame
		if _ext_truck == null or not is_instance_valid(_ext_truck):
			return
		var target_x := _ext_truck.position.x
		_ext_truck.position.x = target_x - 320.0
		var tw := create_tween()
		tw.tween_property(_ext_truck, "position:x", target_x, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## 关卡战场背景路径：本关图 → 同时代首关图 → 时代通用图 → 默认（battlefield 同源回退链简化版）
func _ext_bg_path(level: int) -> String:
	var era := clampi((level - 1) / 20 + 1, 1, 5)
	var candidates := [
		EXT_BG_FMT % level,
		EXT_BG_FMT % ((era - 1) * 20 + 1),
		"res://assets/backgrounds/bg_%02d.png" % era,
		"res://assets/backgrounds/bg_default.png",
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return String(ERAS[_era_idx]["tex"])

func _display_level_name(level: int) -> String:
	return String(LevelInformation.get_shared().get_level_display_name(level))

# ═══════════ v27.13 开场链：醒来演出（自 bunker_main.gd 879-1141 平移适配）═══════════

func _maybe_play_wakeup() -> void:
	var pending := Engine.has_meta(META_WAKEUP)
	if pending:
		Engine.remove_meta(META_WAKEUP)
	if pending:
		var bm := _bunker_mgr()
		if bm != null and bm.has_method("mark_comic_seen"):
			bm.mark_comic_seen()   # 开场已完整播放（或跳过），落档防重播
	if not pending:
		_maybe_show_truck_intro()
		return
	_play_wakeup_cinematic()

func _play_wakeup_cinematic() -> void:
	_wakeup_active = true
	var root := Control.new()
	root.name = "WakeupCinematic"
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # 演出期间挡住工位点击
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.is_pressed():
			_finish_wakeup())
	add_child(root)
	_wakeup_root = root

	# 雪原底图：压在眼睑之下，睁眼先见雪原+基地车+远处黑门；缺图时睁眼直接见基地
	var snow_bg: TextureRect = null
	if ResourceLoader.exists(SNOW_BG_PATH):
		snow_bg = TextureRect.new()
		snow_bg.name = "SnowBg"
		snow_bg.texture = load(SNOW_BG_PATH)
		snow_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		snow_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		snow_bg.size = Vector2(1280, 720)
		snow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(snow_bg)
		root.move_child(snow_bg, 0)

	# 眼睑：上下两片黑（闭合态 = 全黑）
	var lid_top := ColorRect.new()
	lid_top.color = Color(0, 0, 0)
	lid_top.position = Vector2.ZERO
	lid_top.size = Vector2(1280, 360)
	lid_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lid_top)
	var lid_bot := ColorRect.new()
	lid_bot.color = Color(0, 0, 0)
	lid_bot.position = Vector2(0, 360)
	lid_bot.size = Vector2(1280, 360)
	lid_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lid_bot)

	var thought := Label.new()
	thought.position = Vector2(140, 250)
	thought.size = Vector2(1000, 60)
	thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	thought.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8, 0.85))
	thought.text = "（好冷……我还活着？）"
	thought.modulate.a = 0.0
	thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(thought)

	var flash := ColorRect.new()
	flash.color = Color(1, 0.25, 0.15, 0)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	var flash_label := Label.new()
	flash_label.position = Vector2(90, 300)
	flash_label.size = Vector2(1100, 120)
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	flash_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	flash_label.modulate.a = 0.0
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_label)

	var dim := ColorRect.new()
	dim.color = DT.COLOR_TRANSPARENT
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var sub := Label.new()
	sub.position = Vector2(100, 596)
	sub.size = Vector2(1080, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	sub.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 0.9))
	sub.modulate.a = 0.0
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub)

	var hint := Label.new()
	hint.position = Vector2(1080, 690)
	hint.size = Vector2(180, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	hint.text = "点击跳过 ▸"
	hint.modulate.a = 0.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	var beats := [
		{"text": "黑门，吞掉了整个天空。", "col": Color(0.9, 0.2, 0.12, 0.72), "sfx": "enhance"},
		{"text": "「深航计划——回溯至黑门初立之时。」", "col": Color(0.5, 0.35, 0.9, 0.65), "sfx": "enhance"},
		{"text": "「找到他们。一千个，一个都不能少。」", "col": Color(0.2, 0.7, 0.85, 0.55), "sfx": "card_pickup"},
	]

	var tw := create_tween()
	_wakeup_tween = tw
	# A 梦呓
	tw.tween_interval(0.7)
	tw.tween_property(thought, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.7)
	tw.tween_property(thought, "modulate:a", 0.0, 0.45)
	# B 睁眼（开→快速回眨→再开）
	tw.tween_property(lid_top, "size:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(lid_bot, "position:y", 720.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(lid_bot, "size:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lid_top, "size:y", 360.0, 0.22)
	tw.parallel().tween_property(lid_bot, "position:y", 360.0, 0.22)
	tw.parallel().tween_property(lid_bot, "size:y", 360.0, 0.22)
	tw.tween_property(lid_top, "size:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(lid_bot, "position:y", 720.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(lid_bot, "size:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hint, "modulate:a", 0.45, 0.4)
	# C 三拍梦境闪回（眼睑全开后额外留白 2s，让雪原图有足够时间被看到）
	tw.tween_interval(2.0)
	for b in beats:
		var beat: Dictionary = b
		var col: Color = beat["col"]
		tw.tween_callback(func():
			flash.color = Color(col.r, col.g, col.b, 0.0)
			flash_label.text = str(beat["text"])
			if SignalBus != null and SignalBus.has_signal("play_sound"):
				SignalBus.play_sound.emit(str(beat["sfx"])))
		tw.tween_property(flash, "color:a", col.a, 0.12)
		tw.parallel().tween_property(flash_label, "modulate:a", 1.0, 0.16)
		tw.tween_interval(0.85)
		tw.tween_property(flash, "color:a", 0.0, 0.45)
		tw.parallel().tween_property(flash_label, "modulate:a", 0.0, 0.4)
	# D 画外音落定（雪原之上）
	tw.tween_property(dim, "color:a", 0.42, 0.6)
	tw.tween_callback(func(): sub.text = "你从雪里坐起。身旁，是随你一同坠落的基地车。")
	tw.tween_property(sub, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.5)
	tw.tween_property(sub, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): sub.text = "天边尽头，黑门矗立在大地上——仿佛没有顶。")
	tw.tween_property(sub, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.6)
	# E0 进车过场：雪原 → 车厢（本场景本体；无雪原图时本拍仅作过场字幕）
	tw.tween_callback(func(): sub.text = "你钻进基地车。风雪被关在了舱门之外。")
	tw.tween_property(sub, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.9)
	tw.tween_property(sub, "modulate:a", 0.0, 0.5)
	if snow_bg != null:
		tw.parallel().tween_property(snow_bg, "modulate:a", 0.0, 1.1)
	# E 相位仪三拍教学（手腕相位仪 → 纸条 → 床下背包；图缺失时仅字幕兜底）
	tw.tween_callback(func(): _wakeup_teach_beat(root, sub, 0))
	tw.tween_interval(3.2)
	tw.tween_callback(func(): _wakeup_teach_beat(root, sub, 1))
	tw.tween_interval(4.2)
	tw.tween_callback(func(): _wakeup_teach_beat(root, sub, 2))
	tw.tween_interval(3.2)
	# F 收场 → 移动基地指南
	tw.tween_property(root, "modulate:a", 0.0, 0.9)
	tw.tween_callback(_finish_wakeup)

## 醒来演出教学三拍：0=手腕相位仪图 1=纸条（相位仪装卡+找同伴）2=床下背包图（起始卡）
func _wakeup_teach_beat(root: Control, sub: Label, beat: int) -> void:
	if not _wakeup_active:
		return
	var vp := Vector2(1280, 720)
	var img_path := ""
	var caption := ""
	if beat == 0:
		img_path = "res://assets/intro/wakeup_wrist.png"
		caption = "腕上的相位仪微微发亮——它在感应同伴的位置。"
	elif beat == 1:
		caption = ""
	else:
		img_path = "res://assets/intro/wakeup_backpack.png"
		caption = "床下的背包里，静静躺着几张卡。"
	# 图（有图才铺满）
	var tex: TextureRect = null
	if img_path != "" and ResourceLoader.exists(img_path):
		tex = TextureRect.new()
		tex.name = "TeachImg"
		tex.texture = load(img_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.size = vp
		tex.modulate.a = 0.0
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tex)
	# 纸条（beat 1：浅纸面板 + 手写字感的说明）
	var note: PanelContainer = null
	if beat == 1:
		note = PanelContainer.new()
		note.name = "TeachNote"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.87, 0.82, 0.68, 0.96)
		sb.border_color = Color(0.55, 0.45, 0.3, 0.9)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(20.0)
		note.add_theme_stylebox_override("panel", sb)
		note.position = Vector2(390, 220)
		note.custom_minimum_size = Vector2(500, 0)
		note.rotation_degrees = -1.5
		note.modulate.a = 0.0
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nv := VBoxContainer.new()
		note.add_child(nv)
		var nt := Label.new()
		nt.text = "（一张压在枕头下的纸条）"
		nt.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		nt.add_theme_color_override("font_color", Color(0.4, 0.35, 0.28))
		nv.add_child(nt)
		var nb := Label.new()
		nb.text = "相位仪装载卡片，卡片便能随你出战。\n它会指引同伴的位置——迷失者被战胜后，其力量将随你同行。\n　　　　　　　　　　　　——深航计划"
		nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nb.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
		nb.add_theme_color_override("font_color", Color(0.22, 0.19, 0.14))
		nv.add_child(nb)
		root.add_child(note)
	# 淡出上一拍内容与旧字幕
	var ft := create_tween()
	for old_name in ["TeachImg", "TeachNote"]:
		var old = root.get_node_or_null(NodePath(old_name))
		if old != null and is_instance_valid(old):
			ft.parallel().tween_property(old, "modulate:a", 0.0, 0.35)
	ft.parallel().tween_property(sub, "modulate:a", 0.0, 0.3)
	# 淡入本拍
	ft.tween_interval(0.35)
	ft.tween_callback(func(): sub.text = caption)
	ft.set_parallel(true)
	if tex != null:
		ft.tween_property(tex, "modulate:a", 1.0, 0.5)
	if note != null:
		ft.tween_property(note, "modulate:a", 1.0, 0.45)
	if caption != "":
		ft.tween_property(sub, "modulate:a", 1.0, 0.45)

## 跳过 / 收场共用：清演出 → 补弹移动基地首次指南（show_once 随档持久化）
func _finish_wakeup() -> void:
	if not _wakeup_active:
		return
	_wakeup_active = false
	if _wakeup_tween != null and _wakeup_tween.is_valid():
		_wakeup_tween.kill()
	if _wakeup_root != null and is_instance_valid(_wakeup_root):
		_wakeup_root.queue_free()
	_wakeup_root = null
	_maybe_show_truck_intro()
