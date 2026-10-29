# sketchybar の時計メニューに出すカレンダーを画像で描く
#   使い方: render.py <年> <月> <選択中の日 YYYY-MM-DD（なければ -）> <出力ディレクトリ>
#   出力:   <月送り> <曜日> <1 週目> … <6 週目> の画像のパス（空白区切りで 1 行）
#           <出力ディレクトリ>/dates に、各週の日付（7 個ずつ空白区切り、6 行）
# 日曜・祝日は赤、土曜は青、今日は塗りの丸、選んだ日は輪、予定のある日は右上に件数のバッジ。前後の月の日付は薄く表示する。
# 週ごとに別の画像にするのは、sketchybar 側で週の行を押した位置から日付を割り出すため。
# 祝日はカレンダー「日本の祝日」、予定はそれ以外のカレンダーから icalBuddy で読む。
import calendar
import collections
import datetime
import os
import subprocess
import sys
import time
import unicodedata

from PIL import Image, ImageDraw, ImageFont

YEAR, MONTH, OUTDIR = int(sys.argv[1]), int(sys.argv[2]), sys.argv[4]
SELECTED = sys.argv[3] if sys.argv[3] != "-" else None
S = 2  # Retina 用に 2 倍で描き、sketchybar で 0.5 倍表示する

FG = (192, 202, 245)
SUB = (154, 165, 206)
DIM = (86, 95, 137)
RED = (247, 118, 142)
BLUE = (122, 162, 247)
DARK = (26, 27, 38)
DOT = (158, 206, 106)
BUTTON = (47, 53, 73)

W = 224          # 幅（7 列 × 32）
CW = 32          # 1 マスの幅
HEAD = 22        # 曜日の行の高さ
CH = 26          # 日付の行の高さ
NAV_H = 30       # 月送りの行の高さ
ICAL = "/opt/homebrew/bin/icalBuddy"


def font(weight, size):
    d = "/System/Library/Fonts"
    for f in os.listdir(d):
        n = unicodedata.normalize("NFC", f)
        if "角ゴシック" in n and n.endswith(f"W{weight}.ttc"):
            return ImageFont.truetype(os.path.join(d, f), size * S)
    return ImageFont.load_default()


def event_dates(cal_args, start, end):
    """指定したカレンダーの日ごとの予定の件数（YYYY-MM-DD → 件数）"""
    try:
        out = subprocess.run(
            [ICAL, "-nc", "-nrd", "-b", "", "-iep", "datetime", "-df", "%Y-%m-%d", "-tf", "",
             *cal_args, f"eventsFrom:{start}", f"to:{end}"],
            capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return collections.Counter()
    return collections.Counter(line.strip()[:10] for line in out.splitlines() if line.strip()[:4].isdigit())


def P(*xy):  # 論理座標 → 画像の座標
    return tuple(v * S for v in xy)


today = datetime.date.today()
weeks = calendar.Calendar(firstweekday=6).monthdatescalendar(YEAR, MONTH)  # 日曜始まり
while len(weeks) < 6:  # 高さが月ごとに変わらないよう常に 6 週
    last = weeks[-1][-1]
    weeks.append([last + datetime.timedelta(days=i) for i in range(1, 8)])
start, end = weeks[0][0].isoformat(), weeks[-1][-1].isoformat()
holidays = event_dates(["-ic", "日本の祝日"], start, end)
events = event_dates(["-ec", "日本の祝日"], start, end)

# ── 月送りの行: ‹  2026年10月  › ──
nav = Image.new("RGBA", P(W, NAV_H), (0, 0, 0, 0))
d = ImageDraw.Draw(nav)
for cx, arrow in ((16, "‹"), (W - 16, "›")):
    d.ellipse(P(cx - 11, NAV_H / 2 - 11, cx + 11, NAV_H / 2 + 11), fill=BUTTON)
    d.text(P(cx, NAV_H / 2 - 1), arrow, font=font(6, 16), fill=FG, anchor="mm")
is_current = (YEAR, MONTH) == (today.year, today.month)
title = f"{YEAR}年{MONTH}月"
if is_current:
    d.text(P(W / 2, NAV_H / 2), title, font=font(6, 15), fill=FG, anchor="mm")
else:
    # 今月以外: タイトルを少し上に、下に「今月へ」（真ん中を押すと今月に戻る）
    d.text(P(W / 2, NAV_H / 2 - 5), title, font=font(6, 14), fill=BLUE, anchor="mm")
    d.text(P(W / 2, NAV_H / 2 + 9), "今月へ", font=font(3, 9), fill=SUB, anchor="mm")

# ── 曜日の行 ──
head = Image.new("RGBA", P(W, HEAD), (0, 0, 0, 0))
d = ImageDraw.Draw(head)
for i, name in enumerate("日月火水木金土"):
    color = RED if i == 0 else BLUE if i == 6 else SUB
    d.text(P(i * CW + CW / 2, HEAD / 2), name, font=font(6, 11), fill=color, anchor="mm")

# ── 週の行（6 行）──
day_font, bold_font = font(3, 13), font(6, 13)
week_images = []
for week in weeks:
    img = Image.new("RGBA", P(W, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for c, day in enumerate(week):
        cx, cy = c * CW + CW / 2, CH / 2 - 1
        iso = day.isoformat()
        if day.month != MONTH:
            color = DIM
        elif c == 0 or iso in holidays:
            color = RED
        elif c == 6:
            color = BLUE
        else:
            color = FG
        f = day_font
        if day == today:
            d.ellipse(P(cx - 11, cy - 11, cx + 11, cy + 11), fill=BLUE)
            color, f = DARK, bold_font
        if iso == SELECTED and day != today:
            d.ellipse(P(cx - 11, cy - 11, cx + 11, cy + 11), outline=BLUE, width=2 * S // 2 + 1)
            f = bold_font
        d.text(P(cx, cy), str(day.day), font=f, fill=color, anchor="mm")
        # 予定のある日: 右上に件数のバッジ（10 件以上は 9+）
        if events[iso] and day.month == MONTH:
            n = events[iso]
            label = str(n) if n < 10 else "9+"
            bw = 10 if n < 10 else 14
            bx, by = cx + 9, cy - 7
            d.rounded_rectangle(P(bx - bw / 2, by - 5, bx + bw / 2, by + 5), radius=5 * S, fill=RED,
                                outline=(26, 27, 38), width=S)
            d.text(P(bx, by), label, font=font(6, 7), fill=(255, 255, 255), anchor="mm")
    week_images.append(img)

# 古い画像を消して、毎回新しい名前で保存（sketchybar が同じパスの画像を使い回さないように）
os.makedirs(OUTDIR, exist_ok=True)
for f in os.listdir(OUTDIR):
    if f.endswith(".png"):
        try:
            os.remove(os.path.join(OUTDIR, f))
        except OSError:
            pass
stamp = time.time_ns()
paths = []
for name, img in [("nav", nav), ("head", head)] + [(f"w{i + 1}", w) for i, w in enumerate(week_images)]:
    path = os.path.join(OUTDIR, f"{name}-{stamp}.png")
    img.save(path)
    paths.append(path)
with open(os.path.join(OUTDIR, "dates"), "w") as f:
    for week in weeks:
        f.write(" ".join(day.isoformat() for day in week) + "\n")
print(" ".join(paths))
