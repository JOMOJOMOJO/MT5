"""Package only USDJPY observations, with deterministic gzip and provenance.

This is run after holdout evaluation, never as a model-selection input.
"""
import gzip
import io
import json
import pandas as pd
import usdjpy_only_ml as u


def main():
    u.check_freeze();assert (u.OUT/'holdout_complete.json').exists()
    folder=u.OUT/'inputs';folder.mkdir(exist_ok=True);manifest=[]
    for month in (202501,202502,202503,202504,202505,202506):
        src=u.BATCH/str(month);qa=json.loads((src/'collection_qa.json').read_text())
        for name in ('technical_features.csv','technical_outcomes.csv'):
            raw=pd.read_csv(src/name,dtype=str,keep_default_na=False)
            part=raw[raw.symbol.eq('USDJPY')].copy()
            data=part.to_csv(index=False,lineterminator='\n').encode('utf-8')
            dest=folder/f'{month}_{name}.gz'
            with dest.open('wb') as fh:
                with gzip.GzipFile(filename='',mode='wb',fileobj=fh,mtime=0) as gz:gz.write(data)
            reloaded=pd.read_csv(dest,dtype=str,keep_default_na=False)
            assert reloaded.equals(part.reset_index(drop=True))
            manifest.append(dict(month=month,run_id=qa['run_id'],path=dest.relative_to(u.ROOT).as_posix(),
                sha256=u.sha(dest),bytes=dest.stat().st_size,rows=len(part),
                source_path=(src/name).relative_to(u.ROOT).as_posix(),source_sha256=u.sha(src/name),
                transformation='Filter symbol == USDJPY; preserve original string cells; deterministic gzip'))
    u.dump(manifest,'input_subset_manifest.csv')
    # The cached dataset and fitted/prediction evidence remain reproducible but
    # need not be pushed in addition to the compressed source observations.
    print('Packaged',len(manifest),'USDJPY files',sum(r['bytes'] for r in manifest),'bytes')


if __name__=='__main__':main()
