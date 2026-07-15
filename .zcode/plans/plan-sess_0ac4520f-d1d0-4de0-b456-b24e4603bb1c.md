# 势力特殊单位卡解锁门槛：等级 → 声望

## 目标
把 14 张势力特殊单位卡（`fe_` 前缀）的解锁/可用判断，从"势力等级 >= N"改成"势力声望 >= N"。
- epic 卡：声望门槛 1200（= 原 Lv3 下界）
- legendary 卡：声望门槛 2900（= 原 Lv5 下界）

数值用"等级阈值下界映射"，行为与现状完全等价，仅判断/显示口径从等级切到声望。
范围：**只改 `fe_` 特殊卡**，不动普通势力商店（`faction_shop` 的 `required_level` 保留）。

## 背景：当前链路
- 数据字段 `min_faction_level`（值 3 或 5）+ 静态方法 `get_min_faction_level()`
- 声望阈值表 `LEVEL_THRESHOLDS = [0, 500, 1200, 2000, 2900, ...]`（faction_reputation.gd:19），Lv3 下界=1200、Lv5 下界=2900
- 3 个判断点 + 1 个发放入口，全部用 `get_faction_level()` 对比

## 改动（5 个文件）

### 1. `data/faction_exclusive_cards.gd` — 数据字段 + 静态方法
- 第 9 行注释：`min_faction_level: 最低势力等级要求` → `min_reputation: 最低势力声望要求`
- 14 张卡数据：`"min_faction_level": 3` → `"min_reputation": 1200`；`"min_faction_level": 5` → `"min_reputation": 2900`
- 第 345-350 行方法：`get_min_faction_level()` → `get_min_reputation()`（读 `min_reputation` 字段，默认 0）
- 注：`faction_war_events.gd` / `faction_event_manager.gd` 里的 `min_faction_level` 是**势力战争事件触发条件**，存自己的数据、不调本方法，不受影响

### 2. `scenes/ui/backpack_card_item.gd:395-413` — 背包灰显判断 + tooltip
- `EC.get_min_faction_level(c.card_id)` → `EC.get_min_reputation(c.card_id)`
- `fsm.get_faction_level(faction_id) >= min_lv` → `fsm.get_faction_reputation(faction_id) >= min_rep`
- tooltip 文案：`"需要激活 %s 势力且等级 >= %d"` → `"需要激活 %s 势力且声望 >= %d"`

### 3. `managers/blueprint_manager.gd:479-490` — 制造门槛
- `EC.get_min_faction_level(card_id)` → `EC.get_min_reputation(card_id)`
- `fsm.get_faction_level(faction_id) >= min_lv` → `fsm.get_faction_reputation(faction_id) >= min_rep`

### 4. `managers/faction_system_manager.gd` — 升级发放（发放入口）
- 第 258 行注释：`min_faction_level` → `min_reputation`
- 第 227 行调用：`_grant_exclusive_cards_on_level_up(faction_id, result["new_level"])` → `_grant_exclusive_cards_on_level_up(faction_id, result["new_rep"])`
- 第 260 行函数签名：`new_level: int` → `new_rep: int`
- 第 269 行：`cfg.get("min_faction_level", 99)` → `cfg.get("min_reputation", 99999)`
- 第 273 行：`new_level >= min_level` → `new_rep >= min_rep`（变量名 `min_level` → `min_rep`）
- **触发点保留在升级回调内**：因声望门槛 1200/2900 恰好等于 Lv3/Lv5 等级边界，跨过声望门槛的时刻必然是升级时刻，保留在升级块内行为完全等价

## 向后兼容
- `exclusive_cards_granted`（已发放卡 ID 列表）独立于门槛字段名，旧存档已发放的卡不丢失
- 无 schema 变更，无存档迁移
- 纯口径切换 + 数据值映射，零平衡性影响

## 验证
1. Godot headless `--check-only`（无语法错误）
2. Grep 核对：`get_min_faction_level`/`get_min_faction_level` 在特殊卡链路 0 残留；`min_reputation`/`get_min_reputation` 拼写全链路一致
3. 确认 `faction_war_events.gd` / `faction_event_manager.gd` 的 `min_faction_level`（事件系统，独立数据）未被误改