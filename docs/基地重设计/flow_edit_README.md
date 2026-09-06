# Flow 图片编辑工作流（网页 UI 自动化）

用 Google Flow（flow.google.com）做**图生图编辑**的命令行工具。绕开已失效的
flow-mcp API 路线，直接驱动真实网页 UI：上传参考图 → 输提示词 → 生成 →
从网络层截获结果图原始字节落盘。**可跨机器使用**（Windows/macOS/Linux）。

- 工具：`flow_edit_tool.py`（本目录）
- 依赖：仅 `playwright`（不依赖 flow-mcp / gflow-cli）

## 新机器首次部署（一次性）

```powershell
# 1) Python 3.10+ 已装的前提下：
pip install playwright

# 2) 装 Google Chrome（工具优先用系统 Chrome，没有则回退 playwright 内置浏览器）
#    没装过内置浏览器的话补一句：
python -m playwright install chromium

# 3) 首次登录（会弹出浏览器，登录你的 Google 账号，看到项目列表后回控制台按 Enter）
python flow_edit_tool.py --login
```

登录态保存在本机 `%LOCALAPPDATA%\ffroliva\gflow-cli\profile_default`（与
gflow-cli / flow-mcp 共用；换账号就删掉该目录重新 `--login`）。

> 代理要求：flow.google.com 必须可达。走系统代理即可；如果生图全部
> 「智能体运行失败」，九成是代理问题，先在浏览器里确认 flow 能正常生成。

## 日常使用

```powershell
# 图生图编辑（提示词放 UTF-8 文本文件最稳，避免控制台编码问题）
python flow_edit_tool.py --ref .\generated_truck_sprite\truck_tier5.jpeg `
    --prompt-file prompt.txt --prefix truck_landed

# 直接传提示词
python flow_edit_tool.py --ref a.jpg --prompt "改成剖面图" --prefix cutaway

# 可选参数
#   --project <uuid>   指定 Flow 项目（默认自动发现账号里第一个项目）
#   --count N          最多保存几张结果（默认 2；模型通常一次出 1 张）
#   --outdir <dir>     输出目录（默认参考图所在目录）
```

输出：`<前缀>_<时间戳>_<媒体uuid8>.jpg`（模型原生分辨率，当前 1376×768），
日志：输出目录下 `flow_edit.log`。生成结果同时会出现在 Flow 网页项目里。

## 已知行为/排障

| 现象 | 处理 |
| --- | --- |
| 项目页跳到 `/about` 营销页、自动发现不到项目 | Google 会话过期（今天实测出现过）：重跑 `python flow_edit_tool.py --login` |
| 提示「Cookies 被独占锁定」 | 结束占用 gflow profile 的 chrome 进程（任务管理器搜 chrome），重跑 |
| 提交后报「智能体运行失败」 | 基本是代理/网络问题；换节点后重跑 |
| 每次运行开头慢 20~40 秒 | 正常：复制 profile 副本 + 打开项目页（都用 domcontentloaded + 重试） |
| 想要 2752×1536 高清版 | 在 Flow 网页里对结果图点「超高分辨率 2K」；或让 agent 帮你自动化 |
| 尺寸和参考图一样的结果被跳过 | 这是上传素材的回显，不是生成结果，工具自动排除 |

## 为什么不用 flow-mcp（flow-image-server）？

2026-09-05 起 Google 把 Flow 从 `labs.google/fx/tools/flow` 迁到
`flow.google.com`，旧入口 302 到无 reCAPTCHA 的营销页，flow-mcp 的
bearer/reCAPTCHA 直调链路整体失效（另有 0.3.0 版 `resolution="1k"`
默认值直接 KeyError 的 bug）。上游适配前，MCP 工具不可用，以本工具为准。

## 自动化流水线内部步骤（维护参考）

1. `copy_profile`：把 gflow profile 复制到临时目录（跳过锁文件/缓存；Cookies
   被独占时报错提示）→ 避开其他 Chrome 实例的锁冲突
2. 无头 Chrome 打开 `flow.google.com` → 首页抓第一个 `/project/<uuid>` 链接
3. 点「在提示框中添加素材」→「上传媒体内容」→ 文件选择器传参考图
4. ProseMirror 输入提示词 → 点「开始生成」
5. 监听网络：`flow-content.google/image/<uuid>` 响应体 >30KB 即结果字节，
   与提交前基线对比排除素材回显（尺寸等于参考图的也会跳过）
6. 结果落盘；DOM 新图 / batchexecute 里的 fifeUrl 作为降级信号
