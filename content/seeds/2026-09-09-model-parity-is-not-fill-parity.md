# Seed: 同じ売買判定でも、PythonとMT5の取引は完全一致しない

角度: 3,967件すべての特徴量・方向判定が一致しても、仮想351取引と実注文350取引には差が出た。
原因は「モデルが違う」だけではなく、現在quoteで発注する時刻、spread判定、サーバー決済、
同時保有制限。価格を過去へ戻して一致させると、検証の意味を失う。

伝える教訓: signal parity / execution parity / generalizationを別々に検証する。
同月の利益を将来の期待値の証明として宣伝しない。この記事は戦略の販売や利益保証ではない。

根拠: [内部lesson](../../knowledge/lessons/tickshock-model-parity-versus-execution-parity.md)、
[研究結果](../../docs/research/tick_shock/technical_discovery_results.md)。
