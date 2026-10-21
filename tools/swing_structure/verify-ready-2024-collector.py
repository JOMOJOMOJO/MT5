from pathlib import Path
import json
import pandas as pd

root = Path('reports/qa/three_wave')
new = root / 'ready_2024_ml/smoke'
old = root / 'm15_normal_ready_ema_off/smoke_observer'
for name in ['TW_signals.csv', 'TW_ready_shadows.csv']:
    pd.testing.assert_frame_equal(pd.read_csv(new/name), pd.read_csv(old/name), check_exact=True)
counts = {}
for tf, seconds in [('M1',60),('M5',300),('M15',900),('H1',3600)]:
    bars = pd.read_csv(new/f'TW_ml_bars_PERIOD_{tf}.csv')
    assert len(bars)>100 and bars.time.is_unique
    assert (bars.time.diff().dropna()>0).all()
    assert (bars.time+seconds<=bars.available_at).all()
    counts[tf]=len(bars)
quotes = pd.read_csv(new/'TW_ml_entry_quotes.csv')
shadows = pd.read_csv(new/'TW_ready_shadows.csv')
assert len(quotes)==len(shadows) and len(quotes)>0
assert list(quotes.signal_id)==list(shadows.signal_id)
assert (quotes.time_msc.values==shadows.entry_msc.values).all()
assert (quotes.ask.values==shadows.entry.values).all()
(new.parent/'smoke_validation.json').write_text(json.dumps({'parity':'PASS','closed_bars':counts,'quotes':len(quotes)},indent=2))
