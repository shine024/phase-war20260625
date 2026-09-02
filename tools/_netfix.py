# -*- coding: utf-8 -*-
"""共享网络修复：绕过本机系统代理(127.0.0.1:10808 间歇拒绝) + 跳过证书验证。

背景（2026-09-01 排查）：
- urllib.request.urlopen(req, context=ctx) 传 context 时会 build_opener 新链
  并重读系统代理 → 代理拒绝连接 ConnectionRefused；
- 仅 ProxyHandler({}) 直连又遇 SSLCertVerificationError（证书链不被本机信任）；
- 解法：唯一 opener = ProxyHandler({}) + HTTPSHandler(unverified)，一律走
  OPENER.open()（显式调用或 install 后用无 context 的 urlopen）。
"""
import ssl
import urllib.request

_CTX = ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = ssl.CERT_NONE

OPENER = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=_CTX),
)


def install() -> None:
    """装成全局 opener——使既有代码里无 context 的 urlopen 也走本链。"""
    urllib.request.install_opener(OPENER)


def open_url(req, timeout=180):
    return OPENER.open(req, timeout=timeout)
