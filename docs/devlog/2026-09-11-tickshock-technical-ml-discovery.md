# Tick-Shock Technical ML Discovery（分析のみ）

## 依頼と境界

1～4月の486特徴量を再利用し、月200取引以上・コスト後正EVを目的に、
モデル・予測対象・頻度調整・RR1の5距離を時系列比較する。
EA化／MT5実行は今回の範囲外。detector・MQL・既存fixtureは変更しない。
5～6月は以前に観測済みなので、候補が残った場合の再評価も未使用OOSと呼ばない。

## 手順と判断

- [事前仕様](../research/tick_shock/technical_ml_discovery_preregistration.md)を新規fit前に保存。
- Research Director、Statistical Edge Researchの手順で評価条件を先に固定。
  新規MT5収集はせず、ハッシュが一致した月次Technical CSVを再利用。
- 独立入力監査：11,230 episodes、486 features、41 missing cells、36欠損episode、
  10,481 monthly-prefixed market clusters。38の絶対単位feature除外版は448 features。
- 独立設計監査により、学習prefix末尾25%をchronological calibrationへ分離。
  同じモデルを翌月まで固定し、calibration後に再学習してscore尺度を変えない。
- 学習fit内percentile／件数調整も比較するが、in-sample calibrationと明記。
  33分位点等の最大件数は「試行threshold内の最大」であり、理論上のcapacityではない。
- 独立人工テスト18件PASS後に540 fold configurationsの実行を開始。
  最初の人工fixtureで結果CSVにscore列を含めたschema誤りがあったため、
  fixture構築だけを訂正。数値expected・productionは変更していない。

## 実行と再開

```powershell
python tools/tick_shock/test_technical_ml_discovery.py
python tools/tick_shock/technical_ml_discovery.py --prepare-only
python -u tools/tick_shock/technical_ml_discovery.py --resume --workers 3
```

実行先：`reports/analysis/tick_shock/technical_ml_discovery_20260911/`。
`tasks/`に完了済み単位を保存し、source/input SHA一致時だけ`--resume`できる。
`progress.json`と`training.log`が途中状態を示す。完了は`selection.json`、
独立QA、解釈資料を合わせて判断する。RUNNINGだけを完了扱いしない。

## 保持する制約

Bid/Ask含有のgross Rに追加0.2 pipを控除するstressであり、実commission観測ではない。
旧scenario pool警告とgenerated fallbackは消さない。時間決済は900秒以降の実quoteで、
正確な900秒以内を保証しない。既存無関係変更・ユーザー削除includeを保持した。

## 完了結果（2026-09-12）

540 fold構成／3,240 policyを完走。各月200件以上は1,996、合計プラスは3、
各月プラスは0。合計EV上位はRandom Forestのnet R直接回帰、TP=SL=1ATR、
844取引、追加0.2pip後+0.008234R/取引、PF1.0198。2月-0.05564R/取引で、
AUDUSDを除くと合計マイナス。安定性重視のExtra Treesは1,032取引で-0.001992R。
プラス3設定も隠さず開示したが、事前ゲート未達のため5～6月へ進めなかった。

人工18テスト、独立会計74チェック、12構成の実再学習792比較、解釈経路6比較、
SHAP加法性6比較がPASS。source／fixture／input SHAの前後確認も全件一致。
540構成のwall runtimeは約864.6秒（独立検証・解釈時間は別）。EA・MT5実行なし。

完了：`reports/analysis/tick_shock/technical_ml_discovery_20260911/completion.json`。
[日本語説明](../research/tick_shock/technical_ml_discovery_readout_ja.md)と
[詳細資料](../research/tick_shock/technical_ml_discovery_results.md)を参照。
今回の判断：[再利用可能な知見](../../knowledge/experiments/2026-09-12-tickshock-technical-ml-discovery.md)。
