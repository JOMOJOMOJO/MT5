# M5ショート鏡像の研究版

ユーザーの「同じものでショートバージョン」を実装。
[固定計画](../../reports/qa/m5_short_ichimoku_20261007/plan.md)
[ソース差分](../../reports/qa/m5_short_ichimoku_20261007/research_hooks.diff)
[設定差分](../../reports/qa/m5_short_ichimoku_20261007/input_changes.json)。

既存EvaluateRoundShortSignalのbool条件を保持し、ログだけ追加。候補記録と一回の注文queueをショートへ接続。
既存Orders/PositionManagementを変更せずSELL/Risk計算を再利用。ロングEA/Sharedは未変更。
short用パラメータはlongと同値だったため、presetの差はlong OFF、short ON、observer input追加の3つのみ。
生成ソースのデフォルトはshort有効/M5に変更。テスター専用で運用チャートへの適用は拒否する。

観測の位置基準はBid、将来決済pathはAskへ変更。R幅はSL−Bidとして正値化。
単体テスト61件合格：AskによるSL判定、即時spread逆行、両側到達除外、負gap維持、旧short bool/Ordersの一致を含む。
コンパイル0 errors/0 warnings。診断OFF/ONの2023–2024完全一致と2025–2026年9月の3runを準備。
既知期間の単独ショート研究であり、独立エッジや同時運用の成立は主張しない。
MT5起動後は待機せず終了し、完了通知後に結果確認する。
