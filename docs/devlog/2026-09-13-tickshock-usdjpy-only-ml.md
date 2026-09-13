# USDJPY専用ML：母数はあるが、頻度と期待値の両立は未確認

依頼：既存detector/486features/Bid-Askラベルを維持し、USDJPYだけで
Jan–Apr選定、完全freeze後にMay→Juneを評価する。過去に見た月であるため
pristine OOSとは呼ばない。

事前仕様：[preregistration](../research/tick_shock/usdjpy_only_ml_preregistration.md)。
結果：[日本語readout](../research/tick_shock/usdjpy_only_ml_results.md)。
証跡：[分析フォルダ](../../reports/analysis/tick_shock/usdjpy_only_ml_20260912/)。
MT5：[専用batch](../../reports/backtest/batches/usdjpy_only_ml_20260912/)。

## 判断

- Jan–Apr USDJPY3,644 episodes。60設定、180fold、720モデル/policyセル。
- 全forward月200件以上でpooled EVがプラスのセルは0。
- 頻度優先の診断候補ElasticNet NET_R FULL486、2 ATR、FREQUENCY_150を凍結。
  開発880trades、−0.01969R、PF0.9178。採用候補ではない。
- May96trades +0.01840R、June44trades −0.11855R。
  合計140trades −0.02464R、PF0.9064。結果を見た再調整なし。
- 閾値名称のtarget頻度と翌月の実現頻度は異なる。母数不足ではなく、
  score分布/calibrationの月間安定性と売買期待値の両立が問題。
- 元の時計/900秒以降の最初のquoteによるTIME semanticsを維持。
  休場付近の長いholdを黙って削除しない。

## 実装・安全

既存untrackedの分析helperとprivate frozen includeを、そのまま必要依存として
再利用した。ユーザー削除済みの元TechnicalFeatures/TechnicalStudyは復元しない。
モデルheaderとtester-only wrapper/harnessのみ新規作成。通常チャートはinit拒否。
6-symbol dispatcherは収集と同じ時計を保つため維持するが、USDJPY以外は
model/注文callbackへ渡さない。shared modelとの参考比較を専用化の純粋な因果効果とは呼ばない。

MQL推論parity3,644PASS、compile0/0、学習日wiring smokePASS。
parity終了直後にterminal shutdownが未完了でrunnerが安全停止したため、
待ち時間だけを修正。モデル/EX5/configのSHA一致を確認した明示resumeを実施。
May/Juneの上書き・最適化・モデル変更は行っていない。

QAは新規unit13、既存unit18、独立算術/portfolio/causal/hash649チェック、
selected/final estimatorのdeterministic refit、圧縮入力からの再現を含む。
チェック数を独立tradeサンプル数として扱わない。

## 最終照合

MT5 May: 95 trades / +22.62 USD / PF 1.11385。June: 44 trades /
−48.47 USD / PF 0.64014。合計139 trades / −25.85 USD / PF 0.92246。
Pythonとの差はMayのNO_ENTRY_TIMEOUT 1件と実約定差。Juneは44件一致。
commission/fee/swapは当該tester dealで0を観測。一般的な無料約定は主張しない。
MT5再集計QA失敗0。TIMEの最大保有909.42秒で厳密900秒保証ではない。
月ごとの初期残高はリセット。連結DDは確定取引損益の診断で、連続口座equity DDではない。
全2,160 forward policyの独立再集計17,280 checks、全180fit再実行17,820 checks、いずれも失敗0。
モデルはholdout結果を見て変更していない。

## Plateau review

USDJPY単独でも、今回固定した高頻度の技術状態モデルは採用基準未達。
単なるtree数増加やMay/Juneへのthreshold再調整へ進まない。
別研究に進むならfrequency calibrationの検証と時計/休場リスクを分離し、
新しい事前仕様と検証期間を固定する。EAを本番候補へ昇格しない。
