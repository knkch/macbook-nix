# 走る猫のシルエット（RunCat 風・オリジナルの絵）を 5 コマ描いて PNG にする
# 使い方: python3 gen.py <出力ディレクトリ>
import os
import sys

from PIL import Image

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

W, H = 22, 12
SCALE = 4
FG = (192, 202, 245, 255)  # バーの文字色に合わせる

# 足: (付け根の x, 先の x のずれ) × 4 本（後ろ足 2 本・前足 2 本）、体の上下、しっぽの高さ
FRAMES = [
    {"legs": [(7, -3), (8, -2), (13, 3), (14, 2)], "bob": 0, "tail": 0},  # 伸びきる
    {"legs": [(7, -1), (8, 0), (13, 1), (14, 0)], "bob": 0, "tail": 1},
    {"legs": [(7, 2), (8, 3), (13, -2), (14, -1)], "bob": 1, "tail": 2},  # 縮む
    {"legs": [(7, 1), (8, 2), (13, -1), (14, 0)], "bob": 1, "tail": 1},
    {"legs": [(7, -2), (8, -1), (13, 2), (14, 1)], "bob": 0, "tail": 0},
]


def put(px, x, y):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = FG


for n, fr in enumerate(FRAMES):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    b = fr["bob"]

    # 体
    for x in range(6, 16):
        for y in range(4 + b, 8 + b):
            put(px, x, y)
    put(px, 6, 4 + b); px[6, 4 + b] = (0, 0, 0, 0)  # 角を丸める
    # 頭と耳
    for x in range(15, 20):
        for y in range(2 + b, 7 + b):
            put(px, x, y)
    put(px, 16, 1 + b); put(px, 19, 1 + b)
    px[19, 6 + b] = (0, 0, 0, 0)
    put(px, 20, 4 + b)  # 鼻先
    # しっぽ
    t = fr["tail"]
    for i, (x, y) in enumerate([(5, 4), (4, 3), (3, 2), (2, 1)]):
        put(px, x, y + b + (t if i >= 2 else 0) - (1 if t == 2 and i == 3 else 0))
    # 足（付け根 y=8 から 3 ドット）
    for root, dx in fr["legs"]:
        for k in range(3):
            put(px, root + round(dx * (k + 1) / 3), 8 + b + k)

    img.resize((W * SCALE, H * SCALE), Image.NEAREST).save(os.path.join(OUT, f"frame-{n}.png"))
