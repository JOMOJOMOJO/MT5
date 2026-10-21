# エントリー候補研究基盤：初回分析レビュー

2026-10-15。対象はUSDJPY M5、開発期間2024〜2025年。一目雲ブレイク、基準線反発、EMA20/50クロスの固定3手法について、Phase 2〜4の実装・動作検証・初回イベント分析を実施した。[固定設計](2026-10-14-entry-candidate-platform-design.md)に従い、候補抽出と将来経路の評価を分離した。EAの売買バックテストや収益性の確認を完了したという意味ではない。

## 結果と判断

[初回レポート](../../reports/research/entry_candidates/validated_20261014/report.md)と[全評価集計](../../reports/research/entry_candidates/validated_20261014/summary.csv)を正本とする。候補は17,409件、全50本を連続観測できる主比較母集団は16,818件。候補数はポジション数・独立試行数ではない。

| 手法 | 全候補 | 主比較候補 LONG / SHORT | H10平均ネット LONG / SHORT（pips） |
| --- | ---: | ---: | ---: |
| 雲ブレイク | 8,086 | 4,051 / 3,757 | −2.3451 / −2.1079 |
| 基準線反発 | 6,367 | 3,137 / 3,011 | −1.7583 / −2.0823 |
| EMAクロス | 2,956 | 1,427 / 1,435 | −1.8217 / −2.1390 |

事前指定のH10では6条件すべてで平均ネットが負、週block bootstrapによる95%CIの上端も0未満だった。対照との差のCIはすべて0を含み、Holm補正後p値は最小0.8811。したがって、今回の約定近似・固定コスト・H10評価で正の期待値やランダム対照を上回る根拠は得られていない。「すべての出口や環境で永久に無効」とは結論しない。

[環境別集計](../../reports/research/entry_candidates/validated_20261014/environment_summary.csv)では、2024年・2025年の各6条件もすべて平均ネットが負。EMA SHORT、雲LONG/SHORTの対照差は年によって符号が反転した。基準線SHORTの対照差は両年わずかに正だったが、ネット平均は両年負で、全期間の差にも統計的根拠がない。H10の非重複候補による感度確認も6条件すべて平均ネットが負だった。年別・環境別の値は記述的確認で、追加の採用検定ではない。

## QAと再現性

- [基盤の全テスト](../../tools/entry_research/tests/)は統計テスト9件を含めて合計49件成功。[JUnit結果](../../reports/research/entry_candidates/qa/tests_20261015.xml)を保存した。未来改変に対する過去候補の不変性、上位足の観測時刻、方向・H・コスト、OHLC同足曖昧性などを検証した。
- [抽出監査](../../reports/research/entry_candidates/validated_20261014/baseline_match_audit.csv)の31,810層で要求数・抽出数・層内ユニーク数が一致。Parquetでも各10反復の条件別件数、抽出母数、ID一意性を独立照合した。対照168,180行を独立サンプル168,180件とは扱わない。
- 全36集計行で候補数と完全観測数が一致し、欠落評価なし。H10の戦略平均・反復平均対照・差を評価Parquetから再計算し、CSVとの差は浮動小数点誤差の範囲（最大9×10⁻¹⁶）だった。
- 同一データ・設定・seedの全処理再実行は完了し、[再現性QA](../../reports/research/entry_candidates/qa/reproducibility_20261015.json)はPASS。CSV9件のうち8件はSHA256も一致。環境別CSVだけは集計の浮動小数点差があるが、絶対・相対許容値1e-12以内で一致。features/candidates/controls/summaryのParquet内容は完全一致した。
- 4時間足の全時刻・上位足利用時刻・6チャートを監査し、2026年混入や判断後の足の混入は0件。[成果物監査](../../reports/research/entry_candidates/qa/artifact_audit_20261015.json)を保存。

設定・seed・依存version・コードhash・入力manifest参照は[run manifest](../../reports/research/entry_candidates/validated_20261014/manifest.json)、再実行手順は[README](../../tools/entry_research/README.md)に保存した。

## 解釈の制約

入力は保存済みBybit-Live由来バーで、現在のXM履歴とは混ぜていない。サーバー時計とUTCの対応は未検証のため、東京・ロンドン・NY区分はunknown。コストはspread 1.5 + 往復commission 0 + slippage 0.2×2 = **仮定1.9pips**で、実測約定コストではない。主比較は全50本連続という条件付き母集団なので、週末・欠損・期間末直前の候補を除く。

OHLCだけでは同足内TP/SL順序を確定できないケースをambiguousとして分離した。完全なtick窓を入力する検証hookは実装・合成データ検証済みだが、初回分析で実tick順序や実約定を検証したわけではない。今回、新しいMT5売買テスター実行は行っていない。

環境別baselineのestimatorは`pooled_conditional_descriptive_mean`。全反復をプールした条件付き記述平均で、主検定の反復平均とは異なる。環境CSVの`min_replicate_n`、`max_replicate_n`、`represented_replicates`は**対応する対照群の診断**で、strategy行にも付く。strategyが10反復されたという意味ではない。

2026年の価格は今回の基盤で読み込んでいない。過去研究では一部が既知のため、全研究を通じて完全未閲覧OOSだったとは主張しない。

## Plateau reviewと次の制約

今回の目的である「同一条件で入口を比較する基盤」は動作し、再現性QAも通過した。3手法の収益化・EA化を目指すパラメータ調整は開始しない。H・コスト・環境条件を後から選んで勝者を作ることもしない。次はPhase 5として残り7手法を標準値・同じ抽出API・同じ因果性テストで追加する順序を維持する。

三役、MA押し目・戻り、ダウの高安ブレイク、RSI反転、Bollinger回帰、ATR拡大、Donchianは未実装。追加後の検定数は事前に定め、2026年の探索利用、ML導入、EA昇格を今回の結果から承認しない。
