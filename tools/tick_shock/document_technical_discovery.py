"""Generate the development report from preserved results, without selection."""
import argparse,json
from pathlib import Path
import pandas as pd


def table(frame):
    def value(x):
        if isinstance(x,float):return f'{x:.6g}'
        return str(x).replace('|','/')
    return '\n'.join(['| '+' | '.join(frame.columns)+' |','| '+' | '.join(['---']*len(frame.columns))+' |']+
        ['| '+' | '.join(value(x) for x in row)+' |' for row in frame.itertuples(index=False,name=None)])


def main():
    p=argparse.ArgumentParser();p.add_argument('--analysis',type=Path,required=True);p.add_argument('--candidate-run',type=Path,required=True);a=p.parse_args()
    r=json.loads((a.analysis/'analysis_summary.json').read_text());c=r['candidate']
    actual=json.loads((a.candidate_run/'candidate_reconciliation.json').read_text())
    imp=pd.read_csv(a.analysis/'feature_importance.csv');imp=imp[(imp.method==c['method'])&(imp.distance_index==c['distance_index'])]
    importance=imp.groupby('feature').importance.sum().sort_values(ascending=False).head(11).reset_index()
    frontier=pd.read_csv(a.analysis/'frequency_frontier.csv')
    fold=pd.read_csv(a.analysis/'purged_forward_diagnostics.csv');fold=fold[(fold.model_key==c['model_key'])&(fold.threshold_name==c['threshold_name'])]
    near=pd.read_csv(a.analysis/'development_frontier.csv');near=near[near.model_key==c['model_key']]
    costs=pd.read_csv(a.analysis/'cost_sensitivity.csv');costs=costs[costs.candidate_id==c['candidate_id']]
    stress=actual['stress_02'];qualifies=actual['qa_failures']==0 and stress['trades']>=200 and stress['expectancy_r']>0 and stress['pf_money']>1
    verdict='DEVELOPMENT_TESTER_CANDIDATE_ONLY' if qualifies else 'DEVELOPMENT_CANDIDATE_NOT_REPRODUCED_AS_QUALIFYING_TESTER_RESULT'
    lines=[
        '# Tick-Shock Technical Feature Discovery → EA: development results','',
        'Period: 2025-04-01 to 2025-05-01. April reused development; no OOS/live claim.',
        f'Verdict: `{verdict}`; `OOS_VALIDATION_REQUIRED`; `PRODUCTION_NOT_ELIGIBLE`.','',
        '## Population and design','',
        f"Frozen TAIL_V1_PERSISTENT: 40,217 statistical detections, {r['episodes']:,} episodes, {r['market_clusters']:,} episode market clusters. {r['features']} causal technical features and {r['outcome_rows']:,} LONG/SHORT × distance labels.",
        'The labels are not independent trades. Single-position/pending simulation determines deployable frequency. Episode keys, recognition clocks and cluster provenance match Step15P exactly.',
        'One formal feature/outcome MT5 run: 31m33.199s, 14,085,619 tester ticks, 793 MB terminal/tester memory. Application summary measured average 33.398 MB/max34 MB (different scope).',
        'Real-tick mode was used; generated fallback minutes were NOT_OBSERVED. Absence of a discard warning is not proof of zero generated ticks. All six symbols were monitored. Research orders=0.',
        'Completed M1/M5/M15 bars only; 486 features include relative values and cross-timeframe/shock interactions. Six equal-distance geometries were frozen before outcomes; no fine-grid rescue.',
        'Commission across all six symbols was not observed in the research-only run. Research primary net R deducts an explicitly hypothetical 0.2-pip round-trip allowance; spread is already embedded in Bid/Ask.','',
        '## Search and selection','',
        f"{r['method_geometry_count']} fitted method/geometry pairs, {r['threshold_candidates']} threshold candidates; {r['above_200_positive_candidates']} had >=200 trades and positive development EV; {r['gate_candidates']} passed all preregistered gates.",
        'The 0.25 ATR grid had insufficient executable training labels and was not fitted. Extremely narrow distances mostly fail the preregistered 3-spread guard.',
        f"Selected `{c['candidate_id']}`: {c['trades']} trades, win rate {c['win_rate']:.2%}, net expectancy {c['expectancy_r']:+.6f}R, total {c['total_r']:+.6f}R, PF {c['pf']:.6f}, closed-equity MaxDD {c['maxdd_r']:.6f}R.",
        f"LONG={c['long']}; SHORT={c['short']}; TP={c['tp']}; SL={c['sl']}; TIME={c['timeout']}. Net pips={c['total_pips']:.4f}; these cross-symbol pips are descriptive, not equal-currency P/L.",
        f"Best-five-trades removed: {c['top5_removed_total_r']:+.6f}R. Largest positive-day share {c['max_day_profit_share']:.2%}; {c['positive_segments']}/4 positive segments, minimum segment trades {c['min_segment_trades']}.",
        'The selection rule preferred a depth-3 tree over more complex fits, not the largest fitted EV. The most profitable >=200-trade fit was a LightGBM cell with poor temporal frequency coverage; it was not silently promoted.',
        'At runtime choose the greater LONG/SHORT predicted net R only if >=0; exact ties/both below zero mean NO TRADE. Broker/cost/position/risk checks can still reject an armed signal.','',
        '### Fitted frequency frontier (not a promotion table)','',
        table(frontier[['minimum_trades','status','method','trades','expectancy_r','pf','candidate_gate']]),'',
        '### Selected model nearby thresholds','',
        table(near[['threshold','trades','expectancy_r','pf','candidate_gate']]),'',
        '### Features used by the selected trees','',table(importance),'',
        'Importance means contribution to the fitted trees, not causal direction evidence. Raw ATR values can implicitly identify a symbol. USDJPY contributes a large part of the selected development profit; this is not established currency-independent edge.','',
        '## Geometry and timing','',
        'Selected TP=SL=1.0 × latest completed M5 ATR14 at t0, tick-rounded outward. Reject <3 entry spreads; protection distance checks use Bid for Buy and Ask for Sell. This coarse distance trades reachability against costs; see `path_geometry_diagnostics.csv` and `outcome_funnel.csv` for every original grid.',
        'Target hold900 seconds. Selected research trades: average536.342s, maximum912.677s, no weekend-held trades. Across all unselected raw labels, quote gaps can cause much longer holds (maximum173691.211s). The engine closes at an available quote, never invents a deadline quote.',
        'Actual candidate waits until after dispatcher returns and sends using current SymbolInfoTick. It never sends at a historical replay quote. This stricter deployment adapter can differ from the first-eligible research quote. Server TP price improvement, stop gaps, TIME timing and account-currency conversion also differ.','',
        '### Research cost sensitivity','',table(costs[['extra_cost_pips','trades','expectancy_r','pf']]),'',
        '## Actual same-month MT5 candidate','',
        table(pd.DataFrame([dict(metric=k,actual=v) for k,v in actual['actual'].items()])),'',
        'Actual commission/fee/swap are observed history values, not the hypothetical research allowance. Candidate cost-sensitivity independently adds the 0.2-pip allowance on top of these observed costs.',
        f"Additional0.2pip: {stress['trades']} trades, expectancy {stress['expectancy_r']:+.6f}R, money PF {stress['pf_money']:.6f}.",
        f"Model signal rows={actual['signal_rows']}; QA={actual['checks']} checks/{actual['qa_failures']} failures. Matched trade keys={actual['matched_trade_keys']}, MT5-only={actual['mt5_only']}, Python-only={actual['python_only']}.",
        'Exact signal/feature parity and exact trade/fill parity are different claims. Read `python_trade_comparison.csv` and `candidate_qa.csv`; differences are retained, not replaced with simulated prices. MT5 HTML has floating-equity drawdown; the table above uses closed-trade normalized R and account-money drawdown.','',
        '## Generalization warning','',table(fold[['fold','trades','expectancy_r','pf']]),'',
        'These purged forward diagnostics are all negative for the chosen rule. The fitted selected-cluster bootstrap95% CI is approximately [-0.0240,+0.1635]R and is not selection-adjusted. Development positivity does NOT establish prospective positive expectancy.',
        'The user explicitly allowed a development-month EA candidate. Accordingly the EA was built, but no production promotion, OOS claim, live/demo order or additional period search is made. The next gate is frozen-model testing on an unseen period, not retuning this April result.','',
        '## QA and reproduction','',
        'Feature harness24 PASS; execution harness35 PASS; Python specification15 PASS; full MQL model parity3967/3967. Independent research recalculation32 PASS; provenance18 PASS. Deterministic Python replay23 artifacts: byte/SHA differences0.',
        'Formal and candidate runs retain exact-source ZIP bundles whose individual bytes match the recorded SHA, plus EX5, preset, terminal/editor hashes, compile log, report and journal excerpt. The candidate-only snapshot callback was added after the formal run; the exact prior sources remain in its bundle/owning commit.',
        'See `technical_discovery_implementation.md` for commands and causal definitions, and `technical_candidate_usage.md` for tester-only operation. No existing Step3 fixture/expected is edited. Unrelated Step15G dirty work is not included in these commits.','',
        '## Primary paths','',
        '- Research: `reports/backtest/runs/20260909_tstech_discovery_r2_202504/`',
        '- Analysis: `reports/analysis/tick_shock/technical_discovery/`',
        '- Deterministic replay: `reports/analysis/tick_shock/technical_discovery_replay/`',
        f'- Candidate tester: `{a.candidate_run.as_posix()}/`',
        '- EA: `mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnicalCandidate.mq5`',
        '- Model: `mql/Include/TickShock/TickShockTechnicalModel.mqh`','']
    dest=Path('docs/research/tick_shock/technical_discovery_results.md');dest.write_text('\n'.join(lines),encoding='utf-8')
    (a.candidate_run/'summary.md').write_text('# Candidate tester summary\n\nSee [research results](../../../../docs/research/tick_shock/technical_discovery_results.md) and candidate_reconciliation.json.\n\n'+table(pd.DataFrame([dict(metric=k,observed=v,extra_02=actual['stress_02'][k]) for k,v in actual['actual'].items()]))+'\n',encoding='utf-8')
    print(dest)


if __name__=='__main__':main()
