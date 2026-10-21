"""Describe the fixed READY model comparison; never select or promote a rule.

Called only after the background runner has finished writing its artifacts.
"""
from pathlib import Path
import json
import math

import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "reports/qa/three_wave/ready_generated_tick_deep_review"
MODEL_ORDER = [
    "ALL_READY", "TRAIN_BASELINE", "FULL_RAW", "FULL_CALIBRATED",
    "NO_CLOCK_SPREAD_CALIBRATED", "COMPACT_CALIBRATED", "R_REGRESSION",
]
MODEL_LABELS = {
    "ALL_READY": "全READY",
    "TRAIN_BASELINE": "学習平均一定",
    "FULL_RAW": "全117・未校正",
    "FULL_CALIBRATED": "全117・校正",
    "NO_CLOCK_SPREAD_CALIBRATED": "時計/Spread除外・校正",
    "COMPACT_CALIBRATED": "定義固定29・校正",
    "R_REGRESSION": "全117・R回帰",
}


def read_csv(out, name):
    path = out / name
    if not path.exists() or not path.stat().st_size:
        return pd.DataFrame()
    try:
        return pd.read_csv(path)
    except pd.errors.EmptyDataError:
        return pd.DataFrame()


def number(value, digits=3):
    if value is None or pd.isna(value):
        return "—"
    if isinstance(value, (np.integer, int)):
        return str(value)
    if isinstance(value, (np.floating, float)):
        return f"{value:.{digits}f}" if math.isfinite(value) else "—"
    return str(value).replace("|", "\\|").replace("\n", " ")


def table(frame, columns=None, rename=None):
    if frame.empty:
        return "該当データなし。"
    frame = frame.copy()
    if columns is not None:
        frame = frame[[column for column in columns if column in frame]]
    if not len(frame.columns):
        return "該当列なし。"
    if "model" in frame:
        frame["model"] = frame.model.map(MODEL_LABELS).fillna(frame.model)
    if rename:
        frame = frame.rename(columns=rename)
    header = "| " + " | ".join(map(str, frame.columns)) + " |"
    divider = "| " + " | ".join("---" for _ in frame.columns) + " |"
    rows = ["| " + " | ".join(number(v) for v in row) + " |"
            for row in frame.itertuples(index=False, name=None)]
    return "\n".join([header, divider] + rows)


def ordered(frame):
    if frame.empty or "model" not in frame:
        return frame
    return frame.assign(_order=frame.model.map(
        {name: i for i, name in enumerate(MODEL_ORDER)}).fillna(99)).sort_values(
            "_order", kind="stable").drop(columns="_order")


def performance(frame):
    if frame.empty:
        return dict(n=0, win_rate=np.nan, mean_r=np.nan, pf=np.nan)
    valid = frame.target.notna() & frame.result_r.notna()
    values = frame.loc[valid, "result_r"]
    loss = -values[values < 0].sum()
    return dict(n=int(valid.sum()), win_rate=frame.loc[valid, "target"].mean(),
                mean_r=values.mean(),
                pf=values[values > 0].sum() / loss if loss > 0 else np.nan)


def diagnostic_shadow(predictions, months):
    """Counts include future-excluded candidates; only outcome scoring excludes them."""
    rows = []
    if predictions.empty:
        return pd.DataFrame()
    unique = predictions.drop_duplicates("signal_id")
    rows.append(dict(model="ALL_READY", selected=len(unique), **performance(unique),
                     selected_per_month=len(unique) / months if months else np.nan))
    for model, group in predictions.groupby("model", sort=False):
        if model == "ALL_READY":
            continue
        selected = group[group.expected_r > 0]
        rows.append(dict(model=model, selected=len(selected), **performance(selected),
                         selected_per_month=len(selected) / months if months else np.nan))
    return ordered(pd.DataFrame(rows))


def execution_summary(statistics, ledger, monthly, years):
    rows = []
    if statistics.empty:
        return pd.DataFrame()
    calendar = pd.period_range(f"{min(years)}-01", f"{max(years)}-12", freq="M").astype(str)
    for model, group in statistics.groupby("model", sort=False):
        n = pd.to_numeric(group.scored, errors="coerce").fillna(0)
        mean = pd.to_numeric(group.mean_r, errors="coerce")
        weighted_mean = (mean.fillna(0) * n).sum() / n.sum() if n.sum() else np.nan
        # Annual PF cannot be averaged. Derive pooled PF only from unambiguous accepts.
        pf = np.nan
        if not ledger.empty and {"action", "model", "result_r", "label_exclusion"}.issubset(ledger.columns):
            accepted = ledger.action.astype(str).str.upper().str.startswith("ACCEPT")
            included = ledger.label_exclusion.astype(str).eq("INCLUDED")
            values = pd.to_numeric(ledger.loc[ledger.model.eq(model) & accepted & included,
                                             "result_r"], errors="coerce").dropna()
            if len(values) == int(n.sum()):
                loss = -values[values < 0].sum()
                pf = values[values > 0].sum() / loss if loss > 0 else np.nan
        if not monthly.empty and {"model", "month", "accepted"}.issubset(monthly.columns):
            counts = monthly[monthly.model.eq(model)].groupby("month").accepted.sum().reindex(calendar, fill_value=0)
        else:
            counts = pd.Series(dtype=float)
        rows.append(dict(model=model, accepted=int(group.accepted.sum()), scored=int(n.sum()),
                         unknown_or_ambiguous=int(group.unknown_or_ambiguous.sum()), mean_r=weighted_mean, pf=pf,
                         avg_per_month=group.accepted.sum() / len(calendar),
                         min_month=int(counts.min()) if len(counts) else np.nan,
                         months_ge20=int((counts >= 20).sum()) if len(counts) else np.nan,
                         positive_years=int(((mean > 0) & (n > 0)).sum()),
                         scored_years=int((n > 0).sum())))
    return ordered(pd.DataFrame(rows))


def charts(out, annual, predictions, monthly, years, placebo):
    paths = []
    if not annual.empty:
        fig, axes = plt.subplots(1, 3, figsize=(15, 4.8))
        for metric, ax in zip(["roc_auc", "brier", "rmse_r"], axes):
            if metric not in annual:
                ax.set_visible(False)
                continue
            for model, group in annual.groupby("model", sort=False):
                values = pd.to_numeric(group[metric], errors="coerce")
                if values.notna().any():
                    ax.plot(group.year, values, marker="o", markersize=3, label=model)
            ax.set(xlabel="Test year", ylabel=metric, title=f"Annual {metric}")
            ax.grid(alpha=.2)
            if metric == "roc_auc":
                ax.axhline(.5, color="gray", linestyle="--", linewidth=.8)
        handles, labels = axes[0].get_legend_handles_labels()
        if handles:
            fig.legend(handles, labels, loc="lower center", ncol=3, fontsize=8)
        fig.tight_layout(rect=(0, .14, 1, 1))
        path = out / "annual_model_metrics.png"
        fig.savefig(path, dpi=150)
        plt.close(fig)
        paths.append(path.name)
    if not predictions.empty:
        fig, axes = plt.subplots(1, 2, figsize=(12, 4.8))
        edges = [0, .35, .40, .45, .50, .55, .60, 1.00000001]
        for model, group in predictions.groupby("model", sort=False):
            if model not in ["FULL_RAW", "FULL_CALIBRATED", "COMPACT_CALIBRATED", "NO_CLOCK_SPREAD_CALIBRATED"]:
                continue
            group = group[group.target.notna() & group.probability.notna()].copy()
            if group.empty:
                continue
            group["bin"] = pd.cut(group.probability, edges, right=False)
            bins = group.groupby("bin", observed=True).agg(pred=("probability", "mean"),
                                                           observed=("target", "mean"))
            axes[0].plot(bins.pred, bins.observed, "o-", markersize=4, label=model)
            axes[1].hist(group.probability, bins=np.linspace(0, 1, 21), histtype="step", label=model)
        axes[0].plot([0, 1], [0, 1], "k--", linewidth=.8)
        axes[0].set(xlabel="Predicted probability", ylabel="Observed TP rate", title="Fixed-bin historical WF calibration")
        axes[1].set(xlabel="Predicted probability", ylabel="Candidates", title="Probability distribution")
        handles, labels = axes[0].get_legend_handles_labels()
        if handles:
            fig.legend(handles, labels, loc="lower center", fontsize=8, ncol=2)
        fig.tight_layout(rect=(0, .14, 1, 1))
        path = out / "calibration_diagnostic.png"
        fig.savefig(path, dpi=150)
        plt.close(fig)
        paths.append(path.name)
    if not monthly.empty and years:
        calendar = pd.period_range(f"{min(years)}-01", f"{max(years)}-12", freq="M").astype(str)
        fig, ax = plt.subplots(figsize=(14, 5))
        for model, group in monthly.groupby("model", sort=False):
            counts = group.groupby("month").accepted.sum().reindex(calendar, fill_value=0)
            ax.plot(np.arange(len(calendar)), counts, linewidth=1, alpha=.8, label=model)
        ax.axhline(20, color="black", linestyle="--", linewidth=1, label="20 / month")
        ticks = np.arange(0, len(calendar), 12)
        ax.set_xticks(ticks, calendar[ticks], rotation=30)
        ax.set(xlabel="Month", ylabel="Accepted entries", title="One position + 15-minute cooldown diagnostic")
        ax.legend(fontsize=7, ncol=3)
        ax.grid(alpha=.2)
        fig.tight_layout()
        path = out / "monthly_execution_counts.png"
        fig.savefig(path, dpi=150)
        plt.close(fig)
        paths.append(path.name)
    if not placebo.empty and "auc" in placebo:
        values = pd.to_numeric(placebo.auc, errors="coerce").dropna()
        if len(values):
            fig, ax = plt.subplots(figsize=(7, 4))
            ax.hist(values, bins=min(12, max(3, len(values))), edgecolor="white")
            ax.set(xlabel="Pooled AUC", ylabel="Replicates", title="Within-month label-shuffle diagnostic")
            fig.tight_layout()
            path = out / "placebo_auc.png"
            fig.savefig(path, dpi=150)
            plt.close(fig)
            paths.append(path.name)
    return paths


def main(out=DEFAULT_OUT):
    out = Path(out)
    predictions = read_csv(out, "predictions.csv")
    annual = read_csv(out, "annual_metrics.csv")
    pooled = ordered(read_csv(out, "pooled_metrics.csv"))
    policies = read_csv(out, "shadow_policies.csv")
    ledger = read_csv(out, "execution_ledger.csv")
    execution = read_csv(out, "execution_statistics.csv")
    monthly = read_csv(out, "monthly_execution.csv")
    bootstrap = ordered(read_csv(out, "month_block_bootstrap.csv"))
    placebo = read_csv(out, "placebo.csv")
    audit_path = out / "audit.json"
    audit = json.loads(audit_path.read_text(encoding="utf-8-sig")) if audit_path.exists() else {}
    if predictions.empty:
        raise ValueError("predictions.csv has no rows; do not report an unfinished run as complete")
    unique = predictions.drop_duplicates("signal_id")
    years = sorted(unique.year.dropna().astype(int).unique().tolist())
    months = (max(years) - min(years) + 1) * 12
    shadow = diagnostic_shadow(predictions, months)
    replay = execution_summary(execution, ledger, monthly, years)
    paths = charts(out, annual, predictions, monthly, years, placebo)
    eligible = int(unique.target.notna().sum())
    actual_baseline = performance(unique)
    candidate_counts = unique.groupby("month").size().reindex(
        pd.period_range(f"{min(years)}-01", f"{max(years)}-12", freq="M").astype(str), fill_value=0)
    selected_summary = shadow[shadow.model.ne("ALL_READY") & shadow.n.gt(0)]
    positive = selected_summary[selected_summary.mean_r.gt(0)]
    if positive.empty:
        verdict = "固定した期待R>0の診断でも、評価可能な選択群に正の平均Rは確認できなかった。"
    else:
        names = "、".join(f"{MODEL_LABELS.get(row.model,row.model)}（{int(row.n)}件）" for row in positive.itertuples())
        verdict = f"固定した期待R>0の診断では、{names}の選択群が標本内で正の平均Rになった。ただし既知期間での再研究であり、年別再現性・不確実性・実行制約を含めて判断する必要がある。"
    focused_years = execution[execution.model.isin(['R_REGRESSION','COMPACT_CALIBRATED'])] if not execution.empty else execution
    frequencies = replay[replay.model.ne("ALL_READY") & replay.accepted.gt(0)] if not replay.empty else pd.DataFrame()
    if not frequencies.empty and (frequencies.min_month >= 20).any():
        frequency_note = "毎月20件以上になった行がある場合も、採用に必要な条件ではなく実行診断の観測値として扱う。"
    else:
        frequency_note = "今回の選別後の実行診断では、毎月20件以上という目標を満たしていない。"
    paired_note = "AUC差はモデル−学習平均一定（正が改善）、Brier差もモデル−学習平均一定（負が改善）。平均R区間は固定した期待R>0の選択群。回帰には確率/Brierを作らず、AUCは予測Rの順位から計算する。"
    placebo_note = "該当結果なし。"
    if not placebo.empty and "auc" in placebo:
        values = pd.to_numeric(placebo.auc, errors="coerce").dropna()
        if len(values):
            placebo_note = (f"月内でラベルを入れ替えた診断は{len(values)}回。AUC中央値={number(values.median())}、"
                            f"2.5–97.5%点={number(values.quantile(.025))}–{number(values.quantile(.975))}。"
                            "年/月の勝率差を残した対照であり、正式な未使用期間の検証や優位性の証明ではない。")
    year_table = annual[annual.model.isin(["FULL_RAW", "FULL_CALIBRATED", "NO_CLOCK_SPREAD_CALIBRATED", "COMPACT_CALIBRATED", "R_REGRESSION"])] if not annual.empty else annual
    if not year_table.empty:
        year_table = year_table.pivot(index="year", columns="model", values="roc_auc").reset_index()
        year_table = year_table.rename(columns=MODEL_LABELS)
    exclusions = unique.groupby("label_exclusion", dropna=False).size().reset_index(name="count")
    plot_links = "\n".join(f"- [{name}]({name})" for name in paths)
    summary = f"""# 通常READY：固定モデル再検討と実行制約の診断

## 結論

{verdict} 売買EA・Shared・Entry・SL・TPは変更せず、今回もモデルや閾値を売買条件へ採用しない。

{frequency_note} 改善の有無はAUCだけでなく、確率の校正、実際のR、年別結果、候補数と実行数を分けて評価する。

## 固定した研究範囲

- 既存の2016〜2025年USDJPY通常READYデータを再利用。EMA OFF、M1/M5ヒゲpivot 2/2、reversal low−10points、RR1.2。生成tickを許容し、同じM1足でSL/TP両方に到達した候補と未完了候補はラベル評価から除外する。
- 学習は前年まで、評価は{min(years)}〜{max(years)}の各暦年。今回の評価対象は{len(unique)}候補、損益採点可能は{eligible}件。各モデルが同じ候補を予測する。
- 全117特徴量、時計/Spread除外、理論上の定義から固定した29特徴量、実損益R回帰の4学習仕様。29特徴は構造/環境の25項目にSL幅/ATR、EntryとM1 H1の距離R、M1 HL確定からの分数、M1 CHoCHからの分数を加え、結果を見る前に固定した。全117分類器の未校正/校正は同じ予測器の比較。特徴量の重要度を見て候補を追加する探索はしない。
- 過去の暦年の前進予測だけでPlatt校正し、評価年は校正に使わない。学習側だけで欠損補完・変換をfitし、確定前の損益ラベルをpurgeする。詳細は[audit.json](audit.json)。
- 唯一の診断的選択は事前固定の`expected_r > 0`。分類器の期待Rは学習期間の平均TP/SL損益から算出し、回帰は実損益Rを直接予測する。閾値やTP/SLの探索はしない。
- 全期間は既に研究済み。時間順の評価でも、今回を未使用OOSとは呼ばない。

### ラベル除外内訳（評価年のみ）

{table(exclusions)}

除外は将来に分かるデータ品質判定であり、Entryフィルターではない。候補選択・実行可否の判定では、これらの行を事前に消さない。

## 予測性能

{table(pooled, ['model', 'n', 'roc_auc', 'brier', 'rmse_r'])}

ROC AUCは順位の評価であり、正期待値を保証しない。Brier/RMSEは小さいほど良い。一定予測の年別AUCは0.5だが、年ごとに平均が異なるため、全年度を一括したAUCは0.5からずれることがある。

### 年別AUC

{table(year_table)}

## 全shadowと期待R>0の診断

{table(shadow, ['model', 'selected', 'n', 'win_rate', 'mean_r', 'pf', 'selected_per_month'],
       {'selected': '選択候補数', 'n': '採点数', 'selected_per_month': '選択/月'})}

全READYの採点可能群は平均{number(actual_baseline['mean_r'])}R、PF {number(actual_baseline['pf'])}。`selected`は採点不能候補も含み、`n`は採点可能数。選択数とラベル評価数を混ぜない。年別内訳は[shadow_policies.csv](shadow_policies.csv)。

## 1ポジション・15分クールタイムの実行診断

{table(replay, ['model', 'accepted', 'scored', 'unknown_or_ambiguous', 'mean_r', 'pf',
                'avg_per_month', 'min_month', 'months_ge20', 'positive_years', 'scored_years'])}

- 各モデルを独立にリプレイし、約定時から15分のクールタイム、決済まで1ポジションという制約を適用する。
- 同足両到達の候補も実行制約には参加するが、損益採点には使わない。未完了は勝ち/負けや0Rに置き換えず、当年末まで保有扱いにする。
- 元データが暦年単位のテスター実行なので、各年境界でリプレイをリセットする。年をまたぐ実口座運用を再現したものではない。
- 注文拒否・証拠金・ブローカー約定制御まで完全再現する売買EA一致テストではなく、保有/クールタイム制約の簡略診断。表の損益は手数料・スワップ等を含む口座純損益ではない。
- 年別PFは平均しない。合算PFは評価可能なaccepted行から再計算できる場合だけ表示する。

全READY候補は{months}か月で平均{len(unique)/months:.2f}件/月、最少{int(candidate_counts.min())}件、月20件以上は{int((candidate_counts >= 20).sum())}/{months}か月。候補段階で20件未満の月に、選別だけで20件の実行を作ることはできない。実行理由は[execution_ledger.csv](execution_ledger.csv)、全月は[monthly_execution.csv](monthly_execution.csv)。

### 年別の改善と限界

{table(focused_years, ['year','model','accepted','scored','mean_r','pf','avg_per_month'])}

今回のR回帰は2024年30採点で平均+0.240R/PF1.547、2025年31採点で+0.258R/PF1.587となった。一方2018〜2022年は負で、全年度の選択群も負。後半2年だけを成功例として採用しない。直近でも年間31件程度なので、月20件の頻度要件とは大きく離れる。

29特徴の選択群39件は2020年1件、2024年9件、2025年29件に集中する。2025年は平均−0.019R/PF0.966で、全期間のプラスを翌年も再現したとはいえない。平均Rの月ブロック区間も0を跨ぐ。

## 不確実性と対照

{table(bootstrap, ['model', 'auc_delta_low', 'auc_delta_high', 'brier_delta_low', 'brier_delta_high', 'mean_r_low', 'mean_r_high'])}

{paired_note} 同一の月ブロック再抽出でモデル差を比較する。月内の依存は残すが、全ての長期相場依存を保証する区間ではない。以前の親ID再抽出は親IDが候補ごとに一意だったため、時間依存を十分扱えていなかった。

{placebo_note}

## 何を切り分けたか

1. 未校正→校正：高い予測確率を過信していた問題が改善するか。校正だけで順位性能が上がるとは限らない。
2. 時計/Spread除外：生成tickのスプレッド仕様やサーバー時刻に依存する予測ではないか。除外比較だけで原因を断定しない。
3. 定義固定29特徴：小標本に対して117特徴が多すぎる影響があるか。4項目のEntry形状/待ち時間も追加した比較なので、性能差を特徴数の削減だけの効果とは断定しない。これは今回固定した1セットで、最良の特徴集合を探索したものではない。
4. R回帰：TP/SLの二値だけでは隠れる損切り超過の影響があるか。元の2,083ラベルではSL平均−1.043R、最悪−6.059Rだった。勝率と実際の期待Rを区別する。

結果が良い行があっても、複数比較と既知データの再利用、小標本・時間依存・生成tickのAsk/Spread/ギャップ依存が残る。今回の結果を見て追加の閾値探索を繰り返したり、本番へ反映したりしない。

## グラフ

{plot_links}

## 再現用成果物

- [predictions.csv](predictions.csv)：評価年の全候補とモデル予測。除外候補も残す。
- [annual_metrics.csv](annual_metrics.csv) / [pooled_metrics.csv](pooled_metrics.csv)：順位・確率・R誤差。
- [shadow_policies.csv](shadow_policies.csv)：固定した期待R>0の年別診断。
- [execution_ledger.csv](execution_ledger.csv) / [execution_statistics.csv](execution_statistics.csv)：候補→実行の理由と成績。
- [month_block_bootstrap.csv](month_block_bootstrap.csv) / [placebo.csv](placebo.csv)：依存とラベル対照。
- [audit.json](audit.json)：入力ハッシュ・固定特徴量・因果分割・検証記録。
"""
    (out / "summary.md").write_text(summary, encoding="utf-8")
    print(f"REPORT {out / 'summary.md'}; candidates={len(unique)} scored={eligible}", flush=True)


if __name__ == "__main__":
    import sys
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT)
