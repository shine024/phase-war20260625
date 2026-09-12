extends PanelContainer
## 帮助面板：显示游戏各类系统说明
## 包含战斗基础、卡牌成长、相位仪、势力系统、日常任务、移动基地、地图与进阶 七个Tab
## 批次三 B1（2026-08-24）纠偏：法则系统/强化①/蓝图体系/科研点已退役（见 AGENTS.md
## 停用清单），本面板全部内容已对照现役系统重写，禁止再写入已删除系统的说明。
## v26.33（2026-09-08）移动基地核心化重写：基地 Tab 以移动基地为主体（旧固定基地
## 余烬要塞已停用，房间功能并入卡车工位）；地图 Tab 改行军语义（点节点=出车、
## 停靠关=战前准备）；相位仪 Tab 撤符文圣所（旧基地房间）表述。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

# UI 组件引用
@onready var tab_container: TabContainer = $Margin/VBox/TabContainer

var _is_open: bool = false

func _ready() -> void:
	# 初始状态隐藏
	visible = false
	modulate.a = 0.0

	# v7.x 面板统一：SMALL 档 + 青色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_SMALL
	var accent := DT.get_panel_accent("help")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "车长手册", accent, "操作指南")
	chrome.closed.connect(_on_close)

	# 填充 Tab 内容
	_populate_tabs()

## 打开帮助面板
## v9.x 修复：加可选 card 参数对齐 main._notify_panel_opened 的统一分发约定
## （show_panel(null)）——原零参签名导致分发侧带参调用不兼容，且面板从未被
## 分发叫醒（_PANEL_NODE_NAMES 缺 "help" 键），表现为空遮罩且无法关闭。
## 批次2：面板内层动画已拆除（与外层 PanelAnim 双层叠加、时序错拍）——
## 开合动画统一归外层（main overlay / 基地嵌入 wrapper 均已走 PanelAnim），
## 内层只保留打开状态与可见性逻辑；modulate/scale 显式归位防残留。
func show_panel(_card: CardResource = null) -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE

## 关闭帮助面板
func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE

## 关闭按钮回调
func _on_close() -> void:
	hide_panel()
	closed.emit()

## 填充五个帮助标签页
func _populate_tabs() -> void:
	if not tab_container:
		return

	# 清空已有子节点
	for child in tab_container.get_children():
		child.queue_free()

	# Tab 0: 战斗基础
	_add_tab("战斗基础", _get_combat_content())

	# Tab 1: 卡牌成长
	_add_tab("卡牌成长", _get_card_growth_content())

	# Tab 2: 相位仪（原"法则卡"Tab——法则系统已随 P2-7 整体删除，B1 纠偏改写）
	_add_tab("相位仪", _get_phase_instrument_content())

	# Tab 3: 势力系统
	_add_tab("联络台", _get_faction_content())

	# Tab 4: 日常任务
	_add_tab("日常任务", _get_daily_quest_content())
	# Tab 5: 移动基地（v26.33 移动基地核心化重写——旧固定基地已停用）
	_add_tab("移动基地", _get_base_content())
	# Tab 6: 地图与进阶（v26.13 帮助补全）
	_add_tab("地图与进阶", _get_map_content())

## 添加一个标签页（ScrollContainer 包裹 RichTextLabel）
func _add_tab(title: String, bbcode_text: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var rich_label := RichTextLabel.new()
	rich_label.name = "Content"
	rich_label.fit_content = true
	rich_label.scroll_active = false
	rich_label.bbcode_enabled = true
	rich_label.text = bbcode_text
	# 自适应宽度
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 设置默认样式
	rich_label.add_theme_constant_override("line_separation", 6)

	scroll.add_child(rich_label)
	tab_container.add_child(scroll)

# ─── 帮助内容定义 ───────────────────────────────────────────

func _get_combat_content() -> String:
	return """[b][color=#ffcc44]⚔ 战斗基础[/color][/b]

[b][color=#88ccff]◆ 能量系统[/color][/b]
战斗实时进行，能量随时间自动恢复（基础 1 点/秒，相位基座持续消耗 0.5 点/秒）。
- 开局满能量 [color=#ff9944]100 点[/color]，上限 100 点
- 部署能耗按单位战力定价：越强的单位越贵，约 [color=#ff9944]4~15 点[/color]
- 相位仪的恢复/消耗属性会影响净回复速度

[b][color=#88ccff]◆ 部署单位[/color][/b]
从底部相位仪栏选择已装备的卡牌，点击战场格子放置到战场上。
- 每个单位有其 [color=#88ee88]攻击力[/color]、[color=#ee6644]耐久[/color] 和射程
- 同名卡的同场上阵数量有限制，注意底栏槽位提示
- 快捷键 [color=#eeee44]1-9[/color] 可直接从对应槽位发起部署

[b][color=#88ccff]◆ 相位场驱动器保护[/color][/b]
相位场驱动器是你的核心，也是敌方的主要攻击目标。
- 驱动器只有一项 [color=#ee6644]耐久值[/color]，被攻击会持续削减
- 耐久降为 0 时驱动器被摧毁，战斗失败
- 部署防御型单位在前排拦截，是保护驱动器的主要手段

[b][color=#88ccff]◆ 战斗流程（实时制）[/color][/b]
战斗全程实时进行，没有回合概念：
1. 敌方按波次持续入场进攻
2. 你的单位部署后自动索敌、自动攻击
3. 全灭敌方波次并存活即获胜，可随时使用顶栏"撤退"判负离场

[color=#888888]提示：合理搭配前排防御和后排输出单位，形成有效的战斗阵线。[/color]"""

func _get_card_growth_content() -> String:
	return """[b][color=#ffcc44]⬆ 卡牌成长[/color][/b]

[b][color=#88ccff]◆ 卡牌等级（唯一等级轴）[/color][/b]
每张你拥有的卡牌都是独立实例，各自培养互不影响。
- 上阵参战自动积累经验，等级 [color=#88ee88]Lv1-30[/color] 自动提升
- 关键等级解锁[color=#cc88ff]词条槽[/color]（每 5 级一档）
- 等级同时决定光环/能力等级：每 3 级折合 1★（Lv30 即满级 10★）

[b][color=#88ccff]◆ 改造模块（图纸消耗品）[/color][/b]
在改造舱为卡牌安装模块，定向强化特定属性。
- 安装 1 条改造 = 消耗 [color=#ff9944]1 张对应图纸[/color]（库存消耗品）+ 纳米材料
- 图纸来自战斗掉落、制造舱与补给舱；装上后只对选中的那张卡生效
- 武器类改造可随时启用/禁用，卸下返还部分纳米

[b][color=#88ccff]◆ 制造舱（获取新卡牌的唯一通道）[/color][/b]
入口：移动基地「3D 打印机」工位（整备舱同源）。
- 配方目录 [color=#88ee88]38 张[/color]：情报达标即解锁制造资格
- 制造消耗纳米/合金/晶体，工坊折扣可降费
- [color=#cc88ff]品质概率池[/color]：情报推进解锁更高品质概率（史诗/传说）
- 缴获卡（captured_ 前缀）可在制造舱滚动品质

[b][color=#88ccff]◆ 词条与词缀工坊[/color][/b]
- 卡牌词条槽随等级解锁，词条等级 Lv1-3
- [color=#eeee44]词缀工坊[/color]：洗练/锁定词条，击败相位师解锁 Boss 词条池

[b][color=#88ccff]◆ 同名卡各自独立[/color][/b]
同一张卡可以拥有多张（如 T-72#1、T-72#2），部署时按实例各自结算属性。
养成操作只作用于你选中的那一张，不会牵连同名卡。

[color=#888888]提示：优先培养常用主力卡；缺新卡就去制造舱看情报门槛。[/color]"""

func _get_phase_instrument_content() -> String:
	return """[b][color=#ffcc44]◈ 相位仪[/color][/b]

相位仪是你的出战装备架，决定哪些卡牌和符文可以带上战场。

[b][color=#88ccff]◆ 战斗卡槽（绿色）[/color][/b]
- 绿色槽位装备[color=#88ee88]战斗卡[/color]，装备后才能在战斗中部署
- 槽位数量随相位仪等级提升（最多 9 格）
- 战斗胜利后槽位不会自动清空，可随时在底部相位仪栏调整

[b][color=#88ccff]◆ 符文槽[/color][/b]
- 符文槽存放[color=#cc88ff]符文[/color]，提供被动增益（最多 6 格）
- 特定符文组合可激活[color=#eeee44]符文之语[/color]，获得额外套装效果
- 符文是牺牲的相位师们精神的凝结——击败驻守相位师后掉落，也可在势力联络台的商店获取
- 符文在背包的符文标签页装备与管理（移动基地卡仓 / 战斗屏背包同源）

[b][color=#88ccff]◆ 相位场等级与属性点[/color][/b]
- 战斗积累相位场经验，相位场等级 [color=#88ee88]Lv1-30[/color]
- 每升 1 级获得[color=#eeee44]属性点[/color]，可在相位仪面板自由分配/回收/洗点
- 属性点加成直接作用于全体上阵单位

[b][color=#88ccff]◆ 相位仪星级[/color][/b]
- 提升相位仪等级可增加槽位数量与能量上限
- 等级还决定战斗中可部署的[color=#88ccff]前沿范围[/color]（等级越高部署区越靠前）

[color=#888888]提示：优先把主力卡装备进绿槽再开战，符文之语激活后收益可观。[/color]"""

func _get_faction_content() -> String:
	return """[b][color=#ffcc44]⚔ 联络台[/color][/b]

游戏中有多个势力，每个势力都有独特的背景故事、奖励和专属内容。

[b][color=#88ccff]◆ 势力声望[/color][/b]
声望是一条 0~9000+ 的数值轴，共分 [color=#88ee88]10 级[/color]（0/500/1200/2000/2900/3900/5000/6200/7500/9000）。
- 所有势力开局声望相同，等级越高解锁越多权限与商品
- 声望达到 [color=#eeee44]6200（8 级）[/color]解锁全局权限
- 势力之间存在[color=#cc88ff]同盟/竞争/敌对[/color]关系：提升一方声望可能影响其敌对势力

提升声望的主要方式：完成该势力的委托任务与相关事件。

[b][color=#88ccff]◆ 势力商店[/color][/b]
每个势力都有独立的商店，出售独特的物品：
- [color=#88ee88]基础物资[/color]：纳米材料、合金、晶体等养成资源
- [color=#eeee44]势力专属卡牌[/color]：各势力特色战斗卡（共 14 张专属卡）
- 声望等级越高，可购买的商品越稀有

高声望等级解锁更多商品栏位。

[b][color=#88ccff]◆ 势力任务[/color][/b]
势力会定期发布委托任务，完成可获得声望和专属奖励。
任务类型包括：战斗任务、收集任务、成长任务和探索任务。
更高声望等级解锁更困难但更丰厚的委托任务。

[color=#888888]提示：不必专注于单一势力，适度发展多个势力可以获得更丰富的资源。[/color]"""

func _get_daily_quest_content() -> String:
	return """[b][color=#ffcc44]📋 日常任务[/color][/b]

日常任务是每日更新的重复性任务，是获取稳定资源收益的重要途径。

[b][color=#88ccff]◆ 每日刷新[/color][/b]
- 每次刷新提供固定 [color=#88ee88]7 个[/color] 日常任务（3 简单 + 2 普通 + 1 困难 + 1 专家）
- 距上次刷新满 [color=#eeee44]24 小时[/color]后自动刷新
- 刷新后旧任务被替换，已接任务的进度请及时完成
- 任务类型覆盖：战斗胜利、击败敌人、收集卡牌、升级卡牌、完成关卡、获得经验、获得符文

[b][color=#88ccff]◆ 难度分级[/color][/b]
日常任务分为四个难度等级，难度越高奖励越好：
- [color=#88ee88]简单[/color]：完成条件轻松，适合顺手完成
- [color=#eeee44]普通[/color]：需要一定的战斗场次或进度
- [color=#ff9944]困难[/color]：需要专门安排战斗目标
- [color=#ee6644]专家[/color]：高难度，奖励最丰厚

[b][color=#88ccff]◆ 奖励领取[/color][/b]
完成任务后，在委托台的"日常"标签页手动领取奖励：
- 点击已完成任务的 [color=#88ee88]"领取"[/color] 按钮获取奖励
- 奖励内容按难度递增，可能包括：
  - [color=#88ccff]纳米材料[/color]（养成通用资源）
  - [color=#eeee44]能量块[/color]
  - [color=#cc88ff]稀有度碎片[/color]（普通/稀有/史诗/传说，随难度提升）

[color=#888888]提示：每天花少量时间完成日常任务，日积月累可获得大量资源！[/color]"""


func _get_base_content() -> String:
	return """[b][color=#ffcc44]🚚 移动基地[/color][/b]

移动基地（装甲卡车驻地）是你的大本营。从标题屏「移动基地」按钮或战区地图的
「家」标记进入；[color=#88ccff]外景[/color]看驻车环境、[color=#88ccff]剖面[/color]回车厢干活（顶栏切换）。

[b][color=#88ccff]◆ 车厢工位（常显标牌，点击直达）[/color][/b]
- [color=#eeee44]驾驶室 / 尾门跳板[/color]：作战简报与出击——任务目标、环境四维、
  战术主题、战线沙盘、敌方档位、兵力对比
- 指挥电脑桌：战术统计终端（战线/资源/收集/战绩与击杀曲线）
- 世界地图墙：情报舱 · 补给售货机：补给舱·联络台
- 卡牌展示墙：卡仓 · 工具工作台：改造·词条
- 3D 打印机：制造舱 · 医疗柜：医疗休整
- 发电机：燃料与引擎管理 · 铺位：睡觉·存档
- 顶栏：出击（直达停靠关）/ 战区地图 / 时代切换；ESC 逐层关闭面板与简报

[b][color=#88ccff]◆ 行军与燃料（停哪打哪）[/color][/b]
顶栏「战区地图」点任意节点即可出车——自由行军，任意节点都能停靠：
- 耗燃料 = 距离 × 地形系数（战壕 1.0 ~ 极光 1.5），回程半价；
  燃料低于安全储备 [color=#eeee44]10[/color] 时拒绝出车（会说明原因）
- 行军实时推进（[color=#88ee88]1 天 ≈ 12 秒[/color]，离线也计时），到站自动停靠并同步当前关
- [color=#ee6644]行驶中无法出击[/color]，到站停靠后才能打；点停靠关 = 战前准备 → 出击
- 引擎 Lv1-5：提升行军速度与燃料罐容（发电机工位或行军规划内升级）

[b][color=#88ccff]◆ 燃料回复与睡觉[/color][/b]
- 燃料定期自动回复（离线也涨）；铺位睡觉快充 [color=#88ee88]+45/晚[/color]
- 发电机工位可用能量块 [color=#eeee44]1:1[/color] 充能
- 睡觉同时推进天数、恢复精神并自动存档——与战斗结算并列的存档点

[b][color=#88ccff]◆ 挂机与战利品归仓[/color][/b]
挂机自动刷停靠关，战利品先进归仓暂存；挂机结算弹窗「全部入账」一键收取。
精神值随战斗消耗（胜 -10），过低会停机——铺位睡觉恢复。

[color=#888888]旧固定基地（余烬要塞）已停用，其房间功能已并入移动基地工位。[/color]
[color=#888888]提示：关游戏前记得回铺位睡一觉——睡觉是稳定的存档点。[/color]"""

func _get_map_content() -> String:
	return """[b][color=#ffcc44]🗺 地图与进阶[/color][/b]

[b][color=#88ccff]◆ 世界地图（黑日战线 · 100 关）[/color][/b]
- 节点颜色=所属时代，金环加大=相位师首领关，青色双环=当前关
- [color=#eeee44]金色光点[/color]=移动基地位置（纯指示器）；西南「家」标记点击进入移动基地
- 点任意节点 = 行军出车（燃料 × 地形，回程半价，自由停靠）
- 点停靠关 = 战前准备 → 出击；行驶中会被拦截并说明原因
- 滚轮缩放、拖拽平移；从基地进图时 ESC/返回键回移动基地
- 大地图右侧[color=#cc88ff]黑门·无限[/color]：通关第 100 关开启，进入需把基地停靠在第 100 关

[b][color=#88ccff]◆ 敌方四档[/color][/b]
时代内按进度分四档，强度逐档跃升：
[color=#88ee88]新兵[/color](1-5) → [color=#88ccff]老兵[/color](6-11) → [color=#ff9944]精英[/color](12-17) → [color=#ee6644]传奇[/color](18-20)
驾驶室的作战简报会预告本场档位与阵地规模。

[b][color=#88ccff]◆ 情报舱（四页签）[/color][/b]
世界观情报 / 单位谱系图谱 / 符文图鉴 / 敌方情报。
- 把对应敌种情报推到 [color=#eeee44]75%+[/color] 可解锁弱点/抗性提示（败因分析会提醒）
- 情报推进同时是制造舱解锁配方与品质池的核心资源

[b][color=#88ccff]◆ 成就[/color][/b]
战斗/收集/进度/挑战/系统五大类，完成即解锁并可在成就面板领取奖励。
全部成就都可通过正常游玩完成。

[b][color=#88ccff]◆ 组合技与光环[/color][/b]
- 特定卡牌组合触发[color=#eeee44]组合技[/color]，满档机制由组合引擎每秒并入全队
- 医疗/侦查/雷达/堡垒光环按带内槽距生效，指挥/维修恒全场

[color=#888888]提示：卡住了就去情报舱看敌方情报——知彼后针对性改造，比硬堆等级有效。[/color]"""
