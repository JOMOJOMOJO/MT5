"""Descriptive presentation audit. Never recompute or change frozen inference."""
import argparse
import hashlib
import json
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

KEYS = ['symbol', 'timeframe', 'method', 'side']
STATES = ['tp_first', 'sl_first', 'ambiguous', 'neither']
METRICS = ['gross_pips', 'net_pips', 'gross_atr', 'net_atr',
           'mfe_pips', 'mae_pips', 'mfe_atr', 'mae_atr', 'total_cost_pips']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def finish(out):
    out = Path(out)
    inputs = {str(p): sha(p) for p in out.glob('*.parquet')
              if p.stem not in ['barrier_rates', 'baseline_metrics', 'evidence_status']}
    manifest = json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    assert manifest['status'] == 'completed'
    cfg = manifest['config']
    primary = pd.read_parquet(out/'primary.parquet')
    counts = pd.read_parquet(out/'barrier_counts.parquet')
    rows, metrics, statuses = [], [], []
    for r in primary.to_dict('records'):
        ids = {k: r[k] for k in KEYS}
        cell = out/r['symbol']/r['timeframe']/(r['method']+'_'+r['side'])
        mask = counts.horizon.eq(10)
        for k, v in ids.items():
            mask &= counts[k].eq(v)
        sub = counts[mask]
        local = []
        for population in ['strategy', 'unconditional', 'conditional']:
            reps = 1 if population == 'strategy' else cfg['baseline_repeats']
            tally = sub[sub.population.eq(population)].set_index('outcome')['n']
            denominator = int(tally.reindex(STATES, fill_value=0).sum())
            assert denominator == r['n']*reps
            censored = int(tally.get('censored', 0))
            assert censored == (r['n_candidates']-r['n'] if population == 'strategy' else 0)
            for state in STATES:
                count = int(tally.get(state, 0))
                rows.append(dict(ids, population=population, horizon=10, tp_atr=1., sl_atr=1.,
                    outcome=state, n=count, denominator=denominator,
                    rate=count/denominator if denominator else np.nan,
                    original_candidates=r['n_candidates'], comparison_candidates=r['n'],
                    repeat_count=reps, censored_source_rows=censored,
                    inference='descriptive_only_not_independent_repeated_samples'))
            filename = 'outcomes.parquet' if population == 'strategy' else population+'_outcomes.parquet'
            file = cell/filename
            inputs[str(file)] = sha(file)
            data = pd.read_parquet(file)
            data = data[data.horizon.eq(10) & data.complete].copy()
            assert len(data) == denominator
            data['tp_reach_rate'] = (data.mfe_atr >= 1.).astype(float)
            data['sl_reach_rate'] = (data.mae_atr >= 1.).astype(float)
            cols = METRICS+['tp_reach_rate', 'sl_reach_rate']
            if population == 'strategy':
                means = data[cols].mean()
            else:
                sizes = data.groupby('replicate').size()
                assert len(sizes) == reps and sizes.eq(r['n']).all()
                means = data.groupby('replicate')[cols].mean().mean()
            local.append(dict(ids, population=population, horizon=10, n=denominator,
                              comparison_candidates=r['n'], repeat_count=reps,
                              **{('mean_'+k if k in METRICS else k): float(v) for k, v in means.items()}))
        for record in local:
            for metric in ['net_atr','net_pips','mfe_atr','mae_atr']:
                record['strategy_minus_population_'+metric] = local[0]['mean_'+metric]-record['mean_'+metric]
            metrics.append(record)
        reasons = []
        if not r['sample_gate']:
            reasons.append('n_lt_200_or_weeks_lt_30')
        if min(r['n_2024'], r['n_2025']) < cfg['minimum_candidates_per_year']:
            reasons.append('annual_n_lt_75')
        if not r['annual_gate']:
            reasons.append('annual_net_or_control_stability_failed')
        if not r['data_complete_months']:
            reasons.append('incomplete_24_months')
        for name in ['net', 'delta_unconditional', 'delta_conditional']:
            if not r[name+'_ci_low'] > 0:
                reasons.append(name+'_ci_not_positive')
            if not r[name+'_holm'] <= .05:
                reasons.append(name+'_holm_failed')
        sufficient = bool(r['sample_gate'] and min(r['n_2024'], r['n_2025']) >= cfg['minimum_candidates_per_year'])
        statuses.append(dict(ids, n=r['n'], weeks=r['weeks'], n_2024=r['n_2024'], n_2025=r['n_2025'],
            net_atr=r['net_atr'], sample_sufficient=sufficient,
            display_status='記述のみ・標本不足' if not sufficient else '探索的・採択不可' if reasons else '探索仮説候補',
            inference_use='descriptive_only' if not sufficient else 'exploratory_development_only',
            rejection_reasons=';'.join(reasons), exploratory_hypothesis_pass=r['exploratory_hypothesis_pass']))
    tables = dict(barrier_rates=pd.DataFrame(rows), baseline_metrics=pd.DataFrame(metrics), evidence_status=pd.DataFrame(statuses))
    for name, table in tables.items():
        table.to_csv(out/(name+'.csv'), index=False, encoding='utf-8-sig')
        table.to_parquet(out/(name+'.parquet'), index=False)
    # No changes to original analytical tables or their values.
    with duckdb.connect(str(out/'research.duckdb')) as db:
        for name, table in tables.items():
            db.register('supplement', table)
            db.execute(f'CREATE OR REPLACE TABLE "{name}" AS SELECT * FROM supplement')
            db.unregister('supplement')
    assert all(sha(p) == digest for p, digest in inputs.items())
    build_page(out, primary, tables['evidence_status'])
    generated = [out/(name+ext) for name in tables for ext in ['.csv','.parquet']]+[out/'index.html']
    audit = dict(status='PASS', source_sha256=sha(__file__), input_sha256=inputs,
                 output_sha256={p.name:sha(p) for p in generated},
                 original_analytical_tables_unchanged=True, new_statistical_tests=0,
                 barrier_rate_rows=len(rows), baseline_metric_rows=len(metrics), evidence_rows=len(statuses))
    (out/'qa/reporting_audit.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in audit.items() if not k.endswith('sha256')}, indent=2))


def build_page(out, primary, status):
    by_tf = primary.groupby('timeframe').agg(cells=('n','size'), candidates=('n_candidates','sum'),
            complete_h10=('n','sum'), gross_pips_positive=('mean_gross_pips',lambda s:int((s>0).sum())),
            net_pips_positive=('mean_net_pips',lambda s:int((s>0).sum())),
            net_atr_positive=('net_atr',lambda s:int((s>0).sum())),
            passed=('exploratory_hypothesis_pass','sum')).reindex(['M5','M15','H1'])
    table = by_tf.rename(columns={'cells':'条件数','candidates':'原候補数','complete_h10':'H=10観測数',
            'gross_pips_positive':'グロスpips正','net_pips_positive':'ネットpips正',
            'net_atr_positive':'ネットATR正','passed':'採択数'}).to_html()
    displayed = status[KEYS+['n','weeks','n_2024','n_2025','net_atr','display_status','rejection_reasons']].to_html(index=False, float_format=lambda v:f'{v:.4f}')
    html = '''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Phase 3 研究結果</title><style>
body{font:16px/1.8 system-ui,sans-serif;color:#172e3b;background:#f4f7fa;margin:0}
main{max-width:1150px;margin:auto;padding:28px}h1,h2{line-height:1.4;color:#173f50}
.notice{background:#fff2c9;padding:18px;border-left:5px solid #b17912}.card{background:white;padding:20px;margin:20px 0;border-radius:8px}
.scroll{overflow:auto;max-width:100%}table{border-collapse:collapse;font-size:14px;width:100%}td,th{padding:9px 12px;border:1px solid #dae1e7;text-align:left;white-space:nowrap}
th{background:#e6eff4}a{color:#00679a}li{margin-bottom:6px}input{padding:10px;width:90%;max-width:600px;font:inherit}
</style><main><h1>MT5 複数通貨・時間足の研究結果</h1>
<p>2024–2025年の開発内評価 / 6通貨 × 3時間足 × 6手法 × 2方向</p>
<div class="notice"><strong>216条件を評価。事前固定の採択基準を通過した条件は0件。</strong><br>
ネットATRの点推定が正だった25条件も、未知データで再現する利益を確認した結果ではありません。2026年データは今回使用していません。</div>
<section class="card"><h2>時間足別の結果</h2>TABLE
<p>H=10はエントリー足から10本後の終値。M5では50分、M15では150分、H1では10時間です。<br>
ATR平均は候補ごとにATRで割るため、pips平均と正負が一致しない場合があります。候補の重複を独立取引と数えないでください。</p></section>
<section class="card"><h2>成果物</h2><ul>
<li><a href="review.md">最終判断と品質確認</a> / <a href="report.md">全体レポート</a> / <a href="dashboard.html">Plotlyダッシュボード</a></li>
<li><a href="primary.csv">主評価CSV</a> / <a href="baseline_metrics.csv">2種類のランダム対照との比較CSV</a></li>
<li><a href="barrier_rates.csv">同じ観測母集団によるTP/SL先着率CSV</a> / <a href="evidence_status.csv">全条件の不採択理由CSV</a></li>
<li><a href="../data/audit.md">データ品質監査</a> / <a href="qa/artifact_audit.json">独立検算結果</a></li></ul>
<p>TP/SL先着率はH=10を完全観測できた候補が母数。ランダム対照の10反復を10倍の独立標本とは解釈しません。曖昧な同足到達は別分類です。</p>
<p>USDCHFは17か月のみ。コストはbar spreadと仮定を含み、実費を完全には再現していません。432口座シナリオ中384は観測打切りがあり、そのPF/DDを通年成績と呼べません。実ティック・ポートフォリオ・独立OOSの収益性検証は未実施です。</p></section>
<section class="card"><h2>全216条件と標本数</h2><p>件数200・観測週30・各年75件を満たさない行は「標本不足」。そのCIやp値で採択しません。観測週数は完全な独立性を保証せず、基準を満たす行もすべて探索的な評価です。</p>
<label for="filter">通貨・時間足・手法・方向・不採択理由で絞り込み</label><br><input id="filter" placeholder="例: USDJPY H1 donchian"><p id="count"></p>
<div class="scroll" id="evidence">EVIDENCE</div></section></main>
<script>const input=document.getElementById('filter');const rows=[...document.querySelectorAll('#evidence tbody tr')];
function filter(){const words=input.value.toLowerCase().trim().split(/\\s+/);let n=0;for(const row of rows){const show=words.every(w=>row.textContent.toLowerCase().includes(w));row.hidden=!show;if(show)n++;}document.getElementById('count').textContent=n+' / '+rows.length+' 条件を表示';}
input.addEventListener('input',filter);filter();</script></html>'''
    (out/'index.html').write_text(html.replace('TABLE','<div class="scroll">'+table+'</div>').replace('EVIDENCE',displayed),encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', type=Path, required=True)
    finish(parser.parse_args().run)
