# スプレッド遮断原因の診断

対象：quality12b固定設定の2024年全体、2026年4〜9月。旧実行は `../quality12b_revalidation_20261005/runs/20261005_120836_15208538/`。

目的はスプレッド上限2.0pipsを維持し、元の戻り値を変えず、遮断の理由を特定すること。最適化・戦略採否の新判定ではない。

## 計測

- シグナル前の元 `IsSpreadAllowed` 呼出だけ、時刻・バー時刻・tick時刻・SymbolInfoTick成否・失敗コード・Bid/Ask・point/digits/pip・symbol spread・raw計算値を記録。
- `PASS / ABOVE_LIMIT / FLOAT_BOUNDARY_ONLY / TICK_API_FAILURE / INVALID_PIP / NEGATIVE_SPREAD` に分類。
- 格子上のpoint数と小数計算の差は診断のみ。元のdouble比較による発注可否を保持する。
- Python側でも小数文字列をDecimalで再計算し、分類を照合する。
- 旧実行と入力・約定内容・bars/ticks・日別blocked_spreadが一致しない場合、同じ遮断を再現したと扱わず停止する。純損益差がある場合はスワップのみで説明可能なことを要求。

## 隔離

本番EA・Shared・凍結ベースラインは不変。研究ソースは `mql/Experts/Research/Quality12bSpreadDiagnostic.mq5`。テスター外のOnInitは失敗させる。

前回専用MT5フォルダを読み取り元にして、新規専用フォルダへ実行バイナリ・SDK・接続設定・ヒストリー/tickキャッシュをコピー。運用中のMT5には触れない。

2024年には既知の生成補完がある。原因調査で同条件を再現するため今回に限り保持し、品質JSONを保存する。`-SpreadDiagnosis` はpurposeが一致するこの凍結パッケージでのみ使用でき、通常ランナーの厳格な実tick判定は維持する。生成データを品質合格へ昇格しない。

## 起動前検証

- 診断ソース：0 errors / 0 warnings（preflight_compile.log）。
- 原因分類6テスト合格。157.000→157.020の20pointsでも元double計算が2.0pipsを微超過する境界ケースを確認。ただし実データの原因頻度は実行後まで未確定。
- 通常/診断ランナーのread-only事前検査合格。
- 差分は [instrumentation.diff](instrumentation.diff)。

実行中は会話側で待機しない。完了後 `runs/<batch>/status.json` と各期間の `spread_diagnosis.json / spread_distribution.csv / spread_monthly.csv` を確認する。

## 未証明事項

テスターが返したBid/Askの診断であり、過去ライブ市場でその価格が約定可能だった証明ではない。結果が出る前に原因確定・修正済みとは説明しない。
