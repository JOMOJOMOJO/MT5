"""Revision 2: terminal deal-history collection only; retain the failed v1 evidence."""
import argparse, difflib, json, shutil
from pathlib import Path
from prepare_portable_audit import ROOT, sha, save, verify, once

DEFAULT = ROOT / 'reports/qa/portable_audit_20261009_r2'
PARENT = ROOT / 'reports/qa/portable_audit_20261008'

def prepare(out):
    if (out/'manifest.json').exists():
        return verify(out)
    old = verify(PARENT)
    frozen = out/'frozen'; frozen.mkdir(parents=True, exist_ok=True)
    original = (ROOT/'mql/Include/Research/DealQuoteAudit.mqh').read_text(encoding='utf-8')
    observer = once(original, '#define RESEARCH_DEAL_QUOTE_AUDIT',
                    '#define RESEARCH_DEAL_QUOTE_AUDIT\n// Portable QA r2: end-of-test history is independent of the last tick clock.')
    begin = observer.index('void DQDrain()')
    observer = observer[:begin] + '''void DQDrain(const bool final_pass=false)
  {
   if(dqFile==INVALID_HANDLE)return;
   datetime quote_clock=TimeCurrent();
   bool terminal_pass=final_pass && (bool)MQLInfoInteger(MQL_TESTER);
   if(!HistorySelect(0,quote_clock)){Print("DQ_FATAL_HISTORY_NARROW");return;}
   int narrow=HistoryDealsTotal();
   // Only completed tester accounting requests the full already-created deal list.
   // No price data or result of this observer is consumed by signal/risk code.
   if(terminal_pass && !HistorySelect(0,D'3000.12.31 23:59:59'))
     {Print("DQ_FATAL_HISTORY_FINAL");return;}
   int n=HistoryDealsTotal();ulong ids[];ArrayResize(ids,n);long latest=0;
   for(int j=0;j<n;j++)
     {
      ids[j]=HistoryDealGetTicket(j);
      if(ids[j]>0){long stamp=HistoryDealGetInteger(ids[j],DEAL_TIME_MSC);if(stamp>latest)latest=stamp;}
     }
   // DQCapture calls HistoryDealSelect, so snapshot all tickets before capturing.
   for(int j=0;j<n;j++)DQCapture(ids[j]);
   if(terminal_pass)PrintFormat("DQ_FINAL quote_clock=%I64d server_clock=%I64d narrow=%d all=%d latest_msc=%I64d captured=%d",
      (long)quote_clock,(long)TimeTradeServer(),narrow,n,latest,ArraySize(dqSeen));
  }
void DQClose(){DQDrain(true);if(dqFile!=INVALID_HANDLE){FileClose(dqFile);dqFile=INVALID_HANDLE;}}
#endif
'''
    inc = ROOT/'mql/Include/Research/PortableDealQuoteAudit.mqh'
    inc.write_text(observer, encoding='utf-8')
    (out/'observer.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True), observer.splitlines(True),
        fromfile='DealQuoteAudit_original', tofile='PortableDealQuoteAudit_r2')), encoding='utf-8')
    sources = {}
    for name, rel in old['sources'].items():
        src = (ROOT/rel).read_text(encoding='utf-8')
        if name != 'portable_harness':
            src = once(src, original, observer)
            src = once(src, 'double OnTester(){DQDrain();', 'double OnTester(){DQDrain(true);')
        dest = frozen/(name+'.mq5'); dest.write_text(src, encoding='utf-8')
        sources[name] = str(dest.relative_to(ROOT))
    for p in (PARENT/'frozen').glob('*.json'):
        shutil.copyfile(p, frozen/p.name)
    # Keep the editable research successor aligned with its frozen implementation.
    daily = ROOT/'mql/Experts/Research/DailyChannelPortfolioPortable.mq5'
    text = daily.read_text(encoding='utf-8')
    text = once(text, '../../Include/Research/DealQuoteAudit.mqh', '../../Include/Research/PortableDealQuoteAudit.mqh')
    text = once(text, 'double OnTester(){DQDrain();', 'double OnTester(){DQDrain(true);')
    daily.write_text(text, encoding='utf-8')
    files = [inc, daily, ROOT/'tools/quality12b/prepare_portable_audit_r2.py',
             ROOT/'tools/quality12b/analyze_portable_audit_r2.py', ROOT/'tools/quality12b/test_portable_audit_r2.py',
             ROOT/'scripts/run-portable-audit-r2.ps1']
    # Inherited dependencies remain identical, except the intentionally revised research daily source.
    inherited = {p:h for p,h in old['hashes'].items() if p != str(daily.relative_to(ROOT))}
    hashes = dict(inherited)
    hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files+list(frozen.iterdir())})
    # Also lock the original observer, previously embedded but not listed as a dependency.
    original_path = ROOT/'mql/Include/Research/DealQuoteAudit.mqh'
    hashes[str(original_path.relative_to(ROOT))] = sha(original_path)
    save(out/'manifest.json', dict(old, sources=sources, hashes=hashes,
        revision=2, parent_manifest=str((PARENT/'manifest.json').relative_to(ROOT)),
        parent_manifest_sha256=sha(PARENT/'manifest.json'),
        change='Tester final deal collection only; all nine specifications and trading parameters unchanged'))
    return verify(out)

if __name__ == '__main__':
    p=argparse.ArgumentParser(); p.add_argument('--out',type=Path,default=DEFAULT); p.add_argument('--check',action='store_true'); a=p.parse_args()
    m=verify(a.out.resolve()) if a.check else prepare(a.out.resolve())
    print(json.dumps(dict(verified=True,revision=2,runs=len(m['runs']))))
