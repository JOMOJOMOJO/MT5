# PF候補の次段階提案: 実コストを先に確認する

2026-10-17。ユーザーの「次はどう進めるか」への提案。新戦略の実装、MT5実行、昇格は行っていない。[既存追加監査](2026-10-17-positive-pf-followup-review.md)の固定ルールを維持する。

## 今回確認した追加情報

[Bybit公式CFD費用説明](https://www.bybit.com/en/help-center/article/Bybit-CFD-Fees-Explained)（2026-07-30更新、2026-10-17参照）は、Tight-SpreadのForex手数料を6 USD/lot、Zero-Feeでは別途手数料なしとしている。手数料は建玉時に引かれる説明。**これは2024–25の対象口座のモード・実費を確定する資料ではない。** 過去の約定明細・口座モード・当時の仕様が必要。現行料金を当時の全期間へ実測費用として適用しない。Zero-FeeのspreadへTight-Spreadの手数料を二重計上しない。

感度の意味を確認するため、保存済みSL先着台帳を読み取り、追加6 USD/lotの会計負担だけを計算した。SHORTは総4.95 lot、元の実swap前利益35.3672156747 USDから29.70 USDを追加控除すると5.6672156747 USD。LONGは総12.35 lot、42.5550540271 USDから74.10 USDを追加控除すると−31.5449459729 USD。元のentry/exit/lot/到達順・リスクを再実行した結果ではなく、適用口座モード未確認の仮定例。元のCSV/Parquet/レポートは変更しない。

元台帳: `reports/research/account_replay_20261017/validated/USDJPY/H1/atr_breakout_{LONG,SHORT}/execution_trades.parquet`、`scenario=stop_first_lower`。式は `sum(net_pnl_before_unknown_swap_usd - 6 * volume)`。

## 提案する順序

1. 実際の対象口座モード、手数料、歴史的spread/Ask、swap、仕様を確認。未知費用は未知として残す。費用前提により今回の薄い利益が消えるかを先に調べる。
2. SHORTのルール・TP/SL各1ATR・最大10実足・重複制限を固定し、検証専用のMT5照合を1サイクル実施する案。Python候補/取引の差を説明し、実ティック範囲と生成tick代替を監査。これは旧Stage1/2未達を覆す昇格ではない。ランダム対照も同じ出口・費用・重複管理で比較する必要がある。旧固定H10のイベント対照だけを口座PFの対照にしない。
3. 正の実費後期待値と対照差に検証価値が残る場合だけ、データ閲覧履歴を監査した別期間で固定検証を計画。2024–25は探索済み、2026は開かない。評価時点・必要件数・不足時の扱いを先に決める。年約33件のSHORTでは短いデモを統計的確認と扱わない。費用で消える/再現しない場合は固定条件を保留し、新仮説を限定数で計画する。

[MetaQuotes公式](https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation)ではreal-tickモードでもtick不足分を生成する場合がある。設定名だけで全期間の実ティック検証済みとはしない。別ブローカーの同一期間は執行・価格への耐性検査として区別し、新しい独立時間標本とは数えない。
