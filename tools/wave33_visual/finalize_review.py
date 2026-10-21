"""Join native observations to explicitly labelled normal-chart drawing evidence."""
import csv
import json
import re
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports/qa/wave33_visual_20261020'
BATCH = OUT / '20261020_134635_b2cb2b0b'


def read(path, sep=','):
    with path.open(encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle, delimiter=sep))


def main():
    lines = ['# 3波3波 v1.0 初回レビュー成果物', '',
             '既存EAは変更せず、新規EAを実装した。目的は判断根拠の追跡であり、利益最適化・動画一致・運用昇格の判定はしていない。', '',
             '## 実行確認', '',
             '- EAと実エンジンharnessは0 errors / 0 warnings。最終harnessは100/100成功。',
             '- XAUUSD、2025-01-06～2025-01-18、real ticks。通常比較は1,291,229ティック。',
             '- A: 19候補（LONG 8 / SHORT 11）、PIVOTシグナル5件。B: 59候補（33 / 26）、PIVOT 27件、TRENDLINE 26件、先着29件。',
             '- 注文ON: Aは4約定・4決済、Bは24約定・24決済（LONG 15 / SHORT 9）。通常チャート禁止はソースガード。描画再生EAには注文コードがない。',
             '- 61.8%超過は初期値で計測のみ。抵抗表示・SKIP・CAPの各モードを実行した。', '',
             '## 描画の確認境界', '',
             '**実Visual=1テストではPNG保存要求がtrueでもファイルが生成されず、直接画面キャプチャは未確認。** Windows画面読み取りも許可タイムアウト。成績グラフをEA画像として数えていない。', '',
             '下表のPNGは、実CSVのイベントを同じDisplayモジュールで通常MT5チャートへ再生したもの。価格バーは実XAUUSD M1を事例の判断時刻で切った専用カスタム銘柄。後のバーは追加せず、売買・シグナルを再計算しない。テスター画面の直接キャプチャと区別する。W1暫定極値など元CSVにない履歴は復元しない。', '',
             '画像確認で帯の塗り・長いラベルの重なりと、M5水平線の2点が同じ足に入る表示不具合を発見し、描画のみ修正した。線の開始時刻・価格は維持し、旧判定線は更新時刻で右延長を止めて残した。', '',
             '| パターン | ID | 方向 | 候補認定 | 成立または失効の判断時刻 | 区分 | 描画再生 |',
             '|---|---|---|---|---|---|---|']
    evidence = []
    for arm, run in [('A', 'a_pivot_diagnostic'), ('B', 'b_pivot_diagnostic')]:
        cases = read(BATCH / run / 'review_cases.csv')
        render = read(OUT / 'drawing_review' / arm / 'render_summary.csv')
        for i, case in enumerate(cases):
            row = next(r for r in render if int(r['case']) == i)
            assert row['setup_id'] == case['setup_id'] and row['saved'] == '1'
            png = OUT / 'drawing_review' / arm / row['image']
            assert png.exists() and png.stat().st_size > 1000
            inventory_path = None
            for native_summary in (OUT / 'drawing_review' / arm).glob('*_render.csv'):
                if any(r.get('image') == row['image'] for r in read(native_summary, ';')):
                    inventory_path = native_summary.with_name(native_summary.name.removesuffix('_render.csv') + f'_case{i}_objects.csv')
                    break
            assert inventory_path and inventory_path.exists()
            inventory = read(inventory_path, ';')
            names = [r['name'] for r in inventory]
            assert all(len(n) <= 63 for n in names)
            signals = bool(case.get('signal_at'))
            if signals:
                assert any('_entry_' in n for n in names)
                assert any('_SL_' in n for n in names) and any('_TP_' in n for n in names)
            for item in inventory:
                if '_SL_' in item['name'] or '_TP_' in item['name']:
                    seconds = (datetime.strptime(item['time2'], '%Y.%m.%d %H:%M:%S') - datetime.strptime(item['time1'], '%Y.%m.%d %H:%M:%S')).total_seconds()
                    assert seconds >= (300 if arm == 'A' else 60)
            evidence.append({'arm': arm, 'setup_id': case['setup_id'], 'png': str(png.relative_to(OUT)),
                             'objects': len(inventory), 'signal': signals, 'native_tester_screenshot': False,
                             'object_names_within_63': True, 'sl_tp_anchor_spacing_passed': True})
            outcome = 'SIGNAL' if signals else case.get('skip_reason', '')
            outcome = outcome.replace('|', '/')
            lines.append(f"| {arm} | {case['setup_id']} | {case['direction']} | {case['candidate_detected_at']} | {row['cutoff']} | {outcome} | [PNG]({png.relative_to(OUT).as_posix()}) |")
    lines += ['', '全10事例に画像実体とオブジェクト一覧があり、画像名とsetup IDを照合した。成立例のENTRY/SL/TPと、SL/TPの表示足以上の2点間隔を機械確認した。画像は記録イベントの再生確認であり、実テスター画面や動画との完全一致を証明しない。', '',
              '## 詳細・原本', '',
              '- [Aの各5事例・根拠・時刻一覧](20261020_134635_b2cb2b0b/a_pivot_diagnostic/review_cases.md)',
              '- [Bの各5事例・根拠・時刻一覧](20261020_134635_b2cb2b0b/b_pivot_diagnostic/review_cases.md)',
              '- [8本の初回実行監査](20261020_134635_b2cb2b0b/review.md)',
              '- [100件の実harness結果](20261020_135037_fd91f301/engine_harness/harness.csv)',
              '- [Bの実注文イベント](20261020_135037_fd91f301/b_orders_smoke/events.csv)',
              '- [Aの実Visual=1監査（画像未生成）](20261020_135037_fd91f301/a_visual/audit.json)',
              '- [Bの実Visual=1監査（画像未生成）](20261020_173724_075de4c4/b_visual/audit.json)',
              '- [設定と目視照合手順](../../../docs/validation/wave33-v1-visual-review.md)', '',
              '描画修正後の最終A再実行は19候補・5シグナルで監査PASS。元の全イベントCSVとSHA-256が一致した（[比較](drawing_only_regression.json)）。描画によって売買判断が変わっていないことを、この固定区間で確認した。', '',
              '最終ユーザーレビュー欄: 一致 / EAの認識遅れ・過剰判定 / 動画から判断不能。動画画像未提供のため現在は未判定。成績改善へ進まず、差が出た場合は足数・価格差・知り得た時刻を説明してから修正する。', '']
    (OUT / 'README.md').write_text('\n'.join(lines), encoding='utf-8')
    (OUT / 'drawing_review' / 'audit.json').write_text(json.dumps({'cases': evidence, 'count': len(evidence), 'drawing_replay_audit_passed': True, 'direct_tester_capture_verified': False}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    notes = [OUT / 'README.md', ROOT / 'docs/validation/wave33-v1-visual-review.md',
             ROOT / 'docs/devlog/2026-10-20-wave33-visual-verifier.md',
             ROOT / 'content/seeds/2026-10-20-wave33-known-time-before-profit.md',
             BATCH / 'a_pivot_diagnostic/review_cases.md', BATCH / 'b_pivot_diagnostic/review_cases.md']
    for note in notes:
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', note.read_text(encoding='utf-8')):
            if target.startswith(('https://', 'http://', '#')):
                continue
            assert (note.parent / target.split('#')[0].strip('<>')).resolve().exists(), (note, target)
    print('10 native normal-chart replay PNGs + object inventories audited; direct tester capture remains unverified')


if __name__ == '__main__':
    main()
