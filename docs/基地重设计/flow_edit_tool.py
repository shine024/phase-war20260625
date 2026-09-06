# -*- coding: utf-8 -*-
"""Flow 网页版图片编辑工具（独立版，可跨机器使用）

原理：Google 已把 Flow 迁到 flow.google.com，flow-mcp 的 API 直调路线失效。
本工具直接驱动真实网页 UI：打开项目 → 上传参考图 → 输提示词 → 点「开始生成」
→ 从网络层截获结果图原始字节落盘。全程不需要 reCAPTCHA/API 逆向。

依赖（目标机器上装一次）：
  1. Python 3.10+
  2. pip install playwright
  3. 安装 Google Chrome（playwright 以 chrome 通道启动；没有则回退内置 chromium）
  4. 首次使用先登录：python flow_edit_tool.py --login

用法：
  python flow_edit_tool.py --login                         # 首次登录（弹出浏览器）
  python flow_edit_tool.py --ref a.jpg --prompt-file p.txt  # 图生图编辑
  python flow_edit_tool.py --ref a.jpg --prompt "提示词" --prefix cutaway
  可选: --project <uuid>   指定 Flow 项目（默认自动发现第一个）
        --count N          最多保存结果数（默认 2）
        --outdir <dir>     输出目录（默认参考图所在目录）

输出: <outdir>/<prefix>_<时间戳>_<uuid8>.jpg，日志: <outdir>/flow_edit.log
"""
import argparse
import asyncio
import base64
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path

BROWSER_ARGS = [
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--disable-blink-features=AutomationControlled",
]
VIEWPORT = {"width": 1280, "height": 720}
GEN_WAIT_S = 300
SUBMIT_RETRIES = 2
DEFAULT_PROJECT = "5bffb93f-5026-4009-872c-cb70d0304f45"  # 本仓库美术工作用的 Flow 项目


# ── 基础工具 ────────────────────────────────────────────────────────────

def make_logger(log_file: Path):
    def log(msg: str) -> None:
        line = f"[{time.strftime('%H:%M:%S')}] {msg}"
        print(line, flush=True)
        try:
            with log_file.open("a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        except OSError:
            pass
    return log


def jpeg_size(data: bytes):
    """JPEG (w, h)；非 JPEG 或解析失败返回 None。"""
    if not data.startswith(b"\xff\xd8"):
        return None
    i = 2
    while i + 9 < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3):
            h = int.from_bytes(data[i + 5:i + 7], "big")
            w = int.from_bytes(data[i + 7:i + 9], "big")
            return (w, h)
        if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        seglen = int.from_bytes(data[i + 2:i + 4], "big")
        i += 2 + seglen
    return None


def ext_of(head: bytes) -> str:
    if head.startswith(b"\xff\xd8"):
        return "jpg"
    if head.startswith(b"\x89PNG"):
        return "png"
    if head.startswith(b"RIFF"):
        return "webp"
    return "jpg"


# ── gflow profile 定位（跨机器） ────────────────────────────────────────

def gflow_home() -> Path:
    if os.environ.get("GFLOW_CLI_HOME"):
        return Path(os.environ["GFLOW_CLI_HOME"])
    if sys.platform == "win32" and os.environ.get("LOCALAPPDATA"):
        return Path(os.environ["LOCALAPPDATA"]) / "ffroliva" / "gflow-cli"
    # macOS / Linux（platformdirs 约定，与 gflow-cli 一致）
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/ffroliva.gflow-cli"
    return Path.home() / ".local/share/ffroliva/gflow-cli"


def find_profile(log=None) -> Path | None:
    """返回第一个带 .gflow_account 的 profile_* 目录；无则 None。"""
    home = gflow_home()
    if not home.is_dir():
        return None
    for d in sorted(home.glob("profile_*")):
        if d.name.endswith(".broken"):
            continue
        if (d / ".gflow_account").exists() or (d / "Default").is_dir():
            return d
    return None


def copy_profile(log) -> Path:
    """把真实 profile 复制到临时目录，避开运行中 Chrome 的独占锁。"""
    src = find_profile()
    if src is None:
        raise RuntimeError(
            f"未找到已登录的 gflow profile（找过 {gflow_home()}）。\n"
            "请先运行: python flow_edit_tool.py --login"
        )
    tmp = Path(os.environ.get("TEMP", str(Path.home() / ".tmp"))) / "flow_edit_profile"
    if tmp.exists():
        shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True, exist_ok=True)
    dst = tmp / src.name

    def _ignore(_d, names):
        skip = []
        for n in names:
            ln = n.lower()
            if (ln in ("lock", "lockfile") or ln.startswith("singleton")
                    or ln.endswith(".tmp") or ln in (
                        "cache", "code cache", "gpucache", "grshadercache",
                        "shadercache", "dawngraphitecache", "dawnwebgpucache")):
                skip.append(n)
        return skip

    try:
        shutil.copytree(src, dst, ignore=_ignore)
    except shutil.Error as exc:
        failed = {Path(item[0]).name.lower() for item in exc.args[0]}
        log(f"[prep] 复制跳过锁文件: {sorted(failed)}")
        if "cookies" in failed:
            raise RuntimeError(
                "Cookies 被运行中的 Chrome 独占。请先结束占用 gflow profile 的 chrome 进程"
                "（任务管理器搜 chrome / 或重启机器）再重试。"
            )
    for pat in ("SingletonLock", "SingletonCookie", "SingletonSocket"):
        for p in (dst / pat, dst / "Default" / pat):
            try:
                p.unlink()
            except OSError:
                pass
    log(f"[prep] profile 副本就绪: {dst}")
    return dst


# ── 浏览器启动（只依赖 playwright） ────────────────────────────────────

async def launch_context(pw, profile_dir: Path, headless: bool = True):
    """优先系统 Chrome 通道，失败回退 playwright 内置 chromium。"""
    common = dict(
        user_data_dir=str(profile_dir),
        headless=headless,
        args=BROWSER_ARGS,
        viewport=VIEWPORT,
    )
    try:
        return await pw.chromium.launch_persistent_context(channel="chrome", **common)
    except Exception:
        return await pw.chromium.launch_persistent_context(**common)


# ── 页面流程 ────────────────────────────────────────────────────────────

PROJECT_LINK_JS = (
    "() => { const a = document.querySelector('a[href^=\"/project/\"]');"
    " return a ? a.getAttribute('href') : null; }"
)
READY_JS = (
    "() => !!document.querySelector('div.ProseMirror')"
    " || (document.body.innerText||'').includes('开始生成')"
)
OVERLAY_JS = "() => !!document.querySelector('.cdk-overlay-backdrop-showing')"
TILES_JS = "() => document.querySelectorAll('.error-tile').length"
THUMBS_JS = (
    "() => Array.from(document.querySelectorAll('img')).map(i => (i.src||'').slice(0,150))"
    ".filter(s => s.includes('googleusercontent') || s.startsWith('blob:')"
    " || s.includes('flow-content.google'))"
)


async def goto_ready(page, url: str, log, tries: int = 4) -> bool:
    for attempt in range(1, tries + 1):
        try:
            await page.goto(url, wait_until="domcontentloaded", timeout=90000)
        except Exception as exc:
            log(f"[nav] goto 尝试{attempt} 超时(非致命): {str(exc)[:90]}")
        await page.wait_for_timeout(15000)
        try:
            if await page.evaluate(READY_JS):
                return True
        except Exception:
            pass
        try:
            dbg = await page.evaluate(
                """() => ({url: location.href.slice(0, 90), title: document.title.slice(0, 50),
                    pm: !!document.querySelector('div.ProseMirror'),
                    signIn: (document.body.innerText || '').includes('登录') && !(document.body.innerText || '').includes('开始生成'),
                    bodyHead: (document.body.innerText || '').replace(/\\s+/g, ' ').slice(0, 120)})"""
            )
            log(f"[nav] 尝试{attempt} 未就绪: {dbg}")
        except Exception:
            pass
    return False


async def close_overlays(page, rounds: int = 3):
    for _ in range(rounds):
        if not await page.evaluate(OVERLAY_JS):
            break
        await page.keyboard.press("Escape")
        await page.wait_for_timeout(1000)


async def discover_project(page, log) -> str | None:
    try:
        await page.goto("https://flow.google.com/", wait_until="domcontentloaded", timeout=90000)
    except Exception as exc:
        log(f"[nav] 首页超时(非致命): {str(exc)[:90]}")
    for _ in range(6):  # 项目列表可能渲染慢，轮询 30s
        href = await page.evaluate(PROJECT_LINK_JS)
        if href:
            pid = href.rstrip("/").rsplit("/", 1)[-1]
            log(f"[nav] 自动发现项目: {pid}")
            return pid
        await page.wait_for_timeout(5000)
    return None


async def do_login() -> int:
    """首次登录：无头浏览器打开 flow.google.com，用户手动登录 Google。"""
    real = find_profile()
    target = real if real is not None else gflow_home() / "profile_default"
    target.mkdir(parents=True, exist_ok=True)
    print(f"登录 profile: {target}")
    from playwright.async_api import async_playwright
    async with async_playwright() as pw:
        ctx = await launch_context(pw, target, headless=False)
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        await page.goto("https://flow.google.com/", wait_until="domcontentloaded", timeout=90000)
        print("=" * 56)
        print("浏览器已打开 flow.google.com")
        print("请在浏览器中登录你的 Google 账号（登录后能看到项目列表即算成功）")
        print("完成后回到此窗口按 Enter ...")
        print("=" * 56)
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, input)
        ok = False
        for _ in range(20):
            try:
                if await page.evaluate(PROJECT_LINK_JS):
                    ok = True
                    break
            except Exception:
                pass
            await page.wait_for_timeout(3000)
        await ctx.close()
        print("✅ 登录成功，以后可直接用 --ref ... 生成" if ok else
              "⚠️ 未检测到项目列表；如已登录成功也可直接尝试生成")
        return 0 if ok else 1


# ── 主流程 ──────────────────────────────────────────────────────────────

async def run_edit(args) -> int:
    ref = Path(args.ref).resolve()
    if not ref.exists():
        print(f"参考图不存在: {ref}")
        return 1
    prompt = (Path(args.prompt_file).read_text(encoding="utf-8").strip()
              if args.prompt_file else args.prompt)
    if not prompt and not args.dry_run:
        print("需要 --prompt 或 --prompt-file")
        return 1
    out_dir = Path(args.outdir).resolve() if args.outdir else ref.parent
    out_dir.mkdir(parents=True, exist_ok=True)
    log = make_logger(out_dir / "flow_edit.log")
    ref_dims = jpeg_size(ref.read_bytes()[:65536])
    log(f"[run] ref={ref.name} dims={ref_dims} prompt={len(prompt or '')}字 out={out_dir} dry_run={args.dry_run}")

    profile_dir = copy_profile(log)
    from playwright.async_api import async_playwright
    async with async_playwright() as pw:
        ctx = await launch_context(pw, profile_dir, headless=True)
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        captured: dict = {}
        bodies: list[str] = []

        async def on_response(resp):
            try:
                u = resp.url
                if "batchexecute" in u and resp.status == 200:
                    bodies.append(await resp.text())
                elif "flow-content.google/image/" in u and resp.status == 200:
                    data = await resp.body()
                    if len(data) > 30_000:
                        uuid = u.split("/image/")[1][:36]
                        if uuid not in captured:
                            captured[uuid] = data
                            log(f"[net] 截获 {uuid[:8]} ({len(data)//1024} KB)")
            except Exception:
                pass

        page.on("response", on_response)
        try:
            # 1) 项目
            if args.project:
                pid = args.project
            else:
                pid = await discover_project(page, log)
                if not pid:
                    pid = DEFAULT_PROJECT
                    log(f"[nav] 自动发现失败，回退默认项目: {pid}")
            if not await goto_ready(page, f"https://flow.google.com/project/{pid}", log):
                log("[nav] 项目页未就绪（检查代理/登录状态）")
                return 1

            # 2) 上传参考图
            if args.dry_run:
                log("[dry-run] ✅ 环境/登录/项目均正常，未提交生成")
                return 0
            add_btn = page.get_by_role("button", name="在提示框中添加素材")
            if await add_btn.count() == 0:
                log("[ref] 找不到「在提示框中添加素材」按钮")
                return 1
            await add_btn.first.click()
            await page.wait_for_timeout(1500)
            upload_item = page.locator('button:has-text("上传媒体内容")').first
            if await upload_item.count() == 0:
                upload_item = page.locator('button:has-text("上传")').first
            try:
                async with page.expect_file_chooser(timeout=10000) as fc_info:
                    await upload_item.click()
                fc = await fc_info.value
                await fc.set_files(str(ref))
                log("[ref] 已选择文件")
            except Exception as exc:
                log(f"[ref] 上传失败: {type(exc).__name__}: {str(exc)[:150]}")
                return 1
            await page.wait_for_timeout(15000)
            await close_overlays(page)

            # 3) 提示词 + 提交
            pm = page.locator("div.ProseMirror").first
            try:
                await pm.click(timeout=8000)
            except Exception:
                await page.evaluate("() => document.querySelector('div.ProseMirror').focus()")
            await page.wait_for_timeout(400)
            await page.keyboard.insert_text(prompt)
            await page.wait_for_timeout(800)
            log(f"[prompt] 已输入 {len(await pm.inner_text())} 字")

            baseline_tiles = await page.evaluate(TILES_JS)
            cap_base = set(captured)
            imgs_before = set(await page.evaluate(THUMBS_JS))
            log(f"[gen] baseline: tiles={baseline_tiles} captured={len(cap_base)}")

            got_urls: list[str] = []
            new_imgs: list[str] = []
            for attempt in range(1, SUBMIT_RETRIES + 2):
                gen_btn = page.get_by_role("button", name="开始生成")
                if await gen_btn.count() == 0:
                    log("[gen] 找不到「开始生成」按钮")
                    return 1
                if await gen_btn.first.is_disabled():
                    await page.wait_for_timeout(8000)
                await gen_btn.first.click()
                log(f"[gen] 已提交 (attempt {attempt})")

                marked = len(bodies)
                deadline = time.monotonic() + GEN_WAIT_S
                failed = False
                while time.monotonic() < deadline:
                    if [u for u in captured if u not in cap_base]:
                        break
                    for body in bodies[marked:]:
                        urls = re.findall(r'"fifeUrl"\s*:\s*"([^"]+)"', body)
                        if urls:
                            got_urls = [x.replace("\\u0026", "&") for x in urls]
                            break
                    if got_urls:
                        break
                    cur = set(await page.evaluate(THUMBS_JS))
                    fresh_dom = [u for u in cur - imgs_before if len(u) > 70]
                    if fresh_dom:
                        new_imgs = fresh_dom
                        log(f"[gen] DOM 出现新图: {fresh_dom[:2]}")
                        break
                    if await page.evaluate(TILES_JS) > baseline_tiles:
                        log("[gen] 新错误卡片 → 本轮失败")
                        failed = True
                        break
                    await page.wait_for_timeout(5000)

                # DOM 出图后字节可能晚几秒到达，多等一轮再收网
                for _ in range(4):
                    if [u for u in captured if u not in cap_base]:
                        break
                    await page.wait_for_timeout(3000)

                if [u for u in captured if u not in cap_base] or got_urls or new_imgs:
                    break
                if not failed:
                    log("[gen] 未检测到结果，重试提交")
                baseline_tiles = await page.evaluate(TILES_JS)
                cap_base = set(captured)
                imgs_before = set(await page.evaluate(THUMBS_JS))
                await page.wait_for_timeout(4000)

            # 4) 保存
            stamp = time.strftime("%Y%m%d-%H%M%S")
            saved: list[str] = []
            for uuid in [u for u in captured if u not in cap_base] or list(captured):
                data = captured[uuid]
                size = jpeg_size(data)
                if size == ref_dims:
                    log(f"[save] 跳过 {uuid[:8]}: 尺寸 {size} 与参考图一致（素材回显）")
                    continue
                out = out_dir / f"{args.prefix}_{stamp}_{uuid[:8]}.{ext_of(data[:12])}"
                out.write_bytes(data)
                saved.append(str(out))
                log(f"[save] {out} ({len(data)//1024} KB, {size})")
                if len(saved) >= args.count:
                    break
            if not saved and (got_urls or new_imgs):
                for idx, u in enumerate(dict.fromkeys(got_urls or new_imgs)):
                    data_url = await page.evaluate(
                        """async (u) => { try {
                            const r = await fetch(u);
                            if (!r.ok) return null;
                            const b = await r.blob();
                            return await new Promise(res => { const d = new FileReader();
                                d.onload = () => res(d.result); d.readAsDataURL(b); });
                        } catch (e) { return null; } }""",
                        u,
                    )
                    if data_url and data_url.startswith("data:"):
                        raw = base64.b64decode(data_url.split(",", 1)[1])
                        out = out_dir / f"{args.prefix}_{stamp}_{idx}.{ext_of(raw[:12])}"
                        out.write_bytes(raw)
                        saved.append(str(out))
                        log(f"[save] {out} ({len(raw)//1024} KB, fetch)")
                    if len(saved) >= args.count:
                        break
            log("[run] ✅ 成功: " + ", ".join(saved) if saved else "[run] ❌ 未拿到结果")
            return 0 if saved else 1
        finally:
            await ctx.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="Flow 网页版图片编辑工具（UI 自动化）")
    ap.add_argument("--ref", help="参考图路径")
    ap.add_argument("--prompt", help="提示词（中文建议用 --prompt-file）")
    ap.add_argument("--prompt-file", help="UTF-8 提示词文件")
    ap.add_argument("--prefix", default="flow_edit", help="输出文件名前缀")
    ap.add_argument("--count", type=int, default=2, help="最多保存结果数")
    ap.add_argument("--project", help="Flow 项目 UUID（默认自动发现）")
    ap.add_argument("--outdir", help="输出目录（默认参考图所在目录）")
    ap.add_argument("--login", action="store_true", help="首次登录 Google 账号")
    ap.add_argument("--dry-run", action="store_true", help="只验证环境/登录/项目可达，不提交生成")
    args = ap.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    if args.login:
        return asyncio.run(do_login())
    if not args.ref:
        ap.error("需要 --ref（或 --login 首次登录）")
    try:
        return asyncio.run(run_edit(args))
    except KeyboardInterrupt:
        print("\n中断")
        return 1
    except Exception as exc:
        print(f"fatal: {type(exc).__name__}: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
