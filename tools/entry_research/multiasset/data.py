"""Read-only MT5 rates acquisition with explicit broker/clock quality ledger."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import time

import numpy as np
import pandas as pd

LOCK = 1767225600  # 2026-01-01; do not request or accept any later price


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()


def stamp(value):
    return int(pd.Timestamp(value, tz='UTC').timestamp())


def guarded_period(config):
    start, end = stamp(config['warmup_start']), stamp(config['end'])
    if not start < end <= LOCK:
        raise ValueError('development period must end at or before locked 2026')
    return start, end


def normalize(frame, step, start, end):
    """Fail on out-of-range/invalid prices; never silently repair observations."""
    if end > LOCK or not start < end:
        raise ValueError('holdout guard')
    df = frame.copy()
    if df.empty:
        raise ValueError('empty rates')
    if ((df.time < start) | (df.time >= end)).any():
        raise ValueError('out of requested period, including locked holdout')
    if df.time.duplicated().any():
        raise ValueError('duplicate timestamps')
    prices = df[['open', 'high', 'low', 'close']]
    if not np.isfinite(prices.to_numpy()).all() or (prices <= 0).any().any():
        raise ValueError('invalid price')
    if ((df.high < prices.max(axis=1)) | (df.low > prices.min(axis=1))).any():
        raise ValueError('invalid OHLC geometry')
    df = df.sort_values('time').reset_index(drop=True)
    df['close_time'] = df.time + step
    if 'available_time' not in df:
        df['available_time'] = df.close_time
    df['available_time'] = np.maximum(df.available_time, df.close_time)
    return df


def audit(frame, step, config):
    selected = frame[(frame.time >= stamp(config['start'])) & (frame.time < stamp(config['end']))]
    dt = pd.to_datetime(selected.time, unit='s', utc=True)
    gaps = pd.DataFrame({'previous_time': selected.time.shift(), 'next_time': selected.time})
    gaps['seconds'] = gaps.next_time - gaps.previous_time
    gaps = gaps[gaps.seconds != step].dropna()
    coverage = pd.DataFrame({'month': dt.dt.strftime('%Y-%m')}).groupby('month').size()
    months = pd.date_range(config['start'], config['end'], freq='MS', inclusive='left').strftime('%Y-%m')
    result = {'rows': len(frame), 'development_rows': len(selected),
              'first_time': int(frame.time.min()), 'last_time': int(frame.time.max()),
              'first_development_time': int(selected.time.min()) if len(selected) else None,
              'last_development_time': int(selected.time.max()) if len(selected) else None,
              'months_with_data': int(len(coverage)), 'months_expected': len(months),
              'months_missing': [x for x in months if x not in coverage],
              'noncontiguous_intervals': len(gaps),
              'nonpositive_spread_rows': int((frame.spread.fillna(0) <= 0).sum()),
              'duplicates': 0, 'invalid_ohlc': 0,
              'missing_slots_status': 'gaps include weekend/holiday closure; no verified exchange calendar',
              'ask_history': 'unavailable; bar spread is proxy, not execution quote',
              'clock_basis': 'source_clock_unverified; API UTC contract not independently broker-verified'}
    return result, gaps, coverage.reindex(months, fill_value=0).rename_axis('month').rename('rows').reset_index()


def fetch(terminal, out, config, resume=False):
    import MetaTrader5 as mt5
    out = Path(out)
    prior = None
    if (out / 'manifest.json').exists() and not resume:
        raise FileExistsError('immutable acquisition directory already has manifest')
    if (out / 'manifest.json').exists():
        prior = json.loads((out / 'manifest.json').read_text(encoding='utf-8'))
        if prior['config_sha256'] != hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest():
            raise ValueError('resume config mismatch')
        for r in prior['datasets']:
            if r.get('path') and sha(r['path']) != r['sha256']:
                raise ValueError('resume data hash mismatch')
    out.mkdir(parents=True, exist_ok=True)
    start, end = guarded_period(config)
    records = prior['datasets'] if prior else []
    requests = pd.read_csv(out / 'requests.csv').to_dict('records') if prior else []
    specs = prior['specs'] if prior else {}
    if not mt5.initialize(str(terminal), portable=True, timeout=30000):
        raise RuntimeError(f'MT5 initialize: {mt5.last_error()}')
    try:
        terminal_info = mt5.terminal_info()
        if terminal_info.trade_allowed:
            raise RuntimeError('research terminal must have algo trading disabled')
        account = mt5.account_info()
        server = account.server if account else 'unavailable'
        broker = account.company if account else 'unavailable'
        if prior and (server != prior['server'] or broker != prior['broker']):
            raise ValueError('cannot mix brokers on resume')
        manifest = {'broker': broker, 'server': server, 'source': 'MT5 Python copy_rates_range',
                    'terminal_build': terminal_info.build, 'maxbars': terminal_info.maxbars,
                    'start': config['start'], 'end_exclusive': config['end'],
                    'warmup_start': config['warmup_start'], 'holdout_locked': True,
                    'clock_basis': 'source_clock_unverified', 'api_timestamp_contract': 'UTC',
                    'history_spec_verified': False, 'tick_history_verified': False,
                    'config_sha256': hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest(),
                    'datasets': records, 'specs': specs}
        edges = pd.date_range(config['warmup_start'], config['end'], freq='MS', tz='UTC')
        for symbol in config['symbols']:
            if not mt5.symbol_select(symbol, True):
                records.append({'symbol': symbol, 'status': 'symbol_unavailable'})
                continue
            info = mt5.symbol_info(symbol)
            specs[symbol] = {'symbol': symbol, 'point': info.point, 'digits': info.digits,
                'pip_size': .01 if symbol.endswith('JPY') else .0001,
                'tick_size': info.trade_tick_size, 'tick_value': info.trade_tick_value,
                'contract_size': info.trade_contract_size, 'volume_min': info.volume_min,
                'volume_step': info.volume_step, 'volume_max': info.volume_max,
                'currency_profit': info.currency_profit, 'currency_base': info.currency_base,
                'account_currency': 'USD', 'historical_spec_verified': False,
                'spec_time_basis': 'current_metadata_not_historical',
                'pip_convention': 'explicit_FX_convention_not_inferred_from_digits'}
            for tf, step in config['timeframes'].items():
                if any(r['symbol'] == symbol and r.get('timeframe') == tf for r in records):
                    continue
                chunks = []
                for left, right in zip(edges[:-1], edges[1:]):
                    rates = None
                    for attempt in range(3):
                        rates = mt5.copy_rates_range(symbol, getattr(mt5, 'TIMEFRAME_' + tf),
                                                    left.to_pydatetime(), (right-pd.Timedelta(seconds=1)).to_pydatetime())
                        if rates is not None and len(rates) and ((rates['time'] < left.timestamp()) | (rates['time'] >= right.timestamp())).any():
                            requests.append({'symbol': symbol, 'timeframe': tf, 'start': left.isoformat(),
                                'end_exclusive': right.isoformat(), 'rows': len(rates), 'status': 'rejected_out_of_range',
                                'first_returned_time': int(rates['time'].min()), 'last_returned_time': int(rates['time'].max())})
                            rates = None  # quarantine entire response; never ingest future prices
                        if rates is not None and len(rates):
                            break
                        time.sleep(.2)
                    requests.append({'symbol': symbol, 'timeframe': tf, 'start': left.isoformat(),
                                     'end_exclusive': right.isoformat(), 'rows': 0 if rates is None else len(rates),
                                     'status': 'ok' if rates is not None and len(rates) else 'no_valid_rates: '+str(mt5.last_error())})
                    if rates is not None and len(rates):
                        part = pd.DataFrame(rates)
                        if ((part.time < left.timestamp()) | (part.time >= right.timestamp())).any():
                            raise ValueError('API returned rates outside requested interval')
                        chunks.append(part)
                record = {'symbol': symbol, 'timeframe': tf, 'seconds': step, 'server': server}
                if not chunks:
                    record['status'] = 'no_history'
                else:
                    df = normalize(pd.concat(chunks, ignore_index=True), step, start, end)
                    quality, gaps, coverage = audit(df, step, config)
                    path = out / symbol / (tf + '.parquet')
                    path.parent.mkdir(exist_ok=True)
                    df.to_parquet(path, index=False)
                    gaps.to_csv(path.with_suffix('.gaps.csv'), index=False)
                    coverage.to_csv(path.with_suffix('.coverage.csv'), index=False)
                    record.update(quality)
                    record.update(status='available', path=str(path.resolve()), sha256=sha(path))
                records.append(record)
                (out / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
                pd.DataFrame(requests).to_csv(out / 'requests.csv', index=False)
                print(symbol, tf, record['status'], record.get('development_rows', 0), flush=True)
        pd.DataFrame(records).drop(columns=['months_missing'], errors='ignore').to_csv(out / 'audit.csv', index=False)
        return manifest
    finally:
        mt5.shutdown()


def load_dataset(manifest, symbol, timeframe, config):
    records = [x for x in manifest['datasets'] if x['symbol'] == symbol and x.get('timeframe') == timeframe and x['status'] == 'available']
    if not records:
        return None
    record = records[0]
    if sha(record['path']) != record['sha256']:
        raise ValueError('dataset hash mismatch')
    start, end = guarded_period(config)
    return normalize(pd.read_parquet(record['path']), config['timeframes'][timeframe], start, end)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--terminal', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--resume', action='store_true')
    p.add_argument('--config', default=str(Path(__file__).with_name('config.json')))
    a = p.parse_args()
    fetch(a.terminal, a.out, json.loads(Path(a.config).read_text(encoding='utf-8')), a.resume)
