# Wave33 v1.85: 部分利確・建値SLの年間比較

**完了。年間4条件の独立照合23,112項目PASS。** [最終比較表・グラフ・実動作・制約](FINAL_REVIEW.md)を参照。

ユーザー指定の新出口を、既存の2020年通年で固定比較する。[事前計画](PLAN.md) / [隔離実行ランナー](launch.ps1)。A=M15×M5とB=M5×M1について、新機能OFF/ONの4条件。その他の入力は固定し、最適化しない。旧v1.80年間結果は比較対照として流用せず、現行EAでOFFを取り直す。

最終QA後に `deployment.json` を保存してハッシュを固定するまで `-Execute` は拒否する。通常のMT5を止めず、新しいportable runtimeにコピーして実行する。`scripts/backtest.ps1` はインストール済み端末群の共通設定まで書くため今回は呼ばず、既存の専用QAランナーの隔離起動方法を使う。

[最終凍結物の固定短期smoke](smoke/20261026_095845_982f2480/analysis/README.md)は2020.01.01〜01.11、全4条件642項目PASS。Aは各1positionでTP1未到達、B ONは9position中4positionで半分利確・建値SLの確定を観測した。表示修正前の[初回smoke](smoke/20261026_095010_81dbba62/analysis/README.md)と取引結果は一致。短い区間の損益で設定を選ばず、同じ凍結物で年間を実行した。

[今回の年間status](20261026_100045_50909ab6/status.json) / [固定入力と実行物](20261026_100045_50909ab6/provenance.json) / [読取専用の実行処理監査](execution_source_review.json)。独立監査用スクリプト・依存parser・固定計画も各batchのmethod/へ保存する。

```
powershell -NoProfile -ExecutionPolicy Bypass -File reports/backtest/runs/wave33_v185_2020/launch.ps1
```

このコマンドは4条件を表示するだけ。`-Execute` を付けて実行し、日時付きサブフォルダーに保存する。帳票・全候補・足・部分決済CSV・raw deal・journalを取得した後に、position単位で利益/損失/コスト/リスクを照合する。

要求モデルはリアルティックに基づく全ティック（Model4）だが、事前キャッシュに2020年実ティックがない。生成ティック代替と実際のデータカバー率を終了後に明記する。これは未使用期間の有効性やlive運用承認ではない。
