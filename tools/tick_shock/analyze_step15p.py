#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import math
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_202504"
DEFAULT_OUT = ROOT / "reports/analysis/tick_shock/step15p"
COSTS = (0.0, 0.1, 0.2, 0.5, 1.0)
SEED = 20260908
BOOTSTRAPS = 10_000


def scenario_path(run: Path) -> Path:
    plain=run/"symmetric_oco_scenarios.csv"
    return plain if plain.exists() else run/"symmetric_oco_scenarios.csv.gz"


def write_csv(path: Path, rows: list[dict], fields: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if fields is None:
        fields = list(rows[0]) if rows else ["status"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields);writer.writeheader();writer.writerows(rows)


def longest_loss(values: np.ndarray) -> int:
    best = cur = 0
    for value in values:
        cur = cur + 1 if value < 0 else 0;best = max(best, cur)
    return best


def max_drawdown(values: np.ndarray) -> tuple[float, float]:
    equity = np.cumsum(values);peaks = np.maximum.accumulate(np.r_[0.0, equity])[:-1]
    dd = peaks - equity
    return (float(equity[-1]) if len(equity) else 0.0, float(dd.max()) if len(dd) else 0.0)


def metric(group: pd.DataFrame, cost: float) -> dict:
    net_pips = group["gross_pips"].to_numpy(float) - cost
    risk_pips = group["sl_atr"].to_numpy(float) * group["atr14_m5"].to_numpy(float) / group["pip_size"].to_numpy(float)
    net_r = net_pips / risk_pips
    wins = net_pips > 0;losses = net_pips < 0
    pos = float(net_pips[wins].sum());neg = float(-net_pips[losses].sum())
    avg_win = float(net_pips[wins].mean()) if wins.any() else 0.0
    avg_loss = float(net_pips[losses].mean()) if losses.any() else 0.0
    be = abs(avg_loss) / (avg_win + abs(avg_loss)) if avg_win > 0 and avg_loss < 0 else math.nan
    ordered = group.assign(_r=net_r).sort_values(["t0_msc", "episode_id"])["_r"].to_numpy(float)
    terminal, dd = max_drawdown(ordered)
    return {
        "trades": len(group), "tp_first": int((group.result == "TP_FIRST").sum()), "sl_first": int((group.result == "SL_FIRST").sum()),
        "timeout": int((group.result == "TIMEOUT").sum()), "win_rate": float((group.result == "TP_FIRST").mean()), "positive_return_rate": float(wins.mean()), "gross_expectancy_pips": float(group.gross_pips.mean()),
        "net_expectancy_pips": float(net_pips.mean()), "net_expectancy_r": float(net_r.mean()), "pf": pos / neg if neg > 0 else math.inf,
        "average_win_pips": avg_win, "average_loss_pips": avg_loss, "required_break_even_win_rate": be,
        "win_rate_minus_break_even": float((group.result == "TP_FIRST").mean() - be) if math.isfinite(be) else math.nan,
        "geometric_break_even_win_rate": float(group.sl_atr.iloc[0] / (group.tp_atr.iloc[0] + group.sl_atr.iloc[0])),
        "longest_losing_streak": longest_loss(ordered), "terminal_equity_r": terminal, "max_drawdown_r": dd,
    }


def bootstrap_ci(group: pd.DataFrame, cost: float = 0.0) -> tuple[float, float, int]:
    risk_pips = group.sl_atr * group.atr14_m5 / group.pip_size
    cluster = group.assign(_r=group.gross_r-cost/risk_pips).groupby("market_cluster_id").agg(total=("_r", "sum"), n=("_r", "size"))
    totals = cluster.total.to_numpy(float);counts = cluster.n.to_numpy(float);n = len(cluster)
    if n == 0:return math.nan, math.nan, 0
    rng = np.random.default_rng(SEED + int(group.offset_index.iloc[0]) * 100 + int(group.tp_index.iloc[0]) * 10 + int(group.sl_index.iloc[0]))
    values = np.empty(BOOTSTRAPS)
    for start in range(0, BOOTSTRAPS, 250):
        size = min(250, BOOTSTRAPS - start);idx = rng.integers(0, n, size=(size, n))
        values[start : start + size] = totals[idx].sum(axis=1) / counts[idx].sum(axis=1)
    return float(np.quantile(values, 0.025)), float(np.quantile(values, 0.975)), n


def connected_regions(surface: pd.DataFrame) -> list[dict]:
    candidates = surface[(surface.net_expectancy_02_r > 0) & (surface.trades >= 500) & ((surface.bootstrap_02_ci_high_r - surface.bootstrap_02_ci_low_r) <= 0.20) & (surface.bootstrap_02_ci_low_r > -0.02)]
    regions = []
    for offset, frame in candidates.groupby("offset_atr"):
        cells = {(int(r.tp_index), int(r.sl_index)): r for r in frame.itertuples()};seen = set()
        for cell in cells:
            if cell in seen:continue
            stack = [cell];component = []
            while stack:
                cur = stack.pop()
                if cur in seen or cur not in cells:continue
                seen.add(cur);component.append(cur)
                stack.extend([(cur[0]-1,cur[1]),(cur[0]+1,cur[1]),(cur[0],cur[1]-1),(cur[0],cur[1]+1)])
            tps={c[0] for c in component};sls={c[1] for c in component}
            regions.append({"offset_atr":offset,"cell_count":len(component),"tp_levels":len(tps),"sl_levels":len(sls),"qualifies":len(component)>=4 and len(tps)>=2 and len(sls)>=2,"cells":";".join(f"tp{a}_sl{b}" for a,b in component)})
    return regions


def heatmaps(surface: pd.DataFrame, out: Path) -> None:
    for value, name, title in (("net_expectancy_02_r", "tp_sl_net_expectancy_heatmap.png", "Net expectancy R (0.2 pip stress)"), ("win_rate", "tp_sl_win_rate_heatmap.png", "TP-first rate (0.0 pip extra cost)"), ("trades", "tp_sl_trade_frequency_heatmap.png", "Triggered trades")):
        fig, axes = plt.subplots(1, 3, figsize=(15, 4), constrained_layout=True)
        for ax, (offset, frame) in zip(axes, surface.groupby("offset_atr")):
            pivot = frame.pivot(index="sl_atr", columns="tp_atr", values=value).sort_index(ascending=False)
            if value=="net_expectancy_02_r":
                limit=max(abs(float(np.nanmin(pivot.values))),abs(float(np.nanmax(pivot.values))),1e-9)
                image=ax.imshow(pivot.values,aspect="auto",cmap="RdYlGn",norm=TwoSlopeNorm(vmin=-limit,vcenter=0.0,vmax=limit))
            else:image = ax.imshow(pivot.values, aspect="auto", cmap="viridis")
            ax.set_xticks(range(len(pivot.columns)), [str(x) for x in pivot.columns]);ax.set_yticks(range(len(pivot.index)), [str(x) for x in pivot.index])
            ax.set_xlabel("TP ATR");ax.set_ylabel("SL ATR");ax.set_title(f"offset {offset:.2f} ATR");fig.colorbar(image, ax=ax, shrink=0.8)
        fig.suptitle(title);fig.savefig(out / name, dpi=160);plt.close(fig)


def main() -> None:
    parser=argparse.ArgumentParser();parser.add_argument("--out",type=Path,default=DEFAULT_OUT);args=parser.parse_args();out=args.out;out.mkdir(parents=True,exist_ok=True)
    raw = pd.read_csv(scenario_path(RUN), low_memory=False)
    numeric = ["market_cluster_id","t0_msc","t0_quote_msc","t0_processing_msc","atr14_m5","point","pip_size","offset_index","offset_atr","trigger_msc","entry_msc","entry_processing_msc","entry_price","entry_spread","deadline_msc","tp_index","tp_atr","sl_index","sl_atr","tp_price","sl_price","exit_msc","exit_price","gross_price","gross_pips","gross_r","future_reads","backdates","fallback_quotes","ambiguous_triggers"]
    for col in numeric:raw[col]=pd.to_numeric(raw[col],errors="coerce")
    valid = raw[raw.result.isin(["TP_FIRST","SL_FIRST","TIMEOUT"])].copy()
    keys=["offset_index","offset_atr","tp_index","tp_atr","sl_index","sl_atr"]
    surfaces=[];cost_rows=[];boots=[];drawdowns=[]
    for key, group in valid.groupby(keys,sort=True):
        lo,hi,nclusters=bootstrap_ci(group);lo02,hi02,_=bootstrap_ci(group,0.2)
        base_row=dict(zip(keys,key));base_row.update(metric(group,0.0));base_row["eligible_shocks"]=raw.episode_id.nunique();base_row["trades_per_day"]=len(group)/22.0;base_row["bootstrap_ci_low_r"]=lo;base_row["bootstrap_ci_high_r"]=hi;base_row["bootstrap_02_ci_low_r"]=lo02;base_row["bootstrap_02_ci_high_r"]=hi02;base_row["market_clusters"]=nclusters
        base_row["net_expectancy_01_r"]=metric(group,0.1)["net_expectancy_r"];base_row["net_expectancy_02_r"]=metric(group,0.2)["net_expectancy_r"]
        surfaces.append(base_row)
        gross_tp_pips=float((group.tp_atr*group.atr14_m5/group.pip_size).mean());spread_pips=float((group.entry_spread/group.pip_size).mean())
        for cost in COSTS:
            row=dict(zip(keys,key));row["cost_pips"]=cost;row.update(metric(group,cost));row["eligible_shocks"]=raw.episode_id.nunique();row["trades_per_day"]=len(group)/22.0;row["gross_tp_pips"]=gross_tp_pips;row["average_entry_spread_pips"]=spread_pips;row["net_win_pips_after_extra_cost"]=gross_tp_pips-cost;row["spread_consumed_pct_of_tp"]=100.0*spread_pips/gross_tp_pips;row["spread_plus_extra_cost_pct_of_tp"]=100.0*(spread_pips+cost)/gross_tp_pips;cost_rows.append(row)
        boots.append({**dict(zip(keys,key)),"bootstrap_replicates":BOOTSTRAPS,"seed":SEED,"market_clusters":nclusters,"mean_gross_r":float(group.gross_r.mean()),"gross_ci_low_r":lo,"gross_ci_high_r":hi,"mean_net_02_r":metric(group,0.2)["net_expectancy_r"],"net_02_ci_low_r":lo02,"net_02_ci_high_r":hi02})
        m=metric(group,0.0);drawdowns.append({**dict(zip(keys,key)),"trades":m["trades"],"terminal_equity_r":m["terminal_equity_r"],"max_drawdown_r":m["max_drawdown_r"],"longest_losing_streak":m["longest_losing_streak"]})
    surface=pd.DataFrame(surfaces);cost_surface=pd.DataFrame(cost_rows);surface.to_csv(out/"geometry_surface.csv",index=False);cost_surface.to_csv(out/"cost_sensitivity.csv",index=False)
    write_csv(out/"cluster_bootstrap.csv",boots);write_csv(out/"drawdown_results.csv",drawdowns)

    offset_rows=[]
    base=raw.drop_duplicates(["episode_id","offset_index"])
    for offset,g in base.groupby(["offset_index","offset_atr"]):
        offset_rows.append({"offset_index":offset[0],"offset_atr":offset[1],"eligible_shocks":g.episode_id.nunique(),"triggered_trades":int((g.entry_status=="ENTERED").sum()),"long":int((g.oco_direction=="LONG").sum()),"short":int((g.oco_direction=="SHORT").sum()),"no_entry":int((g.entry_status=="NO_ENTRY").sum()),"ambiguous":int((g.entry_status=="AMBIGUOUS_TRIGGER").sum()),"invalid":int((g.entry_status=="INVALID_PATH").sum()),"censored":int((g.entry_status=="CENSORED").sum()),"trades_per_day":int((g.entry_status=="ENTERED").sum())/22.0})
    write_csv(out/"entry_offset_results.csv",offset_rows)
    daily=base.copy();daily["day"]=pd.to_datetime(daily.t0_msc,unit="ms",utc=True).dt.strftime("%Y-%m-%d")
    daily_rows=[]
    for (day,offset),g in daily.groupby(["day","offset_atr"]):daily_rows.append({"day":day,"offset_atr":offset,"eligible":len(g),"triggered":int((g.entry_status=="ENTERED").sum()),"no_entry":int((g.entry_status=="NO_ENTRY").sum()),"ambiguous":int((g.entry_status=="AMBIGUOUS_TRIGGER").sum())})
    write_csv(out/"daily_frequency.csv",daily_rows)

    symbol_rows=[]
    for key,g in valid.groupby(["symbol"]+keys):
        row=dict(zip(["symbol"]+keys,key));row.update(metric(g,0.2));symbol_rows.append(row)
    write_csv(out/"symbol_results.csv",symbol_rows)

    regions=connected_regions(surface);write_csv(out/"positive_region_components.csv",regions,["offset_atr","cell_count","tp_levels","sl_levels","qualifies","cells"])
    qa=[]
    def q(name,count,note=""):qa.append({"check":name,"violations":int(count),"status":"PASS" if int(count)==0 else "FAIL","note":note})
    q("future_quote_usage",raw.future_reads.fillna(0).max())
    q("entry_before_or_at_trigger",((raw.entry_msc.notna())&(raw.entry_msc<=raw.trigger_msc)).sum())
    q("barrier_before_or_at_entry",((raw.exit_msc.notna())&(raw.exit_msc<=raw.entry_msc)).sum())
    q("duplicate_episode_offset_geometry",raw.duplicated(["episode_id","offset_index","tp_index","sl_index"]).sum())
    q("market_cluster_split",(raw.groupby("event_id").market_cluster_id.nunique()>1).sum())
    q("ambiguous_trigger_silently_selected",((raw.entry_status=="AMBIGUOUS_TRIGGER")&((raw.oco_direction!="NONE")|raw.entry_msc.notna())).sum())
    trade_rows=max(0,sum(1 for _ in (RUN/"trades.csv").open(encoding="utf-8-sig"))-1);q("actual_orders_or_trades",trade_rows)
    reconstructed=(valid.exit_price-valid.entry_price)*valid.oco_direction.map({"LONG":1,"SHORT":-1});q("gross_price_recalculation",(np.abs(reconstructed-valid.gross_price)>1e-8).sum())
    q("gross_pips_recalculation",(np.abs(valid.gross_price/valid.pip_size-valid.gross_pips)>1e-6).sum())
    q("gross_r_recalculation",(np.abs(valid.gross_price/(valid.sl_atr*valid.atr14_m5)-valid.gross_r)>1e-6).sum())
    q("record_future_or_backdate",raw.future_reads.fillna(0).max()+raw.backdates.fillna(0).max())
    write_csv(out/"qa_checks.csv",qa)

    heatmaps(surface,out)
    fig,ax=plt.subplots(figsize=(8,5));
    for offset,g in cost_surface.groupby("offset_atr"):ax.plot(g.groupby("cost_pips").net_expectancy_r.mean().index,g.groupby("cost_pips").net_expectancy_r.mean().values,marker="o",label=f"offset {offset:.2f}")
    ax.axhline(0,color="black",lw=.8);ax.set(xlabel="Extra round-trip cost (pip)",ylabel="Mean expectancy R across full surface");ax.legend();fig.tight_layout();fig.savefig(out/"cost_vs_expectancy.png",dpi=160);plt.close(fig)
    cost_ratio=[]
    entered=base[base.entry_status=="ENTERED"]
    for tp in sorted(raw.tp_atr.unique()):
        tp_pips=entered.atr14_m5*tp/entered.pip_size;ratio=entered.entry_spread/entered.pip_size/tp_pips
        cost_ratio.append((tp,float(ratio.mean()),float(ratio.median())))
    fig,ax=plt.subplots(figsize=(8,5));ax.plot([x[0] for x in cost_ratio],[100*x[1] for x in cost_ratio],marker="o",label="mean");ax.plot([x[0] for x in cost_ratio],[100*x[2] for x in cost_ratio],marker="s",label="median");ax.set(xlabel="TP distance (ATR)",ylabel="Initial spread / TP (%)");ax.legend();fig.tight_layout();fig.savefig(out/"tp_distance_vs_cost_consumed_ratio.png",dpi=160);plt.close(fig)

    best=surface.sort_values("net_expectancy_02_r",ascending=False).iloc[0]
    qualifying=[r for r in regions if r["qualifies"]];verdict="MICRO_PROFIT_FEASIBILITY_FOUND" if qualifying else "MICRO_PROFIT_FEASIBILITY_NOT_FOUND"
    summary={"raw_rows":len(raw),"eligible_episodes":raw.episode_id.nunique(),"market_clusters":raw.market_cluster_id.nunique(),"valid_scenario_rows":len(valid),"best_02_cost_offset":best.offset_atr,"best_02_cost_tp":best.tp_atr,"best_02_cost_sl":best.sl_atr,"best_02_cost_expectancy_r":best.net_expectancy_02_r,"best_02_cost_win_rate":best.win_rate,"qualifying_regions":len(qualifying),"verdict":verdict,"actual_commission":"NOT_OBSERVED_ALL_SYMBOL_SCOPE"}
    (out/"analysis_summary.csv").write_text("metric,value\n"+"\n".join(f"{k},{v}" for k,v in summary.items())+"\n",encoding="utf-8")
    hashes=[]
    for path in sorted(out.glob("*.csv")):hashes.append(f"{path.name},{hashlib.sha256(path.read_bytes()).hexdigest().upper()}")
    (out/"deterministic_hashes.txt").write_text("\n".join(hashes)+"\n",encoding="utf-8")


if __name__ == "__main__":main()
