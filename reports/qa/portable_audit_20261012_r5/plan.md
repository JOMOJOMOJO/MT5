# r5：監査修正と未実行4本の継続

## 固定範囲

- 売買EA・Shared・研究MQL・売買inputを変更しない。r4の5ソースと全input JSONをバイト一致で複製。
- 期間は既知の2023-01-01〜2023-04-01。利益最適化、フィルター追加、OOS判定は行わない。
- 既存口座設定を許可済みの独立MT5へ読み込む。通常チャートの自動売買は無効、EAはテスター内のみ。
- MT5起動後は待機・ポーリングを続けずユーザーへ返す。

## 原因と修正

r4のM5 USDJPYは正常に49取引を完了し、新旧の売買・費用・候補・観測環境・履歴が一致した。
しかし監査のreason一覧に `NORMALIZED_VOLUME_EXCEEDS_RISK` がなく、3件の安全な見送りで停止した。

新監査はこのreasonについて以下を要求する。

1. 最小volumeの損失は予算内。
2. 刻みに合わせたvolumeは銘柄仕様内。
3. そのvolumeで再計算した損失は予算超過。
4. 見送りの同一銘柄・同一分にEntry dealが存在しない。

`OK` の予算超過、未知の計算失敗、非有限値は引き続き失敗とする。
「同一分にEntryなし」は今回の同期発注EAの記録に対する監査であり、一般の遅延発注まで否定する証明ではない。
最小volumeの損失から比例拡大した見積もりと再計算損失の差は確認できたが、ブローカー内部の丸め方式までは断定しない。
一段小さいvolumeへの再計算による機会回復は別の売買挙動変更なので、今回には混ぜない。

## 再利用と実行順

元データ：[r4実行](../portable_audit_20261009_r4/runs/20261012_113626_a789b4ef/)

再利用6本：harness、daily_reference、daily_legacy_clock、daily_timer、m5_USDJPY_reference、m5_USDJPY_portable。
全ファイルのSHA256と一覧をmanifestに固定し、新しい出力先へ複製した後に再監査する。過去runは書き換えない。

新規実行4本：m5_EURUSD_reference、m5_EURUSD_portable、m5_XAUUSD_reference、m5_XAUUSD_portable。
新旧ペア内で同一のMT5・口座通貨・契約仕様・観測履歴・費用・約定・候補を要求する。
6本は旧バッチ、4本は新バッチ由来として明示し、全部を同時実行したとは扱わない。

## 発進前確認

- [6本の再監査](preflight/reused_evidence/)：全件合格。
- [USDJPYリスク監査](preflight/reused_evidence/m5_USDJPY_portable/risk_audit.json)：OK49件、予算超過見送り3件、該当分の発注0件。
- [USDJPY新旧比較](preflight/reused_evidence/m5_USDJPY_portable/pair_audit.json)：全比較合格。
- [日足timer終端履歴](preflight/reused_evidence/daily_timer/final_history_clocks.json)：quote時計では13件、server終端では15件（口座残高dealを含む）。取引deal14件をCSVへ回収し、最終2決済の欠落解消を確認。
- 新規Python検査10項目合格。既存分も含む全28項目合格（[実行ログ](preflight/python-tests.log)）。PowerShell構文検査合格。
- MQLの既存コンパイル証跡はr4の5ファイルとも0 errors / 0 warnings。新runnerでも同じ5ソースをコンパイルしてから未実行4本へ進む。

全tick列の完全一致や分内で発生・復帰した契約仕様変更まで保証するものではない。日足の同期quote取得が一部に限られる制約も維持する。
利益による採用判断は今回の合格条件に含めない。
