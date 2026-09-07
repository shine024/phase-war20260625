# -*- coding: utf-8 -*-
"""_tmp_flow_gen.py —— 直连 flow-mcp（stdio MCP 客户端）单张生图
用法: python tools/_tmp_flow_gen.py "<prompt>" "<raw输出目录>"
生成时会弹出有头 Chrome（flow 认证浏览器自动化），约 2 分钟/张。
"""
import asyncio, os, sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


async def main() -> None:
    prompt = sys.argv[1]
    out_dir = os.path.abspath(sys.argv[2])
    os.makedirs(out_dir, exist_ok=True)
    env = {**os.environ, "GFLOW_OUTPUT_DIR": out_dir}
    params = StdioServerParameters(command=sys.executable, args=["-m", "flow_mcp"], env=env)
    async with stdio_client(params) as (r, w):
        async with ClientSession(r, w) as s:
            await s.initialize()
            res = await s.call_tool("generate_image", {
                "prompt": prompt,
                "model": "nano-pro",
                "count": 1,
                "aspect": "16:9",
            })
            for c in res.content or []:
                print(getattr(c, "text", c))


asyncio.run(main())
