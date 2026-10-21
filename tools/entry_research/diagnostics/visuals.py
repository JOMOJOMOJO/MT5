"""Local Plotly diagnostics and explicitly retrospective representative paths."""
from __future__ import annotations

from hashlib import sha256
from html import escape
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.graph_objects as go
from plotly.offline import get_plotlyjs
from plotly.subplots import make_subplots

from .paths import _settings


CLASS_ORDER = ["immediate_adverse", "favorable_then_reversal", "adverse_then_favorable",
               "favorable_continuation", "no_direction", "ambiguous_order", "unclassified_other",
               "unclassifiable_data"]
CLASS_COLORS = ["#bf443d", "#dc8d39", "#378eac", "#27896d", "#97a6ad", "#8d6aaa", "#c5bba8", "#45566c"]
PAGE_STYLE = """
body{margin:0;background:#f4f6f8;color:#243444;font:15px/1.65 system-ui,sans-serif}
main{max-width:1400px;margin:auto;padding:32px 28px 64px}h1{font-size:29px;line-height:1.35}
h2{font-size:21px;margin-top:36px}p{max-width:1100px}.eyebrow{color:#547280;font-size:13px;letter-spacing:.08em}
.card{background:white;border:1px solid #dce3e8;border-radius:12px;padding:22px;margin:20px 0}
.note{background:#fff6df;border-left:4px solid #cba64b;padding:12px 18px}.grid{display:flex;gap:14px;flex-wrap:wrap}
.metric{background:#fff;border:1px solid #dce3e8;border-radius:9px;padding:15px 22px;min-width:170px}
.metric strong{display:block;font-size:26px}a{color:#236b91}nav a{margin-right:20px}
table{border-collapse:collapse;width:100%;font-size:13px}td,th{text-align:left;padding:9px;border-bottom:1px solid #dce3e8}
.table-wrap{overflow-x:auto}.muted{color:#5d6e7a}.plotly-graph-div{width:100%}
"""


def _fragment(fig: go.Figure, div_id: str) -> str:
    return fig.to_html(full_html=False, include_plotlyjs=False, div_id=div_id,
                       config={"responsive": True, "displaylogo": False})


def _page(title: str, body: str, script: str = "plotly.min.js") -> str:
    return (f'<!doctype html><html lang="ja"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{escape(title)}</title><style>{PAGE_STYLE}</style>'
            f'<script src="{escape(script, quote=True)}"></script></head><body><main>{body}</main></body></html>')


def _write(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as handle:
        handle.write(contents)


def _base(fig: go.Figure, title: str, height: int = 540) -> go.Figure:
    fig.update_layout(title={'text':title.replace(' — ', '<br>'), 'font':{'size':14}, 'x':.02, 'y':.98}, template="plotly_white", height=height,
                      font={"family": "system-ui, sans-serif", "color": "#243444"},
                      margin={"t": 130, "l": 65, "r": 35, "b": 100},
                      legend={"orientation": "h", "y": -0.18}, hovermode="closest")
    return fig


def _empty(title: str, message: str) -> go.Figure:
    fig = _base(go.Figure(), title, 320)
    fig.add_annotation(text=message, x=.5, y=.5, xref="paper", yref="paper", showarrow=False)
    return fig


def _dropdown(fig: go.Figure, groups: list[tuple[str, list[int]]]) -> None:
    if not groups:
        return
    for number, trace in enumerate(fig.data):
        trace.visible = number in groups[0][1]
    buttons = [{"label": label, "method": "update", "args": [
        {"visible": [number in indices for number in range(len(fig.data))]}]}
               for label, indices in groups]
    fig.update_layout(updatemenus=[{"buttons": buttons, "direction": "down", "x": 1., "y": 1.16,
                                   "xanchor": "right", "yanchor": "top", "showactive": True}])


def _excursions(classes: pd.DataFrame) -> go.Figure:
    usable = classes.loc[classes.complete.astype(bool)]
    if usable.empty:
        return _empty("MFE / MAE 分布", "50本の完全観測候補がありません")
    counts = usable.groupby(['method','side']).candidate_id.transform('size')
    labels = usable.method.astype(str) + " / " + usable.side.astype(str) + ' (n=' + counts.astype(str) + ')'
    fig = go.Figure()
    for column, color in [("mfe_atr", "#268b73"), ("mae_atr", "#c8554c")]:
        fig.add_trace(go.Box(x=labels, y=usable[column], name=column.upper(), boxpoints=False,
                             marker_color=color, hovertemplate="%{x}<br>%{y:.3f} ATR<extra>%{fullData.name}</extra>"))
    fig.update_layout(boxmode="group")
    cap = float(np.nanquantile(usable[['mfe_atr','mae_atr']].to_numpy(), .99))
    fig.update_yaxes(title="シグナル時点ATR倍率（50本）", range=[0,cap])
    fig.update_layout(updatemenus=[{'x':1,'y':1.12,'xanchor':'right','buttons':[
        {'label':'表示: P99まで（全件保持）','method':'relayout','args':[{'yaxis.range':[0,cap],'yaxis.autorange':False}]},
        {'label':'表示: 全範囲','method':'relayout','args':[{'yaxis.autorange':True}]}]}])
    return _base(fig, f"MFE / MAE 分布 — 完全観測 n={len(usable):,}", 600)


def _class_rates(classes: pd.DataFrame) -> go.Figure:
    if classes.empty:
        return _empty("経路分類", "候補がありません")
    counts = classes.groupby(["method", "side", "class_label"]).size().unstack(fill_value=0)
    totals = counts.sum(axis=1)
    labels = [f"{method} / {side}" for method, side in counts.index]
    fig = go.Figure()
    for category, color in zip(CLASS_ORDER, CLASS_COLORS):
        n = counts[category] if category in counts else pd.Series(0, index=counts.index)
        fig.add_trace(go.Bar(x=labels, y=100 * n / totals, name=category, marker_color=color,
                             customdata=np.column_stack([n, totals]),
                             hovertemplate="%{x}<br>%{y:.2f}%<br>n=%{customdata[0]} / %{customdata[1]}<extra>%{fullData.name}</extra>"))
    fig.update_layout(barmode="stack")
    fig.update_yaxes(title="全元候補に対する割合 (%)", range=[0, 100])
    return _base(fig, "経路分類 — 分母は欠損分類を含む全元候補", 620)


def _return_curves(summary: pd.DataFrame) -> go.Figure:
    if summary.empty:
        return _empty("平均価格経路", "集計がありません")
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True, vertical_spacing=.12,
                        subplot_titles=["方向調整平均リターン", "元のマッチ対照との差"])
    groups = []
    for (method, side), frame in summary.groupby(["method", "side"], sort=True):
        frame = frame.sort_values("horizon")
        indices = []
        for column, name, color, dash, row in [
            ("gross_pips", "Gross", "#4c97c6", "dot", 1),
            ("net_pips", "Net", "#276c9d", "solid", 1),
            ("baseline_net_pips", "Baseline net", "#88939e", "dash", 1),
            ("delta_net_pips", "Net minus baseline", "#a85f39", "solid", 2),
        ]:
            indices.append(len(fig.data))
            fig.add_trace(go.Scatter(x=frame.horizon, y=frame[column], name=name, mode="lines",
                                     line={"color": color, "dash": dash}, customdata=frame[["n"]],
                                     hovertemplate="H=%{x}<br>%{y:.4f} pips<br>n=%{customdata[0]}<extra>%{fullData.name}</extra>"), row=row, col=1)
        groups.append((f"{method} / {side}", indices))
    _dropdown(fig, groups)
    fig.add_hline(y=0, line_color="#b9c2c9", line_width=1, row="all", col=1)
    fig.update_yaxes(title="pips")
    fig.update_xaxes(title="H（約定バーを1本目として数える）", row=2, col=1)
    return _base(fig, "平均価格経路 — 同じ50本完全観測コホートを全Hで固定", 760)


def _timing(summary: pd.DataFrame) -> go.Figure:
    if summary.empty:
        return _empty("エントリー時点比較", "集計がありません")
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True, vertical_spacing=.16,
                        subplot_titles=["元候補あたり / 約定候補あたりの期待値", "約定率"])
    groups = []
    for (method, side, endpoint), frame in summary.groupby(["method", "side", "endpoint"], sort=True):
        frame = frame.sort_values("policy")
        indices = []
        for column, label, color in [("opportunity_net", "元候補あたりNet", "#317daa"),
                                      ("baseline_opportunity_net", "対照: 元候補あたりNet", "#9ba7b0"),
                                      ("conditional_net", "約定候補あたりNet", "#d19246")]:
            indices.append(len(fig.data))
            fig.add_trace(go.Bar(x=frame.policy, y=frame[column], name=label, marker_color=color,
                                 customdata=frame[["n", "filled", "delta_immediate", "delta_baseline"]],
                                 hovertemplate="%{x}<br>%{y:.4f} pips<br>n=%{customdata[0]} / filled=%{customdata[1]}"
                                               "<br>Δimmediate=%{customdata[2]:.4f}<br>Δbaseline=%{customdata[3]:.4f}<extra>%{fullData.name}</extra>"), row=1, col=1)
        indices.append(len(fig.data))
        fig.add_trace(go.Bar(x=frame.policy, y=100 * frame.fill_rate, name="Fill rate (%)", marker_color="#488b72",
                             hovertemplate="%{x}<br>%{y:.2f}%<extra>Fill rate</extra>"), row=2, col=1)
        groups.append((f"{method} / {side} / {endpoint}", indices))
    _dropdown(fig, groups)
    fig.update_layout(barmode="group")
    fig.update_yaxes(title="net pips", row=1, col=1)
    fig.update_yaxes(title="filled / original (%)", range=[0, 100], row=2, col=1)
    return _base(fig, "エントリー時点比較 — 未約定を元候補分母から除かない", 800)


def _environment(environments: pd.DataFrame) -> go.Figure:
    if environments.empty or "dimensions" not in environments:
        return _empty("H1 × M15 環境", "集計がありません")
    subset = environments.loc[environments.dimensions.eq("h1_alignment+m15_alignment")]
    if subset.empty:
        return _empty("H1 × M15 環境", "事前定義したH1 × M15セルがありません")
    categories = ["aligned", "opposed", "other"]
    fig = go.Figure()
    groups = []
    for (method, side), frame in subset.groupby(["method", "side"], sort=True):
        z = np.full((3, 3), np.nan)
        net = np.full((3, 3), np.nan)
        text = np.full((3, 3), "n=0<br>gate=FAIL", dtype=object)
        hover = np.full((3, 3), "Unavailable", dtype=object)
        for _, cell in frame.iterrows():
            y, x = categories.index(cell.h1_alignment), categories.index(cell.m15_alignment)
            # Tiny cells remain labeled but do not receive a persuasive color.
            z[y, x] = cell.delta_net_pips if cell.sample_gates_pass else np.nan
            net[y, x] = cell.mean_net_pips if cell.sample_gates_pass else np.nan
            gate = "PASS" if bool(cell.sample_gates_pass) else "FAIL"
            text[y, x] = f"n={int(cell.n)}<br>gate={gate}"
            hover[y, x] = (f"H1={cell.h1_alignment} / M15={cell.m15_alignment}<br>net={cell.mean_net_pips:.4f} / Δnet={cell.delta_net_pips:.4f} pips"
                           f"<br>n={int(cell.n)} / weeks={int(cell.weeks)}<br>sample gate={gate}"
                           f"<br>gate reasons={escape(str(cell.get('sample_gate_reasons', '')))}"
                           f"<br>Holm p={cell.get('p_delta_net_pips_holm', np.nan):.5f}"
                           f"<br>exploratory hypothesis={bool(cell.get('exploratory_hypothesis', False))}")
        for values, name in [(net, 'Net'), (z, 'Delta')]:
            groups.append((f"{method} / {side} / {name}", [len(fig.data)]))
            fig.add_trace(go.Heatmap(x=categories, y=categories, z=values, zmid=0, colorscale="RdBu",
                                     text=text, texttemplate="%{z:.2f}<br>%{text}", customdata=hover,
                                     hovertemplate="%{customdata}<extra></extra>",
                                     colorbar={"title": name+' pips', 'thickness': 12}))
    _dropdown(fig, groups)
    fig.update_xaxes(title="M15 / エントリー方向との関係")
    fig.update_yaxes(title="H1 / エントリー方向との関係")
    fig.update_layout(plot_bgcolor='#eeeeee')
    return _base(fig, "H1 × M15 — Net / Delta切替、灰色は件数基準未達", 680)


def _representative(bars: pd.DataFrame, candidate: pd.Series, classified: pd.Series,
                    settings: dict) -> tuple[go.Figure, dict]:
    entry, horizon = int(candidate.entry_index), settings["horizon"]
    left, right = max(0, entry - 30), entry + horizon
    window = bars.iloc[left:right].copy()
    price, atr = float(bars.iloc[entry].open), float(candidate.atr14)
    sign = 1 if candidate.side == "LONG" else -1
    favorable = price + sign * settings["threshold_atr"] * atr
    adverse = price - sign * settings["threshold_atr"] * atr
    x = pd.to_datetime(window.time, unit="s")
    offset = np.arange(left - entry, right - entry)
    fig = make_subplots(rows=2, cols=1, vertical_spacing=.16,
                        subplot_titles=["M5: 前30本 + 元エントリーから50本（未来を含む事後診断）",
                                        "方向調整終値経路 / 元シグナルATRで固定"])
    fig.add_trace(go.Candlestick(x=x, open=window.open, high=window.high, low=window.low,
                                 close=window.close, name="M5 Bid OHLC"), row=1, col=1)
    for level, label, color in [(price, "P0: original entry open", "#536776"),
                                  (favorable, "+0.5 ATR favorable", "#25896b"),
                                  (adverse, "-0.5 ATR adverse", "#bb4d43")]:
        fig.add_hline(y=level, line_color=color, line_dash="dash", annotation_text=label, row=1, col=1)
    for instant, label, color in [(candidate.signal_time, "signal available", "#a67c32"),
                                    (candidate.entry_time, "original entry", "#294d7c")]:
        # Numeric epoch milliseconds avoid Plotly date annotation arithmetic.
        fig.add_shape(type="line", x0=pd.Timestamp(int(instant), unit="s"), x1=pd.Timestamp(int(instant), unit="s"),
                      y0=float(window.low.min()), y1=float(window.high.max()), line={"color": color, "dash": "dot"}, row=1, col=1)
        fig.add_trace(go.Scatter(x=[pd.Timestamp(int(instant), unit="s")], y=[price], mode="markers",
                                 marker={"size": 11, "color": color}, name=label), row=1, col=1)
    normalized = sign * (window.close - price) / atr
    fig.add_trace(go.Scatter(x=offset, y=normalized, mode="lines+markers", marker={"size": 3},
                             line={"color": "#347ca5"}, name="direction-adjusted close"), row=2, col=1)
    fig.add_vrect(x0=0, x1=horizon - 1, fillcolor="#dceaf4", opacity=.3, line_width=0, row=2, col=1)
    for level in [0, settings["threshold_atr"], -settings["threshold_atr"]]:
        fig.add_hline(y=level, line_dash="dot", line_color="#9da9b3", row=2, col=1)
    fig.add_trace(go.Scatter(x=[0], y=[0], mode="markers", marker={"size": 10, "color": "#294d7c"}, name="frozen P0"), row=2, col=1)
    fig.update_xaxes(rangeslider_visible=False, row=1, col=1)
    fig.update_xaxes(title="元エントリーバー=0（その終値がH1）", row=2, col=1)
    fig.update_yaxes(title="Bid price", row=1, col=1)
    fig.update_yaxes(title="directional ATR", row=2, col=1)
    _base(fig, f"RETROSPECTIVE | {candidate.method} {candidate.side} | {classified.class_label}", 920)
    audit = {"pre_bars": entry - left, "post_bars": len(window) - (entry - left),
             "window_first_time": int(window.time.iloc[0]), "window_last_time": int(window.time.iloc[-1]),
             "entry_price": price, "frozen_atr": atr, "contains_future_prices": True}
    return fig, audit


def render_visuals(bars: pd.DataFrame, candidates: pd.DataFrame, classes: pd.DataFrame,
                   curve_summary: pd.DataFrame, timing_summary: pd.DataFrame,
                   environments: pd.DataFrame, out_dir: Path, config: dict) -> list[Path]:
    """Write dashboard.html, selection.csv, local JS and representative HTMLs.

    Selection is one complete original candidate per method/side/class, using
    a fixed seeded SHA256 rank. It does not choose the largest win/loss. The
    representative charts intentionally contain future data and are clearly
    separate from the initial decision-only charts. Existing outputs are not
    overwritten. Returns every written file path.
    """
    out = Path(out_dir)
    settings = _settings(config)
    seed = int(config.get("seed", 20261015))
    per_group = int(config.get("representatives_per_method_side_class", 1))
    if per_group != 1:
        raise ValueError("This diagnostic freezes one representative per method/side/class")
    if candidates.candidate_id.duplicated().any() or classes.candidate_id.duplicated().any():
        raise ValueError("Candidate IDs must remain unique")
    if not set(classes.candidate_id).issubset(set(candidates.candidate_id)):
        raise ValueError("Classifications refer to unknown original candidates")
    if (bars.time >= 1767225600).any():
        raise ValueError("2026 holdout price rows are forbidden")
    for name in ["dashboard.html", "selection.csv", "plotly.min.js"]:
        if (out / name).exists():
            raise FileExistsError(f"Refusing to overwrite {out / name}")
    selected = []
    complete = classes.loc[classes.complete.astype(bool)]
    for keys, group in complete.groupby(["method", "side", "class_label"], sort=True):
        ranked = sorted(group.candidate_id, key=lambda cid: sha256(f"{seed}|{cid}".encode()).hexdigest())
        cid = ranked[0]
        digest = sha256(f"{seed}|{cid}".encode()).hexdigest()
        selected.append({"candidate_id": cid, "method": keys[0], "side": keys[1], "class_label": keys[2],
                         "seed": seed, "selection_rule": "minimum_seeded_sha256_within_complete_class",
                         "selection_hash": digest, "representative_file": f"representatives/{digest[:16]}.html"})
    figures = [("excursions", "MFE / MAE 分布", _excursions(classes)),
               ("classes", "経路分類", _class_rates(classes)),
               ("curves", "平均価格経路", _return_curves(curve_summary)),
               ("timing", "エントリー時点", _timing(timing_summary)),
               ("environment", "相場環境", _environment(environments))]
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    _write(out / "plotly.min.js", get_plotlyjs())
    paths.append(out / "plotly.min.js")
    indexed_candidates = candidates.set_index("candidate_id", drop=False)
    indexed_classes = classes.set_index("candidate_id", drop=False)
    for selection in selected:
        cid = selection["candidate_id"]
        candidate, classified = indexed_candidates.loc[cid], indexed_classes.loc[cid]
        fig, audit = _representative(bars, candidate, classified, settings)
        selection.update(audit)
        selection.update({"signal_time": int(candidate.signal_time), "entry_time": int(candidate.entry_time)})
        body = (f'<p class="eyebrow">RETROSPECTIVE DIAGNOSTIC / SOURCE CLOCK</p><h1>{escape(str(cid))}</h1>'
                '<p class="note">この図は判定後50本の未来価格を意図的に含む事後診断です。エントリー判断用のチャートではありません。</p>'
                f'<p>分類: <strong>{escape(str(classified.class_label))}</strong> / 固定seed {seed}による各分類内の1例。'
                '分類は経路の記述であり、利確・損切りの売買規則ではありません。</p>'
                f'<p>P0={audit["entry_price"]:.5f} / ATR={audit["frozen_atr"]:.5f} / 前{audit["pre_bars"]}本・後{audit["post_bars"]}本。'
                '時刻は未変換のブローカー時計。</p>' + _fragment(fig, "representative-path") +
                '<p><a href="../dashboard.html#representatives">ダッシュボードへ戻る</a></p>')
        path = out / selection["representative_file"]
        _write(path, _page(f"Retrospective | {cid}", body, "../plotly.min.js"))
        paths.append(path)
    selection_frame = pd.DataFrame(selected)
    with (out / "selection.csv").open("x", encoding="utf-8", newline="") as handle:
        selection_frame.to_csv(handle, index=False)
    paths.append(out / "selection.csv")
    nav = "".join(f'<a href="#{name}">{escape(title)}</a>' for name, title, _ in figures)
    body = ('<p class="eyebrow">USDJPY M5 / DEVELOPMENT 2024–2025</p>'
            '<h1>エントリー候補の経路・時点・環境診断</h1>'
            '<p>元の候補とATR・エントリー価格を固定した記述的分析。2026年価格は使用しない。'
            'このページは研究統計であり、MT5売買バックテストや利益の確認を表すものではない。</p>'
            f'<div class="grid"><div class="metric">元候補<strong>{len(classes):,}</strong></div>'
            f'<div class="metric">50本完全観測<strong>{int(classes.complete.sum()):,}</strong></div>'
            f'<div class="metric">事後の代表例<strong>{len(selected)}</strong></div></div>'
            f'<p class="note">ネット値は固定コスト{settings["total_cost_pips"]:.1f} pips控除。'
            'MFE/MAEと分類はグロス経路。時刻はsource clockで、地理的セッションは未確認。'
            '環境で条件付けした対照は、その環境に再マッチした因果比較ではない。</p>'
            f'<nav>{nav}<a href="#representatives">代表例</a></nav>')
    for name, title, fig in figures:
        body += f'<section class="card" id="{name}"><h2>{escape(title)}</h2>' + _fragment(fig, f"diagnostic-{name}") + '</section>'
    body += ('<section class="card" id="representatives"><h2>代表例 — 未来価格を含む事後診断</h2>'
             f'<p>seed={seed}、各手法・方向・分類から完全観測の1件を選ぶ。最大利益・最大損失から選ばない。'
             '同じ入力・seedなら同じIDを選ぶ。<a href="selection.csv">選択一覧CSV</a></p>'
             '<div class="table-wrap"><table><thead><tr><th>手法</th><th>方向</th><th>分類</th><th>候補</th></tr></thead><tbody>')
    for row in selected:
        body += (f'<tr><td>{escape(str(row["method"]))}</td><td>{escape(str(row["side"]))}</td>'
                 f'<td>{escape(str(row["class_label"]))}</td><td><a href="{escape(row["representative_file"], quote=True)}">'
                 f'{escape(str(row["candidate_id"]))}</a></td></tr>')
    body += '</tbody></table></div></section>'
    _write(out / "dashboard.html", _page("USDJPY entry research diagnostics", body))
    paths.append(out / "dashboard.html")
    return paths
