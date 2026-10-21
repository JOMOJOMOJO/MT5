# 別MT5による2023年収集の準備

旧テスターの接続先Bybit-Liveに対し、別インストールの既存接続先がVantageTradingLtd-Liveであることを確認。ユーザーの再収集依頼に基づき、別portable端末で2023年のみを同じ条件・EX5で取得する。

研究runnerへ独立の出力グループを追加。深夜の日付跨ぎでもjournalを抽出できるよう、agentの直近2ログから正確なtest開始マーカーを探す方式に対応。実口座売買無効、研究EAはtester内のみ。起動後は会話を終了する。

[収集計画](../../reports/qa/three_wave/ready_alternate_broker_ml/plan.md) / [進捗](../../reports/qa/three_wave/ready_alternate_broker_ml/status.json)
