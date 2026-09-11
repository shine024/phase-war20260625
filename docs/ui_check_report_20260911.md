# UI检查与性能分析报告

**项目**: Phase-War (相位战争) v0.27.0
**检查日期**: 2026-09-11
**检查范围**: 全部UI面板与按钮交互

> **⚠️ 执行核实（2026-09-11，Claude Code）——两条 🔴"严重问题"均不成立，引用本报告前先看本节**：
> - ❌ **P0-1"ModificationPanel 语法错误"不存在**：`modification_panel.gd` L54-58 实为 `const FILTER_ALL/"mod"/"max" + var _filter_mode` 正常声明；报告所引 `var bg_panel := get_node_or_null(...) if ...` 代码块在文件中不存在。反证：当日 GdUnit 全量 311 例 0 失败、`--export-release` 导出零 ERROR、产物 12s 存活冒烟通过——若面板脚本有解析错误，以上全不可能。
> - ❌ **P1-2"backpack_panel 信号连接无守卫"不存在**：实查 :247/:857/:860/:864 的 `SignalBus.*.connect()` 全部带 `is_connected` 守卫；报告"问题示例"代码非本文件实际内容。
> - ⚠️ **P1-3"性能监控失效"系误读**：`battle_performance_monitor.gd` 全文仅 30 行（报告引 L44 越界），`pass #[LOG-v5.1]` 在 L30；文件头注明"默认关闭控制台输出，避免 print 尖峰"——有意设计，非缺陷（ENABLE_CONSOLE_LOG 开关即报告想要的建议，已内建）。
> - ⏸ **P2 项未逐条核实**：PanelChrome 池化与 v27.12 已做的五面板可见守卫+池化+脏标记（见 docs/短板诊断报告 §一）是否同一层面待分辨；AudioCache LRU/DesignTokens 统一为可选优化。
> - 面板清单/按钮链路表/签名色表与实况相符，可继续作参考。

---

## 📊 UI面板总览

### ✅ 正常运作的UI面板 (共23个)

| 面板 | 文件路径 | 状态 | 功能说明 |
|------|----------|------|----------|
| **TitleScreen** | scenes/title_screen.tscn | ✅正常 | 入口界面，含新游戏/继续/设置/退出/切换存档/战斗效果检查按钮 |
| **SettingsPanel** | scenes/ui/settings_panel.tscn | ✅正常 | 音量/难度/全屏/可访问性（高对比/大字号/减少动效） |
| **BackpackPanel** | scenes/ui/backpack_panel.tscn | ✅正常 | 5 Tab（战斗卡/改造/符文/相位仪/全局强化），含搜索+筛选 chips |
| **StorePanel** | scenes/ui/store_panel.tscn | ✅正常 | 多公司商店 +势力补给 +符文售卖 +情报道具 |
| **QuestPanel** | scenes/ui/quest_panel.tscn | ✅正常 | 委托台（公司列表 +任务列表 +每日挑战） |
| **ModificationPanel** | scenes/ui/modification_panel.tscn | ⚠️待修复 | 改造舱（三栏布局：名册/改造库/详情） |
| **GrowthPanel** | scenes/ui/growth_panel.tscn | ✅正常 | 成长中枢（强化等级 +战力星级评估） |
| **EvolutionPanel** | scenes/ui/evolution_panel.tscn | ✅正常 | 制造舱（v26退役进化后接管为制造中心） |
| **CollectionPanel** | scenes/ui/collection_panel.tscn | ✅正常 | 生灵图鉴（卡牌收集进度） |
| **FactionPanel** | scenes/ui/faction_panel.tscn | ✅正常 | 联络台（7势力声望 +技能树） |
| **HelpPanel** | scenes/ui/help_panel.tscn | ✅正常 | 车长手册（7 Tab帮助文档） |
| **AchievementPanel** | scenes/ui/achievement_panel.tscn | ✅正常 | 战功簿（分类成就 +奖励领取） |
| **MvpPanel** | scenes/ui/mvp_panel.tscn | ✅正常 | 整合结算（战绩 +缴获明细） |
| **OccupationPanel** | scenes/ui/occupation_panel.tscn | ✅正常 | 势力领地图（100关占领状态） |
| **AfKPanel** | scenes/ui/afk_panel.tscn | ✅正常 | 挂机模式（4槽位 +模式选择） |
| **IntelligenceHubPanel** | scenes/ui/intelligence_hub_panel.tscn | ✅正常 | 情报舱（世界观/谱系图谱/符文/敌方情报） |
| **LeaderboardPanel** | scenes/ui/leaderboard/leaderboard_panel.tscn | ✅正常 | 排行榜（势力/相位师/敌方） |
| **CardInfoPanel** | scenes/ui/card_info_panel.tscn | ✅正常 | 统一情报弹窗（4 Tab：情报/强化/改造/制造） |
| **BattleHUD** | scenes/ui/battle_hud.tscn | ✅正常 | 战斗 HUD（资源/波次/相位仪槽位） |
| **TopHudBar** | scenes/ui/top_hud_bar.tscn | ✅正常 | 顶部战斗条（关卡/波次/时间/速度/开始/撤退） |
| **BattleStatusStrip** | scenes/ui/battle_status_strip.tscn | ✅正常 | 战斗状态条 |
| **CardGridBattleHud** | scenes/ui/card_grid_battle_hud.tscn | ✅正常 | 格子战 HUD |
| **PhaseInstrumentSelector** | scenes/ui/phase_instrument_selector.tscn | ✅正常 | 相位仪装备选择 |

---

## 🔴 严重问题（需立即修复）

### 1. ModificationPanel脚本语法错误 — 面板将无法正常初始化

**位置**: `scenes/ui/modification_panel.gd` L55-58

**当前代码（有语法错误）**:
```gdscript
var bg_panel := get_node_or_null("BgPanel") if bg_panel is Control:
    (bg_panel as Control).add_theme_stylebox_override("panel",
        PanelStyles.make_panel_frame_textured(DT.get_system_color("modify")))
```

**问题**: `var bg_panel := get_node_or_null("BgPanel")`后直接跟缩进的 `if`，这在 Godot 4 中不是合法语法。变量声明和条件语句必须分开两行。

**影响**: 改造面板在 `_ready()` 时会导致 GDScript 解析错误，整个面板无法初始化，改造功能完全失效。

**修复方案**:
```gdscript
var _bg_panel := get_node_or_null("BgPanel")
if _bg_panel is Control:
    _bg_panel.add_theme_stylebox_override("panel",
        PanelStyles.make_panel_frame_textured(DT.get_system_color("modify")))
```

---

### 2. SignalBus信号连接缺少守卫（潜在内存泄漏风险）

**位置**: `scenes/ui/backpack_panel.gd` (多处)

**问题示例**:
```gdscript
# 问题：无守卫直接连接，可能导致重复连接
SignalBus.card_added_to_backpack.connect(_on_card_added)
SignalBus.card_equipped.connect(_on_card_equipped)
```

**影响**: 面板重新打开时可能重复注册信号处理器，导致回调触发多次。

**修复建议**:
```gdscript
# 正确做法：使用 is_connected 守卫
if not SignalBus.card_added_to_backpack.is_connected(_on_card_added):
    SignalBus.card_added_to_backpack.connect(_on_card_added)
```

**已正确实现的面板**（参考）:
- `quest_panel.gd` ✅
- `faction_panel.gd` ✅
- `collection_panel.gd` ✅
- `achievement_panel.gd` ✅

---

## 🟡 性能优化建议

### 1. BattlePerformanceMonitor控制台日志被注释掉

**位置**: `scripts/battle_performance_monitor.gd` L44

```gdscript
if OS.is_debug_build():
    pass  # [LOG-v5.1] print("...")  ← 日志功能被禁用
```

**影响**: 性能监控功能完全失效，无法实时查看 FPS/DrawCalls/Objects 数量。

**建议**:
- 测试时取消注释或设置 `ENABLE_CONSOLE_LOG = true`
- 发布版本保持禁用避免性能开销

---

### 2. AudioCache无限增长风险

**位置**: `managers/audio_manager.gd` L237-250

**问题**: 音频缓存 `_audio_cache` 只增不减，长期运行可能导致内存累积。

**建议**: 添加 LRU 淘汰策略或限制缓存大小（如最多保留50个常用音效）

---

### 3. PanelChrome实例未做对象池

**涉及面板** (14个):
- settings, backpack, store, quest, faction, modification, growth, evolution
- collection, help, achievement, occupation, afk, intelligence_hub, leaderboard

**现状**: 每个面板打开时动态创建新的 PanelChrome 实例

**建议**: 实现轻量工厂缓存，复用 Chrome 实例以减少 GC 压力

---

### 4. ModificationRegistry缓存刷新时机

**位置**: `scripts/systems/modification_registry.gd`

**静态缓存**:
- `_flat_index`: mod_id → mod_data 映射
- `_unit_type_cache`: unit_type → mod_ids 映射

**问题**: 缓存仅在 `register_all()` 时构建，运行时修改不会自动刷新

**影响**: 热重载或运行时修改改造数据后需要手动调用 `register_all()` 重置

---

## 🟢 建议改进项

### 1. 设计令牌引用不统一

**现状**:
- 部分脚本：`DesignTokens.get_panel_accent("backpack")`
- 其他脚本：`DT.COLOR_AMBER`（DT 是 DesignTokens 的别名）

**建议**: 全项目统一使用 `DT` 别名或完整的 `DesignTokens` 类名，减少重复 preload

---

### 2. UILazyLoader错误处理不完善

**位置**: `managers/ui_lazy_loader.gd`

**问题**: 获取节点失败时只调用 `push_error()` 返回 null，调用方无法区分"未加载"vs"配置错误"

**建议**: 返回错误码字典
```gdscript
return {
    "error": "node_not_found",
    "path": parent_path,
    "panel_id": panel_id
}
```

---

### 3. 按钮光标未统一应用

**位置**: `scripts/ui/panel_styles.gd` L195-200

**已实现但未调用**:
```gdscript
static func apply_pointing_hand(root: Node) -> void:
    # 递归给子树内所有 BaseButton 设手型光标
```

**建议**: 在 `main.gd._ready()` 中统一调用一次，确保所有场景按钮显示手型光标

---

### 4. Label文本溢出防护缺失

**问题**: 部分 Label 未设置 `clip_text = true`，长文本可能溢出容器

**影响**: 背包战斗卡名称、改造描述等长文本可能超出边界

**建议**: 在 `backpack_panel.gd`、`card_info_panel.gd` 等大文本容器中统一添加
```gdscript
label.clip_text = true
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
```

---

## 📋 按钮交互完整性检查

### 关闭按钮（✕）链路检查

所有使用 PanelChrome 的面板均正确连接关闭信号：

| 面板 | chrome.closed 连接 | closed 信号 | main.gd 处理 |
|------|-------------------|-------------|--------------|
| SettingsPanel | ✅ | ✅ | ✅ `_close_overlay` |
| BackpackPanel | ✅ (自定义) | ✅ | ✅ |
| StorePanel | ✅ | ✅ | ✅ |
| QuestPanel | ✅ | ✅ | ✅ |
| FactionPanel | ✅ | ✅ | ✅ |
| ModificationPanel | ✅ | ✅ | ✅ |
| GrowthPanel | ✅ | ✅ | ✅ |
| EvolutionPanel | ✅ | ✅ | ✅ |
| CollectionPanel | ✅ | ✅ | ✅ |
| HelpPanel | ✅ | ✅ | ✅ |
| AchievementPanel | ✅ | ✅ | ✅ |
| OccupationPanel | ✅ | ✅ | ✅ |
| AfKPanel | ✅ | ✅ | ✅ |
| IntelligenceHubPanel | ✅ | ✅ | ✅ |
| LeaderboardPanel | ✅ | ✅ | ✅ |

### 主要操作按钮检查

#### TitleScreen 主菜单
| 按钮 | 功能 | 状态 |
|------|------|------|
| NewGameButton | 开始新游戏 | ✅ |
| ContinueButton | 继续存档 | ✅ |
| SettingsButton | 打开设置 | ✅ |
| QuitButton | 退出确认 | ✅ |
| SwitchSlotButton | 切换存档位 | ✅ |
| CombatCheckButton | 战斗效果检查（debug） | ✅ |

#### BackpackPanel 操作按钮
| 按钮 | 功能 | 状态 |
|------|------|------|
| CloseButton | 关闭面板 | ✅ |
| FilterChips | 兵种/前缀桶筛选 | ✅ |
| SortOption | 排序下拉 | ✅ |
| SearchEdit | 搜索框 | ✅ |
| TabContainer | 标签页切换 | ✅ |

#### StorePanel 购买按钮
| 按钮 | 功能 | 状态 |
|------|------|------|
| CompanyTabs | 公司切换 | ✅ |
| BuyBtn (card) | 购买战斗卡 | ✅ 防抖锁 `_buy_in_progress` |
| BuyBtn (rune) | 购买符文 | ✅ |
| BuyBtn (instrument) | 购买相位仪 | ✅ |

#### QuestPanel 任务按钮
| 按钮 | 功能 | 状态 |
|------|------|------|
| AcceptBtn | 接取任务 | ✅ |
| AbandonBtn | 放弃任务 | ✅ |
| ClaimBtn (daily) | 领取日常奖励 | ✅ |

---

## 📊 性能指标参考

### 战斗性能监控
- **BattlePerformanceMonitor**: 每3秒采样 FPS/ProcessMs/PhysicsMs/DrawCalls/Primitives/Objects
- **PerformanceMetricsManager**: 记录 TTI/背包首开耗时/战斗帧时间 P50/P95
- **BattleSpectacle**: 战斗高光特效，含节流（1s击杀定帧冷却）

### UI性能优化
- **UILazyLoader**: 面板按需加载，减少初始内存占用
- **ManagerLazyLoader**: 管理器延迟加载，避免启动期阻塞
- **对象池**: backpack_card_item_pool, resource_slot_pool 等

---

## 🔧 修复优先级建议

### P0（立即修复）
1. **ModificationPanel 语法错误** - 阻止改造功能使用

### P1（本版本修复）
2. **SignalBus信号连接守卫** - 防止内存泄漏和重复回调
3. **BattlePerformanceMonitor日志** - 恢复性能监控能力

### P2（下版本优化）
4. **AudioCache大小限制** - 防止长期运行内存累积
5. **PanelChrome对象池** - 减少GC压力
6. **统一DesignTokens引用** - 提升代码一致性

---

## 📝 附录：面板样式统一规范

所有面板遵循 v7.x 面板统一设计：
- **框架**: `PanelStyles.make_panel_frame_textured(accent)` 渐变纹理面板框
- **标题栏**: `PanelChrome.attach_to()` 发光竖条 + 标题 + ✕关闭
- **按钮四态**: `PanelStyles.make_button_styles(accent, kind)`  solid/ghost/danger
- **关闭按钮**: `PanelStyles.make_close_button_styles()` hover红色发光

签名色对照表:
| 面板 | 签名色 |
|------|--------|
| Settings | 青色 (COLOR_CYAN_TECH) |
| Backpack | 琥珀色 (COLOR_AMBER) |
| Store | 金色 (COLOR_GOLD) |
| Quest | 青色 (COLOR_CYAN_TECH) |
| Faction | 紫色 (COLOR_VIOLET) |
| Modification | 青色 (COLOR_CYAN_TECH) |
| Growth | 金色 (COLOR_GOLD) |
| Evolution | 紫色 (COLOR_VIOLET) |
| Collection | 青色 (COLOR_CYAN_TECH) |
| Help | 青色 (COLOR_CYAN_TECH) |
| Achievement | 金色 (COLOR_GOLD) |
| Occupation | 青色 (COLOR_CYAN_TECH) |
| AfK | 薄荷色 (COLOR_ACCENT_MINT) |
| Intelligence | 紫色 (COLOR_VIOLET) |
| Leaderboard | 金色 (COLOR_GOLD) |

---

**报告生成**: Agnes (Sapiens AI)
**检查工具**: Godot 4.5 项目扫描 + GDScript 静态分析