# 未使用swap仕様の差で止まった研究を継続

履歴期間修正r2の2025年USDJPYは合格したが、EURUSD短期referenceが旧runとの仕様差で停止。
売りswapのみ1.71→1.70で、36件の買い取引・72約定・cash・risk/funnelは完全一致していた。
過去環境の完全一致と、観測された売買結果の一致を混同していた監査設計を修正した。

[判定基準と証拠・再実行計画](../../reports/qa/wick_rebreak_20261014_r3/plan.md)

MQL/売買条件は変更せず、過去swap差の記録・影響検証をPython監査へ追加した。
現行reference/A/Bの環境一致は維持する。ロット・spread・約定や損益などの差を受け入れるものではない。
旧失敗証拠は保持し、4本の完結済みQAのみ再監査して再利用、残り30本を新規実行する。
Python34件と保存済み5runの再監査に合格。3ソース全てコンパイル0 errors / 0 warnings。
コンパイル対象、最終凍結source、r2のMQL sourceはSHA256一致。
[コンパイル証拠](../../reports/qa/wick_rebreak_20261014_r3/preflight/20261014_094236_a38c1d8b/)
利益による条件採用はまだ行わない。
