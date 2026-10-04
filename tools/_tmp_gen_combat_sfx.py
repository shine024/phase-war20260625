#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6.38 记录5#2/#3：战斗音效重制——程序合成替换 0.15~0.4s 玩具级短促音。

实机主诉："大招（核武轰炸）没有音效"（0.2s pop 在齐射重触发里消失）+
"战斗音效像小蜜蜂游戏太差了"（全部音效是合成器 blip 级素材）。

本脚本用 numpy 合成 44.1kHz 单声道战斗音效 → WAV → ffmpeg 编码 ogg 覆写
assets/sfx/<name>.ogg。自产素材零授权问题（credits 页无需追加条目）。

铁律：*.ogg 不入 git——旧素材已备份 D:/godotplay/_art_backup/sfx_toy_blips_20261002/。
用法：python tools/_tmp_gen_combat_sfx.py [--out assets/sfx]
"""
import argparse
import os
import subprocess
import tempfile

import numpy as np

SR = 44100
FFMPEG_CANDIDATES = [
    r"D:/360安全浏览器下载/铁血联盟3/Godot/ffmpeg-8.0-essentials_build/ffmpeg-8.0-essentials_build/bin/ffmpeg.exe",
    "ffmpeg",
]


def ffmpeg_bin() -> str:
    for c in FFMPEG_CANDIDATES:
        if os.path.isfile(c) or os.environ.get("PATH", ""):
            try:
                subprocess.run([c, "-version"], capture_output=True, timeout=10)
                return c
            except Exception:
                continue
    raise SystemExit("ffmpeg not found")


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env_ad(n: int, attack: float = 0.005, decay_pow: float = 3.0) -> np.ndarray:
    """attack 秒线性起音 + 幂衰减包络。"""
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    e[a:] = np.exp(-decay_pow * np.linspace(0.0, 1.0, n - a) * 6.0)
    return e


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """FFT 域单极 lowpass（够用，免 scipy）。"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = 1.0 / (1.0 + (f / max(cutoff, 1.0)) ** 2)
    return np.fft.irfft(X * H, n=len(x))


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4) * 1.0 / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(X * H, n=len(x))


def sweep(f0: float, f1: float, dur: float, phase_acc: bool = True) -> np.ndarray:
    """频率线性扫频正弦。"""
    tt = t(dur)
    f = np.linspace(f0, f1, len(tt))
    if phase_acc:
        ph = 2 * np.pi * np.cumsum(f) / SR
    else:
        ph = 2 * np.pi * f * tt
    return np.sin(ph)


def normalize(x: np.ndarray, peak: float = 0.72) -> np.ndarray:
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-9 else x


def softclip(x: np.ndarray, drive: float = 1.2) -> np.ndarray:
    return np.tanh(x * drive)


def save_ogg(name: str, x: np.ndarray, out_dir: str, ff: str) -> None:
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wav_path = tf.name
    import wave
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(out_dir, name + ".ogg")
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.unlink(wav_path)
    print("wrote", dst)


def noise(n: int) -> np.ndarray:
    return np.random.default_rng(20261002).uniform(-1.0, 1.0, n)


# ── 音效配方 ──────────────────────────────────────────────

def s_explosion(big: bool = False) -> np.ndarray:
    dur = 1.5 if big else 1.1
    n = int(SR * dur)
    body = lowpass(noise(n), 900 if big else 1400) * env_ad(n, 0.004, 2.2)
    sub = sweep(72 if big else 95, 26 if big else 38, dur) * env_ad(n, 0.002, 2.8) * 1.1
    crack_n = int(SR * 0.08)
    crack = noise(crack_n) * env_ad(crack_n, 0.001, 6.0) * 0.8
    body[:crack_n] += crack
    x = softclip(body * 0.9 + sub * 0.8, 1.1)
    return normalize(x, 0.8 if big else 0.75)


def s_base_destroy() -> np.ndarray:
    n = int(SR * 1.9)
    body = lowpass(noise(n), 700) * env_ad(n, 0.004, 1.6)
    sub = sweep(58, 20, 1.9) * env_ad(n, 0.002, 1.8) * 1.2
    rumble = lowpass(noise(n), 140) * env_ad(n, 0.05, 1.0) * 0.7
    x = softclip(body * 0.9 + sub * 0.9 + rumble * 0.6, 1.1)
    return normalize(x, 0.82)


def s_boss_warn() -> np.ndarray:
    """警报双音号角（0.3s×3 循环），战斗内穿透力优先中频。"""
    seg = 0.30
    n = int(SR * seg)
    out = np.zeros(int(SR * 1.0))
    for i in range(3):
        f = 540 if i % 2 == 0 else 400
        tone = np.sign(np.sin(2 * np.pi * f * t(seg))) * 0.3 + np.sin(2 * np.pi * f * t(seg)) * 0.7
        tone = lowpass(tone, 2000) * env_ad(n, 0.02, 2.0)
        s = int(SR * seg * i)
        out[s:s + n] += tone * 0.9
    return normalize(out, 0.62)


def s_master_appear() -> np.ndarray:
    dur = 1.1
    n = int(SR * dur)
    drone = sum(np.sin(2 * np.pi * f * t(dur) + i) for i, f in enumerate([110, 112.5, 165]))
    shimmer = sweep(900, 1400, dur) * 0.12
    x = (lowpass(drone, 900) * 0.5 + shimmer) * env_ad(n, 0.15, 2.0)
    return normalize(x, 0.6)


def s_rocket_launch() -> np.ndarray:
    dur = 0.75
    n = int(SR * dur)
    whoosh = bandpass(noise(n), 350, 3200) * env_ad(n, 0.10, 2.4)
    rumble = lowpass(noise(n), 200) * env_ad(n, 0.02, 2.0) * 0.8
    x = whoosh * 0.85 + rumble * 0.6
    return normalize(x, 0.66)


def s_missile_hum() -> np.ndarray:
    dur = 0.8
    carrier = np.sin(2 * np.pi * 92 * t(dur) + 3.0 * np.sin(2 * np.pi * 5.2 * t(dur)))
    x = lowpass(carrier, 800) * env_ad(int(SR * dur), 0.08, 1.6)
    return normalize(x, 0.42)


def _gun(dur: float, body_f: float, bright: float, tail: float = 3.5, dbl: bool = False) -> np.ndarray:
    n = int(SR * dur)
    crack = bandpass(noise(n), 1200, 9000) * env_ad(n, 0.001, 7.0) * (0.5 + bright)
    body = sweep(body_f * 1.4, body_f * 0.6, dur) * env_ad(n, 0.001, 5.0) * 0.8
    boom = lowpass(noise(n), 600) * env_ad(n, 0.001, 4.0) * 0.5
    x = softclip(crack * bright + body + boom, 1.3)
    if dbl:  # 机枪机械双击感
        d = int(SR * 0.022)
        x[d:] += x[:-d] * 0.35
    _ = tail
    return normalize(x, 0.68)


def s_gun_sniper() -> np.ndarray:
    x = _gun(0.4, 130, 1.15)
    n = len(x)
    d = int(SR * 0.12)
    echo = np.zeros(n)
    echo[d:] = x[:-d] * 0.3
    d2 = int(SR * 0.28)
    echo[d2:] += x[:-d2] * 0.15
    return normalize(x + echo, 0.72)


def s_gun_shotgun() -> np.ndarray:
    dur = 0.32
    n = int(SR * dur)
    spread = bandpass(noise(n), 300, 5000) * env_ad(n, 0.002, 4.0)
    boom = sweep(150, 55, dur) * env_ad(n, 0.002, 3.2) * 0.9
    return normalize(softclip(spread * 0.8 + boom, 1.25), 0.74)


def s_flak_fire() -> np.ndarray:
    dur = 0.22
    n = int(SR * dur)
    hollow = bandpass(noise(n), 260, 1500) * env_ad(n, 0.002, 4.5)
    thump = sweep(190, 70, dur) * env_ad(n, 0.002, 4.0) * 0.8
    return normalize(softclip(hollow * 0.9 + thump, 1.2), 0.68)


def s_laser_fire() -> np.ndarray:
    dur = 0.32
    carrier = sweep(2300, 320, dur)
    fm = np.sin(2 * np.pi * 38 * t(dur)) * 0.25
    shimmer = sweep(4600, 640, dur) * 0.2
    x = (carrier * (1.0 + fm) + shimmer) * env_ad(int(SR * dur), 0.004, 3.2)
    return normalize(softclip(x, 1.1), 0.55)


def s_rail_cannon() -> np.ndarray:
    dur = 0.8
    n = int(SR * dur)
    em = sweep(48, 90, 0.06).tolist()[-1:]  # noqa: F841
    slap = bandpass(noise(n), 500, 6000) * env_ad(n, 0.001, 6.0) * 0.9
    sub = sweep(96, 30, dur) * env_ad(n, 0.002, 2.6) * 1.0
    ring = np.sin(2 * np.pi * 1750 * t(dur)) * env_ad(n, 0.001, 5.0) * 0.12
    x = softclip(slap + sub + ring, 1.15)
    return normalize(x, 0.74)


def s_omega_cannon() -> np.ndarray:
    dur = 1.2
    n = int(SR * dur)
    sub = sweep(64, 22, dur) * env_ad(n, 0.003, 2.0) * 1.1
    roar = lowpass(noise(n), 1100) * env_ad(n, 0.003, 2.4) * 0.9
    ring = np.sin(2 * np.pi * 2400 * t(dur)) * env_ad(n, 0.001, 6.0) * 0.10
    return normalize(softclip(sub + roar + ring, 1.15), 0.8)


def s_impact_generic() -> np.ndarray:
    dur = 0.28
    n = int(SR * dur)
    thud = sweep(220, 70, dur) * env_ad(n, 0.002, 4.0)
    debris = bandpass(noise(n), 900, 5000) * env_ad(n, 0.002, 5.0) * 0.5
    return normalize(softclip(thud + debris, 1.2), 0.6)


def s_hit() -> np.ndarray:
    dur = 0.16
    n = int(SR * dur)
    x = sweep(320, 110, dur) * env_ad(n, 0.001, 4.5) * 0.8
    x += bandpass(noise(n), 700, 3800) * env_ad(n, 0.001, 6.0) * 0.5
    return normalize(x, 0.52)


def s_hurt() -> np.ndarray:
    dur = 0.26
    n = int(SR * dur)
    x = sweep(300, 140, dur) * env_ad(n, 0.002, 4.0)
    x += lowpass(noise(n), 900) * env_ad(n, 0.002, 5.0) * 0.4
    return normalize(x, 0.55)


def s_cast() -> np.ndarray:
    dur = 0.5
    x = sweep(620, 1900, dur) * 0.8 + sweep(1240, 3800, dur) * 0.25
    x *= env_ad(int(SR * dur), 0.05, 2.4)
    return normalize(x, 0.45)


def s_wave_start() -> np.ndarray:
    out = np.zeros(int(SR * 0.7))
    for i, f in enumerate([330, 440]):
        seg = 0.22
        tone = lowpass(np.sign(np.sin(2 * np.pi * f * t(seg))) * 0.4
                       + np.sin(2 * np.pi * f * t(seg)) * 0.6, 1800)
        tone *= env_ad(int(SR * seg), 0.02, 2.2)
        s = int(SR * 0.24 * i)
        out[s:s + len(tone)] += tone
    return normalize(out, 0.5)


def s_unit_death() -> np.ndarray:
    x = s_explosion() * 0.8
    n = len(x)
    clank = np.sin(2 * np.pi * 1300 * t(n / SR)) * env_ad(n, 0.001, 7.0) * 0.08
    return normalize(x + clank, 0.6)


def s_ultimate_ready() -> np.ndarray:
    out = np.zeros(int(SR * 0.45))
    for i, f in enumerate([880, 1320]):
        seg = 0.16
        tone = np.sin(2 * np.pi * f * t(seg)) * env_ad(int(SR * seg), 0.01, 2.6)
        s = int(SR * 0.17 * i)
        out[s:s + len(tone)] += tone * 0.6
    return normalize(out, 0.42)


def s_return_base() -> np.ndarray:
    """v6.38 记录5#5：回基地转场音——柔和下降 whoosh + 软着陆双击（替代生硬 button 短促音）。"""
    dur = 0.65
    n = int(SR * dur)
    whoosh = bandpass(noise(n), 220, 1600) * env_ad(n, 0.12, 2.2) * 0.8
    tone = sweep(520, 210, dur) * env_ad(n, 0.10, 2.6) * 0.35
    land_n = int(SR * 0.10)
    land = sweep(180, 90, 0.10) * env_ad(land_n, 0.004, 4.5) * 0.7
    x = whoosh + tone
    s = n - land_n
    x[s:] += land
    return normalize(x, 0.5)


RECIPES = {
    "explosion": lambda: s_explosion(False),
    "base_destroy": s_base_destroy,
    "boss_warn": s_boss_warn,
    "master_appear": s_master_appear,
    "rocket_launch": s_rocket_launch,
    "missile_hum": s_missile_hum,
    "shoot": lambda: _gun(0.17, 190, 0.95),
    "hit": s_hit,
    "hurt": s_hurt,
    "gun_pistol": lambda: _gun(0.13, 230, 1.15),
    "gun_smg": lambda: _gun(0.09, 210, 1.0, dbl=True),
    "gun_rifle": lambda: _gun(0.15, 175, 1.1),
    "gun_mg": lambda: _gun(0.12, 140, 0.85, dbl=True),
    "gun_shotgun": s_gun_shotgun,
    "gun_sniper": s_gun_sniper,
    "flak_fire": s_flak_fire,
    "laser_fire": s_laser_fire,
    "rail_cannon": s_rail_cannon,
    "omega_cannon": s_omega_cannon,
    "impact_generic": s_impact_generic,
    "cast": s_cast,
    "wave_start": s_wave_start,
    "unit_death": s_unit_death,
    "ultimate_ready": s_ultimate_ready,
    "return_base": s_return_base,
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "assets", "sfx"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    ff = ffmpeg_bin()
    out_dir = os.path.abspath(args.out)
    only = set(args.only.split(",")) if args.only else None
    for name, fn in RECIPES.items():
        if only and name not in only:
            continue
        save_ogg(name, fn(), out_dir, ff)


if __name__ == "__main__":
    main()
