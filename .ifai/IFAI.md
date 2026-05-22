---
# IFAI Project Configuration
# You can edit these settings directly

# Default language for this project
default_language: zh-CN

# AI provider (optional, overrides global settings)
# ai_provider_id: zhipu
# ai_model: glm-4.6

# Custom instructions for AI responses
# These instructions will be included in the system prompt
custom_instructions: |
  请使用中文回答所有问题，除非用户明确要求使用其他语言。

---

# Project Notes
## 项目说明

这个目录包含项目的 IFAI 配置文件。你可以：

1. **编辑上方的 YAML 配置**：修改项目级别的设置
2. **添加项目说明**：在这里记录项目相关的笔记
3. **团队协作**：将此文件提交到版本控制，共享项目配置

### 配置项说明

- `default_language`: 项目默认语言 (zh-CN, en-US)
- `ai_provider_id`: AI 提供商 ID (可选)
- `ai_model`: AI 模型名称 (可选)
- `custom_instructions`: 自定义指令，会添加到系统提示中

### 示例

```yaml
default_language: en-US
custom_instructions: |
  Always respond in English.
  Use technical terminology appropriate for software engineers.
```
