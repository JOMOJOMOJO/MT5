"""Assemble the completed locked test report without any refitting."""
import json
import re
from datetime import datetime
from pathlib import Path
import numpy as np
import pandas as pd
from analyze_technical_4m2m_real import ROOT, OUT, sha
from evaluate_technical_4m2m_holdout import VALIDATION, verify_freeze
import analyze_technical_discovery as core


def main():
    model=verify_freeze()
    months=pd.read_csv(VALIDATION/'months.csv',encoding='utf-8-sig')
    assert len(months)==2 and (months.status=='COMPLETED').all()
    allchecks=[];results=[];costs=[];trades=[];comparisons=[]
    signals=pd.read_csv(OUT/'locked_holdout/signals.csv')
    for month in (202505,202506):
        run=VALIDATION/str(month)
        q=pd.read_csv(run/'qa_checks.csv');q['month']=month;allchecks.append(q)
        result=json.loads((run/'reconciliation.json').read_text());assert result['qa_failures']==0
        results.append(dict(month=month,**result['actual']))
        comparisons.append(dict(month=month,matched=result['python_matched'],mt5_only=result['mt5_only'],python_only=result['python_only']))
        costs.append(pd.read_csv(run/'actual_cost_sensitivity.csv'))
        t=pd.read_csv(run/'candidate_trades.csv');t['month']=month;t['t0_msc']=t.signal_msc
        t=t.merge(signals[['symbol','t0_msc','market_cluster_id']],on=['symbol','t0_msc'],validate='one_to_one')
        trades.append(t)
    q=pd.concat(allchecks,ignore_index=True)
    core.dump_csv(q,VALIDATION/'qa_checks.csv')
    core.dump_csv(results,VALIDATION/'actual_monthly.csv')
    core.dump_csv(pd.concat(costs,ignore_index=True),VALIDATION/'cost_sensitivity.csv')
    core.dump_csv(comparisons,VALIDATION/'python_mt5_comparison_counts.csv')
    resources=[]
    samples=pd.read_csv(VALIDATION/'runtime_samples.csv',encoding='utf-8-sig')
    for month in (202505,202506):
        run=VALIDATION/str(month)
        evidence=(run/'execution_journal_excerpt.txt').read_text(encoding='utf-8')
        elapsed=re.search(r'Test passed in (\d+):(\d+):(\d+\.\d+)',evidence)
        memory=re.search(r'(\d+) Mb memory used',evidence)
        observed=samples[(samples.month.astype(str)==str(month))&(samples.metatester_processes==1)]
        resources.append(dict(month=month,tester_seconds=int(elapsed[1])*3600+int(elapsed[2])*60+float(elapsed[3]),
                              tester_reported_memory_mb=int(memory[1]),sampled_process_rss_mean_bytes=float(observed.working_set_bytes.mean()),
                              sampled_process_rss_max_bytes=float(observed.working_set_bytes.max()),
                              features_bytes=(run/'technical_features.csv').stat().st_size,
                              outcomes_bytes=(run/'technical_outcomes.csv').stat().st_size,
                              trades_bytes=(run/'candidate_trades.csv').stat().st_size,
                              sampling_note='30s samples, singleton visible MetaTester process; sampling began partway through May'))
    core.dump_csv(resources,VALIDATION/'run_resources.csv')
    t=pd.concat(trades,ignore_index=True).sort_values('entry_msc')
    clustered=t.groupby(['month','market_cluster_id']).net_r.agg(['sum','count'])
    bootstrap=[]
    rng=np.random.default_rng(20260911)
    for label,g in [('BOTH',clustered)]+[(str(m),clustered.loc[m]) for m in (202505,202506)]:
        ids=rng.integers(0,len(g),size=(10000,len(g)))
        means=g['sum'].to_numpy()[ids].sum(axis=1)/g['count'].to_numpy()[ids].sum(axis=1)
        bootstrap.append(dict(period=label,clusters=len(g),trades=int(g['count'].sum()),replicates=10000,
                              expectancy_r=float(g['sum'].sum()/g['count'].sum()),ci_low=float(np.quantile(means,.025)),ci_high=float(np.quantile(means,.975)),
                              cost='actual observed broker costs; not hypothetical pip stress',
                              limitation='clusters sampled iid; multi-day dependence not removed; no live-readiness claim'))
    core.dump_csv(bootstrap,VALIDATION/'cluster_bootstrap.csv')
    findings=[dict(finding='FREQUENCY_BELOW_OBJECTIVE',status='NOT_MET',observed='May 46 / June 25, below 200 per month'),
              dict(finding='STRICT_900_SECOND_HOLD',status='OBSERVED_LIMITATION',observed=f"maximum {t.hold_seconds.max():.3f} seconds; {int((t.hold_seconds>900).sum())} trades exceed 900 seconds"),
              dict(finding='DEVELOPMENT_STABILITY',status='NOT_MET',observed='0 of 108 candidates passed all preregistered gates'),
              dict(finding='LIVE_EXECUTION',status='NOT_OBSERVED',observed='tester-only EA; no live or demo chart orders')]
    core.dump_csv(findings,VALIDATION/'limitations.csv')
    # Deterministic training rerun comparisons.
    replay=OUT.with_name(OUT.name+'_replay');repro=[]
    for name in ('frozen_model.json','TickShockTechnicalModel.mqh','inner_validation.csv','selection_frontier.csv','fitted_training_trades.csv','feature_catalog.csv'):
        repro.append(dict(path=name,sha256=sha(OUT/name),replay_sha256=sha(replay/name),status='PASS' if sha(OUT/name)==sha(replay/name) else 'FAIL'))
    core.dump_csv(repro,OUT/'deterministic_replay_checks.csv')
    assert all(r['status']=='PASS' for r in repro)
    money=t.net_profit.to_numpy(float);rs=t.net_r.to_numpy(float)
    equity=np.r_[0,np.cumsum(money)];r_equity=np.r_[0,np.cumsum(rs)]
    total=dict(trades=len(t),net_profit=float(money.sum()),expectancy_r=float(rs.mean()),
               win_rate=float((money>0).mean()),pf_money=float(money[money>0].sum()/-money[money<0].sum()),
               maxdd_closed_money=float((np.maximum.accumulate(equity)-equity).max()),
               maxdd_closed_r=float((np.maximum.accumulate(r_equity)-r_equity).max()),
               commission=float(t.commission.sum()),fee=float(t.fee.sum()),swap=float(t.swap.sum()))
    summary=dict(verdict='NOT_ELIGIBLE_FOR_PRODUCTION',frequency_objective_met=bool(all(r['trades']>=200 for r in results)),
                 positive_holdout=bool(total['net_profit']>0),selection='DIAGNOSTIC_CANDIDATE',model_sha256=sha(OUT/'frozen_model.json'),
                 actual=total,qa_failures=int((q.status!='PASS').sum()),live_trading_enabled=False,
                 strict_hold_limit_violations=int((t.hold_seconds>900).sum()),max_hold_seconds=float(t.hold_seconds.max()))
    core.write_json(summary,VALIDATION/'summary.json')
    report=['# 1～4月学習EA：5～6月MT5検証結果','',
            '## 結論','',
            '学習結果を固定した別EAを作成し、5月・6月のStrategy Tester検証を完了した。',
            '**本番候補には昇格しない。** 月200取引という目的を満たさない診断用候補であり、',
            '1～4月内の選定時点でも安定性・近隣しきい値の合格条件を満たす候補は0だった。','',
            '## 実MT5成績（観測されたcommission・fee・swapを含む）','',
            '|期間|取引数|勝率|損益 USD|Expectancy R|PF（金額）|最大確定損益DD USD|',
            '|---|---:|---:|---:|---:|---:|---:|']
    for r in results:
        report.append(f"|{r['month']}|{r['trades']}|{r['win_rate']:.1%}|{r['net_profit']:+.2f}|{r['expectancy_r']:+.4f}|{r['pf_money']:.3f}|{r['maxdd_closed_money']:.2f}|")
    report+=['',f"合計：{total['trades']}取引、{total['net_profit']:+.2f} USD、Expectancy {total['expectancy_r']:+.4f}R。",
             '各月10,000 USDから独立開始。結合DDは月別曲線を接続した固定リスク診断で、連続口座運用やequity DDとは異なる。','',
             '## 作ったEA','',
             '`mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnical4m2mCandidate.mq5` / `.ex5`','',
             '- frozen TAIL_V1_PERSISTENT detector、486因果的特徴量、確定M1/M5/M15 bar。',
             '- LONG/SHORT別正則化ロジスティック回帰。期待Rの高い側が0.1R以上なら選択、他はNO TRADE。',
             '- TP＝SL＝2×確定M5 ATR14、最低3スプレッド、900秒から時間決済を要求（下記の実超過あり）。',
             '- 全通貨合計1ポジション。最大10 USDリスク（equityの0.25%上限も適用）。',
             '- Strategy Tester以外は初期化失敗。実運用EAではない。','',
             'モデル選定・特徴量の説明は `docs/research/tick_shock/technical_4m2m_learning_results.md`。',
             '主要係数はM5 EMA価格乖離/傾き、M15 SMA傾き、RSI変化、時間足間interaction等。',
             'モデル係数は独立した利益要因や因果関係を意味しない。','',
             '## 検証手順と証跡','',
             '1. 1～2月学習→3月評価、1～3月学習→4月評価。108候補を固定gridで比較。',
             '2. 診断候補を1つ固定し、1～4月へ再学習。5～6月は一切選定に不使用。',
             '3. モデルJSON・MQL・EA・presetのハッシュを保存。モデル独立再計算、MT5推論11,230件一致。',
             '4. 初回のcallback接続漏れを無効試行として保存。既存callbackを接続し、1月2日の実処理3件一致を確認。',
             '5. 同じ重み/特徴/しきい値/geometryで5月→6月をModel4、EURUSD M1、Bybit-Liveで実行。',
             '6. 実約定・CSV・HTML損益・独立推論・因果時刻・数量を照合。','',
             f"集約QA：{len(q)}項目、FAIL {summary['qa_failures']}。最終compileはcandidate/harnessとも0 errors / 0 warnings。",
             '取引件数までの完全一致を推論一致と混同しない。`python_mt5_comparison_counts.csv` と月別比較CSVを参照。',
             '現在quoteでの注文、serverのTP/SL、時間決済の次tickによる差は比較CSVへ残した。','',
             '5月はPythonの47件に対してMT5は46件。差の1件はUSDJPYの `NO_ENTRY_TIMEOUT`。6月は両方25件。',
             '全3,889エピソードの方向/スコアと特徴量は一致し、損益・約定が完全一致したという意味ではない。',
             f"実保有時間は最大{t.hold_seconds.max():.3f}秒、900秒超過は{int((t.hold_seconds>900).sum())}件。厳密な15分以内は未達。",
             'これは `hold_time_overruns.csv` と `limitations.csv` へ残し、PASSへ含めない。コードを結果に合わせて修正していない。','',
             f"実commission合計 {total['commission']:.2f} USD、fee {total['fee']:.2f} USD、swap {total['swap']:.2f} USD。",
             'ゼロは当該testerで観測されたdealの値であり、他口座やライブでもゼロとの保証ではない。',
             '追加0/0.1/0.2/0.5/1 pip往復ストレスは `cost_sensitivity.csv`。既存Bid/Askスプレッドとは別の仮定。','',
             '実行時間は5月22分18.676秒、6月16分19.573秒。MT5報告メモリは787/843MB。',
             'CSV容量・採取したプロセスメモリは `run_resources.csv`。再学習や無効試行の時間はこのtester時間に含めない。','',
             '## 制約と次の判断','',
             '- 1～4月での再学習後、頻度が月28～77件へ落ちた。月200件の成立は未確認。',
             '- 月内fitted利益だけで候補を採用すると、この不安定性を見落とす。',
             '- January/April旧pool警告は保持。Technical収集だけの合格をglobal VALIDATEDへ昇格しない。',
             '- 2月/3月の一部区間に生成ティック置換が記録されている。純粋実ティック100%の主張はしない。',
             '- 月別起動warmup・月末censoringがある。May/Juneは今回の固定holdoutであり、普遍的未使用OOSとは呼ばない。',
             '- partial fill・ライブ約定・再起動復元・他broker運用は本試験で保証しない。',
             '- 同じ5～6月に合わせたしきい値調整・追加候補の探索は行っていない。',
             '- この1候補を資金投入対象にしない。目的を達成するには、今回の失敗理由を踏まえた別の事前仕様と新しい検証期間が必要。','',
             '## 主要ファイル','',
             '- `reports/analysis/tick_shock/technical_4m2m_real/`：学習・選定・固定モデル・独立再計算。',
             '- `reports/backtest/batches/tstech_4m2m_validation_r2_20260911/202505/`：5月実MT5。',
             '- `reports/backtest/batches/tstech_4m2m_validation_r2_20260911/202506/`：6月実MT5。',
             '- 同batchの `actual_monthly.csv`、`qa_checks.csv`、`cluster_bootstrap.csv`、`source_hashes.csv`。',
             '- `docs/devlog/2026-09-11-tickshock-4m2m-ea-validation.md`：実装経緯と無効試行。','']
    text='\n'.join(report)
    (VALIDATION/'summary.md').write_text(text,encoding='utf-8')
    (ROOT/'docs/research/tick_shock/technical_4m2m_validation_results.md').write_text(text,encoding='utf-8')
    state=json.loads((VALIDATION/'status.json').read_text(encoding='utf-8-sig'))
    state.update(status='COMPLETED_QA_WITH_LIMITATIONS',detail='Both months tested and reconciled; frequency/edge not established; hold overruns retained',
                 qa_completed_at=datetime.now().astimezone().isoformat())
    core.write_json(state,VALIDATION/'status.json')
    artifacts=[]
    for folder in (OUT,VALIDATION,ROOT/'mql/Include/TickShock4m2mFrozen'):
        for path in sorted(folder.rglob('*')):
            if path.is_file() and path.name not in ('artifact_manifest.csv','runtime_samples.csv','finalization.log'):
                artifacts.append(dict(path=str(path.relative_to(ROOT)),sha256=sha(path),bytes=path.stat().st_size))
    extra=['mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnical4m2mCandidate.mq5',
           'mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnical4m2mCandidate.ex5',
           'mql/Experts/tests/ExpectedValue_TickShock_Technical4m2mParityHarness.mq5',
           'mql/Experts/tests/ExpectedValue_TickShock_Technical4m2mParityHarness.ex5',
           'docs/research/tick_shock/technical_4m2m_real_preregistration.md',
           'docs/research/tick_shock/technical_4m2m_learning_results.md',
           'docs/research/tick_shock/technical_4m2m_validation_results.md',
           'docs/devlog/2026-09-11-tickshock-4m2m-ea-validation.md']
    extra += [str(p.relative_to(ROOT)) for p in (ROOT/'tools/tick_shock').glob('*technical_4m2m*.py')]
    extra += [str(p.relative_to(ROOT)) for p in (ROOT/'tools/tick_shock').glob('*technical_4m2m*.ps1')]
    for name in extra:
        p=ROOT/name
        artifacts.append(dict(path=name,sha256=sha(p),bytes=p.stat().st_size))
    core.dump_csv(artifacts,VALIDATION/'artifact_manifest.csv')
    print(json.dumps(summary,indent=2))


if __name__=='__main__':main()
