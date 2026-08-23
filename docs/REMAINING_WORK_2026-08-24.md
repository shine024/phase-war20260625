# 未完成清单（2026-08-24 盘点）

> 发行执行计划批次 1~9 已全部完成（见 CHANGELOG v20.4~v20.7 + RELEASE_EXECUTION_PLAN.md）。
> 本文件汇总**全部剩余工作**，供后续会话/人工继续。完成一项就勾选并在 CHANGELOG 记批次。
> 快照日期：2026-08-24；分支 feat/v6.14-system-integration（领先 origin **14 个 commit 未 push**）。

---

## 一、并行轨道（发行计划内，未启动）

### 轨道A · 相位师美术（P2-2）★用户已拍板：EA 走 C（接受复用），1.0 前升级

- [ ] **EA 收口（C 方案，S）**：现状核实 + 文档定稿——30 位 master 战场复用时代原型+势力染色，
      世界地图仅 tooltip 名字。零美术工作量，只需在 AGENTS/规格文档记入"1.0 前补专属立绘"
- [ ] **1.0 升级（届时二选一）**：
  - 方案 A：30 位全部补专属立绘+用满（含未上场 10 位接入遭遇池）。AI 图管线现成
    （`docs/相位战争_美术资源提示词总览.md` + `docs/美术资源生成工作流_v3.md`），
    新图落盘后重跑 `tools/generate_card_foot_anchors.py` + 缩略图树生成；PNG 不入 git，**先备份再动**
  - 方案 B：收缩阵容至驻守上场的 20 位（改 `data/phase_master_garrison.gd` 映射，删 10 位冗余）
- [ ] **boss 待机帧**：仅 cold_boss_mig / fut_boss_nexus 有帧组（2/5），其余 3 组程序化摇摆兜底——
      选 A/B 时顺带补齐（`docs/boss_spell_shots/` 有管线痕迹）
- 数据位置：`data/enemy_phase_masters_*.gd` 5 文件×6 位；驻守映射 `data/phase_master_garrison.gd`

### 轨道B · VFX 收尾（P2-5，自评 4.16/10 → 目标 6.0/10）

- [ ] **f01/f02 弹道飞行弹体**（曲射炮弹/空射，当前 traj ~4）：程序化弹体 14×9px 太小不可读。
      已勘察：`scenes/units/bullet.gd:280`（wt1/2 走程序化弹体，size_scale 1.15）、
      `scripts/weapon_projectile_vfx.gd`（build_bullet_points 单一真理源）
- [ ] **f05 霰弹 6 发 18° 散射签名**：命中缺散射图案。改 `scripts/battle/vfx_impact_factory.gd`
- [ ] **铁律流程**（`.agents/skills/vfx-tuning/SKILL.md`，改前必读）：
      ①先读 v12/v17 报告 ②PIL 量贴图实寸 ③改前校准测量 ④单轮单变量 + AI 三次取中位 ⑤感知优先
- [ ] **工具链**：截图 `"$GODOT" --path . res://scenes/tools/vfx_audit_matrix.tscn`（勿 --headless）→
      AI 评分 `python tools/review_vfx_audit_matrix.py`（key 在 tools/_api_key.txt，~15 分钟/48 格）→
      回归锁 `--script tests/weapon_visual_profiles_smoke.gd`
- [ ] 达标线 6.0/10 即收，不无限打磨

---

## 二、批次9 验收遗留（回灌路线图 P2-8~P2-12）

- [ ] **P1-2 人工验收 B 部分**（清单在 `docs/RELEASE_ACCEPTANCE_BATCH9.md` §B）：
      新档教程 13 步 / 1~40 关推进与时代切换 / 5 时代相位师关 / 长局手感（Tween/VFX/BGM/战场回收）/
      存档回环 + 损坏恢复 toast / 日常任务"获得符文"实跑
- [ ] **P2-8 PM 基地战出口**：弱势方可无限僵持——加撤退按钮或 N 分钟无伤害判负
- [ ] **P2-9 击杀掉真卡通道复活**：bp_* 蓝图掉落已清（批次9 F1）；复活为真卡直掉需经济评估
      （先例 ww2_panther/ww2_kingtiger/ww1_saint；批次7 审计基于无此通道现状）
- [ ] **P2-10 合金/晶体零消耗方**：合成删除后纯展示——接消耗或退役（批次7 决议 EA 现状）
- [ ] **P2-11 L43+ 难度曲线人工核验**：soak 观察到无强化账号秒败级首波，真实玩家体感待测
- [ ] **P2-12 Lambda capture 残留**：~1/25 场一次 index-1 报错（良性有守卫，无堆栈难定位）

---

## 三、发行工程（P0-1~3 计划外另排 + P3 商店线，全部未动）

- [ ] **P0-1 移除新档作弊发放**（S，出门阻断）：`save_manager.gd` `_enqueue_starter_backpack_cards()`
      5 资源各 100,000 + 全蓝图；正式量注释（nano 1500/alloy 800）就在旁边
- [ ] **P0-2 摘除标题屏开发按钮**（S）：title_screen.tscn L185-207 两个工具入口按钮
- [ ] **P0-3 从零建导出配置**（M，**无 export_presets.cfg**）：排除 docs/(280MB)/addons/tests/tools；
      config/name+version；Windows 图标 .ico
- [ ] **P3-1 版本号 + 分支整理**：feat/v6.14 领先 main 79+14 提交回并；对外版本收敛 0.x
- [ ] **P3-2 Steam Direct**（$100/APP、AI 内容披露必填、隐私页可极简）
- [ ] **P3-4 商店物料**（胶囊 6 尺寸/截图 ≥5/预告片 30s~1min/中文描述）
- [ ] **P3-5 音频来源凭证留档**（43 SFX + 7 BGM 的 AI 生成记录或采购许可）
- [ ] **P3-6 手柄/Steam Deck 核对**（当前仅键鼠，可标"仅键鼠"）
- [x] P3-7 CI 门禁转正 ✅ 批次8 已达成（145 例全绿，tests.yml 有效）
- [ ] **先决决策 D1/D2/D3 未正式拍板**：平台（推荐 PC Steam）/ 形态（EA 已倾向）/ 语言（仅中文可行）

---

## 四、随手项

- [ ] **push**：本地 14 个 commit 未推 origin（含批次8/9 全部成果）
- [ ] 批次6 的 bgm_battle_cold 是 WW2 变体过渡曲——正式曲走 P3-5 采购/生成线替换
- [ ] `docs/RELEASE_EXECUTION_PLAN.md` 可归档（9 批次全部完成，主线闭环）

---

**恢复工作建议顺序**：push → 轨道A EA 收口（半小时）→ P0-1/2/3（能打包）→ 人工验收 B 部分 → 轨道B VFX → P3 商店线。
