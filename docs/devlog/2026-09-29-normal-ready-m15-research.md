# 通常READYのM15環境分析

前回119候補はSkipLowerHL=trueのCHoCH入口だったため、通常READYの成績として流用しない。売買本体を変更せず、ソースをincludeするテスター専用観測EAを追加した。通常READY・M1 reversal low SL・EMA初期条件ONを明示し、既知9か月を固定検証した。

139候補から実約定70件、月5〜12件。DOWN_MID/HIGHは合算で正だが期間別の符号が逆転し、RANGE_HIGHは合算で負。M15条件採用は行わない。前回とpivot・SL・EMA等が違うため、Entry遅延単独の効果とは解釈しない。

M15全イベントの独立研究計算一致、短期の売買本体/観測版CSV一致、SL・RR・残高・source hashを監査した。終了時強制決済1件はログと残高で補完し、通常決済のみの感度集計も保存した。

検証端末が途中で自動更新されたため、2025年前半を同じbuild 6230で再実行し、5 CSV・最終残高が全て一致することを確認した。

- [結果・設定・全CSV・制限](../../reports/qa/three_wave/m15_normal_ready/summary.md)
- [再利用する教訓](../../knowledge/experiments/normal-ready-m15-20260929.md)
