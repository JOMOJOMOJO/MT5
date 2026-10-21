# M5 continuation ショート反転版：事前固定検証

## ユーザー依頼

直前のロングと同じ方式のショートを作り、MT5で検証する。
既存のショート判定/SELL注文経路を再利用した研究専用EA。ロング売買版・Sharedは変更しない。
これはロングの鏡像を測る実験であり、独立した新手法や運用可能性の証明とは呼ばない。

## 固定条件

- USDJPY / M5、新しい足で1回判定し、利用可能Bidで成行SELL。
- ピボット左右2本、最新2高値・2安値が両方切り下げ。
- EMA13<EMA100、直前確定終値<EMA100、EMA100は5本前以下（横ばい可）。
- 直前確定高値<最新確定ピボット高値、終値とEMA13の距離<=1.2ATR。
- **下ヒゲ>=全値幅50%、上ヒゲ<=10%。** ロングの長い上ヒゲ条件を上下反転。
- 直近24本の値幅>=1.5ATR、5ATR区画境界をまたぐ条件は同じ。
- 月〜金、サーバー時刻7:00以上22:00未満、spread<=0.20ATR。
- SL=Entry+2.2ATR、TP=Entry−SL幅×1.5。ATRはM5確定足のATR14。
- Equityリスク0.65%、同時1ポジション、1日2回、18M5本の保有上限。
- 日次3%/ピークEquity下落12%等の実行制御と、SELLのブローカー距離/口座通貨損失計算は維持。
- ショート単独。ロングとの同時運用/ポートフォリオリスクは検証しない。

## 一目と環境

M15/H1/H4のダウ分類と一目9/26/52をそのまま記録。価格位置はショートEntry Bid/約定価格基準。
一目による除外はしない。H4の雲より下の事後成績を重点確認する。
雲の上下をショート用に名前だけ反転しない。BELOWは常に価格が雲より下を意味する。
一目は既知OHLCだけで計算。現在雲は現在足qから26本前由来、転換/基準は確定足q−1。
監査OHLC保存・別言語再計算・future改変不変性を維持する。

## ショートのshadow

Entry Bid、決済はAsk。利用可能Ask tickから1分OHLCを作成し、Ask上昇でSL、下降でTPとする。
Bidを決済に使ってspreadを過小評価しない。
1分内でSL/TP両方へ達した候補はAMBIGUOUS_M1として成績から除外し、行は保存。
18本の時間決済、END_CENSORED、ギャップ、正方向TP超過診断は以前と同じ。
MFE/MAEは18本の固定窓、commission/swap/margin/発注制約をshadowに混ぜない。

## テスト順序

1. 2023–2024：診断OFFのショート単独control。
2. 2023–2024：診断ON。同じSELL Entry/SL/TP/ロット/決済/損益とraw funnelの完全一致を要求。
3. 2025–2026年9月：同じ固定設定で検証。

controlに取引がない場合は同一性の証拠が弱いため停止し、期間を勝手に延ばさない。
取引は全件SELL、SL>Entry>TP、予定損失<=risk budgetを監査。
両期間は既知期間でありOOSではない。生成tick混在を品質ラベル付きで保持する。
ロングとの比較は同じ期間・数値設定の別テストとして行い、合算運用の利益とはしない。

## 出力・採用判断

全候補/実取引CSV、一目別統計、年別/月別件数、gate理由、long_short_comparison.csv、summary.md。
全体とH4雲下の件数・平均R・PF・勝率・年別再現性を確認する。
閾値最適化やAND探索、本番採用は行わない。非同期起動後に待機せず終了する。

## ファイル

- `mql/Experts/Research/RelativeM5ShortIchimoku.mq5`
- `presets/RelativeContinuation/USDJPY_M5_short_research.set`
- `tools/quality12b/prepare_short_ichimoku.py`
- `tools/quality12b/analyze_short_ichimoku.py`
- 差分：research_hooks.diff / input_changes.json
