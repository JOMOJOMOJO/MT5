"""Export frozen estimators and causal policy. Never reads final-holdout data."""
import json
import csv
import os
import pickle
from pathlib import Path
import numpy as np
import two_stage_ml as study


def main():
    out=study.OUT
    freeze=json.loads((out/'python_freeze.json').read_text())
    for name,expected in freeze['files'].items():
        assert study.sha(out/name)==expected,name
    spec=json.loads((out/'frozen_model.json').read_text())
    dest=study.ROOT/'mql/Include/TickShockTwoStageModel.mqh'
    if dest.exists():raise FileExistsError(dest)
    lines=['// Generated: fixed two-stage model; not a production promotion.',
        '#ifndef TICK_SHOCK_TWO_STAGE_MODEL_MQH','#define TICK_SHOCK_TWO_STAGE_MODEL_MQH',
        '#define TS2_FEATURE_COUNT 486',f'#define TS2_USED_COUNT {len(spec["features"])}',
        f'#define TS2_HOLD_SECONDS {spec["horizon_seconds"]}',
        f'const bool TS2_ROLLING={str(spec["policy"]["policy"].startswith("ROLLING")).lower()};',
        f'const bool TS2_GATE_ENABLED={str(spec["selection"]["gate"]!=0).lower()};',
        f'const double TS2_GATE={float(spec["stage1_threshold"] or 0):.17g};',
        f'const double TS2_FIXED_THRESHOLD={spec["policy"]["threshold"]:.17g};',
        f'const double TS2_QUANTILE={float(spec["policy"]["q"] or 0):.17g};']
    def array(name,values,kind='double'):
        text=','.join(str(int(v)) if kind=='int' else format(float(v),'.17g') for v in values)
        lines.append(f'const {kind} {name}[{len(values)}]={{'+text+'};')
    array('TS2Index',spec['feature_indices'],'int')
    for key,name in [('stage1','Tradeability'),('long','Long'),('short','Short')]:
        model=spec['models'][key];array('TS2'+name+'Median',model['median'])
        if model['kind']=='LINEAR':
            for field in ('mean','scale','coefficient'):array('TS2'+name+field.title(),model[field])
            lines += [f'double TS2Score{name}(const double &raw[])','{',f' double z={model["intercept"]:.17g};',
                ' for(int i=0;i<TS2_USED_COUNT;++i){int j=TS2Index[i];',
                f' double v=(MathIsValidNumber(raw[j])&&raw[j]!=EMPTY_VALUE)?raw[j]:TS2{name}Median[i];',
                f' z+=(v-TS2{name}Mean[i])/TS2{name}Scale[i]*TS2{name}Coefficient[i];',' }',' return z;','}']
        else:
            def expr(tree,node=0):
                if model['kind']=='FOREST':
                    if tree['left'][node]<0:return format(tree['value'][node],'.17g')
                    return f'(v[{tree["feature"][node]}]<={tree["threshold"][node]:.17g}?{expr(tree,tree["left"][node])}:{expr(tree,tree["right"][node])})'
                if 'leaf_value' in tree:return format(tree['leaf_value'],'.17g')
                assert tree['decision_type']=='<='
                return f'(v[{tree["split_feature"]}]<={tree["threshold"]:.17g}?{expr(tree["left_child"])}:{expr(tree["right_child"])})'
            lines += [f'double TS2Score{name}(const double &raw[])','{',' double v[TS2_USED_COUNT];',
                f' for(int i=0;i<TS2_USED_COUNT;++i){{int j=TS2Index[i];v[i]=(MathIsValidNumber(raw[j])&&raw[j]!=EMPTY_VALUE)?raw[j]:TS2{name}Median[i];'+
                ('v[i]=(double)(float)v[i];' if model['kind']=='FOREST' else '')+'}',' double z=0;']
            lines += [' z+='+expr(tree)+';' for tree in model['trees']]
            lines += [f' return z/{len(model["trees"])}.0;' if model['kind']=='FOREST' else ' return z;','}']
    lines += ['#endif','']
    dest.write_text('\n'.join(lines),encoding='utf-8')
    with (out/'dataset.pkl').open('rb') as handle:f,o,xf,columns,names=pickle.load(handle)
    x=xf[:,spec['feature_indices']]
    scores={key:study.export_predict(model,x) for key,model in spec['models'].items()}
    score=np.maximum(scores['long'],scores['short'])
    if spec['policy']['policy'].startswith('ROLLING'):
        thresholds=study.rolling_thresholds([],[],f.t0_processing_msc.to_numpy(),score,spec['policy']['q'])
    else:thresholds=np.full(len(f),spec['policy']['threshold'])
    direction=np.where(scores['long']>scores['short'],1,np.where(scores['short']>scores['long'],-1,0))
    direction[score<thresholds]=0
    if spec['selection']['gate']!=0:direction[scores['stage1']<spec['stage1_threshold']]=0
    common=Path(os.environ['APPDATA'])/'MetaQuotes/Terminal/Common/Files/two_stage_model_parity_20260913'
    common.mkdir(exist_ok=False)
    with (common/'vectors.csv').open('w',encoding='utf-8',newline='') as handle:
        writer=csv.writer(handle)
        writer.writerow(['episode_id','processing_msc','expected_stage1','expected_long','expected_short','expected_threshold','expected_direction']+names)
        for i,row in f.iterrows():
            writer.writerow([row.episode_id,int(row.t0_processing_msc),scores['stage1'][i],scores['long'][i],scores['short'][i],
                thresholds[i] if np.isfinite(thresholds[i]) else '',int(direction[i])]+[v if np.isfinite(v) else '' for v in xf[i]])
    study.js(dict(model_sha256=study.sha(out/'frozen_model.json'),source_path=dest.relative_to(study.ROOT).as_posix(),
        mql_sha256=study.sha(dest),holdout_read=False,status='GENERATED_NOT_YET_PARITY_VALIDATED',
        development_vectors=str(common/'vectors.csv'),vectors_sha256=study.sha(common/'vectors.csv'),rows=len(f)), 'mql_export.json')


if __name__=='__main__':main()
