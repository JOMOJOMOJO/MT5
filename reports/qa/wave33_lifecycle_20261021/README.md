# Wave33 v1.30：波の所属・初動終了の修正確認

古い①第1波・②押し戻りへ、数時間後の別の下位転換を結び付けていた問題を修正した。W2に属する下位構造に限定し、初動が進んだのにトリガー未成立だった候補は終了する。経過時間・抵抗線・損益を見た調整はしていない。[正確な仮定と限界](../../../knowledge/experiments/2026-10-21-wave33-lifecycle-repair.md)

## ユーザー画像3件の固定比較

時刻はブローカー／元データ時刻。旧挙動で同じシグナル・W1・約定価格を再現した後、修正版の同じ候補を照合した。

|元の売買|修正版で候補を終了した時刻|その候補からの売買|
|---|---|---:|
|2016.05.12 01:55 SHORT|2016.05.11 20:55|0|
|2016.05.16 14:30 LONG|2016.05.16 09:35|0|
|2016.05.23 16:50 SHORT|2016.05.23 10:00|0|

終了理由はすべて `INITIAL_MOVE_MISSED`。W2の後、確定終値がW1終点を越える初回進行を観測した時点で、有効シグナルが成立していなかった。[詳細比較](case_comparison/README.md)、[機械判定・全件数・ハッシュ](case_comparison/case_regression.json)。同日の別候補の正常売買まで禁止したという意味ではない。

## 検証証拠

- [ネイティブハーネスとXAUUSD両パターン](engineering/20261021_092608_f901e83c/review.md)：既存エンジン100・描画19・新規寿命96、計215項目PASS。Aは19候補・1約定1決済、Bは59候補・9約定9決済。
- [USDJPY固定比較](usdjpy_2016/20261021_092751_77c88c38/review.md)：両設定179候補、旧61シグナル55約定54決済、修正版25シグナル24約定24決済。全候補・見送りを保存。
- [実CSVの追加因果監査](lifecycle_audit.json)：3run、1,079チェック、違反0。所属・既知時刻・同候補重複・終了後の再利用を確認。
- 全MQLコンパイルは0 errors / 0 warnings。[独立コードレビュー](independent_review.md)でも修正範囲の新規問題なし。
- [旧v1.20バックアップとハッシュ](baseline_v120/hashes.json)、[元CSVの読み取り専用コピー](source_snapshot/original_user_events.csv)、[配布記録](deployment.json)。

USDJPY 2016のModel4指定は、ネイティブログ上では「no real ticks, every tick generation used」にフォールバックしている。上記は候補寿命の回帰確認であり、実ティックの執行品質・成績は証明しない。全取引の利益比較や最適化は行わない。

## 描画レビュー

記録イベントを同じDisplayへ時刻順に渡し、各判定時点までの実M1バーだけで通常MT5チャートを描く。シグナル再計算・注文コードなし。ビジュアルテスター自体のスクリーンショットではない。

[10事例の日時・既知時刻・画像一覧](review_cases.md)、[有限線・パネルOFF・失効表示の監査](drawing_audit.json)。Aの2016年描画では履歴本数の上限を修正して再実行した。[失敗と再確認](drawing_review/render_retry.md)

- A：画像3件の旧候補終了＋新しいLONG約定・SHORTシグナルの計5事例。SHORTは同銘柄の保有中のため注文見送り。[一覧](drawing_review/A/render_summary.csv)、[選定元CSV](render_cases/a_pivot_diagnostic/review_cases.csv)。
- B：LONG/SHORT、成立・始点破壊・初動失効・期限切れの5事例。[判定根拠と既知時刻](engineering/20261021_092608_f901e83c/b_orders_smoke/review_cases.md)、[描画一覧](drawing_review_b/B/render_summary.csv)。

波形の事後位置と、EAが知った時刻はCSV・tooltipで分ける。元足へ遡った理想注文を作らない。最終的な波形一致のレビューはユーザーが行う。

## 再実行

[MT5操作手順](../../../docs/validation/wave33-tester-orders.md)に従い、v1.30 EX5と新しいSETでテスターを再起動する。`InpStrictWaveLifecycle=true`、パネルOFF、山谷破線ON、抵抗DISPLAY_ONLY、RR1、各注文のリスク1%を初期値とする。発注はテスター内に限定。
