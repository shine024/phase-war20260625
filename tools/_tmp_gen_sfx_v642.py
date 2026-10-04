#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6.42 记录6：音频四项重制——开场风声/按钮/胜利/武器力度分级。

实机主诉（2026-10-04）："刚开始剧情背景音不好 / 按钮音不好 / 胜利时音效不好 /
武器音效不好，没区分力和力度"。

产出：
  - button.ogg        柔和 UI 短嗒（原合成器 blip 偏硬偏高频）
  - win.ogg           短号角式凯旋琶音（原 0.5s 扫频单音太弱）
  - cannon_fire.ogg   新增：重炮档开火（力度分级 tier2/3 直射）
  - impact_light.ogg  新增：轻档命中（tier0/1）
  - impact_heavy.ogg  新增：重档命中（tier3）
  - explosion_big.ogg 新增：大当量爆炸（曲射 HEAVY/NUCLEAR 落地）
  - ambient_wakeup_wind.wav 新增：苏醒演出专用雪原风声（柔化风+低鸣，无缝循环；
                      与战斗 ambient_battle_wind 分离，战斗氛围不受影响）

铁律：*.ogg/*.wav 不入 git——旧素材已备份
D:/godotplay/_art_backup/sfx_pre_v642_20261004/。
用法：python tools/_tmp_gen_sfx_v642.py [--out assets/sfx] [--only button,win]
"""
import argparse
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
FFMPEG_CANDIDATES = [
    r"D:/360安全浏览器下载/铁血联盟3/Godot/ffmpeg-8.0-essentials_build/ffmpeg-8.0-essentials_build/bin/ffmpeg.exe",
    "ffmpeg",
]


def ffmpeg_bin() -> str:
    for c in FFMPEG_CANDIDATES:
        try:
            subprocess.run([c, "-version"], capture_output=True, timeout=10)
            return c
        except Exception:
            continue
    raise SystemExit("ffmpeg not found")


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env_ad(n: int, attack: float = 0.005, decay_pow: float = 3.0) -> np.ndarray:
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    e[a:] = np.exp(-decay_pow * np.linspace(0.0, 1.0, n - a) * 6.0)
    return e


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = 1.0 / (1.0 + (f / max(cutoff, 1.0)) ** 2)
    return np.fft.irfft(X * H, n=len(x))


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = (f / np.maximum(f, 1.0)) ** 2 / (1.0 + (cutoff / np.maximum(f, 1.0)) ** 4)
    return np.fft.irfft(X * H, n=len(x))


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4) * 1.0 / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(X * H, n=len(x))


def sweep(f0: float, f1: float, dur: float) -> np.ndarray:
    tt = t(dur)
    f = np.linspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def normalize(x: np.ndarray, peak: float = 0.72) -> np.ndarray:
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-9 else x


def softclip(x: np.ndarray, drive: float = 1.2) -> np.ndarray:
    return np.tanh(x * drive)


def noise(n: int, seed: int = 20261004) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, n)


def save_ogg(name: str, x: np.ndarray, out_dir: str, ff: str) -> None:
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wav_path = tf.name
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


def save_wav(name: str, x: np.ndarray, out_dir: str) -> None:
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype(np.int16)
    dst = os.path.join(out_dir, name + ".wav")
    with wave.open(dst, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", dst)


# ── 音效配方 ──────────────────────────────────────────────

def s_button() -> np.ndarray:
    """柔和 UI 短嗒：2ms 咔哒(高通噪声) + 1450Hz 软正弦衰减，整体温和不刺耳。"""
    dur = 0.07
    n = int(SR * dur)
    click = highpass(noise(n, 11), 1800) * env_ad(n, 0.0005, 8.0) * 0.45
    ping = np.sin(2 * np.pi * 1450 * t(dur)) * env_ad(n, 0.001, 5.0) * 0.5
    ping2 = np.sin(2 * np.pi * 2180 * t(dur)) * env_ad(n, 0.001, 6.5) * 0.18
    x = lowpass(click + ping + ping2, 5200)
    return normalize(x, 0.42)


def _tone(f: float, dur: float, bright: float = 0.25) -> np.ndarray:
    """软号角单音：正弦基频 + 弱方波泛音，attack 12ms。"""
    n = int(SR * dur)
    base = np.sin(2 * np.pi * f * t(dur))
    sq = np.sign(np.sin(2 * np.pi * f * t(dur))) * bright
    oct2 = np.sin(2 * np.pi * f * 2 * t(dur)) * 0.18
    x = lowpass(base + sq + oct2, f * 6)
    return x * env_ad(n, 0.012, 1.9)


def s_win() -> np.ndarray:
    """凯旋琶音：C5-E5-G5 上行 + C6 长音收束 + 底部暖 pad，~1.8s。"""
    out = np.zeros(int(SR * 1.9))
    seq = [(523.25, 0.00, 0.42), (659.25, 0.13, 0.42), (783.99, 0.26, 0.42)]
    for f, st, dur in seq:
        tone = _tone(f, dur)
        s = int(SR * st)
        out[s:s + len(tone)] += tone * 0.55
    # 终止长音：C 大三和弦（C5/E5/G5/C6）渐强再收
    chord_dur = 1.35
    n = int(SR * chord_dur)
    chord = (np.sin(2 * np.pi * 523.25 * t(chord_dur)) * 0.5
             + np.sin(2 * np.pi * 659.25 * t(chord_dur)) * 0.38
             + np.sin(2 * np.pi * 783.99 * t(chord_dur)) * 0.34
             + np.sin(2 * np.pi * 1046.5 * t(chord_dur)) * 0.3)
    chord += np.sin(2 * np.pi * 1046.5 * 2 * t(chord_dur)) * 0.06  # 一丝亮泽
    swell = np.concatenate([np.linspace(0.4, 1.0, int(n * 0.25)),
                            np.exp(-2.2 * np.linspace(0, 1, n - int(n * 0.25)) ** 1.0)])
    chord *= swell
    s = int(SR * 0.36)
    out[s:s + n] += lowpass(chord, 4200) * 0.62
    # 底部暖 pad（130.8Hz C3）铺底
    pad = np.sin(2 * np.pi * 130.81 * t(1.7)) * env_ad(int(SR * 1.7), 0.25, 1.2) * 0.22
    out[:len(pad)] += pad
    return normalize(softclip(out, 1.05), 0.58)


def s_cannon_fire() -> np.ndarray:
    """重炮档开火：低频体腔(110→40Hz) + 中频推进(260→90Hz) + 短促高频崩 + 尾部闷响。"""
    dur = 0.55
    n = int(SR * dur)
    body = sweep(110, 40, dur) * env_ad(n, 0.002, 3.0) * 1.0
    mid = sweep(260, 90, dur) * env_ad(n, 0.002, 4.2) * 0.5
    crack = bandpass(noise(n, 21), 800, 4200) * env_ad(n, 0.001, 8.0) * 0.7
    tail = lowpass(noise(n, 22), 500) * env_ad(n, 0.01, 2.2) * 0.5
    x = softclip(body + mid + crack + tail, 1.25)
    return normalize(x, 0.76)


def s_impact_light() -> np.ndarray:
    """轻档命中：短促金属嗒 + 小闷点，干净不拖泥。"""
    dur = 0.12
    n = int(SR * dur)
    tick = bandpass(noise(n, 31), 2200, 7000) * env_ad(n, 0.0008, 7.5) * 0.55
    thud = sweep(380, 160, dur) * env_ad(n, 0.001, 5.0) * 0.7
    return normalize(softclip(tick + thud, 1.15), 0.5)


def s_impact_heavy() -> np.ndarray:
    """重档命中：深砸(150→45Hz) + 低频碎屑 + 金属残响，明显比 generic 沉。"""
    dur = 0.5
    n = int(SR * dur)
    thud = sweep(150, 45, dur) * env_ad(n, 0.002, 3.4) * 1.0
    debris = bandpass(noise(n, 41), 700, 3200) * env_ad(n, 0.002, 5.5) * 0.4
    body = lowpass(noise(n, 42), 620) * env_ad(n, 0.002, 4.0) * 0.55
    clank = np.sin(2 * np.pi * 620 * t(dur)) * env_ad(n, 0.001, 6.0) * 0.10
    return normalize(softclip(thud + debris + body + clank, 1.2), 0.68)


def s_explosion_big() -> np.ndarray:
    """大当量爆炸：初裂 + 宽频轰 + 低频长尾（explosion 的 1.6 倍时长、更深的 sub）。"""
    dur = 1.7
    n = int(SR * dur)
    body = lowpass(noise(n, 51), 850) * env_ad(n, 0.004, 2.0)
    sub = sweep(62, 22, dur) * env_ad(n, 0.002, 2.2) * 1.15
    crack_n = int(SR * 0.09)
    crack = noise(crack_n, 52) * env_ad(crack_n, 0.001, 5.5) * 0.9
    body[:crack_n] += crack
    rumble = lowpass(noise(n, 53), 130) * env_ad(n, 0.06, 0.9) * 0.75
    x = softclip(body * 0.85 + sub * 0.9 + rumble * 0.7, 1.1)
    return normalize(x, 0.85)


def s_wakeup_wind() -> np.ndarray:
    """苏醒演出雪原风声（12s 无缝循环）：柔化风体 + 阵风呼吸 + 高频耳语 + 极低暖鸣。"""
    dur = 12.0
    n = int(SR * dur)
    # 风体：低通噪声 + 双 LFO 阵风（不同周期叠加，避免机械感）
    wind = lowpass(noise(n, 61), 480)
    lfo = (0.62 + 0.24 * np.sin(2 * np.pi * t(dur) / 5.3 + 0.7)
           + 0.14 * np.sin(2 * np.pi * t(dur) / 2.1 + 2.1))
    wind *= lfo
    # 高频耳语：带通噪声，随阵风反向轻摆（风尖呼啸）
    whisper = bandpass(noise(n, 62), 1400, 3400) * (1.15 - 0.45 * lfo) * 0.16
    # 极低暖鸣：55Hz 双音微差拍（冰原空旷感），音量很低
    drone = (np.sin(2 * np.pi * 55.0 * t(dur)) + np.sin(2 * np.pi * 55.35 * t(dur))) * 0.05
    drone *= 0.6 + 0.4 * np.sin(2 * np.pi * t(dur) / 7.9)
    x = wind * 0.6 + whisper + drone
    # 无缝循环：尾段 0.8s 与首段 0.8s 交叉淡化
    fade_n = int(SR * 0.8)
    fade_out = np.linspace(1.0, 0.0, fade_n)
    fade_in = np.linspace(0.0, 1.0, fade_n)
    tail = x[-fade_n:].copy()
    x[-fade_n:] = tail * fade_out + x[:fade_n] * fade_in
    return normalize(x, 0.52)


RECIPES = {
    "button": s_button,
    "win": s_win,
    "cannon_fire": s_cannon_fire,
    "impact_light": s_impact_light,
    "impact_heavy": s_impact_heavy,
    "explosion_big": s_explosion_big,
}
WAV_RECIPES = {
    "ambient_wakeup_wind": s_wakeup_wind,
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
    for name, fn in WAV_RECIPES.items():
        if only and name not in only:
            continue
        save_wav(name, fn(), out_dir)


if __name__ == "__main__":
    main()
