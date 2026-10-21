"""Freeze execution portability QA. Old EAs, research sources and presets are read-only."""
import argparse,difflib,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DEFAULT=ROOT/'reports/qa/portable_audit_20261008'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def once(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b)
def function(s,name,body):
    m=re.search(r'(?m)^(?:double|bool|int|void) '+name+r'\([^\n]*\)\s*\{',s)
    assert m,name
    start=m.start();i=m.end();depth=1
    while depth:
        if s[i]=='{':depth+=1
        elif s[i]=='}':depth-=1
        i+=1
    return s[:start]+body+s[i:]
def save(p,obj):p.write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def verify(out):
    m=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    for p,h in m['hashes'].items():assert sha(ROOT/p)==h,p
    for p,h in m.get('preserved',{}).items():assert sha(ROOT/p)==h,('Preserved source changed',p)
    return m
def prepare(out):
    if (out/'manifest.json').exists():return verify(out)
    frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    portable=ROOT/'mql/Include/Research/PortableTrading.mqh'
    context=ROOT/'mql/Include/Research/PortableContextDiagnostics.mqh'
    observer=(ROOT/'mql/Include/Research/DealQuoteAudit.mqh').read_text(encoding='utf-8')
    daily_path=ROOT/'mql/Experts/Research/DailyChannelPortfolio.mq5'
    daily=daily_path.read_text(encoding='utf-8')
    new=once(daily,'#property version "1.01"','#property version "1.02"\n#include "../../Include/Research/PortableTrading.mqh"\ninput bool InpIndependentClock=true;\ninput double InpDeviationATR=0.05;')
    new=function(new,'DCUSDGroup','''int DCUSDGroup(const string symbol,const int side)
  {return PFUsdDirection(SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE),SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT),side);}''')
    new=once(new,'total+=risk;if(DCUSDGroup(symbol,side)==group)same+=risk;',
                   'total+=risk;if(group!=0 && DCUSDGroup(symbol,side)==group)same+=risk;')
    new=once(new,'same<=equity*InpUSDGroupRiskPercent/100.0+1e-7','(group==0 || same<=equity*InpUSDGroupRiskPercent/100.0+1e-7)')
    new=once(new,'if(PositionGetTicket(j)==0)continue;','if(PositionGetTicket(j)==0 || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;')
    new=function(new,'DCClose','''bool DCClose(const string symbol)
  {
   bool complete=true;
   for(int j=PositionsTotal()-1;j>=0;j--)
     {
      ulong ticket=PositionGetTicket(j);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      bool ok=dcTrade.PositionClose(ticket);uint rc=dcTrade.ResultRetcode();DCLog(symbol,0,"CLOSE_RESULT",0,0,0,0,0,0,rc);
      if(!ok || rc!=TRADE_RETCODE_DONE || PositionSelectByTicket(ticket))complete=false;
     }
   return complete;
  }''')
    new=once(new,'dcAssets[j].name=names[j];','''string resolved,why;
      if(!PFResolveSymbol(names[j],resolved,why)){Print("DC_FATAL_SYMBOL ",names[j]," ",why);return INIT_FAILED;}
      for(int k=0;k<j;k++)if(dcAssets[k].name==resolved)return INIT_PARAMETERS_INCORRECT;
      names[j]=resolved;dcAssets[j].name=resolved;''')
    new=once(new,'dcTrade.SetExpertMagicNumber(InpMagic);dcTrade.SetAsyncMode(false);dcTrade.SetDeviationInPoints(10);',
       '''if(InpDeviationATR<0 || InpRiskPercent>100 || InpTotalRiskPercent<=0 || InpUSDGroupRiskPercent<=0 ||
         InpDailyLossPercent<=0 || InpDailyLossPercent>=100 || InpPeakLossPercent<=0 || InpPeakLossPercent>=100)return INIT_PARAMETERS_INCORRECT;
   if(!PFOpen(InpTelemetryFileName+".risk.csv"))return INIT_FAILED;
   if(InpIndependentClock && !EventSetTimer(10))return INIT_FAILED;
   dcTrade.SetExpertMagicNumber(InpMagic);dcTrade.SetAsyncMode(false);''')
    new=once(new,'   if(PositionSelect(symbol))\n     {\n      bool buy=',
       '   if(PFForeignPosition(symbol,InpMagic)){DCLog(symbol,r[1].time,"FOREIGN_POSITION");return;}\n   if(PositionSelect(symbol))\n     {\n      bool buy=')
    a=new.index('   double unitLoss=DCRisk(');b=new.index('   if(PositionsTotal()>=3',a)
    new=new[:a]+'''   PFPlan plan;bool planned=PFMakePlan(symbol,type,price,sl,InpRiskPercent,a[0],plan);PFWrite(symbol,type,price,sl,plan);
   if(!planned){DCLog(symbol,r[1].time,plan.reason,price,a[0],level,sl,plan.volume,plan.loss);return;}
   double volume=plan.volume,risk=plan.loss;
   dcTrade.SetDeviationInPoints((ulong)MathCeil(InpDeviationATR*a[0]/point));
'''+new[b:]
    new=once(new,'PositionsTotal()>=3','PFCountPositions(InpMagic)>=3')
    new=once(new,'void OnDeinit(const int reason)\n  {','void OnDeinit(const int reason)\n  {\n   EventKillTimer();PFClose();')
    new+='\nvoid OnTimer(){if(InpIndependentClock)OnTick();}\n'
    target=ROOT/'mql/Experts/Research/DailyChannelPortfolioPortable.mq5';target.write_text(new,encoding='utf-8')
    (out/'daily_changes.diff').write_text(''.join(difflib.unified_diff(daily.splitlines(True),new.splitlines(True),fromfile='daily_v1.01',tofile='daily_portable_v1.02')),encoding='utf-8')
    baseline_path=ROOT/'mql/Experts/Research/RelativeM5MultiTFDiagnostics.mq5'
    base=baseline_path.read_text(encoding='utf-8-sig')
    m5=once(base,'#include <Trade\\Trade.mqh>','#include <Trade\\Trade.mqh>\n#include "../../Include/Research/PortableTrading.mqh"')
    m5=once(m5,'if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;','if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return INIT_FAILED; // Parallel logs require a pass-specific optimization adapter.')
    m5=once(m5,'bool PersistRiskState()','#include "../../Include/Research/PortableContextDiagnostics.mqh"\n\nbool PersistRiskState()')
    m5=function(m5,'CalculateVolume','''double CalculateVolume(ENUM_ORDER_TYPE side,double entryPrice,double stopPrice)
  {
   PFPlan p;bool ok=PFMakePlan(runtimeSymbol,side,entryPrice,stopPrice,InpRiskPercent,GetDistanceUnit(),p);
   PFWrite(runtimeSymbol,side,entryPrice,stopPrice,p);
   if(!ok){Print("ORDER_SKIPPED ",p.reason);return 0;}
   return p.volume;
  }''')
    m5=once(m5,'   if(!DCOpen()) return INIT_FAILED;',
       '   if(!DCOpen() || !PFOpen(runtimeTelemetryFileName+".risk.csv") || !PCOpen(runtimeSymbol,runtimeTelemetryFileName+".portable_context.csv")) return INIT_FAILED;')
    m5=once(m5,'   DCClose();','   PFClose();PCClose();\n   DCClose();')
    m5=once(m5,'DCLoad(dcDecision,dcQuote.ask);DCWrite("CANDIDATE",dcDecision,dcQuote.ask,gate);',
       'DCLoad(dcDecision,dcQuote.ask);DCWrite("CANDIDATE",dcDecision,dcQuote.ask,gate);\n   PCWrite(dcId,runtimeSymbol,dcDecision,dcPlan);')
    m5target=ROOT/'mql/Experts/Research/RelativeM5PortableDiagnostics.mq5';m5target.write_text(m5,encoding='utf-8')
    (out/'m5_changes.diff').write_text(''.join(difflib.unified_diff(base.splitlines(True),m5.splitlines(True),fromfile='m5_multitf',tofile='m5_portable')),encoding='utf-8')
    # Standalone frozen sources preserve old modules and avoid installing into a live terminal.
    def flatten(s):
        for name in ('PortableTrading','PortableContextDiagnostics','DealQuoteAudit'):
            s=s.replace('#include "../../Include/Research/'+name+'.mqh"',(ROOT/f'mql/Include/Research/{name}.mqh').read_text(encoding='utf-8'))
        return s.replace('#include "../../Include/M15Environment.mqh"',(ROOT/'mql/Include/M15Environment.mqh').read_text(encoding='utf-8-sig'))
    sources={}
    def source(name,s,quotes=False):
        if quotes:
            for typ,fn in [('int','OnInit'),('void','OnDeinit'),('void','OnTradeTransaction')]:s=once(s,typ+' '+fn+'(',typ+' Base'+fn+'(')
            s+='\n'+observer+'''
int OnInit(){int rc=BaseOnInit();if(rc==INIT_SUCCEEDED){DQStart(runtimeTelemetryFileName+".cost.csv");if(dqFile==INVALID_HANDLE)return INIT_FAILED;}return rc;}
void OnDeinit(const int reason){DQClose();BaseOnDeinit(reason);}
double OnTester(){DQDrain();return 0;}
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &q,const MqlTradeResult &r)
{BaseOnTradeTransaction(t,q,r);if(t.type==TRADE_TRANSACTION_DEAL_ADD)DQCapture(t.deal);}
'''
        p=frozen/(name+'.mq5');p.write_text(flatten(s),encoding='utf-8');sources[name]=str(p.relative_to(ROOT))
    source('daily_portable',new)
    source('m5_reference',base,True);source('m5_portable',m5,True)
    qa=(ROOT/'mql/Experts/tests/PortableTradingHarness.mq5').read_text(encoding='utf-8')
    source('portable_harness',qa)
    daily_values=json.loads((ROOT/'reports/qa/cost_channel_20261008_r2/frozen/daily_channel.json').read_text())
    daily_values.update(InpIndependentClock='false',InpDeviationATR='0.05')
    save(frozen/'daily_legacy_clock.json',daily_values)
    save(frozen/'daily_timer.json',dict(daily_values,InpIndependentClock='true'))
    values=json.loads((ROOT/'reports/qa/m5_multitf_diagnostics_20261007/frozen/inputs.json').read_text())
    runs=[dict(run_id='harness',expert='portable_harness',inputs='harness.json',symbol='USDJPY',kind='harness',reference='')]
    save(frozen/'harness.json',dict(InpTelemetryFileName='portable_harness.csv'))
    previous=ROOT/'reports/qa/cost_channel_20261008_r2/runs/20261008_171544_bbf5d27f/daily_smoke/report.htm'
    runs += [dict(run_id='daily_legacy_clock',expert='daily_portable',inputs='daily_legacy_clock.json',symbol='USDJPY',kind='daily',reference=str(previous.relative_to(ROOT))),
             dict(run_id='daily_timer',expert='daily_portable',inputs='daily_timer.json',symbol='USDJPY',kind='daily',reference='')]
    for symbol in ['USDJPY','EURUSD','XAUUSD']:
        v=dict(values,InpSymbol=symbol);save(frozen/(symbol+'.json'),v)
        for kind in ['reference','portable']:
            runs.append(dict(run_id=f'm5_{symbol}_{kind}',expert='m5_'+kind,inputs=symbol+'.json',symbol=symbol,kind='m5',reference=''))
    for r in runs:r.update(date_from='2023.01.01',date_to='2023.04.01' if r['kind']!='harness' else '2023.01.06',timeframe='M5' if r['kind']=='m5' else 'M1',label='ENGINEERING_QA_NOT_STRATEGY_SELECTION')
    preserved=[daily_path,baseline_path,ROOT/'mql/Include/M15Environment.mqh',ROOT/'mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5',ROOT/'mql/Experts/usdjpy_20260402_round_continuation_long.mq5']
    tracked=[portable,context,target,m5target,ROOT/'mql/Include/M15Environment.mqh',ROOT/'mql/Experts/tests/PortableTradingHarness.mq5',Path(__file__).resolve(),ROOT/'tools/quality12b/analyze_portable_audit.py',ROOT/'tools/quality12b/test_portable_audit.py',ROOT/'scripts/run-portable-audit.ps1',previous,previous.parent/'cost.csv',previous.parent/'audit.json']+list(frozen.iterdir())
    save(out/'manifest.json',dict(purpose='MULTI_ASSET_PORTABILITY_QA',sources=sources,runs=runs,
       expected_server='VantageTradingLtd-Live',expected_broker='Vantage Trading Ltd',symbols=['USDJPY','EURUSD','GBPUSD','AUDUSD','XAUUSD'],
       hashes={str(p.relative_to(ROOT)):sha(p) for p in tracked},preserved={str(p.relative_to(ROOT)):sha(p) for p in preserved}))
    return verify(out)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT);p.add_argument('--check',action='store_true');a=p.parse_args()
    m=verify(a.out.resolve()) if a.check else prepare(a.out.resolve());print(json.dumps(dict(verified=True,runs=len(m['runs']))))
