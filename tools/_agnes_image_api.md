# Agnes 免费生图 API（2026-08-30 用户提供）

- 模型: `agnes-image-2.1-flash`（文生图 + 图生图转换/重绘/风格化）
- 端点: `POST https://apihub.agnes-ai.com/v1/images/generations`（备用 `https://apihub.agnes-ai.cn/v1`）
- 头: `Authorization: Bearer KEY` + `Content-Type: application/json`
- 返回: 图像 URL 或 Base64
- 文档: https://www.agnes-ai.com/zh-Hans/docs/agnes-image-21-flash

## Keys（与视频 key 同策略：本地留存，不入 zip/git）
1. sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv
2. sk-2mxCpSC8Nf0nm2TAf9fYHuRxNj7aeoIttPuuu9ivodbU3zXN
3. sk-Pzu3QigNdQlVhFC7cVDVsTDwfvt3T6nIDq23HeJgaKMnRo6K

## 用途备注
- 视频管线（agnes-video-2.5-flash）key 见 tools/_api_key.txt，两套独立。
- 潜在用途：补卡图/风格化重绘/动画帧修复素材源。

## 模型行为实测特点（v26.2→v26.8 基地房间批量生图三轮实测，2026-09-02 沉淀）

1. **负面词基本无效且反激活**：`Avoid: trash, debris, garbage, rubble, litter...` 全列表
   压不住垃圾满地——flash 档模型对负面列表敏感度差，写概念词反而把概念激活进画面
   （"不要大象"效应）。负面词只留结构性排除（text / perspective view / ceiling / frame）。
2. **正面意象锁死是唯一可靠手段**：要干净地面不是写 "no trash"，而是
   "the floor is one smooth continuous surface of polished metal planks, completely
   empty and spotless" ——给模型一个明确的"该画什么"，比"不该画什么"有效一个量级。
3. **风格词自带场景暗示**：gritty / somber / dusty（粗粝/阴郁/尘土）会把破败与垃圾带进
   画面；连色板词 "dusty olive" 的 dusty 都有暗示。战争题材内景尤其强，升级/现代语义
   生成时应换 "stylized / muted palette of dark grey-brown and olive green"。
4. **屏幕与挂画内容必须显式限定**："screens showing ONLY simple abstract glowing
   patterns, plain color readouts and flat graphic symbols (never detailed pictures or
   scenes)" ——不限定时模型在屏幕里画乱七八糟的具象画。
5. **管线适配**：白底转透明（flood_white_to_alpha）+ aspect-fill 裁切适配良好；
   size 1152x768 可用（≈3:2）；单张 30~60s，15 张批量约 6 分钟；3 key 轮换未见限流；
   curl --http1.1 调用稳定（参照 generate_impact_textures_ai.py 模式）。
6. **参考实现**：`tools/generate_bunker_caps_upg.py`（prompt 三轮演进 v1→v3 全程在
   git 历史 + 本文件对照阅读）；室内景 prompt 骨架来自 `docs/基地重设计/生图需求清单.md`。
