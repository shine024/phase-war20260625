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
