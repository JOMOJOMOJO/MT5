"""Native HTML accounting components of the fixed Wave33 annual positions."""
from __future__ import annotations

import argparse
from collections import Counter
import csv
from datetime import datetime
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re


def rows(path,delimiter=','):
    with path.open(encoding='utf-8-sig',newline='') as f:
        yield from csv.DictReader(f,delimiter=delimiter)


def stamp(value):
    return datetime.fromisoformat(value[:10].replace('.','-')+value[10:])


def number(value):
    return float(value.replace(' ','').replace('\xa0',''))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_csv(path,data):
    if data:
        with path.open('w',encoding='utf-8-sig',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=list(data[0]))
            writer.writeheader();writer.writerows(data)


class TableRows(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows=[];self.row=None;self.cell=None

    def handle_starttag(self,tag,attrs):
        if tag=='tr':
            self.row=[]
        elif tag in ('td','th') and self.row is not None:
            self.cell=[]

    def handle_data(self,data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self,tag):
        if tag in ('td','th') and self.cell is not None:
            self.row.append(''.join(self.cell).strip());self.cell=None
        elif tag=='tr' and self.row is not None:
            self.rows.append(self.row);self.row=None


def native_pairs(path):
    data=path.read_bytes()
    parser=TableRows()
    parser.feed(data.decode('utf-16' if data[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig'))
    deals=[]
    for cells in parser.rows:
        if len(cells)==13 and re.fullmatch(r'\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}',cells[0]) and cells[4] in ('in','out'):
            deals.append(dict(at=stamp(cells[0]).isoformat(' '),ticket=int(cells[1]),symbol=cells[2],
                              kind=cells[3],side=cells[4],volume=number(cells[5]),price=number(cells[6]),
                              order=int(cells[7]),commission=number(cells[8]),swap=number(cells[9]),
                              profit=number(cells[10]),balance=number(cells[11]),comment=cells[12]))
    opened=None;completed=[]
    for deal in deals:
        if deal['side']=='in':
            assert opened is None,'Overlapping positions require a ticket-aware parser'
            opened=deal
        else:
            assert opened is not None
            assert deal['symbol']==opened['symbol']
            assert deal['kind']!=opened['kind']
            assert deal['volume']==opened['volume']
            assert opened['at']<=deal['at']
            completed.append((opened,deal));opened=None
    assert opened is None
    return completed


def measure(data):
    result=dict(n=len(data))
    for component in ('price_profit','commission','swap','net'):
        cash=sum(x[component+'_cash'] for x in data)
        r=sum(x[component+'_r'] for x in data)
        result[component+'_cash']=cash
        result[component+'_r']=r
        result[component+'_mean_r']=r/len(data) if data else None
    result.update(swap_nonzero_n=sum(abs(x['swap_cash'])>.00001 for x in data),
                  swap_debit_n=sum(x['swap_cash']<0 for x in data),
                  swap_credit_n=sum(x['swap_cash']>0 for x in data),
                  swap_debit_cash=sum(x['swap_cash'] for x in data if x['swap_cash']<0),
                  swap_credit_cash=sum(x['swap_cash'] for x in data if x['swap_cash']>0),
                  price_positive_net_negative_n=sum(x['price_profit_cash']>0 and x['net_cash']<0 for x in data))
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path('reports/backtest/runs/wave33_v170_2020'))
    args=parser.parse_args()
    batch=args.root/'20261022_161002_0ef87d9b'
    position_file=args.root/'pattern_review_20261023/resistance/trades.csv'
    integrity_file=args.root/'analysis/native_integrity.json'
    out=args.root/'pattern_review_20261023/mechanisms/cost_decomposition'
    definitions=out/'definitions.json'
    assert definitions.exists(),'Record definitions before aggregation'
    definition_data=json.loads(definitions.read_text(encoding='utf-8'))
    original=list(rows(position_file))
    integrity=json.loads(integrity_file.read_text(encoding='utf-8'))
    trades=[];checks=Counter();hashes={str(x):sha(x) for x in (definitions,position_file,integrity_file)}
    for arm,run_name in [('A','a_extension_on'),('B','b_extension_on')]:
        run=batch/run_name
        config={r['parameter']:r['value'] for r in rows(run/'config.csv',';')}
        assert config['account_currency']==config['symbol_currency_profit']=='USD'
        contract=float(config['contract_size'])
        by_entry={x['entry_at']:x for x in original if x['arm']==arm}
        assert len(by_entry)==sum(x['arm']==arm for x in original)
        exits={x['setup_id']:x for x in rows(run/'events.csv',';') if x['event_type']=='EXIT'}
        pairs=native_pairs(run/'report.htm')
        assert len(pairs)==len(by_entry)
        for entry,exit in pairs:
            assert entry['at'] in by_entry
            old=by_entry.pop(entry['at'])
            close=exits[old['setup_id']]
            direction=1 if old['direction']=='LONG' else -1
            assert entry['kind']==('buy' if direction==1 else 'sell')
            assert exit['at']==old['exit_at']==stamp(close['exit_at']).isoformat(' ')
            assert abs(entry['price']-float(old['entry_price']))<1e-7
            assert abs(exit['price']-float(close['exit_price']))<1e-7
            risk=abs(entry['price']-float(old['sl_price']))*entry['volume']*contract
            assert abs(risk-float(old['risk_cash']))<.00001
            price=entry['profit']+exit['profit']
            assert abs(direction*(exit['price']-entry['price'])*entry['volume']*contract-price)<.011
            commission=entry['commission']+exit['commission']
            swap=entry['swap']+exit['swap']
            net=price+commission+swap
            assert abs(net-float(old['net_cash']))<.00001
            assert abs(net/risk-float(old['net_r']))<.000001
            assert abs(float(close['execution_net_cash'])-net)<.00001
            checks['positions_native_and_ea_matched']+=1
            checks['independent_price_profit_and_risk_matched']+=1
            trade=dict(arm=arm,setup_id=old['setup_id'],entry_at=entry['at'],exit_at=exit['at'],
                       entry_deal=entry['ticket'],exit_deal=exit['ticket'],direction=old['direction'],
                       entry_price=entry['price'],exit_price=exit['price'],sl_price=float(old['sl_price']),
                       volume=entry['volume'],initial_risk_cash=risk,order_room_band=old['order_room_band'],
                       exit_reason=old['exit_reason'])
            for key,value in [('price_profit',price),('commission',commission),('swap',swap),('net',net)]:
                trade[key+'_cash']=value;trade[key+'_r']=value/risk
            trades.append(trade)
        assert not by_entry
        selected=[x for x in trades if x['arm']==arm]
        expected=integrity['runs'][run_name]['native_costs']
        for source,target in [('commission','commission_cash'),('swap','swap_cash'),('profit','price_profit_cash')]:
            assert abs(sum(x[target] for x in selected)-expected[source])<.00001
            checks['existing_native_cost_summary_matched']+=1
        for name in ('report.htm','events.csv','config.csv'):
            hashes[str(run/name)]=sha(run/name)
    assert len(trades)==475
    groups=[]
    for arm in ('A','B'):
        base=[x for x in trades if x['arm']==arm]
        for group in ('ALL','0.25_TO_0.5','0.5_TO_1','GE_1'):
            same=base if group=='ALL' else [x for x in base if x['order_room_band']==group]
            for period in ('ALL','2020H1','2020H2'):
                part=same if period=='ALL' else [x for x in same if (x['entry_at']<'2020-07-01')==(period=='2020H1')]
                groups.append(dict(arm=arm,order_room_band=group,period=period,**measure(part)))
    sign_changed=[x for x in trades if x['price_profit_cash']>0 and x['net_cash']<0]
    middle_ids={'W33_XAUUSD+_15_5_SHORT_1590788700_160','W33_XAUUSD+_5_1_LONG_1593640800_637'}
    chart_examples=[x for x in trades if x['setup_id'] in middle_ids]
    save_csv(out/'positions.csv',trades)
    save_csv(out/'groups.csv',groups)
    save_csv(out/'price_positive_net_negative.csv',sign_changed)
    save_csv(out/'middle_chart_examples.csv',chart_examples)
    summary=dict(definitions=definition_data,checks=dict(checks),input_hashes=hashes,
                 n=len(trades),groups=groups,price_positive_net_negative=sign_changed,
                 middle_chart_examples=chart_examples,script_hash=sha(Path(__file__)))
    (out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report=['# 年間475件の価格損益・明示費用の会計分解', '',
            '原本report.htmのin/out約定を全475件のEA記録へ照合し、価格損益＋手数料＋スワップ＝純損益を確認しました。価格・時刻・方向・数量・現金損益・初期SL金額リスクも一致。既存監査native_costsの年間集計6項目にも一致しています。', '',
            '以下の価格損益は実際に約定した価格間の損益成分です。スプレッド・滑りを含み、費用ゼロの別の戦略成績ではありません。各成分Rの分母はそのポジションの元のSL金額リスクで、足し合わせると実現純損益Rになります。', '',
            '|組|①余地|期間|件数|価格損益 平均R|手数料 平均R|swap 平均R|純損益 平均R|',
            '|---|---|---|---:|---:|---:|---:|---:|']
    for row in groups:
        if row['n']:
            report.append(f"|{row['arm']}|{row['order_room_band']}|{row['period']}|{row['n']}|{row['price_profit_mean_r']:+.3f}|{row['commission_mean_r']:+.3f}|{row['swap_mean_r']:+.3f}|{row['net_mean_r']:+.3f}|")
    report.extend(['', '## スワップと価格プラス／純損失', '', '|組|swap非ゼロ|負担件数 / USD|受取件数 / USD|価格プラスでも純損失|', '|---|---:|---:|---:|---:|'])
    for row in [x for x in groups if x['period']==x['order_room_band']=='ALL']:
        report.append(f"|{row['arm']}|{row['swap_nonzero_n']}|{row['swap_debit_n']} / {row['swap_debit_cash']:.2f}|{row['swap_credit_n']} / {row['swap_credit_cash']:.2f}|{row['price_positive_net_negative_n']}|")
    report.extend(['', '## 追加したmiddle負け図の内訳', '', '|組・entry|価格損益 USD / R|手数料 USD / R|swap USD / R|純損益 USD / R|', '|---|---:|---:|---:|---:|'])
    for x in chart_examples:
        report.append(f"|{x['arm']} {x['entry_at']}|{x['price_profit_cash']:.2f} / {x['price_profit_r']:+.3f}|{x['commission_cash']:.2f} / {x['commission_r']:+.3f}|{x['swap_cash']:.2f} / {x['swap_r']:+.3f}|{x['net_cash']:.2f} / {x['net_r']:+.3f}|")
    report.extend(['', '適用されたスワップと手数料が2020年当時の条件を再現しているかは未照合です。今回保存された設定には当時の日別スワップ条件がなく、現在またはテスト時の条件が過去へ適用された可能性を排除できません。費用の符号・額がEA会計と一致することと、過去条件の正しさは別です。', '',
                   '全位置：positions.csv。①余地3区分と前後半：groups.csv。価格プラス→純損失：price_positive_net_negative.csv。定義・入力ハッシュ・照合結果：definitions.json / summary.json。', '',
                   '再現：`python tools/wave33_visual/annual_cost_decomposition.py`。EA修正、別費用成績、時刻別の探索、再シミュレーションは行っていません。', ''])
    (out/'README.md').write_text('\n'.join(report),encoding='utf-8')
    print(json.dumps(dict(n=len(trades),checks=dict(checks),overall=[x for x in groups if x['period']==x['order_room_band']=='ALL'],middle=[x for x in groups if x['period']=='ALL' and x['order_room_band']=='0.5_TO_1']),ensure_ascii=False))


if __name__=='__main__':
    main()
