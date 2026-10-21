"""Exact same-fill cost attribution and position-ID based portfolio audit."""
import argparse,csv,json,re,math
from collections import defaultdict,Counter
from datetime import datetime,timezone
from pathlib import Path
from analyze_reports import Rows,decode_report,headers,number
from compare_reproduction import compare
from tick_quality import audit,execution_blocks

ROOT=Path(__file__).resolve().parents[2]
def read(p,delimiter=','):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f,delimiter=delimiter))
def write(p,rows):
    if not rows:return
    with p.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def save(p,x):p.write_text(json.dumps(x,indent=2,ensure_ascii=False,allow_nan=False)+'\n',encoding='utf-8')
def f(r,k):return float(r[k])

def components(side,entry,exit_,bid0,ask0,bid1,ask1,risk):
    assert side in (-1,1) and risk>0 and bid0>0 and bid1>0 and ask0>=bid0 and ask1>=bid1
    midpoint=side*((bid1+ask1-bid0-ask0)/2)
    spread=(ask0-bid0+ask1-bid1)/2
    qin=ask0 if side==1 else bid0;qout=bid1 if side==1 else ask1
    residual=side*((entry-qin)+(qout-exit_))
    gross=side*(exit_-entry)
    assert math.isclose(midpoint-spread-residual,gross,abs_tol=1e-8)
    return dict(mid_move_r=midpoint/risk,spread_cost_r=spread/risk,
                execution_residual_cost_r=residual/risk,fill_price_r=gross/risk)

def native(path):
    parser=Rows();parser.feed(decode_report(path.read_bytes()));h=headers(parser.rows)
    period=re.fullmatch(r'(\S+)\s*\((\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})\)',h['period']);assert period
    inp={};deals=[];section=''
    for row in parser.rows:
        if len(row)==1 and row[0] in ('Deals','約定'):section='deals';continue
        for cell in row:
            m=re.fullmatch(r'(Inp\w+)=(.*)',cell)
            if m:assert m[1] not in inp;inp[m[1]]=m[2]
        if section=='deals' and row and re.match(r'^\d{4}\.\d{2}\.\d{2}',row[0]):
            assert len(row)==13,row
            if row[3]=='balance':continue
            assert row[3] in ('buy','sell'),row
            deals.append(dict(deal=row[1],symbol=row[2],price=float(number(row[6])),volume=float(number(row[5])),
                profit=float(number(row[10])),commission=float(number(row[8])),swap=float(number(row[9]))))
    meta=dict(expert=h['expert'],from_date=period[2],to_date=period[3],model_quality=h['model_quality'],inputs=inp)
    return h,meta,deals

def pair(deals):
    groups=defaultdict(list)
    for r in deals:groups[r['position_id']].append(r)
    trades=[]
    for pos,rows in groups.items():
        entries=[r for r in rows if r['entry_kind']=='0'];exits=[r for r in rows if r['entry_kind'] in ('1','3')]
        assert len(entries)+len(exits)==len(rows),'Reversal deal unsupported'
        assert entries and exits,('Unclosed position',pos)
        assert len({r['symbol'] for r in rows})==1
        ev=sum(f(r,'volume') for r in entries);xv=sum(f(r,'volume') for r in exits)
        assert math.isclose(ev,xv,abs_tol=1e-8),(pos,ev,xv)
        side=1 if entries[0]['type']=='0' else -1
        assert all(r['type']==entries[0]['type'] for r in entries)
        assert all(r['type']!=entries[0]['type'] for r in exits)
        def weighted(rs,k):return sum(f(r,k)*f(r,'volume') for r in rs)/sum(f(r,'volume') for r in rs)
        entry=weighted(entries,'price');exit_=weighted(exits,'price');sl=weighted(entries,'sl')
        risk=side*(entry-sl);assert risk>0
        first=min(int(r['time_msc']) for r in entries);last=max(int(r['time_msc']) for r in exits);assert last>=first
        t=dict(position_id=pos,symbol=entries[0]['symbol'],side='buy' if side==1 else 'sell',
            entry_time=datetime.fromtimestamp(first/1000,timezone.utc).strftime('%Y-%m-%d %H:%M:%S'),
            exit_time=datetime.fromtimestamp(last/1000,timezone.utc).strftime('%Y-%m-%d %H:%M:%S'),
            entry_price=entry,exit_price=exit_,initial_sl=sl,risk_price=risk,volume=ev,holding_hours=(last-first)/3600000,
            profit=sum(f(r,'profit') for r in rows),commission=sum(f(r,'commission') for r in rows),
            swap=sum(f(r,'swap') for r in rows),fee=sum(f(r,'fee') for r in rows))
        t['net']=t['profit']+t['commission']+t['swap']+t['fee'];t['year']=t['entry_time'][:4]
        t['quote_complete']=all(r['quote_status'] in ('CURRENT_EXACT_MSC','HISTORY_EXACT_MSC') and r['time_msc']==r['quote_msc'] for r in rows)
        t.update(mid_move_r='',spread_cost_r='',execution_residual_cost_r='',fill_price_r=side*(exit_-entry)/risk,
                 midpoint_usd='',spread_usd='',residual_usd='',net_reconstructed_usd='')
        if t['quote_complete']:
            t.update(components(side,entry,exit_,weighted(entries,'bid'),weighted(entries,'ask'),weighted(exits,'bid'),weighted(exits,'ask'),risk))
            # USD attribution scale inferred from actual deal profit. Not an entry-time risk estimate.
            if abs(t['fill_price_r'])>1e-10:
                scale=t['profit']/t['fill_price_r'];assert scale>0
                t['midpoint_usd']=t['mid_move_r']*scale;t['spread_usd']=t['spread_cost_r']*scale
                t['residual_usd']=t['execution_residual_cost_r']*scale
                t['net_reconstructed_usd']=t['midpoint_usd']-t['spread_usd']-t['residual_usd']+t['commission']+t['swap']+t['fee']
                assert math.isclose(t['net'],t['net_reconstructed_usd'],abs_tol=1e-7)
        trades.append(t)
    return sorted(trades,key=lambda r:(r['entry_time'],r['position_id']))

def metrics(rows):
    net=[float(r['net']) for r in rows];win=sum(x for x in net if x>0);loss=-sum(x for x in net if x<0)
    valid=[r for r in rows if r['quote_complete'] in (True,'True')]
    def avg(k):return sum(float(r[k]) for r in valid)/len(valid) if valid else None
    return dict(n=len(rows),net=sum(net),pf=win/loss if loss else None,win_rate=sum(x>0 for x in net)/len(net) if net else None,
      mean_fill_r=sum(float(r['fill_price_r']) for r in rows)/len(rows) if rows else None,
      exact_quote_n=len(valid),mean_mid_move_r=avg('mid_move_r'),mean_spread_cost_r=avg('spread_cost_r'),
      mean_execution_residual_r=avg('execution_residual_cost_r'),commission=sum(float(r['commission']) for r in rows),
      swap=sum(float(r['swap']) for r in rows),fee=sum(float(r['fee']) for r in rows))

def audit_retry_events(logs):
    pending=set();rejected=0;marked=0;resolved=Counter()
    for i,r in enumerate(logs):
        key=(r['symbol'],r['signal_bar']);event=r['event']
        if event in ('SEND_RESULT','SEND_FAILED'):
            assert int(r['retcode']) in (10009,10010,10018),('Unexpected order rejection',r)
            if int(r['retcode'])==10018:
                rejected+=1
                assert i+1<len(logs) and logs[i+1]['event']=='RETRY_MARKET_CLOSED',('Market-closed signal consumed',key)
                assert (logs[i+1]['symbol'],logs[i+1]['signal_bar'])==key
        elif event=='RETRY_MARKET_CLOSED':
            assert key not in pending,('Repeated send without resumption',key)
            assert i>0 and logs[i-1]['retcode']=='10018'
            pending.add(key);marked+=1
        elif event in ('RETRY_RESUMED','RETRY_EXPIRED','RETRY_END_CENSORED'):
            assert key in pending,('Unmatched retry transition',key,event)
            pending.remove(key);resolved[event]+=1
        if event in ('BAR_EVALUATED','SIGNAL'):
            assert datetime.strptime(r['signal_bar'],'%Y.%m.%d %H:%M:%S')<datetime.strptime(r['time'],'%Y.%m.%d %H:%M:%S')
    assert rejected==marked and not pending,('Unresolved market-closed retry',pending)
    return dict(rejected=rejected,marked=marked,resolved=dict(resolved))

def check(run,spec):
    h,meta,nd=native(run/'report.htm');assert h['broker']=='Vantage Trading Ltd' and h['currency']=='USD'
    assert meta['from_date']==spec['date_from'] and meta['to_date']==spec['date_to']
    expected=dict(line.strip().split('=',1) for line in (run/'inputs.set').read_text().splitlines() if '=' in line)
    assert set(expected)==set(meta['inputs'])
    for k,v in expected.items():
        if v.lower() in ('true','false'):assert meta['inputs'][k].lower()==v.lower(),k
        else:
            try:assert float(v)==float(meta['inputs'][k]),k
            except ValueError:assert v==meta['inputs'][k],k
    q=read(run/'cost.csv',';');assert len({r['deal'] for r in q})==len(q)
    byid={r['deal']:r for r in q};assert set(byid)=={r['deal'] for r in nd}
    for d in nd:
        r=byid[d['deal']];assert r['symbol']==d['symbol']
        for k in ('price','volume','profit','commission','swap'):assert math.isclose(f(r,k),d[k],abs_tol=1e-7),(d['deal'],k)
    trades=pair(q);write(run/'trades_cost_decomposition.csv',trades)
    actual=metrics(trades);assert math.isclose(actual['net'],float(number(h['net_profit'])),abs_tol=0.011)
    assert len(trades)==int(number(h['trade_count']))
    quality=audit(meta,run/'journals');assert quality['matching_execution_blocks']==1 and quality['test_finished_in_block']
    block='\n'.join(execution_blocks(meta,run/'journals')[0])
    assert not re.search(r'array out of range|zero divide|DQ_FATAL|DC_FATAL|DC_FINISH errors=[1-9]',block,re.I)
    result=dict(passed=True,actual=actual,quality=quality,reported_drawdown=h.get('equity_drawdown_maximal'))
    if spec['kind']=='cost':
        parity=compare(ROOT/spec['reference'],run/'report.htm',require_real_ticks=False)
        save(run/'execution_parity.json',parity)
        assert parity['passed'] and parity['classification']=='EXACT_EXECUTIONS_AND_COSTS','Baseline execution changed'
        result['parity']=True
    else:
        logs=read(run/'telemetry.csv',';')
        result['retry_audit']=audit_retry_events(logs)
        entry_days=[(t['symbol'],t['entry_time'][:10]) for t in trades]
        assert len(entry_days)==len(set(entry_days)),'Duplicate symbol/day entry'
        observed={r['symbol'] for r in logs};assert observed==set(expected['InpSymbols'].split(',')),observed
        coverage=[]
        for symbol in sorted(observed):
            times=sorted({datetime.strptime(r['time'],'%Y.%m.%d %H:%M:%S') for r in logs if r['symbol']==symbol and r['event']=='BAR_EVALUATED'})
            assert times,('No bar evaluation',symbol)
            start=datetime.strptime(spec['date_from'],'%Y.%m.%d');end=datetime.strptime(spec['date_to'],'%Y.%m.%d')
            # Operational coverage guard, not a trading parameter or profit gate.
            assert (times[0]-start).days<=14 and (end-times[-1]).days<=14,('Incomplete symbol coverage',symbol)
            coverage.append(dict(symbol=symbol,first_evaluation=str(times[0]),last_evaluation=str(times[-1]),evaluated_days=len({t.date() for t in times})))
        write(run/'coverage.csv',coverage)
        plans=[r for r in logs if r['event']=='RISK_PLAN']
        assert all(f(r,'risk_money')<=f(r,'equity')*float(expected['InpRiskPercent'])/100+1e-6 for r in plans)
        assert all(f(r,'tp')==0 for r in q if r['entry_kind']=='0')
        assert 'DC_FINISH errors=0' in block
        result['events']=dict(Counter(r['event'] for r in logs));result['risk_plans']=len(plans)
        # A functioning short QA sample is required before longer runs; no outcome gate.
        if spec['run_id']=='daily_smoke':assert trades,'Smoke produced no trades; stop for diagnosis'
    save(run/'audit.json',result)
    print(json.dumps(dict(run=spec['run_id'],passed=True,n=len(trades),quote_n=actual['exact_quote_n'])))

def aggregate(batch,package):
    manifest=json.loads((package/'manifest.json').read_text(encoding='utf-8'));rows=[]
    for spec in manifest['runs']:
        run=batch/spec['run_id'];assert json.loads((run/'audit.json').read_text())['passed']
        if spec['run_id']=='daily_smoke':continue
        for r in read(run/'trades_cost_decomposition.csv'):
            r['run_id']=spec['run_id'];r['family']=spec['expert'];rows.append(r)
    for ref in manifest.get('completed_cost_runs',[]):
        run=ROOT/ref['path'];assert json.loads((run/'audit.json').read_text())['passed']
        for r in read(run/'trades_cost_decomposition.csv'):
            r['run_id']=ref['run_id'];r['family']=ref['family'];rows.append(r)
    write(batch/'all_trades.csv',rows);groups=[]
    for family in ('cost_long','cost_short','daily_channel'):
        for year in ('ALL','2023','2024','2025','2026'):
            subset=[r for r in rows if r['family']==family and (year=='ALL' or r['year']==year)]
            groups.append(dict(family=family,year=year,**metrics(subset)))
    write(batch/'statistics.csv',groups)
    lines=['# コスト分解と日足チャネル基準戦略','',
      '既知期間・固定仕様。2023–2024 / 2025–2026年9月は別の初期資金10,000 USD。QA重複は集計から除外。','',
      '|対象|年|n|純損益USD|PF|quote完全n|平均mid R|平均spread R|平均fill R|',
      '|---|---|---:|---:|---:|---:|---:|---:|---:|']
    def fmt(v):return 'NA' if v is None else f'{v:.3f}'
    for r in groups:lines.append(f"|{r['family']}|{r['year']}|{r['n']}|{r['net']:.2f}|{fmt(r['pf'])}|{r['exact_quote_n']}|{fmt(r['mean_mid_move_r'])}|{fmt(r['mean_spread_cost_r'])}|{fmt(r['mean_fill_r'])}|")
    for family in ('daily_channel',):
        t=[r for r in rows if r['family']==family];by=[]
        for symbol in manifest['symbols']:by.append(dict(symbol=symbol,**metrics([r for r in t if r['symbol']==symbol])))
        write(batch/'daily_by_symbol.csv',by)
        months=[]
        for year in range(2023,2027):
            for month in range(1,10 if year==2026 else 13):
                key=f'{year}-{month:02}';z=[r for r in t if r['entry_time'].startswith(key)]
                months.append(dict(month=key,**metrics(z)))
        write(batch/'daily_monthly.csv',months)
        lines+=['',f'日足基準戦略の実行頻度：{len(t)/45:.2f}件/月。最低月件数={min(x["n"] for x in months)}。',
          '損益は同時運用ポートフォリオの実測。銘柄別はその内訳であり、個別運用バックテストではない。']
    lines+=['','## コスト分解の意味',
      '同じEntryと決済時刻で、fill価格R = mid値動きR − 両端spread負担R − 約定と同時気配の残差R。',
      '残差は純粋な通信遅延slippageではなく、SL/TP価格との乖離等も含む。',
      '現金分解は実損益から逆算した換算係数を使う会計的帰属。Entry時のリスク換算の再推定ではない。',
      '同期quote欠損/曖昧な行は残し、mid集計から除外。欠損があれば母集団全体への断定をしない。',
      'SL/TPや決済時刻を無コストで再判定した成績ではない。mid利益が正でも無コスト戦略の優位性を証明しない。',
      'cost_long/shortは実取引に限定した分析。見送り候補までのコスト分解ではない。',
      '手数料・swap・feeは別列で保存。純損益はすべて込み。','',
      '## 制限',
      'モデル4要求でも生成tick混在は品質ラベル付きで残す。各runのaudit.jsonを参照。',
      '全期間は既知・OOSではない。利益が出ても採用・昇格しない。負の結果を理由に閾値を再探索しない。',
      '日足の処理はUSDJPY tickを時計にし、各分の最初のtickで他銘柄を確認。各銘柄の最初のtick約定を保証しない。']
    (batch/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--package',type=Path,required=True);p.add_argument('--batch',type=Path);a=p.parse_args()
    if a.run:
        m=json.loads((a.package/'manifest.json').read_text(encoding='utf-8'));check(a.run,next(r for r in m['runs'] if r['run_id']==a.run_id))
    else:aggregate(a.batch,a.package)
