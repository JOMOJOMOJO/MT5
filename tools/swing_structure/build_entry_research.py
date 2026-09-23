"""Generate isolated tester-only entry variants from the frozen production sources."""
from pathlib import Path
import hashlib, json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports/qa/three_wave/entry_research'
OUT.mkdir(parents=True, exist_ok=True)
sources = ['mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5',
           'mql/Include/ThreeWaveStructure.mqh']
manifest = {}
for name in sources:
    raw = (ROOT/name).read_bytes()
    manifest[name] = hashlib.sha256(raw).hexdigest()
    (OUT/Path(name).name).write_bytes(raw)
(OUT/'source_manifest.json').write_text(json.dumps(manifest, indent=2))

def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)

engine = (ROOT/sources[1]).read_text(encoding='utf-8-sig')
engine = replace_once(engine, '      // READY requires a currently-valid confirmed HL', '''      // Research modes preserve all origin, confirmation, reset and M5 deadline guards above.
      // Mode 1: enter on the FIRST closed CHoCH, only when its confirmed reversal
      // low has retraced at least 50% of the frozen M5 Wave1 (origin remains intact).
      // No synthetic future HL is inserted; execution uses the reversal-low stop.
      if(InpEntryResearchMode==1 && pat.found_choch && pat.choch_time==r[i].time)
      {
         double midpoint=(s.origin_low.price+s.wave1_high.price)*0.5;
         if(pat.reversal_low.price<=midpoint && pat.reversal_low.price>s.origin_low.price)
         {
            pat.ready=true; pat.ready_time=r[i].time; pat.ready_price=r[i].close;
            TWTrace(close_time,s.break_time,"LONG_READY","M5_FIB50_M1_CHOCH");
            return true;
         }
         TWTrace(close_time,s.break_time,"WAIT_M1_RESET","M5_FIB50_NOT_REACHED_AT_CHOCH");
      }
      // Mode 2: confirmed, unbroken HL is sufficient; no extra upside break.
      if(InpEntryResearchMode==2 && pat.found_hl)
      {
         pat.ready=true; pat.ready_time=r[i].time; pat.ready_price=r[i].close;
         TWTrace(close_time,s.break_time,"LONG_READY","M1_HL_CONFIRMATION");
         return true;
      }

      // READY requires a currently-valid confirmed HL''')
engine = replace_once(engine, 'if(pat.found_hl && !pat.ready)', 'if(InpEntryResearchMode==0 && pat.found_hl && !pat.ready)')
(ROOT/'mql/Include/ThreeWaveEntryResearch.mqh').write_text(engine, encoding='utf-8')
ea = (ROOT/sources[0]).read_text(encoding='utf-8-sig')
ea = ea.replace('#include "../Include/ThreeWaveStructure.mqh"',
    'input int InpEntryResearchMode=0; // 0=current, 1=M5 fib50+CHoCH, 2=confirmed HL\n#include "../Include/ThreeWaveEntryResearch.mqh"')
ea = replace_once(ea, 'int OnInit()\n{', '''int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || InpEntryResearchMode<0 || InpEntryResearchMode>2 ||
      InpVerifyIndicator || (InpEntryResearchMode==1 && InpStopMode!=STOP_M1_REVERSAL_LOW))
      return INIT_PARAMETERS_INCORRECT;
   Print("TW_RESEARCH mode=",InpEntryResearchMode," stop=",EnumToString(InpStopMode));''')
ea = ea.replace('p.early_break?"WAVE2_RETURN_HIGH_CLOSE_BREAK":"WAVE1_HIGH_CLOSE_BREAK"',
    'InpEntryResearchMode==1?"M5_FIB50_M1_CHOCH":(InpEntryResearchMode==2?"M1_HL_CONFIRMATION":(p.early_break?"WAVE2_RETURN_HIGH_CLOSE_BREAK":"WAVE1_HIGH_CLOSE_BREAK"))')
(ROOT/'mql/Experts/USDJPY_3Wave_EntryResearch.mq5').write_text(ea, encoding='utf-8')
