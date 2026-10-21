"""Post-run integrity review and fixed-selection TP attribution; no refitting."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
from report_ready_rr_choice import perf,table

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_rr_choice'

def main():
    p=pd.read_csv(OUT/'predictions.csv');x=pd.read_csv(OUT/'candidates.csv')
    m=json.loads((OUT/'manifest.json').read_text())
    source=pd.read_csv(ROOT/'reports/qa/three_wave/ready_generated_tick_ml/all_candidates.csv')
    old=source.set_index('signal_id').loc[x.signal_id]
    for c in ['entry','sl','tp','entry_msc','result_r','exit_msc']:
        np.testing.assert_allclose(x[c],old[c],rtol=0,atol=0,equal_nan=True)
    for f,h in m['production_hashes'].items():assert hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==h
    for f,h in m['script_hashes'].items():assert hashlib.sha256((Path(__file__).parent/f).read_bytes()).hexdigest()==h
    a=pd.read_csv(OUT/'sequence_availability.csv')
    assert (a.max_available_at*1000<=a.entry_msc).all()
    splits=pd.read_csv(OUT/'calibration_splits.csv')
    assert (splits.train_max_known<splits.valid_min_entry).all()
    assert x.signal_id.is_unique and not p.duplicated(['model','signal_id']).any()
    assert (p.p1>=p.p12).all() and p[['p1','p12']].ge(0).all().all() and p[['p1','p12']].le(1).all().all()
    q=x[x.paired_eligible];counts=q.reach_class.value_counts()
    rows=[];forced=[]
    for name,g in p[p.paired_eligible&~p.model.str.startswith('ALWAYS')].groupby('model'):
        chosen=g[g.action.ne('SKIP')]
        v=np.where(chosen.action.eq('RR1'),chosen.rr1_result_r,chosen.rr12_result_r)
        switched=chosen[chosen.action.eq('RR1')]
        rows.append(dict(model=name,n=len(chosen),adaptive_mean=float(np.mean(v)),
            same_selected_rr1_mean=chosen.rr1_result_r.mean(),same_selected_rr12_mean=chosen.rr12_result_r.mean(),
            rr_choice_delta_vs_rr12=float(np.mean(v-chosen.rr12_result_r)),
            rescued=int(switched.reach_class.eq(1).sum()),reduced_winner=int(switched.reach_class.eq(2).sum())))
        # Reviewer-only attribution: same out-of-year predictions, no abstention.
        # This is not a newly selected/promoted policy and is shadow only.
        fv=np.where(g.e1>=g.e12,g.rr1_result_r,g.rr12_result_r)
        forced.append(dict(model=name,**perf(fv)))
    pd.DataFrame(rows).to_csv(OUT/'same_selection_rr_attribution.csv',index=False)
    pd.DataFrame(forced).to_csv(OUT/'no_abstention_diagnostic.csv',index=False)
    review=dict(status='REVIEWED',entry_sl_original_tp_labels_unchanged=True,production_hashes_unchanged=True,
        training_script_hashes_unchanged=True,availability_windows_checked=len(a),calibration_splits_checked=len(splits),
        prediction_rows=len(p),paired_labels=len(q),reach_counts={str(int(k)):int(v) for k,v in counts.items()},
        rescue_fraction_of_rr12_losses=float(counts[1]/(counts[0]+counts[1])),plots_visually_reviewed=True,
        verdict='NO_PROMOTION_FREQUENCY_AND_STABILITY_FAIL',additional_diagnostics='Post-run TP attribution only; no refit or threshold changes')
    (OUT/'final_review.json').write_text(json.dumps(review,indent=2),encoding='utf-8')
    appendix=f'''

## 完了後レビュー：結論

1. **RR1.2が遠すぎたケースは存在するが、負け全体の主因とは言えない。** 共通2082件のうち、1R前にSLは1189件、1R到達後1.2R前にSLは81件、1.2R到達は812件。RR1へ短縮して救えるのは元の1270敗中81件（{review['rescue_fraction_of_rr12_losses']:.2%}）。1R未達でも途中で上昇した可能性はあり、「全て方向が逆だった」という意味ではない。
2. 固定RR1は勝率42.9%、固定RR1.2は39.0%だが、平均Rはそれぞれ約−0.167/−0.168。勝率上昇と期待値改善は同じではない。
3. 5モデルで最も良かったTSFRESH_LGBMも実行53件、平均+0.021R、PF1.040、月0.55件。shadow平均Rの月ブロック95%区間は−0.221〜+0.247R。2020/2021/2023は負、2024は3件のみ正、2025は27件で+0.227R。年をまたいだ安定性と月20件を満たさない。
4. 時刻・スプレッドの直接入力を削除しても、持続的な正期待値は確認できなかった。これは「元モデルがシミュレータだけを学習した」という証明ではない。既存の同一目的変数による除去比較は前研究 `../ready_generated_tick_deep_review/summary.md` を参照。本研究では目的変数もRR選択へ変更しているため、旧AUCとの差を特徴削除だけの効果と扱わない。
5. tsaugのノイズ追加は平均−0.028R→+0.001Rとなったが、35件→32件という小標本でほぼ損益ゼロ。独立データを増やした成果とは評価しない。Transformer追加や条件採用へは進めない。
6. 実tick品質フラグ群のtsfreshは29件・+0.280Rと良かったが、年/期間とtick品質が交絡し、同じ既知データの部分集計である。これだけで生成tickが悪さをしていたとは特定できない。

### 見送り効果とRR選択効果の分離

同じモデルが選んだ同じ候補だけで、全てRR1.2にした場合と比較する。`rescued`はRR1へ切り替えて負けを救った件数、`reduced_winner`は元の1.2R勝ちを短縮した件数。これは保有制約を入れないshadow比較であり、Entry選択を固定した利確変更だけの差。

{table(pd.DataFrame(rows))}

特にtsfreshの53件は、RR選択で+0.021R、同じ53件を全てRR1.2なら+0.063Rだった。RR1への切り替えで救ったのは1件、利益を縮めた元の勝ちは21件。今回の小さなプラスを「伸び幅予測の成功」と解釈しない。波形モデル2種も、RR短縮で救った負けは0件だった。

補助診断として、見送りをなくし、同じ年外予測の期待Rが大きい方を必ず選んだ結果も計算した。結果確認後に追加した原因分解であり、事前固定した主評価や新方策の採用ではない。再学習・閾値変更はしていない。

{table(pd.DataFrame(forced))}

結論は **本番へ採用しない**。Entry/SL/元TPラベルの全件一致、EA/Sharedハッシュ不変、全8364窓の取得時刻、全calibration分割の因果順序、5モデルの再学習一致を確認した。生成tick主体・同分両タッチ除外・RR1決済時刻の分解能・小標本・既知期間再利用という限界は残る。元の候補が月平均17.25件のため、Entryを固定して見送りを加えるだけでは毎月20件という頻度目標に到達できない。
'''
    path=OUT/'summary.md';text=path.read_text(encoding='utf-8')
    text=text.replace('完了後のレビューで、年別の符号、頻度、合成系列の影響を確認してから結論を付ける。','完了後レビューの結論は以下に記す。')
    marker='\n\n## 完了後レビュー：結論'
    if marker in text:text=text.split(marker)[0]
    path.write_text(text+appendix,encoding='utf-8')
    print(json.dumps(review,indent=2));print(pd.DataFrame(rows).to_string(index=False));print(pd.DataFrame(forced).to_string(index=False))

if __name__=='__main__':main()
