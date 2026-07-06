# 立绘资产规格（v7.x 剧情对话面板）

剧情对话面板（`scenes/ui/story_dialogue_panel.tscn`）使用 Galgame 范式双立绘布局：
我方（陈末）恒在屏幕左侧、NPC/Boss 恒在右侧，底部居中对话框。

## 立绘尺寸规范（产出标准）

| 项目 | 规格 |
|------|------|
| **画布尺寸** | **540 × 720 px**（宽 × 高） |
| **格式** | PNG，透明背景 |
| **朝向** | 竖向全身立绘（脚位贴近底边 y=720，头顶不超过 y=0） |
| **主体居中** | 角色重心大致在画布水平中线（x=270），左右各留白 ≥ 30px |
| **画风统一** | 霓虹深色主题，描边清晰（参考 Phase War 整体配色） |

## 渲染适配（旧图可继续用）

- TextureRect 用 `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`：
  - 忽略源图像素尺寸，按容器 540×720 居中显示
  - 保持源图比例，不会变形
- 任意尺寸的旧立绘都能继续渲染，但**新产出的立绘请按 540×720 规格**，避免比例不一致导致左右立绘大小错位

## 命名规范

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| 我方/NPC 角色 | `<英文名小写>.png` | `player.png` / `linwei.png` / `locke.png` |
| Boss | `boss_<英文名小写>.png` | `boss_baron.png` / `boss_mirror.png` |

文件路径：`res://ui/portraits/<文件名>.png`

## 已注册的 speaker（参见 `data/speaker_registry.gd`）

| speaker 中文名 | 阵营 | 方位 | 立绘文件 |
|---------------|------|------|---------|
| 陈末 / 指挥官（别名） | player（我方） | 左 | player.png |
| 林薇 | npc | 右 | linwei.png |
| 扎克 | npc | 右 | zack.png |
| 洛克 | npc | 右 | locke.png |
| 海伦 | npc | 右 | helen.png |
| 真实者 | npc | 右 | realist.png |
| 铁血男爵 | enemy | 右 | boss_baron.png |
| 钢铁元帅 | enemy | 右 | boss_marshall.png |
| 相位之主 | enemy | 右 | boss_phase_lord.png |
| 虚空领主 | enemy | 右 | boss_void_lord.png |
| 镜像 / 镜像守护者（别名） | enemy | 右 | boss_mirror.png |
| 守护者 | neutral | 中（两侧暗化） | boss_guardian.png |
| 旁白 | neutral | 中（无立绘，首字徽章） | — |

## 新增 NPC 立绘的步骤

1. 把按规格产出的 PNG 放到 `ui/portraits/<英文名>.png`
2. 在 `data/speaker_registry.gd` 的 `SPEAKER_REGISTRY` 字典里加一条：
   ```gdscript
   "新NPC名": {
       "display_name": "新NPC名",
       "faction": "npc",  # 或 player/enemy/neutral
       "portrait_path": "res://ui/portraits/<英文名>.png",
       "color": Color(0.5, 0.7, 0.9),  # 自选配色
   },
   ```
3. 对话数据（`data/quest_definitions.gd`）只需写 `{"speaker": "新NPC名", "text": "..."}`，面板自动渲染

## 缺省/未注册 speaker 的行为

- 立绘路径空或文件不存在：对应侧立绘隐藏，96 圆形徽章显示 speaker 首字（如"林"）
- speaker 未在注册表：默认归为 neutral（中），颜色用红色 fallback，徽章显示首字
