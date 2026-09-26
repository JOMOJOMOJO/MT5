# READY vs Fib Wave2: 2025年1〜3月バックテスト

## 結論

今回の固定条件ではFib Wave2は改善しなかった。取引数は23→26と3回増えたが、純損益は−131.01→−601.09 USD、平均損益は−0.054→−0.234R、最大Equity DDは5.07→7.03%へ悪化。通常の売買用EAへ反映する根拠は得られていない。通常版・Sharedは変更していない。

## 条件

`USDJPY_3Wave_FibWave2Research`、USDJPY/M1、2025-01-01〜2025-04-01未満、MT5 Model4、初期10000 USD、Equity1%、RR1、EMA20>50>100かつ全上向きON、M1/M5左右2本、Fib .382〜.618、クールタイム15分。プリセット差分は`InpFibEntryMode`の0/1のみ。SLは依頼どおりREADYがWave2 Low、Fibがreversal low（それぞれ10ポイント下）。これは入口だけを同一SLで比較した実験ではなく、指定された入口とSL基準の組合せの比較。

[固定計画](plan.md)・[ソースハッシュ](source_hashes.json)。最適化なし。1〜3月は以前の研究でも参照済みなので未見OOSではない。

## 全期間

| 指標 | READY | Fib Wave2 |
|---|---:|---:|
| 取引数 | 23 | 26 |
| 勝率 | 47.83% | 38.46% |
| 純損益USD | -131.01 | -601.09 |
| 1取引平均損益R | -0.0536 | -0.2336 |
| 合計R | -1.233 | -6.073 |
| PF | 0.893 | 0.627 |
| MT5最大残高DD | 435.99 USD (4.31%) | 701.34 USD (6.94%) |
| MT5最大Equity DD | 514.29 USD (5.07%) | 711.23 USD (7.03%) |

[集計CSV](comparison.csv)・[全取引CSV](trades.csv)。Rは全dealのprofit+commission+swap+feeを初期リスクで除したposition単位の値。金額は複利影響を含む実テスター値。DDはnative MT5レポートの値。

## 月別

| 月 | READY回数 / 損益USD | Fib回数 / 損益USD |
|---|---:|---:|
| 2025-01 | 12 / -5.03 | 15 / -98.37 |
| 2025-02 | 5 / -128.61 | 5 / -101.45 |
| 2025-03 | 6 / +2.63 | 6 / -401.27 |

[月別CSV](monthly.csv)。月はエントリー月で集計。どちらも全月で月20回目標に届かない。早期化による改善は今回の結果からは支持されないが、少数・1四半期の結果であらゆる期間の不成立までは結論しない。

## 実装監査と制限

[監査JSON](audit.json)。FibのWave1確定後到達、観測tickの次イベントで判断、ゾーン価格、Ask発注、SL、1%以下の想定リスク、1ポジション、15分クールタイムを確認。RECOVERY_BLOCKEDなし。通常版・Shared・共通注文コードの4保護ファイルのハッシュ不変。

ヒストリー品質は両方98%リアルティック。2025-03-27に実tick欠落・不整合による破棄/補完ログあり。当日の入出取引は両方式0件だが、構造認識などへの間接影響まで排除したという意味ではない。Model4を指定しただけで100%実tickと呼ばない。

このテスターで記録されたcommission/swap/feeは0。Bid/Askによるスプレッドは取引結果に含まれるが、別の口座手数料体系や実約定遅延は未検証。今回ExecutionDelay=0。利益改善の採用・ライブ昇格は行わない。

## 証拠

- [READYプリセット](../fib_compare_q1_ready/default.set) / [Fibプリセット](../fib_compare_q1_fib/default.set)
- [READY nativeレポート](../fib_compare_q1_ready/tw_fib_compare_q1_ready.htm) / [Fib nativeレポート](../fib_compare_q1_fib/tw_fib_compare_q1_fib.htm)
- [READYログ](../fib_compare_q1_ready/tester.log) / [Fibログ](../fib_compare_q1_fib/tester.log)
- [実装・1月の一致検証](../fib_wave2/summary.md)

再集計: `python tools/swing_structure/analyze_fib_wave2_comparison.py`。再実行は`run-three-wave-fib-wave2.ps1`でFrom=2025.01.01, To=2025.04.01, Model=4, RewardRisk=1, FibMode=0/1。独立TEMP端末のみを使用し、ユーザーの通常端末は停止しなかった。
