# 早期SLを勝ち側と比較

2026-10-18。負けの56%が最初2本でSLという前回結果について、原因と勝ちとの違いを調べた。新規`tools/entry_research/early_loss/`に、固定8事前特徴、事後のquote距離・価格経路、共通暦4週ブロック区間を実装。旧EA・会計・候補・価格は保護した。

勝ちも52.7%が早期決着し、損失側との差の区間は0を跨いだ。費用でSL側が近くなる実行構造、ブレイク幅が早期SLで小さい関連を確認。大きな足や上位足逆行の一律除外は支持せず、回復率をSL拡大の利益と混同しない結論にした。SL後価格はエントリー原点・方向調整・終値判定と明記。

11テスト合格、独立監査で件数と機序を照合。表示上の凡例重なりを修正し、正本を`delivery/`に保存。旧検証版は保持。新フィルタ・戦略変更なし、2026不使用。

[研究レビュー](../../knowledge/experiments/2026-10-18-early-loss-review.md)、[正本レポート](../../reports/research/early_loss_20261018/delivery/report.md)、[テスト](../../reports/research/early_loss_20261018/qa/pytest.xml)、[実行手順](../../tools/entry_research/early_loss/README.md)。
