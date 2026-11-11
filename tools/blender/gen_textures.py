"""주차장 텍스처 생성 (Blender 백그라운드에서 실행).

사용법:
  blender --background --python tools/blender/gen_textures.py -- <출력 폴더>

모든 텍스처는 주파수 공간에서 만든 노이즈라서 가장자리가 완벽하게 이어진다(타일링).
"""
import os
import sys

import bpy
import numpy as np

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])  # 상대 경로는 Blender가 다르게 해석한다
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------- 노이즈 도구

def spectral(n, beta, fmin=1.0, fmax=None, seed=0, aspect=1.0):
    """가장자리가 이어지는 1/f^beta 노이즈. 평균 0, 표준편차 1.
    aspect > 1 이면 세로로 길게 늘어난 무늬(흘러내린 자국)가 된다."""
    rng = np.random.default_rng(seed)
    kx = np.fft.fftfreq(n) * n
    ky = np.fft.rfftfreq(n) * n
    k = np.sqrt((kx[:, None] * aspect) ** 2 + (ky[None, :] / aspect) ** 2)
    amp = np.zeros_like(k)
    m = k >= fmin
    if fmax is not None:
        m &= k <= fmax
    amp[m] = k[m] ** (-beta / 2.0)
    spec = amp * np.exp(1j * rng.uniform(0, 2 * np.pi, k.shape))
    img = np.fft.irfft2(spec, s=(n, n))
    return (img - img.mean()) / (img.std() + 1e-9)


def norm01(x):
    return (x - x.min()) / (x.max() - x.min() + 1e-9)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def normal_from_height(h, strength):
    """OpenGL 방식(초록이 위) 노멀맵. Godot과 같은 방식."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nrm = np.stack([-dx * strength, dy * strength, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    return nrm * 0.5 + 0.5


def save(name, arr):
    """arr: (높이, 너비, 3 또는 4), 값 0~1, 첫 행이 이미지 위쪽."""
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    h, w, c = arr.shape
    if c == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1))], -1)
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.alpha_mode = "STRAIGHT"
    img.pixels.foreach_set(np.flipud(np.clip(arr, 0, 1)).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("saved", img.filepath_raw)


def srgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ---------------------------------------------------------------- 바닥 콘크리트 (4 m, 1024 px)

def floor():
    n = 1024
    low = spectral(n, 3.2, 1, 20, seed=1)        # 큰 얼룩
    mid = spectral(n, 2.0, 8, 160, seed=2)       # 중간 얼룩
    fine = spectral(n, 1.0, 120, None, seed=3)   # 표면 입자
    pores = smoothstep(2.4, 3.4, spectral(n, 0.2, 200, None, seed=4))   # 작은 기공
    agg = smoothstep(1.7, 2.6, spectral(n, 1.2, 60, 300, seed=5))       # 골재가 비친 밝은 점
    warm = spectral(n, 3.0, 1, 10, seed=6)

    lum = 1.0 + 0.065 * low + 0.045 * mid + 0.04 * fine - 0.35 * pores + 0.08 * agg
    base = srgb("8A8D88")
    col = base[None, None, :] * lum[..., None]
    col[..., 0] *= 1.0 + 0.01 * warm
    col[..., 2] *= 1.0 - 0.01 * warm
    save("floor_albedo", col)

    rough = 0.80 + 0.05 * mid - 0.05 * low + 0.12 * pores
    save("floor_rough", np.clip(rough, 0, 1))

    height = 0.45 * fine + 0.25 * mid - 2.0 * pores + 0.4 * agg
    save("floor_normal", normal_from_height(height, 0.35))


# ---------------------------------------------------------------- 칠한 벽 (2 m, 512 px)

def wall():
    n = 512
    low = spectral(n, 3.0, 1, 12, seed=11)
    mid = spectral(n, 2.0, 6, 120, seed=12)
    fine = spectral(n, 1.0, 80, None, seed=13)
    bug = smoothstep(2.6, 3.5, spectral(n, 0.3, 100, None, seed=14))   # 거푸집 기포 자국
    lum = 1.0 + 0.03 * low + 0.02 * mid + 0.02 * fine - 0.25 * bug
    col = srgb("E4E3DC")[None, None, :] * lum[..., None]
    save("wall_albedo", col)
    save("wall_rough", np.clip(0.72 + 0.06 * mid + 0.15 * bug, 0, 1))
    save("wall_normal", normal_from_height(0.4 * fine + 0.2 * mid - 1.8 * bug, 0.3))


# ---------------------------------------------------------------- 천장 콘크리트 (2.4 m, 512 px)
# 거푸집 판(1.2 x 0.6 m) 이음매가 보이는 노출 콘크리트

def ceiling():
    n = 512
    px_per_m = n / 2.4
    low = spectral(n, 3.0, 1, 12, seed=21)
    mid = spectral(n, 2.0, 6, 120, seed=22)
    fine = spectral(n, 1.0, 80, None, seed=23)
    yy, xx = np.mgrid[0:n, 0:n]
    pw, ph = 1.2 * px_per_m, 0.6 * px_per_m
    px = (xx / pw) % 1.0
    py = (yy / ph) % 1.0
    edge = np.minimum(np.minimum(px, 1 - px) * pw, np.minimum(py, 1 - py) * ph)  # 이음매까지 거리(px)
    seam = 1.0 - smoothstep(0.0, 2.5, edge)
    rng = np.random.default_rng(24)
    panel_id = (np.floor(xx / pw) + 7 * np.floor(yy / ph)).astype(int)
    panel_tint = rng.uniform(-0.06, 0.06, panel_id.max() + 1)[panel_id]
    lum = 1.0 + 0.08 * low + 0.04 * mid + 0.03 * fine + panel_tint - 0.25 * seam
    col = srgb("9C9E9A")[None, None, :] * lum[..., None]
    save("ceiling_albedo", col)
    save("ceiling_rough", np.clip(0.85 + 0.05 * mid, 0, 1))
    save("ceiling_normal", normal_from_height(0.4 * fine + 0.3 * mid - 1.5 * seam, 0.3))


# ---------------------------------------------------------------- 셰이더용 노이즈 묶음 (1024 px)
# R: 아주 큰 얼룩, G: 중간, B: 잔 노이즈, A: 세로로 흘러내린 자국

def noise_pack():
    n = 1024
    r = norm01(spectral(n, 3.4, 1, 8, seed=31))
    g = norm01(spectral(n, 2.2, 4, 80, seed=32))
    b = norm01(spectral(n, 1.0, 60, None, seed=33))
    a = norm01(spectral(n, 1.6, 2, 200, seed=34, aspect=6.0))
    save("noise_pack", np.stack([r, g, b, a], -1))


# ---------------------------------------------------------------- 데칼

def oil_stain(name, seed):
    n = 512
    yy, xx = np.mgrid[0:n, 0:n] / n - 0.5
    rng = np.random.default_rng(seed)
    blob = np.zeros((n, n))
    for _ in range(5):  # 여러 방울이 겹친 기름 자국
        cx, cy = rng.normal(0, 0.08, 2)
        rad = rng.uniform(0.07, 0.18)
        d = np.sqrt((xx - cx) ** 2 + ((yy - cy) * rng.uniform(0.7, 1.3)) ** 2)
        blob = np.maximum(blob, 1.0 - smoothstep(rad * 0.4, rad, d))
    wobble = spectral(n, 2.0, 4, 60, seed=seed + 1)
    alpha = smoothstep(0.15, 0.6, blob + 0.12 * wobble) * (0.55 + 0.12 * spectral(n, 1.5, 10, 120, seed=seed + 2))
    # 가장자리 근처는 반드시 0 (데칼 경계가 보이지 않게)
    alpha *= 1.0 - smoothstep(0.38, 0.48, np.maximum(abs(xx), abs(yy)))
    col = np.zeros((n, n, 3)) + srgb("1C1914")
    save(name, np.concatenate([col, np.clip(alpha, 0, 0.75)[..., None]], -1))


def tire_marks():
    w, h = 1024, 256
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    rng = np.random.default_rng(41)
    alpha = np.zeros((h, w))
    for center in (0.3, 0.7):           # 두 바퀴
        curve = center + 0.04 * np.sin(u * 2.4 + rng.uniform(0, 3))
        band = 1.0 - smoothstep(0.03, 0.07, abs(v - curve))
        alpha = np.maximum(alpha, band)
    breaks = norm01(spectral(1024, 2.0, 2, 60, seed=42)[:h, :w])
    tread = 0.75 + 0.25 * np.sin(u * 900.0)
    fade = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.7, 1.0, u))
    alpha *= smoothstep(0.35, 0.65, breaks) * tread * fade * 0.5
    col = np.zeros((h, w, 3)) + srgb("15130F")
    save("tire_marks", np.concatenate([col, alpha[..., None]], -1))


def leak_streak():
    w, h = 256, 1024
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h          # v = 0 이 위쪽
    cols = norm01(spectral(1024, 1.4, 4, 120, seed=51, aspect=8.0)[:h, :w])
    drip_len = norm01(spectral(1024, 2.0, 2, 30, seed=52)[:1, :w]).repeat(h, 0)
    alpha = smoothstep(0.45, 0.8, cols) * (1.0 - smoothstep(0.2, 0.25 + 0.7 * drip_len, v))
    alpha *= 1.0 - smoothstep(0.35, 0.5, abs(u - 0.5))
    alpha = np.clip(alpha * 0.55 + (1.0 - smoothstep(0.0, 0.08, v)) * 0.35 * (1 - smoothstep(0.3, 0.5, abs(u - 0.5))), 0, 0.7)
    col = np.zeros((h, w, 3)) + srgb("3A3A2E")
    save("leak_streak", np.concatenate([col, alpha[..., None]], -1))


floor()
wall()
ceiling()
noise_pack()
oil_stain("oil_stain_a", 61)
oil_stain("oil_stain_b", 71)
tire_marks()
leak_streak()
print("TEXTURES DONE")
