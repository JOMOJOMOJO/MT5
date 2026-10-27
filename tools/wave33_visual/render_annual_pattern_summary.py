"""Render the fixed annual pattern review; reads saved tables, no new analysis."""
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
import numpy as np

ROOT = Path("reports/backtest/runs/wave33_v170_2020")
OUT = ROOT / "pattern_review_20261023"
font = FontProperties(fname="C:/Windows/Fonts/meiryo.ttc")
plt.rcParams["font.family"] = font.get_name()
plt.rcParams["axes.unicode_minus"] = False

with (OUT / "resistance/groups.csv").open(encoding="utf-8-sig", newline="") as handle:
    groups = list(csv.DictReader(handle))
annual = json.loads((ROOT / "analysis/streak_summary.json").read_text(encoding="utf-8-sig"))
fig, axes = plt.subplots(2, 2, figsize=(13.5, 9.2), layout="constrained")
fig.set_facecolor("#f7f9fc")
colors = {"A": "#267db4", "B": "#8e5ab5"}
bands = ["0.25_TO_0.5", "0.5_TO_1", "GE_1"]
labels = ["①まで0.25〜0.5R未満", "0.5〜1R未満", "1R以上"]
for ax, arm, title in zip(axes[0], ("A", "B"), ("A：M15 × M5", "B：M5 × M1")):
    data = [next(row for row in groups if row["arm"] == arm and row["feature"] == "order_room_band" and row["value"] == band and row["period"] == "ALL") for band in bands]
    values = [float(row["mean_r"]) for row in data]
    ax.bar(np.arange(3), values, width=0.58, color=[colors[arm], "#c9524f", colors[arm]], alpha=0.9)
    ax.axhline(0, color="#405167", linewidth=0.9)
    ax.set_ylim(-0.49, 0.15)
    ax.set_xticks(np.arange(3), labels, fontsize=9)
    ax.set_ylabel("1取引あたりの平均・費用込みR")
    ax.set_title(title + "｜①までの余地と実績", loc="left", fontsize=13, weight="bold", pad=13)
    for index, (value, row) in enumerate(zip(values, data)):
        ax.text(index, value + (0.018 if value >= 0 else -0.018), f"{value:+.3f}R\nn={row['n']} / 勝率{float(row['win_rate']):.1%}", ha="center", va="bottom" if value >= 0 else "top", fontsize=10)
    ax.grid(axis="y", alpha=0.15)
    ax.set_axisbelow(True)

ax = axes[1, 0]
x = np.arange(2)
win = [annual["results"][arm]["summary"]["mean_win_r"] for arm in ("A", "B")]
loss = [-annual["results"][arm]["summary"]["mean_loss_r"] for arm in ("A", "B")]
ax.bar(x - .17, win, .30, color="#329f75", label="勝ち1回の平均利益")
ax.bar(x + .17, loss, .30, color="#c9524f", label="負け1回の平均損失の大きさ")
for pos, vals in ((x - .17, win), (x + .17, loss)):
    for xx, yy in zip(pos, vals):
        ax.text(xx, yy + .03, f"{yy:.3f}R", ha="center", fontsize=10)
ax.set_xticks(x, ["A：46勝 / 51敗", "B：187勝 / 191敗"])
ax.set_ylim(0, 1.38)
ax.set_ylabel("勝ち・負けの大きさ（絶対値）")
ax.set_title("RR設定は1でも、平均利益と平均損失は等しくない", loc="left", fontsize=12, weight="bold", pad=13)
ax.legend(loc="upper left", fontsize=9, frameon=False)
ax.grid(axis="y", alpha=.15)
ax.set_axisbelow(True)

ax = axes[1, 1]
for shift, arm in ((-.08, "A"), (.08, "B")):
    data = [next(row for row in groups if row["arm"] == arm and row["feature"] == "order_room_band" and row["value"] == "0.5_TO_1" and row["period"] == half) for half in ("2020H1", "2020H2")]
    values = [float(row["mean_r"]) for row in data]
    ax.plot(x + shift, values, marker="o", color=colors[arm], label=arm, linewidth=2)
    for index, (xx, value, row) in enumerate(zip(x + shift, values, data)):
        left = arm == "A" and index == 0
        offset = (-13, -13) if left else ((14, -22) if arm == "A" else (13, 13))
        ax.annotate(f"{arm} {value:+.3f}R\nn={row['n']}", (xx, value), xytext=offset, textcoords="offset points", ha="right" if left else "left", fontsize=10, color=colors[arm])
ax.axhline(0, color="#405167", linewidth=.9)
ax.set_xlim(-.40, 1.55)
ax.set_ylim(-.62, .10)
ax.set_xticks(x, ["前半：1〜6月", "後半：7〜12月"])
ax.set_ylabel("1取引あたりの平均・費用込みR")
ax.set_title("0.5〜1R未満の群は、前後半も両方マイナス", loc="left", fontsize=12, weight="bold", pad=13)
ax.grid(axis="y", alpha=.15)
ax.set_axisbelow(True)
for ax in axes.flat:
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
fig.suptitle("XAUUSD+ 2020年｜475取引の勝ち負けを再点検", fontsize=19, weight="bold")
fig.supxlabel("1R＝実約定から当初SLまでの金額リスク。既存取引の記述集計であり、フィルター採用後の成績ではありません。\n①までの余地は注文時点で計算。前後半とも既に観測済みの同一年・生成ティックです。", fontsize=9)
fig.savefig(OUT / "pattern_summary.png", dpi=165)
plt.close(fig)
print(OUT / "pattern_summary.png")
