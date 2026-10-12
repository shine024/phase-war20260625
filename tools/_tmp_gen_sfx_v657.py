#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6.57 记录3#1：剧情翻格提示音 story_page 换血——程序合成纸感翻页。

实机主诉（2026-10-11 记录3#1）：「开始剧情时的按钮提示音很差要换，黑门出现后，
剧情过度有提示音也不好。」两处同源：序章漫画逐格推进音 story_page（黑门在
intro_comic_panels 第 3 格登场），v6.54 换过的 Kenney 划擦声仍不像翻页。

设计（纸感翻页 ~0.22s mono）：
  - 主体：白噪 → 时变单极低通（截止 2800→700Hz 下扫）= "唰"的挥扫；
  - 纸感颤动：36Hz 浅调幅（纸张抖动）；
  - 碎纸粒：3 粒 3.5kHz 以上高频噪声短粒（16ms 汉宁窗），错落在挥扫中后段；
  - 包络：12ms 快攻 + 85ms 指数衰减 + 尾 30ms 渐隐。

响度策略：RMS 匹配被替换旧文件（v6.54/v6.56 同配方，ffmpeg astats 实测），
统一 OGG Vorbis q6 / 44.1kHz / mono。
旧素材已备份 D:/godotplay/_art_backup/sfx_pre_v657_20261011/。
铁律：*.ogg 不入 git。

用法：python tools/_tmp_gen_sfx_v657.py [--dry-run]
"""
import argparse
import os
import shutil
import subprocess
import sys
import wave

import numpy as np

FFMPEG_CANDIDATES = [
    r"D:/360安全浏览器下载/铁血联盟3/Godot/ffmpeg-8.0-essentials_build/ffmpeg-8.0-essentials_build/bin/ffmpeg.exe",
    "ffmpeg",
]

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SFX_DIR = os.path.join(REPO, "assets", "sfx")
BACKUP_DIR = r"D:/godotplay/_art_backup/sfx_pre_v657_20261011"
SR = 44100
SEED = 20261011


def ffmpeg_bin():
    for c in FFMPEG_CANDIDATES:
        try:
            subprocess.run([c, "-version"], capture_output=True, timeout=10)
            return c
        except Exception:
            continue
    raise SystemExit("ffmpeg not found")


def run(args):
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")


def old_rms(ff, path):
    r = run([ff, "-hide_banner", "-nostats", "-i", path, "-af", "astats", "-f", "null", "-"])
    hits = [ln for ln in r.stderr.splitlines() if "RMS level dB" in ln]
    if not hits:
        return None
    try:
        return float(hits[-1].split(":")[-1].strip())
    except ValueError:
        return None


def rms_db(x):
    m = float(np.mean(x.astype(np.float64) ** 2))
    return 10.0 * np.log10(max(m, 1e-12))


def onepole_lp(x, fc):
    """时变截止单极低通（fc 可为标量或等长数组）。"""
    fc = np.full(len(x), float(fc)) if np.isscalar(fc) else fc
    alpha = 1.0 - np.exp(-2.0 * np.pi * fc / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def synth_page_turn():
    rng = np.random.default_rng(SEED)
    dur = 0.22
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.standard_normal(n).astype(np.float64)

    # 主体：截止下扫的带通体（LP 高截 - LP 低截 150Hz 去隆隆）
    fc_sweep = np.linspace(2800.0, 700.0, n)
    body_band = onepole_lp(x, fc_sweep) - onepole_lp(x, 150.0)
    # 包络：12ms 快攻 + 85ms 指数衰减
    env = np.minimum(t / 0.012, 1.0) * np.exp(-np.maximum(t - 0.012, 0.0) / 0.085)
    # 纸感颤动（36Hz 浅调幅）
    flutter = 1.0 + 0.22 * np.sin(2.0 * np.pi * 36.0 * t + 1.3)
    y = body_band * env * flutter

    # 碎纸粒：高频噪声短粒错落（挥扫中后段），汉宁窗防爆音
    hp = x - onepole_lp(x, 3500.0)
    for gt, gl in ((0.030, 0.35), (0.075, 0.50), (0.130, 0.30)):
        i0 = int(gt * SR)
        i1 = min(n, i0 + int(0.016 * SR))
        if i1 <= i0:
            continue
        grain = hp[i0:i1] * np.hanning(i1 - i0)
        y[i0:i1] += gl * grain * env[i0:i1] * 2.0

    # 尾 30ms 渐隐防咔
    fo = int(0.030 * SR)
    y[-fo:] *= np.linspace(1.0, 0.0, fo)
    return y


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    ff = ffmpeg_bin()
    dst = os.path.join(SFX_DIR, "story_page.ogg")
    if not os.path.isfile(dst):
        raise SystemExit("现役库无 story_page.ogg")
    old = old_rms(ff, dst)
    if old is None:
        print("[WARN] 旧文件 RMS 量测失败 — 用 -18dB 基准")
        old = -18.0
    seg = synth_page_turn()
    gain = old - rms_db(seg)
    print("  story_page dur=%.2fs gain=%+.1f dB (old %.1f)" % (len(seg) / SR, gain, old))
    if args.dry_run:
        return 0

    os.makedirs(BACKUP_DIR, exist_ok=True)
    bak = os.path.join(BACKUP_DIR, "story_page.ogg")
    if not os.path.isfile(bak):
        shutil.copy2(dst, bak)
        print("[备份] %s" % bak)

    y = seg * (10.0 ** (gain / 20.0))
    peak = float(np.max(np.abs(y)))
    if peak > 0.98:
        y *= 0.98 / peak
    tmp_wav = os.path.join(SFX_DIR, "story_page_cut.wav")
    pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp_wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    tmp_ogg = dst + ".tmp.ogg"
    r = run([ff, "-y", "-i", tmp_wav, "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", tmp_ogg])
    if r.returncode != 0 or not os.path.isfile(tmp_ogg):
        print("[FAIL] %s" % (r.stderr or "")[-300:])
        return 1
    os.replace(tmp_ogg, dst)
    os.remove(tmp_wav)
    print("[OK] story_page.ogg ← 程序合成纸感翻页 (seed=%d)" % SEED)
    return 0


if __name__ == "__main__":
    sys.exit(main())
