# 性能优化：商店 + 背包 + 点卡详情卡顿修复

## 总体策略

三个独立的性能层，每个都遵循一个核心理念：**不要在用户等待的那一帧做可以延后或可以跳过的工作**。

- **商店**：打开分帧 + 购买信号去重（避免一次买卡触发 2-3 次全量重建）
- **背包标签**：补全签名去重（相位仪标签新增）+ 补全对象池 release 链路（让已声明的池真正生效）
- **点卡详情**：3 个子面板改为 Tab 切换时才刷（当前点一张卡同步刷 3 个，首次还实例化 3 个完整 .tscn）

所有改动**不动数据源**（InstanceRegistry 全集查询保持不变，遵守铁律 2），只优化刷新时机和 UI 节点复用。**向后兼容**：功能行为不变，只改变"何时刷新"和"是否复用节点"。

---

## 阶段 A：商店打开分帧 + 信号去重

### A1. store_panel.gd 加打开分帧（仿 backpack_presenter 模式）

**改动**：
1. 新增字段：`_open_refresh_inflight: bool = false`（单飞守卫）、`_buy_in_progress` 已存在（L28，复用）
2. 新增 `on_overlay_opened()` 方法：`_open_refresh_inflight` 守卫 + `call_deferred("_run_open_refresh_pipeline")`
3. 新增 `_run_open_refresh_pipeline()`：参考 `backpack_presenter.gd:640-667` 的 3 步拆帧——
   - Step 1: 校验可见性（`is_visible_in_tree()`，不可见直接退出）
   - Step 2: `await get_tree().process_frame` 后调 `_refresh_balance()`（轻量，立即刷余额让用户看到数字）
   - Step 3: `await get_tree().process_frame` 后调 `_refresh_items()`（重活，单独一帧）
   - 复位 `_open_refresh_inflight = false`
4. `_ready()` L44 的 `_refresh_items()` 调用**保留**（首次实例化 LazyLoader 后立即 visible 场景需要兜底），但 `_on_resources_changed` 路径改为延迟刷新（见 A2）

### A2. main.gd 新增 store 分支（关键，否则 A1 无效）

`main.gd` `_open_overlay()` L349 附近的 match 里**没有 `panel_key == "store"` 分支**，store_panel 的 `on_overlay_opened()` 永远不会被调用。

**改动**：在 L356 后（backpack 分支后）新增：
```gdscript
elif panel_key == "store":
    var store_panel: Node = overlay.get_node_or_null("CenterContainer/StorePanel")
    if store_panel == null:
        store_panel = overlay.find_child("StorePanel", true, false)
    if store_panel and store_panel.has_method("on_overlay_opened"):
        store_panel.on_overlay_opened()
```

### A3. resources_changed 信号去重（解决一次购买 2-3 次全量重建）

**根因**：`basic_resource_manager.add_resource` 每次 emit `resources_changed`（L23/L47），`_on_resources_changed` L74-76 无条件全量刷；同时 `_on_buy_pressed` L740/L745 自身又刷。一次买 permit 卡 = 3 次 `_refresh_items()`。

**改动**（store_panel.gd）：
1. 新增字段 `_suppress_resources_refresh: bool = false`
2. `_on_resources_changed()` L74-76 改为：
   ```gdscript
   func _on_resources_changed() -> void:
       _refresh_balance()  # 余额轻量，保持即时刷新
       if _suppress_resources_refresh:
           return  # 购买流程自身会刷新 items，跳过回弹
       _refresh_items()
   ```
3. 4 个购买回调（`_on_buy_pressed` L699、`_on_buy_rune` L353、`_on_buy_intel_item` L456、`_on_buy_instrument_pressed` L756）入口置 `true`，finally 段或延迟刷新前置 `false`：
   ```gdscript
   _suppress_resources_refresh = true
   # ... 购买逻辑 ...
   _suppress_resources_refresh = false
   _refresh_items()  # 统一由购买流程刷新一次
   ```

**效果**：一次购买从 2-3 次 `_refresh_items()` 降到 1 次。

### A4. 购买流程延迟刷新改分帧（可选，低优先级）

`_on_buy_pressed` L745 的 `_refresh_items()` 在 `await 0.4s` 后同步执行。可进一步改为 `call_deferred("_refresh_items")` 避免挤在反馈动画同帧。改动小，纳入 A3 一起做。

---

## 阶段 B：背包 5 标签签名去重 + 对象池补全

### B1. 相位仪标签新增签名去重（唯一完全无守护的标签）

**改动**（backpack_panel.gd）：
1. L112 后新增字段：`var _last_phase_inst_signature: String = "__INIT__"`
2. `refresh_phase_instruments_tab()` L1080-1111 在 `_clear_phase_inst_list()` 调用前插入签名守卫（仿 `refresh_runes_tab` L958-968 模式）：
   - key = `inst_id:[E]equipped|star`（含装备状态，参考符文标签的 `[E]` 标记最佳实践）
   - 命中签名 → `return`
   - 未命中 → 写签名 + 继续 `_clear_phase_inst_list()`
3. 签名构造位置：在 `sorted_instruments` 排序后、`_clear_phase_inst_list()` 之前

**效果**：相位仪标签每次打开背包/切 tab 时，数据未变直接跳过全量手搓重建（当前每次开背包都重建 N 个 10+ 节点的 item）。

### B2. 补全对象池 release 链路（让已声明的池真正生效）

**现状**：5 个非战斗卡标签的清空路径全用 `_clear_grid_children`（L1505-1508 直接 `queue_free`）或等价 `queue_free`，池只 acquire 不 release，永远空。

**改动**（backpack_panel.gd）：新增通用池化清空函数，按 meta 分流回收（参考 `_flush_rebuild_card_grid` L419-437 的分流模式）：
```gdscript
func _clear_grid_to_pool(grid: GridContainer, pool: Array, meta_key: String) -> void:
    for child in grid.get_children():
        grid.remove_child(child)
        if is_instance_valid(child) and child.has_meta(meta_key):
            pool.append(child)
            child.visible = false
        else:
            child.queue_free()
```

把以下 5 个清空调用点改为走池：
| 标签 | 当前清空位置 | 改为 | 对应池 |
|------|------------|------|--------|
| 改造 intel | L796 `_clear_grid_children(_intel_grid)` | `_clear_grid_to_pool(_intel_grid, _resource_slot_pool, "is_resource_slot")` + 给 acquire 处（L831 `ResourceSlotScene.instantiate()`）加池化 + 加 meta | `_resource_slot_pool` |
| 属性 stat_boosts | L909-911 `queue_free` 循环 | `_clear_grid_to_pool(_stat_boosts_grid, _stat_boost_slot_pool, "is_stat_boost")` | `_stat_boost_slot_pool` |
| 符文 runes grid | L969 `_clear_grid_children(_runes_grid)` | `_clear_grid_to_pool(_runes_grid, _rune_slot_pool, "is_rune_slot")` + acquire 处 L1394 已有池化，加 meta 标记 | `_rune_slot_pool` |
| 资源 resources | L1536 `_clear_grid_children(_resources_grid)` | `_clear_grid_to_pool(_resources_grid, _resource_slot_pool, "is_resource_slot")` + acquire 处 L1552 加池化 | `_resource_slot_pool` |
| 相位仪 | L1115-1119 `_clear_phase_inst_list` 的 `queue_free` | 暂不池化（手搓节点结构复杂，签名去重已能解决主要问题；池化收益小风险高，留待后续） | — |

**注意**：acquire 侧（`_add_stat_boost_item` L1841、`_add_rune_item` L1392、resources/intel 的 instantiate 处）需要：
- 优先从池 pop
- 复用前复位 `visible = true`、`modulate = Color(1,1,1,1)`（参考 `_add_card_item` L1623-1626）
- 复用前断开旧信号连接再重连（参考 `_add_rune_item` L1407-1408 已有此模式）
- 确保 `set_meta(meta_key, true)` 打上标记

### B3. 符文信息栏 refresh_rune_info_panel 轻量化

**现状**：`refresh_rune_info_panel` L997-1071 每次切符文 tab 都重建 VBox + Label（无池无签名）。但它被 `refresh_runes_tab` L991 连带调用，B1/B2 修好后只要 grid 签名命中就会连带跳过。

**改动**：在 `refresh_rune_info_panel` 开头加签名守卫（key = 激活符文之语 id 列表），命中跳过。改动小，纳入 B2。

### B4. 移除 _diag_card_item_internals 空跑调用（附带清理）

**现状**：`_flush_rebuild_card_grid` L461 每次重建后调 `_diag_card_item_internals`（L505-548），函数内全 `pass` + 注释 print，但仍遍历 item 整个节点树。

**改动**：删除 L461 的调用点（函数体可保留或一并删除，低风险）。改动 1 行。

---

## 阶段 C：点卡详情子面板延迟刷新（最重尖峰）

### C1. card_info_panel 接入 tab_changed 按需刷新

**根因**：`_refresh_sub_panels` L303-314 点卡时无条件同步刷 3 个子面板；但 3 个子面板是 TabContainer 的 Tab 1/2/3，用户点卡后停在情报 Tab（L197 `current_tab = TabIdx.INFO`），强化/改造/进化 Tab 用户不切过去就看不到。

**改动**（card_info_panel.gd）：
1. 新增字段：
   ```gdscript
   var _sub_panel_dirty: Dictionary = {}  # {TabIdx: bool} 标记哪个子面板需要刷新
   var _tab_changed_connected: bool = false
   ```
2. `_resolve_nodes()` L123 解析 `_tab_container` 后，连接 tab_changed 信号（若未连接）：
   ```gdscript
   if _tab_container and not _tab_changed_connected:
       _tab_container.tab_changed.connect(_on_info_tab_changed)
       _tab_changed_connected = true
   ```
3. 新增 `_on_info_tab_changed(tab_index)`：
   ```gdscript
   func _on_info_tab_changed(tab_index: int) -> void:
       if current_card == null:
           return
       match tab_index:
           TabIdx.REINFORCE:
               _ensure_reinforce_instance()
               if _reinforce_instance and _reinforce_instance.has_method("set_selected_card"):
                   _reinforce_instance.set_selected_card(current_card)
               _sub_panel_dirty[TabIdx.REINFORCE] = false
           TabIdx.MODIFY:
               _ensure_modify_instance()
               if _modify_instance and _modify_instance.has_method("set_selected_card"):
                   _modify_instance.set_selected_card(current_card)
               _sub_panel_dirty[TabIdx.MODIFY] = false
           TabIdx.EVOLVE:
               _ensure_evolve_instance()
               if _evolve_instance and _evolve_instance.has_method("set_selected_card"):
                   _evolve_instance.set_selected_card(current_card)
               _sub_panel_dirty[TabIdx.EVOLVE] = false
   ```
4. `_refresh_sub_panels` L303-314 改为只标记 dirty，不立即刷：
   ```gdscript
   func _refresh_sub_panels(card: CardResource) -> void:
       if card.card_type != GC.CardType.COMBAT_UNIT:
           return
       # 不再同步刷 3 个子面板，改为标记 dirty，等用户切到对应 Tab 时才刷
       _sub_panel_dirty[TabIdx.REINFORCE] = true
       _sub_panel_dirty[TabIdx.MODIFY] = true
       _sub_panel_dirty[TabIdx.EVOLVE] = true
   ```
5. **首次实例化拆帧**（可选优化）：`_on_info_tab_changed` 切到某 Tab 时，若该子面板首次未实例化，用 `call_deferred` 挂载避免挤在切 Tab 同帧。但 evolution/modification 本身的刷新仍是重活，可进一步考虑分帧。**初版先做按需刷新，实例化拆帧作为 C2 观察**。

### C2. evolution_panel 嵌入模式短路（最重子面板）

**现状**：evolution_panel 的 `set_selected_card` L562-569 **没有 `_embedded_mode` 短路**（reinforcement L326-329 和 modification L954 都有），嵌入模式照样跑 `_update_evolution_tree`（每个进化目标造一套节点 + `can_evolve_blueprint`）。

**改动**（evolution_panel.gd）：评估是否在 `set_selected_card` 开头加 `if _embedded_mode:` 短路——但进化树本身是嵌入模式要显示的核心内容，不能完全跳过。

**决策**：**C2 暂不动 evolution_panel 逻辑**。C1 的按需刷新已经把"点卡时同步刷进化"延后到"用户切到进化 Tab 时才刷"，这是主要收益。evolution_panel 内部的 `_update_evolution_tree` 优化（如缓存进化树节点、避免重复 `can_evolve_blueprint`）留待后续，属于单独的性能任务。

---

## 实施顺序与验证

### 依赖关系
- A1 依赖 A2（main.gd 不加 store 分支，on_overlay_opened 不会被调）
- A3 独立（信号去重）
- B1/B2/B3/B4 相互独立
- C1 自包含

### 建议实施顺序（风险从低到高）
1. **B4**（删 _diag 空跑）—— 1 行，零风险，先验证改动流程
2. **A2 + A1**（商店分帧）—— 中等，需要游戏内验证开商店不卡
3. **A3**（信号去重）—— 中等，需要验证买卡后 UI 正确刷新
4. **B1**（相位仪签名）—— 低，签名模式已有 4 处参考
5. **B2 + B3**（对象池补全）—— 中等，需要验证切 tab 数据正确显示
6. **C1**（点卡按需刷新）—— 中高，需要验证切强化/改造/进化 Tab 时数据正确

### 验证方式
- 每阶段完成后 Godot headless `--check-only`（项目体量大可能超时，属既有现象，主要看有无语法错误）
- Grep 静态核对：签名 key 拼写、信号 connect/disconnect 配对、meta_key 一致性
- **关键功能验证（需游戏内实机）**：
  - 商店：开商店流畅、买卡后余额/购买按钮正确刷新、切公司 tab 正常
  - 背包：开背包流畅、切 5 个 tab 数据正确、装备/卸下相位仪后相位仪 tab 更新、买符文后符文 tab 更新
  - 点卡详情：点卡后情报 Tab 立即显示、切强化/改造/进化 Tab 数据正确（按需刷新不丢数据）、强化/改造/进化操作后 UI 正确更新

### 涉及文件清单（共 4 个 .gd 文件）
1. `scenes/ui/store_panel.gd` — A1（分帧）+ A3（信号去重）+ A4（延迟刷新分帧）
2. `scenes/main.mtd` — A2（store 分支）⚠️ 注意：是 main.gd 不是 main.tscn
3. `scenes/ui/backpack_panel.gd` — B1（相位仪签名）+ B2（对象池补全）+ B3（符文信息栏签名）+ B4（删 _diag 调用）
4. `scenes/ui/card_info_panel.gd` — C1（按需刷新）

### 不改的东西（向后兼容承诺）
- 不改数据源（InstanceRegistry 全集查询、SaveManager 队列兜底、BlueprintManager 补全都保持）
- 不改子面板内部刷新逻辑（reinforcement/modification/evolution 的 `_refresh_card_list` / `_refresh_mod_list` / `_update_evolution_tree` 原样保留）
- 不改 card_info_panel.tscn（TabContainer 结构不变，只加运行时信号连接）
- 不改 evolution_panel.gd（C2 留待后续）
- 不改 default_cards.gd / company_store.gd（S3 查表去冗余收益小，留待后续）
- 不升级 schema、不改存档格式

### 风险评估
- **最高风险点**：C1 按需刷新——如果 `_on_info_tab_changed` 信号连接时机或 `current_tab` 赋值顺序有误，可能导致切 Tab 时子面板不刷新（显示旧卡数据）。需要确保 `_refresh_sub_panels` 标记 dirty 和 `_on_info_tab_changed` 消费 dirty 的时序正确，且每次 `show_card_info` 都重新标记 dirty。
- **中风险点**：B2 对象池——meta_key 标记必须 acquire/release 两侧一致，否则节点会被误回收到错误的池或漏回收。需要 Grep 核对所有 `set_meta` / `has_meta` 配对。
- **低风险点**：A1/A3 商店分帧——backpack_presenter 已验证过同款模式，照搬风险低。