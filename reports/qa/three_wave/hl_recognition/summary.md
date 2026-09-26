# M1 HLだけを右1本／反転確認型に変更した比較

2026-09-25。現行READYは保存済みの `ema_filter_off` を再利用し、新2方式だけを実際のMT5テスターで実行した。**売買用EAとSharedは変更していない。**

## 比較条件

保存済み現行結果と厳密にそろえるため、期間は **2025年1月**（2025-01-01〜2025-02-01未満）。USDJPY M1/M5、Model4、初期10,000 USD、Equity1%、EMA OFF、**RR1、SL＝認定HL−10ポイント**、クールタイム15分。M1/M5の汎用ピボット左右2/2、CHoCH、Wave1 High、押し中の戻り高値、READYの高値終値突破条件は維持。

直前のFib入口・RR1.2・reversal low SLの研究とは別の比較である。[事前仕様](plan.md)。現行との入力差はHL認識モードと研究用Magicだけ：[parameter_diff.json](parameter_diff.json)。

### 変更したHL認識

- **右1本**：M1 Wave2のHLにだけ左2・右1を使用。M1全体の `InpLowerRightBars` は2のまま。現行Sharedの同値扱い（左側は厳密、右側は同値可）を継承。
- **反転確認型**：Wave1 High以降の閉じた足の最安値をHL候補とする。その候補足の直前M1足高値を固定し、終値で上抜いた時にHLとして認定。安値更新なら候補・基準を更新。同値なら最初の候補を保持。Wave1 Highが確定して利用可能になる前には認定しない。候補はreversal lowより上である必要がある。
- どちらもHLを認定しただけで発注しない。**現行READYの高値突破条件を満たしてから発注する。** SLは同じルールだが、認定したHLの位置が違えばSL価格とロットは変わる。

## 結果

| 方式 | 取引数 | 勝率 | 損益USD | 平均初期R | PF | 最大Equity DD |
|---|---:|---:|---:|---:|---:|---:|
| 現行・保存済み | 23 | 47.83% | -111.61 | -0.0439 | 0.906 | 7.89% |
| HLだけ右1本 | 23 | 47.83% | -118.66 | -0.0472 | 0.901 | 6.87% |
| HL反転確認型 | 23 | 34.78% | -699.45 | -0.3125 | 0.530 | 9.12% |

**右1本は損益がほぼ変わらず、反転確認型は悪化した。採用はしない。** 全方式が同じ23のM5/CHoCH/Wave1構造で取引したが、入口の時刻・価格・HLとSLは一致するとは限らない。23回は1月の件数であり、毎月20回を維持できる証拠ではない。

## HL認識と実際の入口を分けると

| 方式 | HL認定まで中央値 | 認定後READY待ち中央値 | HL足から入口まで中央値 | 最大 |
|---|---:|---:|---:|---:|
| 現行 | 3分 | 1分 | 約4分 | 約8分 |
| 右1本 | 2分 | 2分 | 約4分 | 約8分 |
| 反転確認型 | 3分 | 1分 | 約4分 | 約21分 |

各方式が認定したHLの足の開始時刻を起点にした値。認定HL自体が異なるため、次の同一構造の対比較も行った。

- 右1本：現行より入口が早い3件、同じ20件、遅い0件。認定HLの足が異なるのは1件。
- 反転確認型：早い5件、同じ15件、遅い3件。認定HLの足が異なるのは8件。
- 現行方式のHLの足を共通の基準として「前後1分以内に入口が来た」件数は、両方式とも0件。
- 反転確認型自身が認定したHLから1分後の足で入れた例は1件あるが、現行のHLと同じ底であることを意味しない。

右1本でHL認定を1分早めても、その間に元の戻り高値をまだ上抜いていなければ待ち続ける。そのため認定後の待ちが1分増え、入口中央値は変わらなかった。

反転確認型はWave1以降の最安値候補を保持するため、現行が後続の別のHLへ認識を更新している場面で、より古い安値をHLとして残すこともある。HLに対応する戻り高値が変わり、認定方法の変更が必ず早期化になるとは限らなかった。

例：2025-01-20は現行のHLが21:19、入口21:24。反転型はHLが21:12、入口21:33で約9分遅くなった。詳細：[paired_entries.csv](paired_entries.csv)、[paired_summary.json](paired_summary.json)。この違いを見て定義を事後調整することはしていない。

## 検証と制限

- 研究EA・ネイティブ計算テストのコンパイルは0エラー・0警告：[EA compile](USDJPY_3Wave_HLRecognitionResearch_compile.log)、[test compile](ThreeWaveHLRecognition_Validation_compile.log)。
- 境界テスト12件成功：[policy.csv](policy.csv)。右側1本の確認待ち、同値、起点以上、Wave1確定待ち、候補更新、1分認定、同一候補の重複、形成中の足除外を確認。
- [audit.json](audit.json)：独立OHLCで全HL認定の価格と確定時刻、左2/右1、固定した直前足高値、未来足不使用を照合。SL＝HL−10、取引損益とネイティブレポート、クールタイム・単一ポジションを確認。RECOVERY_BLOCKEDなし。
- READY前までの記録は、右1本がHL認定74イベント・後のHL割れ32イベント、反転型が認定30・HL割れ6。READY成立で構造走査を終えるため、これは全認定の最終成功率やエントリー後のHL維持率ではない。
- [static_audit.json](static_audit.json)：MakePlan/Place/CheckRequest/Manage/Recover/Protect/EMAEntryAllowed/OnTickの関数本体が売買用と一致。[protected_after.json](protected_after.json)：売買用・Shared・共通入力・共通発注includeは不変。
- 差分：[EA](ea.diff)、[HL解析関数](analyzer.diff)。[ソース・EX5ハッシュ](source_hashes.json)。研究用コピーにのみ差分を適用。
- 1月は既に検討済みの期間、各方式23取引。OOSではない。History品質96%リアルティック、手数料・swap・feeは記録上0、Bid/Askスプレッドあり、遅延0。ビジュアル・デモ・ライブは未検証。
- 研究EAはテスター専用。通常インジケーターは従来のHLを描くため、新HLの確認には研究EAのマーカー／CSVを使用する。通常インジケーターとの信号一致検証は無効化している。

## 判断

今回の制約「HLだけ変更、READY条件を維持」の範囲では、改善と理想のHL±1分の入口を確認できなかった。現行方式を維持する。右1本や反転型を売買用へ適用しない。

HL付近で入ることをさらに優先するなら、次に変える対象はREADYの追加高値突破待ちになる。ただし、それはHL認識だけの変更ではなく別の入口実験なので、今回は実装していない。

## ファイル

- EA：[USDJPY_3Wave_HLRecognitionResearch.mq5](../../../../mql/Experts/USDJPY_3Wave_HLRecognitionResearch.mq5)
- プリセット：[右1本](../../../presets/USDJPY_3Wave_HLRecognition_Right1_RR10_EMAOff.set)、[反転確認型](../../../presets/USDJPY_3Wave_HLRecognition_Reversal_RR10_EMAOff.set)。MQL5/Profiles/Testerにも配置済み。
- 集計：[comparison.csv](comparison.csv)、[trades.csv](trades.csv)。生データ：[右1本](../hl_rec_right1_jan/)、[反転型](../hl_rec_reversal_jan/)、[現行保存済み](../ema_filter_off/)。
- 再集計：`python tools/swing_structure/analyze_hl_recognition.py`。実行：[runner](../../../../tools/swing_structure/run-three-wave-hl-recognition.ps1)。
