"""Prepare a logging-only tester clone; never edits the trading EA or launches MT5."""
import csv
import difflib
import json
from pathlib import Path
from prepare_revalidation import ROOT, digest, verify

BASE = ROOT/'reports/qa/quality12b_revalidation_20261005'
OUT = ROOT/'reports/qa/quality12b_spread_diagnosis_20261006'
PRIOR = BASE/'runs/20261005_120836_15208538'

LOGGER = r'''
// Research-only quote audit. Original decisions are returned unchanged.
int spreadAuditHandle = INVALID_HANDLE;
bool spreadAuditEntryGate = false;
void WriteSpreadAudit(bool tickOk,int tickError,const MqlTick &quote,double pip,double rawSpread)
  {
   if(!spreadAuditEntryGate || !MQLInfoInteger(MQL_TESTER))
      return;
   if(spreadAuditHandle == INVALID_HANDLE)
     {
      spreadAuditHandle=FileOpen(runtimeTelemetryFileName+".spread.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
      if(spreadAuditHandle == INVALID_HANDLE)
        {
         Print("SPREAD_AUDIT_FILE_FAILED error=",GetLastError());
         return;
        }
      FileWrite(spreadAuditHandle,"time","bar_time","tick_time_msc","tick_ok","tick_error",
                "bid","ask","point","digits","pip","symbol_spread_points","tick_flags",
                "raw_spread_pips","limit_pips","raw_allowed","point_gap_rounded","point_aligned",
                "point_grid_allowed","reason");
     }
   double point=SymbolInfoDouble(runtimeSymbol,SYMBOL_POINT);
   long digits=SymbolInfoInteger(runtimeSymbol,SYMBOL_DIGITS);
   double gap=(tickOk && point>0.0)?(quote.ask-quote.bid)/point:0.0;
   double rounded=MathRound(gap);
   bool aligned=(tickOk && point>0.0 && MathAbs(gap-rounded)<0.000001);
   bool rawAllowed=(rawSpread>=0.0 && rawSpread<=InpMaxSpreadPips);
   bool gridAllowed=(tickOk && pip>0.0 && point>0.0 && gap>=0.0 &&
                     rounded<=InpMaxSpreadPips*pip/point);
   string reason="PASS";
   if(!tickOk) reason="TICK_API_FAILURE";
   else if(pip<=0.0) reason="INVALID_PIP";
   else if(rawSpread<0.0) reason="NEGATIVE_SPREAD";
   else if(!rawAllowed && aligned && gridAllowed) reason="FLOAT_BOUNDARY_ONLY";
   else if(!rawAllowed) reason="ABOVE_LIMIT";
   FileWrite(spreadAuditHandle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
             TimeToString(iTime(runtimeSymbol,InpSignalTimeframe,0),TIME_DATE|TIME_SECONDS),
             quote.time_msc,(int)tickOk,tickError,DoubleToString(quote.bid,16),DoubleToString(quote.ask,16),
             DoubleToString(point,16),digits,DoubleToString(pip,16),
             SymbolInfoInteger(runtimeSymbol,SYMBOL_SPREAD),quote.flags,
             DoubleToString(rawSpread,16),DoubleToString(InpMaxSpreadPips,16),(int)rawAllowed,
             DoubleToString(rounded,0),(int)aligned,(int)gridAllowed,reason);
   FileFlush(spreadAuditHandle);
  }
'''

NEW_GET = '''double GetCurrentSpreadPips()
  {
   MqlTick tick;
   ZeroMemory(tick);
   bool tickOk=SymbolInfoTick(runtimeSymbol,tick);
   int tickError=tickOk?0:GetLastError();
   if(!tickOk)
     {
      WriteSpreadAudit(false,tickError,tick,0.0,-1.0);
      return -1.0;
     }
   double pip = GetPipSize();
   if(pip <= 0.0)
     {
      WriteSpreadAudit(true,0,tick,pip,-1.0);
      return -1.0;
     }
   double spread=(tick.ask-tick.bid)/pip;
   WriteSpreadAudit(true,0,tick,pip,spread);
   return spread;
  }
'''


def once(source, old, new):
    assert source.count(old) == 1, old[:80]
    return source.replace(old, new, 1)


def prepare():
    if (OUT/'manifest.json').exists():
        return verify(OUT)
    original = (BASE/'frozen/quality12b_snapshot.mq5').read_text(encoding='utf-8-sig')
    source = once(original, 'double GetCurrentSpreadPips()', LOGGER+'\ndouble GetCurrentSpreadPips()')
    start = source.index('double GetCurrentSpreadPips()')
    end = source.index('\nbool IsSpreadAllowed()', start)
    source = source[:start]+NEW_GET+source[end:]
    source = once(source, '   if(!IsSpreadAllowed())\n     {\n      dailyBlockedSpread++;',
        '   spreadAuditEntryGate=true;\n   bool spreadAuditAllowed=IsSpreadAllowed();\n   spreadAuditEntryGate=false;\n   if(!spreadAuditAllowed)\n     {\n      dailyBlockedSpread++;')
    source = once(source, 'int OnInit()\n  {', 'int OnInit()\n  {\n   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;')
    source = once(source, '   CloseTelemetryFile();', '   CloseTelemetryFile();\n   if(spreadAuditHandle != INVALID_HANDLE) FileClose(spreadAuditHandle);')
    target = ROOT/'mql/Experts/Research/Quality12bSpreadDiagnostic.mq5'
    target.parent.mkdir(exist_ok=True, parents=True)
    assert not target.exists(), 'Preserve existing research source'
    target.write_text(source, encoding='utf-8')
    (OUT/'frozen').mkdir(parents=True)
    (OUT/'frozen/quality12b_snapshot.mq5').write_bytes(target.read_bytes())
    for name in ('inputs.json','quality12b_full.set'):
        (OUT/'frozen'/name).write_bytes((BASE/'frozen'/name).read_bytes())
    (OUT/'instrumentation.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),source.splitlines(True),fromfile='frozen_baseline',tofile='research_diagnostic')),encoding='utf-8')
    runs = [dict(run_id=name,stage='Extend',date_from=start,date_to=end,label='SPREAD_CAUSE_DIAGNOSIS_ONLY',
                 reference_report=str((PRIOR/name/'report.htm').relative_to(ROOT)),reference_sha256=digest(PRIOR/name/'report.htm'))
            for name,start,end in [('annual_2024','2024.01.01','2025.01.01'),('recent_2026_apr_sep','2026.04.01','2026.10.01')]]
    with (OUT/'run_matrix.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(runs[0]));w.writeheader();w.writerows(runs)
    manifest=json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))
    manifest.update(created='2026-10-06',purpose='SPREAD_DIAGNOSIS_ONLY',source=str(target.relative_to(ROOT)),
                    source_sha256=digest(target),baseline_source_sha256=digest(BASE/'frozen/quality12b_snapshot.mq5'),
                    source_identity_note='Logging-only tester clone; see instrumentation.diff; order parity is mandatory.',
                    runs=runs,reference_reports=[],sha256={})
    for p in list((OUT/'frozen').iterdir())+[OUT/'run_matrix.csv',OUT/'instrumentation.diff']:
        manifest['sha256'][p.relative_to(OUT).as_posix()]=digest(p)
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('Prepared quote diagnosis; no terminal launched:',OUT)


if __name__ == '__main__':
    prepare()
