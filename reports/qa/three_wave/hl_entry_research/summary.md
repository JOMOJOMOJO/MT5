# HL直後 / HL再接近 / READY 比較（2026-09-25）

## 結論

HL再接近はHL付近で買う目的に合い、今回Q1合計は+91.20 USD / 平均+0.087Rだった。ただし11取引のみで、1月7回+298.33、2月3回-103.75、3月1回-103.38。安定した正期待値や最低月20回は確認できず、通常売買用への採用はしない。

HL確定直後はREADYより平均入口が近づいたが、21取引・-357.51 USD・平均-0.169Rでマイナス。入口を早めるだけで十分という結果ではない。

## 固定条件

USDJPY M1/M5、2025-01-01〜2025-04-01未満、Model4、初期10000 USD、Equity1%、RR1、EMA20>50>100かつ全上向きON、M1/M5左右2本、クールタイム15分。**SLは全方式reversal low−10ポイントに統一**。したがって、Wave2 Low SLで行った以前のREADY結果とは別の比較。

[事前計画](plan.md)。HL近傍幅は25%で固定し、最適化していない。Q1は参照済みデータで未見OOSではない。

## 成績

| 指標 | READY | HL確定直後 | HL再接近 |
|---|---:|---:|---:|
| 取引数 | 23 | 21 | 11 |
| 勝率 | 43.48% | 42.86% | 54.55% |
| 純損益USD | -465.38 | -357.51 | +91.20 |
| 平均損益R | -0.2023 | -0.1692 | +0.0869 |
| PF | 0.682 | 0.713 | 1.177 |
| 最大Equity DD | 6.59% | 5.37% | 2.40% |
| 平均HLから入口までの距離 | 7.00 pips | 4.20 pips | 1.98 pips |
| 平均SL幅 | 13.67 pips | 11.82 pips | 11.12 pips |

距離の平均は各方式が実際に取引した集合の値で、全く同じ候補における因果効果と解釈しない。[同一M5/M1試行の取引比較](paired_trades.csv)ではSL価格が一致することを別途確認。

| 月 | READY 回数/損益USD | HL直後 回数/損益USD | HL再接近 回数/損益USD |
|---|---:|---:|---:|
| 1月 | 12 / -164.15 | 11 / +41.84 | 7 / +298.33 |
| 2月 | 5 / +93.09 | 6 / -202.91 | 3 / -103.75 |
| 3月 | 6 / -394.32 | 4 / -196.44 | 1 / -103.38 |

[全体CSV](comparison.csv)・[月別CSV](monthly.csv)・[全取引CSV](trades.csv)。損益は全dealのprofit+commission+swap+fee、Rはpositionの初期リスク基準、月はエントリー月。nativeレポートと金額照合済み。

## 取引が減る理由

HL直後と再接近は同じ66個の初回HLを監視開始した。

- HL直後: 63件判断、21件発注、41件EMAで見送り、1件既存ポジション。ほか3件無効化。
- HL再接近: 31件判断、11件発注、19件EMAで見送り、1件既存ポジション。残り35件は判断前に無効化（構造失効など27、HL/起点割れ7、同じ親波の判断済み1）。

EMAを外したり再接近幅を広げたりする最適化は行っていない。近い価格を待つほど機会を失う関係があるが、今回だけで最適な幅を決めない。

## 実装

研究EA `mql/Experts/USDJPY_3Wave_HLEntryResearch.mq5/.ex5`、テスター専用。通常EA/Shared/注文共通部は変更なし。

`InpHLEntryMode`:
- 0 `HL_ENTRY_READY`: 現行再上抜け。
- 1 `HL_ENTRY_CONFIRM`: 最初の有効なHL確定後の利用可能Ask。
- 2 `HL_ENTRY_RETEST`: そのHLを固定し、Bid>=HLかつAsk<=HL+0.25*(HL−SL)で判断。確定時点で既に範囲内ならその時点で判断し、範囲外ならtickで待つ。

`InpHLNearFraction=0.25`。後のHL更新で初回HLを移動しない。初回HL割れ、起点割れ、親波の失効/期限切れ、READY機会終了で取消。初回判断がEMA等で拒否されても後から追わない。追加2方式は同じM5親波で判断1回。EMAは確定M1のみ、構造更新は毎分、再接近監視のみtick単位。

共通SLの比較を守るため`InpStopMode=1`以外は研究版で拒否。Magic初期値260922335。研究監視はテスト内だけで、途中再起動からの再開は対象外。`TW_hl_events.csv`にARM/DECISION/INVALIDATE、HL/確定時刻、Ask範囲、SL、判断理由を保存。

## 検証

- [コンパイル](compile.log): エラー0・警告0。
- [policy](policy.csv): ネイティブ判定12件成功。Ask境界・スプレッド・HL割れ・期限・重複等。
- [静的監査](static_audit.json): MakePlan/Place/CheckRequest/Manage/Recover/Protect/EMAEntryAllowedの関数本体は通常版と一致。
- [実行監査](audit.json): 同じ66監視開始、確定後判断、固定HL・SL、Ask範囲、1%リスク、クールタイム、1ポジション、損益照合。
- [保護ファイル](protected.json)は不変。[差分](entry_adapter.diff)と[ソースハッシュ](source_hashes.json)。
- 短期テスト後、消費済み候補を毎tickコピー/走査判定する無駄を省いた。READY実行中の変更だったが、READYはこの追加監視関数を呼ばない。追加2方式は修正後ビルドで実行。売買条件は不変。

履歴品質は全方式98%リアルティック。3/27の欠落・不整合による補完あり。その日の直接入出取引は0だが、間接影響まで否定しない。記録上commission/swap/feeは0、ExecutionDelay=0。別口座の手数料・実約定遅延、長期/OOS、ビジュアル画面での目視は未検証。

## 使用ファイル

テスターで`USDJPY_3Wave_HLEntryResearch`を選び、以下を読み込む。全38入力明示・最適化OFF・RR1・EMA ON。MQL5/Profiles/Testerにも配置。

- [READY](../../../presets/USDJPY_3Wave_HLResearch_READY_RR10.set)
- [HL確定直後](../../../presets/USDJPY_3Wave_HLResearch_HLConfirm_RR10.set)
- [HL再接近](../../../presets/USDJPY_3Wave_HLResearch_HLRetest_RR10.set)

nativeレポート: [READY](../hl_compare_q1_ready/tw_hl_compare_q1_ready.htm) / [HL直後](../hl_compare_q1_confirm/tw_hl_compare_q1_confirm.htm) / [HL再接近](../hl_compare_q1_retest/tw_hl_compare_q1_retest.htm)。再集計: `python tools/swing_structure/analyze_hl_entry_comparison.py`。

## 採用判断

HL再接近は位置の仮説を満たした一方、頻度・安定性目標を満たさない。通常EAに反映せず研究として保管する。次の検証を行う場合は25%を固定した別期間での再現性が先であり、同じQ1で幅やEMA条件を探索して利益を合わせ込まない。
