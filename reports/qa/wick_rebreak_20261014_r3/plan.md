# A/B研究の継続：過去環境差と現行ペアの一致を区別する

## 状況

[r2](../wick_rebreak_20261013_r2/plan.md) は、修正した2025年USDJPYの全期間履歴監査に合格した。
その後、6本目の `qa_EURUSD_reference` で旧r1と環境仕様が異なるため停止した。

差は `SYMBOL_SWAP_SHORT: 1.71 → 1.70` のみ。
36取引・72約定の時刻/価格/volume/SL/TP/理由・現金損益は一致し、risk/adjustment/funnelのCSVもhash一致した。
全取引は買い、同一サーバー日内で完結し、適用swapは全て0。
「過去の環境と同一」と「売買結果に影響がない」は異なるため、別々に記録する。

## 固定する条件

- [元のA/B計画](../wick_rebreak_20261013/plan.md) と入力値を維持する。最適化なし。
- r2のMQL sourceをバイト単位でコピー。EA・observer・既存Shared・本番EAは今回変更しない。
- 現在実行するreference/A/Bペアの環境仕様・履歴fingerprint・閉じた足・元候補・shadowの一致監査を維持する。
- テスト中の仕様変動、約定・cash・risk計算、期間不足、未来情報、A/B母集団差などは引き続き不合格で停止する。

## 過去runとの比較だけに適用する分類

過去runとの仕様差は `historical_environment_comparison.json` に全件記録し、差があれば `environment_exact=false` とする。
以下を全て満たした場合だけ、環境完全一致とは別に、売買結果の比較が可能と判定する。

1. 差が `SYMBOL_SWAP_LONG / SYMBOL_SWAP_SHORT` の値だけ。
2. 入力が買い専用で、全実取引も買い。
3. 全実取引が同一サーバー日内で完結。
4. 適用swapが両runとも全約定0。
5. 約定時刻・価格・volume・SL/TP・理由と、profit/commission/swap/feeが一致。
6. risk/funnel/候補/Entry/shadow/実行判断の存在するCSVが全てhash一致。
7. tester build、symbol、期間、bars/ticks、戦略inputsも一致。

この判定を現行A/Bペアの環境差を無視するためには使わない。
契約サイズ・ロット刻み・tick size・証拠金・spread・売買結果などの差を許容する例外ではない。
取引が0件なら「影響なし」の証拠にならないため例外を適用しない。

## 再利用と再実行

r2のharnessと、完結済みのUSDJPY短期reference/A/Bの計4本だけをhash検証・再監査付きで再利用する。
旧版の誤った期間hashは再利用しない。
単独で終了していた2025 USDJPY AとEURUSD referenceは再利用せず、新しいB/後続runと揃えて再実行する。
全34本のうち、新規MT5実行30本・再利用4本。別年独立口座という元の集計方針を維持する。
旧batchの失敗statusやauditファイルは書き換えない。新しい成果物で判定と由来を明示する。

## 事前検証

Python回帰テスト34件合格。swap差の記録、実適用swap・夜越え・short有効・cash差・fill差・契約差・0取引の拒否を含む。
保存済み5runを別のpreflightフォルダへコピーし、新監査を適用した結果は全て合格。
停止したEURUSDは `environment_exact=false` を維持したまま、約定/損益一致を確認した。
保存元のファイルは変更していない。

[再監査結果](preflight/artifact_reaudit/summary.json)
[EURUSDの差と影響確認](preflight/artifact_reaudit/qa_EURUSD_reference/historical_environment_comparison.json)

起動後は対話を終了し、ユーザーの完了通知後に全期間の損益・頻度・年別再現性を評価する。
現段階でBの有効性・本番採用は未判定。
