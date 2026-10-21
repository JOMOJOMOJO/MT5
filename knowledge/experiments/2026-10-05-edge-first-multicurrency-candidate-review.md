# 正期待値を先に確かめる：複数通貨を許容する方針への更新

## ユーザーの最新方針

まず利益を残せる手法を見つけ、必要なら通貨を増やして頻度を確保したい。したがって単通貨月20件は候補発見時の必須条件から外す。従来READYの負期待値を通貨数で補えるとは扱わない。これはこの研究スレッドの優先順位更新であり、既存の本番運用や会社全体のルート変更ではない。

## 既存候補の一次証拠確認

再検証の第一候補：`quality12b_guarded`。

- ソース：[M15 long EA](../../mql/Experts/usdjpy_20260402_round_continuation_long.mq5)
- 設定：[quality12b_guarded](../../reports/presets/usdjpy_20260402_round_continuation_long-quality12b_guarded.set)
- [旧release packet](../../.company/release/usdjpy_20260402_round_continuation_long-quality12b_guarded.md)
- [train HTM](../../reports/backtest/imported/usdjpy_20260402_round_continuation_long-quality12b_guarded-train-9m-m15.htm)
- [後半検証HTM](../../reports/backtest/imported/usdjpy_20260402_round_continuation_long-quality12b_guarded-oos-3m-m15.htm)

| 期間 | 取引数 | Net USD | PF |
| --- | ---: | ---: | ---: |
| 2025年4〜12月 | 60 | 914.94 | 1.56 |
| 2026年1〜3月 | 9 | 113.20 | 2.17 |

INIsはModel=4、ExecutionMode=0。HTMはVantage Trading Ltd、100% real ticks、初期10000 USD。保存済み結果の読取確認であり、本日再テストした数字ではない。後半検証の手数料は0、swapは+7.01 USD。現在の実口座費用や遅延を十分再現しているとは言わない。

ロジックは直近HH/HL、EMA13>EMA100、終値がEMA100より上、直近安値未割れ、EMA13までの距離、上ヒゲ/下ヒゲ率、50pip区画の低変動除外等。現ソースでは多数の追加bucketがあるが当該候補はround longのみ。USDJPY入力は変更可能でも、22pip SLと50pip区画の他通貨適合性は未検証。移植時のATR化などは単なる移植ではなく別の戦略変更になる。

## プラスという数字だけで採用できない理由

1. [選定履歴](2026-04-02-usdjpy-round-continuation-long-cycle2-quality-promotion.md)では後半区間を複数preset比較に使用。ファイル名OOSを、未閲覧の独立検証と読み替えない。
2. 後半は9件。旧releaseのforward候補記載は、実際のforward成功の証拠ではない。今回の限定確認では完了済みの新しいforward評価を確認できなかった。
3. train利益が週末ギャップ1件に集中。
   - buy deal70：2025-10-03 20:45、0.43 lot、147.431、SL147.211、TP147.761。
   - sell deal71：2025-10-06 00:01、149.421、comment `tp 147.761`。
   - +572.68 USDにswap+2.31 USDを加え、+574.99 USD。train純益の62.8%。33pip目標に対し約199pipの約定利益。
   - この1取引を保存済み損益から単純除外するとNet339.95、PF約1.21。再テストではなく、後続ロットの複利効果も再計算していない感応度診断。
   - ギャップ自体を不正と断定しない。実ブローカーでのTPギャップ約定とテスターの扱いの確認が先。

`Method2 S2 short`は長期でも4件のみで、第一候補にしない。[記録](2026-04-10-usdjpy-method2-s2-standalone-guarded-cycle1.md)。stack型は単体より頻度は高いが、今回は頻度のための追加条件を優先しない。

## 次に実施する順序

1. 当該EA・全input・コンパイラとデータを固定し、旧成績を再現する。省略inputの現default依存をなくす。週末TP約定の診断を分離する。
2. パラメータを動かさず複数年で検証する。既に調べた2016〜2025や繰返し使った2026年1〜3月は既知期間として表示する。未使用期間は実行履歴を確認するまで断定しない。
3. 単体で費用・年別・大勝依存を確認してから、対象通貨を事前固定して横展開する。勝った通貨だけ残す後付け選別は別の探索として扱う。
4. 合成ポートフォリオではUSD/JPY等の共通エクスポージャー、同時保有、同時損切り、証拠金、総SLリスクを計算する。単通貨のリスク率をそのまま全銘柄で同時使用しない。
5. 最後に合成後の月別実行数を評価する。低頻度でも質を落とすパラメータ緩和はしない。

別の新規候補を開く場合は、長めの時間軸の単純なトレンド追随を検討できる。[Time Series Momentum](https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum)は通貨を含む先物・フォワードでの長期的な一次研究である。ただし、その証拠をM15/H1の小売MT5 EAへ直接外挿しない。今回既存候補と同時に新戦略を実装しない。

## 本日の作業範囲

過去の元HTM、設定、ソースと検証履歴のレビュー。結論は「再検証対象がある」であり「勝てる手法を発見した」ではない。MT5起動、新EA実装、本番/Shared/入力値変更は行っていない。
