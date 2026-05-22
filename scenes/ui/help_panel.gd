extends PanelContainer
## 帮助面板：显示游戏各类系统说明
## 包含战斗基础、卡牌成长、法则卡、势力系统、日常任务 五个Tab

signal closed

# UI 组件引用
@onready var close_button: Button = $Margin/VBox/CloseButton
@onready var tab_container: TabContainer = $Margin/VBox/TabContainer

# 动画参数
var _anim_duration: float = 0.25
var _is_open: bool = false

func _ready() -> void:
	# 初始状态隐藏
	visible = false
	modulate.a = 0.0

	# 连接关闭按钮
	if close_button:
		close_button.pressed.connect(_on_close)

	# 填充 Tab 内容
	_populate_tabs()

## 打开帮助面板
func show_panel() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, _anim_duration).set_trans(Tween.TRANS_FADE)
	# 轻微缩放动画
	scale = Vector2(0.9, 0.9)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), _anim_duration).set_trans(Tween.TRANS_BACK)

## 关闭帮助面板
func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, _anim_duration).set_trans(Tween.TRANS_FADE)
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

	# Tab 2: 法则卡
	_add_tab("法则卡", _get_phase_law_content())

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
每场战斗开始时，你将获得一定数量的 [color=#ff9944]能量点数[/color]。
部署不同单位消耗不同的能量，合理分配能量是获胜的关键。
- [color=#88ee88]普通单位[/color]：消耗 1-2 能量
- [color=#eeee44]精英单位[/color]：消耗 3-5 能量
- [color=#ee6644]传说单位[/color]：消耗 6+ 能量
部分技能和装备可以临时增加或减少能量消耗。

[b][color=#88ccff]◆ 部署单位[/color][/b]
从手牌中选择单位放置到战场上。
每个单位有其 [color=#88ee88]攻击力[/color]、[color=#ee6644]生命值[/color] 和 [color=#88ccff]特殊技能[/color]。
部署位置会影响单位的战斗效果，注意利用地形优势。

[b][color=#88ccff]◆ 相位场驱动器保护[/color][/b]
相位场驱动器是你的核心目标，也是敌方的主要攻击目标。
- 驱动器拥有独立的 [color=#88ee88]护盾值[/color] 和 [color=#ee6644]结构值[/color]
- 护盾值会在每回合自动恢复一定量
- 当结构值降为 0 时，驱动器被摧毁，战斗失败
- 可以部署防御型单位或使用技能来保护驱动器

[b][color=#88ccff]◆ 回合流程[/color][/b]
1. [color=#888888]准备阶段[/color]：查看手牌，规划部署
2. [color=#88ee88]部署阶段[/color]：消耗能量放置单位和技能
3. [color=#eeee44]战斗阶段[/color]：单位自动执行攻击
4. [color=#888888]结算阶段[/color]：计算伤害，检查胜负

[color=#888888]提示：合理搭配前排防御和后排输出单位，形成有效的战斗阵线。[/color]"""

func _get_card_growth_content() -> String:
	return """[b][color=#ffcc44]⬆ 卡牌成长[/color][/b]

[b][color=#88ccff]◆ 基本成长[/color][/b]
成长系统允许你直接培养背包中的卡牌，提升作战能力。
- 在成长面板中选择你拥有的卡牌
- 消耗研究点执行升星
- 达到指定星级后可进行改装分支选择

[b][color=#88ccff]◆ 卡牌类型[/color][/b]
战斗卡已一体化，不再需要手动拼装平台与武器。
- 战斗卡：直接决定单位能力
- 能量卡：提供资源节奏
- 法则卡：提供战术效果并可同样成长

[b][color=#88ccff]◆ 强化突破[/color][/b]
卡牌成长核心分两步：
- [color=#88ee88]升星[/color]：消耗研究点，提升基础强度
- [color=#cc88ff]改装[/color]：在关键星级解锁分支，形成战术差异

[color=#888888]提示：优先培养常用主力卡，成长收益最高。[/color]"""

func _get_phase_law_content() -> String:
	return """[b][color=#ffcc44]Ψ 法则卡[/color][/b]

法则已并入统一卡牌体系，不再使用独立法则面板。

[b][color=#88ccff]◆ 被动法则[/color][/b]
被动法则可提供持续增益效果：
- [color=#88ee88]能量共鸣[/color]：每回合额外恢复 1 点能量
- [color=#eeee44]相位护盾[/color]：每回合开始时为驱动器恢复护盾
- [color=#88ccff]时间加速[/color]：部署阶段可多放置一个单位
- [color=#cc88ff]物质凝聚[/color]：卡牌部署成本降低 10%
- [color=#ee6644]毁灭法则[/color]：所有单位攻击力提升 5%

被动法则可以通过 [color=#cc88ff]研究系统[/color] 解锁和升级。

[b][color=#88ccff]◆ 主动法则[/color][/b]
主动法则可在战斗中手动释放，具有即时效果：
- [color=#88ee88]相位震荡[/color]：对敌方全体造成一次伤害
- [color=#eeee44]时空冻结[/color]：冻结敌方一个单位一回合
- [color=#88ccff]能量汲取[/color]：立即获得额外能量点数
- [color=#cc88ff]逆转因果[/color]：复活一个已阵亡的己方单位
- [color=#ee6644]维度裂隙[/color]：召唤额外单位加入战场

主动法则使用后需要冷却数回合才能再次使用。

[b][color=#88ccff]◆ 成长方式[/color][/b]
法则卡与其他卡牌一致：
- 可通过掉落或商店获得
- 在成长面板进行升星
- 在成长面板进行改装分支

[color=#888888]提示：将法则卡与战斗卡协同培养，能显著提升阵容上限。[/color]"""

func _get_faction_content() -> String:
	return """[b][color=#ffcc44]⚔ 势力系统[/color][/b]

游戏中有多个势力，每个势力都有独特的背景故事、奖励和专属内容。

[b][color=#88ccff]◆ 势力声望[/color][/b]
通过与势力的交互来提升声望等级：
- [color=#888888]中立[/color]（0-99）：基础权限，可购买普通商品
- [color=#88ee88]友好[/color]（100-499）：解锁特殊商品和任务
- [color=#eeee44]尊敬[/color]（500-999）：获得势力专属卡牌来源与许可函
- [color=#cc88ff]崇拜[/color]（1000+）：最高等级，解锁传说级奖励

提升声望的方式：
- 完成势力委托任务
- 捐赠资源给势力
- 在特定战斗中选择支持该势力的决策

注意：某些势力的声望提升可能导致敌对势力的声望下降！

[b][color=#88ccff]◆ 势力商店[/color][/b]
每个势力都有独立的商店，出售独特的物品：
- [color=#88ee88]基础物资[/color]：纳米材料、研究点数等
- [color=#eeee44]势力卡牌[/color]：该势力特色战斗卡与法则卡
- [color=#cc88ff]专属技能书[/color]：只能在该势力商店购买的技能
- [color=#ee6644]传说物品[/color]：崇拜等级才能购买的顶级道具

商店库存每日刷新，高声望等级解锁更多商品栏位。

[b][color=#88ccff]◆ 势力任务[/color][/b]
势力会定期发布委托任务，完成可获得声望和专属奖励。
任务类型包括：战斗任务、收集任务、成长任务和探索任务。
更高声望等级解锁更困难但更丰厚的委托任务。

[color=#888888]提示：不必专注于单一势力，适度发展多个势力可以获得更丰富的资源。[/color]"""

func _get_daily_quest_content() -> String:
	return """[b][color=#ffcc44]📋 日常任务[/color][/b]

日常任务是每日更新的重复性任务，是获取稳定资源收益的重要途径。

[b][color=#88ccff]◆ 每日刷新[/color][/b]
- 任务列表在每天 [color=#eeee44]凌晨 4:00[/color] 自动刷新
- 每日提供 [color=#88ee88]4-6 个[/color] 日常任务
- 未完成的任务在刷新后会被替换
- 未领取的奖励会保留到次日刷新前
- 可以消耗 [color=#cc88ff]刷新券[/color] 手动刷新任务列表（最多 3 次/天）

[b][color=#88ccff]◆ 难度分级[/color][/b]
日常任务分为三个难度等级：
- [color=#88ee88]★ 普通任务[/color]
  完成条件简单，奖励基础资源
  示例：完成 1 场战斗、完成 1 次升星

- [color=#eeee44]★★ 困难任务[/color]
  需要更多操作或更高技巧
  示例：使用特定属性单位获胜 3 次、完成 3 次改装

- [color=#ee6644]★★★ 挑战任务[/color]
  高难度，奖励丰厚稀有资源
  示例：不损失驱动器结构值通过关卡、连击击败 10 个敌人

[b][color=#88ccff]◆ 奖励领取[/color][/b]
完成日常任务后，需要手动领取奖励：
- 点击任务列表中的 [color=#88ee88]"领取"[/color] 按钮获取奖励
- 支持一键领取所有已完成任务的奖励
- 奖励内容可能包括：
  - [color=#88ccff]纳米材料[/color]
  - [color=#eeee44]研究点数[/color]
  - [color=#cc88ff]研究点与卡牌研究数据[/color]
  - [color=#88ee88]刷新券[/color]
  - [color=#ee6644]势力声望[/color]

[b][color=#88ccff]◆ 活跃度奖励[/color][/b]
每日完成指定数量的任务可解锁额外的活跃度宝箱：
- 完成 2 个任务：[color=#88ee88]基础宝箱[/color]
- 完成 4 个任务：[color=#eeee44]进阶宝箱[/color]
- 完成全部任务：[color=#ee6644]精英宝箱[/color]

[color=#888888]提示：每天花少量时间完成日常任务，日积月累可获得大量资源！[/color]"""
