"""Mechanically materialize a private archived dependency tree; never restore user deletions."""
import csv
import json
import os
import shutil
import zipfile
from pathlib import Path
from analyze_technical_4m2m_real import ROOT, BATCH, OUT, sha
from technical_discovery_independent_recalculation import read_csv, number, score


def main():
    frozen=json.loads((OUT/'freeze_record.json').read_text())
    assert sha(OUT/'frozen_model.json')==frozen['frozen_model_sha256']
    assert sha(OUT/'TickShockTechnicalModel.mqh')==frozen['mql_model_sha256']
    dest=ROOT/'mql/Include/TickShock4m2mFrozen'
    if dest.exists():
        raise FileExistsError(dest)
    rows=[]
    with zipfile.ZipFile(BATCH/'frozen/exact_source_bundle.zip') as archive:
        for name in archive.namelist():
            if not name.startswith('mql/') or not name.endswith(('.mqh','.mq5')):
                continue
            target=(dest/name).resolve()
            assert target.is_relative_to(dest.resolve())
            target.parent.mkdir(parents=True,exist_ok=True)
            with archive.open(name) as src, target.open('xb') as dst:
                shutil.copyfileobj(src,dst)
            if name=='mql/Include/TickShock/TickShockTechnicalStudy.mqh':
                old='FileWriteString(g_tstd_features,line+"\\r\\n");FileFlush(g_tstd_features);++g_tstd_episodes;return true;'
                new='FileWriteString(g_tstd_features,line+"\\r\\n");FileFlush(g_tstd_features);++g_tstd_episodes;\n#ifdef TS_TECH_CANDIDATE\n   TSTCOnSnapshot(episode,symbol,t0,processing,quote,f);\n#endif\n   return true;'
                data=target.read_text(encoding='utf-8')
                assert data.count(old)==1
                target.write_text(data.replace(old,new),encoding='utf-8')
            rows.append(dict(path=str(target.relative_to(ROOT)),source='collection exact_source_bundle.zip:'+name+(' + restored candidate callback' if name.endswith('TickShockTechnicalStudy.mqh') else ''),sha256=sha(target)))
    for name in ('TickShockTechnicalCandidate.mqh','TickShockTechnicalModel.mqh'):
        source=ROOT/'mql/Include/TickShock'/name if name.endswith('Candidate.mqh') else OUT/name
        target=dest/'mql/Include/TickShock'/name
        assert not target.exists()
        shutil.copy2(source,target)
        rows.append(dict(path=str(target.relative_to(ROOT)),source=str(source.relative_to(ROOT)),sha256=sha(target)))
    with (OUT/'ea_dependency_hashes.csv').open('w',newline='',encoding='utf-8') as stream:
        w=csv.DictWriter(stream,fieldnames=['path','source','sha256']);w.writeheader();w.writerows(rows)
    # All training observations, independent model interpreter expectations.
    folder=Path(os.environ['APPDATA'])/'MetaQuotes/Terminal/Common/Files/technical_4m2m_model_parity_r2'
    folder.mkdir(exist_ok=False)
    spec=json.loads((OUT/'frozen_model.json').read_text())
    count=0
    with (folder/'vectors.csv').open('w',newline='',encoding='utf-8') as stream:
        w=csv.writer(stream)
        w.writerow(['episode_id','expected_long','expected_short','expected_direction']+spec['features'])
        for month in ('202501','202502','202503','202504'):
            for r in read_csv(BATCH/month/'technical_features.csv'):
                raw=[number(r.get(n)) for n in spec['features']]
                ls,ss=[score(spec['models'][s],raw) for s in ('long','short')]
                d=0 if max(ls,ss)<spec['threshold'] or ls==ss else 1 if ls>ss else -1
                w.writerow([month+':'+r['episode_id'],format(ls,'.17g'),format(ss,'.17g'),d]+[r.get(n,'') for n in spec['features']])
                count+=1
    print(f'Private dependencies={len(rows)} parity vectors={count}; original files unchanged')


if __name__=='__main__':
    main()
