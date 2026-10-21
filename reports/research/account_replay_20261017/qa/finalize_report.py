"""Add explicit end-of-sample censor classification to the frozen replay report."""
import argparse,hashlib,json
from pathlib import Path
import pandas as pd
from tools.entry_research.account_replay.report import render,markdown


def finish(out):
    out=Path(out);render(out)
    accounts=pd.read_parquet(out/'accounts.parquet');stops=pd.read_csv(out/'qa/remaining_stops.csv')
    def category(r):
        if r['status']=='censored_data_end':return '評価期間末の未決済'
        if r['evidence']=='holiday_date_but_historical_session_unverified':return '歴史的休場表未確認の祝日'
        return '平日等の不明な空白'
    stops['category']=stops.apply(category,axis=1)
    summary=stops.groupby(['timeframe','category']).size().reset_index(name='scenarios')
    assert summary.scenarios.sum()==len(stops)==len(accounts)-int(accounts.account_path_complete.sum())
    summary.to_csv(out/'stop_categories.csv',index=False,encoding='utf-8-sig')
    states=[]
    for r in accounts.to_dict('records'):
        cell=out/r['symbol']/r['timeframe']/(r['method']+'_'+r['side'])
        equity=pd.read_parquet(cell/'execution_equity.parquet');equity=equity[equity.scenario.eq(r['scenario'])]
        last=equity.iloc[-1]
        stop=stops
        for k in ['symbol','timeframe','method','side','scenario']:stop=stop[stop[k].eq(r[k])]
        status='closed_path' if stop.empty else str(stop.iloc[0]['status'])
        states.append({k:r[k] for k in ['symbol','timeframe','method','side','scenario']} | dict(
            end_state=status,account_path_complete=r['account_path_complete'],requested_period_available=r['requested_period_available'],
            last_observed_mark_time=int(last.time),last_observed_mark_text=pd.Timestamp(last.time,unit='s').isoformat(),
            realized_balance_before_unknown_swap_usd=r['ending_realized_balance_usd'],
            last_observed_liquidation_equity_before_unknown_swap_usd=float(last.equity_close_usd),
            last_mark_is_only_prefix=status=='censored_time_gap',
            marked_unrealized_before_unknown_swap_usd=float(last.equity_close_usd)-r['ending_realized_balance_usd'],
            no_forced_end_of_period_exit=True,all_costs_verified=False))
    end_state=pd.DataFrame(states);end_state.to_csv(out/'end_state.csv',index=False);end_state.to_parquet(out/'end_state.parquet',index=False)
    note='''## 停止理由を区別した最終確認

'''+markdown(summary)+'''

期間末の未決済は、価格不足で途中の取引経路が不明になったケースとは異なる。10本保有の出口が2026年側へ延びるため、2026を読まず右側打切りとした。期末に強制決済したことにはしない。最後に観測した清算評価額と未実現損益は [end_state.csv](end_state.csv) に別記録した。未知swap控除前の評価額であり、実現利益ではない。

不明な空白で停止した口座の最終評価額は、その空白より前の時点の値で、2025年末残高ではない。USDCHFの17か月制約も別に残る。停止理由一覧は [stop_categories.csv](stop_categories.csv)。

保存M1で埋められなかった短い平日の空白は、同じブローカーにも120要求で再照会したが回収0行だった。98応答には前後のバー、22応答は空。無tick・配信停止・欠損の原因は断定せず、補間していない。[再取得監査](../qa/broker_probe.md)

先行する `weekend_repaired/` は文字列列への逐次代入が遅く、性能修正のため中断した。167,889行の全注釈がdtypeを含め完全一致したことを確認して一括代入にし、`validated/` で全件再実行した。[同値確認](../qa/calendar_optimization.json)

今回の旧26件＋新27件の計53テストは全件合格。既存戦略・原候補・価格・統計推論を変えた最適化は行っていない。
'''
    path=out/'report.md';text=path.read_text(encoding='utf-8')
    text=text.replace('## 新旧比較',note+'\n## 新旧比較',1)
    text=text.replace('平日の空白と祝日、実swapなどの制約が残る','平日の空白と祝日、期間末未決済、実swapなどの制約が残る')
    path.write_text(text,encoding='utf-8')
    html=out/'dashboard.html';text=html.read_text(encoding='utf-8')
    end_count=int(stops.status.eq('censored_data_end').sum())
    text=text.replace(f'残り {len(stops)} は原因未確定の空白等で停止。',
                      f'残りは未確認の空白 {len(stops)-end_count} 件と期間末未決済 {end_count} 件。')
    banner='<h2>残った停止の内訳</h2>'+summary.to_html(index=False)+'<p>期間末未決済は2026年を参照せず右側打切り。強制決済はしていません。<a href="end_state.csv">最後の実現残高・未実現評価額</a>は未知swap控除前です。</p>'
    text=text.replace('<h2>全432シナリオ',banner+'<h2>全432シナリオ',1)
    html.write_text(text,encoding='utf-8')
    files=[path,html,out/'stop_categories.csv',out/'end_state.csv',out/'end_state.parquet']
    audit=dict(status='PASS',new_statistical_tests=0,core_replay_results_changed=False,
        source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        outputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
    (out/'qa/reporting_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    print(summary.to_string(index=False))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('out');finish(p.parse_args().out)
