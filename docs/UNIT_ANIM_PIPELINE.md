# 单位分帧动画工作流（Unit Anim Pipeline）

> 2026-08-30 全量落地：110 敌方单位 × idle+attack = 220 动画已接入游戏（同日起敌我双方通用，我方 flip_h 镜像）。
> 本文是完整工作流真身：目录约定、命令、质量关、改帧回路、坑清单。
> **存储约定（2026-08-30 定）**：只保留 source.mp4（仅当前版，历史版删）+ f*.png 成片 + sheet/meta/bak 历史；`raw/` 中间抽帧与 `_probe/` 不落盘（build 会重新生成，audit 需要时从 mp4 重抽）。

## 一、目录与角色

| 路径 | 角色 | 铁律 |
|---|---|---|
| `资料/单位分帧动画/NNN_<key>_<中文名>/{idle,attack}/f*.png` | **源真身·逐帧** | **永不删除**。手改就改这些；`NNN_`=单位序号(1-110, 与 preview.html 编号一致) |
| 同上 `sheet_{idle,attack}.png` / `meta.json` / `source.mp4` | 派生产物 | 由脚本生成，可重建 |
| `assets/effects/unit_anims/<key>/sheet_{idle,attack}.png + anim.json` | **游戏加载层（v2 雪碧图版）** | 每单位 2 张 256² 拼条（~104MB/110 单位）；`anim.json` 记帧数/fps；运行时 AtlasTexture 切区域换帧 |
| `资料/单位分帧动画/preview.html` | 浏览器复审页 | `preview` 子命令重生成 |
| 项目外 `phase-war-anim-backup-YYYY-MM-DD.zip` | 快照备份 | PNG 不入 git，**大改动后必须重打** |
| `scripts/battle/unit_frame_anim.gd` | 运行时驱动 | 换贴图模式（见下） |

- `资料/.gdignore` 已放置：Godot 不导入源目录，**游戏引用一律走 assets 部署层**。
- 运行时 key 约定：敌方 archetype id 带 `foe_` 前缀，驱动自动剥前缀查目录。

## 二、全流程（新单位从零到上场）

```
①配置   tools/unit_animations_extra.json 加条目(key/name/art/category/air/anims)
        （38 个老单位直接在 generate_unit_animations.py 的 UNITS 里）
②参考图 卡图 PNG → 白底 512 jpg（_build_extra_cfg.py 产物在 _ref/）
③视频   python tools/generate_unit_animations.py create <unit> <anim>
        ⚠️ API 限流 6 请求/分钟：批量必须 ≥16s 间隔 + 限流退避（_batch_extra2.py 先例）
④轮询   ... poll <unit> <anim>   → 下载 mp4
⑤构建   ... build <unit> <anim>  → 抽帧 fps=8 + 白底转透明 + 统一bbox + f*.png + sheet + meta
⑥自检   python tools/anim_video_selfcheck.py "<单位目录全名>"
        阈值: keep 3~50% / bg% ≥55 / 朝向 4帧全左；FAIL→重摇一次→仍 FAIL 记 GATE-FAIL 放行待分诊
⑦部署   python tools/deploy_unit_anims.py
        + Godot --headless --import（机器A: D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe）
⑧复审   浏览器开 资料/单位分帧动画/preview.html + 游戏内实看
⑨备份   改动落定后重打 zip（_finish_extra.py 或 _backup_anim.py）
```

批量驱动参考：`_batch_extra.py`（一轮）→ `_batch_extra2.py`（补漏，16s 间距+65s×3 退避）→ `_fallback_missing.py`（卡图合成兜底）→ `_finish_extra.py`（完整性+check+preview+备份）。

## 三、改帧回路（手改 f*.png 后）

```powershell
# 1. 手改 资料/单位分帧动画/<单位>/idle/f03.png ...
# 2. 重打包雪碧图（⚠️ 不能用 build——它会从 mp4 重抽覆盖你的手改！）
python tools/repack_unit_sheet.py "<单位目录名>"          # idle+attack 都重打
python tools/repack_unit_sheet.py "<单位目录名>" idle      # 只打一个
# 3. 部署 + 导入
python tools/deploy_unit_anims.py
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --import
# 4. 游戏里刷新看效果；落定后重打备份 zip
```

## 四、运行时接入（v24）

- 模式 = **换贴图**（BossIdleAnim v14 先例）：驱动挂 `unit_spr` 下直接换 `texture`，
  军衔条/角标/枪口锚点/受击闪白/空中悬空全不断链。
- v2 雪碧图：帧 512²→256² 缩小拼横条（2200 PNG→220 sheet，240MB→104MB）；
  驱动建 AtlasTexture 区域切片换帧，attach 时自动做尺寸补偿（scale×512/256、
  offset.y×256/512）——视觉大小与脚线锚定和静态卡图一致（探针已验证补偿数学）。
  源 `f*.png` 仍是 512² 全分辨率真身，改帧回路不受影响。
- 接线：`scripts/card_grid_unit_visuals.gd`
  - 敌我双方普通单位出生 → `UnitFrameAnim.attach(unit_spr, anim_id, face_right)`（idle 8fps ping-pong 往返；敌=朝左原图，我方=同套 sheet 驱动内 flip_h 镜像，2026-08-30 起；开火经 fire_lunge_sprite→notify_fire 播 attack，construct_unit 与 enemy_unit 调用点现成）
  - 开火点 `fire_lunge_sprite` → `notify_fire()`（attack 播一遍回 idle）
- boss/相位师仍走 BossIdleAnim，互不干扰。
- 我方未接（素材朝左，我方需 flip，属后续轮）。
- motion_reduce（无障碍）自动回静态图。
- 探针：`tests/_tmp_unit_frame_anim_probe.gd`（编译+key解析+attach+开火切换）。

## 五、回退 / 卸载

- 单位级回退：删 `assets/effects/unit_anims/<key>/` → 该单位回静态卡图。
- 全量回退：删 `assets/effects/unit_anims/` 下所有非 boss 目录。
- 静态卡图 PNG 全程未被触碰，永远可回。

## 六、坑清单（已踩过，勿重蹈）

0. **fix3 新增（2026-08-30 复审修复轮）**：
   - **白/银机身被"近白修剪"吃掉**：v6d-2 会把与边框经近白路径连通的主体像素剃掉——
     edge_mode 救回的白色部件又被它吃。修法=单位加 `"nw_trim": false`（配合 `matte_edge: true`）。
     已启用：mlrs/abrams/technical×2/m6/drone/再生骨架/雷达站/pak40/ssc1/m81(ww2)/fut_mech/mig。
   - **模板 prompt 与单位类型不符**：growler(EA-18G 飞机)被塞了步兵模板 → keep%=4 惨案。
     改 prompt 前先看 `_ref/<unit>_white.jpg` 参考图确认到底是什么。
   - **"不要有人"类需求**：prompt 要显式写"画面中绝对没有任何士兵或人物，只有武器本身"。
   - **改 json prompt 后必须刷新内存 UNITS**（`gua.UNITS.update(extra)`），否则 create 仍用旧 prompt。
   - **非战斗单位 attack**：用户不要开火动作 → attack=idle 帧复制（bak_fix3/ 留原件），
     脚本 `tools/_fix3_copy_idle_attack.py`。
   - **用 attack 图生成 idle**（保持设计一致）：attack f00 → 白底 512 jpg → 存
     `_ref/<unit>_fromattack_white.jpg` → 临时换 `UNITS[u]['ref']` 再 step_create。
1. **`build` 覆盖手改帧**：build 从 source.mp4 重抽 f*.png。手改单位只能用 `repack_unit_sheet.py`。
2. **显示名含 `/`**：单位名 `Sd.Kfz.251/1` 会把动画目录劈成嵌套两层——新单位命名禁用 `/`（已改名 `Sd.Kfz.251-1`）。
3. **mp4 级翻转修复**：朝向错误修源头——`ffmpeg -vf hflip` 翻 mp4 再 build（metis 先例，原视频存 `source_preflip.mp4`）；翻产物帧会被下次 build 冲掉。
4. **GATE-FAIL 误判三类**（放行前先 ASCII 分诊 `tools/_*_view.py` 模式）：
   - 大型堡垒 bg%<55（碉堡/离子炮台占帧 40%+）
   - 对称造型朝向启发式失效（无人机/护盾穹顶 0/4 但轮廓稳定）
   - 发射闪光瞬间不对称（ssc1 f06 左侧闪光=正确攻击方向）
5. **API 限流**：批量创建 11s 间距必炸（8 单位跳过），用 ≥16s + 退避。
6. **pass-2 类驱动的日志自锁**：脚本内部开 log 时，pwsh 包装不要 Out-File 同一文件。
7. **冷备份铁律**：未来任何全量重建前，`cold_ak` 要加回跳过表（其 attack 是 fallback 产物，_rebuild 会覆盖）。
8. **Godot `--script` 探针的 autoload 噪音**：`card_background_ui.gd` 引用 BlueprintManager 会在 headless 探针报"Failed to compile depended scripts"——预存噪音，非断链；以探针最终 PASS 行为准。

## 七、相关文件索引

| 文件 | 用途 |
|---|---|
| `tools/generate_unit_animations.py` | 核心：upload/create/poll/build/preview/check/batch（UNITS=110） |
| `tools/unit_animations_extra.json` | 72 个新单位条目（name/art/category/air/anims+prompt） |
| `tools/_build_extra_cfg.py` | extra json + 白底参考图生成器 |
| `tools/anim_video_selfcheck.py` | 质量关卡（keep/bg%/朝向） |
| `tools/anim_fallback_from_card.py` | 卡图合成兜底 |
| `tools/deploy_unit_anims.py` | 源 → assets 部署（v2：512²帧缩 256² 拼单张 sheet + anim.json，清 v1 逐帧） |
| `tools/repack_unit_sheet.py` | 手改帧后 sheet 重打包 |
| `tools/_batch_extra{,2}.py` / `_fallback_missing.py` / `_finish_extra.py` | 批量四件套（参考实现） |
| `tools/_agnes_image_api.md` | Agnes 生图 API（备用素材源） |
| `tools/_api_key.txt` | Agnes 视频 API key |
