# Decision States

## promote

- PF, drawdown, sample size, execution realismが最低ラインを超えている
- 改善理由を説明できる
- 次は forward または長期検証へ進める状態

## test-next

- 壊れてはいないが、証拠が薄い
- 追加の期間、セッション、レジーム検証が必要
- 次の実験が 1-3 件に絞れている

## refactor

- ロジック自体は残す価値がある
- ただしフィルタ、cooldown、risk、session 制御を作り直す必要がある
- 同じ構造のまま微調整しても改善しにくい

## reject

- 相場前提が弱い
- spread や執行コストで edge が消える
- trade count が増えても損失構造が変わらない
- 改善理由を説明できず、最適化だけが進んでいる
