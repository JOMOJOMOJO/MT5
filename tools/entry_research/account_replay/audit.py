"""Audit gaps against saved M1 quotes without filling or changing prices."""
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
from .calendar import annotate_bars, WEEKEND_POLICY
from ..multiasset.data import sha


def audit(data_dir, out):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((Path(data_dir)/'manifest.json').read_text(encoding='utf-8'))
    by_key={(r['symbol'],r['timeframe']):r for r in manifest['datasets'] if r.get('status')=='available'}
    records=[]
    for sym in manifest['specs']:
        mrec=by_key[sym,'M1'];assert sha(mrec['path'])==mrec['sha256']
        minute=pd.read_parquet(mrec['path']).time.to_numpy()
        assert (minute<1767225600).all()
        for tf,step in [('M5',300),('M15',900),('H1',3600)]:
            rec=by_key[sym,tf];assert sha(rec['path'])==rec['sha256']
            b=annotate_bars(pd.read_parquet(rec['path']),step,WEEKEND_POLICY)
            for idx in np.flatnonzero(b.gap_before_seconds.to_numpy()>0):
                left,right=int(b.time.iloc[idx-1]+step),int(b.time.iloc[idx])
                n=int(np.searchsorted(minute,right)-np.searchsorted(minute,left))
                records.append(dict(symbol=sym,timeframe=tf,previous_open=int(b.time.iloc[idx-1]),
                    gap_start=left,gap_end=right,gap_start_text=pd.Timestamp(left,unit='s').isoformat(),
                    gap_end_text=pd.Timestamp(right,unit='s').isoformat(),
                    status=b.gap_before_status.iloc[idx],evidence=b.gap_evidence.iloc[idx],
                    missing_seconds=right-left,m1_rows_in_gap=n,
                    development=right>=1704067200,historically_verified=False))
    frame=pd.DataFrame(records)
    frame.to_csv(out/'gap_audit.csv',index=False)
    frame.to_parquet(out/'gap_audit.parquet',index=False)
    summary=frame[frame.development].groupby(['timeframe','status','evidence']).agg(
        n=('symbol','size'),m1_rows_in_gap=('m1_rows_in_gap','sum')).reset_index()
    summary.to_csv(out/'gap_summary.csv',index=False)
    (out/'calendar_sources.md').write_text('''# 休場・時計・履歴価格の根拠

2026-10-17。価格は旧runと同じBybit-Liveの保存済み2024–2025データ（warmupを含む）。各ParquetのSHAを検証し、ギャップ内のM1実在行数を監査した。M1にも価格がない区間へ足を生成しない。

採用する週末ルールはsource clockの土曜00:00〜月曜00:00の正確な48時間に限定した経験的proxy。ブローカーの過去取引カレンダー・夏時間を独立検証済みとはしない。閉場前後に余分な空白がある場合はunknownのまま。クリスマス/元日の24時間空白は専用の理由を表示するが、歴史的休場表が未確認なので自動承認しない。

公式の[MT5 API仕様](https://www.mql5.com/en/docs/python_metatrader5/mt5copyratesrange_py)はUTC日時を要求する。これは返却された履歴とサーバー時計の歴史的一致を保証する独立証拠ではない。[Bybitの現行FAQ](https://www.bybit.com/en/help-center/article/FAQ-CFD)と[仕様ページ](https://www.bybit.com/en/help-center/article/Contracts-Available-on-MT5-and-Specifications)も調査したが、今回必要な2024–2025年の休場表と実swap履歴は確認できなかった。現行仕様をそのまま歴史へ適用しない。

`gap_audit.csv` の空白は観測上の事実であり、価格配信なし・無tick・サーバー欠損などの原因まで断定していない。`m1_rows_in_gap=0` だけで正常休場とは判定しない。
''',encoding='utf-8')
    return summary


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--data',required=True);p.add_argument('--out',required=True)
    a=p.parse_args();print(audit(a.data,a.out).to_string(index=False))
