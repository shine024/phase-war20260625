## 重构 evolution_panel 匹配"进化站"设计稿

### 目标
把 `scenes/ui/evolution_panel.tscn` + `.gd` 改造为设计稿"进化站"页面：**三栏布局**（左名册列表 + 中进化路径 + 右详情）+ **紫色签名色** + 1180×640 + chip 筛选。**删掉顶部 OptionButton 下拉**，选卡改为左栏列表点击。保持公开契约和 embedded 模式不变。

### 保持不变（兼容性硬约束）
- **公开方法签名**：`signal closed` / `set_embedded_mode(bool)` / `set_selected_card(card)` / `show_panel()`
- **embedded 模式行为**：`set_embedded_mode(true)` 隐藏标题/资源栏/左名册 + 清零 min_size + 右栏占满
- **业务逻辑**：所有 `_create_evolution_node` / `_update_evolution_tree` / `_update_detail_panel` / `_on_evolve_pressed` / `_on_target_selected` / `_set_stat_compare` / `_get_current_power_score` / `_get_target_power_score` 等业务方法原样保留
- **数据源**：`card.get_evolution_targets()` / `BlueprintManager.can_evolve_blueprint` / `card.calculate_evolved_stats` 全部沿用

### 改动文件
1. `scenes/ui/evolution_panel.tscn` — **完全重写**节点结构
2. `scenes/ui/evolution_panel.gd` — **重写渲染层**（节点引用 + _refresh_card_selector→_refresh_card_list + _create_card_item + 选色改紫），业务逻辑不动

---

### A. 新 .tscn 节点结构（1180×640，紫色签名色 + 顶部色条）

```
EvolutionPanel (Control, 1180×640, 紫签名色)
└─ VBoxContainer (sep=0)
   ├─ TitleRow (PanelContainer 52px, 顶部紫色色条)
   │  └─ TitleHBox: TitleMark(❖紫) + TitleLabel("战术进化站 EVOLUTION FORGE") + Spacer + MetaLabel + CloseBtn(×)
   ├─ ResourceBar (PanelContainer 36px, 占位不切换可见)
   │  └─ ResourceHBox: 当前战力/强化等级/改造数/敌源 + Spacer + 状态行
   ├─ ResultLabel (Label 24px, 始终占位不抖动)
   └─ BodyHBox (HBoxContainer, 三栏)
      ├─ LeftPanel (PanelContainer 220px) ★新增（替代 OptionButton）
      │  └─ LeftVBox: ColHead("单位名册"+计数) + ColFilter(chip:全部/可进化/终阶) + CardListScroll→CardListContainer
      ├─ MiddlePanel (PanelContainer expand, 进化路径列表)
      │  └─ MiddleVBox: PathHead("进化路径"+计数) + PathScroll→EvolutionTree
      └─ DetailPanel (PanelContainer 300px, 详情面板)
         └─ DetailScroll→DetailContent: NoSelectionLabel / TargetNamePanel / InfoPanel / RequirementsPanel / StatsPanel / ResourcePanel / ButtonArea(EvolveButton)
```

**保留的关键节点路径**（业务方法访问的，路径不变避免改业务逻辑）：
- `VBoxContainer/MainContentSplit/LeftPanel/EvolutionScroll/EvolutionTree` → 改为 `VBoxContainer/BodyHBox/MiddlePanel/MiddleVBox/PathScroll/EvolutionTree`（路径变）
- `VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/*` → 改为 `VBoxContainer/BodyHBox/DetailPanel/DetailScroll/DetailContent/*`（路径变）

**为减少改动量，.gd 改用 `%` unique_name 访问所有节点**（与 modification_panel 一致风格），不再硬编码路径。

### B. .gd 改动明细

**节点引用全部改用 `%` unique_name_in_owner**：
- 所有 `get_node_or_null("VBoxContainer/...")` → `get_node_or_null("%NodeName")`
- 删除 `card_selector`（OptionButton）相关代码，改用 `card_list_container`（VBox 列表）

**主题色切换**（金→紫）：
- `THEME_GOLD` → `DT.COLOR_VIOLET`（紫签名色）
- `THEME_GOLD_SOFT` → `DT.COLOR_VIOLET_SOFT`
- 保留 `THEME_CYAN`（情报分支色）/ `THEME_PURPLE`（势力分支色）/ `THEME_GREEN`/`THEME_RED` 不变
- `_path_type_color()` 中 "main" 改用 `DT.COLOR_VIOLET`（主线紫，与面板签名色一致）

**重写方法**：
1. `_ready()` — 节点绑定改用 `%`；chip 筛选连接
2. `_apply_embedded_layout()` — 隐藏 LeftPanel + TitleRow + ResourceBar
3. `_refresh_card_selector()` → 改名 `_refresh_card_list()`，构建左栏列表项（不用 OptionButton）
4. **新增 `_create_card_item(card)`** — 列表项样式（缩略卡图 + 卡名#N + Lv·Mx/9 + 战力，与 growth/modification 一致）
5. `_on_card_selector_changed(index)` → 删除，改用 `_on_card_list_item_pressed(card)` 直接绑定卡对象
6. `_apply_title_fonts()` — 路径改 `%` 访问
7. `_create_evolution_node()` — 路径色条/状态色改紫；选项中 button 内部样式不变（业务逻辑保留）

**新增**：
- **chip 筛选**：`_on_filter_pressed(mode)` 过滤全部/可进化/终阶（终阶=无进化目标）
- **ResultLabel 固定占位**：`visible = true` 始终，`_show_result` 只切 text 不切 visible（同 modification 修复）

### C. 关键实现细节

- **签名色**：`DT.COLOR_VIOLET (0.653, 0.546, 0.98)` 用于面板边框/title-mark/选中态/进化路径节点色条；标题文字用 `COLOR_VIOLET_SOFT`
- **顶部色条**：TitleRow StyleBoxFlat `border_width_top = 2 + border_color = violet`
- **节点访问**：全部 `%` unique_name，与 modification_panel/growth_panel 一致风格
- **9 个 stat 标签**（HP/攻击/防御/射程/移速）路径改 `%StatHP` 等
- **进化路径节点**（_create_evolution_node）：保留原业务逻辑，只把金→紫、战力对比绿色保留
- **chip 筛选**：默认"全部"激活；切换时调 `_refresh_card_list` 重渲染
- **ResultLabel 始终占位**：避免显示/隐藏抖动布局

### D. 不做的事
- 不改 main.gd / ui_lazy_loader.gd / card_info_panel.gd（公开契约不变）
- 不改业务逻辑（进化树构建/详情填充/属性对比/进化执行）
- 不改 data 层（evolution_targets/can_evolve_blueprint/calculate_evolved_stats 调用不变）
- 不改其他面板

### E. 验证
1. **Godot headless 加载 + 实例化 + _ready**（参照 modification_panel 验证脚本）
2. **公开契约检查**：`signal closed` / `set_embedded_mode` / `set_selected_card` / `show_panel` 全部存在
3. **embedded 模式检查**：`set_embedded_mode(true)` 后 LeftPanel/TitleRow/ResourceBar 不可见
4. **Grep 核对**：所有 `%NodeName` 在 .tscn 和 .gd 中配对一致
5. **%NodeName 去重**：避免 9 个 stat 标签等共享同名冲突
6. **面板尺寸**：1180×640 适配 1280×720 屏幕
7. **ResultLabel 不抖动**：切换提示时 BodyHBox 位置不变

### F. 风险与缓解
| 风险 | 缓解 |
|------|------|
| 破坏 set_embedded_mode 契约 | embedded 模式隐藏逻辑保留（LeftPanel 整体而非 OptionButton） |
| 9 个 stat 标签路径变更 | 全部用 `%StatHP` 等 unique_name，路径无关 |
| _refresh_card_selector 被外部调用？ | Grep 确认只在 _ready 调用，安全改名为 _refresh_card_list |
| THEME_GOLD 全局替换遗漏 | Grep 一一替换 + 编译验证 |
| chip 筛选破坏 embedded 模式 | embedded 模式 LeftPanel 整体隐藏，chip 自然不显示 |