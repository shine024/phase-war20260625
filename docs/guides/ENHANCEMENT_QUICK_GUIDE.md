# Phase War 快速使用指南 - 新增功能

## 🎵 音效系统

### 基础使用
```gdscript
# 播放音效
AudioManager.play_sfx("button")        # 按钮点击
AudioManager.play_sfx("hit")           # 命中音效
AudioManager.play_sfx("win")           # 胜利音效

# 播放UI音效
AudioManager.play_ui_sfx("panel_open")   # 面板打开
AudioManager.play_ui_sfx("card_pickup")  # 卡牌拾取
```

### 音量控制
```gdscript
# 设置音效音量 (0.0-1.0)
AudioManager.set_sfx_volume(0.8)

# 设置主音量
AudioManager.set_master_volume(0.9)
```

---

## 🎨 UI美化系统

### 快速美化
```gdscript
# 美化面板
UIBeautifier.beautify_panel(my_panel, "success")

# 美化按钮
UIBeautifier.beautify_button(my_button)

# 美化标签
UIBeautifier.beautify_label(title_label, "title")
UIBeautifier.beautify_label(success_label, "success")
```

### 使用增强面板基类
```gdscript
extends EnhancedPanelBase

func _ready():
    super._ready()
    set_panel_type(PanelType.SUCCESS)  # 设置面板类型
    beautify_all()                     # 美化所有子元素
```

### 主题切换
```gdscript
var theme_manager = UIEnhanced.new()
theme_manager.set_theme("neon")  # 可选: default, neon, warm
```

---

## ⚔️ 战斗界面增强

### 增强版血条
```gdscript
# 血条已经自动支持以下功能：
# - 平滑过渡动画
# - 根据血量百分比变色
# - 低血量脉动效果
# - 伤害/治疗闪烁

# 手动触发效果
hp_bar.trigger_damage_flash()  # 伤害闪烁
hp_bar.trigger_heal_flash()    # 治疗闪烁
```

### 伤害数字显示
```gdscript
# 创建各种伤害数字
DamageNumberDisplay.create_damage_number(parent, pos, 100)
DamageNumberDisplay.create_critical_damage(parent, pos, 500)
DamageNumberDisplay.create_heal_number(parent, pos, 200)
DamageNumberDisplay.create_shield_number(parent, pos, 50)
DamageNumberDisplay.create_miss(parent, pos)
```

---

## 🎓 教程系统

### 启动教程
```gdscript
# 创建并启动教程
var tutorial = preload("res://scenes/ui/interactive_tutorial.tscn").instantiate()
add_child(tutorial)
tutorial.start_tutorial("tutorial_welcome")

# 监听完成事件
tutorial.tutorial_completed.connect(func(id):
    print("教程完成: ", id)
    tutorial.queue_free()
)
```

### 快速提示
```gdscript
# 显示快速提示
tutorial.show_quick_tip("提示信息", position, 3.0)

# 显示操作提示
tutorial.show_action_tip("点击这里开始", target_position)
```

---

## 🏆 挑战模式

### 开始挑战
```gdscript
# 开始生存挑战
ChallengeModeManager.start_survival_challenge(ChallengeModeManager.ChallengeDifficulty.NORMAL)

# 开始Boss连战
ChallengeModeManager.start_boss_rush_challenge(ChallengeModeManager.ChallengeDifficulty.HARD)
```

### 检查解锁条件
```gdscript
var player_data = {"level": 10, "completed_challenges": {}}
var can_start = ChallengeDefinitions.check_unlock_requirements("survival_hard", player_data)
```

---

## 📊 排行榜系统

### 提交分数
```gdscript
# 提交挑战分数
LeaderboardManager.submit_score("survival_highscore", 20, {"time": 300.0})

# 更新战斗统计
LeaderboardManager.update_battle_stats(true, 5000, 120.0)

# 更新关卡进度
LeaderboardManager.update_level_progress(15, 3)
```

### 获取排行榜
```gdscript
# 获取前10名
var top_10 = LeaderboardManager.get_top_entries("survival_highscore", 10)

# 获取玩家排名
var my_rank = LeaderboardManager.get_player_rank("survival_highscore")

# 获取玩家统计
var stats = LeaderboardManager.get_player_stats()
```

---

## ✨ 视觉特效

### 战斗特效
```gdscript
# 爆炸特效
VisualEffectsManager.create_explosion(parent, position, 1.0, Color.RED)

# 命中特效
VisualEffectsManager.create_hit_effect(parent, position, true)  # 暴击

# 治疗特效
VisualEffectsManager.create_heal_effect(parent, position, 100)

# 护盾特效
VisualEffectsManager.create_shield_effect(parent, position)

# 升级特效
VisualEffectsManager.create_level_up_effect(parent, position)
```

### 屏幕震动
```gdscript
# 震动相机
VisualEffectsManager.create_screen_shake(camera, 5.0, 0.3)
```

---

## 🎬 动画系统

### 基础动画
```gdscript
# 淡入/淡出
AnimationUtils.fade_in(panel, 0.3)
AnimationUtils.fade_out(panel, 0.3)

# 滑入/滑出
AnimationUtils.slide_in(panel, Vector2.UP, 0.3, 50.0)
AnimationUtils.slide_out(panel, Vector2.DOWN, 0.3, 50.0)

# 缩放动画
AnimationUtils.scale_animation(button, Vector2(1.1, 1.1), 0.2)

# 弹跳动画
AnimationUtils.bounce_animation(label, 0.2, 0.4)
```

### 高级动画
```gdscript
# 震动动画
AnimationUtils.shake_animation(panel, 5.0, 0.5)

# 脉冲动画
AnimationUtils.pulse_animation(button, 0.95, 1.05, 1.0)

# 数字滚动
AnimationUtils.number_scroll(score_label, 0, 1000, 1.0)

# 进度条动画
AnimationUtils.progress_bar_animation(progress_bar, 0.0, 100.0, 0.5)
```

### 序列动画
```gdscript
# 序列执行多个动画
var animations = [
    {"node": panel1, "properties": {"modulate:a": 1.0}, "duration": 0.3},
    {"node": panel2, "properties": {"modulate:a": 1.0}, "duration": 0.3, "delay": 0.2}
]
AnimationUtils.sequence_animation(animations)
```

---

## 🎯 实用示例

### 创建美化按钮
```gdscript
func create_beautiful_button(text: String) -> Button:
    var button = Button.new()
    button.text = text
    UIBeautifier.beautify_button(button)

    # 添加点击动画
    button.pressed.connect(func():
        AnimationUtils.bounce_animation(button, 0.1, 0.2)
    )

    return button
```

### 显示战斗结果
```gdscript
func show_battle_result(player_won: bool, damage: int, time: float):
    # 创建伤害数字
    if player_won:
        VisualEffectsManager.create_level_up_effect(self, Vector2(200, 200))
    else:
        VisualEffectsManager.create_hit_effect(self, Vector2(200, 200), true)

    # 更新排行榜
    LeaderboardManager.update_battle_stats(player_won, damage, time)

    # 显示结果面板
    var result_panel = create_result_panel(player_won, damage, time)
    add_child(result_panel)
    AnimationUtils.slide_in(result_panel, Vector2.UP, 0.4)
```

### 完整的面板美化流程
```gdscript
func create_enhanced_panel() -> void:
    var panel = EnhancedPanelBase.new()
    panel.set_panel_type(EnhancedPanelBase.PanelType.INFO)
    add_child(panel)

    # 添加内容
    var content = VBoxContainer.new()
    var title = Label.new()
    title.text = "标题"
    var button = Button.new()
    button.text = "确定"

    content.add_child(title)
    content.add_child(button)
    panel.set_content(content)

    # 美化所有元素
    panel.beautify_all()

    # 添加关闭动画
    button.pressed.connect(func():
        panel.close_with_animation()
    )
```

---

## 🔧 配置和自定义

### 主题颜色自定义
```gdscript
var theme_manager = UIEnhanced.new()

# 获取主题颜色
var primary_color = theme_manager.get_theme_color("primary")
var success_color = theme_manager.get_theme_color("success")

# 创建自定义样式
var custom_style = theme_manager.create_panel_style(
    Color(0.1, 0.15, 0.2, 0.95),  # 背景色
    Color(0.2, 0.8, 0.4, 1.0),     # 边框色
    10.0                           # 圆角半径
)
```

### 排行榜格式化
```gdscript
# 格式化分数显示
var formatted = LeaderboardDefinitions.format_score(1500.5, "damage")
# 输出: "1,500 伤害"

var time_formatted = LeaderboardDefinitions.format_score(125.3, "time")
# 输出: "02:05"

# 获取排名颜色
var rank_color = LeaderboardDefinitions.get_rank_color(1)  # 金色
```

---

## 📝 注意事项

1. **性能考虑**：大量同时播放的特效可能影响性能，建议合理控制数量
2. **内存管理**：特效会自动销毁，但手动创建时要注意及时释放
3. **兼容性**：新系统与现有代码兼容，可以逐步迁移
4. **音效文件**：建议添加真实音效文件以获得最佳体验

---

## 🆘 常见问题

### Q: 如何自定义主题颜色？
A: 创建自定义UIEnhanced实例并设置颜色主题，或者直接使用create_panel_style()等方法。

### Q: 特效性能如何优化？
A: 使用对象池、限制同时显示的特效数量、避免在_process()中频繁创建特效。

### Q: 排行榜如何实现在线功能？
A: 当前是本地排行榜，需要添加网络通信模块连接到服务器。

### Q: 教程系统如何自定义？
A: 修改TutorialDefinitions中的教程配置，或创建新的教程步骤。

---

*更新日期：2026年3月30日*
*版本：v1.0*
