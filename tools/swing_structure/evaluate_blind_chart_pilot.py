"""Unseal the frozen 20 judgments. Fixed groups only; no tuning or EA changes."""
from pathlib import Path
import hashlib,json,itertools,math
import numpy as np
import pandas as pd
from scipy.stats import spearmanr,rankdata
from sklearn.metrics import roc_auc_score
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/three_wave/ready_blind_chart_200'
SUB=BASE/'judgments/submission_ea6df8ad8ba7bad5'
OUT=SUB/'evaluation'
SCORES=['continuation_probability','wave1_quality','wave2_quality','selling_pressure_decay','higher_tf_alignment']

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def perf(g):
    v=g.result_r;loss=-v[v<0].sum();profit=v[v>0].sum()
    return dict(n=len(g),tp=int(g.outcome.eq('TP').sum()),sl=int(g.outcome.eq('SL').sum()),
        win_rate=g.target.mean() if len(g) else np.nan,expectancy_r=v.mean(),sum_r=v.sum(),
        pf=profit/loss if loss>0 else (np.inf if profit>0 else np.nan),
        mean_mfe_r=g.mfe_to_exit.mean(),mean_mae_r=g.mae_to_exit.mean())
def md(df):
    def f(v):
        if pd.isna(v):return '—'
        return f'{v:.3f}' if isinstance(v,(float,np.floating)) else str(v)
    return '\n'.join(['| '+' | '.join(df.columns)+' |','| '+' | '.join(['---']*len(df.columns))+' |']+
        ['| '+' | '.join(f(v) for v in r)+' |' for r in df.itertuples(index=False,name=None)])

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    receipt=json.loads((SUB/'receipt.json').read_text());machine=json.loads((BASE/'private_audit/machine_audit.json').read_text())
    original=(SUB/'original_submission.json').read_bytes();assert hashlib.sha256(original).hexdigest()==receipt['original_sha256']
    ratings=pd.read_csv(SUB/'judgments_frozen.csv')
    pd.testing.assert_frame_equal(ratings,pd.DataFrame(json.loads(original)),check_dtype=False)
    assert sha(BASE/'public_sample_manifest_20.csv')==receipt['public_manifest_sha256']
    assert all(sha(BASE/p)==h for p,h in receipt['image_hashes_at_receipt'].items())
    assert sha(BASE/'blind_sample_manifest_200_private.csv')==machine['sample_sha256']
    source=BASE.parent/'ready_generated_tick_ml/all_candidates.csv'
    assert sha(source)==machine['source_candidate_sha256']
    production_before={p:sha(ROOT/p) for p in machine['production_hashes']}
    mapping=pd.read_csv(BASE/'private_label_manifest_20.csv',usecols=['blind_id','candidate_id','year','source_quality'])
    fixed=pd.read_csv(BASE/'blind_sample_manifest_200_private.csv').set_index('blind_id')
    assert mapping.candidate_id.to_list()==fixed.loc[mapping.blind_id,'candidate_id'].to_list()
    fields=['signal_id','entry_msc','entry','sl','tp','outcome','result_r','target','label_exclusion','parent_id','month','year',
            'mfe_to_exit','mae_to_exit','real_tick_verified_before']
    labels=pd.read_csv(source,usecols=fields)
    x=ratings.merge(mapping,on='blind_id',validate='one_to_one').merge(labels,left_on='candidate_id',right_on='signal_id',validate='one_to_one',suffixes=('','_source'))
    assert len(x)==20 and x.year.eq(x.year_source).all() and x.groupby('year').size().eq(2).all()
    assert x.label_exclusion.eq('INCLUDED').all() and x.target.isin([0,1]).all()
    assert x.outcome.eq(x.target.map({1:'TP',0:'SL'})).all()
    assert ((x.result_r>0)==x.target.eq(1)).all()
    x['entry_time']=pd.to_datetime(x.entry_msc,unit='ms').astype(str)
    x['decile']=np.ceil(x.continuation_probability.rank(method='average')/len(x)*10).astype(int)
    groups={'ALL':np.ones(len(x),dtype=bool)}
    groups.update({f'GRADE_{s}':x.overall_grade.eq(s).to_numpy() for s in ['A','B','C']})
    thresholds=[]
    for pct in [10,20,30]:
        nominal=math.ceil(len(x)*pct/100);cut=x.continuation_probability.nlargest(nominal).iloc[-1]
        key=f'TOP_{pct}';groups[key]=x.continuation_probability.ge(cut).to_numpy();x[key]=groups[key]
        thresholds.append(dict(group=key,nominal_n=nominal,score_boundary=int(cut),actual_n=int(groups[key].sum()),method='PRE_FIXED_PERCENTILE_INCLUDE_BOUNDARY_TIES'))
    x.sort_values('continuation_probability',ascending=False).to_csv(OUT/'judgments_with_outcomes.csv',index=False,encoding='utf-8-sig')
    stats=pd.DataFrame([dict(group=k,**perf(x.loc[v])) for k,v in groups.items()]);stats.to_csv(OUT/'group_statistics.csv',index=False)
    pd.DataFrame(thresholds).to_csv(OUT/'fixed_top_groups.csv',index=False)
    deciles=[]
    for dec in range(1,11):
        g=x[x.decile.eq(dec)];deciles.append(dict(decile=dec,min_score=g.continuation_probability.min(),max_score=g.continuation_probability.max(),**perf(g)))
    pd.DataFrame(deciles).to_csv(OUT/'decile_statistics.csv',index=False)
    score_rows=[];separation=[]
    for c in SCORES:
        corr_r=spearmanr(x[c],x.result_r);corr_y=spearmanr(x[c],x.target)
        score_rows.append(dict(score=c,auc=roc_auc_score(x.target,x[c]),spearman_result_r=corr_r.statistic,
            spearman_target=corr_y.statistic,mean_tp=x.loc[x.target.eq(1),c].mean(),mean_sl=x.loc[x.target.eq(0),c].mean()))
        for outcome,g in x.groupby('outcome'):
            v=g[c];separation.append(dict(score=c,outcome=outcome,n=len(v),mean=v.mean(),median=v.median(),q25=v.quantile(.25),q75=v.quantile(.75)))
    scores=pd.DataFrame(score_rows);scores.to_csv(OUT/'score_metrics.csv',index=False)
    pd.DataFrame(separation).to_csv(OUT/'score_outcome_distributions.csv',index=False)
    years=[]
    for year in range(2016,2026):
        for key,mask in groups.items():
            g=x.loc[mask&x.year.eq(year).to_numpy()];years.append(dict(year=year,group=key,**perf(g)))
    annual=pd.DataFrame(years);annual.to_csv(OUT/'yearly_statistics.csv',index=False)
    # Exact label permutation for the predesignated primary AUC. Assumes exchangeable labels.
    ranks=rankdata(x.continuation_probability);n=len(x);k=int(x.target.sum());den=k*(n-k)
    observed=float(roc_auc_score(x.target,x.continuation_probability))
    win=x.loc[x.target.eq(1),'continuation_probability'].to_numpy();loss=x.loc[x.target.eq(0),'continuation_probability'].to_numpy()
    pairwise=((win[:,None]>loss).sum()+.5*(win[:,None]==loss).sum())/(len(win)*len(loss))
    assert abs(observed-pairwise)<1e-12
    null=np.array([(sum(ranks[list(ix)])-k*(k+1)/2)/den for ix in itertools.combinations(range(n),k)])
    p_hi=float(np.mean(null>=observed-1e-12));p_two=float(np.mean(np.abs(null-.5)>=abs(observed-.5)-1e-12))
    # Sensitivity intervals: resample complete calendar years, keep original top-group membership.
    rng=np.random.default_rng(20261002);blocks=[np.flatnonzero(x.year.eq(y)) for y in range(2016,2026)]
    sample_ix=[np.concatenate([blocks[i] for i in rng.integers(0,10,10)]) for _ in range(5000)]
    def interval(values):
        v=np.asarray(values);v=v[np.isfinite(v)]
        return (list(np.quantile(v,[.025,.975])) if len(v) else [None,None]),len(v)
    auc_values=[];boot={g:[] for g in groups}
    for ix in sample_ix:
        sample=x.iloc[ix]
        if sample.target.nunique()==2:auc_values.append(roc_auc_score(sample.target,sample.continuation_probability))
        for key,mask in groups.items():
            v=sample.loc[mask[ix],'result_r'];boot[key].append(v.mean() if len(v) else np.nan)
    auc_ci,auc_n=interval(auc_values);cis=[]
    for key,v in boot.items():
        ci,valid=interval(v);cis.append(dict(group=key,mean_r_low=ci[0],mean_r_high=ci[1],valid_replicates=valid,total_replicates=5000))
    pd.DataFrame(cis).to_csv(OUT/'year_block_intervals.csv',index=False)
    diagnostics=dict(primary_auc=observed,auc_year_block_95pct=auc_ci,auc_valid_replicates=auc_n,
        exact_auc_permutation_p_greater=p_hi,exact_auc_permutation_p_two_sided=p_two,permutations=len(null),
        unique_parent_ids=int(x.parent_id.nunique()),unique_months=int(x.month.nunique()),
        unique_years=int(x.year.nunique()),rows_per_year=2,
        formal_p_value_limit='Unconditional permutation assumes exchangeable labels; temporal dependence and pilot size limit inference',
        annual_inference='Two candidates per year; no yearly reproducibility claim',
        top_membership_frozen=True,judgments_unchanged=True,source_labels_unchanged=True,
        actual_prompt_model_and_variant_not_independently_verified=True,production_unchanged=True,
        lightgbm_compared=False,remaining_images_generated=False)
    assert production_before=={p:sha(ROOT/p) for p in production_before}
    (OUT/'evaluation_audit.json').write_text(json.dumps(diagnostics,indent=2),encoding='utf-8')
    fig,ax=plt.subplots(figsize=(10,5))
    for o,col in [('TP','#198478'),('SL','#c44955')]:
        g=x[x.outcome.eq(o)];ax.scatter(g.continuation_probability,g.result_r,c=col,label=o,s=65,alpha=.8)
    ax.axhline(0,color='grey',lw=1);ax.set(xlabel='Frozen continuation score',ylabel='Realized R',title='Blind pilot: 20 frozen judgments');ax.legend();fig.tight_layout();fig.savefig(OUT/'score_vs_result.png',dpi=140);plt.close(fig)
    lines=f'''# ブラインド画像判定20件：初回照合

提出原文を固定した後、ユーザーの「判定して」により初めて実結果と結合した。評点・コメント・画像・母集団・Entry/SL/TPを変更していない。閾値探索・再抽出なし。

## 結論

**この20件では「画像の高評価ほど、固定TPへ届きやすい」という予測力は確認できなかった。** A評価は2勝3敗、Bは2勝4敗、Cは5勝4敗で、gradeが上がるほど成績が良くなる順序ではない。全体は9勝11敗、平均−0.019R、PF0.967。

上位20%は4件で2勝2敗、平均+0.095R。上位30%も6件で3勝3敗、+0.097Rだったが、最上位10%の2件（83点・82点）は両方SL。上位20%の勝ちは2018/2023各1件、負けは2016/2022各1件で、年ごとの再現性は判定できない。

上位足整合スコアもAUC0.384で、今回の固定決済結果を良い順に並べられていない。Cだけを採用する、高得点帯の一部だけを除く、といった事後ルールには進めない。一方で20件だけから「画像判断は常に無効」「過去の印象は全て偶然」とも断定できない。

次に検証する場合は未判定180件のまま仕様を固定し、今回の20件は開封済み試作として分離する。今回の採点結果から特徴やプロンプトを変更して、同じ20件で改善を測らない。

## 固定した集計

主指標はcontinuation scoreのROC-AUC、事前指定上位20%の平均R。上位10/30%、A/B/C、他4scoreは副次診断。割合で決めた境界同点は全て含める。

{md(stats[['group','n','tp','sl','win_rate','expectancy_r','pf']])}

## 予測順位とscoreの分離

{md(scores)}

主AUC={observed:.4f}。0.5は順位の識別力がない基準。年単位5000回再標本化の95%範囲は{auc_ci[0]:.3f}〜{auc_ci[1]:.3f}。主AUCの全ラベル配置{len(null):,}通りによる片側p={p_hi:.4f}、両側p={p_two:.4f}。置換検定はラベル交換可能性を仮定し、時間依存や20件の小標本を解消しない。副次scoreから最良のものを選んで採用しない。

群別の年ブロック区間はyear_block_intervals.csvに保存した。元の上位群の所属を固定し、再標本に該当候補がない反復は平均を欠測として除外している。特に上位10%は2敗しかなく、この2件を再標本化した狭い負の区間は、将来の上位10%が常に負になるという証拠ではない。

continuation_probabilityは『画像から見た上昇継続の主観スコア』として提出され、固定RRの到達確率としては定義されていない。例えば80点をそのまま実勝率80%の予測と解釈しない。今回照合しているのは、固定SLより先に固定TPへ届くという特定ラベルとの順位関係。

## 上位群の年別内訳

{md(annual[annual.group.eq('TOP_20')][['year','n','tp','sl','expectancy_r','pf']])}

各年2件、全体上位20%はわずか4件。上位群が複数年で勝っても、年ごとの再現性を証明できる件数ではない。n=0の年は未評価、PFの分母に損失がない群は∞表示であり安定性を意味しない。

## 制約と次の扱い

- これは保有制約のない既存shadow結果との対応であり、画像フィルター付きEAの実行リプレイではない。
- 各年2件の層化試作。年別20件の本番200件全体に対する結論ではない。全期間は既知研究データであり戦略の未知OOSではない。
- 生成tickを含む既存データ。既存の同分SL/TP両到達・未完了除外を変更しない。手数料等を新たに加減しない。
- actualモデル名・版・使用プロンプト・チャット履歴・rawのみを実際に渡したかは添付JSONから独立確認できない。案内どおりrawを使った想定であり、完全ブラインドの運用確認とは区別する。
- 今回ラベルを開封した20件を今後の未開封確認群に混ぜない。残り180件を判定する場合は同じプロンプト・画像仕様・上位割合を維持し、今回の答え合わせをその判定チャットへ渡さない。
- 追加180画像、LightGBM比較、新特徴実装、EA変更は行っていない。

## 保存物

- judgments_with_outcomes.csv：20件ごとの評点・実結果・Entry/SL/TP・年・R。
- group_statistics.csv / decile_statistics.csv / yearly_statistics.csv：固定区分別成績。
- score_metrics.csv / score_outcome_distributions.csv：各scoreのAUC・相関・分布。
- year_block_intervals.csv / evaluation_audit.json：不確実性・照合監査。
- score_vs_result.png：提出スコアと実損益の散布図。
'''
    (OUT/'summary.md').write_text(lines,encoding='utf-8')
    print(stats[['group','n','tp','sl','win_rate','expectancy_r','pf']].to_string(index=False))
    print(scores.to_string(index=False));print(json.dumps(diagnostics,indent=2))
    print(annual[annual.group.eq('TOP_20')][['year','n','tp','sl','expectancy_r']].to_string(index=False))

if __name__=='__main__':main()
