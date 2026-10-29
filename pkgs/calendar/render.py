# sketchybar の時計メニューに出すカレンダーを画像で描く
#   使い方: render.py <年> <月> <出力ディレクトリ>
#   出力:   <月送りの行の画像> <カレンダーの画像>（空白区切りで 1 行）
# 日曜・祝日は赤、土曜は青、今日は丸、予定のある日は点。前後の月の日付は薄く表示する。
# 祝日はカレンダー「日本の祝日」、予定はそれ以外のカレンダーから icalBuddy で読む。
import calendar
import datetime
import os
import subprocess
import sys
import time
import unicodedata

from PIL import Image, ImageDraw, ImageFont

YEAR, MONTH, OUTDIR = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
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
    """指定したカレンダーで予定がある日（YYYY-MM-DD）の集合"""
    try:
        out = subprocess.run(
            [ICAL, "-nc", "-nrd", "-b", "", "-iep", "datetime", "-df", "%Y-%m-%d", "-tf", "",
             *cal_args, f"eventsFrom:{start}", f"to:{end}"],
            capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return set()
    return {line.strip()[:10] for line in out.splitlines() if line.strip()[:4].isdigit()}


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

# ── カレンダー ──
H = HEAD + CH * 6 + 4
grid = Image.new("RGBA", P(W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(grid)
head_font, day_font, today_font = font(6, 11), font(3, 13), font(6, 13)
for i, name in enumerate("日月火水木金土"):
    color = RED if i == 0 else BLUE if i == 6 else SUB
    d.text(P(i * CW + CW / 2, HEAD / 2), name, font=head_font, fill=color, anchor="mm")
for r, week in enumerate(weeks):
    for c, day in enumerate(week):
        cx, cy = c * CW + CW / 2, HEAD + r * CH + CH / 2 - 1
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
            color, f = DARK, today_font
        d.text(P(cx, cy), str(day.day), font=f, fill=color, anchor="mm")
        if iso in events and day.month == MONTH:
            dot = DARK if day == today else DOT
            d.ellipse(P(cx - 1.5, cy + 7, cx + 1.5, cy + 10), fill=dot)

# 古い画像を消して、毎回新しい名前で保存（sketchybar が同じパスの画像を使い回さないように）
os.makedirs(OUTDIR, exist_ok=True)
for f in os.listdir(OUTDIR):
    if f.endswith(".png"):
        try:
            os.remove(os.path.join(OUTDIR, f))
        except OSError:
            pass
stamp = time.time_ns()
nav_path = os.path.join(OUTDIR, f"nav-{stamp}.png")
grid_path = os.path.join(OUTDIR, f"grid-{stamp}.png")
nav.save(nav_path)
grid.save(grid_path)
print(nav_path, grid_path)
