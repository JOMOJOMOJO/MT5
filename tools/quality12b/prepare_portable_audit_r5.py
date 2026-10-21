"""Freeze an audit-only continuation: re-audit six existing runs, execute four."""
import argparse
import json
import shutil
from pathlib import Path
from prepare_portable_audit import ROOT, verify, save, sha

DEFAULT = ROOT / 'reports/qa/portable_audit_20261012_r5'
PARENT = ROOT / 'reports/qa/portable_audit_20261009_r4'
ORIGIN = PARENT / 'runs/20261012_113626_a789b4ef'
REUSE_IDS = ('harness', 'daily_reference', 'daily_legacy_clock', 'daily_timer',
             'm5_USDJPY_reference', 'm5_USDJPY_portable')


def prepare(out):
    if (out / 'manifest.json').exists():
        return verify(out)
    parent = verify(PARENT)
    status = json.loads((ORIGIN / 'status.json').read_text(encoding='utf-8-sig'))
    assert status['status'] == 'FAILED' and status['run_id'] == 'm5_USDJPY_portable'
    frozen = out / 'frozen'
    frozen.mkdir(parents=True, exist_ok=True)
    sources = {}
    for name, rel in parent['sources'].items():
        dest = frozen / (name + '.mq5')
        shutil.copyfile(ROOT / rel, dest)
        assert sha(dest) == sha(ROOT / rel)
        sources[name] = str(dest.relative_to(ROOT))
    for source in (PARENT / 'frozen').glob('*.json'):
        shutil.copyfile(source, frozen / source.name)
    reuse = {}
    for run_id in REUSE_IDS:
        folder = ORIGIN / run_id
        assert (folder / 'report.htm').is_file() and (folder / 'inputs.set').is_file()
        files = {str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}
        reuse[run_id] = dict(source=str(folder.relative_to(ROOT)), files=files)
    tools = ['tools/quality12b/prepare_portable_audit_r5.py',
             'tools/quality12b/analyze_portable_audit_r5.py',
             'tools/quality12b/portable_risk_audit.py',
             'tools/quality12b/test_portable_audit_r5.py', 'scripts/run-portable-audit-r5.ps1']
    files = [ROOT / p for p in tools] + list(frozen.iterdir())
    files += [ORIGIN / 'status.json', ORIGIN / 'provenance.json']
    files += list(ORIGIN.glob('*.compile.log')) + list(ORIGIN.glob('*.ex5'))
    hashes = dict(parent['hashes'])
    hashes.update({str(p.relative_to(ROOT)): sha(p) for p in files})
    for item in reuse.values():
        hashes.update({str(Path(item['source']) / rel): value for rel, value in item['files'].items()})
    save(out / 'manifest.json', dict(parent, revision=5, sources=sources, hashes=hashes,
         parent_manifest=str((PARENT / 'manifest.json').relative_to(ROOT)),
         parent_manifest_sha256=sha(PARENT / 'manifest.json'), reuse=reuse,
         change='Audit-only correction for conservative volume rejection; six locked runs reused; four remaining runs executed; no MQL or strategy-input changes'))
    return verify(out)


def copy_verified_run(source, target, files):
    source, target = source.resolve(), target.resolve()
    assert not target.exists(), ('Refuse overwrite', target)
    assert not target.is_relative_to(source) and not source.is_relative_to(target)
    actual = {str(p.relative_to(source)) for p in source.rglob('*') if p.is_file()}
    assert actual == set(files), ('Reuse inventory changed', source)
    for rel, expected in files.items():
        p = (source / rel).resolve()
        assert p.is_relative_to(source), ('Unsafe reuse path', rel)
        assert sha(p) == expected, ('Reuse source changed', p)
    shutil.copytree(source, target)
    for rel, expected in files.items():
        assert sha(target / rel) == expected, ('Copy differs', rel)


def reuse_into(package, output):
    from analyze_portable_audit_r5 import check_r5
    manifest = verify(package)
    assert output.resolve().is_relative_to(package.resolve()), 'Reuse output must stay inside new package'
    output.mkdir(parents=True, exist_ok=True)
    copied = []
    for spec in manifest['runs']:
        run_id = spec['run_id']
        if run_id not in manifest['reuse']:
            continue
        item = manifest['reuse'][run_id]
        dest = output / run_id
        copy_verified_run(ROOT / item['source'], dest, item['files'])
        # Audit writes only to the copied run. The r4 evidence remains untouched.
        check_r5(dest, spec, package)
        entry = dict(run_id=run_id, source=item['source'], input_file_hashes=item['files'],
                     re_audited=True, newly_executed=False)
        save(dest / 'reuse_origin.json', entry)
        copied.append(entry)
    save(output / 'reuse_provenance.json', dict(reused=copied,
         pending=[r['run_id'] for r in manifest['runs'] if r['run_id'] not in manifest['reuse']]))
    verify(package)
    return dict(reused_runs=len(copied), pending_runs=len(manifest['runs'])-len(copied))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, default=DEFAULT)
    p.add_argument('--check', action='store_true')
    p.add_argument('--reuse-into', type=Path)
    a = p.parse_args()
    package = a.out.resolve()
    if a.reuse_into:
        result = reuse_into(package, a.reuse_into.resolve())
    else:
        m = verify(package) if a.check else prepare(package)
        result = dict(verified=True, revision=5, runs=len(m['runs']), reuse_runs=len(m['reuse']))
    print(json.dumps(result))
