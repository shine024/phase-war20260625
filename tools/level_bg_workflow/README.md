# 关卡背景图生成工作流（带回家复用版）

> 一键调用 agnes-ai API 生成 16:9 横版关卡战场背景图。车道占下半画面主导（~55%），最底部允许稀疏小元素。

---

## 一、文件夹内容

| 文件 | 作用 |
|------|------|
| `generate_level_bg.py` | 主生成脚本（改顶部 `LEVEL_THEMES` 加关卡、改 `GEOMETRY` 调车道比例） |
| `api_keys.txt` | 3 个 API key，一行一个，脚本自动轮换 |
| `README.md` | 本说明 |

整个文件夹**自包含**，复制到任何带 Python3 + curl 的电脑即可跑（不依赖项目其它文件）。

---

## 二、快速开始

```bash
# 默认：第1关，4 张车道质感变体
python generate_level_bg.py

# 只出 1 张（快速试参数）
python generate_level_bg.py --single

# 换关卡（需先在 LEVEL_THEMES 里定义）
python generate_level_bg.py --level 21 --variants 4
```

**依赖**：Python 3.8+ 和 `curl`（系统自带）。

**产出**：`docs/关卡背景_生成/level<N>/level<N>_<质感>.png`（1792×1024 PNG）。
> 注：脚本里 `ROOT` 指向项目根，产出会落到项目的 `docs/` 下；单独拎走脚本时，把 `OUTPUT_ROOT` 改成你想要的目录即可。

---

## 三、当前几何（v6，已按反馈调对）

```
地平线压到画面顶部约 1/3 处
┌─────────────────────────┐
│   天空 + 远景   ~33%     │  ← 从 50% 压下来
├─────────────────────────┤
│   中景过渡      ~10%     │
├─────────────────────────┤  ← 地平线（画面 1/3 处）
│                         │
│   战斗车道(地面) ~55%    │  ← 从 40% 扩上去，占下半主导
│   主体开阔平坦           │
│   最底部允许稀疏小元素   │  ← 枯草/车辙/浅水洼/碎石
└─────────────────────────┘
```

要继续微调比例，改脚本顶部的 `GEOMETRY` 字符串里的数字描述（33% / 10% / 55%）。

---

## 四、踩坑总结（v1-v5 换来的，别重蹈）

| 坑 | 现象 | 解决 |
|----|------|------|
| **百分比数字模型不执行** | 写 `lane occupies 40%` 五张图构图几乎不变 | 改用直白几何词：`horizon at one-third from top` / `bottom 55% is the lane`。模型对「上1/3/下1/2」这种结构词比对「40%」敏感得多 |
| **负面词写进 prompt 文本里无效** | 文本里的 `Negative prompt: ...` 被当普通描述忽略 | 必须**独立 `negative_prompt` 字段**传（见 `call_api` 的 payload） |
| **车道堆满障碍** | 木桩/沙袋/铁丝网堵在车道里 | 删掉 `Props allowed on lane edges`（这句本就是许可放道具），改成 `lane body stays OPEN`；障碍物约束到「地平线过渡带」；负面词加 `barridges blocking the lane` 等 |
| **车道完全空又太死板** | v5 强制车道零元素，显得假 | v6 折中：车道**主体**开阔，但**最底部边缘**允许稀疏低矮小元素（枯草/车辙/浅水洼） |
| **520 / 审核拒绝** | Cloudflare 临时故障或偶发内容审核 | 3 key 轮换 + 间隔递增重试（见 `run_one`），通常换 key 即过 |
| **后台跑无输出** | `python x.py &` 日志空 | 用 `python -u x.py`（unbuffered）前台跑 |

---

## 五、添加新关卡

在 `LEVEL_THEMES` 字典照着第 1 关格式加：

```python
21: {
    "name": "第21关·二战不列颠空战",
    "era": "World War II",
    "faction_style": "Nova Arms style: olive drab + rust orange + steel gray, industrial war economy",
    "sky": "daylight stormy sky, dramatic cloud stacks, distant city skyline silhouettes, ...",
    "midground": "Battle of Britain mood: distant airfield strips, radar tower lattice, empty radar bunkers, ...",
    "narrative": 'Phase War Stage 21 "不列颠空战，欧洲战场开启" (no text)',
    "variants": [
        ("dry_dirt", "dry packed dirt ground, flat and clear"),
        ("wet_mud", "wet muddy ground, flat and clear, glossy puddles"),
        # ... 想要几种质感就加几条
    ],
},
```

> 完整的 1-100 关英文 prompt 可参考项目里的 `docs/level_background_ai_prompts_1-100(生图).md`，把对应关的 sky/midground 文案搬过来即可。

---

## 六、部署到游戏（回项目后）

生成的图要替换进游戏，等比缩放/裁剪到项目背景尺寸后放到：
```
assets/backgrounds/bg_level_01.png   （第1关）
```
游戏会自动识别（`Battlefield.gd` 和 `world_map.gd` 都按 `bg_level_%02d.png` 命名加载，无需改代码）。可参考项目里的 `tools/deploy_card_icons_11.py`（白底转透明+缩放）改写一个背景部署脚本。
