# Seed: MLの取引件数を戻せても、期待値が戻るとは限らない

学習scoreの尺度と月別件数を分けて扱うと、少数取引へ縮む問題は改善できる。
しかし「月200件を保てた」と「その200件に十分なコスト後edgeがある」は別の検証。
薄いプラスはspread以外の僅かな追加コストや特定通貨への依存で消える。

記事化する場合は、単純に「機械学習はFXで無意味」と一般化せず、
比較したデータ・候補数・選択バイアス・実commission未観測を明記する。
勝率やモデル精度の自慢ではなく、頻度校正と利益の裏付けを切り分ける話にする。

根拠：[internal lesson](../../knowledge/experiments/2026-09-12-tickshock-technical-ml-discovery.md)、
[analysis readout](../../docs/research/tick_shock/technical_ml_discovery_readout_ja.md)。
