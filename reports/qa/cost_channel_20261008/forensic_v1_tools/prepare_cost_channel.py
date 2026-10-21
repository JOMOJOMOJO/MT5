"""Freeze cost-only replays and one daily portfolio baseline. Never launch MT5."""
import argparse, hashlib, json, re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/cost_channel_20261008'
LONG=ROOT/'reports/qa/m5_ichimoku_diagnostics_20261007'
SHORT=ROOT/'reports/qa/m5_short_ichimoku_20261007'

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x): p.write_text(json.dumps(x,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def verify(out):
    m=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    for name,h in m['hashes'].items(): assert digest(ROOT/name)==h,name
    for r in m['runs']:
        if r.get('reference'): assert digest(ROOT/r['reference'])==r['reference_sha256']
    return m

def prepare(out):
    if (out/'manifest.json').exists(): return verify(out)
    frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    observer=(ROOT/'mql/Include/Research/DealQuoteAudit.mqh').read_text(encoding='utf-8')
    runs=[];sources={}
    for side,package,batch in [('long',LONG,'20261007_183110_12bea14d'),('short',SHORT,'20261007_193908_b4fa5afc')]:
        s=(package/'frozen/quality12b_snapshot.mq5').read_text(encoding='utf-8-sig')
        for typ,name in [('int','OnInit'),('void','OnDeinit'),('void','OnTradeTransaction')]:
            old=typ+' '+name+'(';assert s.count(old)==1
            s=s.replace(old,typ+' Base'+name+'(')
        s+='\n'+observer+'''
int OnInit(){int rc=BaseOnInit();if(rc==INIT_SUCCEEDED){DQStart(runtimeTelemetryFileName+".cost.csv");if(dqFile==INVALID_HANDLE)return INIT_FAILED;}return rc;}
void OnDeinit(const int reason){DQClose();BaseOnDeinit(reason);}
double OnTester(){DQDrain();return 0;}
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &q,const MqlTradeResult &r)
{BaseOnTradeTransaction(t,q,r);if(t.type==TRADE_TRANSACTION_DEAL_ADD)DQCapture(t.deal);}
'''
        name='cost_'+side
        (frozen/(name+'.mq5')).write_text(s,encoding='utf-8')
        inputs=json.loads((package/'frozen/inputs.json').read_text())
        save(frozen/(name+'.json'),inputs)
        sources[name]=str((frozen/(name+'.mq5')).relative_to(ROOT))
        for period,start,end in [('2023_2024','2023.01.01','2025.01.01'),('2025_2026','2025.01.01','2026.10.01')]:
            oldid=('known_' if side=='long' else 'short_')+period
            ref=package/'runs'/batch/oldid/'report.htm'
            assert ref.exists(),ref
            runs.append(dict(run_id=name+'_'+period,kind='cost',expert=name,inputs=name+'.json',
                date_from=start,date_to=end,timeframe='M5',reference=str(ref.relative_to(ROOT)),reference_sha256=digest(ref)))
    source=ROOT/'mql/Experts/Research/DailyChannelPortfolio.mq5'
    s=source.read_text(encoding='utf-8').replace('#include "../../Include/Research/DealQuoteAudit.mqh"',observer)
    (frozen/'daily_channel.mq5').write_text(s,encoding='utf-8')
    values={name:value.strip().strip('"') for name,value in re.findall(r'^input\s+\w+\s+(Inp\w+)\s*=\s*([^;]+);',s,re.M)}
    save(frozen/'daily_channel.json',values);sources['daily_channel']=str((frozen/'daily_channel.mq5').relative_to(ROOT))
    for tag,start,end in [('smoke','2023.01.01','2023.04.01'),('2023_2024','2023.01.01','2025.01.01'),('2025_2026','2025.01.01','2026.10.01')]:
        runs.append(dict(run_id='daily_'+tag,kind='portfolio',expert='daily_channel',inputs='daily_channel.json',
            date_from=start,date_to=end,timeframe='M1',reference='',label='QA_ONLY' if tag=='smoke' else 'KNOWN_PERIOD_NOT_OOS'))
    paths=list(frozen.iterdir())+[source,ROOT/'mql/Include/Research/DealQuoteAudit.mqh',
          ROOT/'tools/quality12b/analyze_cost_channel.py',ROOT/'scripts/run-cost-channel.ps1',
          ROOT/'tools/quality12b/prepare_cost_channel.py',ROOT/'tools/quality12b/analyze_reports.py',
          ROOT/'tools/quality12b/compare_reproduction.py',ROOT/'tools/quality12b/tick_quality.py',
          ROOT/'tools/quality12b/test_cost_channel.py']
    m=dict(schema=1,purpose='COST_DECOMPOSITION_AND_FIXED_DAILY_BASELINE',sources=sources,runs=runs,
           expected_server='VantageTradingLtd-Live',expected_broker='Vantage Trading Ltd',
           symbols=['USDJPY','EURUSD','GBPUSD','AUDUSD','XAUUSD'],
           hashes={str(p.relative_to(ROOT)):digest(p) for p in paths})
    save(out/'manifest.json',m)
    for name in sources:
        v=json.loads((frozen/(name+'.json')).read_text())
        (out/(name+'.set')).write_text('\n'.join(f'{k}={x}' for k,x in v.items())+'\n',encoding='ascii')
    return m

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=OUT);p.add_argument('--check',action='store_true');p.add_argument('--refresh-before-first-run',action='store_true');a=p.parse_args()
    if a.refresh_before_first_run:
        assert not (a.out/'runs').exists() and not (a.out/'runner.lock').exists(),'Cannot refreeze an executed/running study'
        (a.out/'manifest.json').unlink(missing_ok=True)
    m=verify(a.out) if a.check else prepare(a.out)
    print(json.dumps(dict(verified=True,runs=len(m['runs']),out=str(a.out))))
