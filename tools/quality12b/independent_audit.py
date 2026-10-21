"""Independent HTML/deal, input and daily gate audit; never invokes MT5.

Does not import the original report analyzer. Daily summaries belong to the
preceding day_reset, NOT the timestamp at which rollover writes the summary.
"""
import argparse
import csv
from collections import Counter, defaultdict
from decimal import Decimal
from hashlib import sha256
from html import unescape
import json
from pathlib import Path
import re


def rows_from_html(path):
    raw = path.read_bytes()
    text = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    return [[re.sub(r'\s+', ' ', unescape(re.sub('<[^>]+>', ' ', cell))).strip()
             for cell in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', row, re.I | re.S)]
            for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', text, re.I | re.S)]


def decimal(value):
    return Decimal(re.sub(r'[\s,]', '', str(value)))


def write_csv(path, rows):
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def run(package, batch):
    inputs = dict(line.split('=', 1) for line in (package/'frozen/quality12b_full.set').read_text().splitlines() if line.startswith('Inp'))
    operational = {'InpTelemetryFileName', 'InpOperatorCommandFile', 'InpStatusFileName'}
    matrix = list(csv.DictReader((package/'run_matrix.csv').open(encoding='utf-8-sig')))
    records, monthly, detail = [], [], {}
    source_hash = sha256((package/'frozen/quality12b_snapshot.mq5').read_bytes()).hexdigest()
    provenance = json.loads((batch/'provenance.json').read_text(encoding='utf-8-sig'))
    assert source_hash.lower() == provenance['source_sha256'].lower()
    for case in matrix:
        d = batch/case['run_id']
        rows = rows_from_html(d/'report.htm')
        cells = [c for row in rows for c in row]
        echoed = dict(c.split('=', 1) for c in cells if re.fullmatch(r'Inp\w+=.*', c))
        assert set(echoed) == set(inputs)
        assert not {k for k in inputs if k not in operational and inputs[k] != echoed[k]}
        ini = dict(line.split('=', 1) for line in (d/'tester_public.ini').read_text().splitlines() if '=' in line)
        for k, v in {'Model':'4', 'Period':'M15', 'Symbol':'USDJPY', 'Deposit':'10000', 'FromDate':case['date_from'], 'ToDate':case['date_to']}.items():
            assert ini[k] == v, (d.name, k)
        section = None
        deals = []
        for row in rows:
            if row == ['Deals'] or row == ['約定']:
                section = 'deals'
            if section == 'deals' and len(row) == 13 and re.match(r'^\d{4}\.\d{2}\.\d{2}', row[0]) and row[3] in ('buy', 'sell'):
                deals.append(row)
        pending, trades = None, []
        for row in deals:
            if row[4] == 'in':
                assert pending is None
                pending = row
            else:
                assert row[4] == 'out' and pending is not None
                assert row[3] != pending[3] and decimal(row[5]) == decimal(pending[5])
                trades.append(dict(entry=pending, exit=row, net=sum((decimal(r[i]) for r in (pending, row) for i in (8, 9, 10)), Decimal(0))))
                pending = None
        assert pending is None
        saved = list(csv.DictReader((d/'trades.csv').open(encoding='utf-8-sig')))
        assert len(saved) == len(trades)
        for a, t in zip(saved, trades):
            assert a['entry_deal_id'] == t['entry'][1] and a['exit_deal_id'] == t['exit'][1]
            assert decimal(a['net']) == t['net']
            assert decimal(a['entry_price']) == decimal(t['entry'][6])
            assert decimal(a['exit_price']) == decimal(t['exit'][6])
        net = sum((t['net'] for t in trades), Decimal(0))
        pos = sum((t['net'] for t in trades if t['net'] > 0), Decimal(0))
        neg = sum((t['net'] for t in trades if t['net'] < 0), Decimal(0))
        metrics = json.loads((d/'metrics.json').read_text(encoding='utf-8-sig'))
        assert net == decimal(metrics['reported']['net_profit'])
        assert pos == decimal(metrics['reported']['gross_profit'])
        assert neg == decimal(metrics['reported']['gross_loss'])
        assert abs(pos/-neg - decimal(metrics['reported']['profit_factor'])) <= Decimal('0.0051')
        assert decimal(deals[-1][11]) == Decimal(10000)+net
        blocks = []
        for p in (d/'journals/Tester').rglob('*.log'):
            if not any(s.startswith('Agent-') for s in p.parts):
                continue
            text = p.read_text(encoding='utf-8-sig')
            starts = list(re.finditer(r'^.*testing of .* started with inputs:.*$', text, re.M))
            for i, match in enumerate(starts):
                if f"from {case['date_from']} 00:00 to {case['date_to']} 00:00" in match[0] and 'quality12b_snapshot.ex5' in match[0]:
                    blocks.append(text[match.start():starts[i+1].start() if i+1 < len(starts) else len(text)])
        assert len(blocks) == 1
        block = blocks[0]
        assert 'thread finished' in block
        journal_inputs = dict(re.findall(r'\b(Inp\w+)=(.*)', block))
        assert all(journal_inputs.get(k, '').strip() == v for k, v in echoed.items())
        balance = re.findall(r'final balance ([\d.]+) USD', block)
        assert len(balance) == 1 and decimal(balance[0]) == Decimal(10000)+net
        errors = [l for l in block.splitlines() if re.search(r'failed market|not enough money|array out of range|zero divide|critical error|initialization failed', l, re.I)]
        fallback = [l for l in block.splitlines() if re.search(r'real ticks (absent|discarded)|every tick generation used', l)]
        telemetry = list(csv.DictReader((d/'telemetry.csv').open(encoding='utf-8-sig'), delimiter=';'))
        active_day, daily = None, []
        for r in telemetry:
            if r['event'] == 'day_reset':
                active_day = r['timestamp'][:10]
            if r['event'] == 'daily_summary':
                assert active_day is not None
                daily.append(dict(day=active_day, **{k:int(r[k]) for k in r if k.startswith('blocked_')}))
        assert len(daily) == len({r['day'] for r in daily})
        months = sorted({r['day'][:7] for r in daily})
        for month in months:
            days = [r for r in daily if r['day'].startswith(month)]
            monthly.append(dict(run_id=d.name, month=month.replace('.', '-'), observed_days=len(days),
                entries=sum(t['entry'][0].startswith(month) for t in trades),
                spread_blocked_bar_checks=sum(r['blocked_spread'] for r in days),
                days_with_60_spread_blocks=sum(r['blocked_spread'] == 60 for r in days),
                daily_loss_blocks=sum(r['blocked_daily_loss'] for r in days),
                equity_cap_blocks=sum(r['blocked_equity_cap'] for r in days)))
        events = Counter(r['event'] for r in telemetry)
        assert events['entry'] == len(trades)
        missing_exits = len(trades)-events['exit']
        forced = [t for t in trades if t['exit'][12] == 'end of test']
        assert missing_exits == len(forced), (d.name, missing_exits, forced)
        detail[d.name] = dict(errors=errors, fallback_evidence=fallback, telemetry_events=dict(events),
            missing_telemetry_exits_explained_by_test_end=missing_exits,
            test_end_exits=[dict(time=t['exit'][0], net=str(t['net'])) for t in forced],
            all_report_inputs_match_frozen=True, all_journal_inputs_match_report=True,
            all_deals_match_saved_csv=True, daily_summary_attribution='preceding day_reset date',
            source_report_sha256=sha256((d/'report.htm').read_bytes()).hexdigest())
        records.append(dict(run_id=d.name, trades=len(trades), net=str(net), pf=float(pos/-neg),
            failed_order_lines=len(errors), spread_blocked_bar_checks=sum(r['blocked_spread'] for r in daily),
            daily_loss_blocks=sum(r['blocked_daily_loss'] for r in daily),
            equity_cap_blocks=sum(r['blocked_equity_cap'] for r in daily),
            telemetry_exit_count=events['exit'], test_end_closures=len(forced),
            last_telemetry_time=telemetry[-1]['timestamp'], accounting_and_input_audit_pass=True))
    out = batch/'independent_audit'
    out.mkdir(exist_ok=True)
    write_csv(out/'run_checks.csv', records)
    write_csv(out/'monthly_gate_checks.csv', monthly)
    (out/'evidence.json').write_text(json.dumps(detail, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(records, indent=2))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('package', type=Path)
    ap.add_argument('batch', type=Path)
    args = ap.parse_args()
    run(args.package, args.batch)
