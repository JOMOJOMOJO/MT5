"""Causal timing, geometry, READY parity and protected-source audit."""
from pathlib import Path
import hashlib
import json
import difflib
import math
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / 'reports/qa/three_wave'
OUT = QA / 'fib_wave2'
manifest = json.loads((OUT / 'protected.json').read_text('utf-8-sig'))
for entry in manifest:
    assert hashlib.sha256(Path(entry['Path']).read_bytes()).hexdigest().upper() == entry['Hash']
fib = pd.read_csv(QA / 'fib_wave2_january/TW_fib_events.csv')
signals = pd.read_csv(QA / 'fib_wave2_january/TW_signals.csv')
arms = fib[fib.event == 'ARM'].set_index('key')
touches = fib[fib.event == 'TOUCH'].set_index('key')
decisions = fib[fib.event == 'DECISION'].set_index('key')
assert arms.index.is_unique and touches.index.is_unique and decisions.index.is_unique
assert touches.parent.is_unique
for row in touches.itertuples():
    arm = arms.loc[row.Index]
    confirmed = pd.Timestamp(row.wave1_confirmed).value // 1_000_000
    assert row.tick_msc >= arm.tick_msc >= confirmed
    assert row.zone_bottom <= row.bid <= row.zone_top
    span = row.wave1_high-row.reversal_low
    assert abs(row.zone_bottom-(row.wave1_high-span*.618)) < 1e-9
    assert abs(row.zone_top-(row.wave1_high-span*.382)) < 1e-9
for row in decisions.itertuples():
    touch = touches.loc[row.Index]
    assert row.tick_seq == touch.tick_seq+1
    assert row.tick_msc >= touch.tick_msc
    assert row.bid >= row.reversal_low
    if row.sent:
        time = pd.Timestamp(row.tick_msc, unit='ms').floor('s')
        matches = signals[(pd.to_datetime(signals.signal_time) == time) & signals.sent]
        assert len(matches) == 1
        s = matches.iloc[0]
        assert abs(s.entry_price-row.ask) < 1e-9
        expected_sl=math.floor((row.reversal_low-.010)/.001+1e-9)*.001
        assert abs(s.sl-expected_sl) < 1e-9
        assert s.stop_mode == 'STOP_M1_REVERSAL_LOW'
        assert abs(s.tp-(s.entry_price+(s.entry_price-s.sl)*s.rr)) <= .00050001
        assert s.expected_loss <= s.equity*.01+1e-7
assert len(signals) == len(decisions)
assert (signals.state_transition_reason == 'FIB_WAVE2_NEXT_TICK').all()
ready = pd.read_csv(QA / 'fib_wave2_ready/TW_signals.csv')
base = pd.read_csv(QA / 'ema_filter_final/TW_signals.csv')
pd.testing.assert_frame_equal(ready, base)
ready_deals = pd.read_csv(QA / 'fib_wave2_ready/TW_deals.csv')
base_deals = pd.read_csv(QA / 'ema_filter_final/TW_deals.csv')
pd.testing.assert_frame_equal(ready_deals, base_deals)
deals = pd.read_csv(QA / 'fib_wave2_january/TW_deals.csv')
entry_times = deals[(deals.entry == 0) & (deals.type == 0)].time_msc.sort_values()
assert (entry_times.diff().dropna() >= 900000).all()
policy = pd.read_csv(OUT / 'policy.csv').iloc[0]
assert policy.checks == 12 and policy.failures == 0
before = (OUT / 'baseline.mq5').read_text().splitlines(True)
after = (ROOT / 'mql/Experts/USDJPY_3Wave_FibWave2Research.mq5').read_text().splitlines(True)
(OUT / 'entry_adapter.diff').write_text(''.join(difflib.unified_diff(before, after, fromfile='current_standard_EA', tofile='FibWave2Research')), encoding='utf-8')
result = dict(status='PASS', protected_files=len(manifest), native_policy_checks=12,
              arms=len(arms), touches=len(touches), decisions=len(decisions),
              fib_orders=int(signals.sent.sum()), ready_orders=int(ready.sent.sum()),
              fib_reasons=signals.reason.value_counts().to_dict(),
              ready_signals_and_deals_identical=True,
              next_tick_and_closed_confirmation=True,
              risk_and_cooldown=True)
(OUT / 'audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
