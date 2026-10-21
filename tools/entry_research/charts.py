"""Decision-only charts: never send future candles to Plotly's hidden data."""
from pathlib import Path
import json
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots


def snapshot_frames(enriched: dict, decision_time: int, lookback: int = 100) -> dict:
    return {tf: bars.loc[(bars.close_time <= decision_time) & (bars.available_time <= decision_time)]
            .tail(lookback).copy() for tf, bars in enriched.items()}


def write_chart(enriched: dict, candidate, path: Path, lookback: int = 100) -> dict:
    decision = int(candidate['signal_time'])
    frames = snapshot_frames(enriched, decision, lookback)
    order = ['M1', 'M5', 'M15', 'H1']
    fig = make_subplots(rows=4, cols=1, subplot_titles=order, vertical_spacing=.06)
    audit = {'candidate_id': str(candidate['candidate_id']), 'decision_time': decision,
             'future_candles_included': False, 'timeframes': {}}
    for row, tf in enumerate(order, 1):
        df = frames[tf]
        x = pd.to_datetime(df.time, unit='s')
        fig.add_trace(go.Candlestick(x=x, open=df.open, high=df.high, low=df.low, close=df.close,
                                    name=tf, showlegend=False), row=row, col=1)
        for col, color in [('kijun', '#ef9f33'), ('ema_fast', '#277da8'), ('ema_slow', '#c3588c'),
                           ('cloud_a', '#27a878'), ('cloud_b', '#777777')]:
            fig.add_trace(go.Scatter(x=x, y=df[col], mode='lines', name=col,
                                    line={'width': 1, 'color': color}, showlegend=(row == 1)), row=row, col=1)
        fig.add_vline(x=pd.Timestamp(decision, unit='s').to_pydatetime(), line_dash='dot', row=row, col=1)
        if tf == 'M5':
            signal = df.loc[df.time == candidate['time']]
            if len(signal):
                fig.add_trace(go.Scatter(x=pd.to_datetime(signal.time, unit='s'), y=signal.close,
                    mode='markers', marker={'size': 13, 'symbol': 'triangle-up' if candidate['side']=='LONG' else 'triangle-down',
                                           'color': '#e63946'}, name='signal close'), row=row, col=1)
        audit['timeframes'][tf] = {'n': len(df), 'max_close_time': int(df.close_time.max()) if len(df) else None,
                                  'max_available_time': int(df.available_time.max()) if len(df) else None}
        fig.update_xaxes(rangeslider_visible=False, row=row, col=1)
    title = (f"{candidate['candidate_id']} | decision {pd.Timestamp(decision, unit='s')} "
             f"| ATR={candidate['atr14']:.5f} | {candidate.get('clock_basis', 'source clock')}")
    fig.update_layout(title=title, height=1300, template='plotly_white', hovermode='x unified')
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.write_html(path, include_plotlyjs='directory', full_html=True)
    path.with_suffix('.audit.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
    return audit
