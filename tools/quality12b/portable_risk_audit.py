"""Validate recorded risk plans. A denied plan is not a placed oversized trade."""
import math
from collections import Counter
from datetime import datetime, timezone


def minute_key(text):
    return int(datetime.strptime(text, '%Y.%m.%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp()) // 60


def audit_risk(rows, deals, risk_percent):
    assert math.isfinite(risk_percent) and risk_percent > 0
    entry_minutes = {(r['symbol'], int(r['time_msc']) // 60000)
                     for r in deals if int(r['entry_kind']) in (0, 2)}
    rejections = []
    allowed = {'OK', 'MIN_VOLUME_EXCEEDS_RISK', 'INSUFFICIENT_MARGIN',
               'NORMALIZED_VOLUME_EXCEEDS_RISK'}
    for row in rows:
        reason = row['reason']
        assert reason in allowed, ('Unexpected risk reason', row)
        values = {k: float(row[k]) for k in ('contract_size', 'min_volume', 'max_volume',
                  'step', 'minimum_equity', 'min_loss', 'budget', 'planned_loss', 'volume')}
        assert all(math.isfinite(v) for v in values.values()), ('Nonfinite risk data', row)
        assert values['contract_size'] > 0 and values['min_volume'] > 0
        assert values['budget'] > 0 and values['min_loss'] > 0
        assert math.isclose(values['minimum_equity'], values['min_loss'] * 100 / risk_percent,
                            rel_tol=1e-8)
        if reason in ('OK', 'NORMALIZED_VOLUME_EXCEEDS_RISK'):
            assert values['min_volume'] - 1e-10 <= values['volume'] <= values['max_volume'] + 1e-10
            assert values['step'] > 0
            units = values['volume'] / values['step']
            assert abs(units - round(units)) <= 1e-7
        if reason == 'OK':
            assert 0 < values['planned_loss'] <= values['budget'] + 1e-7, ('Accepted risk exceeds budget', row)
        elif reason == 'MIN_VOLUME_EXCEEDS_RISK':
            assert values['min_loss'] > values['budget'] or values['volume'] == 0
        elif reason == 'NORMALIZED_VOLUME_EXCEEDS_RISK':
            assert values['min_loss'] <= values['budget'] + 1e-7, ('Wrong rejection stage', row)
            assert values['planned_loss'] > values['budget'] + 1e-7, ('Contradictory rejection', row)
            assert (row['symbol'], minute_key(row['time'])) not in entry_minutes, ('Rejected plan was filled in signal minute', row)
            rejections.append(dict(time=row['time'], symbol=row['symbol'], volume=values['volume'],
                                   budget=values['budget'], planned_loss=values['planned_loss'],
                                   excess=values['planned_loss'] - values['budget'],
                                   no_entry_in_signal_minute=True))
    return dict(risk_reasons=dict(Counter(r['reason'] for r in rows)),
                risk_reasons_by_symbol={s: dict(Counter(r['reason'] for r in rows if r['symbol'] == s))
                                        for s in sorted({r['symbol'] for r in rows})},
                normalized_risk_rejections=rejections,
                evidence_limit='No same-symbol entry deal in the rejection minute; not a general proof about delayed submissions')
