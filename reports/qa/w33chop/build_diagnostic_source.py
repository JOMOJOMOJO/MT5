"""Create the isolated observer EA from preserved v1.80 without changing trading."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
source = ROOT / 'mql/Experts/Wave33VisualVerifier.mq5'
original = source.read_bytes()
text = original.decode('utf-8-sig').replace('\r\n', '\n')
changes = []
def replace(old, new):
    global text
    assert text.count(old) == 1, (old, text.count(old))
    text = text.replace(old, new)
    changes.append({'old': old, 'new': new})

replace('#property version "1.80"', '#property version "1.81"')
replace('#include "../Include/Wave33Visual/Wave1Target.mqh"', '#include "../Include/Wave33Visual/Wave1Target.mqh"\n#include "../Include/Wave33Visual/Chop.mqh"')
replace('input string InpRunTag="wave33_v1";', 'input string InpRunTag="wave33_chop_v181";\ninput bool InpChopDiagnostic=true; // Observation only; never rejects an entry.\ninput bool InpChopLabels=true; // Compact labels at knowledge availability, no panel.')
replace('CWave33Engine g_engine;', 'CWave33ChopObserver g_chop;\nCWave33Engine g_engine;')
replace('string value="1.80|"', 'string value="1.81|"')
replace('   return W33Hash(value);', '   value+="|"+(string)InpChopDiagnostic+"|"+(string)InpChopLabels+"|"+W33_CHOP_VERSION+"|0.5";\n   return W33Hash(value);')
replace('   g_ledger.Write(e);g_display.Event(e);', '   g_chop.Event(e); // Read-only observer; evaluate before the event is published.\n   g_ledger.Write(e);g_display.Event(e);')
replace('      if(accepted && periods[i]==g_lower)g_ledger.WriteLowerBar(_Symbol,g_lower,pending[i],now);', '      if(accepted && periods[i]==g_lower)\n        {g_chop.AcceptedLowerBar(pending[i].time);g_ledger.WriteLowerBar(_Symbol,g_lower,pending[i],now);}')
replace('FileWrite(file,"ea_version","1.80")', 'FileWrite(file,"ea_version","1.81")')
replace('   FileWrite(file,"resolved_run_tag",g_tag);', '   FileWrite(file,"resolved_run_tag",g_tag);\n   FileWrite(file,"chop_diagnostic",InpChopDiagnostic);FileWrite(file,"chop_labels",InpChopLabels);\n   FileWrite(file,"chop_formula_version",W33_CHOP_VERSION);FileWrite(file,"chop_threshold",W33_CHOP_THRESHOLD);\n   FileWrite(file,"chop_policy","observation only; no entry filter; known lower pivots strictly inside fixed W1 anchors; sum adverse moves / positive directional span");')
replace('   g_display.Init(g_prefix,g_effective_draw);ZeroMemory(g_last);', '   g_display.Init(g_prefix,g_effective_draw);ZeroMemory(g_last);\n   if(!g_chop.Open(g_tag,g_prefix,g_lower,InpChopDiagnostic,g_effective_draw && InpChopLabels))\n     {Print("Wave33 INIT_CHOP_CSV_OPEN_FAILED tag=",g_tag," error=",GetLastError());g_ledger.Close();return INIT_FAILED;}')
replace('      g_ledger.Close();if(g_exit_tick_file!=INVALID_HANDLE){FileClose(g_exit_tick_file);g_exit_tick_file=INVALID_HANDLE;}\n      W33ReleaseBatchRunTag', '      g_chop.Close();g_ledger.Close();if(g_exit_tick_file!=INVALID_HANDLE){FileClose(g_exit_tick_file);g_exit_tick_file=INVALID_HANDLE;}\n      W33ReleaseBatchRunTag')
replace('   g_ledger.Close();if(g_exit_tick_file!=INVALID_HANDLE){FileClose(g_exit_tick_file);g_exit_tick_file=INVALID_HANDLE;}\n   W33ReleaseBatchRunTag', '   g_chop.Close();g_ledger.Close();if(g_exit_tick_file!=INVALID_HANDLE){FileClose(g_exit_tick_file);g_exit_tick_file=INVALID_HANDLE;}\n   W33ReleaseBatchRunTag')
replace('   if(!InpKeepObjects)g_display.Clear();ChartRedraw();g_ready=false;', '   if(!InpKeepObjects){g_chop.Clear();g_display.Clear();}ChartRedraw();g_ready=false;')
target = ROOT / 'mql/Experts/Wave33ChopDiagnostic.mq5'
target.write_bytes(text.replace('\n', '\r\n').encode('utf-8-sig'))
assert source.read_bytes() == original
(ROOT / 'reports/qa/w33chop/source_copy_manifest.json').write_text(json.dumps({
    'source': str(source.relative_to(ROOT)), 'source_sha256': hashlib.sha256(original).hexdigest(),
    'target': str(target.relative_to(ROOT)), 'target_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'changes': changes, 'original_unchanged': True,
}, indent=2), encoding='utf-8')
print(f'Created {target.name}: {len(changes)} diagnostic-only replacements; original unchanged')
