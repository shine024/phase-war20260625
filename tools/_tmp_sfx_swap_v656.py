#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6.56 记录1三轮#5：武器音效换血——The Free Firearm Sound Library (bart, OGA, CC0)
真枪录音替换自合成枪声。

实机主诉（2026-10-10 记录1三轮#5）：「武器音效，不好，不像开枪开炮等的音效。」
源：Prepared SFX Library（21 枪族 54 发野外录音，每文件为多连发长录音），
需瞬态检测剪出单发/短点射再换血；missile_hum 枪族无对应源，用 Kenney Sci-Fi
（CC0，v6.54 同包本地存档）thrusterFire_002 变体（v6.54 rocket_launch 用过 _001，取变体避同质）。

响度策略：RMS 匹配被替换旧文件（v6.54 流程沿用，实测旧文件 astats RMS_level），
混合配比不变；统一转码 OGG Vorbis q6 / 44.1kHz / mono。
剪裁策略：envelope(10ms 均滑) 首个过阈瞬态为弹头起点，前 12ms 预卷，按时长剪，
尾 80ms 渐隐防咔；PPSh 两文件分别供 gun_mg(短点射) 与 flak_fire(密集连发段)。

证据链：7z 原包存档 /d/godotplay/sfxdl/oga_gun_20261010/（OGA 页面 CC0 声明截图
见工单）；Kenney sci-fi 原包沿用 _steam_assets/licenses/kenney_20261010/ 存档。
旧素材已备份 D:/godotplay/_art_backup/sfx_pre_v656_20261010/。
铁律：*.ogg 不入 git。

用法：python tools/_tmp_sfx_swap_v656.py [--src <解包根>] [--dry-run]
"""
import argparse
import os
import subprocess
import sys

import numpy as np

FFMPEG_CANDIDATES = [
    r"D:/360安全浏览器下载/铁血联盟3/Godot/ffmpeg-8.0-essentials_build/ffmpeg-8.0-essentials_build/bin/ffmpeg.exe",
    "ffmpeg",
]

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SFX_DIR = os.path.join(REPO, "assets", "sfx")
SR = 44100

## slot → (源文件, (kind, dur_sec))。kind: "shot"=瞬态剪单发; "trim"=定长剪+尾渐隐
MAPPING = {
    "gun_pistol":  ("firearm/Prepared SFX Library/1911/A_34P.wav", ("shot", 0.50)),
    "gun_smg":     ("firearm/Prepared SFX Library/Carl Gustav M45/G_24P.wav", ("shot", 0.40)),
    "gun_rifle":   ("firearm/Prepared SFX Library/AK-47/C_29P.wav", ("shot", 0.60)),
    "gun_mg":      ("firearm/Prepared SFX Library/PPSh/P_22P.wav", ("shot", 0.75)),
    "gun_shotgun": ("firearm/Prepared SFX Library/Mossberg/N_26P.wav", ("shot", 0.90)),
    "gun_sniper":  ("firearm/Prepared SFX Library/Mosin Nagant/M_26P.wav", ("shot", 1.05)),
    "flak_fire":   ("firearm/Prepared SFX Library/PPSh/P_18P.wav", ("shot", 0.55)),
    "shoot":       ("firearm/Prepared SFX Library/AR-15/D_24P.wav", ("shot", 0.55)),
    "missile_hum": ("kenney_scifi/Audio/thrusterFire_002.ogg", ("trim", 0.90, 0.25)),
}


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


def load_mono(ff, path):
    """ffmpeg 解码为 mono s16le 44.1k 原始 PCM → float32 numpy。"""
    r = subprocess.run(
        [ff, "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
        capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace")[-200:])
    x = np.frombuffer(r.stdout, dtype=np.int16).astype(np.float32) / 32768.0
    return x


def rms_db(x):
    m = float(np.mean(x.astype(np.float64) ** 2))
    return 10.0 * np.log10(max(m, 1e-12))


def old_rms(ff, path):
    r = run([ff, "-hide_banner", "-nostats", "-i", path, "-af", "astats", "-f", "null", "-"])
    hits = [ln for ln in r.stderr.splitlines() if "RMS level dB" in ln]
    if not hits:
        return None
    try:
        return float(hits[-1].split(":")[-1].strip())
    except ValueError:
        return None


def cut_shot(x, dur):
    """envelope 10ms 均滑，首个过阈(峰值25%)瞬态=弹头起点，前 12ms 预卷。"""
    win = max(1, int(0.010 * SR))
    env = np.abs(x)
    env = np.convolve(env, np.ones(win) / win, mode="same")
    peak = float(np.percentile(env, 99.5))
    thr = peak * 0.25
    skip = int(0.05 * SR)  # 跳过文件头 50ms 防起手杂音误触发
    idx = int(np.argmax(env[skip:] > thr)) + skip
    start = max(0, idx - int(0.012 * SR))
    end = min(len(x), start + int(dur * SR))
    seg = x[start:end].copy()
    fi = max(1, int(0.003 * SR))
    seg[:fi] *= np.linspace(0, 1, fi)
    fo = min(len(seg), int(0.080 * SR))
    seg[-fo:] *= np.linspace(1, 0, fo)
    return seg


def cut_trim(x, dur, fade):
    seg = x[: int(dur * SR)].copy()
    fo = min(len(seg), int(fade * SR))
    seg[-fo:] *= np.linspace(1, 0, fo)
    return seg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=r"D:/godotplay/sfxdl/oga_gun_20261010")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    ff = ffmpeg_bin()
    work = os.path.join(os.path.abspath(args.src), "_work")
    os.makedirs(work, exist_ok=True)

    plan = []
    for slot, (rel, spec) in MAPPING.items():
        src = os.path.join(args.src, rel)
        dst = os.path.join(SFX_DIR, slot + ".ogg")
        if not os.path.isfile(src):
            print("[MISS] 源不存在: %s" % src)
            continue
        if not os.path.isfile(dst):
            print("[MISS] 目标不在现役库（跳过）: %s" % dst)
            continue
        old = old_rms(ff, dst)
        if old is None:
            print("[WARN] 旧文件 RMS 量测失败 %s — 用 -18dB 基准" % slot)
            old = -18.0
        x = load_mono(ff, src)
        if spec[0] == "shot":
            seg = cut_shot(x, spec[1])
        else:
            seg = cut_trim(x, spec[1], spec[2])
        gain = old - rms_db(seg)
        plan.append((slot, src, dst, seg, gain))
        print("  %-12s dur=%.2fs gain=%+.1f dB (old %.1f)" % (slot, len(seg) / SR, gain, old))
    print("=== 换血计划 %d 项 ===" % len(plan))
    if args.dry_run:
        return 0

    for slot, src, dst, seg, gain in plan:
        # 增益落 PCM 再转码（避免 ffmpeg volume 滤镜二次量测歧义），限幅保护
        y = seg * (10.0 ** (gain / 20.0))
        peak = float(np.max(np.abs(y)))
        if peak > 0.98:
            y *= 0.98 / peak
        tmp_wav = os.path.join(work, slot + "_cut.wav")
        pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
        import wave
        with wave.open(tmp_wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        tmp_ogg = dst + ".tmp.ogg"
        r = run([ff, "-y", "-i", tmp_wav, "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", tmp_ogg])
        if r.returncode != 0 or not os.path.isfile(tmp_ogg):
            print("[FAIL] %s: %s" % (slot, (r.stderr or "")[-300:]))
            continue
        os.replace(tmp_ogg, dst)
        os.remove(tmp_wav)
        print("[OK] %s ← %s" % (slot, os.path.basename(src)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
