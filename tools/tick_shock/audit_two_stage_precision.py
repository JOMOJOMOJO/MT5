"""Bounded serialization audit, not a blanket relaxed numerical tolerance."""
import json
from pathlib import Path
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'reports/backtest/batches/two_stage_development_20260913/202501'

def precision_bounds(frame):
    entry=np.where(frame.direction.eq(1),frame.entry_ask,frame.entry_bid)
    atr=frame.atr14_m5.to_numpy(float);gross=frame.gross_r.to_numpy(float)
    computed=frame.direction.to_numpy()*(frame.exit_price.to_numpy()-entry)/atr
    # Each DoubleToString(...,12) value has absolute rounding <= 0.5e-12.
    # |N'/A' - N/A| <= (|delta N| + |N/A| |delta A|) / |A'|.
    # Add the rounded R's half LSB and double arithmetic error for quote subtraction.
    arithmetic=8*np.finfo(float).eps*(np.abs(entry)+np.abs(frame.exit_price.to_numpy()))/atr
    bound=(1e-12+np.abs(gross)*.5e-12)/atr+.5e-12+arithmetic
    return computed,np.abs(computed-gross),bound

def main():
    f=pd.read_csv(RUN/'fixed_time_outcomes.csv');f=f[f.status.eq('TIME')].copy()
    computed,error,bound=precision_bounds(f)
    f['independent_r']=computed;f['absolute_error']=error;f['serialization_bound']=bound
    f['within_bound']=error<=bound
    f[f.absolute_error.gt(1e-9)].to_csv(RUN/'r_precision_differences.csv',index=False)
    report=dict(rows=len(f),old_absolute_tolerance=1e-9,old_failures=int((error>1e-9).sum()),
        max_error=float(error.max()),outside_serialization_bound=int((error>bound).sum()),
        max_bound_ratio=float((error/bound).max()),source='TSTDNumber: DoubleToString(v,12)')
    (RUN/'r_precision_audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
