# TODO BACKLOG — 未来待办事项

> 2026-09-02 由 v26.6 四批品质冲刺收尾时入档。出处：`docs/CHANGELOG.md` G 节（批B 结构收敛定性报告）。
> 基线验证：GdUnit 218/218 + boot smoke 300 帧零错误（commit `fdd9696`）。
> 每完成一项：勾选 + 在 CHANGELOG 追加条目 + 跑双验证。

---

## 一、高价值（玩法影响大，优先）

### 1. 词缀洗练 / 锁定 / Boss 解锁面板 ✅（v26.11）
- [x] 已完成：词条工坊面板（affix_forge_panel，基地·维修工坊入口）+ Boss 池击败相位师渐进解锁（原：计费实现全齐（纳米 500~10000 档），缺 UI 面板——最大数值 sink 完全闲置）
- [ ] 工作量：中（新面板，仿 modification_panel 范式：左列表 + 右详情）
- [ ] 涉及：词缀洗练计费逻辑 / 锁定词条 / Boss 解锁入口

### 2. faction 商店目录过滤 + 库存上下架 ✅（v26.11）
- [x] 已完成：补给/声望特购区 + 售罄态（原：store_panel 只渲染 RUNE 类商品，势力装备/卡牌商品全部不可见）；注：add/remove_item_to_store 仍为预留（上下架完整接线需玩法设计决策）
- [ ] 工作量：小
- [ ] 附带：势力库存上下架断链同补

### 3. faction_event BONUS 池消费端 ✅（v26.11）
- [x] 已完成：结算全字段发放 + BONUS 激活 + 势力面板决策区（原：势力事件奖励池数据在、无消费端（事件结算不发 BONUS 奖励））；遗留：加成的战斗侧数值效果未接（需决策）
- [ ] 工作量：小

### 4. 教程重置入口 ✅（v26.11）
- [x] 已完成：设置面板按钮 + 确认框（原：重置函数活、设置页无按钮）
- [ ] 工作量：极小（设置面板加一按钮 + 确认框）

---

## 二、中价值

### 5. 成就服务面板 ✅（2026-09-11 用户裁决 E1）
- [x] 已完成：成就面板 SummaryPanel 与列表之间加服务区块——「最近解锁」5 条金名 chip（tooltip=描述）+「即将完成」3 条（≥50% 进度带百分比）；数据走既有 get_recent_achievements/get_recommended_achievements，随 refresh() 重建（remove+free 防同帧共存）

### 6. stat_boost 背包页签 ✅（v26.11）
- [x] 已完成：背包第 5 页签"全局强化"（只读：名称/描述/层数/当前加成）（原：v9.0 砍掉页签，战斗掉落 stat_boost 玩家拿到无处查看）
- [ ] 工作量：小（背包加页签，复用既有渲染）

### 7. intel get_stat_visibility 消费端 ✅（2026-09-11 用户裁决 F1）
- [x] 已完成：敌详情数值行三档呈现——full_stats=精确；behavior_summary/equipment_type/name_and_type=区间模糊（±30% 取整到 5，攻速 1 位小数）；空/hidden_stats=???。fail-open：情报管理器缺席/无法判型按精确显示。收口在 card_info_panel._format_enemy_combat_summary，等级词表对齐 data/intel_reveal_events.gd

### 8. Boss 套路展示 ✅（2026-09-11 用户裁决 G1）
- [x] 已完成：出征过场（SortieInterstitial）战报对相位师驻守关追加两行——「⚠ 相位师驻守：名号「称号」— 威胁度」+「情报：驻防平台…」（平台走 EnemyPhaseEquipment 真名）。取不到数据静默降级普通战报；AFK/教程链不带 meta 不触发

---

## 三、低风险观察项（顺手修，建议一锅端）

- [x] `faction_event_manager.save_state` 不存 `active_event`——读档丢未决事件（小 bug）✅（v26.11 已修，旧档无 key 零破坏）
- [x] `enemy_unit._effective_fire_range` 相位场射程 ×1.5 零引用 ✅（v26.11 已删，git 可找回）
- [x] `phase_instrument_loadout_sync.gd` 整文件零消费 ✅（v26.11 已删——实为实例化后零方法调用的拆分残留）
- [x] `achievement_rewards` company_rep 修复 ✅（v26.11 回归锁：tests/unit/managers/test_achievement_company_rep.gd，真实 autoload +7 声望断言）

---

## 四、需先决策再做

### 9. blueprint 自定义武器槽 ✅ 销项（2026-09-11 用户裁决 C1）
- [x] 玩法不做。数据层 `blueprint_manager.gd blueprint_weapon_slots` 保留作存档兼容——纯存档基建（保存链/save_migration_v8/存档不变量测试在位），零 UI/玩法消费方，删除需动存档 schema 得零收益。若未来做武器自定义再启用

### 10. 相位仪战斗掉落链 ✅ 已复活落地（2026-09-11 用户初裁 D1 停用，当日改裁"要掉"）
- [x] 普通战斗胜利 8% 掉 1 台未解锁**势力专属仪**（"战场缴获"通道）：star ≤5 进池、权重 32/16/8/4/2 低星常见高星珍稀；6-7★招牌（含主动大招）不进池保持商店稀缺。相位师战跳过（自身另有特殊仪掉落）。通用系列开局全解锁不占池；全解锁后链自然熄火（AFK 自限）。实现在 game_manager._maybe_roll_regular_instrument_drop

---

## 五、并行会话注意

- v26.7（battle_ended 广播竞态六连错修复）由另一会话进行中，涉及 `main.gd` / `bottom_instrument_bar.gd` / `main_reward.gd`。开工前先看其是否已提交，避免撞车。

---

## 完成约定

1. 每项做完：本文件勾选 + `docs/CHANGELOG.md` 追加版本条目
2. 验证门禁：GdUnit 全绿 + boot smoke 零 ERROR（命令见 AGENTS.md）
3. 删除类改动：先 grep 全项目确认零调用方，参照批A/B 流程入档
