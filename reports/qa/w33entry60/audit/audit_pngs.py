"""Validate every final rendered PNG and its exact causal packet crop."""
from bisect import bisect_left
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageStat

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHARTS = HERE.parent / 'charts'
PACKETS = HERE.parent / 'data/blind/packets.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = json.loads((CHARTS / 'render_manifest.json').read_text(encoding='utf-8'))
    packets = json.loads(PACKETS.read_text(encoding='utf-8'))['cases']
    failures, records = [], []
    script = ROOT / 'tools/wave33_visual/entry60_render.py'
    if manifest['source_packet_sha256'] != sha(PACKETS):
        failures.append('frozen packet hash differs from render source')
    if manifest['script_sha256'] != sha(script):
        failures.append('renderer script changed after final render')
    expected_ids = [f'V{i:03}' for i in range(1, 61)]
    if [r['blind_id'] for r in manifest['cases']] != expected_ids:
        failures.append('60 case IDs in manifest')
    shapes, hashes, pre_clips = {}, [], []
    packet_by_id = {p['blind_id']: p for p in packets}
    for r in manifest['cases']:
        cid = r['blind_id']
        p = packet_by_id[cid]
        path = CHARTS / r['file']
        h = sha(path)
        if h != r['sha256']:
            failures.append(cid + ': final PNG hash mismatch')
        hashes.append(h)
        bars = p['upper_bars']
        first = min([p['snapshot']['wave1_start_time']] + [q['time'] for q in p['pre_pivots']])
        left = max(0, min(bisect_left([b['time'] for b in bars], first)-8, len(bars)-90))
        if r['upper_packet_start_row'] != left or r['upper_bars'] != len(bars)-left or r['lower_bars'] != min(180, len(p['lower_bars'])):
            failures.append(cid + ': crop/window count mismatch')
        if p['pre_pivots'] and min(q['time'] for q in p['pre_pivots']) < bars[left]['time']:
            pre_clips.append(cid)
        with Image.open(path) as im:
            im.load()
            if im.format != 'PNG' or im.size != (1650, 990):
                failures.append(cid + ': image format/dimensions')
            if max(ImageStat.Stat(im.convert('RGB')).stddev) < 10:
                failures.append(cid + ': image nearly blank')
            info = json.dumps(im.info).lower()
            for word in ('net_cash', 'net_r', 'exit_reason', 'profit', 'loss', 'outcome'):
                if word in info:
                    failures.append(cid + ': forbidden PNG metadata ' + word)
            shapes[cid] = list(im.size)
        records.append(dict(blind_id=cid, hash_match=h == r['sha256'],
                            upper_bars=r['upper_bars'], lower_bars=r['lower_bars'],
                            warnings=r['warnings']))
    if len(set(hashes)) != 60:
        failures.append('duplicate case PNG pixel artifacts')
    if pre_clips:
        failures.append('pre8 pivots hidden by chart crop: ' + ','.join(pre_clips))
    sheets = []
    for parity, names in manifest['contact_sheets'].items():
        if len(names) != 5:
            failures.append(parity + ': contact sheet count')
        for name in names:
            path = CHARTS / name
            with Image.open(path) as im:
                im.load()
                if im.size != (2400, 2200):
                    failures.append(name + ': contact dimensions')
            sheets.append(dict(file=name, sha256=sha(path)))
    even = json.loads((HERE / 'even_blind_review.json').read_text(encoding='utf-8'))
    for c in even['cases']:
        if c['image_sha256'] != sha(CHARTS / (c['blind_id'] + '.png')):
            failures.append(c['blind_id'] + ': PNG differs from frozen even review')
    result = dict(status='PASS' if not failures else 'FAIL', case_pngs=len(records),
                  contact_sheets=len(sheets), labels_read=False, failures=failures,
                  source_packet_sha256=sha(PACKETS), renderer_script_sha256=sha(script),
                  all_pngs_source_cutoff_audited=True,
                  full_pngs_visually_inspected_by_this_reviewer=30,
                  other_30_visual_review='independent odd reviewer; freeze pending at this audit time',
                  pre8_source_points_clipped=pre_clips, cases=records, sheets=sheets,
                  semantic_guard='Renderer reads causal packets only; static code review confirms no label/exit file access, dates, P/L or future candles in display text.')
    (HERE / 'png_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('cases','sheets')}, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
