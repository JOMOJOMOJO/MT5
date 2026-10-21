# 多銘柄の土台と上位足定義の監査・修正

ユーザーは新戦略の反復より先に、銘柄依存・ロット・spread・上位足認識を見直すよう依頼。mq5-review / research-director / systematic-ea-trader / professional-traderの視点で既存EA、研究成果、公式APIを確認した。

- [計画・発見事項・公式参照](../../reports/qa/portable_audit_20261008/plan.md)
- [日足差分](../../reports/qa/portable_audit_20261008/daily_changes.diff)
- [M5差分](../../reports/qa/portable_audit_20261008/m5_changes.diff)
- [共通計算](../../mql/Include/Research/PortableTrading.mqh)
- [上位足・volume・急変観測](../../mql/Include/Research/PortableContextDiagnostics.mqh)

日足のUSD文字列分類、固定10points、他所有position混入、単一chart時計、最低lot/リスク見送り理由の混在を研究後継版で修正。M5は既に相対距離・OrderCalcProfitを使用しており、同等計算を共通化して詳細観測を追加。
旧複数銘柄EAの最低lot切上げと固定lot fallbackはリスクを超え得るため採用しなかった。

上位足のpivot方向と終値break方向は別定義であり、既存1,666候補でも反対方向の状態を確認した。これは分類ミス件数ではない。旧分類を変更せず両方を保持する。
Roundという名前の現行M5ロングは長い上ヒゲを要求する。強い陽線追随とは異なる。volumeや急変の意味は足の形状・方向と一緒に考える必要がある。

4ソースの隔離コンパイル0 errors / 0 warnings：[preflight](../../reports/qa/portable_audit_20261008/preflight/20261008_175518_ab55be75/status.json)。Pythonのポートフォリオ照合5テスト合格。MQLハーネス18項目の実行はこれからのMT5 QA内。

9runは工学検証。M5のUSDJPY/EURUSD/XAUUSDで旧版との完全一致、日足の時計差、lot根拠、因果時刻を確認する。利益で選別しない。過去凍結版・本番EA・Shared・ユーザーのdirty変更はhashで保全。ネイティブ最適化はpassログ分離を実装する前には実行しない。

起動後はユーザー方針通り待機しない。新しい環境フィルター・RR最適化・本番採用はQA結果後に切り分ける。
