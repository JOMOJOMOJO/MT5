# v1.85 短期執行smoke

独立照合: **PASS / 638項目**。損益は部分決済をposition単位に合算。

| 条件 | 完了position | 純損益 USD | position PF | 合計R | 平均R | 最大連敗 | native equity DD |
|---|---:|---:|---:|---:|---:|---:|---|
| v185_a_scale_off | 1 | -65.26 | 0.000 | -1.328 | -1.328 | 1 | 80.46 (1.60%) |
| v185_a_scale_on | 1 | -65.26 | 0.000 | -1.328 | -1.328 | 1 | 80.46 (1.60%) |
| v185_b_scale_off | 9 | 73.03 | 1.275 | 1.674 | 0.186 | 2 | 155.97 (3.11%) |
| v185_b_scale_on | 9 | -48.55 | 0.813 | -0.945 | -0.105 | 2 | 155.97 (3.11%) |

検証期間2020.01.01〜2020.01.11（短期smoke、年間成績ではない）、XAUUSD+、5,000 USD、risk 1%、RR入力1.0、各組の差はScaleOutだけ。

半分決済は銘柄の数量stepに切り下げるため、奇数stepでは厳密な50%にならない。最小数量で2分割できない場合は近いTPで全量決済し、リスクを増やして分割しない。建値SLは実約定価格が基準で、手数料・swap・fee・slippage込みの損益ゼロを保証するものではない。

ティック品質・TP1/建値変更・拒否などの全件数は[summary.json](summary.json)。全positionは[positions.csv](positions.csv)、同一①の比較は[paired_positions.csv](paired_positions.csv)。

実ティックの精度、未使用期間の有効性、live readinessは別の検証。勝率やPFだけで昇格しない。
