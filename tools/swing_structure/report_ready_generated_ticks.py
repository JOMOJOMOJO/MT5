"""Report the fixed generated-tick study without choosing a threshold."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import analyze_ready_2024_ml as base
from sklearn.metrics import roc_auc_score
from analyze_ready_generated_ticks import OUT

def table(x):
    def fmt(v):
        if pd.isna(v):return '—'
        return f'{v:.3f}' if isinstance(v,(float,np.floating)) else str(v)
    return '\n'.join(['| '+' | '.join(x.columns)+' |','| '+' | '.join(['---']*len(x.columns))+' |']+
                     ['| '+' | '.join(fmt(v) for v in row)+' |' for row in x.itertuples(index=False,name=None)])

def main():
    x=pd.read_csv(OUT/'all_candidates.csv');p=pd.read_csv(OUT/'walkforward_predictions.csv')
    met=pd.read_csv(OUT/'walkforward_metrics.csv');annual=pd.read_csv(OUT/'yearly_statistics.csv')
    monthly=pd.read_csv(OUT/'monthly_statistics.csv');pooled=pd.read_csv(OUT/'pooled_metrics.csv')
    imp=pd.read_csv(OUT/'lightgbm_importance.csv');stats=pd.read_csv(OUT/'period_feature_statistics.csv')
    st=imp.groupby('feature').agg(positive_years=('auc_drop',lambda v:int((v>0).sum())),negative_years=('auc_drop',lambda v:int((v<0).sum())),mean_auc_drop=('auc_drop','mean')).reset_index().sort_values('mean_auc_drop',ascending=False)
    st.to_csv(OUT/'feature_stability.csv',index=False)
    scopes=[]
    settled=x[x.outcome.isin(['TP','SL'])].copy();settled['target']=settled.tester_target
    for scope,g in [('ALL_SETTLED_BEFORE_EXCLUSION',settled),('ALL_ELIGIBLE',x[x.target.notna()]),('WF_TEST_2018_2025',p[p.model.eq('LIGHTGBM')]),
                    ('WF_PREVIOUS_REAL_TICK_VERIFIED',p[p.model.eq('LIGHTGBM')&p.real_tick_verified_before])]:
        scopes.append(dict(scope=scope,**base.perf(g)))
    pd.DataFrame(scopes).to_csv(OUT/'baseline_scopes.csv',index=False)
    # Fixed previously specified bins, including zero-count months, no best-bin selection.
    bins=[]
    for (year,model),g in p.groupby(['year','model']):
        labels=pd.cut(g.probability,base.EDGES,labels=base.LABELS,right=False)
        for label in base.LABELS:
            q=g[labels==label];n=q.groupby('month').size().reindex([f'{year}-{m:02d}' for m in range(1,13)],fill_value=0)
            bins.append(dict(year=year,model=model,bin=label,min_month=int(n.min()),avg_month=n.mean(),months_ge20=int((n>=20).sum()),**base.perf(q)))
    pd.DataFrame(bins).to_csv(OUT/'annual_probability_bins.csv',index=False)
    # Pure real-tick subset is a sensitivity check, not an independent holdout.
    sensitivity=[]
    for name,g in p[p.real_tick_verified_before].groupby('model'):
        sensitivity.append(dict(model=name,**base.scores(g.target,g.probability),**base.perf(g)))
    pd.DataFrame(sensitivity).to_csv(OUT/'real_tick_subset_sensitivity.csv',index=False)
    # Resample parents as blocks, preserving within-parent candidate dependence.
    bootstrap=[]
    for name in ['LIGHTGBM','TRAIN_PREVALENCE']:
        g=p[p.model.eq(name)].reset_index(drop=True)
        groups=list(g.groupby('parent_id').indices.values());rng=np.random.default_rng(20261001)
        aucs=[]
        for _ in range(500):
            idx=np.concatenate([groups[i] for i in rng.integers(0,len(groups),len(groups))]);q=g.iloc[idx]
            if q.target.nunique()==2:aucs.append(roc_auc_score(q.target,q.probability))
        bootstrap.append(dict(model=name,parent_blocks=len(groups),replicates=len(aucs),auc_low=np.quantile(aucs,.025),auc_high=np.quantile(aucs,.975)))
    pd.DataFrame(bootstrap).to_csv(OUT/'parent_bootstrap_auc.csv',index=False)
    fig,axes=plt.subplots(1,2,figsize=(12,4))
    for name in ['LIGHTGBM','LOGISTIC_L2','TREE_D2','TRAIN_PREVALENCE']:
        g=met[met.model.eq(name)];axes[0].plot(g.year,g.roc_auc,'o-',label=name);axes[1].plot(g.year,g.brier,'o-',label=name)
    axes[0].axhline(.5,color='gray',linestyle='--');axes[0].set(title='Annual walk-forward AUC',xlabel='Year',ylabel='AUC')
    axes[1].set(title='Annual Brier score (lower is better)',xlabel='Year',ylabel='Brier');axes[1].legend(fontsize=8)
    fig.tight_layout();fig.savefig(OUT/'annual_model_metrics.png',dpi=150);plt.close(fig)
    fig,ax=plt.subplots(figsize=(11,4));ax.bar(annual.year,annual.n,label='Included');ax.bar(annual.year,annual.dual_touch,bottom=annual.n,label='Dual SL/TP minute excluded')
    ax.set(title='Candidates per year (shadow signals)',xlabel='Year',ylabel='Count');ax.legend();fig.tight_layout();fig.savefig(OUT/'yearly_counts.png',dpi=150);plt.close(fig)
    lg=met[met.model.eq('LIGHTGBM')];ref=met[met.model.eq('TRAIN_PREVALENCE')]
    compare=lg.merge(ref,on='year',suffixes=('_lgb','_base'))
    audit=json.loads((OUT/'audit.json').read_text())
    text=f'''# 生成tickを許容した通常READYの機械学習研究

## 結論

生成tickを許容することで学習対象を2083件まで増やせた。LightGBMには弱い識別傾向があるが、確率予測の誤差は全期間で単純な学習勝率予測より改善せず、前回固定の確率binはすべて平均Rが負だった。「モデルで正期待値の取引群を作れた」という結果ではない。今回はフィルターや売買EAへ反映しない。

LightGBMで繰り返し寄与したのはサーバー時刻(hour_cos)、spread/ATR、spread/Rなど。H1最寄り抵抗距離やWave1の加速も一部の年で寄与した。ただしpermutation importanceは勝ち方向を示す指標ではない。生成tickのスプレッド仕様を学んだ可能性があるため、そのまま市場の優位性や特定セッションの効果と解釈しない。

## 対象と除外

2016〜2025年USDJPY、通常READY、EMA OFF、M1/M5ヒゲpivot 2/2、SL=M1 reversal low−10points、RR1.2を固定。既存MT5収集結果を再利用し、2023は履歴再取得後のBybit実行を使用。Vantageや再実行の候補を重複加算していない。売買EA・Shared変更なし、追加MT5起動なし。

全{len(x)}候補のうち、Entry分からExit分までのいずれかのM1足でLow<=SLかつHigh>=TPとなる{int(x.dual_touch_minute.sum())}件を除外。未完了{int(x.outcome.eq('END_CENSORED').sum())}件を別扱いとし、学習対象は{int(x.target.notna().sum())}件。Entry/Exit分の足全体で判定する保守的な方法で、除外のための将来情報はモデル特徴量に使用しない。

この除外は将来の結果を見たデータ品質処理であり、ライブで適用できる売買フィルターではない。除外後成績を実際の売買成績とは呼ばない。実tick限定の旧結果も保持する。

{table(annual)}

## 固定した評価方法

- 前回と同じ117特徴量・モデル設定。M15/H1の構造・位置・高安pivotを結ぶ線の傾き/価格距離も含む。
- 2016〜2017を初期学習とし、2018〜2025を1年ずつ前進検証。各年の学習には前年までのみ使用。
- 年境界の15分embargo、決着前ラベルの除外、親ID重複排除。補完・標準化・カテゴリ変換は学習側でfit。
- 閾値探索・最適化・売買条件採用はしていない。ランダム分割なし。既知期間なので未使用OOSとは呼ばない。
- 各年・各モデルの再学習{len(audit['repeat_checks'])}回は予測値1e-12以内で一致。各年の特徴量構築でprefix再計算・未来価格変更への不変性・M15ネイティブ表示との一致を監査。

## モデル結果

{table(pooled[['model','n','roc_auc','pr_auc','brier']])}

LightGBMの年別AUCが0.5を上回ったのは{int((lg.roc_auc>.5).sum())}/8年、Brierが学習勝率一定予測より良かったのは{int((compare.brier_lgb<compare.brier_base).sum())}/8年。pooled AUCだけで年を跨ぐ再現性を判断しない。

親ID単位で500回再抽出したpooled AUCの95%区間（年を跨ぐ相場変化を完全に表す区間ではない）:

{table(pd.DataFrame(bootstrap))}

{table(met[met.model.eq('LIGHTGBM')][['year','roc_auc','pr_auc','brier']])}

### 売買候補そのものの成績

{table(pd.DataFrame(scopes))}

Rは保存済みshadowのAsk Entry/Bid決済から計算。生成tickのスプレッド・約定順序モデル依存は残る。手数料・スワップ等を含む口座純損益ではない。1ポジション/クールタイムの実行成績とは区別する。

## 頻度

全120か月の除外後候補平均は{monthly.n.mean():.2f}件/月、最少{monthly.n.min()}件、月20件以上は{int((monthly.n>=20).sum())}/120か月。これは全shadow候補で、実行可能取引数ではない。候補段階ですでに毎月20回を保証しないため、モデルによる絞り込みで頻度目標を満たすとはいえない。

## LightGBMの特徴量診断

下表は各テスト年で特徴を入れ替えた際のAUC低下。正負が年によって変わる特徴は安定した根拠としない。テスト結果で特徴を選び直して再学習する処理は行っていない。

{table(st.head(15))}

## 出力

- all_candidates.csv: 全候補・除外理由・既存の実tick品質フラグ・特徴量。
- excluded_candidates.csv / exclusion_preflight.csv: 除外の内訳。
- bar_first_touch_audit.csv: M1足で最初に触れたバリアとテスター結果の整合。
- yearly_statistics.csv / monthly_statistics.csv: 件数・成績。
- walkforward_predictions.csv / walkforward_metrics.csv / walkforward_folds.csv: 予測・年別成績・分割。
- probability_bins.csv / annual_probability_bins.csv: 前回固定の確率bin別成績と頻度。最良閾値は選択しない。
- real_tick_subset_sensitivity.csv: 実tick品質確認済み部分だけでの感度確認。
- lightgbm_importance.csv / feature_stability.csv / period_feature_statistics.csv: 特徴量別診断。
- decision_tree_diagnostic.txt: 深さ2の診断木（数値閾値は学習側標準化単位）。
- annual_model_metrics.png / yearly_counts.png: グラフ。

## 制限

生成tickでのSL/TP順序の曖昧さを4件取り除いても、実Ask・スプレッド・ギャップ・滑りを完全には再現しない。短時間で片側だけに到達したケースは除外しない。同じ親波や近接時刻の候補は独立ではなく、2091候補を独立2091取引と見なさない。結果に基づく採用・優位性確立の主張はしない。
'''
    (OUT/'summary.md').write_text(text,encoding='utf-8')
    print('REPORT COMPLETE',flush=True)

if __name__=='__main__':main()
