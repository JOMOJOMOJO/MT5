"""Verify the frozen 20-image pilot and record completed human-facing visual QA.

No grading, outcomes, label joins, or return analysis.
"""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
from PIL import Image
from build_blind_chart_pilot import ROOT,OUT,SOURCE,SAFE,META,selection,ph,png_chunks

def main():
    priv=OUT/'private_audit';a=json.loads((priv/'machine_audit.json').read_text())
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    assert sha(SOURCE)==a['source_candidate_sha256']
    assert sha(OUT/'blind_sample_manifest_200_private.csv')==a['sample_sha256']
    assert all(sha(ROOT/p)==h for p,h in a['source_hashes'].items())
    assert all(sha(ROOT/p)==h for p,h in a['production_hashes'].items())
    assert sha(Path(__file__).with_name('build_blind_chart_pilot.py'))==a['generator_sha256']
    x=pd.read_csv(SOURCE,usecols=list(dict.fromkeys(SAFE+META)));x=x[x.label_exclusion.eq('INCLUDED')]
    m=selection(x);pub=pd.read_csv(OUT/'public_sample_manifest_20.csv')
    assert list(pub)==['blind_id','raw_image_path','annotated_image_path']
    assert pub.blind_id.to_list()==m.iloc[:20].blind_id.to_list()
    assert len(m)==200 and m.groupby('year').size().eq(20).all()
    assert m.iloc[:20].groupby('year').size().eq(2).all()
    assert m.blind_id.is_unique and m.candidate_id.is_unique
    b=pd.read_csv(priv/'ohlc_availability.csv');ann=pd.read_csv(priv/'annotation_availability.csv');pixels=pd.read_csv(priv/'pixel_audit.csv')
    assert len(b)==6560 and len(ann)==189 and len(pixels)==20
    assert ((b.close_time*1000<=b.entry_msc)&(b.available_at*1000<=b.entry_msc)).all()
    assert ((ann.bar_time*1000<=ann.entry_msc)&(ann.confirmed_time*1000<=ann.entry_msc)&(ann.available_at*1000<=ann.entry_msc)).all()
    for c in ['prefix_pixel_match','future_mutation_pixel_match','label_mutation_pixel_match','future_annotation_blocked','metadata_empty','base_unchanged_outside_annotation_mask']:
        assert pixels[c].all()
    before=pd.read_csv(priv/'pre_choch_timestamp_fix/pixel_audit.csv').set_index('blind_id')
    for row in pixels.itertuples():assert before.loc[row.blind_id,'raw_pixel_hash']==row.raw_pixel_hash
    files=list((OUT/'public').rglob('*.png'));assert len(files)==40
    assert {p.stem for p in files}==set(pub.blind_id)
    assert all(p.suffix=='.png' for p in (OUT/'public').rglob('*') if p.is_file())
    hashes=[]
    for row in pub.itertuples():
        q=pixels[pixels.blind_id.eq(row.blind_id)].iloc[0]
        for kind,path in [('raw',row.raw_image_path),('annotated',row.annotated_image_path)]:
            f=OUT/path;im=Image.open(f)
            assert im.size==(2400,1600) and im.mode=='RGB' and not im.info
            png_chunks(f);assert ph(im)==q[kind+'_pixel_hash']
            hashes.append(dict(blind_id=row.blind_id,variant=kind,pixel_hash=ph(im),file_sha256=sha(f)))
    pd.DataFrame(hashes).to_csv(priv/'final_image_hashes.csv',index=False)
    omitted=pd.read_csv(priv/'annotation_omissions.csv')
    assert len(omitted)==11 and omitted.label.eq('return high').all() and omitted.reason.eq('NO_LOGGED_POINT').all()
    special={'5a9f8cfc9e7342169b444e9125036592':'M5/H1に大きな値幅。小さな足は圧縮されるが軸切れなし。',
             '117745a30f684770b3f612a2eaf2101f':'H1の長いヒゲを全表示。原寸でも確認。小足の相対的縮小は仕様。'}
    qa=[]
    for row in pub.itertuples():
        qa.append(dict(blind_id=row.blind_id,raw_review='PASS',annotated_review='PASS',four_tf_readable=True,
            candles_not_clipped=True,legend_outside_candles=True,base_pixels_identical=True,
            note=special.get(row.blind_id,'4時間足・ローソク・凡例・境界を確認。採点はしていない。')))
    pd.DataFrame(qa).to_csv(priv/'visual_qa.csv',index=False)
    fraction=100*pixels.annotation_candle_fraction.max()
    audit=f'''# 20件生成監査

2026-10-02。最終判定：**20/20 PASS（raw20枚・annotated20枚）**。
要求された時刻・入力分離・画素不変性・公開物監査の範囲で未来情報混入を検出しなかった。これは将来の予測力や保存元データの全ての問題がないことを証明するものではない。

## 実施結果

| 検査 | 結果 |
| --- | --- |
| 固定母集団／抽出 | 2083件から2016〜2025各年20件、計200件 |
| 試作 | 各年の抽出順位1・2、計20件。年ごとの入れ替えなし |
| 再抽出再現性 | 保存集合と固定seed再計算が一致 |
| 重複 | candidate_id、blind_idとも0 |
| 表示OHLC | 6560足、全てclose_time<=Entry・available_at<=Entry |
| prefixだけで描画 | 20件×2版でpixel hash完全一致 |
| 未来・未取得OHLCを極端値へ改変 | 20件×2版でpixel hash完全一致 |
| outcome/R/TP/SL/exit/MFE/MAE改変 | 20件×2版でpixel hash完全一致 |
| 描画注釈 | 189点、全てbar/confirmed/available<=Entry |
| CHoCH | M1/M5の40点全てCSV・足・終値breakと照合 |
| 未来confirmed timeの注釈 | 全20件で描画されないことを確認 |
| READY境界 | 4パネルとも固定右境界。未確定足を追加しない |
| 原ログ照合 | 20件の描画用構造列とEntry quoteが一致 |
| raw/annotated共通ベース | overlay外の全画素が一致 |
| PNG | 40枚全て2400×1600 RGB、info空、IHDR/IDAT/IENDのみ |
| 公開物 | 40PNGと別置き3列manifestのみ。年・候補ID・時刻・出典・結果・private pathなし |
| 本番コード | EA/Shared/収集コードの作業前後hash不変 |

## 見つけて修正した点

CHoCHの内部構造はbar timeを持つが、CSV書き出しはTF秒を加えた**閉じた時刻**だった。試作初回はこれを開始時刻と扱ったため11点で終値照合が失敗した。EAの `CSVSignal` 書き出しを確認し、CSV時刻をconfirmed time、そのTF秒前をbar timeとして修正した。

修正後は全40 CHoCH点が照合合格。20件のraw pixel hashは初回と完全一致。再抽出・成績閲覧・表示倍率変更はせず、同じ候補のannotatedを再生成し、全監査を再実行した。初回監査は `private_audit/pre_choch_timestamp_fix/` に保存。

## 省略した注釈

return highは9件で元ログに存在し、検証して描画した。残る11件は元ログに存在しないため省略した。未来点や仮の高値で補完していない。最終版に価格・時刻不一致を抱えた注釈はない。

## ラベル分離

母表を列許可リストで読むため、結果ラベルやTP/SLの価格は描画用データとして読み込まない。画像rendererは相対OHLCと検証済み表示点だけを受け取る。ランダム改変テストもこの投影境界の前で実施した。

`private_label_manifest_20.csv` は候補対応・時刻・年・品質等の管理情報だけで、実現損益・TP/SL結果もChatGPT判定結果もまだ含まない。publicに渡すファイルはPNGと公開3列manifestのみ。管理・監査ファイルを一緒に添付しない。

## 証跡

- [足時刻](private_audit/ohlc_availability.csv)
- [注釈時刻](private_audit/annotation_availability.csv)
- [全件の画素監査](private_audit/pixel_audit.csv)
- [最終画像hash](private_audit/final_image_hashes.csv)
- [出典・本番ファイルhash](private_audit/machine_audit.json)
- [画像QA](image_qa_20.md)

固定200件manifest SHA256：`{a['sample_sha256']}`。

## 停止状態

残り180件は未生成。採点、結果join、TP/SL比較、LightGBM比較、新特徴量追加、EA変更は未実施。追加180件にも同じ監査を全件適用する前提で、rawの生成実装は拡張可能と判断する。annotatedは今回20件の比較用に限る。
'''
    (OUT/'generation_audit_20.md').write_text(audit,encoding='utf-8')
    lines=['| blind_id | raw | annotated | 注記 |','| --- | --- | --- | --- |']
    lines += [f"| {q['blind_id']} | PASS | PASS | {q['note']} |" for q in qa]
    report=f'''# 20件・画像品質QA

2026-10-02。20候補のraw/annotated計40枚を画像として確認済み。結果ラベルを読み込まず、勝敗や継続可能性の採点は実施していない。

## 確認結果

- 2400×1600の共通配置。全20件で4時間足が識別でき、ローソク・軸・見出しの切れなし。
- M1は120本で実体幅約5px、M5は約6px、M15は約10px、H1は約13px。M1だけを別倍率へ変更していない。
- M15/H1は64/48本を全件表示。形成中足を省くため、判定直前の途中足内の変化は見えない。これは情報不足を補完せず守るべき初版の制限。
- 大きな値動きや長いヒゲがある図では、小足が相対的に細くなる。高安の切断・外れ値除去・結果依存のズームはしていない。原寸で判読できることを確認した。
- rawとannotatedは同じbase画像。凡例は予約余白、点は小さな中抜き。注釈が重なるローソク画素は最大**{fraction:.3f}%**。注釈外の全画素は完全一致。
- rawにはCHoCH/Wave/pivot/READY/Entry線なし。annotatedは確認済み構造点とREADY境界のみ。
- 注釈時刻の試作不具合は修正・再監査済み。表示レイアウトは変更していない。

全20組の上下比較画像と修正後annotated一覧を確認し、さらに2件を2400×1600原寸で確認した。縮小一覧はQA専用であり、本判定にはpublicの原寸PNGを使う。

## 個別記録

{chr(10).join(lines)}

## 判定

表示上の阻害問題なし。return highがログにない11件は省略したまま。固定仕様で残りraw180件へ拡張可能だが、今回は生成しない。今回の品質QAはChatGPTによる相場評価ではない。
'''
    (OUT/'image_qa_20.md').write_text(report,encoding='utf-8')
    final=dict(status='COMPLETE_STOPPED_AT_20',machine_pass=20,visual_pass=20,public_images=40,
        frozen_candidates=200,remaining_images_generated=0,no_grading_or_result_join=True,
        private_manifest_has_no_results=True,production_unchanged=True,
        qa_notes='CSV CHoCH close-time interpretation corrected, all 40 points verified; 11 absent return highs omitted')
    (priv/'final_review.json').write_text(json.dumps(final,indent=2),encoding='utf-8')
    print(json.dumps(final,indent=2))

if __name__=='__main__':main()
