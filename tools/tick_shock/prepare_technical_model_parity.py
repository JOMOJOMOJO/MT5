"""Serialize formal features and independent JSON model expectations for MQL."""
import argparse,csv,json,os
from pathlib import Path
from technical_discovery_independent_recalculation import read_csv,number,score

p=argparse.ArgumentParser();p.add_argument('--features',type=Path,required=True);p.add_argument('--model',type=Path,required=True);a=p.parse_args()
s=json.loads(a.model.read_text());rows=read_csv(a.features)
dest=Path(os.environ['APPDATA'])/'MetaQuotes/Terminal/Common/Files/technical_model_parity'
dest.mkdir(parents=True,exist_ok=True)
with (dest/'vectors.csv').open('w',encoding='utf-8',newline='') as f:
    w=csv.writer(f);w.writerow(['episode_id','expected_long','expected_short','expected_direction']+s['features'])
    for r in rows:
        raw=[number(r.get(n)) for n in s['features']];ls=score(s['models']['long'],raw);ss=score(s['models']['short'],raw)
        d=0 if max(ls,ss)<s['threshold'] or ls==ss else 1 if ls>ss else -1
        w.writerow([r['episode_id'],format(ls,'.17g'),format(ss,'.17g'),d]+[r.get(n,'') for n in s['features']])
print(f'Independent vectors {len(rows)}: {dest}')
