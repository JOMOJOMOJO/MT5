"""One-time, fail-if-existing migration. No tester or production terminal writes."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'mql/Include/RelativeContinuation'
MAIN = ROOT / 'mql/Experts/RelativeContinuation.mq5'

def main():
    if DEST.exists() or MAIN.exists():
        raise SystemExit('Successor exists; edit it normally, do not rerun migration')
    DEST.mkdir()
    paths = list((ROOT / 'mql/Include/Quality12b').glob('*.mqh'))
    paths.append(ROOT / 'mql/Experts/usdjpy_20260402_round_continuation_long.mq5')
    mapping = []
    for path in paths:
        text = path.read_text(encoding='utf-8-sig')
        if path.name == 'Configuration.mqh':
            def convert(m):
                typ, name, val = m.groups()
                newname = name.replace('Pips', 'Atr')
                newval = float(val)/10
                mapping.append(dict(old=name, new=newname, old_default=float(val), new_default=newval,
                                    note='Initial engineering scale only: old numeric value / 10, NOT equivalent trades or fitted ATR'))
                return f'input double {newname} = {newval:g};'
            text = re.sub(r'input\s+(int|double)\s+(Inp\w*Pips)\s*=\s*([\d.]+);', convert, text)
        text = text.replace('Quality12b/', 'RelativeContinuation/').replace('QUALITY12B_', 'RELATIVE_CONTINUATION_')
        text = text.replace('GetPipSize', 'GetDistanceUnit').replace('Pips', 'Atr').replace('spread_pips', 'spread_atr')
        text = re.sub(r'\bpip\b', 'unit', text)
        text = text.replace('InpRoundStepAtr', 'InpGridStepAtr')
        target = MAIN if path.suffix == '.mq5' else DEST / path.name
        target.write_text(text, encoding='utf-8')
    out = ROOT / 'reports/qa/relative_continuation_20261006'
    out.mkdir(parents=True, exist_ok=True)
    for row in mapping:
        row['new'] = row['new'].replace('InpRoundStepAtr', 'InpGridStepAtr')
    (out / 'parameter_migration.json').write_text(json.dumps(mapping, indent=2)+'\n', encoding='utf-8')
    print(f'Created successor; {len(mapping)} price-distance inputs migrated; original untouched')

if __name__ == '__main__':
    main()
