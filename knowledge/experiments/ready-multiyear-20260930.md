# 旧年追加と前回仮説の期間再検証

通常READY固定・EMA OFF・ヒゲ2/2・SL reversal low−10points・RR1.2。2016〜2025で2,091候補を得たが、実tick品質条件を満たしたのは295件。取得年数の増加を有効ラベル数の増加と混同しない。

2025年213候補の四半期walk-forwardを固定モデルで検証。LightGBM集約AUC0.523、TreeD2 0.558。LightGBM Q2 AUC0.613に対しQ4 0.422。複数年を足してもモデルの確率順位は安定せず、Brierも定数予測より悪い。

前回の2024小標本で良かった「M5 Wave1 close locationが高い」は2025Q2〜Q4で逆転した。過去の有望な説明を保持するために新しい条件を足すのではなく、否定結果として残す。学習係数が4fold同符号でも学習期間が入れ子なら独立な4再現ではなく、test側を見る。

次の制約はモデル追加ではなく実tickラベル品質と標本数。現行READYの2025頻度は月平均17.75件で、見送りfilterのみでは毎月20回の目標を解決しない。本番昇格なし。

[研究報告](../../reports/qa/three_wave/ready_multiyear_ml/summary.md) / [四半期特徴比較](../../reports/qa/three_wave/ready_multiyear_ml/analysis/quarterly_hypothesis_statistics.csv) / [固定bin](../../reports/qa/three_wave/ready_multiyear_ml/analysis/pooled_probability_bins.csv)
