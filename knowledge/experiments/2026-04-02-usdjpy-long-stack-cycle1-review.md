# USDJPY Long Stack Cycle 1

## 目的

- `quality12b` の品質を崩さずに、`EMA continuation sidecar` を重ねて回数を増やせるかを actual MT5 で確認した。

## 候補

- `quality12b + london-loose`
  - train `+2097.43 / PF 1.16 / 128 trades / DD 17.49%`
  - OOS `+846.45 / PF 1.81 / 19 trades / DD 2.59%`
- `quality12b + london-quality`
  - train `+1237.09 / PF 1.11 / 110 trades / DD 15.60%`
  - OOS `+1022.12 / PF 2.63 / 16 trades / DD 2.52%`
- `strict + london-loose`
  - train `+622.02 / PF 1.05 / 150 trades / DD 25.33%`
  - OOS `+903.26 / PF 1.79 / 19 trades / DD 3.06%`

## 判断

- 回数は増えたが、どの stack も long-window actual PF が `1.30` を超えなかった。
- repo の live gate では `PF 1.16 / 1.11 / 1.05` は昇格不可。
- `quality12b` 単体の train `PF 1.46` を壊してまで stack へ進む価値はない。

## 結論

- `usdjpy_20260402_long_stack` は `research only`。
- `quality12b` はそのまま `quality-first secondary live-track candidate` として扱う。
- 次の live-track は stack ではなく `quality12b_guarded` の demo-forward proving に進める。
