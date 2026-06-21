# 离线挂机 - 功能设计文档

> 版本: 1.0
> 创建日期: 2026-06-21
> 状态: 已实现

---

## 一、功能概述

游戏关闭期间，按时间戳计算离线挂机奖励（封顶 8 小时）。玩家重新打开游戏时，若离线时长超过阈值（5 分钟），弹出"欢迎回来"窗显示离线时长、折合战斗次数与奖励明细，玩家点领取后奖励入账。

**核心特性：**
- 纯数值计算（不实际模拟战斗），读档即时结算
- 奖励关卡来源：在线挂机配置（CYCLE→第一个有效 slot / PUSH→push_level），未配过回退最高解锁关
- 奖励种类：基础货币（确定性）+ 掉落模拟（随机）
- 战斗频率：按关卡波次配置估算单场时长，反推每小时场次

---

## 二、核心机制

```
游戏关闭 → save_game() 记录 last_active_at = Time.get_unix_time_from_system()
                                                    │
游戏重开 → load_game() → 计算 elapsed = now - last_active_at
                          │
                   elapsed > 阈值(5分钟)?
                     ├─ 否 → 不弹窗
                     └─ 是 → capped = min(elapsed, 8小时)
                             │
                    battles = capped × battles_per_hour / 3600
                             │
                    聚合货币(get_drops_for_level × battles)
                    + 掉落预估(generate_battle_drops 抽样)
                             │
                    弹"欢迎回来"窗 → 领取 → 入账
```

### 2.1 battles_per_hour 估算公式

```
battle_duration_sec = waves × wave_interval + 固定开销(20秒)
battles_per_hour = 3600 / battle_duration_sec
```

| 时代 | 波次(范围) | 间隔(秒) | 单场时长 | 场次/小时 |
|------|-----------|---------|---------|----------|
| 一战 | 3-5 | 14 | ~76s | ~47 |
| 二战 | 4-7 | 13 | ~91s | ~40 |
| 冷战 | 5-8 | 12 | ~104s | ~35 |
| 现代 | 6-9 | 12 | ~116s | ~31 |
| 近未来 | 7-10 | 11 | ~119s | ~30 |

8 小时封顶约 240-376 场。下限保护 `MIN_BATTLES_PER_HOUR=10`，避免极短战斗导致奖励爆炸。

---

## 三、关键文件

| 文件 | 说明 |
|------|------|
| `scripts/systems/offline_idle_manager.gd` | 核心计算 + 入账（OfflineIdleManager） |
| `managers/save_manager.gd` | `last_active_at` 时间戳写入/读取/查询 |
| `scenes/main.gd` | 持有 manager + 触发欢迎回来弹窗 |
| `scenes/ui/offline_reward_dialog.gd` | 欢迎回来弹窗（静态 create 构建） |

---

## 四、关键常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `MAX_OFFLINE_SECONDS` | 28800 (8h) | 离线时长封顶 |
| `MIN_OFFLINE_THRESHOLD` | 300 (5min) | 离线不足不弹窗 |
| `BATTLE_OVERHEAD_SEC` | 20.0 | 单场部署/结算固定开销 |
| `DROP_SIM_MAX_BATTLES` | 50 | 掉落模拟上限（超过不放大，保守） |
| `MIN_BATTLES_PER_HOUR` | 10.0 | 场次/小时下限保护 |

---

## 五、奖励关卡来源回退链

```
1. 在线挂机 CYCLE 模式 → 第一个非0 slot 关卡
2. 在线挂机 PUSH 模式 → push_level
3. 都无效/未配过挂机 → LevelProgressManager.get_max_unlocked_level()
```

---

## 六、货币 vs 掉落入账

- **货币**：`get_drops_for_level(level) × battles`，纯静态无副作用，**确定性**——弹窗显示值 = 入账值（精确）
- **掉落**：弹窗显示"约 N 件战利品"（抽样预估），领取时**实际重新生成** `min(battles, 50)` 场的 `generate_battle_drops` 并 `claim_drops`。掉落本就有随机性，显示预估、入账实际符合游戏惯例

---

## 七、向后兼容

- `last_active_at` 是 save JSON 顶层增量键，旧档无此键 → `_last_active_at=0` → `compute_offline_rewards` 见 `last_active_at<=0` 返回空（不弹窗），下次 save 自动补时间戳
- 无需 schema 迁移（与 v6.6 加 SK_AFK 等增量键一致）

---

## 八、已知风险

| 风险 | 处理 |
|------|------|
| 玩家改系统时间作弊 | 仅按 epoch 差计算，改时间可刷——单机游戏接受 |
| 离线奖励过大 | 8 小时封顶 + 场次受波次约束，可调常量 |
| 模拟掉落性能 | `DROP_SIM_MAX_BATTLES=50` 上限，不做放大 |
| `pending_drops` 污染 | 计算时快照/清空/恢复 pending；货币不入 pending |
