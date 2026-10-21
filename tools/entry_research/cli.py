"""Reproducible research commands, with an enforced development-period lock."""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import subprocess
from pathlib import Path

import duckdb
import pandas as pd

from .data import import_archives, fetch_mt5, _bounds
from .features import build_features
from .signals import extract
from .evaluation import evaluate
from .baseline import matched_baseline
from .statistics import summarize, METRICS
from .charts import write_chart

REPO = Path(__file__).resolve().parents[2]
PACKAGE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False, default=str), encoding='utf-8')


def status(out, stage):
    print(stage, flush=True)
    save_json(out / 'status.json', {'stage': stage})


def validate_config(config):
    _, end = _bounds(config['start'], config['end'])
    if end != config['end_exclusive']:
        raise ValueError('end and end_exclusive disagree')
    if config['entry_timeframe'] not in config['timeframes']:
        raise ValueError('entry_timeframe missing')
    if config['timeframe_seconds'] != config['timeframes'][config['entry_timeframe']]:
        raise ValueError('entry timeframe duration mismatch')
    if config.get('primary_horizon') != 10:
        raise ValueError('Current prespecified inference contract requires H10; revise statistics explicitly')
    if not 0 <= config['max_entry_delay_seconds'] <= config['timeframe_seconds']:
        raise ValueError('entry delay exceeds one bar')


def load_dataset(directory, config):
    meta = json.loads((directory / 'dataset_manifest.json').read_text(encoding='utf-8'))
    for key in ['symbol', 'point', 'pip_size']:
        if meta.get(key) != config[key]:
            raise ValueError(f'Dataset/config mismatch: {key}')
    if meta['clock_basis'] != config['clock_basis']:
        raise ValueError('Clock basis must match manifest; never silently infer UTC')
    for name, digest in meta['outputs_sha256'].items():
        if sha(directory / name) != digest:
            raise ValueError(f'Dataset hash mismatch: {name}')
    data = {tf: pd.read_parquet(directory / f'{tf}.parquet') for tf in config['timeframes']}
    for tf, frame in data.items():
        if (frame.time >= config['end_exclusive']).any():
            raise ValueError(f'{tf}: forbidden future/holdout data')
        if frame.time.duplicated().any() or not frame.time.is_monotonic_increasing:
            raise ValueError(f'{tf}: invalid time ordering')
        if not frame.available_time.is_monotonic_increasing or (frame.available_time < frame.close_time).any():
            raise ValueError(f'{tf}: invalid availability ordering')
    return data


def evaluate_to_disk(bars, events, config, directory, detail=True):
    directory.mkdir(parents=True, exist_ok=False)
    small = []
    for start in range(0, len(events), 1500):
        frame = events.iloc[start:start+1500]
        # Run first baseline replicate separately, so only it generates large path tables.
        outcomes, touches, barriers = evaluate(bars, frame, {**config, 'emit_paths': detail})
        part = f'{start//1500:04d}'
        outcomes.to_parquet(directory / f'outcomes_{part}.parquet', index=False, compression='zstd')
        if detail:
            touches.to_parquet(directory / f'touches_{part}.parquet', index=False, compression='zstd')
            barriers.to_parquet(directory / f'barriers_{part}.parquet', index=False, compression='zstd')
        small.append(outcomes[['candidate_id','horizon','complete',*METRICS]])
    if not small:
        empty = pd.DataFrame(columns=['candidate_id','horizon','complete',*METRICS])
        empty.to_parquet(directory / 'outcomes_0000.parquet', index=False)
        return empty
    return pd.concat(small, ignore_index=True)


def sql_path(path):
    return str(path).replace('\\','/').replace("'", "''")


def aggregate(out, summary):
    db = duckdb.connect(str(out / 'research.duckdb'))
    try:
        for name, path in [('candidates', out/'candidates.parquet'), ('controls',out/'controls.parquet'),
                           ('outcomes',out/'events/outcomes_*.parquet'),
                           ('barriers',out/'events/barriers_*.parquet'), ('touches',out/'events/touches_*.parquet'),
                           ('baseline_outcomes',out/'baseline/rep*/outcomes_*.parquet'),
                           ('baseline_barriers',out/'baseline/rep0/barriers_*.parquet'),
                           ('baseline_touches',out/'baseline/rep0/touches_*.parquet')]:
            db.execute(f"CREATE VIEW {name} AS SELECT * FROM read_parquet('{sql_path(path)}')")
        db.register('summary_frame', summary)
        db.execute('CREATE TABLE summary AS SELECT * FROM summary_frame')
        groups = []
        for source, event_table, path_table in [('strategy','candidates','barriers'), ('baseline_rep0','controls','baseline_barriers')]:
            q = f"""SELECT '{source}' AS source,b.method,b.side,b.horizon,b.tp_atr,b.sl_atr,
                count(*) AS n, count_if(b.outcome='tp_first') AS tp_first_n,
                count_if(b.outcome='sl_first') AS sl_first_n,count_if(b.outcome='ambiguous') AS ambiguous_n,
                count_if(b.outcome='neither') AS neither_n,count_if(b.outcome='censored') AS censored_n,
                avg(CASE WHEN NOT b.censored THEN (b.outcome='tp_first')::INT END) AS tp_first_rate,
                avg(CASE WHEN NOT b.censored THEN (b.outcome='sl_first')::INT END) AS sl_first_rate,
                avg(CASE WHEN NOT b.censored THEN (b.outcome='ambiguous')::INT END) AS ambiguous_rate,
                avg(CASE WHEN NOT b.censored THEN (b.outcome IN ('tp_first','ambiguous'))::INT END) AS tp_first_upper_bound
                FROM {path_table} b JOIN {event_table} c USING(candidate_id) WHERE c.eligible
                GROUP BY b.method,b.side,b.horizon,b.tp_atr,b.sl_atr ORDER BY 2,3,4,5,6"""
            groups.append(db.execute(q).df())
        first = pd.concat(groups, ignore_index=True)
        base = first.loc[first.source=='baseline_rep0', ['method','side','horizon','tp_atr','sl_atr','tp_first_rate','sl_first_rate','ambiguous_rate']]
        comparisons = first.loc[first.source=='strategy'].merge(base, on=['method','side','horizon','tp_atr','sl_atr'], suffixes=('','_baseline'))
        for col in ['tp_first_rate','sl_first_rate','ambiguous_rate']:
            comparisons['delta_'+col] = comparisons[col] - comparisons[col+'_baseline']
        tables = {'barrier_rates': first, 'barrier_comparison':comparisons}
        touches = []
        for label, table, event in [('strategy','touches','candidates'),('baseline_rep0','baseline_touches','controls')]:
            touches.append(db.execute(f"""SELECT '{label}' AS source,b.method,b.side,b.horizon,b.move,b.level,
                count(*) AS n,count_if(b.censored) AS censored_n,avg(b.reached::INT) AS reach_rate,
                avg(b.first_hit_bar) AS mean_hit_bar_when_reached,median(b.first_hit_bar) AS median_hit_bar_when_reached
                FROM {table} b JOIN {event} c USING(candidate_id) WHERE c.eligible
                GROUP BY b.method,b.side,b.horizon,b.move,b.level ORDER BY 2,3,4,5,6""").df())
        tables['touch_rates'] = pd.concat(touches, ignore_index=True)
        envs, replicate_counts = [], []
        for field in ['year','hour','weekday','vol_bucket','h1_trend','m15_trend','h1_stale','m15_stale','cloud_position','session']:
            replicate_counts.append(db.execute(f"""SELECT '{field}' AS dimension,CAST({field} AS VARCHAR) AS value,
                method,side,min(n) AS min_observed_replicate_n,max(n) AS max_replicate_n,count(*) AS represented_replicates
                FROM (SELECT {field},method,side,replicate,count(*) AS n FROM controls WHERE eligible
                      GROUP BY {field},method,side,replicate)
                GROUP BY {field},method,side""").df())
            for label, table, event in [('strategy','outcomes','candidates'), ('baseline_all_replicates','baseline_outcomes','controls')]:
                envs.append(db.execute(f"""SELECT '{label}' AS source,'{field}' AS dimension,
                    CAST(c.{field} AS VARCHAR) AS value,o.method,o.side,o.horizon,
                    count(*) AS n_rows,count(DISTINCT c.week) AS n_weeks,
                    avg(o.gross_pips) AS mean_gross_pips,avg(o.net_pips) AS mean_net_pips,
                    median(o.net_pips) AS median_net_pips,avg(o.mfe_atr) AS mean_mfe_atr,avg(o.mae_atr) AS mean_mae_atr
                    FROM {table} o JOIN {event} c USING(candidate_id) WHERE c.eligible AND o.complete
                    GROUP BY c.{field},o.method,o.side,o.horizon ORDER BY 3,4,5,6""").df())
        env = pd.concat(envs, ignore_index=True)
        repeats = db.execute('SELECT count(DISTINCT replicate) FROM controls').fetchone()[0]
        env = env.merge(pd.concat(replicate_counts,ignore_index=True),on=['dimension','value','method','side'],how='left')
        env['min_replicate_n'] = env.min_observed_replicate_n.where(env.represented_replicates==repeats,0)
        env['baseline_repeats'] = repeats
        env['n_events_per_replicate'] = env.n_rows / env.source.map({'strategy':1,'baseline_all_replicates':repeats})
        env['thin_sample'] = (env.n_events_per_replicate < 100) | (env.n_weeks < 20)
        env['estimator'] = env.source.map({'strategy':'event_mean', 'baseline_all_replicates':'pooled_conditional_descriptive_mean'})
        tables['environment_summary'] = env
        tables['censor_counts'] = db.execute("""SELECT method,side,horizon,complete,censor_reason,count(*) AS n
            FROM outcomes GROUP BY ALL ORDER BY method,side,horizon,complete,censor_reason""").df()
        for name, table in tables.items():
            table.to_csv(out / f'{name}.csv', index=False)
            db.register('tmp_frame', table)
            db.execute(f'CREATE TABLE {name} AS SELECT * FROM tmp_frame')
            db.unregister('tmp_frame')
        return tables
    finally:
        db.close()


def table_md(frame):
    def fmt(x):
        if isinstance(x, float):
            return f'{x:.4f}' if pd.notna(x) else 'NA'
        return str(x).replace('|','/')
    return '\n'.join(['| '+' | '.join(frame.columns)+' |', '| '+' | '.join(['---']*len(frame.columns))+' |']+
                      ['| '+' | '.join(map(fmt,row))+' |' for row in frame.itertuples(index=False,name=None)])


def write_report(out, config, data_dir, raw, summary, tables):
    primary = summary[summary.horizon==10]
    counts = raw.groupby(['method','side']).agg(all_candidates=('candidate_id','size'),
        common_50bar=('eligible','sum'),consecutive=('same_side_consecutive','sum'),overlap_50=('overlap_50','sum')).reset_index()
    counts.to_csv(out/'candidate_counts.csv', index=False)
    cols = ['method','side','n_complete','n_strategy_weeks','thin_sample','mean_gross_pips','mean_net_pips','mean_net_pips_ci_low',
            'mean_net_pips_ci_high','delta_net_pips','delta_net_pips_ci_low','delta_net_pips_ci_high','p_delta_net_pips_holm']
    coverage = pd.read_csv(data_dir/'coverage.csv')
    text = f"""# USDJPY M5 エントリー候補研究・初回分析

研究用イベント統計。MT5の売買バックテスト、収益性の確定、demo/live昇格ではない。
固定3手法、2024〜2025年、2026年価格は未読。過去研究で2026年の一部は既知なので完全未閲覧OOSとは呼ばない。

## 入力と再現性

- データ: `{data_dir.relative_to(REPO) if data_dir.is_relative_to(REPO) else data_dir}`。Bybit-Live由来の保存バー。原本SHA256・重複差分・取得可能期間はdataset_manifest.json。
- シード {config['seed']}、基準比較 {config['baseline_repeats']} 回、週block bootstrap {config['bootstrap_reps']} 回。設定はconfig.json、実装hash・依存version・git HEADはmanifest.json。
- 雲9/26/52、表示シフト26、基準線は前足確定値への反発、EMA20/50。最適化なし。
- コストは仮定: spread {config['cost']['spread_pips']}pips + 往復commission {config['cost']['commission_pips_roundtrip']}pips + 片道slippage {config['cost']['slippage_pips_per_side']}pips。保存spreadは実約定コストではない。
- source clockとUTCの対応未検証のため東京/ロンドン/NYはunknown。hour/weekdayはサーバー時計。
- 2024年6月6日以前に実tickの裏付けなし。2025年にもtick品質警告あり。OHLCから精密な約定や到達順序を推測しない。

## データ範囲

{table_md(coverage[['timeframe','year','rows','first_time','last_time','missing_weekday_slots_unclassified']])}

timeはsource clock秒。欠落候補の詳細はgaps.csv。weekday空白には休日・閉場も含み、すべてをデータ障害と断定しない。価格補完なし。

## 候補母集団

{table_md(counts)}

主比較は全50本が連続する共通母集団。全候補と各Hの欠損はcandidates.parquet、censor_counts.csvへ保存。週末・欠損・期間末直前の候補が主比較から除かれる。
シグナル観測時刻と名目確定を区別し、観測後の次の足始値を約定近似に使用。遅れがある場合は最大1本待つ。実tickによる約定確認ではない。

## 主要評価 H10（pips）

{table_md(primary[cols])}

CIはsource clockの同じカレンダー週を共通再標本化した95%区間。週内依存を保持するが、隣接週の依存や長期レジーム変化を完全には解消しない。
ベースラインはsymbol/year/hour/weekday/相対ATR区分/方向/件数を一致させ各層で復元なし。候補バーも抽選対象。10反復はサンプル数を増やさない。baseline_match_audit.csvに一致を記録。
検定はH10の3手法×2方向でHolm補正。他H・水準・環境別集計は記述的探索で、そこから勝者を選ぶと追加検証が必要。n<100又は週<20はthin_sample。
平均ネット>0だけでedge認定せず、差のCI・年別安定性・コスト・MT5検証を別に確認する。

## 出力

- summary.csv: 全Hのグロス/ネット平均・中央値、MFE/MAE、ATR換算、対照との差、CI、非重複候補の感度。
- barrier_rates.csv / barrier_comparison.csv: 全25 TP/SL組合せ、tp_first / sl_first / ambiguous / neither、対照との差。比率の分母にはneither/ambiguousを残す。
- touch_rates.csv: 各水準の到達率と到達バー数。正確なtick時刻ではなく、元Parquetに到達時間の区間を保存。
- environment_summary.csv: 年・時間帯・曜日・vol・H1/M15方向・雲位置別の件数つき集計。baselineの行数は10反復合計、n_events_per_replicateは平均件数。環境別baselineは全反復のプール条件付き記述平均で、主検定の反復平均と異なる。細分化条件は採用根拠にしない。
- events/、baseline/: 全イベントの評価Parquet。到達詳細のベースラインは事前固定第1反復のみ。到達率・MFE/MAEはグロス価格経路、netは固定時点リターンのコスト控除値。
- charts/: 各手法・方向の最初の候補の4時間足HTML。確定・観測済み足だけをHTMLに埋め込み、未来を非表示データとしても含めない。任意候補はchartコマンドで生成可能。
- research.duckdb: 永続集計テーブルとParquetビュー。移動後は元ディレクトリの絶対参照ビューの再作成が必要。

## 次の判断

この段階では3手法をEA化・昇格しない。7手法追加は同じ抽出API・未来不変性テストを通すPhase 5とする。
実tickによる同足順序確認、履歴コスト・時差対応確認、別期間/別brokerでの固定再検証は未実施。利益の出る出口・ポジション制約・資金配分を後付けした結果と今回の入口比較を混同しない。
"""
    (out/'report.md').write_text(text, encoding='utf-8')


def run(config_path, out, data_dir=None):
    config = json.loads(config_path.read_text(encoding='utf-8'))
    validate_config(config)
    out.mkdir(parents=True, exist_ok=False)
    save_json(out/'config.json',config)
    manifest = {'schema_version':1, 'git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
        'git_branch':subprocess.check_output(['git','branch','--show-current'],cwd=REPO,text=True).strip(),
        'uncommitted_code_identified_by_sha256':True, 'python':platform.python_version(),
        'dependencies':{p:importlib.metadata.version(p) for p in ['pandas','numpy','scipy','pyarrow','duckdb','plotly','MetaTrader5','pytest']},
        'code_sha256':{str(p.relative_to(REPO)):sha(p) for p in PACKAGE.rglob('*') if p.is_file() and '.venv' not in p.parts and '__pycache__' not in p.parts and p.suffix in ['.py','.json','.txt']},
        'seed':config['seed'], 'holdout_2026_read':False, 'analysis_type':'research_event_study_not_MT5_strategy_test'}
    try:
        status(out,'loading_data')
        if data_dir is None:
            data_dir = out/'data'
            bars = import_archives(REPO,data_dir,config)
        else:
            bars = load_dataset(data_dir,config)
        manifest['data_dir'] = str(data_dir.resolve())
        manifest['dataset_manifest_sha256'] = sha(data_dir/'dataset_manifest.json')
        save_json(out/'manifest.json',manifest)
        status(out,'extracting_candidates')
        features,enriched = build_features(bars,config)
        features.to_parquet(out/'features.parquet',index=False,compression='zstd')
        raw = extract(features,config['methods'])
        raw.to_parquet(out/'candidates.parquet',index=False,compression='zstd')
        raw[['candidate_id','method','side','signal_time','nominal_close_time','entry_time','entry_delay_seconds','atr14','eligible']].to_csv(out/'candidate_index.csv',index=False)
        matched = raw.loc[raw.eligible].copy()
        if matched.empty:
            raise ValueError('No eligible candidates; inspect dataset before running statistics')
        status(out,f'evaluating_{len(raw)}_candidates')
        outcomes = evaluate_to_disk(bars[config['entry_timeframe']],raw,config,out/'events')
        status(out,'sampling_matched_controls')
        controls,audit = matched_baseline(features,matched,config['seed'],config['baseline_repeats'])
        controls.to_parquet(out/'controls.parquet',index=False,compression='zstd')
        audit.to_csv(out/'baseline_match_audit.csv',index=False)
        controls_out = []
        for rep,frame in controls.groupby('replicate',sort=True):
            status(out,f'evaluating_baseline_{rep+1}_of_{config["baseline_repeats"]}')
            controls_out.append(evaluate_to_disk(bars[config['entry_timeframe']],frame,config,out/f'baseline/rep{rep}',detail=rep==0))
        status(out,'bootstrap_statistics')
        matched_out = outcomes[outcomes.candidate_id.isin(matched.candidate_id)]
        summary = summarize(matched_out,matched,pd.concat(controls_out,ignore_index=True),controls,config['seed']+1,config['bootstrap_reps'])
        summary.to_csv(out/'summary.csv',index=False)
        summary.to_parquet(out/'summary.parquet',index=False)
        status(out,'duckdb_aggregations')
        tables = aggregate(out,summary)
        status(out,'decision_only_charts_and_report')
        for (method,side), group in matched.groupby(['method','side'],sort=True):
            write_chart(enriched,group.sort_values('signal_time').iloc[0],out/f'charts/{method}_{side}.html')
        write_report(out,config,data_dir,raw,summary,tables)
        manifest['result_sha256'] = {p.name:sha(p) for p in out.glob('*.csv')}
        save_json(out/'manifest.json',manifest)
        status(out,'complete')
    except Exception as exc:
        save_json(out/'status.json',{'stage':'failed','error':str(exc)})
        raise


def main():
    parser=argparse.ArgumentParser(description='Entry candidate research (2026 locked)')
    sub=parser.add_subparsers(dest='command',required=True)
    r=sub.add_parser('run')
    r.add_argument('--config',type=Path,default=PACKAGE/'configs/initial.json')
    r.add_argument('--out',type=Path,required=True)
    r.add_argument('--data-dir',type=Path)
    f=sub.add_parser('fetch')
    for arg in ['terminal','symbol','start','end']:
        f.add_argument('--'+arg,required=True)
    f.add_argument('--out',type=Path,required=True)
    c=sub.add_parser('chart')
    c.add_argument('--run',type=Path,required=True)
    c.add_argument('--candidate-id',required=True)
    c.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    if args.command=='run':
        run(args.config.resolve(),args.out.resolve(),args.data_dir.resolve() if args.data_dir else None)
    elif args.command=='fetch':
        fetch_mt5(args.terminal,args.symbol,args.start,args.end,args.out.resolve())
    else:
        config=json.loads((args.run/'config.json').read_text(encoding='utf-8'))
        validate_config(config)
        meta=json.loads((args.run/'manifest.json').read_text(encoding='utf-8'))
        data=load_dataset(Path(meta['data_dir']),config)
        _,enriched=build_features(data,config)
        candidates=pd.read_parquet(args.run/'candidates.parquet')
        selected=candidates.loc[candidates.candidate_id==args.candidate_id]
        if len(selected)!=1:
            raise ValueError('candidate-id must identify one stored candidate')
        if args.out.exists():
            raise FileExistsError(args.out)
        write_chart(enriched,selected.iloc[0],args.out)
