"""Index immutable study evidence without rerunning selection or holdout."""
import csv
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports/analysis/tick_shock/usdjpy_only_ml_20260912'
BATCH = ROOT / 'reports/backtest/batches/usdjpy_only_ml_20260912'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def main():
    freeze = json.loads((OUT / 'freeze_record.json').read_text())
    for name, expected in freeze['files'].items():
        assert sha(OUT / name) == expected, name
    assert sha(ROOT / 'tools/tick_shock/usdjpy_only_ml.py') == freeze['driver_sha256']
    assert sha(ROOT / 'docs/research/tick_shock/usdjpy_only_ml_preregistration.md') == freeze['prereg_sha256']
    for name, expected in freeze['source_files'].items():
        assert sha(ROOT / name) == expected, name
    assert json.loads((BATCH / 'summary.json').read_text())['qa_failures'] == 0
    sources = list((ROOT / 'tools/tick_shock').glob('*usdjpy_only*'))
    sources += [ROOT / 'tools/tick_shock/verify_usdjpy_forward_frontier.py']
    sources += list((ROOT / 'mql/Include/TickShock4m2mFrozen').rglob('*.mqh'))
    sources += [ROOT / p for p in [
        'mql/Include/TickShockUSDJPYOnlyModel.mqh',
        'mql/Experts/ExpectedValue_USDJPY_TickShockMLHoldout.mq5',
        'mql/Experts/tests/ExpectedValue_USDJPY_TickShockMLParityHarness.mq5',
        'tools/tick_shock/technical_ml_discovery.py',
        'tools/tick_shock/analyze_technical_discovery.py',
        'tools/tick_shock/analyze_technical_4m2m_real.py',
        'tools/tick_shock/interpret_technical_ml_discovery.py',
        'tools/tick_shock/verify_technical_month_capture.py',
        'scripts/compile.ps1', 'scripts/backtest.ps1']]
    docs = [ROOT / p for p in [
        'docs/research/tick_shock/usdjpy_only_ml_preregistration.md',
        'docs/research/tick_shock/usdjpy_only_ml_results.md',
        'docs/devlog/2026-09-13-tickshock-usdjpy-only-ml.md',
        'knowledge/experiments/2026-09-13-tickshock-usdjpy-only-ml.md',
        'content/seeds/2026-09-13-frequency-calibration-is-not-a-trade-quota.md']]
    files = set(sources + docs + list(OUT.rglob('*')) + list(BATCH.rglob('*')))
    rows = []
    for path in sorted(files):
        if not path.is_file() or path.name in {'delivery_manifest.csv', 'delivery_completion.json'}:
            continue
        if 'deterministic_full_replay' in path.parts or '__pycache__' in path.parts:
            continue
        relative = path.relative_to(ROOT).as_posix()
        ignored = subprocess.run(['git', 'check-ignore', '-q', '--', relative], cwd=ROOT).returncode == 0
        # Only the two compiler logs are deliberately force-added. Other ignored raw remains local.
        forced = (path.parent == BATCH and path.name in {'candidate_compile.log', 'parity_compile.log'}) or (path.parent == OUT and path.suffix == '.log')
        rows.append(dict(path=relative, sha256=sha(path), bytes=path.stat().st_size,
                         role='source_dependency' if path in sources else 'evidence_or_document',
                         delivery='LOCAL_ONLY' if ignored and not forced else 'COMMIT'))
    with (OUT / 'delivery_manifest.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=['path','sha256','bytes','role','delivery'])
        writer.writeheader()
        writer.writerows(rows)
    result = dict(status='COMPLETED_NOT_PRODUCTION_ELIGIBLE', freeze_integrity=True,
                  model_sha256=sha(OUT/'frozen_model.json'), artifacts=len(rows),
                  source_dependencies=len(set(sources)), mt5_qa_failures=0,
                  source_prerequisites_commit='f0415e6712748802d7db8069d803dd01f30fddc5',
                  manifest_self_hash_excluded=True,
                  local_only_reason='Caches, repeated replay outputs and identifying/full-scanner raw stay local; USDJPY compressed inputs and compact evidence are delivered.',
                  terminal_and_binary_hashes='reports/backtest/batches/usdjpy_only_ml_20260912/source_hashes.csv',
                  standard_dependencies='MT5 standard MQL library and pinned Python requirements',
                  unrelated_worktree_changes='Preserved; not staged or repaired.')
    (OUT/'delivery_completion.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
