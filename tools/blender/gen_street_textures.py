"""거리(지상) 텍스처 생성 (Blender 백그라운드에서 실행).

사용법:
  blender --background --python tools/blender/gen_street_textures.py -- <출력 폴더>
"""
import os
import sys

import bpy
import numpy as np

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(OUT, exist_ok=True)


def spectral(n, beta, fmin=1.0, fmax=None, seed=0, shape=None):
    rng = np.random.default_rng(seed)
    h, w = shape if shape else (n, n)
    ky = np.fft.fftfreq(h) * h
    kx = np.fft.rfftfreq(w) * w
    k = np.sqrt(ky[:, None] ** 2 + kx[None, :] ** 2)
    amp = np.zeros_like(k)
    m = k >= fmin
    if fmax is not None:
        m &= k <= fmax
    amp[m] = k[m] ** (-beta / 2.0)
    spec = amp * np.exp(1j * rng.uniform(0, 2 * np.pi, k.shape))
    img = np.fft.irfft2(spec, s=(h, w))
    return (img - img.mean()) / (img.std() + 1e-9)


def norm01(x):
    return (x - x.min()) / (x.max() - x.min() + 1e-9)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nrm = np.stack([-dx * strength, dy * strength, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    return nrm * 0.5 + 0.5


def save(name, arr):
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


# ---------------------------------------------------------------- 보도블록 (2 m, 512 px)
# 20 x 10 cm 벽돌형 블록, 반장씩 엇갈려 깔기. 블록마다 색이 조금씩 다르고, 줄눈에 때가 끼어 있다.

def pavers():
    n = 512
    px = n / 2.0                       # px per m
    bw, bh = 0.2 * px, 0.1 * px        # 블록 크기 (px)
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    row = np.floor(yy / bh)
    xs = xx + (row % 2) * bw * 0.5
    col = np.floor(xs / bw)
    fx = (xs % bw) / bw
    fy = (yy % bh) / bh
    edge = np.minimum(np.minimum(fx, 1 - fx) * bw, np.minimum(fy, 1 - fy) * bh)
    joint = 1.0 - smoothstep(0.6, 2.2, edge)
    bevel = 1.0 - smoothstep(0.0, 4.0, edge)
    rng = np.random.default_rng(3)
    block_id = (col.astype(int) * 7919 + row.astype(int) * 104729) % 10007
    tint = rng.uniform(-1, 1, 10007)[block_id]
    hue = rng.choice([0, 0, 0, 1], 10007)[block_id]      # 가끔 붉은 블록
    fine = spectral(n, 1.0, 40, None, seed=4)
    low = spectral(n, 3.0, 1, 10, seed=5)
    base = np.where(hue[..., None] == 1, srgb("8A6A60")[None, None, :], srgb("8C8C88")[None, None, :])
    lum = 1.0 + 0.09 * tint + 0.05 * fine + 0.08 * low - 0.55 * joint
    col_img = base * lum[..., None]
    save("pavers_albedo", col_img)
    save("pavers_rough", np.clip(0.78 + 0.08 * fine - 0.25 * smoothstep(0.4, 1.4, low) * (1 - joint), 0, 1))
    height = -joint * 1.2 - bevel * 0.4 + 0.15 * fine
    save("pavers_normal", normal_from_height(height, 1.2))


# ---------------------------------------------------------------- 자판기 앞판 (512 x 1024)
# 위쪽 2/3: 음료 진열칸(밝게 빛남), 아래: 버튼과 꺼내는 곳(어둡게)

def vending_front():
    w, h = 512, 1024
    img = np.zeros((h, w, 3)) + srgb("dfe6ea")
    rng = np.random.default_rng(11)
    colors = ["c8473f", "2f6fc0", "e3c23b", "3a9a5a", "e0561e", "ffffff", "8a3fa8", "1a1a1a", "d94f8a"]
    rows, cols = 5, 7
    top, bottom = 40, 640
    cell_h = (bottom - top) / rows
    cell_w = (w - 40) / cols
    for r in range(rows):
        for c in range(cols):
            x0 = int(20 + c * cell_w + 8)
            x1 = int(20 + (c + 1) * cell_w - 8)
            y0 = int(top + r * cell_h + 10)
            y1 = int(top + (r + 1) * cell_h - 34)
            can = srgb(rng.choice(colors))
            img[y0:y1, x0:x1] = can
            # 캔의 반사 줄
            hl = x0 + (x1 - x0) // 3
            img[y0:y1, hl:hl + 4] = np.minimum(can + 0.35, 1.0)
            # 가격 표 + 버튼
            img[y1 + 6:y1 + 18, x0:x1] = srgb("2a2a2a")
            img[y1 + 20:y1 + 28, x0 + 6:x1 - 6] = srgb("ff4040") if rng.random() < 0.2 else srgb("5cff7a")
        img[int(top + (r + 1) * cell_h - 8):int(top + (r + 1) * cell_h - 4), 20:w - 20] = srgb("9aa3a8")
    # 아래 패널
    img[660:, :] = srgb("1d2023")
    img[700:760, 330:470] = srgb("0a0a0a")          # 지폐 투입구 주변
    img[860:960, 60:452] = srgb("0b0c0d")           # 꺼내는 곳
    img[780:800, 360:380] = srgb("e3c23b")          # 동전 투입구
    save("vending_front", img)


# ---------------------------------------------------------------- 아파트 창문 (밤, 1024 x 1024 = 30 m x 30 m)
# 층 높이 3 m, 창 폭 2.5 m. 대부분 꺼져 있고 일부만 켜져 있다 (따뜻한 빛, 형광등 빛, TV 빛).

def apartment_windows():
    n = 1024
    px = n / 30.0
    img = np.zeros((n, n, 3)) + srgb("23262a")
    emit = np.zeros((n, n, 3))
    rng = np.random.default_rng(21)
    floors, bays = 10, 12
    for f in range(floors):
        for b in range(bays):
            x0 = int(b * 2.5 * px + 0.25 * px)
            x1 = int((b + 1) * 2.5 * px - 0.25 * px)
            y0 = int(f * 3.0 * px + 0.8 * px)
            y1 = int(f * 3.0 * px + 2.4 * px)
            img[y0:y1, x0:x1] = srgb("0e1013")
            roll = rng.random()
            if roll < 0.16:
                c = srgb(rng.choice(["ffd8a0", "ffe3b8", "f0f4ff", "c8d8ff", "ffcf88"]))
                k = rng.uniform(0.5, 1.0)
                emit[y0:y1, x0:x1] = c * k
                # 커튼
                if rng.random() < 0.5:
                    cx = int(x0 + (x1 - x0) * rng.uniform(0.3, 0.7))
                    emit[y0:y1, cx:x1] *= 0.35
            elif roll < 0.2:
                emit[y0:y1, x0:x1] = srgb("6b8cff") * 0.35   # TV 빛
            # 난간
            img[y1:y1 + 3, x0 - 6:x1 + 6] = srgb("5a5e60")
        img[int(f * 3.0 * px):int(f * 3.0 * px) + 4, :] = srgb("33373b")
    save("apartment_albedo", img)
    save("apartment_emission", emit)


# ---------------------------------------------------------------- 맨홀 뚜껑 (512, 알파)

def manhole():
    n = 512
    yy, xx = (np.mgrid[0:n, 0:n] / n - 0.5) * 2
    r = np.sqrt(xx ** 2 + yy ** 2)
    alpha = 1.0 - smoothstep(0.9, 0.93, r)
    ring = smoothstep(0.82, 0.84, r) * (1 - smoothstep(0.88, 0.9, r))
    grid = ((np.floor((xx + yy) * 9) + np.floor((xx - yy) * 9)) % 2) * (r < 0.78)
    rust = norm01(spectral(n, 2.0, 2, 60, seed=31))
    col = srgb("2a2826")[None, None, :] * (0.8 + 0.4 * rust[..., None])
    col = col * (1 - 0.35 * grid[..., None]) + 0.12 * ring[..., None]
    col[..., 0] += 0.05 * smoothstep(0.6, 0.9, rust)
    save("manhole", np.concatenate([col, alpha[..., None]], -1))


# ---------------------------------------------------------------- 빗물받이 덮개 (512 x 256, 알파)

def drain():
    w, h = 512, 256
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    slots = ((xx % 32) > 8) * (yy > 20) * (yy < h - 20) * (xx > 16) * (xx < w - 16)
    col = np.zeros((h, w, 3)) + srgb("3a3835")
    col[slots > 0] = srgb("050505")
    save("drain", np.concatenate([col, np.ones((h, w, 1))], -1))


pavers()
vending_front()
apartment_windows()
manhole()
drain()
print("STREET TEXTURES DONE")
