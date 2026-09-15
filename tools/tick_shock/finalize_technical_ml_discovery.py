"""Finalize discovery evidence; disclose positive cells without changing selection.

No model fitting and no May/June outcomes. Positive aggregate cells are an audit
of the completed, preregistered surface, not new candidates or a rescue search.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import subprocess

import numpy as np
import pandas as pd
import technical_ml_discovery as ml
import report_technical_ml_discovery as report


def key(c):
    return '__'.join(str(c[k]) for k in report.KEYS)


def gather(output,config,wf,data):
    rows=report.match(wf,config)
    frames=[]
    for r in rows.to_dict('records'):
        actions=ml.load_actions(output,config,int(r['month']),data)
        frames.append(ml.simulate(actions,r['threshold'])[0])
    return report.enrich(pd.concat(frames).sort_values(['signal_processing_msc','t0_msc','episode_id']))


def positive_audit(output,frontier,wf,data):
    positive=frontier[(frontier.min_month_trades>=200)&(frontier.total_r>0)]
    summaries,monthly,costs,dependence,boots=[],[],[],[],[]
    for config in positive.sort_values(['total_r',*report.KEYS],ascending=[False,True,True,True,True,True]).to_dict('records'):
        trades=gather(output,config,wf,data)
        ident=key(config)
        summary={**config,**report.independent_accounting(trades),'candidate_id':ident,
                 'scope':'POSITIVE_POOLED_DEVELOPMENT_CELL_NOT_ADOPTED'}
        summaries.append(summary)
        for month,t in trades.groupby('month'):
            monthly.append(dict(candidate_id=ident,month=month,**report.independent_accounting(t)))
        for cost in report.COSTS:
            costs.append(dict(candidate_id=ident,extra_cost_pips=cost,**report.independent_accounting(trades,cost)))
        for groupcol in ('symbol','server_week','side','server_session'):
            totals=trades.groupby(groupcol).net_r.sum()
            denominator=totals.clip(lower=0).sum()
            for group,t in trades.groupby(groupcol):
                value=report.independent_accounting(t)
                dependence.append(dict(candidate_id=ident,dimension=groupcol,group=group,
                    **value,total_r_excluding_group=summary['total_r']-value['total_r'],
                    positive_group_share=max(value['total_r'],0)/denominator if denominator else math.nan))
        boots.extend([dict(candidate_id=ident,**r) for r in report.bootstrap(trades)])
    for name,rows in [('positive_pooled_cells',summaries),('positive_pooled_monthly',monthly),
                      ('positive_pooled_costs',costs),('positive_pooled_dependence',dependence),
                      ('positive_pooled_bootstrap',boots)]:
        ml.dump(rows,output/f'{name}.csv')
    return pd.DataFrame(summaries),pd.DataFrame(monthly)


def family_profit_comparison(output,frontier,wf,data):
    rows=[]
    for family,g in frontier.groupby('family'):
        pool=g[g.min_month_trades>=200]
        if pool.empty:pool=g
        best=pool.sort_values(['expectancy_r',*report.KEYS],ascending=[False,True,True,True,True,True]).iloc[0].to_dict()
        rows.append({**best,**report.independent_accounting(gather(output,best,wf,data)),
                     'selection':'POOLED_EV_BEST_SAME_DEVELOPMENT_DATA_NOT_WORST_MONTH_BEST'})
    result=pd.DataFrame(rows)
    ml.dump(result,output/'model_family_pooled_best.csv')
    return result


def finalize(output):
    required=['selection.json','qa_checks.csv','deterministic_rerun.csv','verify_source_integrity.csv',
              'interpretation_metadata.json','interpretation_qa.csv','interpretation_shap_additivity.csv']
    for name in required:
        if not (output/name).exists():raise FileNotFoundError(output/name)
    checks=[]
    for name in ('qa_checks.csv','deterministic_rerun.csv','verify_source_integrity.csv',
                 'interpretation_qa.csv','interpretation_shap_additivity.csv'):
        q=pd.read_csv(output/name)
        bad=q.status.ne('PASS').sum()
        checks.append(dict(evidence=name,checks=len(q),pass_count=int(q.status.eq('PASS').sum()),fail_count=int(bad)))
        assert not bad,f'QA failure in {name}'
    selection=json.loads((output/'selection.json').read_text())
    assert selection['fold_configurations']==540
    assert not selection['holdout_outcomes_read']
    ml.init_worker(output/'dataset.pkl');data=ml._DATA
    f,o,xf,columns=data
    assert set(f.month)=={202501,202502,202503,202504}
    frontier=pd.read_csv(output/'candidate_frontier.csv')
    wf=pd.read_csv(output/'walk_forward.csv')
    positive,months=positive_audit(output,frontier,wf,data)
    family=family_profit_comparison(output,frontier,wf,data)
    ml.dump(checks,output/'final_qa_summary.csv')
    native=pd.read_csv(output/'interpretation_native_importance.csv')
    perm=pd.read_csv(output/'interpretation_feature_permutation.csv')
    groups=pd.read_csv(output/'interpretation_group_permutation.csv')
    important=native[native.role.str.startswith('DIAGNOSTIC')].groupby('feature').normalized_importance.mean().sort_values(ascending=False)
    interaction=important[important.index.str.contains('_x_|^m1_m5_|^m1_m15_|^m5_m15_',regex=True)]
    ml.dump(important.rename('mean_normalized_importance').reset_index(),output/'diagnostic_feature_ranking.csv')
    ml.dump(interaction.rename('mean_normalized_importance').reset_index(),output/'diagnostic_interaction_ranking.csv')
    p=perm[perm.role.str.startswith('DIAGNOSTIC')].groupby('feature_or_group').agg(
        observations=('ev_degradation','size'),ev_degradation=('ev_degradation','mean'),
        total_r_degradation=('total_r_degradation','mean'),rmse_increase=('ev_rmse_increase','mean')).sort_values('total_r_degradation',ascending=False)
    ml.dump(p.reset_index(),output/'diagnostic_permutation_ranking.csv')
    gp=groups[groups.role.str.startswith('DIAGNOSTIC')].groupby('feature_or_group').agg(
        observations=('ev_degradation','size'),ev_degradation=('ev_degradation','mean'),
        total_r_degradation=('total_r_degradation','mean'),rmse_increase=('ev_rmse_increase','mean'))
    ml.dump(gp.reset_index(),output/'diagnostic_group_permutation_summary.csv')
    bins=pd.read_csv(output/'interpretation_feature_bins.csv')
    bins=bins[bins.role.str.startswith('DIAGNOSTIC')]
    contrasts=[]
    for (feature,side,month),g in bins.groupby(['feature','direction','month']):
        g=g.sort_values('bin')
        contrasts.append(dict(feature=feature,direction=side,month=month,
            high_minus_low=float(g.net_expectancy_r.iloc[-1]-g.net_expectancy_r.iloc[0]),
            low_ev=float(g.net_expectancy_r.iloc[0]),high_ev=float(g.net_expectancy_r.iloc[-1]),
            min_bin_rows=int(g.rows.min())))
    contrasts=pd.DataFrame(contrasts)
    states=contrasts.groupby(['feature','direction']).agg(months=('month','size'),
        high_minus_low=('high_minus_low','mean'),positive_months=('high_minus_low',lambda x:int((x>0).sum())),
        negative_months=('high_minus_low',lambda x:int((x<0).sum())),low_ev=('low_ev','mean'),
        high_ev=('high_ev','mean'),min_bin_rows=('min_bin_rows','min')).reset_index()
    states['scope']='FIT_QUINTILES_VALIDATION_ACTION_LABELS_NOT_PORTFOLIO_NOT_ADOPTED'
    ml.dump(states,output/'diagnostic_state_bin_contrasts.csv')
    consistent=states[(states.months==3)&((states.positive_months==3)|(states.negative_months==3))]
    consistent=consistent.sort_values('high_minus_low')
    calibration=wf[wf.target_count>0].groupby(['calibration','target_count']).agg(
        cells=('trades','size'),median_actual=('trades','median'),p10_actual=('trades',lambda x:x.quantile(.1)),
        p90_actual=('trades',lambda x:x.quantile(.9)),median_ev=('expectancy_r','median'),
        fraction_positive=('total_r',lambda x:(x>0).mean()))
    ml.dump(calibration.reset_index(),output/'calibration_frequency_summary.csv')
    monthly=pd.read_csv(output/'diagnostic_monthly.csv')
    cost=pd.read_csv(output/'diagnostic_cost_sensitivity.csv')
    dc=cost[cost.month.astype(str)=='POOLED']
    geometry=pd.read_csv(output/'geometry_path_normalized.csv')
    geometry=geometry[geometry.month.isin(ml.MONTHS)].groupby('distance_atr')[['executed_rows','tp_first','sl_first','time_exit']].sum().reset_index()
    geometry['time_exit_rate']=geometry.time_exit/geometry.executed_rows
    ml.dump(geometry,output/'geometry_timeout_summary.csv')
    scope='NO_EA_CANDIDATE_UNDER_PREREGISTERED_GATE' if selection['passing_candidates']==0 else 'DEVELOPMENT_CANDIDATE_ONLY'
    reportpath=ml.ROOT/'docs/research/tick_shock/technical_ml_discovery_readout_ja.md'
    tab=report.markdown_table
    text=(
        '# Tick-Shock Technical ML Discovery：結果の説明\n\n'
        f'判定：`{scope}`。今回の依頼どおり**分析まで**。EA作成・変更・MT5再実行はしていません。\n\n'
        '## 結論\n\n'
        f'1～4月の11,230 episodes、486特徴量を使い、2～4月の9,602 episodesで時系列評価しました。'
        f'6モデル系統×3予測対象×2特徴量版×5距離×3期間＝540組を実行しました。'
        f'頻度調整を含む3,240設定のうち、各月200件以上は{selection["frequency_qualified"]:,}設定、'
        f'その中で合計損益がプラスは{len(positive)}設定。しかし各月プラスの設定は0でした。\n\n'
        '**「全部マイナス」ではありません。ただし月を跨ぐ安定性とコスト余裕が弱く、採用条件は満たしませんでした。** '
        '事前ルールに従い5～6月へは進めていません。5～6月は過去の実験で観測済みなので、今後使っても完全未使用OOSではありません。\n\n'
        '## 1. 合計損益がプラスだった設定も開示\n\n'
        '以下は実Bid/Askに含まれるspreadに加え、**仮想の追加往復0.2 pip**を控除した1R固定のoffline損益です。'
        '実commissionの測定値ではありません。0.2 pipには、未観測commission・追加slippage等への感度を見る意味があります。\n\n'
        +tab(positive,['family','target','variant','geometry','policy','trades','expectancy_r','pf','maxdd_r','worst_month_ev','top5_removed_total_r'])+'\n\n'
        'geometry index1/2/3/4/5は、それぞれ0.5/0.75/1.0/1.5/2.0 ATRです。上表は開示用であり、採用候補への差し替えではありません。\n\n'
        +tab(months,['candidate_id','month','trades','expectancy_r','pf','total_r'])+'\n\n'
        'プラス3設定の通貨・週別依存、上位5件除外、0～1pip感度、cluster/day bootstrapは '
        '`positive_pooled_*.csv`。多数比較後に選ばれたプラスなので、独立した利益証明ではありません。\n\n'
        '## 2. モデル別：合計EVが最も良い設定\n\n'
        +tab(family,['family','target','variant','geometry','policy','trades','expectancy_r','pf','worst_month_ev'])+'\n\n'
        '別表`model_family_comparison.csv`は最悪月EVを重視した順位です。順位基準を混同しません。'
        'NET_Rを選んだLOGISTIC行はRidge回帰、ELASTICNET行はElasticNet回帰。'
        'WIN/TP_FIRSTではそれぞれL2/ElasticNet Logisticです。XGBoostは未導入、SHAPはLightGBM標準機能を使用しました。\n\n'
        '## 3. 月別安定性を重視した診断モデル\n\n'
        'Extra Trees・net R直接回帰・448特徴量・TP=SL=2ATR・学習score percentile300件相当。'
        'これは最悪月が最も軽い頻度適合モデルであり、採用モデルではありません。\n\n'
        +tab(monthly,['month','trades','win_rate','expectancy_r','pf','maxdd_r','tp','sl','timeout'])+'\n\n'
        '直接net R回帰が比較的残り、TP先着確率を学習平均payoffでEVへ変換する方法は弱い結果でした。'
        'TIME決済の損益とSL gapがあるため、TP確率だけから2p−1でEVを計算していません。\n\n'
        '## 4. 特徴量・interactionの読み方\n\n'
        '診断Extra Treesの平均重要度上位は次のとおりです。これはモデル使用度であって「利益が出る条件」ではありません。\n\n'
        +tab(important.head(12).rename('importance').reset_index(),['feature','importance'])+'\n\n'
        '既存interactionの上位：\n\n'+tab(interaction.head(8).rename('importance').reset_index(),['feature','importance'])+'\n\n'
        'Validation内・同じ通貨内でのpermutation、訓練期間の分位点で区切った翌月のfeature bin、'
        'PDP、interaction除外再学習、LightGBM TreeSHAPを実行しています。'
        '相関した特徴量の代替・不自然な組合せの影響があるため、個別指標の因果効果とは解釈しません。'
        '`interpretation_*.csv`と`diagnostic_*ranking.csv`を参照してください。\n\n'
        '次は、訓練期間だけで決めた低位binと高位binを比較し、3評価月で差の符号が揃った状態です。'
        'direction=1はLONG、-1はSHORT。high_minus_lowは高位状態−低位状態の平均net R差。'
        '差がプラスでも両方の損益がマイナスの場合があり、売買ruleには採用していません。\n\n'
        +tab(consistent,['feature','direction','high_minus_low','low_ev','high_ev','min_bin_rows'])+'\n\n'
        '## 5. Frequency frontierとthreshold\n\n'
        '100/200/300/500/800件相当を、固定EV・fit内percentile・fit内件数・過去calibration tail件数で比較しました。'
        '時系列の最後25%をcalibrationに残し、同じモデルを翌月まで固定。後から再fitしてscore尺度を変更していません。'
        '目標件数と成立件数は一致保証ではなく、全通貨1ポジション・拒否・episode密度で変わります。\n\n'
        '`frequency_expectancy_frontier.csv`は全月の実際の件数とEV、`calibration_frequency_summary.csv`は全固定設定の分布です。'
        '月200件以上にすること自体はできましたが、それだけで正EVにはなりませんでした。\n\n'
        '## 6. 通貨依存性\n\n'
        '38の絶対単位featureを除いた448版も比較しましたが、normalized featureからも通貨は推測可能です。'
        '除外版が一律改善したわけではなく、モデル別の同一policy比較では悪化もあります。'
        '診断モデルではUSDJPYのプラスに対してUSDCHFの損失が大きく、通貨共通の安定edgeとは言えません。'
        '`diagnostic_symbol.csv`、`raw_scale_exclusion_paired.csv`を参照。\n\n'
        '## 7. TP/SLとコストが残す問題\n\n'
        '全評価期間の実行可能な両方向labelを集計したTIME比率（独立取引数ではない）：\n\n'
        +tab(geometry,['distance_atr','executed_rows','tp_first','sl_first','time_exit','time_exit_rate'])+'\n\n'
        '診断2ATRモデルの追加コスト感度：\n\n'
        +tab(dc,['extra_roundtrip_cost_pips','trades','expectancy_r','pf','total_r'])+'\n\n'
        'つまり、追加コストなし／0.1pipでは薄いプラス傾向が見えても、0.2pipで消える程度の余裕です。'
        '実Bid/Ask spreadはどの行にも含まれています。2ATRではTIMEが多く、「毎回RR1で勝敗が決まる戦略」でもありません。\n\n'
        '## 8. QAと限界\n\n'
        +tab(pd.DataFrame(checks),['evidence','checks','pass_count','fail_count'])+'\n\n'
        '人工18テストに加え、12固定構成を本当に再学習して予測・thresholdを比較しました。'
        'MQL source/EX5・既存fixture/expected・入力CSVのSHA不変を確認。'
        '元のJanuary/Aprilのlegacy-pool警告、February/Marchのgenerated fallbackは保持しています。'
        '15分決済は期限以降の最初の実quoteであり、厳密に900秒以内ではありません。'
        'bootstrap CIは候補選択の多重比較バイアスを補正しておらず、利益証明ではありません。\n\n'
        '## 9. EA化可否と次の判断\n\n'
        '**今回はEA化しません。** 今回分かったのは、取引数の維持は改善できても、'
        '方向・損益のsignalが追加コストと月別・通貨別変動を十分に上回っていないことです。'
        '同じデータでモデル数やthresholdを増やして救済せず、今回の全結果を保存します。'
        '5～6月の再評価を希望する場合も、この未達と観測済み期間である点を引き継ぐ必要があります。\n\n'
        '主データ：`reports/analysis/tick_shock/technical_ml_discovery_20260911/`。'
        '設計：[事前仕様](technical_ml_discovery_preregistration.md)。'
        '詳細：[全体資料](technical_ml_discovery_results.md)。\n')
    reportpath.write_text(text,encoding='utf-8')
    now=datetime.now(timezone.utc).isoformat()
    result=dict(status='COMPLETED_ANALYSIS_QA',completed_at=now,fold_configurations=540,
        candidate_policies=3240,frequency_qualified=selection['frequency_qualified'],positive_pooled_cells=len(positive),
        passing_candidates=selection['passing_candidates'],qa_evidence=checks,ea_created=False,
        holdout_outcomes_read=False,holdout_status='NOT_RUN_PREREGISTERED_GATE_NOT_MET' if not selection['passing_candidates'] else 'PENDING',
        report=reportpath.relative_to(ml.ROOT).as_posix(),branch=subprocess.check_output(['git','branch','--show-current'],cwd=ml.ROOT,text=True).strip(),
        base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ml.ROOT,text=True).strip())
    ml.write_json(result,output/'completion.json')
    progress=json.loads((output/'progress.json').read_text());progress.update(status='COMPLETED_ANALYSIS_QA',completed_at=now)
    ml.write_json(progress,output/'progress.json')
    artifacts=[]
    paths=list(output.rglob('*'))+[reportpath,ml.ROOT/'docs/research/tick_shock/technical_ml_discovery_results.md',
        ml.ROOT/'docs/research/tick_shock/technical_ml_discovery_preregistration.md',
        ml.ROOT/'docs/devlog/2026-09-11-tickshock-technical-ml-discovery.md',
        ml.ROOT/'knowledge/experiments/2026-09-12-tickshock-technical-ml-discovery.md',
        ml.ROOT/'content/seeds/2026-09-12-ml-frequency-is-not-profitability.md']
    paths+=list((ml.ROOT/'tools/tick_shock').glob('*technical_ml_discovery.py'))
    paths+=[Path(ml.core.__file__),ml.ROOT/'tools/tick_shock/analyze_technical_4m2m_real.py']
    for p in sorted(set(paths)):
        if p.is_file() and p.name!='artifact_manifest.csv' and p.suffix!='.log':
            artifacts.append(dict(path=p.relative_to(ml.ROOT).as_posix(),bytes=p.stat().st_size,sha256=ml.sha(p),
                                  purpose='source' if p.suffix=='.py' else 'evidence_or_document'))
    ml.dump(artifacts,output/'artifact_manifest.csv')
    print(json.dumps(result,indent=2),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=ml.OUT)
    finalize(p.parse_args().output)
