# 通常READY固定・2024年ML診断

## 結論

**LightGBMまで実行したが、採用できる条件は確認できなかった。** 最も大きい制限は実tickデータの不足である。180候補を収集できたが、実tick品質の条件を満たす正解ラベルは82件。指定walk-forwardのうち成立したのは最後の1区間（学習52件、検証30件）だけだった。

この区間ではTreeのAUCが0.658、LightGBMが0.557、Logisticが0.411。Treeの順位づけには良い結果が出たものの、確率誤差は定数予測より大きく、複数期間での安定性は未確認。**「LightGBMで優位性が見つかった」「2024年を4foldで検証できた」とは言えない。**

M15・H1のトレンドライン位置は、Entry時点の確定高値2点・安値2点から計算し、全候補に記録した。売買EA・Shared・Entry・SL・TPは変更していない。フィルターも採用していない。

## 1. 2024年の全READYと勝敗

| 集計範囲 | 候補 | TP | SL | TP率 | 平均R | PF |
|---|---:|---:|---:|---:|---:|---:|
| MT5で観測した全件（生成tickを含む参考値） | 180 | 75 | 105 | 41.67% | -0.1208 | 0.8054 |
| 実tick開始以降・Entry〜決済の警告日重複なし | 82 | 34 | 48 | 41.46% | -0.1151 | 0.8121 |
| 正解ラベル未検証 | 98 | ※ | ※ | — | — | — |

※98件にもtester上のTP41/SL57は保存したが、実tickで確定した正解とは扱わず`target`を欠損にした。期間末未完了は今回は0件。Rは既存shadowの価格Rであり、commission/swapを含む口座純損益ではない。

固定条件はHL_ENTRY_READY、SkipLowerHL=false、EMA OFF、M1/M5ヒゲ2/2、SL=M1 reversal low−10points、TP=RR1.2、USDJPY。全READYを独立shadowで追跡し、保有ポジション・クールタイムで候補を削除していない。

月別全候補は **12 / 12 / 20 / 13 / 17 / 7 / 18 / 16 / 12 / 23 / 16 / 14件**。平均15件/月で、月20件を満たすのは3月と10月だけ。これは実行制約をかける前の件数なので、今回の固定条件のまま毎月20回を確保することはできない。

### データ品質の制約

MT5はModel=4で実行したが、journalには実tick開始が2024-06-06と記録されていた。さらに40日でabsent/discarded警告があり、6〜7月は広く生成tickへ置換されている。実tick開始前、またはEntry〜決済が警告日に重なる候補は学習対象外にした。警告のない日はjournalに基づく判定であり、別のraw tickソースで全tickを独立照合したものではない。

このため、1〜6月の有効ラベルは0件、7月は1件、8月16件、9月12件、10月23件、11月16件、12月14件となった。データ品質のために除外した98件を、単に負けや0Rとして補完していない。

[月別件数](monthly_statistics.csv) / [データ品質の図](monthly_data_coverage.png) / [journal抜粋](tick_quality_excerpt.txt)

## 2. 時間順の検証で識別できたか

| 指定fold | 学習可能件数 | 検証可能件数 | 扱い |
|---|---:|---:|---|
| Jan-Apr → May-Jun | 0 | 0 | 評価不能 |
| Jan-Jun → Jul-Aug | 0 | 17 | 評価不能 |
| Jan-Aug → Sep-Oct | 17 | 35 | 学習30件未満の固定基準でスキップ |
| Jan-Oct → Nov-Dec | 52 | 30 | 実施 |

学習52件の実際の範囲は7月31日〜10月。学習のTP率44.23%、検証のTP率36.67%。test開始前15分をembargoとし、trainの決済が境界以降ならpurgeする実装にした。今回は対象行0件だった。同じ親IDがtrain/testに重複した場合も除外する。

| モデル | ROC-AUC | PR-AUC（AP） | Balanced accuracy | Brier（小さいほど良い） |
|---|---:|---:|---:|---:|
| 学習TP率による定数予測 | 0.5000 | 0.3667 | 0.5000 | 0.2379 |
| Logistic L2 | 0.4115 | 0.3511 | 0.4330 | 0.2937 |
| Tree depth 2 | 0.6579 | 0.5870 | 0.5550 | 0.2482 |
| Tree depth 3 | 0.6579 | 0.5870 | 0.5550 | 0.2482 |
| Tree depth 4 | 0.6579 | 0.5870 | 0.5550 | 0.2482 |
| LightGBM | 0.5574 | 0.5092 | 0.5766 | 0.2344 |

PR-AUCの主表はAverage Precision。直線補間による台形面積もCSVの`pr_auc_trapezoid`へ別保存した。定数予測や少数の確率値では台形面積が楽観的になるため、主表に混ぜない。

Treeは順位づけで定数基準を上回り、LightGBMもごく弱い識別を示した。ただし検証30件、TP11件のみであり、統計的な優位性や再現性を確立するものではない。2024年は既知研究期間を含み、完全未使用OOSとは呼ばない。

## 3. どのモデルが安定したか

**安定性は判定できない。** 4区間のうち1区間しか成立していない。depth 2/3/4はmin_samples_leaf=15のため同じ木になった。これは3つの独立した成功ではない。

LightGBMのBrierは定数基準より0.0036だけ小さい。固定確率binの実TP率は単調に増えていない。

| LightGBM予測bin | n | 実TP率 | 平均R |
|---|---:|---:|---:|
| <0.35 | 7 | 28.57% | -0.3853 |
| 0.35〜0.40 | 5 | 40.00% | -0.1328 |
| 0.40〜0.45 | 4 | 50.00% | +0.0960 |
| 0.45〜0.50 | 6 | 16.67% | -0.7590 |
| 0.50〜0.55 | 5 | 40.00% | -0.1266 |
| 0.55〜0.60 | 2 | 50.00% | +0.0905 |
| >=0.60 | 1 | 100.00% | +1.1981 |

最後の1件を根拠に「0.60以上だけ売買」とすることはできない。binを動かす探索、再チューニングは行っていない。

[OOF予測](walkforward_predictions.csv)は30候補×6モデルの180行。年間180候補すべてに学習外予測が付いたという意味ではない。[確率bin](probability_bin_statistics.csv) / [calibration図](calibration.png)

## 4. 複数モデル・foldで共通して重要だった特徴

**複数foldで安定した特徴は確認不能。** `feature_stability.csv`には分母1と`INSUFFICIENT_FOLDS`を明示した。

この1foldでLightGBMのtest permutation importanceが正だった主な項目は、M1 Wave1 efficiency（AUC低下平均0.0653）、server時刻hour_sin（0.0608）、H1 up/down swing比（0.0096）、直前5分realized movement（0.0093）。他の多くは0か負だった。標準偏差も保存しており、重要度は因果関係ではない。

Treeはserver時刻hour_sinとM1 Wave1 strengthを使った。Logisticの大きい係数にはM15 break経過、break距離、hour_sinなどがあるが、モデル全体のtest AUCは0.411なので、大きい係数をそのまま良条件とは見なせない。

人間向けの木は[decision_tree_rules_by_fold.txt](decision_tree_rules_by_fold.txt)に元の単位で保存。例えばhour_sinの0.55893、M1 strengthの4.09510が出たが、**学習で得た診断用境界であり売買閾値ではない**。一つの葉はtest6件中5勝だった一方、別の「class 1」葉は11件中2勝。葉のclass表示も確かな勝ち条件ではない。

## 5. M15/H1の上位足情報には予測力があったか

今回のモデルからは裏づけられなかった。H1/M15の情報をtestでまとめて入れ替えたときのAUC低下平均は、Logisticで-0.1012、LightGBMで-0.1266。負の値は、入れ替えた方が平均AUCが上がったことを意味する。Treeはこれらを使用せず0だった。

相関する特徴、入力を入れ替えたときの非現実的な組み合わせ、小標本の影響があるので、「上位足は無意味」と断定する結果でもない。現時点では上位足特徴を追加した効果を支持できない、という範囲にとどめる。

### M15/H1のトレンドライン位置

確定高値2点を結ぶ橙線、確定安値2点を結ぶ青線をEntry時刻へ外挿した。傾き/ATR、Entryの線からの距離/ATR、上/下、アンカー候補時刻・確定時刻をCSVへ保存した。上下線が交差する場合は帯内位置を欠損にする。これは機械的な2点線であり、裁量で何度も接触を確認した線と同一ではない。

価格位置のUP/DOWN/RANGE × LOW/MID/HIGHとライン位置は独立に残した。図にはEntryより未来のローソク足を描いていない。例は勝敗を選ばず時系列indexで抽出した。

[1月例](trendline_example_000.png) / [5月例](trendline_example_060.png) / [9月例](trendline_example_120.png) / [12月例](trendline_example_179.png)

## 6. M5 Wave1の大きさより質が重要だったか

**質が大きさを上回るとは言えない。** 有効ラベル82件の記述統計は以下。

| 特徴 | TP平均 | SL平均 | 標準化平均差（TP−SL） |
|---|---:|---:|---:|
| Wave1陽線率 | 0.7342 | 0.7252 | +0.063 |
| Wave1平均close location | 0.6525 | 0.6268 | +0.311 |
| Wave1最大逆行 / formation ATR | 0.3626 | 0.4103 | -0.118 |
| Wave1値幅 / formation ATR | 5.6149 | 4.4785 | +0.323 |

終値が高値側にある度合い（close location）はTP側が高く、7〜10月と11〜12月でも平均・中央値が同方向だった。次の仮説として残せる。一方、途中逆行は11〜12月ではTP側の方が大きくなり、期間で方向が逆転した。値幅側の差も同程度なので「大きさではなく質が正解」とはまとめない。

## 7. READY直前の上側張り付きは再現したか

`window20_upper25_fraction`の平均はTP0.1912、SL0.1833、標準化平均差+0.061。大きく重なる。7〜10月の中央値はTP0.25 / SL0.15だったが、11〜12月はTP0.10 / SL0.15へ逆転した。**安定した予測力は確認できない。**

ここでの割合はM1 closeが窓range上側25%にあった割合で、tick滞在時間そのものではない。

## 8. クラスタの意味と成績差

KMeans k=2〜6をすべて実行し、成績からkを選んでいない。trainだけで補完・標準化し、testを割り当てた。

- trainの最小clusterは1〜2件。外れ値群になりやすい。
- k=3〜6のtest silhouetteは約0.005〜0.019と低い。
- seed変更のARI平均は約0.29〜0.50。初期値への安定性も高くない。
- k=2ではtest30件が一つのclusterに入り、test silhouetteは定義できない。
- 固定表示例k=3ではtestは3件/27件/0件。3件群は0勝、27件群は11勝、平均-0.139R。これを再現性のある市場状態区分とは呼べない。

117入力に対してtrain52件なので、高次元・小標本の制限が強い。良い結果が出るまで特徴やkを削り替えることは行っていない。

[クラスタ品質](cluster_quality.csv) / [割当](cluster_assignments.csv) / [成績](cluster_statistics.csv) / [特徴プロファイル](cluster_profiles.csv) / [PCA図](cluster_pca_k3.png)

## 9. 人間が理解できる次の仮説（最大3つ）

いずれも **exploratory / hypothesis only**。売買条件への採用候補ではない。

1. **M5 Wave1の終値が、各足の高値側に偏っているか。** 今回の単純比較で両区間の平均・中央値が同方向。ただし分布の重なりは大きく、数値閾値は決めない。
2. **上位足の下降波縮小・上昇波拡大が、本当に次区間でも関係するか。** H1下降波比の平均はTP側が小さかったが中央値は期間で不一致。M15上昇波拡大も期間で逆転。現状では未支持の仮説として残す。
3. **M1 Wave1の効率が高すぎる候補に、Entryまでの進行が集中していないか。** LightGBMで重要度が出たが、単純比較ではTP側の効率が低い方向だった。「一直線ほど良い」とは限らないという事後的な問い。時間帯との組み合わせや閾値は今回探索しない。

第1仮説の優先度を高める程度にとどめ、2・3を条件化しない。

## 10. 採用可否と未完了事項

**採用なし。** 4foldの再現性を評価するための実tickラベルが不足している。現ブローカーデータのまま再実行しても、2024年前半の実tick欠損は埋まらない。

次に必要なのは、同じ条件の実tickを確保できる未使用期間、または適切な履歴ソースの追加である。履歴ソースを変更する場合はAsk/spread・bar・READY候補も変わり得るため、今回の行と無条件に結合しない。期間拡張や別ブローカー採用は今回実施していない。

Tokyo/London/New Yorkのセッション判定は、過去のserver→UTCオフセットが確認できていないため未実装。server hour/dayとsin/cos、spreadは記録した。SHAPは未導入のため省略し、指定のpermutation importanceを使用。PyCaretは使用せず、trainだけで前処理する明示的なsklearn pipelineとLightGBMを直接使用した。

## 検証・再現性

- 収集EA：0 errors / 0 warnings。MT5による年間収集完了。
- 収集前の短期テスト：既存observerとsignals/shadowsが完全一致、quotes5件を照合。
- 前研究2024Q3の46候補：Entry時刻・価格・SL・TP・riskが一致。
- M15分類・position・raw・break方向・経過：MT5出力と180件一致。
- 全候補のpivot確定時刻<=Entry、元の構造アンカー価格を確認。
- 時系列5点で未来履歴を切断し、全特徴量が不変。中間点では未来OHLC改変でも不変。
- 前処理列名の警告を修正した後の再実行でOOF予測が1e-12以内で一致。モデル設定は変更していない。
- 売買EAと20ファイルの既存Shared等は前研究のhashから変更なし。
- 親IDは180件すべて別。ただし近接相場・将来価格経路の重複による依存は残る。多数特徴の比較、小標本、既知期間の制限がある。

## 出力・再実行

- [ready_2024_ml_dataset.csv](ready_2024_ml_dataset.csv)：全180候補、194特徴、元の結果、品質フラグ、学習target。
- [feature_definitions.md](feature_definitions.md)：時刻・計算式・制限。
- [walkforward_predictions.csv](walkforward_predictions.csv) / [walkforward_metrics.csv](walkforward_metrics.csv)
- [feature_stability.csv](feature_stability.csv) / [logistic_coefficients_by_fold.csv](logistic_coefficients_by_fold.csv)
- [decision_tree_rules_by_fold.txt](decision_tree_rules_by_fold.txt) / [boosting_importance_by_fold.csv](boosting_importance_by_fold.csv)
- [基本集計と比較表](tables.md) / [特徴分布図](feature_distributions.png) / [期間別の仮説比較](hypothesis_period_descriptive.csv)
- [データQA](dataset_audit.json) / [最終QA](final_audit.json) / [固定プロトコル](analysis_protocol.md) / [バージョン](requirements.txt)

保存済みMT5データからの再生成は以下。MT5を起動する処理は含まない。

```powershell
python tools/swing_structure/build_ready_2024_ml_dataset.py
python tools/swing_structure/analyze_ready_2024_ml.py
python tools/swing_structure/report_ready_2024_ml.py
```
