# 3波3波 v1.0 初回レビュー成果物

既存EAは変更せず、新規EAを実装した。目的は判断根拠の追跡であり、利益最適化・動画一致・運用昇格の判定はしていない。

**表示更新 v1.10:** 左上パネルを初期非表示にし、確定高安を破線で連結した。現在の見方と画像は [表示改訂資料](display_v2/README.md) を参照。売買判定の全イベントCSVは初版と一致する。

**最新 v1.20:** 水平線の無限延長を止め、注文ON専用設定を追加した。[最新の変更・実注文検証](finite_lines_orders/README.md) と [MT5で売買する手順](../../../docs/validation/wave33-tester-orders.md) を参照。

## 実行確認

- EAと実エンジンharnessは0 errors / 0 warnings。最終harnessは100/100成功。
- XAUUSD、2025-01-06～2025-01-18、real ticks。通常比較は1,291,229ティック。
- A: 19候補（LONG 8 / SHORT 11）、PIVOTシグナル5件。B: 59候補（33 / 26）、PIVOT 27件、TRENDLINE 26件、先着29件。
- 注文ON: Aは4約定・4決済、Bは24約定・24決済（LONG 15 / SHORT 9）。通常チャート禁止はソースガード。描画再生EAには注文コードがない。
- 61.8%超過は初期値で計測のみ。抵抗表示・SKIP・CAPの各モードを実行した。

## 描画の確認境界

**実Visual=1テストではPNG保存要求がtrueでもファイルが生成されず、直接画面キャプチャは未確認。** Windows画面読み取りも許可タイムアウト。成績グラフをEA画像として数えていない。

下表のPNGは、実CSVのイベントを同じDisplayモジュールで通常MT5チャートへ再生したもの。価格バーは実XAUUSD M1を事例の判断時刻で切った専用カスタム銘柄。後のバーは追加せず、売買・シグナルを再計算しない。テスター画面の直接キャプチャと区別する。W1暫定極値など元CSVにない履歴は復元しない。

画像確認で帯の塗り・長いラベルの重なりと、M5水平線の2点が同じ足に入る表示不具合を発見し、描画のみ修正した。線の開始時刻・価格は維持し、旧判定線は更新時刻で右延長を止めて残した。

| パターン | ID | 方向 | 候補認定 | 成立または失効の判断時刻 | 区分 | 描画再生 |
|---|---|---|---|---|---|---|
| A | W33_XAUUSD_15_5_LONG_1736161200_1 | LONG | 2025.01.06 11:15:00 | 2025.01.06 15:45:00 | WAVE1_ORIGIN_BROKEN | [PNG](drawing_review/A/W33R_85A8785F1DE7977D_0.png) |
| A | W33_XAUUSD_15_5_SHORT_1736177400_2 | SHORT | 2025.01.06 15:45:00 | 2025.01.07 01:15:00 | SIGNAL | [PNG](drawing_review/A/W33R_84A876CCA76A1C88_1.png) |
| A | W33_XAUUSD_15_5_LONG_1736188200_3 | LONG | 2025.01.06 18:45:00 | 2025.01.07 19:45:00 | TIMEOUT/NO_LOWER_REVERSAL | [PNG](drawing_review/A/W33R_87A87B852AFB6FD7_2.png) |
| A | W33_XAUUSD_15_5_LONG_1736204400_4 | LONG | 2025.01.06 23:15:00 | 2025.01.06 23:15:00 | ACTIVE_SETUP_SAME_DIRECTION | [PNG](drawing_review/A/W33R_86A879F284804A62_3.png) |
| A | W33_XAUUSD_15_5_LONG_1736320500_7 | LONG | 2025.01.08 07:30:00 | 2025.01.08 12:30:00 | SIGNAL | [PNG](drawing_review/A/W33R_81A87213D3E90839_4.png) |
| B | W33_XAUUSD_5_1_LONG_1736132100_1 | LONG | 2025.01.06 03:00:00 | 2025.01.06 04:27:00 | SIGNAL | [PNG](drawing_review/B/W33R_76AB09B57072A42D_0.png) |
| B | W33_XAUUSD_5_1_SHORT_1736140500_2 | SHORT | 2025.01.06 05:20:00 | 2025.01.06 13:20:00 | TIMEOUT/NO_LOWER_REVERSAL | [PNG](drawing_review/B/W33R_75AB0822C3DA9AA8_1.png) |
| B | W33_XAUUSD_5_1_LONG_1736158800_3 | LONG | 2025.01.06 10:25:00 | 2025.01.06 13:14:00 | SIGNAL | [PNG](drawing_review/B/W33R_74AB068F1F090887_2.png) |
| B | W33_XAUUSD_5_1_SHORT_1736163900_4 | SHORT | 2025.01.06 11:50:00 | 2025.01.06 11:50:00 | ACTIVE_SETUP_SAME_DIRECTION | [PNG](drawing_review/B/W33R_73AB04FC9C445122_3.png) |
| B | W33_XAUUSD_5_1_SHORT_1736177100_5 | SHORT | 2025.01.06 15:30:00 | 2025.01.06 17:12:00 | SIGNAL | [PNG](drawing_review/B/W33R_72AB0369CDE496C1_4.png) |

全10事例に画像実体とオブジェクト一覧があり、画像名とsetup IDを照合した。成立例のENTRY/SL/TPと、SL/TPの表示足以上の2点間隔を機械確認した。画像は記録イベントの再生確認であり、実テスター画面や動画との完全一致を証明しない。

## 詳細・原本

- [Aの各5事例・根拠・時刻一覧](20261020_134635_b2cb2b0b/a_pivot_diagnostic/review_cases.md)
- [Bの各5事例・根拠・時刻一覧](20261020_134635_b2cb2b0b/b_pivot_diagnostic/review_cases.md)
- [8本の初回実行監査](20261020_134635_b2cb2b0b/review.md)
- [100件の実harness結果](20261020_135037_fd91f301/engine_harness/harness.csv)
- [Bの実注文イベント](20261020_135037_fd91f301/b_orders_smoke/events.csv)
- [Aの実Visual=1監査（画像未生成）](20261020_135037_fd91f301/a_visual/audit.json)
- [Bの実Visual=1監査（画像未生成）](20261020_173724_075de4c4/b_visual/audit.json)
- [設定と目視照合手順](../../../docs/validation/wave33-v1-visual-review.md)

描画修正後の最終A再実行は19候補・5シグナルで監査PASS。元の全イベントCSVとSHA-256が一致した（[比較](drawing_only_regression.json)）。描画によって売買判断が変わっていないことを、この固定区間で確認した。

最終ユーザーレビュー欄: 一致 / EAの認識遅れ・過剰判定 / 動画から判断不能。動画画像未提供のため現在は未判定。成績改善へ進まず、差が出た場合は足数・価格差・知り得た時刻を説明してから修正する。
