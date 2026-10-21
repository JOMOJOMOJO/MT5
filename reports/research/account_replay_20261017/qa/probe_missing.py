"""Read-only retry of observed short gaps; never requests locked 2026 prices."""
from datetime import datetime,timezone
from pathlib import Path
import json
import pandas as pd
import MetaTrader5 as mt5

out=Path(__file__).parent/'broker_probe';out.mkdir(exist_ok=True)
g=pd.read_csv(Path(__file__).parent/'gap_audit.csv')
g=g[g.development & g.status.eq('unknown_gap') & (g.missing_seconds<3600)].drop_duplicates(['symbol','gap_start','gap_end'])
terminal=Path('C:/Users/windows/AppData/Local/CodexMT5Multiasset20261016/terminal64.exe')
logs=[]
if not mt5.initialize(str(terminal),portable=True,timeout=30000):
    (out/'status.json').write_text(json.dumps(dict(status='unavailable',error=str(mt5.last_error()))),encoding='utf-8')
    raise SystemExit('research terminal unavailable')
try:
    account=mt5.account_info()
    if account is None or account.server!='Bybit-Live':raise RuntimeError('Expected research source unavailable')
    for row in g.itertuples():
        left,right=int(row.gap_start),int(row.gap_end)
        assert 1704067200<=left<right<1767225600
        for label,tf,step in [('M1',mt5.TIMEFRAME_M1,60),('M5',mt5.TIMEFRAME_M5,300)]:
            rates=mt5.copy_rates_range(row.symbol,tf,datetime.fromtimestamp(left-step,timezone.utc),datetime.fromtimestamp(right+step,timezone.utc))
            if rates is None:
                logs.append(dict(symbol=row.symbol,timeframe=label,start=left,end=right,status='request_failed',recovered_rows=0,error=str(mt5.last_error())))
                continue
            d=pd.DataFrame(rates)
            if len(d) and ((d.time<left-step)|(d.time>right+step)).any():
                logs.append(dict(symbol=row.symbol,timeframe=label,start=left,end=right,status='out_of_requested_range_rejected',recovered_rows=0,error=''))
                continue
            found=d[(d.time>=left)&(d.time<right)] if len(d) else d
            d.to_parquet(out/f'{row.symbol}_{label}_{left}_{right}.parquet',index=False)
            logs.append(dict(symbol=row.symbol,timeframe=label,start=left,end=right,status='response_saved',recovered_rows=len(found),error=''))
    result=pd.DataFrame(logs);result.to_csv(out/'requests.csv',index=False)
    summary=dict(status='completed',request_count=len(result),requests_with_recovered_prices=int(result.recovered_rows.gt(0).sum()),
                 recovered_rows=int(result.recovered_rows.sum()),failed_requests=int(result.status.ne('response_saved').sum()),
                 server=account.server,holdout_2026_requested=False,original_data_modified=False)
    (out/'status.json').write_text(json.dumps(summary,indent=2),encoding='utf-8');print(json.dumps(summary,indent=2))
finally:mt5.shutdown()
