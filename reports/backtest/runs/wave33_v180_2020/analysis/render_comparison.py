"""Render saved annual trade tables; no strategy simulation or tuning."""
import csv
import json
from datetime import datetime
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
import numpy as np

OUT=Path(__file__).resolve().parent
OLD=OUT.parents[1]/'wave33_v170_2020'/'analysis'
plt.rcParams['font.family']=FontProperties(fname='C:/Windows/Fonts/meiryo.ttc').get_name()
plt.rcParams['axes.unicode_minus']=False

def load(root):
    with (root/'trades.csv').open(encoding='utf-8-sig',newline='') as f:
        return list(csv.DictReader(f))

old,new=load(OLD),load(OUT)
summaries={v:json.loads((p/'streak_summary.json').read_text(encoding='utf-8-sig'))['results'] for v,p in [('1.70',OLD),('1.80',OUT)]}
fig,axes=plt.subplots(2,2,figsize=(13.5,8.5),layout='constrained')
fig.set_facecolor('#f7f9fc')
for col,(arm,label,color) in enumerate([('A','A：M15 × M5','#2478b5'),('B','B：M5 × M1','#8656b5')]):
    ax=axes[0,col]
    for version,table,c in [('1.70',old,'#8c96a2'),('1.80',new,color)]:
        trades=[r for r in table if r['arm']==arm]
        x=[datetime.fromisoformat(r['exit_at']) for r in trades]
        y=np.cumsum([float(r['net_r']) for r in trades])
        ax.plot(x,y,color=c,lw=1.7,label=f'v{version}：{y[-1]:+.2f}R')
    ax.axhline(0,color='#8291a1',lw=.7);ax.legend(frameon=False,fontsize=10)
    s=summaries['1.80'][arm]['summary']
    ax.set_title(f"{label}｜v1.80 {s['n']}件・純損益PF {s['pf_cash']:.3f}",loc='left',fontsize=12,weight='bold')
    ax.set_ylabel('費用込み・決済済み取引の累積R')
    ax.tick_params(axis='x',rotation=30);ax.grid(axis='y',alpha=.15)
    ax=axes[1,col]
    x=np.arange(12)
    for shift,version,table,c in [(-.18,'1.70',old,'#a6afb9'),(.18,'1.80',new,color)]:
        values=[sum(float(r['net_r']) for r in table if r['arm']==arm and r['month']==f'2020-{m:02}') for m in range(1,13)]
        ax.bar(x+shift,values,.34,color=c,label=f'v{version}',alpha=.9)
    ax.axhline(0,color='#8291a1',lw=.7)
    ax.set_xticks(x,[str(m) for m in range(1,13)]);ax.set_xlabel('2020年・エントリー月')
    ax.set_ylabel('月別の合計・費用込みR');ax.legend(frameon=False,fontsize=9)
    ax.grid(axis='y',alpha=.15);ax.set_axisbelow(True)
fig.suptitle('3波3波EA｜逆①候補取消＋①手前TP延長の年間比較',fontsize=16,weight='bold')
fig.supxlabel('XAUUSD+／各口座5,000 USD／生成ティック／A・Bは独立した実行／2変更同時の比較',fontsize=10)
fig.savefig(OUT/'annual_comparison.png',dpi=145);plt.close(fig)
print(OUT/'annual_comparison.png')
