# Wave33: 上位高安帯除外だけを変える固定比較

ユーザーの「実施して。」を受け、[前回提案](../../knowledge/experiments/2026-10-26-wave33-next-entry-diagnostic.md)の実テスター比較へ進む。既存EAの修正や帯幅・RRの探索は行わない。

M5×M1、部分利確OFF、2020年XAUUSD+、各5,000 USD、risk 1%、RR1、帯片幅5%を固定し、`InpSkipPriorLevelRetest` だけをOFF/ONにする。前回B分割OFFの45入力を基準とし、対象フラグと保存用タグ以外を同じにする。[専用runと結果](../../reports/backtest/runs/wave33_v185_prior_2020/)へ新規保存する。

実行前に、現行source・EX5・17headerの計19hashが前回のQA deploymentと一致することをrootで確認した。変更がないため再compileは不要とし、前回の0 errors / 0 warningsログと同じ実行物を使う。標準backtestスクリプトは既存端末共通設定も変更するため、前回と同じ専用portable/Hidden方式を再利用する。元EA、前回レポート、ユーザーの稼働端末は保護する。

OFFを取り直して前回334position・純損益-1,440.92 USDの再現性を確認する。ONでは単純に既存119件を削るだけでなく、未発注枠解放後の新しい候補・追加約定・複利ロットも追う。全費用、平均R、position PF、証拠金DD、最大連敗、四半期・方向別を報告する。

既知の2020年を未使用期間とは扱わず、real ticksが0%なら生成代替を明記する。結果が負のままなら利益改善を認定せず、帯幅やRRの救済最適化をしない。続ける根拠が得られた場合だけ、別途未使用期間の検証を考える。

固定比較は20,397項目PASSで完了した。[結果とplateau review](../../knowledge/backtests/2026-10-26-wave33-prior-filter-comparison.md)へ詳細を保存。334→215position、純損益-1,440.92→-527.93 USD、平均R -0.0975→-0.0472、証拠金DD35.90%→23.41%へ改善したが、PF0.9112で赤字、最大連敗8のまま。利益採用は見送り、追加探索を行わない。

元取引の除外119件（勝51/負68）、追加約定0。残る215件の入口は同一だが、複利数量と逆①利益決済のミリ秒単位差があり、元取引単純削除の損益と実テスターの損益は一致しない。OFFの全668dealと受理足は旧原本に完全一致し、旧configもタグ以外一致。既存端末に触れず、旧保存環境をコピーした専用portableで実施した。

[最終報告・残高図](../../reports/backtest/runs/wave33_v185_prior_2020/FINAL_REVIEW.md)と、部分利確OFFの比較用ビジュアルpreset（[OFF](../../presets/wave33/Wave33Prior_v185_B_Off_Visual.set) / [ON](../../presets/wave33/Wave33Prior_v185_B_On_Visual.set)）を保存した。presetは実行条件から描画ON・出力タグだけを変えた確認用で、EA既定値は変更していない。図は含み損益を除く実deal残高として目視確認した。[未公開seed](../../content/seeds/2026-10-26-fewer-losses-still-negative.md)には損失縮小と期待値改善の区別だけを残した。
