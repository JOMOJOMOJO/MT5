# 逆方向につながる①の両側見送り・表示 QA

## 結果

- 実 EA を include した native harness：3 設定 × 282 = **846 assertions PASS**、0 failures。
- 表示専用の通常チャート fixture：**27 assertions PASS**、0 failures。実際の before/after PNG を保存し、目視確認済み。
- 独立 CSV 監査：**202 checks PASS**。両側見送り OFF のエンジンは、変更前コピーと **912 event rows の全 CSV 列が一致**。
- EA/harness/replay のコンパイルはそれぞれ 0 errors / 0 warnings。MetaEditor のプロセス戻り値 1 は既存 build script がログの成功結果と照合して扱っている。

[native manifest](native_latest.json)、[表示 manifest](display_latest.json)、[独立監査](native_event_audit.json)、[実行物と現行ソースの照合](qa_attestation.json)。

## 判定の検証範囲

M15/M5・M5/M1 の各 LONG→SHORT / SHORT→LONG を、旧候補のみ取消 ON/OFF と、旧候補が単なる候補／未発注シグナルの両方で確認した。新候補の WAVE1_BREAK → 古い INVALIDATE → 新しい INVALIDATE の順序、同時刻の理由 `CONNECTED_OPPOSITE_W1_BOTH`、相互 setup ID・共有頂点、後続足・重複配信からのシグナルや発注の復活防止を検証した。

送信済み注文・保有中ポジションは両側取消の対象にならない。未確定足、遅延した確定足、起点時刻の不一致、半ポイント境界、価格差超過、未来の known_at、銘柄・時間足の違いも検証した。通常の発注を含む収益性検証ではなく、発注 ON の設定でも対象候補から注文・ポジションが生じないことを確認する fixture である。

ユーザー提示画像の元ログと一致した [2025-01-14 の保存事例](recorded_pair.json) も使用した。21:35 の高値 2676.33 を共有する旧 LONG と新 SHORT は、両側 ON なら **22:15 の新候補認識時点で双方が終了**する。元ログで後に出た 22:39 の SHORT 注文は、判定入力には使わない。この保存値の再判定は一年分の市場データの再実行ではない。

## 描画の確認

通常チャート fixture は、2025 年の日付を付けた合成 OHLC だけを取引不可の専用カスタム銘柄へ登録する。注文関数・口座照会・シグナル計算を含まない。**実バックテスト画面のスクリーンショットではない**。

20 個の同一点ラベルについて、全件表示、矩形の非重複、画面内配置、元の時刻・価格、有限の引出線、他の描画物を管理しないこと、繰り返し配置・ズーム、画面外→画面内への復帰、OFF 時の元フォント 10 と色・本文・座標の復元を確認した。

- [変更前の同一点ラベル](display/run_b562a513/ld_b562a513_dense_before.png)
- [間隔を空けたラベル](display/run_b562a513/ld_b562a513_dense_after.png)

20 個を同一点へ置いた厳しい fixture なので引出線は多い。通常の既知役割のラベルは短縮表示を持ち、原文と出所は tooltip / CSV に残る。どの密度・ズームでも完全に重複しないという保証ではなく、物理的な画面容量を超える場合にも候補自体は隠さない。

## Tester の表示制約と保存した失敗

headless Tester の chart API は見かけの寸法を返すため、表示未確認を PASS と数えない。最終 native 3 設定では表示の行を `NOT_TESTED` と明記した。

Visual Tester では 20/20 の矩形配置・有限線・元アンカーなどは確認できたが、`ChartScreenShot` が true を返しても PNG を出さず、固定価格レンジ変更も反映されなかった。既存の recorded review runner と同じ制約である。`run_5ae27b2d` / `run_0ca0c334` の失敗は削除せず残し、表示証拠は成功した通常チャート描画で補った。Tester の標準レポート画像を before/after 証拠に数えていない。

他に、初回 headless 表示仮定、長い出力パス、通常チャート runner の書込中 CSV 読込で試行が止まった記録も保持した。いずれも検証側の修正であり、通過を得るための取引ルール変更はしていない。

## 再実行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compile.ps1 -Source mql/Experts/tests/Wave33PairLayoutHarness.mq5 -LogPath reports/qa/w33_pair_layout_20261025/compile/harness.log
powershell -NoProfile -ExecutionPolicy Bypass -File reports/qa/w33_pair_layout_20261025/run_native.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compile.ps1 -Source mql/Experts/tests/Wave33LabelReplay.mq5 -LogPath reports/qa/w33_pair_layout_20261025/compile/replay.log
powershell -NoProfile -ExecutionPolicy Bypass -File reports/qa/w33_pair_layout_20261025/run_display.ps1
python reports/qa/w33_pair_layout_20261025/audit_native.py
```

全 runner は専用の portable terminal だけを起動・終了する。既存の MT5 を停止しない。2026 年の取引データ、一年分の収益、実ティック、最適化は今回の対象外。
