"""Check native tester decisions against independent archived M1 EMA calculations."""
from pathlib import Path
import json
import re
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / 'reports/qa/three_wave'
bars = pd.read_csv(QA / 'resistance_research/TW_resistance_M1.csv')
bars.index = pd.to_datetime(bars.time, format='%Y.%m.%d %H:%M:%S')
for period in (20, 50, 100):
    bars[f'ema{period}'] = bars.close.ewm(span=period, adjust=False).mean()
log = (QA / 'ema_filter_final/tester.log').read_text(encoding='utf-8-sig')
checked = 0
maximum_error = 0.0
outcomes = {}
for line in log.splitlines():
    if 'TW_EMA_FILTER decision=' not in line:
        continue
    when = pd.Timestamp(re.search(r'decision=(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})', line)[1])
    closed = pd.Timestamp(re.search(r'closed_bar=(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})', line)[1])
    assert closed < when
    history = bars.loc[bars.index < when]
    assert history.index[-1] == closed
    current, previous = [], []
    for period in (20, 50, 100):
        for key, offset, dest in [(f'ema{period}', -1, current), (f'prev{period}', -2, previous)]:
            recorded = float(re.search(rf'\b{key}=([0-9.]+)', line)[1])
            expected = history[f'ema{period}'].iloc[offset]
            error = abs(recorded - expected)
            maximum_error = max(maximum_error, error)
            assert error < 1e-7, (when, key, recorded, expected)
            dest.append(expected)
    ordered = current[0] > current[1] > current[2]
    rising = all(a > b for a, b in zip(current, previous))
    expected = 'EMA_ORDER_NOT_BULLISH' if not ordered else ('EMA_NOT_ALL_RISING' if not rising else 'EMA_PASS')
    assert f'result={expected}' in line
    outcomes[str(when)] = expected
    checked += 1
on = pd.read_csv(QA / 'ema_filter_final/TW_signals.csv')
off = pd.read_csv(QA / 'ema_filter_off/TW_signals.csv')
assert on.signal_id.tolist() == off.signal_id.tolist()
assert checked == len(on) > 0
for row in on.itertuples():
    allowed = outcomes[str(pd.Timestamp(row.signal_time))] == 'EMA_PASS'
    if row.sent:
        assert allowed
    if not allowed:
        assert row.reason.startswith('EMA_') and not row.sent
result = dict(status='PASS', checked=checked, max_ema_error=maximum_error,
              ready_ids_unchanged=True, on_reasons=on.reason.value_counts().to_dict(),
              off_reasons=off.reason.value_counts().to_dict())
(QA / 'ema_filter/audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
