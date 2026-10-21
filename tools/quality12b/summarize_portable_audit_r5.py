"""Descriptive closure of fixed portability QA; no parameter or filter search."""
import argparse
import json
from collections import Counter
from pathlib import Path
from analyze_cost_channel import read, write, native, save
from prepare_portable_audit import ROOT, sha, verify


def summarize(package, batch):
    manifest = verify(package)
    status = json.loads((batch / 'status.json').read_text(encoding='utf-8-sig'))
    assert status['status'] == 'COMPLETED' and status['completed_runs'] == 10
    assert status['newly_executed_runs'] == 4 and status['reused_runs'] == 6
    out = batch / 'review'
    out.mkdir(exist_ok=True)
    evidence = [batch / 'status.json', package / 'manifest.json']
    for spec in manifest['runs']:
        a = batch / spec['run_id'] / 'audit.json'
        assert json.loads(a.read_text(encoding='utf-8'))['passed']
        evidence.append(a)
    compile_logs = list(batch.glob('*.compile.log'))
    assert len(compile_logs) == 5
    assert all('Result: 0 errors, 0 warnings' in p.read_text(encoding='utf-16') for p in compile_logs)
    evidence += compile_logs
    rows, monthly, funnel, pairs = [], [], [], []
    for symbol in ('USDJPY', 'EURUSD', 'XAUUSD'):
        d = batch / f'm5_{symbol}_portable'
        a = json.loads((d / 'audit.json').read_text(encoding='utf-8'))
        p = json.loads((d / 'pair_audit.json').read_text(encoding='utf-8'))
        assert all(p[k] for k in ('passed', 'execution_pass', 'cash_pass', 'candidate_pass', 'environment_pass', 'history_pass'))
        t = read(d / 'trades.csv'); h, meta, _ = native(d / 'report.htm')
        assert len(t) == a['actual']['n']
        rows.append(dict(symbol=symbol, **a['actual'], mean_trades_per_month=len(t)/3,
                         equity_drawdown_maximal=h['equity_drawdown_maximal'],
                         risk_percent=meta['inputs']['InpRiskPercent'],
                         sl_atr=meta['inputs']['InpStopLossAtr'], target_r=meta['inputs']['InpTargetRMultiple'],
                         max_spread_atr=meta['inputs']['InpMaxSpreadAtr'], max_hold_bars=meta['inputs']['InpMaxHoldBars'],
                         context_rows=a['context_rows'], context_missing=a['context_missing'],
                         tick_quality=a['quality']['category']))
        for month in ('2023-01', '2023-02', '2023-03'):
            mt = [r for r in t if r['entry_time'].startswith(month)]
            wins = sum(float(r['net']) > 0 for r in mt)
            monthly.append(dict(symbol=symbol, month=month, n=len(mt), wins=wins,
                                net=round(sum(float(r['net']) for r in mt), 2), at_least_20=len(mt)>=20))
        f = read(d / 'funnel.csv', ';'); signals = [r for r in f if r['signal']=='true']
        blocked = [r for r in signals if r['entry_gate']!='true']
        spread_failed = sum(r['spread_allowed']=='false' for r in signals)
        blocked_position = sum(r['spread_allowed']=='true' and int(r['positions'])>0 for r in blocked)
        allowed = sum(r['entry_gate']=='true' for r in signals)
        rejected = a['risk_reasons'].get('NORMALIZED_VOLUME_EXCEEDS_RISK', 0)
        assert allowed == len(t) + rejected
        assert len(signals) == len(blocked) + allowed
        funnel.append(dict(symbol=symbol, evaluated_bars=len(f), signal_bars=len(signals),
                           signal_spread_failed=spread_failed, spread_passed_but_position_open=blocked_position,
                           other_gate_blocked=len(blocked)-spread_failed-blocked_position,
                           entry_gate_passed=allowed, normalized_risk_rejected=rejected, entries=len(t),
                           note='Spread and other causes can overlap; priority here is spread, then open position, then other'))
        pairs.append(dict(symbol=symbol, **{k:p[k] for k in ('execution_pass','cash_pass','environment_pass','history_pass','candidate_pass','passed')},
                          candidate_context_rows=p['candidate_rows_candidate']))
        for name in ('report.htm','trades.csv','risk.csv','risk_audit.json','funnel.csv','pair_audit.json','portable_context.csv','inputs.set'):
            evidence.append(d / name)
    write(out / 'm5_results.csv', rows)
    write(out / 'monthly_results.csv', monthly)
    write(out / 'funnel_summary.csv', funnel)
    write(out / 'pair_summary.csv', pairs)
    save(out / 'evidence.json', dict(status='ENGINEERING_QA_PASSED', sources={str(p.relative_to(ROOT)):sha(p) for p in evidence},
         production_sources_unchanged=True, inherited_runs=6, newly_executed_runs=4,
         symbols_tested=['USDJPY','EURUSD','XAUUSD'], account_currency='USD', optimization=False,
         note='Independent symbol accounts; do not interpret sums as a jointly constrained portfolio'))
    print(json.dumps(dict(status='ENGINEERING_QA_PASSED', output=str(out), m5_trades=sum(r['n'] for r in rows),
                          all_symbols_maintain_20_each_month=all(r['at_least_20'] for r in monthly))))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--package', type=Path, required=True)
    p.add_argument('--batch', type=Path, required=True)
    a = p.parse_args()
    summarize(a.package.resolve(), a.batch.resolve())
