#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Flow 视频模式探针：上传白底参考图 + 动画提示词，看能否出视频。

验证点：
  1) 项目页是否存在视频模型入口（按钮/下拉含「视频/Veo」字样）
  2) 提交后网络层是否出现视频响应（mp4/webm 或 flow-content 视频 URL）
  3) 产物规格（分辨率/时长/水印无法程序判断，落盘人工看）

用法：
  python -u tools/_tmp_flow_video_pilot.py --ref 资料路径/fut_inf_c96_white.jpg \
      --prompt-file <utf8.txt> --out <目录> [--ui-dump-only]
"""
import argparse
import asyncio
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "docs" / "基地重设计"))
import flow_edit_tool as fet  # noqa: E402

UI_DUMP_JS = """
() => {
  const out = {buttons: [], combos: [], aria: []};
  document.querySelectorAll('button').forEach(b => {
    const t = (b.innerText || b.getAttribute('aria-label') || '').trim();
    if (t && t.length < 40) out.buttons.push(t);
  });
  document.querySelectorAll('[role="listbox"], [role="menu"]').forEach(m => {
    out.combos.push((m.innerText || '').slice(0, 300));
  });
  document.querySelectorAll('[aria-label]').forEach(e => {
    const a = e.getAttribute('aria-label');
    if (a && (a.includes('视频') || a.toLowerCase().includes('veo') || a.includes('video')))
      out.aria.push(a);
  });
  const bodyHas = {};
  ['视频', 'Veo', '视频生成', '帧', '时长'].forEach(k => {
    bodyHas[k] = (document.body.innerText || '').includes(k);
  });
  out.bodyHas = bodyHas;
  return out;
}
"""

VIDEO_URL_HINTS = ("video", "mp4", "webm", "veo", "mime=video")


async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True)
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ui-dump-only", action="store_true")
    ap.add_argument("--wait", type=int, default=660)
    args = ap.parse_args()

    ref = Path(args.ref).resolve()
    prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    log = fet.make_logger(out_dir / "flow_video_pilot.log")

    from playwright.async_api import async_playwright
    async with async_playwright() as pw:
        profile_dir = fet.copy_profile(log)
        ctx = await fet.launch_context(pw, profile_dir, headless=False)
        page = ctx.pages[0] if ctx.pages else await ctx.new_page()
        hits: list = []

        async def on_response(resp):
            try:
                u = resp.url
                ct = (resp.headers or {}).get("content-type", "")
                # 只认真视频：mp4/webm 魔数或 flow-content 视频 URL；排除 gstatic 营销素材
                if ("gstatic.com" in u or "landing" in u):
                    return
                if resp.status == 200 and ("video/mp4" in ct or "video/webm" in ct
                                           or ("flow-content" in u and "video" in u.lower())):
                    hits.append((u, ct, resp))
                    log(f"[net] 视频响应: ct={ct} {u[:140]}")
            except Exception:
                pass

        page.on("response", on_response)
        try:
            pid = await fet.discover_project(page, log) or fet.DEFAULT_PROJECT
            if not await fet.goto_ready(page, f"https://flow.google.com/project/{pid}", log):
                log("[nav] 项目页未就绪")
                return 1
            await page.wait_for_timeout(4000)

            dump = await page.evaluate(UI_DUMP_JS)
            log(f"[ui] buttons={dump['buttons'][:24]}")
            log(f"[ui] aria命中={dump['aria']}")
            log(f"[ui] body关键词={dump['bodyHas']}")
            if args.ui_dump_only:
                return 0

            # 上传参考图（同 flow_edit_tool 流程）
            add_btn = page.get_by_role("button", name="在提示框中添加素材")
            if await add_btn.count() == 0:
                log("[ref] 找不到添加素材按钮")
                return 1
            await add_btn.first.click()
            await page.wait_for_timeout(1500)
            upload_item = page.locator('button:has-text("上传媒体内容")').first
            if await upload_item.count() == 0:
                upload_item = page.locator('button:has-text("上传")').first
            async with page.expect_file_chooser(timeout=10000) as fc_info:
                await upload_item.click()
            fc = await fc_info.value
            await fc.set_files(str(ref))
            log("[ref] 已选择参考图")
            await page.wait_for_timeout(15000)
            await fet.close_overlays(page)

            pm = page.locator("div.ProseMirror").first
            try:
                await pm.click(timeout=8000)
            except Exception:
                await page.evaluate("() => document.querySelector('div.ProseMirror').focus()")
            await page.wait_for_timeout(300)
            await page.keyboard.insert_text(prompt)
            await page.wait_for_timeout(600)
            log(f"[prompt] 已输入 {len(prompt)} 字")

            gen_btn = page.get_by_role("button", name="开始生成").first
            # 提交前再看一眼 UI（上传素材后可能出现视频模式选项）
            dump2 = await page.evaluate(UI_DUMP_JS)
            log(f"[ui2] buttons={dump2['buttons'][:24]}")
            log(f"[ui2] aria命中={dump2['aria']}")

            if await gen_btn.is_disabled():
                await page.wait_for_timeout(6000)
            await gen_btn.click()
            log("[gen] 已提交")

            deadline = time.monotonic() + args.wait
            last_log = time.monotonic()
            while time.monotonic() < deadline:
                if hits:
                    break
                if time.monotonic() - last_log > 60:
                    log(f"[wait] …{int(deadline - time.monotonic())}s 剩余, hits={len(hits)}")
                    last_log = time.monotonic()
                await page.wait_for_timeout(5000)
                if time.monotonic() > deadline - 5:
                    log("[body] 全页文本前 1500 字：\n" +
                        (await page.evaluate("() => (document.body.innerText||'').slice(0,1500)")))

            # 落盘：抓 mp4/webm 大响应体
            saved = 0
            for u, ct, resp in hits:
                try:
                    data = await resp.body()
                except Exception:
                    continue
                if len(data) < 100_000:
                    continue
                ext = ".mp4" if data[4:8] == b"ftyp" else (".webm" if data[:4] == b"\x1a\x45\xdf\xa3" else ".bin")
                fp = out_dir / f"flow_video_{int(time.time())}_{saved}{ext}"
                fp.write_bytes(data)
                log(f"[save] ✅ {fp} ({len(data)//1024} KB, ct={ct})")
                saved += 1
            log(f"[done] 视频疑似命中 {len(hits)}，落盘 {saved}")
            return 0 if saved else 1
        finally:
            await ctx.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(asyncio.run(main()))
