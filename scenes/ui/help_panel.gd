extends PanelContainer
## 帮助面板：显示游戏各类系统说明
## 包含战斗基础、卡牌成长、相位仪、势力系统、日常任务 五个Tab
## 批次三 B1（2026-08-24）纠偏：法则系统/强化①/蓝图体系/科研点已退役（见 AGENTS.md
## 停用清单），本面板全部内容已对照现役系统重写，禁止再写入已删除系统的说明。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

# UI 组件引用
@onready var tab_container: TabContainer = $Margin/VBox/TabContainer

# 动画参数
var _anim_duration: float = DT.MOTION_POP  # C7: 动效时长走 token（弹出 TRANS_BACK 组合）
var _is_open: bool = false

func _ready() -> void:
	# 初始状态隐藏
	visible = false
	modulate.a = 0.0

	# v7.x 面板统一：SMALL 档 + 青色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_SMALL
	var accent := DT.get_panel_accent("help")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "游戏帮助", accent, "HELP")
	chrome.closed.connect(_on_close)

	# 填充 Tab 内容
	_populate_tabs()

## 打开帮助面板
## v9.x 修复：加可选 card 参数对齐 main._notify_panel_opened 的统一分发约定
## （show_panel(null)）——原零参签名导致分发侧带参调用不兼容，且面板从未被
## 分发叫醒（_PANEL_NODE_NAMES 缺 "help" 键），表现为空遮罩且无法关闭。
func show_panel(_card: CardResource = null) -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	var tween := create_tween()
	# Godot 4 已移除 TRANS_FADE 枚举, modulate:a 渐变本身即线性 fade, 无需 set_trans
	tween.tween_property(self, "modulate:a", 1.0, _anim_duration)
	# 轻微缩放动画
	scale = Vector2(0.9, 0.9)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), _anim_duration).set_trans(Tween.TRANS_BACK)

## 关闭帮助面板
func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	# Godot 4 已移除 TRANS_FADE 枚举, modulate:a 渐变本身即线性 fade, 无需 set_trans
	tween.tween_property(self, "modulate:a", 0.0, _anim_duration)
	tween.parallel().tween_property(self, "scale", Vector2(0.9, 0.9), _anim_duration).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): visible = false)

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
	_add_tab("势力系统", _get_faction_content())

	# Tab 4: 日常任务
	_add_tab("日常任务", _get_daily_quest_content())

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
- 关键等级解锁[color=#cc88ff]词条槽[/color]，可在强化界面选择并升级词条（词条 Lv1-3）
- 等级同时决定光环/能力星级：每 3 级折合 1 星（Lv30 即满星 10★）

[b][color=#88ccff]◆ 改造模块[/color][/b]
在改造面板为卡牌安装模块，定向强化特定属性。
- 模块按兵种分类，消耗资源安装，可随时调整
- 改造只对选中的那张卡生效，同名其他卡不受影响

[b][color=#88ccff]◆ 进化[/color][/b]
满足等级门槛（一阶 Lv5 / 二阶 Lv10）后可在进化面板进化：
- 进化后变为[color=#eeee44]全新卡牌[/color]，等级/经验/改造/词条槽重置
- 继承加成、耐久下限与情报奖励会保留
- 进化是跨越时代战力台阶的核心手段

[b][color=#88ccff]◆ 同名卡各自独立[/color][/b]
同一张卡可以拥有多张（如 T-72#1、T-72#2），部署到战场时按实例各自结算属性。
养成操作只作用于你选中的那一张，不会牵连同名卡。

[color=#888888]提示：优先培养常用主力卡，成长收益最高。[/color]"""

func _get_phase_instrument_content() -> String:
	return """[b][color=#ffcc44]◈ 相位仪[/color][/b]

相位仪是你的出战装备架，决定哪些卡牌和符文可以带上战场。

[b][color=#88ccff]◆ 战斗卡槽（绿色）[/color][/b]
- 绿色槽位装备[color=#88ee88]战斗卡[/color]，装备后才能在战斗中部署
- 槽位数量随相位仪星级提升（最多 9 格）
- 战斗胜利后槽位不会自动清空，可随时在底部相位仪栏调整

[b][color=#88ccff]◆ 符文槽[/color][/b]
- 符文槽存放[color=#cc88ff]符文[/color]，提供被动增益（最多 6 格）
- 特定符文组合可激活[color=#eeee44]符文之语[/color]，获得额外套装效果
- 符文通过战斗掉落与日常任务获得

[b][color=#88ccff]◆ 相位场等级与属性点[/color][/b]
- 战斗积累相位场经验，相位场等级 [color=#88ee88]Lv1-30[/color]
- 每升 1 级获得[color=#eeee44]属性点[/color]，可在相位仪面板自由分配/回收/洗点
- 属性点加成直接作用于全体上阵单位

[b][color=#88ccff]◆ 相位仪星级[/color][/b]
- 提升相位仪星级可增加槽位数量与能量上限
- 星级还决定战斗中可部署的[color=#88ccff]前沿范围[/color]（星级越高部署区越靠前）

[color=#888888]提示：优先把主力卡装备进绿槽再开战，符文之语激活后收益可观。[/color]"""

func _get_faction_content() -> String:
	return """[b][color=#ffcc44]⚔ 势力系统[/color][/b]

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
完成任务后，在任务面板的"日常"标签页手动领取奖励：
- 点击已完成任务的 [color=#88ee88]"领取"[/color] 按钮获取奖励
- 奖励内容按难度递增，可能包括：
  - [color=#88ccff]纳米材料[/color]（养成通用资源）
  - [color=#eeee44]能量块[/color]
  - [color=#cc88ff]稀有度碎片[/color]（普通/稀有/史诗/传说，随难度提升）

[color=#888888]提示：每天花少量时间完成日常任务，日积月累可获得大量资源！[/color]"""
