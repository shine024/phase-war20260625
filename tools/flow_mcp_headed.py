#!/usr/bin/env python3
"""flow-mcp 有头启动器 —— 绕过 Google 对 headless Chrome 的风控。

2026-08-29 实测：flow-mcp 的 browser_pool 写死 headless=True，Google 开始对无头
Chrome 下发不含 recaptcha/enterprise.js 的页面变体（登录态正常但无法 mint token）。
有头模式页面正常。本脚本 monkey-patch _BrowserPool._start 强制 headless=False，
再启动官方 MCP server（stdio），避免改动 site-packages（升级免疫）。
"""
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import flow_mcp.browser_pool as bp


async def _start_headed(self) -> None:
    self._profile_dir = bp.resolve_profile()
    self._cleanup_profile_locks(self._profile_dir)
    channel = bp.channel_for_profile(self._profile_dir)
    self._pw = await bp.async_playwright().start()
    self._ctx = await self._pw.chromium.launch_persistent_context(
        user_data_dir=str(self._profile_dir),
        headless=False,  # ← 关键：有头，Google 才下发完整页面
        channel=channel or None,
        args=bp.BROWSER_ARGS,
        viewport=bp.VIEWPORT,
    )
    self._page = self._ctx.pages[0] if self._ctx.pages else await self._ctx.new_page()
    bp.log.info("browser.pool_started", profile=str(self._profile_dir),
                channel=channel, headed=True)


bp._BrowserPool._start = _start_headed

# ── 会话续接：Google 可能把会话拦在账号选择页（accounts.google.com/accountchooser）──
# 现象：落地页 3s 时有 recaptcha 脚本 → 整页跳转到账号选择页并停留；
# capture_bearer_token 收到跳转前残页的 ya29 便"成功"，随后在谷歌页面上找
# recaptcha 脚本必然失败。修法：capture 前若发现被拦，自动点击已保存账号继续。
import flow_mcp.browser as _fb  # noqa: E402
import flow_mcp.generator as _gen  # noqa: E402

_orig_capture = _fb.capture_bearer_token


async def _capture_with_session_continue(page, timeout_ms: int = 60_000):
    try:
        await page.goto("https://labs.google/fx/tools/flow",
                        wait_until="domcontentloaded", timeout=timeout_ms)
        await page.wait_for_timeout(4000)
        if "accounts.google.com" in (page.url or ""):
            _fb.log.warning("auth.account_chooser_detected", url=page.url[:120])
            await page.locator("[data-identifier]").first.click(timeout=10000)
            await page.wait_for_url("**labs.google**", timeout=60000)
            await page.wait_for_timeout(3000)
    except Exception as exc:
        _fb.log.warning("auth.session_continue_failed", error=str(exc)[:200])
        if "accounts.google.com" in (page.url or ""):
            raise  # 连点账号都失败（如要求输密码）→ 交回原逻辑报错，需人工登录
    return await _orig_capture(page, timeout_ms)


_fb.capture_bearer_token = _capture_with_session_continue
_gen.capture_bearer_token = _capture_with_session_continue  # generator 是 from-import 绑定

from flow_mcp.server import main  # noqa: E402

if __name__ == "__main__":
    main()
