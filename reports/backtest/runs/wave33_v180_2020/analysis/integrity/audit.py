"""Read-only independent native cash/coverage audit of fixed Wave33 annual runs."""
from __future__ import annotations
from collections import Counter
import csv
from decimal import Decimal as D
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(ROOT / 'tools/wave33_visual'))
from audit_opposite_exit import Cells, report_deals

OUT = Path(__file__).resolve().parent
NEW = ROOT / 'reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154'
OLD = ROOT / 'reports/backtest/runs/wave33_v170_2020/20261022_161002_0ef87d9b'
checks = 0
failures = []


def check(condition, code, **context):
    global checks
    checks += 1
    if not condition:
        failures.append(dict(code=code, **context))


def number(text):
    return D(text.replace(' ', '').replace('\xa0', '').replace(',', ''))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream, delimiter=';'))


def summary(path):
    raw = path.read_bytes()
    cells = Cells()
    cells.feed(raw.decode('utf-16' if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else 'utf-8-sig'))
    pairs = {}
    for row in cells.rows:
        for i, cell in enumerate(row[:-1]):
            if cell.endswith(':'):
                pairs[cell[:-1]] = row[i+1]
    mapping = dict(period='期間', quality='ヒストリー品質', bars='バー', ticks='ティック',
                   initial_deposit='初期証拠金', net='総損益', gross_profit='総利益', gross_loss='総損失',
                   pf='プロフィットファクター', trades='取引数', deals='約定数',
                   balance_dd='残高最大ドローダウン', equity_dd='証拠金最大ドローダウン',
                   long='ロング (勝率 %)', short='ショート (勝率 %)',
                   wins='勝ちトレード (勝率 %)', losses='負けトレード (負率 %)',
                   win_streak='最大 連勝数 (金額)', loss_streak='最大 連敗数 (金額)')
    result = {key:pairs.get(label) for key,label in mapping.items()}
    for key in ('bars', 'ticks', 'trades', 'deals'):
        result[key] = int(result[key])
    for key in ('initial_deposit', 'net', 'gross_profit', 'gross_loss', 'pf'):
        result[key] = number(result[key])
    return result


def coverage(path, label):
    source = rows(path)
    included = [r for r in source if '2020.01.01' <= r['bar_time'][:10] < '2021.01.01']
    months = Counter(r['bar_time'][:7] for r in included)
    check(set(months) == {f'2020.{m:02}' for m in range(1,13)}, 'all_twelve_months_present', run=label, file=path.name)
    check(all(r['bar_time'] < r['closed_at'] <= r['known_at'] for r in source), 'closed_then_known_order', run=label, file=path.name)
    check(all(a['bar_time'] < b['bar_time'] for a,b in zip(source, source[1:])), 'strict_bar_order', run=label, file=path.name)
    return dict(rows=len(source), in_year_rows=len(included), pre_year_rows=len(source)-len(included),
                first_bar=source[0]['bar_time'], last_bar=source[-1]['bar_time'],
                last_known=source[-1]['known_at'], monthly_rows=dict(sorted(months.items())), sha256=sha(path))


def audit_run(path, label):
    native = summary(path/'report.htm')
    deals = report_deals(path/'report.htm')
    events = rows(path/'events.csv')
    config = {r['parameter']:r['value'] for r in rows(path/'config.csv')}
    fill = {r['fill_at']:r for r in events if r['event_type']=='FILL'}
    exits = {r['setup_id']:r for r in events if r['event_type']=='EXIT'}
    check(len(fill) == sum(r['event_type']=='FILL' for r in events), 'unique_fill_times', run=label)
    check(len(exits) == sum(r['event_type']=='EXIT' for r in events), 'unique_exit_setups', run=label)
    check(config['account_currency']==config['symbol_currency_profit']=='USD', 'usd_quote_account', run=label)
    contract=number(config['contract_size'])
    deposit=native['initial_deposit']
    balance=deposit
    peak=deposit
    max_dd=D(0)
    max_dd_percent=D(0)
    positives=D(0)
    negatives=D(0)
    open_deal=None
    positions=[]
    for deal in deals:
        cash=sum(deal[key] for key in ('profit','commission','swap'))
        balance += cash
        peak=max(peak,balance)
        draw=peak-balance
        max_dd=max(max_dd,draw)
        max_dd_percent=max(max_dd_percent,draw/peak*100)
        positives += max(D(0),cash)
        negatives += min(D(0),cash)
        if deal['entry']=='in':
            check(open_deal is None, 'no_position_overlap', run=label)
            check(deal['time'] in fill, 'native_entry_has_fill', run=label, at=deal['time'])
            open_deal=deal
            continue
        check(deal['entry']=='out' and open_deal is not None, 'paired_native_exit', run=label, at=deal['time'])
        if open_deal is None:
            continue
        entry=open_deal
        source=fill[entry['time']]
        close=exits.get(source['setup_id'])
        check(close is not None, 'fill_has_ea_exit', run=label, setup=source['setup_id'])
        if close is None:
            open_deal=None
            continue
        sign=1 if source['direction']=='LONG' else -1
        price_profit=entry['profit']+deal['profit']
        commission=entry['commission']+deal['commission']
        swap=entry['swap']+deal['swap']
        net=price_profit+commission+swap
        risk=abs(entry['price']-number(source['sl_price']))*entry['volume']*contract
        check(entry['symbol']==deal['symbol']==source['symbol'], 'native_symbol_match',run=label,setup=source['setup_id'])
        check(entry['type']==('buy' if sign==1 else 'sell') and deal['type']!=entry['type'], 'native_direction_match',run=label,setup=source['setup_id'])
        check(entry['volume']==deal['volume'], 'native_volume_match',run=label,setup=source['setup_id'])
        check(entry['price']==number(source['entry_price']), 'native_fill_price_match',run=label,setup=source['setup_id'])
        check(deal['time']==close['exit_at'], 'native_exit_time_match',run=label,setup=source['setup_id'])
        check(deal['price']==number(close['exit_price']), 'native_exit_price_match',run=label,setup=source['setup_id'])
        check(abs(sign*(deal['price']-entry['price'])*entry['volume']*contract-price_profit)<=D('.011'), 'independent_price_profit',run=label,setup=source['setup_id'])
        check(abs(risk-number(close['execution_initial_risk_money']))<=D('.00001'), 'independent_initial_risk',run=label,setup=source['setup_id'])
        check(abs(net-number(close['execution_net_cash']))<=D('.00001'), 'native_cash_matches_exit_event',run=label,setup=source['setup_id'])
        check(abs(net/risk-number(close['realized_r']))<=D('.000001'), 'native_cash_matches_r',run=label,setup=source['setup_id'])
        check('end of test' not in deal['comment'].lower(), 'no_forced_test_end_exit',run=label,setup=source['setup_id'])
        positions.append(dict(run=label,setup_id=source['setup_id'],entry_at=entry['time'],exit_at=deal['time'],
            direction=source['direction'],entry_price=entry['price'],exit_price=deal['price'],volume=entry['volume'],
            price_profit=price_profit,commission=commission,swap=swap,net_cash=net,risk_cash=risk,net_r=net/risk,
            exit_reason=close['exit_reason'],native_comment=deal['comment']))
        open_deal=None
    check(open_deal is None, 'no_terminal_open_position',run=label)
    check(len(positions)==native['trades']==len(fill)==len(exits), 'all_native_positions_accounted',run=label)
    check(len(deals)==native['deals'], 'all_native_deals_accounted',run=label)
    check(sum(p['net_cash'] for p in positions)==native['net']==balance-deposit, 'net_cash_reconciliation',run=label)
    check(positives==native['gross_profit'] and negatives==native['gross_loss'], 'signed_deal_pf_components_match',run=label)
    check(abs(positives/-negatives-native['pf'])<=D('.005'), 'native_pf_rounding',run=label)
    dd_cash=number(native['balance_dd'].split(' ')[0]) if ' ' not in native['balance_dd'].split(' (')[0] else number(native['balance_dd'].split(' (')[0])
    check(abs(max_dd-dd_cash)<=D('.011'), 'independent_balance_max_dd',run=label)
    tp_wins_negative=[p for p in positions if p['price_profit']>0 and p['net_cash']<0]
    journal=Path(json.loads((path.parent/'provenance.json').read_text(encoding='utf-8-sig'))['terminal_root'])/'Tester/logs'
    selected=[]
    for log in sorted(journal.glob('*.log')):
        raw=log.read_bytes()
        text=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig',errors='replace')
        for line in text.splitlines():
            if ('2020.01.01 00:00 - 2021.01.01 00:00  no real ticks, every tick generation used' in line or
                re.search(r'XAUUSD\+,(?:M1|M5):\s+40971991 ticks',line)):
                selected.append(dict(file=str(log),text=line))
    check(native['quality'].startswith('0%'), 'zero_real_tick_share_reported',run=label)
    check(any('no real ticks, every tick generation used' in r['text'] for r in selected), 'native_fallback_message',run=label)
    result=dict(path=str(path.relative_to(ROOT)),summary=native,closed_positions=len(positions),native_pf_exact=positives/-negatives,
                position_net_pf=sum(max(D(0),p['net_cash']) for p in positions)/-sum(min(D(0),p['net_cash']) for p in positions),
                position_net_wins=sum(p['net_cash']>0 for p in positions),position_net_losses=sum(p['net_cash']<0 for p in positions),
                price_profit=sum(p['price_profit'] for p in positions),commission=sum(p['commission'] for p in positions),
                swap=sum(p['swap'] for p in positions),sum_net_r=sum(p['net_r'] for p in positions),
                mean_net_r=sum(p['net_r'] for p in positions)/len(positions),final_balance=balance,
                independently_recomputed_balance_dd=max_dd,independently_recomputed_balance_dd_percent=max_dd_percent,
                equity_dd_independent=False,price_positive_net_negative=tp_wins_negative,
                event_counts=dict(Counter(r['event_type'] for r in events)),generated_tick_evidence=selected,
                source_coverage={name:coverage(path/name,label) for name in ('upper_bars.csv','lower_bars.csv')},
                input_hashes={name:sha(path/name) for name in ('events.csv','config.csv','report.htm','run.json','inputs.set')})
    return result, positions


def dump(value):
    if isinstance(value,D):
        return float(value)
    raise TypeError(type(value).__name__)


def main():
    proof=json.loads((NEW/'provenance.json').read_text(encoding='utf-8-sig'))
    deployment_path=ROOT/'reports/qa/w33v180/deployment.json'
    deployment=json.loads(deployment_path.read_text(encoding='utf-8-sig'))
    check(proof['source_sha256']['Wave33VisualVerifier']==deployment['source_sha256'], 'annual_source_matches_validated_v180')
    for header,value in proof['header_sha256'].items():
        check(value==deployment['header_sha256'].get(header), 'annual_header_matches_validated_v180',header=header)
    runtime=Path(proof['terminal_root'])
    runtime_source=runtime/'MQL5/Experts/Wave33VisualVerifier.mq5'
    runtime_binary=runtime/'MQL5/Experts/Wave33VisualVerifier.ex5'
    check(sha(runtime_source).upper()==proof['source_sha256']['Wave33VisualVerifier'], 'runtime_source_matches_record')
    for header,value in proof['header_sha256'].items():
        header_path=runtime/'MQL5/Include'/header.replace('\\','/')
        check(sha(header_path).upper()==value, 'runtime_header_matches_record',header=header)
    source_provenance=dict(deployment_sha256=sha(deployment_path),source_sha256=proof['source_sha256']['Wave33VisualVerifier'],
         runtime_binary_sha256=sha(runtime_binary),validated_binary_sha256=deployment['binary_sha256'],
         runtime_binary_equals_deployed=sha(runtime_binary).upper()==deployment['binary_sha256'],
         note='The annual runner rebuilt the same source/header set; the recompiled EX5 differs from the earlier deployed binary.')
    results={}
    positions=[]
    for label,path in [('v180_A',NEW/'v180_a_both'),('v180_B',NEW/'v180_b_both'),
                       ('v170_A',OLD/'a_extension_on'),('v170_B',OLD/'b_extension_on')]:
        results[label],found=audit_run(path,label)
        positions.extend(found)
    comparison={}
    for arm in ('A','B'):
        a,b=results['v170_'+arm],results['v180_'+arm]
        check(a['summary']['ticks']==b['summary']['ticks'], 'same_native_tick_count',arm=arm)
        check(a['summary']['period']==b['summary']['period'], 'same_native_period',arm=arm)
        comparison[arm]={key:dict(old=a['summary'][key],new=b['summary'][key]) for key in ('trades','net','pf','balance_dd','equity_dd')}
        comparison[arm]['source_bars_identical']={name:a['source_coverage'][name]['sha256']==b['source_coverage'][name]['sha256'] for name in ('upper_bars.csv','lower_bars.csv')}
        for name,equal in comparison[arm]['source_bars_identical'].items():
            check(equal, 'same_source_bar_observations',arm=arm,file=name)
        old_cfg={r['parameter']:r['value'] for r in rows(Path(a['path'])/'config.csv')}
        new_cfg={r['parameter']:r['value'] for r in rows(Path(b['path'])/'config.csv')}
        comparison[arm]['configuration_differences']={key:[old_cfg.get(key),new_cfg.get(key)] for key in sorted(old_cfg.keys()|new_cfg.keys()) if old_cfg.get(key)!=new_cfg.get(key)}
    result=dict(status='PASS' if not failures else 'FAIL',checks=checks,failures=failures,runs=results,comparison=comparison,source_provenance=source_provenance,
       limitations=['Equity DD is native report evidence; full tick equity path is not independently reconstructed.',
                    '2020 history contains generated ticks only despite requested model 4. Not a real-tick validation.',
                    '12 months are observed, but market closure versus missing historical bars is not independently classified.',
                    'Historical commission/swap correctness for 2020 is unverified; current tester symbol contract costs are preserved.',
                    'Old/new comparison combines two policy additions and intervening tester batching changes; it cannot isolate per-rule causal profitability.'])
    (OUT/'native_integrity.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,default=dump)+'\n',encoding='utf-8')
    with (OUT/'native_positions.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(positions[0]));w.writeheader();w.writerows(positions)
    print(json.dumps(dict(status=result['status'],checks=checks,failures=failures,
       metrics={k:dict(trades=v['summary']['trades'],net=float(v['summary']['net']),pf=float(v['summary']['pf']),equity_dd=v['summary']['equity_dd'],net_pf=float(v['position_net_pf'])) for k,v in results.items()}),ensure_ascii=True,indent=2))


if __name__=='__main__':
    main()
