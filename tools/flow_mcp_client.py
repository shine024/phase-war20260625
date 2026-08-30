#!/usr/bin/env python3
"""flow-mcp stdio 客户端 —— 让 DSH 通过子进程 JSON-RPC 调 flow-mcp（Google Flow 生图）。

用法：
    python tools/flow_mcp_client.py --out-dir <目录> [--only tex_grass tex_sea ...]

按 docs/地图重设计/格陵兰底图提示词与流程.md §2 的 5 条材质贴图提示词生成，
产物归一化为 tex_*.png（1024×1024 RGB），原始 flow-gen-* 文件移入 _raw/ 备查。
服务器 stderr 落盘到 <out-dir>/_flow_mcp_server.log。
"""
import argparse
import json
import os
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

EXE = r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\Scripts\flow-mcp.exe"
# 有头启动器：绕过 Google 对 headless Chrome 的页面风控（见 flow_mcp_headed.py 头注）
WRAPPER = str((Path(__file__).parent / "flow_mcp_headed.py").resolve())
SERVER_CMD = [sys.executable, WRAPPER]

HEAD = ("seamless tileable texture, hand-painted watercolor game asset, top-down flat view, "
        "even soft lighting, uniform repeating pattern filling the whole square, "
        "no objects, no border, no vignette, no text, no watermark")

TILES = [
    ("tex_grass", "arctic tundra grassland and moss, muted sage green with dry grass "
     "brush strokes and small patches of bare earth"),
    ("tex_snow", "fresh snow field, pale blue-white, faint wind ripples, sparse ice "
     "crystal sparkle, soft drifts"),
    ("tex_rock", "rugged grey-brown mountain rock and scree slope, painterly cracks, "
     "gravel and lichen speckles"),
    ("tex_sea", "calm deep ocean water seen from directly above, dark blue, subtle "
     "current brush strokes and faint wave shimmer"),
    ("tex_forest", "dense dark pine forest canopy seen from high above, muted blue-green, "
     "painterly clumping tree crowns with tiny snow gaps"),
]

CALL_TIMEOUT_S = 300   # 单次生成（含浏览器启动/轮询）上限


class McpClient:
    """极简 MCP stdio JSON-RPC 客户端（newline-delimited JSON）。"""

    def __init__(self, cmd: list[str], env: dict, stderr_file: Path):
        self._err = open(stderr_file, "w", encoding="utf-8", errors="replace")
        self.proc = subprocess.Popen(
            cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=self._err, env=env, text=True, encoding="utf-8",
        )
        self.q: queue.Queue = queue.Queue()
        self._id = 0
        threading.Thread(target=self._reader, daemon=True).start()

    def _reader(self) -> None:
        for line in self.proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "id" in msg:  # 响应（通知无 id，忽略）
                self.q.put(msg)

    def request(self, method: str, params: dict | None = None, timeout: float = CALL_TIMEOUT_S):
        self._id += 1
        rid = self._id
        req = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            req["params"] = params
        self.proc.stdin.write(json.dumps(req) + "\n")
        self.proc.stdin.flush()
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                msg = self.q.get(timeout=max(0.2, deadline - time.time()))
            except queue.Empty:
                break
            if msg.get("id") == rid:
                if "error" in msg:
                    raise RuntimeError(f"MCP error: {msg['error']}")
                return msg.get("result")
        raise TimeoutError(f"{method} 无响应（>{timeout:.0f}s）")

    def notify(self, method: str) -> None:
        self.proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": method}) + "\n")
        self.proc.stdin.flush()

    def close(self) -> None:
        try:
            self.proc.stdin.close()
        except Exception:
            pass
        try:
            self.proc.wait(timeout=15)
        except Exception:
            self.proc.kill()
        self._err.close()


def result_text(result: dict) -> str:
    parts = []
    for c in (result or {}).get("content") or []:
        if c.get("type") == "text":
            parts.append(c.get("text", ""))
    return "\n".join(parts) or json.dumps(result, ensure_ascii=False)


def normalize(raw_files: list[Path], out_png: Path, resize_to: tuple | None = None) -> None:
    from PIL import Image
    src = raw_files[0]
    im = Image.open(src).convert("RGB")
    if resize_to and im.size != resize_to:
        im = im.resize(resize_to, Image.LANCZOS)
    im.save(out_png)
    print(f"   ↳ 归一化 {src.name} → {out_png.name} ({im.size[0]}×{im.size[1]})", flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", required=True, help="贴图输出目录（GFLOW_OUTPUT_DIR）")
    ap.add_argument("--only", nargs="*", default=None, help="只生成指定的 tile 名（冒烟测试用）")
    ap.add_argument("--model", default="nano-pro", help="nano-pro(默认) | nano2 | narwhal | gem_pix_2")
    # 注意：flow-mcp 0.3.0 上游 bug——resolution="1k" 在 generator.py:466 无条件字典取值必 KeyError，
    # 只能传 "2k"（走 upsample；失败自动回退原图下载），2K 源下采样到 1024 质量反而更好。
    ap.add_argument("--resolution", default="2k", choices=["2k", "4k"])
    ap.add_argument("--prompt", default=None, help="任意提示词（自由模式）；不传则跑内置 5 贴图")
    ap.add_argument("--name", default="candidate", help="自由模式输出基名")
    ap.add_argument("--count", type=int, default=1, help="自由模式生成张数（顺序多次调用）")
    ap.add_argument("--aspect", default="1:1", choices=["9:16", "16:9", "1:1", "4:3", "3:4"])
    ap.add_argument("--gcli-home", default=None,
                    help="GFLOW_CLI_HOME 覆盖（用隔离 profile 副本，避开 DSH 原生工具的浏览器锁）")
    ap.add_argument("--resize", default=None, help="归一化目标尺寸如 1024x1024；默认保留原生尺寸")
    args = ap.parse_args()

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = out_dir / "_raw"
    raw_dir.mkdir(exist_ok=True)

    env = dict(os.environ)
    env["GFLOW_OUTPUT_DIR"] = str(out_dir)
    env["FLOW_GEN_TIMEOUT_MS"] = "240000"  # 默认 90s 对慢生成不够
    env["FLOW_NAV_TIMEOUT_MS"] = "90000"
    if args.gcli_home:
        env["GFLOW_CLI_HOME"] = str(Path(args.gcli_home).resolve())

    if args.prompt:
        # 自由模式：jobs 直接携带完整提示词
        jobs = [((args.name if args.count == 1 else f"{args.name}_{i}"), args.prompt)
                for i in range(1, args.count + 1)]
    else:
        # 贴图模式：内置 HEAD + 各 tile 描述
        jobs = [((n), HEAD + " ; " + d) for n, d in TILES if args.only is None or n in args.only]
    resize_to = tuple(int(x) for x in args.resize.split("x")) if args.resize else None
    print(f"flow-mcp 客户端：{len(jobs)} 张 → {out_dir}  (model={args.model}, aspect={args.aspect})", flush=True)

    cli = McpClient(SERVER_CMD, env, out_dir / "_flow_mcp_server.log")
    ok = 0
    try:
        init = cli.request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "dsh-phase-war", "version": "1.0"},
        }, timeout=60)
        print(f"握手 OK：server = {init.get('serverInfo', {}).get('name')} "
              f"v{init.get('serverInfo', {}).get('version')}", flush=True)
        cli.notify("notifications/initialized")

        tools = cli.request("tools/list", {}, timeout=30)
        print("工具：", ", ".join(t["name"] for t in tools.get("tools", [])), flush=True)

        for name, desc in jobs:
            out_png = out_dir / f"{name}.png"
            if out_png.exists():
                print(f"── {name} 已存在，跳过", flush=True)
                ok += 1
                continue
            saved = False
            for attempt in range(1, 4):  # 页面慢加载/瞬时失败重试
                before = set(p.name for p in out_dir.iterdir())
                print(f"── {name} 生成中 (第 {attempt} 次) ...", flush=True)
                try:
                    res = cli.request("tools/call", {
                        "name": "generate_image",
                        "arguments": {
                            "prompt": desc,
                            "model": args.model,
                            "count": 1,
                            "aspect": args.aspect,
                            "resolution": args.resolution,
                        },
                    })
                except (TimeoutError, RuntimeError) as exc:
                    print(f"   ⚠ 调用异常：{exc}", flush=True)
                    if attempt < 3:
                        time.sleep(8)
                        continue
                    break
                text = result_text(res)
                is_err = (res or {}).get("isError", False) or text.lstrip().startswith("❌")
                new_files = [p for p in out_dir.iterdir() if p.name not in before
                             and p.is_file() and p.name.startswith("flow-gen")]
                if not is_err and new_files:
                    normalize(new_files, out_png, resize_to)
                    for f in new_files:
                        f.rename(raw_dir / f.name)
                    saved = True
                    break
                transient = ("recaptcha" in text.lower() or "failed to load" in text.lower()
                             or "timed out" in text.lower() or "429" in text)
                print(f"   ✗ {name}：{text[:300]}", flush=True)
                if transient and attempt < 3:
                    time.sleep(10)
                    continue
                break
            if saved:
                ok += 1
    finally:
        cli.close()
    print(f"完成 {ok}/{len(jobs)} → {out_dir}", flush=True)
    return 0 if ok == len(jobs) else 1


if __name__ == "__main__":
    sys.exit(main())
