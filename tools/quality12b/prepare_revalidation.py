"""Freeze historical MT5 inputs and the current unmodified EA. Never launches MT5."""
import argparse
import csv
import hashlib
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = ROOT / 'reports/qa/quality12b_revalidation_20261005'
SOURCE = ROOT / 'mql/Experts/usdjpy_20260402_round_continuation_long.mq5'
REPORTS = [ROOT / ('reports/backtest/imported/usdjpy_20260402_round_continuation_long-quality12b_guarded-' + x + '-m15.htm') for x in ('train-9m', 'oos-3m')]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs(path):
    data = path.read_bytes()
    text = data.decode('utf-16') if data[:2] in (b'\xff\xfe', b'\xfe\xff') else data.decode('utf-8-sig')
    plain = html.unescape(re.sub(r'<[^>]+>', ' ', text))
    pairs = re.findall(r'(Inp\w+)\s*=\s*([^\r\n]+)', plain)
    if len(pairs) != len(dict(pairs)):
        raise ValueError('Duplicate inputs in historical report')
    return {k: v.strip() for k, v in pairs}


def verify(out):
    manifest = json.loads((out / 'manifest.json').read_text(encoding='utf-8'))
    for name, expected in manifest['sha256'].items():
        if digest(out / name) != expected:
            raise ValueError('Frozen artifact changed: ' + name)
    print('Frozen package verified; no application launched.')
    return manifest


def prepare(out):
    if (out / 'manifest.json').exists():
        return verify(out)
    if out.exists():
        raise ValueError('Output exists without manifest; preserve it and choose another directory')
    values = inputs(REPORTS[0])
    if values != inputs(REPORTS[1]):
        raise ValueError('Historical train and check inputs differ')
    source_data = SOURCE.read_bytes()
    if b'../Include/Quality12b/' in source_data:
        from refactor_modules import reassemble
        source_data, _ = reassemble(source_data)
    names = re.findall(r'^input\s+\w+\s+(Inp\w+)\s*=', source_data.decode('utf-8-sig'), re.M)
    if len(names) != len(values) or set(names) != set(values):
        raise ValueError('Current source input schema differs from historical report; manual review required')
    enabled = [k for k, v in values.items() if k.endswith('Bucket') and v == 'true']
    assert enabled == ['InpEnableRoundBucket'], enabled
    assert values['InpSymbol'] == 'USDJPY' and values['InpSignalTimeframe'] == '15'
    assert values['InpStopLossPips'] == '22.0' and values['InpTargetRMultiple'] == '1.5'
    runs = [
        dict(run_id='reproduce_train', stage='Reproduce', date_from='2025.04.01', date_to='2025.12.31', label='KNOWN_SELECTED_TRAIN', expected_trades=60, expected_net=914.94, expected_pf=1.56),
        dict(run_id='reproduce_check', stage='Reproduce', date_from='2026.01.01', date_to='2026.04.01', label='KNOWN_REUSED_VALIDATION', expected_trades=9, expected_net=113.20, expected_pf=2.17),
    ]
    for year in range(2018, 2026):
        runs.append(dict(run_id=f'annual_{year}', stage='Extend', date_from=f'{year}.01.01', date_to=f'{year+1}.01.01', label='RETROSPECTIVE_NOT_OOS', expected_trades='', expected_net='', expected_pf=''))
    runs.append(dict(run_id='recent_2026_apr_sep', stage='Extend', date_from='2026.04.01', date_to='2026.10.01', label='UNUSED_STATUS_UNVERIFIED_NOT_OOS', expected_trades='', expected_net='', expected_pf=''))
    (out / 'frozen').mkdir(parents=True)
    (out / 'frozen/quality12b_snapshot.mq5').write_bytes(source_data)
    (out / 'frozen/inputs.json').write_text(json.dumps(values, indent=2) + '\n', encoding='utf-8')
    (out / 'frozen/quality12b_full.set').write_text('; All historical inputs; use isolated runner to avoid shared filenames\n' + '\n'.join(f'{k}={values[k]}' for k in names) + '\n', encoding='ascii')
    with (out / 'run_matrix.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(runs[0]))
        writer.writeheader()
        writer.writerows(runs)
    manifest = dict(schema=1, created='2026-10-05', status='PREPARED_NOT_EXECUTED', input_count=len(values),
                    source=str(SOURCE.relative_to(ROOT)), source_sha256=hashlib.sha256(source_data).hexdigest(),
                    source_identity_note='Current source with local Quality12b modules reassembled if present; historical binary identity is not proven. Reproduction is required.',
                    reference_reports=[dict(path=str(p.relative_to(ROOT)), sha256=digest(p)) for p in REPORTS],
                    runtime_only_overrides=['InpTelemetryFileName', 'InpOperatorCommandFile', 'InpStatusFileName'],
                    expected_broker='Vantage Trading Ltd', expected_server='VantageTradingLtd-Live',
                    symbol='USDJPY', timeframe='M15', model=4, execution_mode=0, deposit=10000, currency='USD', leverage=100,
                    runs=runs, sha256={})
    for path in sorted((out / 'frozen').iterdir()):
        manifest['sha256'][path.relative_to(out).as_posix()] = digest(path)
    manifest['sha256']['run_matrix.csv'] = digest(out / 'run_matrix.csv')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Prepared {len(runs)} fixed runs / {len(values)} inputs; no MT5 launched: {out}')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=DEFAULT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    (verify if args.check else prepare)(args.out.resolve())
