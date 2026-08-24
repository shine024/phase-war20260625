# 相位师美术方案定稿（轨道A / P2-2）

> 2026-08-24 定稿。决策：**EA 走 C 方案（接受现状复用，零美术工作量），1.0 前升级专属立绘。**
> 本文档是 EA 现状的代码级核实记录（文件:行号可复查）+ 1.0 升级路径，后续会话/美术工作以本文档为准。

---

## 一、EA 现状（2026-08-24 代码核实）

### 1. 战场呈现：共享底座图 + 势力染色（真实生效）

相位师（phase master，30 位）在战场上**不是卡牌单位**，而是"相位场底座"（EnemyPhaseFieldDriver）：

- 30 位共用同一张底座贴图 `assets/phase_field/enemy_phase_field.png`（tscn 静态引用，不存在缺图面）
- **势力四色染色真实生效**：`scenes/units/enemy_phase_field_driver.gd:544-575` `_apply_body_visual_from_master`
  读 `enemy_faction` 写入 `spr.modulate`（steel/flame/thunder/void 四色 tint）；该基色同时被疲劳暗化（1189-1198）、
  buff/大招闪光（517-542）复用为底色——染色链路是活的
- 底座尺寸按时代参考原型的 visual_scale 取值：`_pick_visual_archetype_for_era`（1474-1483，`_ERA_VISUAL_ARCHETYPES` 154-160）
- `data/card_foot_anchors.gd` 的 VISUAL_SCALE 表**不覆盖 master**（无 enemy_master 键）——master 不进卡格

### 2. "复用时代原型卡图"的精确含义

复用发生在 **master 的产兵**上，不是 master 本体：

- 产兵走 `visual_archetype_id` 直引时代原型（`enemy_phase_field_driver.gd:1001-1003` → `construct_unit.gd:375`
  `setup_with_enemy_visual` → `scripts/card_grid_unit_visuals.gd:66-78` 取 vis_enemy 卡图）
- 产兵单位**无势力染色**（construct_unit 的 modulate 仅受击闪白/隐身/克隆），势力只体现在名称前缀 meta（driver 1030-1033）
- master 数据文件（`data/enemy_phase_masters_*.gd` 5 文件）**无任何 visual/icon/portrait 字段**——本就没有专属立绘的挂载点

### 3. 世界地图：仅 tooltip 名字，无立绘

- `scenes/world_map.gd:369-376` 组装"名字 Lv.X"字符串；420-425 写 `btn.tooltip_text`（"⚔ 相位师首领：%s"）；
  447-452 仅给关卡按钮金色字体+描边；613-615 详情面板加"驻守相位师"文字行。**全程无贴图/图标节点**

### 4. 阵容：上场 20 位 / 未上场 10 位

- 驻守映射 `data/phase_master_garrison.gd:16-46` 恰好 20 条（L10~L100 每 5 关一档，驻守关 100% 固定遭遇）
- 驻守 20 位：005-009, 011-016, 018-020, 022, 024-026, 028, 030
- 未驻守 10 位（001-004, 010, 017, 021, 023, 027, 029）：**并非绝对不上场**——非驻守关 15% 随机遭遇抽 9 位 NPC
  相位师（`data/npc_phase_masters.gd:10-19`），由 `managers/game_manager.gd:241-347` `_enrich_master_config` 从全 30 位池
  按势力+最接近等级**借 equipment/stats/id**（匿名装备供体，名字保留 NPC 名）

### 5. boss 待机帧：2/5 有帧组，其余程序化摇摆

- 仅 `cold_boss_mig` / `fut_boss_nexus` 有完整 6 帧组（`assets/effects/unit_anims/<id>/idle_f0..f5.png`）
- 帧接入是文件系统自动探测（`scripts/battle/boss_idle_anim.gd:20,38-47`，<2 帧静默回退）；
  其余 3 组 boss（ww1_boss_av7 / ww2_boss_kingtiger / mod_boss_command）+ **全部 30 位 master** 走程序化正弦摇摆
  （`scripts/card_grid_unit_visuals.gd:120-134` 判 boss 档 → 151-159 `_boss_sway_idle`，rotation ±0.011 rad）
- `docs/BOSS_IDLE_ANIM_SPEC.md` 规划的第一批 10 个 `enemy_master_XXX` 帧目录**全部未交付**（assets 下无任何 enemy_master 目录）

### 6. 报错面结论

master 专属美术本就不存在、无加载路径指向 → **零缺图报错面**；现存 push_warning 均与 master 立绘无关。
C 方案是对现状的准确描述，零美术工作量、零风险。

---

## 二、1.0 升级路径（届时二选一，EA 不做）

### 方案 A：30 位全部补专属立绘 + 用满（含未上场 10 位接入遭遇池）

- AI 图管线现成：`docs/相位战争_美术资源提示词总览.md` + `docs/美术资源生成工作流_v3.md`
- 新图落盘后必须：重跑 `tools/generate_card_foot_anchors.py`（脚部/头部锚点）+ 缩略图树生成
- ⚠️ PNG 不入 git（.gitignore 全局忽略 `*.png`），**先按 AGENTS.md 备份铁律打包再动**
- 需给 master 数据结构加 visual 字段 + 底座/产兵加载路径改造（当前无挂载点，见上文 §2）

### 方案 B：收缩阵容至驻守上场的 20 位

- 改 `data/phase_master_garrison.gd` 映射，删 10 位冗余（需同步处理随机遭遇装备供体池从 30 → 20 位收缩）
- 工作量小，但损失 IP 角色资产

### 顺带项（选 A/B 时一并处理）

- 补齐 3 组 boss 待机帧（ww1_boss_av7 / ww2_boss_kingtiger / mod_boss_command，管线痕迹在 `docs/boss_spell_shots/`）
- 若做方案 A，评估 master 底座是否也换专属形象（当前 30 位共用一张底座图，仅染色区分）
