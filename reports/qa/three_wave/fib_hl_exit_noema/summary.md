# EMA条件OFF：Fib終値エントリー＋HL保護更新

2026-09-25。ユーザー指定により研究プリセットの `InpUseEMAFilter=false` を設定した。従来の条件はM1確定足のEMA20>50>100、かつ3本とも前足より上向き。線の傾きが平行かどうかは判定していない。OFFは並び・上向きの両方を無効にする。EMA表示は独立してONにできる。

## 結論

EMA OFFで取引は1件から38件へ増えたが、SL/TP固定版もHL更新版も負の期待値だった。更新版は勝率とDDが改善した一方、利確幅の縮小により平均損益Rはほぼ変わらなかった。今回の範囲では収益性の改善策として採用する根拠はない。月20件を満たしたのは1月だけ。

研究用のEMA OFFプリセットを保存。売買用EA・研究EA・Sharedのソースとバイナリは変更していない。研究結果を売買用へ昇格していない。

## 条件と結果

2025-01-01〜2025-04-01未満、USDJPY M1/M5、Model4、初期10,000 USD、Equityリスク1%。Fib50〜61.8%内の最初のM1確定終値の次tickで買い、初期SL reversal low−10ポイント、TP RR1.2。更新版はHL確定後SLをHL−10ポイント、新SL幅からTP1.2倍へ一度だけ変更。その他の条件は[前回の固定仕様](../fib_hl_exit/plan.md)を維持。

| EMA OFF | 取引数 | 勝率 | 損益USD | 平均初期R | PF | 最大Equity DD |
|---|---:|---:|---:|---:|---:|---:|
| SL/TP固定 | 38 | 39.47% | -523.53 | -0.1360 | 0.775 | 7.20% |
| HL確定後更新 | 38 | 47.37% | -508.87 | -0.1348 | 0.703 | 5.93% |

| 月 | 両版の取引数 | 固定版損益USD | 更新版損益USD |
|---|---:|---:|---:|
| 2025-01 | 20 | +193.27 | +46.68 |
| 2025-02 | 6 | -165.09 | -61.85 |
| 2025-03 | 12 | -551.71 | -493.70 |

39候補のうち38件発注、1件は保有中で見送り。EMA理由での見送りは0。38約定の時刻・M5構造・M1構造は両版で一致した。

同一取引の初期リスクRを比較すると改善13件、悪化17件、差が1e-6R以内8件。固定版の負けが更新版の勝ちに変わったのは3件、逆は0件。ただし勝ち幅を縮めた取引などが相殺し、38件合計の差はわずか+0.04596R。金額差にはEquity連動ロットの影響も含む。

更新版ログ：HLによる更新候補27件、SL/TP同時変更23件、新TP到達済みの市場決済4件。新SLが約定価格以上になるため元の保護を維持したSKIPが1件。全38件でHL更新が生じるわけではない。

## 検証

- [パラメータ差](parameter_diff.json)：前回ON実行との差は両版とも `InpUseEMAFilter` のみ。
- [ソース監査](source_audit.json)：売買用・Shared・研究用ソースとEX5が前回と一致。新規コンパイルは不要で、前回の0エラー・0警告バイナリを使用。
- [audit.json](audit.json)：全39候補の確定足・最初のFib帯内終値を独立M1 OHLCで照合。HL確定時刻、SL10ポイント、TP丸め、初期R保存、15分クールタイム・単一ポジションを照合。RECOVERY_BLOCKEDなし。
- History品質98%リアルティック。3月27日に欠損6分・破棄1431分の警告。手数料・swap・feeは記録上0、Bid/Askスプレッドあり、遅延0。今回のQ1は既に見た期間でOOSではない。
- 更新拒否やfreeze待機、再起動復元、ビジュアル表示、デモフォワードは未検証。研究EAはテスター専用。

## 使用するプリセット

MT5テスターで `USDJPY_3Wave_FibHLExitResearch` を選択し、以下を読み込む。`MQL5/Profiles/Tester/` にも同名ファイルを配置済み。ソースのデフォルトは従来どおりEMA ONなので、OFFで実行する際は必ずプリセットを読み込むか `InpUseEMAFilter=false` を確認する。

- [HL更新・EMA OFF](../../../presets/USDJPY_3Wave_FibHLExit_DynamicHL_RR12_EMAOff.set)
- [SL/TP固定・EMA OFF](../../../presets/USDJPY_3Wave_FibHLExit_Static_RR12_EMAOff.set)

[comparison.csv](comparison.csv)、[monthly.csv](monthly.csv)、[全取引](trades.csv)、[同一入口の対比較](paired_trades.csv)、[更新ログ](../fib_hl_q1_noema_dynamic/TW_hl_exit_updates.csv)。再集計：`python tools/swing_structure/analyze_fib_hl_exit.py --run-prefix fib_hl_q1_noema --output fib_hl_exit_noema`。
