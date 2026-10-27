# 以前の高安帯への再到達: native QA

MT5 内で新しい分類器と、実際の `Wave33ChopDiagnostic` の `Plan` / `HandleSignal` を呼び出す専用 EA を検証する。合成データによる動作確認であり、年間の損益検証ではない。

最終結果は **PASS: native 1,470 項目、独立監査 67 項目、失敗 0**。最終 batch は `run_8a9f584f`。現在の EA / module / harness ソースと harness EX5 のハッシュが native 実行時 manifest に一致することも [qa_final_verification.json](qa_final_verification.json) で確認した。

| 設定 | native 確認項目 | SIGNAL | 見送り | 注文無効の候補 | ORDER/FILL |
|---|---:|---:|---:|---:|---:|
| 見送り OFF・診断 ON | 312 | 12 | 0 | 12 | 0 |
| 見送り OFF・診断 OFF | 300 | 12 | 0 | 12 | 0 |
| 見送り ON・診断 ON | 312 | 12 | 4 | 8 | 0 |
| 見送り ON・診断 OFF | 312 | 12 | 4 | 8 | 0 |
| 見送り ON・注文 ON（全候補が阻害帯あり） | 232 | 4 | 4 | 0 | 0 |
| 不正な帯幅 -0.01 / 1.01 | 各 1 | 0 | 0 | 0 | 0 |

## 対象

- [専用ハーネス](../../../mql/Experts/tests/Wave33PriorContextHarness.mq5): 元 EA のコールバックだけを別名にして include する。取引判断は実物の関数を利用する。
- [native runner](run_native.ps1): 専用の新規 portable MT5 ディレクトリを作成。通常・デモ・実口座の既存稼働プロセスや設定を変更しない。
- テスターは XAUUSD / M1、2025-01-06 の最初の利用可能ティックを利用する。分類器・スイング形状には固定 fixture を投入。`Plan` の価格取得だけはそのテスターの実気配値を利用する。
- 2026 年の価格データは読まない。年間リプレイ・パラメータ最適化・未使用期間の成績比較は実施しない。

## native で確認すること

M15×M5 / M5×M1 と LONG / SHORT の全 4 組合せについて確認する。

1. 以前の M15/H1 高値（LONG）または安値（SHORT）と①の終点が同じ帯にあり、TP が帯の先、確定終値も注文気配値も帯を抜けていなければ `BLOCKED`。
2. 帯の端とちょうど同じ場合・端のわずか外側を、終点 / TP / 確定終値 / 気配値ごとに確認。
3. 近くに無害な水準または終値不明の水準があっても、別の既知の阻害帯を隠さない。
4. M15 と H1 の同値は H1 を代表表示に選ぶ。二つの反発とは数えない。
5. ①起点以降の水準、判断時点で未確定の水準、異なる足・異なる高安種別は不採用。
6. 未公開 pivot は利用しない。未来 known_at の確定終値、形成中の足、元高安より古い終値は利用しない。同じ cache でも既知時刻を迎えて初めて新しい終値が有効になる。
7. 固定前・再延長中の①や、終値不足は `UNAVAILABLE` として許容。①更新後は新アンカーで再計算。
8. 実 `HandleSignal` は ON の該当候補だけ `PRIOR_LEVEL_RETEST` で見送り、方向枠を解放し、重複処理でも注文しない。
9. 診断 OFF + 見送り ON でも必要な観測は有効。見送り OFF では従来の発注無効フローを維持し、予定 entry / SL / TP は変えない。
10. 送信済み・保有済みの方向枠を `FinishUnordered` で終了できない。
11. 帯幅の負値・1 超は実 `OnInit` が `INIT_PARAMETERS_INCORRECT` で拒否。
12. 実チャートオブジェクト 6 個を作成し、2 本の線の左右 ray が無効、矩形は判断時刻開始・下位足 12 本後終了であることを native property で確認。

## ユーザー画像の fixture

[recorded_fixture.json](recorded_fixture.json) は保存済みの 2024-04-03 07:05 買い候補を参照する。以前の高値 2288.35、① 2276.72→2287.99、entry 2286.14、SL 2282.83、TP 2290.12。

帯の片幅は `11.27 × 0.05 = 0.5635`。①高値は帯内、TP は上端 2288.9135 の先、当時の H1 確定終値 2285.10 は帯の下なので、新設定 ON なら `BLOCKED` となる。SHORT は同じ数値の対称変換による合成例であり、実在するショート取引の主張ではない。

これは分類器の入力を固定した再生である。元データを丸ごと新 EA に通して当該候補が再生成されるところまでの検証ではない。

## 結果ファイルと限界

- 最終 native 結果: [native_latest.json](native_latest.json)。各 run の入力・CSV・匿名化 journal・ハッシュを保存。
- 独立したイベント数 / 価格 / 時刻 / ON・OFF 同一性監査: [native_event_audit.json](native_event_audit.json)。再実行は `python audit_native.py`。
- コンパイルログ: [compile_harness.log](compile_harness.log)。0 errors / 0 warnings を必須とする。
- 注文 ON ケースも、明示的に阻害帯がある 4 候補だけを処理し、ORDER/FILL/保有/待機注文がすべてゼロであることを確認する。約定・決済性能や収益性の検証ではない。
- オブジェクトの作成・ray・時間座標は native で読み戻す。文字の重なり、色の見やすさ、tooltip 全文の目視・読み戻しは今回の native QA の対象外。

以前の表示版が通過した batch も上書きせず残し、最終版は `native_latest.json` が指す batch とする。
