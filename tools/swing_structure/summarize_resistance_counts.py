"""All prespecified 0/1/2+ resistance-count cells, including unfavorable results."""
from pathlib import Path
import numpy as np
import pandas as pd
O=Path(__file__).resolve().parents[2]/'reports/qa/three_wave/resistance_research'
s=pd.read_csv(O/'resistance_statistics.csv');s=s[s.comparison=='COUNT']
keys=['stage','stop_basis','feature','label','mode'];wide=None
periods=['discovery','replication','extension']
for period in periods:
    z=s[s.period==period].drop(columns=['period','comparison','threshold_R']).set_index(keys).add_suffix('_'+period)
    wide=z if wide is None else wide.join(z,how='outer')
wide['positive_all']=np.logical_and.reduce([wide['expectancy_R_'+p]>0 for p in periods])
wide['twenty_every_month']=np.logical_and.reduce([wide['min_month_'+p]>=20 for p in periods])
wide.to_csv(O/'count_stability.csv')
print('Fixed count bins positive and >=20 every month:',int((wide.positive_all & wide.twenty_every_month).sum()))
