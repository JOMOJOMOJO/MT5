# Wave33: デイトレの24時間制約を先に固定する

ユーザーの希望を受け、今後の出口案は約定から24時間を上限とする。[提案と未確定事項](../../knowledge/experiments/2026-10-26-wave33-daytrade-exit-plan.md)へ保存。現EAへはまだ実装していない。

professional-trader / systematic-ea-trader / research-directorの観点から、まず全量を残して段階SLを動かす案を推奨。前回の分割＋建値の複合変更を、分割利確単独の欠陥と断定せず、固定TPなし・共通24hの据置SL対段階SLで一要因を比較する順序にした。従来TPとの優劣をこの比較だけで結論しない。

根拠は[既存の24時間内到達数](../../reports/backtest/analysis/wave33_uncapped_20261026/README.md)と[元position単位の分割比較](../../knowledge/patterns/2026-10-26-partial-exits-and-trade-counts.md)。数か月後の最大MFEを今回の出口案の根拠にしない。初期R固定・逆①利益決済維持・休場での時間決済限界・価格建値と費用込み建値を区別した。EA・テスター起動、設定やEAソース変更、新しい数値評価は行っていない。

新しい実績がないため公開seedは追加しない。既存のMFEと実行可能利益のseedを参照する。
