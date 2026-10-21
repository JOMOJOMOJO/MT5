"""Frozen mirror-short experiment, reusing existing SELL execution and safety."""
import difflib,hashlib,json
from pathlib import Path
from prepare_m5_context import once

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/m5_ichimoku_diagnostics_20261007'
OUT=ROOT/'reports/qa/m5_short_ichimoku_20261007'
MIRROR={
    'InpRoundShortSessionStartHour':'InpSessionStartHour','InpRoundShortSessionEndHour':'InpSessionEndHour',
    'InpRoundShortMaxEma13DistanceAtr':'InpMaxEma13DistanceAtr','InpRoundShortMinLowerWickShare':'InpMinUpperWickShare',
    'InpRoundShortMaxUpperWickShare':'InpMaxLowerWickShare','InpRoundShortMinSlowSlopeAtr':'InpMinSlowSlopeAtr',
    'InpRoundShortStopLossAtr':'InpStopLossAtr','InpRoundShortTargetRMultiple':'InpTargetRMultiple','InpRoundShortMaxHoldBars':'InpMaxHoldBars'}
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def section(s,start,end):return s[s.index(start):s.index(end,s.index(start))]

def prepare():
    if OUT.exists():raise SystemExit('Refuse overwrite of frozen package')
    original=(BASE/'frozen/quality12b_snapshot.mq5').read_text();s=original
    s=once(s,'input bool            InpEnableRoundBucket        = true;','input bool            InpEnableRoundBucket        = false;')
    s=once(s,'input bool            InpEnableRoundShortBucket   = false;','input bool            InpEnableRoundShortBucket   = true;')
    s=once(s,'InpSignalTimeframe          = PERIOD_M15;','InpSignalTimeframe          = PERIOD_M5;')
    s=once(s,'int dcContext=INVALID_HANDLE,dcPath=INVALID_HANDLE;','input bool InpShortObserver=true;\nint dcContext=INVALID_HANDLE,dcPath=INVALID_HANDLE;')
    s=once(s,'   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;',
           '   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;\n   if(InpEnableRoundBucket || !InpEnableRoundShortBucket) return INIT_PARAMETERS_INCORRECT;')
    s=once(s,'bool roundSignal=EvaluateRoundSignal(rates,fastEma,slowEma);','bool roundSignal=EvaluateRoundShortSignal(rates,fastEma,slowEma);')
    s=once(s,'if(roundSignal) buckets[bucketCount++] = SIGNAL_ROUND;','if(roundSignal) buckets[bucketCount++] = SIGNAL_ROUND_SHORT;')
    s=once(s,'         if(EvaluateRoundShortSignal(rates, fastEma, slowEma))\n            buckets[bucketCount++] = SIGNAL_ROUND_SHORT;','         // The short signal above is evaluated and enqueued exactly once.')
    # Diagnostics only inside the existing short function. Its boolean logic is preserved.
    block=section(s,'bool EvaluateRoundShortSignal(','bool EvaluateRoundLooseSignal(')
    modified=block.replace('return false;','return RecordRoundDecision("SHORT_CONDITION_NOT_MET");').replace('return true;','return RecordRoundDecision("SHORT_SIGNAL",true);')
    s=once(s,block,modified)
    for name,args in [('DCCandidate','const datetime barTime,const bool gate'),('DCEntry','const datetime when,const double fill'),('DCUpdate','const bool newBar')]:
        marker='void '+name+'('+args+')\n  {'
        s=once(s,marker,marker+'\n   if(!InpShortObserver) return;')
    s=once(s,'DCLoad(dcDecision,dcQuote.ask);DCWrite("CANDIDATE",dcDecision,dcQuote.ask,gate);',
        'DCLoad(dcDecision,dcQuote.bid);DCWrite("CANDIDATE",dcDecision,dcQuote.bid,gate);')
    s=once(s,'double sl=NormalizePrice(dcQuote.ask-InpStopLossAtr*atr);','double sl=NormalizePrice(dcQuote.bid+InpRoundShortStopLossAtr*atr);')
    s=once(s,'double tp=NormalizePrice(dcQuote.ask+InpStopLossAtr*atr*InpTargetRMultiple);',
        'double tp=NormalizePrice(dcQuote.bid-InpRoundShortStopLossAtr*atr*InpRoundShortTargetRMultiple);')
    s=once(s,'double risk=dcQuote.ask-NormalizePrice(dcQuote.ask-InpStopLossAtr*GetDistanceUnit());',
        'double risk=NormalizePrice(dcQuote.bid+InpRoundShortStopLossAtr*GetDistanceUnit())-dcQuote.bid;')
    block=section(s,'void DCUpdate(','void DCCandidate(')
    s=once(s,block,block.replace('t.bid','t.ask').replace('>=InpMaxHoldBars','>=InpRoundShortMaxHoldBars'))
    for x in ('open','high','low','close'):s=once(s,'"'+x+'_bid"','"'+x+'_ask"')
    # Broker SELL/risk/position-management implementations remain byte-identical.
    for name,nextname in [('Orders','TelemetryControl'),('PositionManagement','PriceStructure')]:
        marker='// RELATIVE_CONTINUATION_MODULE_BEGIN '+name
        end='// RELATIVE_CONTINUATION_MODULE_END '+name
        assert section(s,marker,end)==section(original,marker,end)
    target=ROOT/'mql/Experts/Research/RelativeM5ShortIchimoku.mq5';assert not target.exists()
    target.write_text(s,encoding='utf-8')
    frozen=OUT/'frozen';frozen.mkdir(parents=True)
    for name in ('M15Environment.mqh','HTFResearchEnvironment.mqh'):(frozen/name).write_bytes((BASE/'frozen'/name).read_bytes())
    (frozen/'quality12b_snapshot.mq5').write_text(s,encoding='utf-8')
    values=json.loads((BASE/'frozen/inputs.json').read_text())
    values.update(InpEnableRoundBucket='false',InpEnableRoundShortBucket='true',InpShortObserver='true')
    for short,long in MIRROR.items():values[short]=values[long]
    (frozen/'inputs.json').write_text(json.dumps(values,indent=2)+'\n')
    (frozen/'quality12b_full.set').write_text('\n'.join(f'{k}={v}' for k,v in values.items())+'\n')
    preset=ROOT/'presets/RelativeContinuation/USDJPY_M5_short_research.set'
    assert not preset.exists();preset.write_bytes((frozen/'quality12b_full.set').read_bytes())
    runs=[dict(run_id='short_control_2023_2024',stage='Control',date_from='2023.01.01',date_to='2025.01.01',
        timeframe='M5',label='OBSERVER_OFF_EXECUTION_CONTROL',overrides={'InpShortObserver':'false'}),
        dict(run_id='short_2023_2024',stage='Observe',date_from='2023.01.01',date_to='2025.01.01',
        timeframe='M5',label='KNOWN_PERIOD_NOT_OOS',overrides={},reference_run_id='short_control_2023_2024'),
        dict(run_id='short_2025_2026',stage='Observe',date_from='2025.01.01',date_to='2026.10.01',
        timeframe='M5',label='KNOWN_PERIOD_NOT_OOS',overrides={})]
    manifest=json.loads((BASE/'manifest.json').read_text())
    long_trades=BASE/'runs/20261007_183110_12bea14d/trades_with_ichimoku.csv'
    manifest.update(purpose='M5_SHORT_ICHIMOKU',source=str(target.relative_to(ROOT)),source_sha256=digest(target),input_count=len(values),
        runs=runs,analysis_sha256=digest(ROOT/'tools/quality12b/analyze_short_ichimoku.py'),
        long_reference=dict(path=str(long_trades.relative_to(ROOT)),sha256=digest(long_trades)),
        sha256={p.relative_to(OUT).as_posix():digest(p) for p in frozen.iterdir()})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'research_hooks.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='long_observer',tofile='short_observer')))
    (OUT/'input_changes.json').write_text(json.dumps({k:dict(old=json.loads((BASE/'frozen/inputs.json').read_text()).get(k),new=v) for k,v in values.items() if json.loads((BASE/'frozen/inputs.json').read_text()).get(k)!=v},indent=2)+'\n')
    print('Prepared short-only research EA, preset and 3 fixed runs; no MT5 launched.')

if __name__=='__main__':prepare()
