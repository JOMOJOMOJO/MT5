"""Plot fixed, saved entry-chart review findings; no new feature search."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
import numpy as np

root=Path(__file__).resolve().parent
plt.rcParams['font.family']=FontProperties(fname='C:/Windows/Fonts/meiryo.ttc').get_name()
plt.rcParams['axes.unicode_minus']=False
with (root/'analysis/visual_category_counts.csv').open(encoding='utf-8-sig') as f:visual=list(csv.DictReader(f))
with (root/'analysis/fixed_feature_groups.csv').open(encoding='utf-8-sig') as f:groups=list(csv.DictReader(f))
fig,axes=plt.subplots(1,2,figsize=(13.3,5.7),layout='constrained')
fig.set_facecolor('#f7f9fc')
ax=axes[0];x=np.arange(2)
for shift,outcome,label,color in [(-.18,'WIN','勝ち30件','#21876a'),(.18,'LOSS','負け30件','#be5b57')]:
    counts=[int(next(r['count'] for r in visual if r['arm']=='ALL' and r['feature']=='w1_progress' and r['category']==cat and r['outcome']==outcome)) for cat in ['CLEAN','CHOPPY_OR_MIXED']]
    ax.bar(x+shift,counts,.34,label=label,color=color)
    for xx,n in zip(x+shift,counts):ax.text(xx,n+.5,str(n)+'件',ha='center',fontsize=12)
ax.set_xticks(x,['素直に進む①','往復が多い・混在する①']);ax.set_ylim(0,30)
ax.set_ylabel('各30件の画像に含まれる件数');ax.set_title('画像では、①の進み方に違いがあった',loc='left',fontsize=12,weight='bold')
ax.legend(frameon=False);ax.grid(axis='y',alpha=.14);ax.set_axisbelow(True)
ax=axes[1]
data=[next(r for r in groups if r['cohort']=='ALL_440_IN_SAMPLE' and r['stratum']=='ALL' and r['feature']=='wave1_breaks_pre8_outer_close' and r['category']==cat) for cat in ['TRUE','FALSE']]
values=[float(r['mean_r']) for r in data]
ax.bar([0,1],values,.55,color=['#2a7fb9','#7f8da1'])
for i,(r,value) in enumerate(zip(data,values)):
    ax.text(i,value+(.009 if value>=0 else -.009),f"{value:+.3f}R\nn={r['n']} / 勝率{float(r['win_rate']):.1%}",ha='center',va='bottom' if value>=0 else 'top',fontsize=11)
ax.axhline(0,color='#7f8da1',lw=.8);ax.set_ylim(-.19,.10)
ax.set_xticks([0,1],['①前の高安範囲を\n終値で外へ突破','その高安範囲の\n内側にとどまる'])
ax.set_ylabel('年間既存取引の平均・費用込みR');ax.set_title('年間では、この2群の勝率が同じだった',loc='left',fontsize=12,weight='bold')
ax.grid(axis='y',alpha=.14);ax.set_axisbelow(True)
fig.suptitle('①と直前ジグザグの60画像レビュー｜形の違い ≠ 負けを除く条件の確定',fontsize=14,weight='bold')
fig.supxlabel('左：勝敗を均等にした観察標本。年間勝率ではない。右：440件中378件で計測、62件欠測。すべて既観測の2020年・生成ティック。',fontsize=9)
fig.savefig(root/'findings.png',dpi=145);plt.close(fig)
print(root/'findings.png')
