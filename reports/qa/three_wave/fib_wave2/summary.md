# Fib Wave2 Entry研究版（2026-09-25）

## 作成物と範囲

EA: `mql/Experts/USDJPY_3Wave_FibWave2Research.mq5` / `.ex5`。MT5ストラテジーテスター専用。

通常版v1.03を基準に、READY / Fib Wave2をinputで切り替える研究版を作成した。通常版・M5/M1認識のShared・ピボット設定・注文共通部は変更していない。[保護対象ハッシュ](protected.json)と[差分](entry_adapter.diff)を保存。固有Magic初期値260922334、研究用ジャーナル名を使用する。

- `InpFibEntryMode=0` (`ENTRY_CURRENT_READY`): 従来のHL確定→再上抜け。SLは既存`InpStopMode`に従う。
- `InpFibEntryMode=1` (`ENTRY_FIB_WAVE2`): CHoCHとWave1 Highが確定後、Fibゾーン初回到達を監視。
- `InpFibEntryMinRetracement=0.382`, `InpFibEntryMaxRetracement=0.618`: 高値からの押し割合。0 < min < max < 1。
- `InpUseEMAFilter=true`, `InpEMARequireRising=true`: 既存EMA条件を維持。

## Fib方式の時系列と価格

1. 既存Sharedが認識したM1 reversal low / CHoCH / Wave1 Highを利用。
2. Wave1 Highの確定が新しく観測されたM1足で監視開始。高値・安値とFib範囲を固定。
3. `range=Wave1High-reversalLow`、上端=`High-range*0.382`、下端=`High-range*0.618`。
4. 確定後の実際のBidが上下端を含む範囲へ初めて入ったOnTickを記録。形成中バーの最終High/Lowや、確定前の過去の接触を使わない。起動時の古いセットアップは遡って採用しない。
5. その次に受け取ったOnTickのAskで既存Place()を呼ぶ。ミリ秒時刻が同じtickでも、イベント順序が次なら次tickと扱う。到達tickでの発注は禁止。
6. 次tickで価格がゾーン外に動いていても、起点割れ・構造無効化・既存注文制約がなければ成行発注する。Askにはスプレッドがあるため、約定価格がBid基準ゾーンの外になる場合がある。
7. ゾーンを飛び越えた値動きは接触と推測しない。実際にゾーン内のBidを観測した場合にのみ到達とする。
8. EMA・保有・クールタイムなどで見送った初回到達は消費し、後から買い直さない。同一M5親波の初回到達を複数のM1候補で重複利用しない。
9. SLは`reversalLow - InpSLBufferPoints * _Point`を既存tick刻み丸めで設定。Fib方式では`InpStopMode`よりこちらを優先し、ログの`stop_mode`にも実際の基準を記録する。リスク・ロット・RR・発注/保護管理は既存経路を利用。

M5/M1構造の再評価は従来どおり新しいM1足ごと。Fib到達監視だけをtick単位で追加。確定済みM5高値突破や期限切れでSharedが部分的なM1状態を返しても、その古い状態を再利用しない。

## 検証

- [研究EAコンパイル](compile.log): **0 errors, 0 warnings**。
- [tick判定テストコンパイル](policy_compile.log): **0 errors, 0 warnings**。
- [ネイティブ判定テスト](policy.csv): **12件成功・失敗0**。上下境界、ゾーン飛び越し、同tick発注禁止、次tick、起点割れ、構造失効、重複を確認。
- 2025年1月、USDJPY M1、Model4リアルティック、RR1、EMA ON。
- [Fib方式ログ](../fib_wave2_january/tester.log): 監視38件、初回到達34件、発注15件、EMA順序で14件・上向き条件で5件見送り。
- [READY方式ログ](../fib_wave2_ready/tester.log): 12件発注。
- [独立監査](audit.json): 通常版と研究版READYの全シグナル・約定CSVが一致。Fibは確定後到達、次tick、ゾーン算式、Ask、SL/TP、Equity1%以下の計算、15分クールタイム、保護4ファイル不変を確認。
- [同構造比較CSV](paired_signals.csv): 例 1/6 Fib 01:40:01 / 157.446 / SL157.390、READY 01:53:00 / 157.478 / SL157.412（サーバー時刻）。

## プリセットと使い方

テスターで`Experts/dev/mql/Experts/USDJPY_3Wave_FibWave2Research`、USDJPY、M1、リアルティックを選択する。

- [Fib Wave2 RR1](../../../presets/USDJPY_3Wave_Research_FibWave2_RR10.set)
- [READY RR1](../../../presets/USDJPY_3Wave_Research_READY_RR10.set)
- [Fib Wave2 RR1.2](../../../presets/USDJPY_3Wave_Research_FibWave2_RR12.set)
- [READY RR1.2](../../../presets/USDJPY_3Wave_Research_READY_RR12.set)

全39入力を明示、最適化OFF。MQL5/Profiles/Testerへも配置。比較は同一期間、同一RRのペアで行う。通常版やCC版に読み込んでもFib方式にはならない。

`TW_fib_events.csv`にARM/TOUCH/DECISION/INVALIDATE、確定時刻、到達・判断tick時刻と順序、ゾーン、実際のBid/Ask、理由を保存する。`TW_signals.csv`のFib行は`state_transition_reason=FIB_WAVE2_NEXT_TICK`。互換性のため内部`ready_time`に発注判断時刻−60秒を設定するが、これはREADY足やHL確定を意味せず、HLを捏造しない。Fib行のsignal_timeは実際の判断時刻。

## 制限と採用判断

今回は機能検証。1月15回は月20回目標に不足し、収益性改善・他期間再現性・運用昇格は未検証。長期/OOS、ビジュアル画面の目視は未実施。研究版は通常チャートでの実注文を禁止している。Fib監視状態はテスト内で保持し、途中再起動からの監視再開は対象外。データ取得失敗で構造を再確認できない監視は取消し、過去に遡って再発注しない。

波の認識や注文関数を変更して入口を早めた結果を混同しないため、READY一致とFib時系列の検証を優先した。次の評価を行う場合も、固定条件で他期間の期待値・DD・頻度を比較し、今回の1月だけで閾値最適化しない。
