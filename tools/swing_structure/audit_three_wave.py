"""Audit native MT5 evidence and aggregate closed positions, without optimizing inputs."""
import csv
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / 'reports/qa/three_wave'


def rows(path):
    return list(csv.DictReader(path.open(encoding='utf-8-sig', newline=''))) if path.exists() else []


def dt(s):
    return datetime.strptime(s, '%Y.%m.%d %H:%M:%S')


class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows, self.row, self.cell = [], [], None

    def handle_starttag(self, tag, attrs):
        if tag == 'tr':
            self.row = []
        if tag in ('td', 'th'):
            self.cell = []

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(' '.join(''.join(self.cell).split()))
            self.cell = None
        if tag == 'tr':
            self.rows.append(self.row)


def audit(run):
    signals = rows(run / 'TW_signals.csv')
    deals = rows(run / 'TW_deals.csv')
    exits = rows(run / 'TW_exits.csv')
    parity = rows(run / 'TW_parity.csv')
    issues = []
    preset = (run / 'default.set').read_text(encoding='utf-8-sig')
    expected_rr = float(next(line.split('=', 1)[1] for line in preset.splitlines()
                             if line.startswith('InpRewardRisk=')))
    settings = dict(line.split('=', 1) for line in preset.splitlines() if '=' in line)
    entry_mode = int(settings.get('InpEntryResearchMode', 0))
    stop_mode = int(settings.get('InpStopMode', 0))
    ids = Counter(s['signal_id'] for s in signals)
    if any(v != 1 for v in ids.values()):
        issues.append('duplicate signal candidate ID')
    for s in signals:
        t = dt(s['signal_time'])
        if dt(s['decision_tick']) < t:
            issues.append('decision before signal close: ' + s['signal_id'])
        for k in ('m5_origin_confirmed', 'm5_return_confirmed', 'm5_wave1_confirmed',
                  'm1_reversal_confirmed', 'm1_return_confirmed', 'm1_wave1_confirmed',
                  'm1_wave2_confirmed', 'm1_wave2_return_confirmed'):
            if s[k] and dt(s[k]) > t:
                issues.append('future pivot: ' + k + ' ' + s['signal_id'])
        if entry_mode == 1:
            low, high = float(s['m5_origin']), float(s['m5_wave1_high'])
            if not low < float(s['m1_reversal_low']) <= (low + high) / 2:
                issues.append('invalid M5 fib50 geometry')
            if s['m1_wave2_confirmed'] or s['m1_wave1_confirmed']:
                issues.append('unexpected future M1 wave fields at CHoCH')
            if t != dt(s['m1_choch_time']):
                issues.append('CHoCH entry not on confirmation')
        elif not float(s['m1_reversal_low']) < float(s['m1_wave2_low']) < float(s['m1_wave1_high']):
            issues.append('invalid HL geometry: ' + s['signal_id'])
        retrace = 0 if entry_mode == 1 else (float(s['m1_wave1_high']) - float(s['m1_wave2_low'])) / (float(s['m1_wave1_high']) - float(s['m1_reversal_low'])) * 100
        if abs(retrace - float(s['retracement_pct'])) > 1e-6:
            issues.append('retracement diagnostic error')
        if entry_mode == 2 and t != dt(s['m1_wave2_confirmed']):
            issues.append('HL entry not on confirmation')
        if s['sent'] == 'true':
            if float(s['expected_loss']) > float(s['equity']) * .01 + 1e-8:
                issues.append('planned risk exceeds 1%')
            anchor = ('m1_wave2_low', 'm1_reversal_low', 'm5_origin')[stop_mode]
            if abs(float(s['sl']) - (float(s[anchor]) - .010)) > .00101:
                issues.append('wrong default SL anchor')
            if float(s['rr']) != expected_rr:
                issues.append('RR differs from tester preset')
            if abs(float(s['tp']) - (float(s['entry_price']) + (float(s['entry_price']) - float(s['sl'])) * expected_rr)) > .00051:
                issues.append('wrong configured TP')
            if abs(float(s['lots']) * 100 - round(float(s['lots']) * 100)) > 1e-6:
                issues.append('wrong lot step')
    if any(p['equal'] != 'true' for p in parity):
        issues.append('indicator parity failure')
    if parity and len({p['time'] for p in parity}) != len(parity):
        issues.append('multiple decisions in one M1 bar')

    by_position = defaultdict(list)
    for d in deals:
        by_position[d['position']].append(d)
    accepted = {s['order']: s for s in signals if s['sent'] == 'true'}
    initial_risk = {e['position_id']: float(e['initial_risk']) for e in exits}
    trades, unclosed = [], []
    for position, ds in by_position.items():
        ins = [d for d in ds if d['entry'] == '0']
        outs = [d for d in ds if d['entry'] in ('1', '3')]
        if not ins:
            issues.append('exit without opening fill: ' + position)
            continue
        if any(d['type'] != '0' for d in ins):
            issues.append('non-long entry')
        vin = sum(float(d['volume']) for d in ins)
        vout = sum(float(d['volume']) for d in outs)
        signal = accepted.get(ins[0]['order'])
        if not signal:
            issues.append('fill without accepted candidate: ' + position)
        elif int(ins[0]['time_msc']) / 1000 < (dt(signal['signal_time']) - datetime(1970, 1, 1)).total_seconds():
            issues.append('fill before signal close')
        if abs(vin - vout) > 1e-7:
            unclosed.append(position)
            continue
        pnl = sum(sum(float(d[k]) for k in ('profit', 'commission', 'swap', 'fee')) for d in ds)
        risk = initial_risk.get(position, float(signal['expected_loss']) if signal else 0)
        trades.append(dict(position=position, entry_time=ins[0]['time'], exit_time=outs[-1]['time'],
                           entry_price=sum(float(d['price']) * float(d['volume']) for d in ins) / vin,
                           exit_price=sum(float(d['price']) * float(d['volume']) for d in outs) / vout,
                           lots=vin, profit=pnl, initial_risk=risk, result_R=pnl / risk if risk else None))
    trades.sort(key=lambda t: t['entry_time'])
    for a, b in zip(trades, trades[1:]):
        if dt(b['entry_time']) < dt(a['exit_time']):
            issues.append('overlapping positions')
        if (dt(b['entry_time']) - dt(a['entry_time'])).total_seconds() < 900:
            issues.append('15 minute fill cooldown violated')
    wins = [t for t in trades if t['profit'] > 0]
    losses = [t for t in trades if t['profit'] < 0]
    gross_win = sum(t['profit'] for t in wins)
    gross_loss = -sum(t['profit'] for t in losses)
    balance, peak, max_dd = 10000., 10000., 0.
    monthly = defaultdict(lambda: dict(trades=0, profit=0.))
    for t in sorted(trades, key=lambda t: t['exit_time']):
        balance += t['profit']
        peak = max(peak, balance)
        max_dd = max(max_dd, peak - balance)
        m = monthly[t['exit_time'][:7]]
        m['trades'] += 1
        m['profit'] += t['profit']
    mean = lambda a: statistics.mean(a) if a else None
    metrics = dict(trades=len(trades), win_rate=len(wins) / len(trades) if trades else None,
                   profit_factor=gross_win / gross_loss if gross_loss else None,
                   expectancy=mean([t['profit'] for t in trades]),
                   expectancy_R=mean([t['result_R'] for t in trades if t['result_R'] is not None]),
                   net_profit=sum(t['profit'] for t in trades),
                   max_closed_balance_drawdown=max_dd,
                   average_win_R=mean([t['result_R'] for t in wins]),
                   average_loss_R=mean([t['result_R'] for t in losses]))
    native_report = {}
    for report in run.glob('*.htm'):
        parser = TableParser()
        raw = report.read_bytes()
        parser.feed(raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8-sig'))
        for r in parser.rows:
            for i, c in enumerate(r[:-1]):
                if c.endswith(':') or c.endswith('：'):
                    native_report[c.rstrip(':：')] = r[i+1]
        (run / 'report_fields.json').write_text(json.dumps(native_report, ensure_ascii=False, indent=2), encoding='utf-8')
    metrics['max_equity_drawdown'] = native_report.get('証拠金最大ドローダウン', native_report.get('Equity Drawdown Maximal'))
    metrics['native_history_quality'] = native_report.get('ヒストリー品質', native_report.get('History Quality'))
    native_net = native_report.get('総損益', native_report.get('Total Net Profit'))
    if native_net and abs(float(native_net.replace(' ', '')) - metrics['net_profit']) > .015:
        issues.append('deal net profit does not reconcile to native report')
    log = (run / 'tester.log').read_text(encoding='utf-8-sig') if (run / 'tester.log').exists() else ''
    quality = [line.split('\t')[-1] for line in log.splitlines()
               if any(term in line for term in ('real ticks absent', 'real ticks discarded', 'tick prices mismatch'))]
    result = dict(run=run.name, candidates=len(signals), sent=sum(s['sent'] == 'true' for s in signals),
                  decisions_compared=len(parity), parity_failures=sum(p['equal'] != 'true' for p in parity),
                  reasons=dict(Counter(s['reason'] for s in signals)), metrics=metrics,
                  monthly=dict(monthly), unclosed_positions=unclosed, data_quality_warnings=quality, issues=issues)
    if trades:
        with (run / 'trades.csv').open('w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=list(trades[0])); w.writeheader(); w.writerows(trades)
    with (run / 'monthly.csv').open('w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(['exit_month', 'trades', 'profit'])
        for m, v in sorted(monthly.items()): w.writerow([m, v['trades'], round(v['profit'], 2)])
    (run / 'audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=True))
    return result


if __name__ == '__main__':
    names = sys.argv[1:] or ['parity', 'visual', 'real_ticks']
    results = [audit(QA / n) for n in names if (QA / n / 'TW_signals.csv').exists()]
    if not results or any(r['issues'] for r in results):
        raise SystemExit(1)
