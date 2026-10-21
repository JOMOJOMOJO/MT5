"""Freeze user-supplied chart judgments against public IDs only; no label join."""
from pathlib import Path
import argparse,hashlib,json
from datetime import datetime,timezone
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/three_wave/ready_blind_chart_200'
SCORES=['continuation_probability','wave1_quality','wave2_quality','selling_pressure_decay','higher_tf_alignment']
FIELDS=['blind_id','overall_grade',*SCORES,'comment']

def main(path):
    data=Path(path).read_bytes();h=hashlib.sha256(data).hexdigest()
    rows=json.loads(data.decode('utf-8-sig'))
    assert isinstance(rows,list) and len(rows)==20,'Expected exactly 20 judgments'
    public=pd.read_csv(BASE/'public_sample_manifest_20.csv')
    assert list(public)==['blind_id','raw_image_path','annotated_image_path']
    for r in rows:
        assert isinstance(r,dict) and set(r)==set(FIELDS),'Unexpected or missing fields'
        assert isinstance(r['blind_id'],str) and r['overall_grade'] in ['A','B','C']
        for c in SCORES:
            assert type(r[c]) in [int,float] and 0<=r[c]<=100,f'Invalid {c}'
        assert isinstance(r['comment'],str) and r['comment'].strip()
    ids=[r['blind_id'] for r in rows]
    assert len(set(ids))==20,'Duplicate ID'
    assert set(ids)==set(public.blind_id),'Missing or unexpected public ID'
    # Content-addressed receipt: preserve original bytes and submitted ordering.
    out=BASE/'judgments'/('submission_'+h[:16]);out.mkdir(parents=True,exist_ok=True)
    raw=out/'original_submission.json'
    if raw.exists():assert raw.read_bytes()==data
    else:raw.write_bytes(data)
    table=pd.DataFrame(rows,columns=FIELDS)
    csv=out/'judgments_frozen.csv'
    if not csv.exists():table.to_csv(csv,index=False,encoding='utf-8-sig')
    else:
        pd.testing.assert_frame_equal(pd.read_csv(csv),table,check_dtype=False)
    counts=table.overall_grade.value_counts().reindex(['A','B','C'],fill_value=0).to_dict()
    artifacts={}
    for r in public.itertuples():
        for key in ['raw_image_path','annotated_image_path']:
            f=BASE/getattr(r,key);artifacts[getattr(r,key)]=hashlib.sha256(f.read_bytes()).hexdigest()
    receipt=out/'receipt.json'
    if not receipt.exists():
        metadata=dict(status='FROZEN_VALIDATED_NOT_JOINED',received_utc=datetime.now(timezone.utc).isoformat(),
            original_sha256=h,count=20,grade_counts={k:int(v) for k,v in counts.items()},
            duplicate_ids=0,missing_ids=0,unexpected_ids=0,all_scores_in_range=True,
            original_text_unchanged=True,source='USER_ATTACHED_JSON',
            expected_image_variant='raw',actual_image_variant_independently_verified=False,
            judge_model=None,judge_version=None,judge_session_context_verified=False,
            actual_prompt_verified=False,grading_time=None,
            image_hashes_at_receipt=artifacts,
            public_manifest_sha256=hashlib.sha256((BASE/'public_sample_manifest_20.csv').read_bytes()).hexdigest(),
            prompt_template_sha256=hashlib.sha256((BASE/'prompt_template.md').read_bytes()).hexdigest(),
            private_label_manifest_read=False,realized_outcomes_read=False,label_join_performed=False)
        receipt.write_text(json.dumps(metadata,indent=2,ensure_ascii=False),encoding='utf-8')
    report=f'''# ブラインド判定の受領・固定

提出20件のIDは公開試作20件と完全一致。重複・欠落・未知IDなし。指定7評価項目が全件そろい、5数値項目は全て0〜100。原文と提出順を保存し、評点・commentは変更していない。

| grade | 件数 |
| --- | ---: |
| A | {counts['A']} |
| B | {counts['B']} |
| C | {counts['C']} |

原文SHA256：`{h}`。

- original_submission.json：添付原文のバイト列をそのまま保存。
- judgments_frozen.csv：後の照合用。blind_idと提出評価のみ。
- receipt.json：受領時刻、原文・公開画像・公開manifest・prompt templateのhash、検証結果。

以前の案内によりraw判定を想定するが、実際に使用した画像版、モデル名・版、プロンプト、チャット履歴はこのJSONだけから確認できないため未確認と記録した。添付にない情報を補完しない。

この受領処理はprivate対応表・結果ラベルを読み込まない。実結果join、勝率/損益/PF/AUCの算出、LightGBM比較は未実施。残り180件の画像生成も行っていない。
'''
    (out/'intake_validation.md').write_text(report,encoding='utf-8')
    print(json.dumps(dict(folder=str(out),count=20,grade_counts={k:int(v) for k,v in counts.items()},
                         missing=0,duplicates=0,status='FROZEN_VALIDATED_NOT_JOINED'),ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('submission');main(p.parse_args().submission)
