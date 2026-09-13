"""Deterministic model-to-MQL export. Does not read holdout data."""
import csv
import json
import os
from pathlib import Path
import numpy as np
import usdjpy_only_ml as u


def main():
    u.check_freeze();spec=json.loads((u.OUT/'frozen_model.json').read_text())
    dest=u.ROOT/'mql/Include/TickShockUSDJPYOnlyModel.mqh'
    if dest.exists(): raise FileExistsError(dest)
    lines=['// Generated frozen USDJPY-only NET_R model. Tester-only wrapper.',
        '#ifndef TECHNICAL_DISCOVERY_MODEL_MQH','#define TECHNICAL_DISCOVERY_MODEL_MQH',
        '#define TD_MODEL_FEATURE_COUNT 486',f'#define TD_MODEL_USED_FEATURES {len(spec["features"])}',
        f'#define TD_MODEL_DISTANCE_INDEX {spec["distance_index"]}',f'#define TD_MODEL_DISTANCE_ATR {spec["distance_atr"]:.17g}',
        f'#define TD_MODEL_THRESHOLD {spec["threshold"]:.17g}']
    def array(name,values,kind='double'):
        vs=[str(int(v)) if kind=='int' else format(float(v),'.17g') for v in values]
        lines.append(f'const {kind} {name}[{len(vs)}]={{'+','.join(vs)+'};')
    array('TDUsedIndex',spec['full_feature_indices'],'int')
    for side,name in (('1','Long'),('-1','Short')):
        model=spec['models'][side];array('TD'+name+'Median',model['median'])
        if model['kind']=='LINEAR':
            for n in ('mean','scale','coefficient'): array('TD'+name+n.title(),model[n])
            lines += [f'double TDScore{name}(const double &raw[])', '{',f' double z={model["intercept"]:.17g};',
                ' for(int i=0;i<TD_MODEL_USED_FEATURES;++i){int j=TDUsedIndex[i];',
                f' double v=(MathIsValidNumber(raw[j])&&raw[j]!=EMPTY_VALUE)?raw[j]:TD{name}Median[i];',
                f' z+=(v-TD{name}Mean[i])/TD{name}Scale[i]*TD{name}Coefficient[i];',' }',' return z;','}']
        else:
            def expr(t,node=0):
                if model['kind']=='FOREST':
                    if t['left'][node]<0:return format(t['value'][node],'.17g')
                    return f'(v[{t["feature"][node]}]<={t["threshold"][node]:.17g}?{expr(t,t["left"][node])}:{expr(t,t["right"][node])})'
                if 'leaf_value' in t:return format(t['leaf_value'],'.17g')
                assert t['decision_type']=='<='
                return f'(v[{t["split_feature"]}]<={t["threshold"]:.17g}?{expr(t["left_child"])}:{expr(t["right_child"])})'
            lines += [f'double TDScore{name}(const double &raw[])','{',' double v[TD_MODEL_USED_FEATURES];',
                f' for(int i=0;i<TD_MODEL_USED_FEATURES;++i){{int j=TDUsedIndex[i];v[i]=(MathIsValidNumber(raw[j])&&raw[j]!=EMPTY_VALUE)?raw[j]:TD{name}Median[i];'+
                ('v[i]=(double)(float)v[i];' if model['kind']=='FOREST' else '')+'}', ' double z=0;']
            lines += [' z+='+expr(t)+';' for t in model['trees']]
            lines += [f' return z/{len(model["trees"])}.0;' if model['kind']=='FOREST' else ' return z;','}']
    lines += ['int TDModelDecision(const double &raw[],double &ls,double &ss)','{',
        ' if(ArraySize(raw)!=TD_MODEL_FEATURE_COUNT)return 0;',
        ' ls=TDScoreLong(raw);ss=TDScoreShort(raw);',
        ' if(!MathIsValidNumber(ls)||!MathIsValidNumber(ss)||ls==ss||MathMax(ls,ss)<TD_MODEL_THRESHOLD)return 0;',
        ' return ls>ss?1:-1;','}','#endif','']
    dest.write_text('\n'.join(lines),encoding='utf-8')
    f,o,xf,cols=u.read_data();x=xf[:,spec['full_feature_indices']]
    ls=u.export_predict(spec['models']['1'],x);ss=u.export_predict(spec['models']['-1'],x)
    direction=np.where(ls>ss,1,np.where(ss>ls,-1,0));direction[np.maximum(ls,ss)<spec['threshold']]=0
    common=Path(os.environ['APPDATA'])/'MetaQuotes/Terminal/Common/Files/usdjpy_only_parity_20260912'
    common.mkdir(exist_ok=False)
    with (common/'vectors.csv').open('w',encoding='utf-8',newline='') as fh:
        w=csv.writer(fh);w.writerow(['episode_id','expected_long','expected_short','expected_direction']+pd_names())
        for i,row in f.iterrows():
            w.writerow([row.episode_id,format(ls[i],'.17g'),format(ss[i],'.17g'),direction[i]]+
                [format(v,'.17g') if np.isfinite(v) else '' for v in xf[i]])
    u.js(dict(model_sha256=u.sha(u.OUT/'frozen_model.json'),mql_sha256=u.sha(dest),
        mql_path=dest.relative_to(u.ROOT).as_posix(),parity_vectors=str(common/'vectors.csv'),
        parity_vectors_sha256=u.sha(common/'vectors.csv'),rows=len(f),prepared_at=u.stamp()),'mt5_export.json')
    print('Exported',dest,'vectors',len(f),flush=True)


def pd_names():
    import pandas as pd
    return pd.read_csv(u.OUT/'feature_catalog.csv').feature.tolist()


if __name__=='__main__':main()
