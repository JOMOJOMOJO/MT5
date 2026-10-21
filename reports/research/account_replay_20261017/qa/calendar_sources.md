# 休場・時計・履歴価格の根拠

2026-10-17。価格は旧runと同じBybit-Liveの保存済み2024–2025データ（warmupを含む）。各ParquetのSHAを検証し、ギャップ内のM1実在行数を監査した。M1にも価格がない区間へ足を生成しない。

採用する週末ルールはsource clockの土曜00:00〜月曜00:00の正確な48時間に限定した経験的proxy。ブローカーの過去取引カレンダー・夏時間を独立検証済みとはしない。閉場前後に余分な空白がある場合はunknownのまま。クリスマス/元日の24時間空白は専用の理由を表示するが、歴史的休場表が未確認なので自動承認しない。

公式の[MT5 API仕様](https://www.mql5.com/en/docs/python_metatrader5/mt5copyratesrange_py)はUTC日時を要求する。これは返却された履歴とサーバー時計の歴史的一致を保証する独立証拠ではない。[Bybitの現行FAQ](https://www.bybit.com/en/help-center/article/FAQ-CFD)と[仕様ページ](https://www.bybit.com/en/help-center/article/Contracts-Available-on-MT5-and-Specifications)も調査したが、今回必要な2024–2025年の休場表と実swap履歴は確認できなかった。現行仕様をそのまま歴史へ適用しない。

`gap_audit.csv` の空白は観測上の事実であり、価格配信なし・無tick・サーバー欠損などの原因まで断定していない。`m1_rows_in_gap=0` だけで正常休場とは判定しない。
