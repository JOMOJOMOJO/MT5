from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5
import numpy as np
import pandas as pd


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "reports" / "research"
ORIGIN_PATH = REPO_ROOT.parents[2] / "origin.txt"
TIMEFRAME_MAP = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1": mt5.TIMEFRAME_H1,
}
SESSION_WINDOWS = {
    "asia": (0, 8),
    "london": (7, 16),
    "ny": (13, 22),
    "late": (20, 24),
}
HORIZONS = (3, 6, 12)
RULE_QUANTILES = (0.1, 0.2, 0.8, 0.9)


@dataclass
class RuleResult:
    side: str
    context: str
    horizon: int
    feature: str
    operator: str
    quantile: float
    threshold: float
    train_trades: int
    train_tpd: float
    train_expectancy: float
    train_hit_rate: float
    test_trades: int
    test_tpd: float
    test_expectancy: float
    test_hit_rate: float
    score: float


@dataclass
class PairRuleResult:
    side: str
    context: str
    horizon: int
    rule_a: str
    rule_b: str
    train_trades: int
    train_tpd: float
    train_expectancy: float
    train_hit_rate: float
    test_trades: int
    test_tpd: float
    test_expectancy: float
    test_hit_rate: float
    score: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Mine BTC features for new EA hypotheses.")
    parser.add_argument("--symbol", default="BTCUSD")
    parser.add_argument("--timeframe", default="M5", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--bars", type=int, default=140000)
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-days", type=int, default=89)
    parser.add_argument("--min-samples", type=int, default=120)
    parser.add_argument("--min-trades-per-day", type=float, default=3.0)
    parser.add_argument("--min-coverage", type=float, default=0.03)
    parser.add_argument("--max-coverage", type=float, default=0.65)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    return parser.parse_args()


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def load_terminal_path(explicit: str | None) -> str:
    if explicit:
        return explicit
    origin = ORIGIN_PATH.read_text(encoding="utf-16").strip()
    return str(Path(origin) / "terminal64.exe")


def initialize_mt5(terminal_path: str) -> None:
    if not mt5.initialize(path=terminal_path):
        raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")


def symbol_point(symbol: str) -> float:
    info = mt5.symbol_info(symbol)
    if info is None or not info.point:
        return 1.0
    return float(info.point)


def load_rates(symbol: str, timeframe_label: str, bars: int) -> pd.DataFrame:
    timeframe = TIMEFRAME_MAP[timeframe_label]
    if not mt5.symbol_select(symbol, True):
        raise RuntimeError(f"Failed to select symbol {symbol}: {mt5.last_error()}")
    point = symbol_point(symbol)
    chunk_size = 5000
    frames: list[pd.DataFrame] = []
    position = 0
    while position < bars:
        count = min(chunk_size, bars - position)
        rates = mt5.copy_rates_from_pos(symbol, timeframe, position, count)
        if rates is None:
            if frames:
                break
            raise RuntimeError(f"Failed to copy rates: {mt5.last_error()}")
        chunk = pd.DataFrame(rates)
        if chunk.empty:
            break
        frames.append(chunk)
        position += len(chunk)
        if len(chunk) < count:
            break
    if not frames:
        raise RuntimeError("No rates were returned from MT5.")
    frame = pd.concat(frames, ignore_index=True)
    frame["time"] = pd.to_datetime(frame["time"], unit="s")
    frame["symbol_point"] = point
    return frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)


def load_rates_by_range(symbol: str, timeframe_label: str, lookback_days: int, bars_fallback: int) -> pd.DataFrame:
    timeframe = TIMEFRAME_MAP[timeframe_label]
    if not mt5.symbol_select(symbol, True):
        raise RuntimeError(f"Failed to select symbol {symbol}: {mt5.last_error()}")
    point = symbol_point(symbol)
    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        return load_rates(symbol, timeframe_label, bars_fallback)
    end = datetime.fromtimestamp(tick.time)
    start = end - timedelta(days=lookback_days)
    rates = mt5.copy_rates_range(symbol, timeframe, start, end)
    if rates is None:
        return load_rates(symbol, timeframe_label, bars_fallback)
    frame = pd.DataFrame(rates)
    if frame.empty:
        return load_rates(symbol, timeframe_label, bars_fallback)
    frame["time"] = pd.to_datetime(frame["time"], unit="s")
    frame["symbol_point"] = point
    return frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)


def ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def rsi(series: pd.Series, period: int) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0.0).rolling(period).mean()
    loss = (-delta.clip(upper=0.0)).rolling(period).mean()
    rs = gain / loss.replace(0.0, np.nan)
    return 100.0 - (100.0 / (1.0 + rs))


def true_range(df: pd.DataFrame) -> pd.Series:
    return pd.concat(
        [
            df["high"] - df["low"],
            (df["high"] - df["close"].shift(1)).abs(),
            (df["low"] - df["close"].shift(1)).abs(),
        ],
        axis=1,
    ).max(axis=1)


def adx(df: pd.DataFrame, period: int) -> pd.Series:
    up_move = df["high"].diff()
    down_move = -df["low"].diff()
    plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)
    tr = true_range(df)
    atr = tr.rolling(period).mean()
    plus_di = 100.0 * pd.Series(plus_dm, index=df.index).rolling(period).mean() / atr.replace(0.0, np.nan)
    minus_di = 100.0 * pd.Series(minus_dm, index=df.index).rolling(period).mean() / atr.replace(0.0, np.nan)
    dx = ((plus_di - minus_di).abs() / (plus_di + minus_di).replace(0.0, np.nan)) * 100.0
    return dx.rolling(period).mean()


def stochastic(df: pd.DataFrame, period: int, smooth: int) -> tuple[pd.Series, pd.Series]:
    lowest = df["low"].rolling(period).min()
    highest = df["high"].rolling(period).max()
    k = 100.0 * (df["close"] - lowest) / (highest - lowest).replace(0.0, np.nan)
    d = k.rolling(smooth).mean()
    return k, d


def add_sessions(df: pd.DataFrame) -> pd.DataFrame:
    frame = df.copy()
    frame["hour"] = frame["time"].dt.hour
    frame["dow"] = frame["time"].dt.dayofweek
    for session_name, (start, end) in SESSION_WINDOWS.items():
        frame[f"session_{session_name}"] = frame["hour"].between(start, end - 1).astype(float)
    return frame


def enrich_features(frame: pd.DataFrame) -> tuple[pd.DataFrame, list[str]]:
    df = add_sessions(frame)
    df["atr14"] = true_range(df).rolling(14).mean()
    df["atr_pct"] = df["atr14"] / df["close"].replace(0.0, np.nan)

    df["ema10"] = ema(df["close"], 10)
    df["ema20"] = ema(df["close"], 20)
    df["ema50"] = ema(df["close"], 50)
    df["ema100"] = ema(df["close"], 100)
    df["ema_gap_10_20"] = (df["ema10"] - df["ema20"]) / df["atr14"]
    df["ema_gap_20_50"] = (df["ema20"] - df["ema50"]) / df["atr14"]
    df["ema_gap_50_100"] = (df["ema50"] - df["ema100"]) / df["atr14"]
    df["close_vs_ema20"] = (df["close"] - df["ema20"]) / df["atr14"]
    df["close_vs_ema50"] = (df["close"] - df["ema50"]) / df["atr14"]
    df["ema20_slope_3"] = (df["ema20"] - df["ema20"].shift(3)) / df["atr14"]
    df["ema50_slope_6"] = (df["ema50"] - df["ema50"].shift(6)) / df["atr14"]

    df["rsi14"] = rsi(df["close"], 14)
    df["rsi7"] = rsi(df["close"], 7)

    df["macd_line"] = ema(df["close"], 12) - ema(df["close"], 26)
    df["macd_signal"] = ema(df["macd_line"], 9)
    df["macd_hist"] = (df["macd_line"] - df["macd_signal"]) / df["atr14"]
    df["macd_line_atr"] = df["macd_line"] / df["atr14"]

    bb_mid = df["close"].rolling(20).mean()
    bb_std = df["close"].rolling(20).std()
    df["bb_z"] = (df["close"] - bb_mid) / bb_std.replace(0.0, np.nan)
    df["bb_width"] = (bb_std * 4.0) / df["close"].replace(0.0, np.nan)

    df["adx14"] = adx(df, 14)
    df["stoch_k"], df["stoch_d"] = stochastic(df, 14, 3)
    df["stoch_spread"] = df["stoch_k"] - df["stoch_d"]

    df["ret_1"] = df["close"].pct_change(1)
    df["ret_3"] = df["close"].pct_change(3)
    df["ret_6"] = df["close"].pct_change(6)
    df["ret_12"] = df["close"].pct_change(12)
    df["ret_24"] = df["close"].pct_change(24)
    df["roc_atr_3"] = (df["close"] - df["close"].shift(3)) / df["atr14"]
    df["roc_atr_6"] = (df["close"] - df["close"].shift(6)) / df["atr14"]
    df["roc_atr_12"] = (df["close"] - df["close"].shift(12)) / df["atr14"]

    bar_range = (df["high"] - df["low"]).replace(0.0, np.nan)
    df["body_atr"] = (df["close"] - df["open"]) / df["atr14"]
    df["range_atr"] = bar_range / df["atr14"]
    df["upper_wick_share"] = (df["high"] - df[["open", "close"]].max(axis=1)) / bar_range
    df["lower_wick_share"] = (df[["open", "close"]].min(axis=1) - df["low"]) / bar_range
    df["close_location"] = (df["close"] - df["low"]) / bar_range

    df["high_break_12"] = (df["close"] - df["high"].shift(1).rolling(12).max()) / df["atr14"]
    df["low_break_12"] = (df["close"] - df["low"].shift(1).rolling(12).min()) / df["atr14"]
    df["high_break_24"] = (df["close"] - df["high"].shift(1).rolling(24).max()) / df["atr14"]
    df["low_break_24"] = (df["close"] - df["low"].shift(1).rolling(24).min()) / df["atr14"]
    df["range_compression_12"] = df["high"].rolling(12).max().sub(df["low"].rolling(12).min()) / df["close"]
    df["range_compression_24"] = df["high"].rolling(24).max().sub(df["low"].rolling(24).min()) / df["close"]

    df["tick_volume_z"] = (
        (df["tick_volume"] - df["tick_volume"].rolling(50).mean())
        / df["tick_volume"].rolling(50).std().replace(0.0, np.nan)
    )
    df["tick_volume_rel10"] = df["tick_volume"] / df["tick_volume"].rolling(10).mean().replace(0.0, np.nan)
    df["tick_volume_change_1"] = df["tick_volume"].pct_change(1)
    df["tick_volume_change_3"] = df["tick_volume"].pct_change(3)
    df["tick_acceleration_3"] = (
        df["tick_volume"].diff().diff().rolling(3).mean()
        / df["tick_volume"].rolling(50).std().replace(0.0, np.nan)
    )
    df["tick_flow_signed_3"] = (
        np.sign(df["ret_1"].fillna(0.0)) * df["tick_volume_rel10"].fillna(0.0)
    ).rolling(3).mean()
    point = df["symbol_point"].fillna(1.0).replace(0.0, np.nan)
    df["spread_points"] = df["spread"].astype(float)
    df["spread_price"] = df["spread_points"] * point
    df["spread_atr"] = df["spread_price"] / df["atr14"].replace(0.0, np.nan)
    df["spread_z"] = (
        (df["spread_price"] - df["spread_price"].rolling(50).mean())
        / df["spread_price"].rolling(50).std().replace(0.0, np.nan)
    )
    df["spread_change_1"] = df["spread_price"].diff()
    df["spread_change_3"] = df["spread_price"].diff(3)
    df["spread_acceleration_3"] = df["spread_price"].diff().diff().rolling(3).mean()

    prev_high_12 = df["high"].shift(1).rolling(12).max()
    prev_low_12 = df["low"].shift(1).rolling(12).min()
    prev_high_24 = df["high"].shift(1).rolling(24).max()
    prev_low_24 = df["low"].shift(1).rolling(24).min()
    df["breakout_up_12"] = (df["close"] > prev_high_12).astype(float)
    df["breakout_down_12"] = (df["close"] < prev_low_12).astype(float)
    df["breakout_up_24"] = (df["close"] > prev_high_24).astype(float)
    df["breakout_down_24"] = (df["close"] < prev_low_24).astype(float)
    df["breakout_persist_up_3"] = df["breakout_up_12"].rolling(3).sum()
    df["breakout_persist_down_3"] = df["breakout_down_12"].rolling(3).sum()
    df["breakout_persist_up_6"] = df["breakout_up_12"].rolling(6).sum()
    df["breakout_persist_down_6"] = df["breakout_down_12"].rolling(6).sum()
    df["breakout_followthrough_up"] = df["high_break_12"].clip(lower=0.0).rolling(3).mean()
    df["breakout_followthrough_down"] = (-df["low_break_12"]).clip(lower=0.0).rolling(3).mean()

    for horizon in HORIZONS:
        df[f"future_return_atr_{horizon}"] = (df["close"].shift(-horizon) - df["close"]) / df["atr14"]
        df[f"future_up_{horizon}"] = (df[f"future_return_atr_{horizon}"] > 0.0).astype(float)

    feature_columns = [
        "atr_pct",
        "ema_gap_10_20",
        "ema_gap_20_50",
        "ema_gap_50_100",
        "close_vs_ema20",
        "close_vs_ema50",
        "ema20_slope_3",
        "ema50_slope_6",
        "rsi14",
        "rsi7",
        "macd_line_atr",
        "macd_hist",
        "bb_z",
        "bb_width",
        "adx14",
        "stoch_k",
        "stoch_d",
        "stoch_spread",
        "ret_1",
        "ret_3",
        "ret_6",
        "ret_12",
        "ret_24",
        "roc_atr_3",
        "roc_atr_6",
        "roc_atr_12",
        "body_atr",
        "range_atr",
        "upper_wick_share",
        "lower_wick_share",
        "close_location",
        "high_break_12",
        "low_break_12",
        "high_break_24",
        "low_break_24",
        "range_compression_12",
        "range_compression_24",
        "tick_volume_z",
        "tick_volume_rel10",
        "tick_volume_change_1",
        "tick_volume_change_3",
        "tick_acceleration_3",
        "tick_flow_signed_3",
        "spread_points",
        "spread_price",
        "spread_atr",
        "spread_z",
        "spread_change_1",
        "spread_change_3",
        "spread_acceleration_3",
        "breakout_up_12",
        "breakout_down_12",
        "breakout_up_24",
        "breakout_down_24",
        "breakout_persist_up_3",
        "breakout_persist_down_3",
        "breakout_persist_up_6",
        "breakout_persist_down_6",
        "breakout_followthrough_up",
        "breakout_followthrough_down",
    ]
    return df, feature_columns


def trim_latest_window(df: pd.DataFrame, analysis_days: int) -> pd.DataFrame:
    latest = df["time"].max()
    start = latest - pd.Timedelta(days=analysis_days)
    return df[df["time"] >= start].copy().reset_index(drop=True)


def split_masks(df: pd.DataFrame, oos_days: int) -> tuple[pd.Series, pd.Series, pd.Timestamp]:
    latest = df["time"].max()
    split_date = latest - pd.Timedelta(days=oos_days)
    train_mask = df["time"] < split_date
    test_mask = ~train_mask
    return train_mask, test_mask, split_date


def safe_corr(series_x: pd.Series, series_y: pd.Series, method: str) -> float | None:
    joined = pd.concat([series_x, series_y], axis=1).dropna()
    if len(joined) < 50:
        return None
    if method == "spearman":
        x = joined.iloc[:, 0].rank(method="average")
        y = joined.iloc[:, 1].rank(method="average")
        value = x.corr(y, method="pearson")
    else:
        value = joined.iloc[:, 0].corr(joined.iloc[:, 1], method=method)
    if pd.isna(value):
        return None
    return float(value)


def correlations_by_split(
    df: pd.DataFrame,
    feature_columns: list[str],
    train_mask: pd.Series,
    test_mask: pd.Series,
) -> pd.DataFrame:
    rows: list[dict[str, Any]] = []
    for feature in feature_columns:
        for horizon in HORIZONS:
            target = f"future_return_atr_{horizon}"
            rows.append(
                {
                    "feature": feature,
                    "horizon": horizon,
                    "train_pearson": safe_corr(df.loc[train_mask, feature], df.loc[train_mask, target], "pearson"),
                    "train_spearman": safe_corr(df.loc[train_mask, feature], df.loc[train_mask, target], "spearman"),
                    "test_pearson": safe_corr(df.loc[test_mask, feature], df.loc[test_mask, target], "pearson"),
                    "test_spearman": safe_corr(df.loc[test_mask, feature], df.loc[test_mask, target], "spearman"),
                }
            )
    corr_df = pd.DataFrame(rows)
    corr_df["abs_consistency"] = (
        corr_df[["train_spearman", "test_spearman"]]
        .abs()
        .min(axis=1)
        .fillna(0.0)
    )
    return corr_df.sort_values(["abs_consistency", "test_spearman"], ascending=[False, False]).reset_index(drop=True)


def elapsed_days(times: pd.Series) -> float:
    if times.empty:
        return 0.0
    return max(1.0, (times.iloc[-1] - times.iloc[0]).total_seconds() / 86400.0)


def evaluate_rule(
    df: pd.DataFrame,
    signal: pd.Series,
    future_return: pd.Series,
    side: str,
    min_samples: int,
) -> dict[str, float] | None:
    side_sign = 1.0 if side == "long" else -1.0
    selected = df.loc[signal, ["time"]].copy()
    selected["ret"] = future_return.loc[signal] * side_sign
    selected = selected.dropna()
    if len(selected) < min_samples:
        return None
    expectancy = float(selected["ret"].mean())
    hit_rate = float((selected["ret"] > 0.0).mean())
    trades = int(len(selected))
    tpd = trades / elapsed_days(selected["time"])
    return {
        "trades": trades,
        "tpd": tpd,
        "expectancy": expectancy,
        "hit_rate": hit_rate,
    }


def score_rule(train_stats: dict[str, float], test_stats: dict[str, float], min_trades_per_day: float) -> float:
    turnover_score = min(train_stats["tpd"], test_stats["tpd"]) / max(1.0, min_trades_per_day)
    expectancy_score = (test_stats["expectancy"] * 100.0) + (train_stats["expectancy"] * 40.0)
    hit_score = ((test_stats["hit_rate"] - 0.5) * 100.0) + ((train_stats["hit_rate"] - 0.5) * 40.0)
    return float(expectancy_score + hit_score + turnover_score * 10.0)


def signal_coverage(mask: pd.Series) -> float:
    valid = mask.dropna()
    if valid.empty:
        return 0.0
    return float(valid.mean())


def signal_coverage_within_context(signal: pd.Series, context_mask: pd.Series, subset_mask: pd.Series) -> float:
    active = context_mask.loc[subset_mask].fillna(False)
    if active.empty or active.sum() == 0:
        return 0.0
    selected = signal.loc[subset_mask].fillna(False)
    return float(selected[active].mean())


def mine_single_feature_rules(
    df: pd.DataFrame,
    feature_columns: list[str],
    train_mask: pd.Series,
    test_mask: pd.Series,
    min_samples: int,
    min_trades_per_day: float,
    min_coverage: float,
    max_coverage: float,
) -> pd.DataFrame:
    results: list[RuleResult] = []
    contexts: dict[str, pd.Series] = {
        "all": pd.Series(True, index=df.index),
        "asia": df["session_asia"] >= 1.0,
        "london": df["session_london"] >= 1.0,
        "ny": df["session_ny"] >= 1.0,
        "late": df["session_late"] >= 1.0,
    }
    for feature in feature_columns:
        train_feature = df.loc[train_mask, feature].dropna()
        if len(train_feature) < min_samples:
            continue
        for quantile in RULE_QUANTILES:
            threshold = float(train_feature.quantile(quantile))
            operator = "<=" if quantile < 0.5 else ">="
            base_signal = (df[feature] <= threshold) if operator == "<=" else (df[feature] >= threshold)

            for context_name, context_mask in contexts.items():
                signal = base_signal & context_mask
                train_coverage = signal_coverage_within_context(signal, context_mask, train_mask)
                test_coverage = signal_coverage_within_context(signal, context_mask, test_mask)
                if (
                    train_coverage < min_coverage
                    or train_coverage > max_coverage
                    or test_coverage < min_coverage
                    or test_coverage > max_coverage
                ):
                    continue
                for horizon in HORIZONS:
                    future_return = df[f"future_return_atr_{horizon}"]
                    long_train = evaluate_rule(df.loc[train_mask], signal.loc[train_mask], future_return.loc[train_mask], "long", min_samples)
                    long_test = evaluate_rule(df.loc[test_mask], signal.loc[test_mask], future_return.loc[test_mask], "long", min_samples)
                    if long_train and long_test:
                        if (
                            long_train["expectancy"] > 0.0
                            and long_test["expectancy"] > 0.0
                            and long_train["tpd"] >= min_trades_per_day
                            and long_test["tpd"] >= min_trades_per_day
                        ):
                            results.append(
                                RuleResult(
                                    side="long",
                                    context=context_name,
                                    horizon=horizon,
                                    feature=feature,
                                    operator=operator,
                                    quantile=quantile,
                                    threshold=threshold,
                                    train_trades=int(long_train["trades"]),
                                    train_tpd=float(long_train["tpd"]),
                                    train_expectancy=float(long_train["expectancy"]),
                                    train_hit_rate=float(long_train["hit_rate"]),
                                    test_trades=int(long_test["trades"]),
                                    test_tpd=float(long_test["tpd"]),
                                    test_expectancy=float(long_test["expectancy"]),
                                    test_hit_rate=float(long_test["hit_rate"]),
                                    score=score_rule(long_train, long_test, min_trades_per_day),
                                )
                            )

                    short_train = evaluate_rule(df.loc[train_mask], signal.loc[train_mask], future_return.loc[train_mask], "short", min_samples)
                    short_test = evaluate_rule(df.loc[test_mask], signal.loc[test_mask], future_return.loc[test_mask], "short", min_samples)
                    if short_train and short_test:
                        if (
                            short_train["expectancy"] > 0.0
                            and short_test["expectancy"] > 0.0
                            and short_train["tpd"] >= min_trades_per_day
                            and short_test["tpd"] >= min_trades_per_day
                        ):
                            results.append(
                                RuleResult(
                                    side="short",
                                    context=context_name,
                                    horizon=horizon,
                                    feature=feature,
                                    operator=operator,
                                    quantile=quantile,
                                    threshold=threshold,
                                    train_trades=int(short_train["trades"]),
                                    train_tpd=float(short_train["tpd"]),
                                    train_expectancy=float(short_train["expectancy"]),
                                    train_hit_rate=float(short_train["hit_rate"]),
                                    test_trades=int(short_test["trades"]),
                                    test_tpd=float(short_test["tpd"]),
                                    test_expectancy=float(short_test["expectancy"]),
                                    test_hit_rate=float(short_test["hit_rate"]),
                                    score=score_rule(short_train, short_test, min_trades_per_day),
                                )
                            )
    return pd.DataFrame([rule.__dict__ for rule in results]).sort_values(
        ["score", "test_expectancy", "test_hit_rate"],
        ascending=[False, False, False],
    ).reset_index(drop=True)


def summarize_rules(rules_df: pd.DataFrame, side: str) -> list[dict[str, Any]]:
    if rules_df.empty:
        return []
    subset = rules_df[rules_df["side"] == side].head(10).copy()
    return subset.to_dict(orient="records")


def rule_label(row: pd.Series) -> str:
    return f"{row['context']}:{row['feature']} {row['operator']} {float(row['threshold']):.4f}"


def build_rule_signal(df: pd.DataFrame, row: pd.Series) -> pd.Series:
    if row["operator"] == "<=":
        signal = df[row["feature"]] <= float(row["threshold"])
    else:
        signal = df[row["feature"]] >= float(row["threshold"])
    if row["context"] != "all":
        signal = signal & (df[f"session_{row['context']}"] >= 1.0)
    return signal


def mine_pair_rules(
    df: pd.DataFrame,
    single_rules_df: pd.DataFrame,
    train_mask: pd.Series,
    test_mask: pd.Series,
    min_samples: int,
    min_trades_per_day: float,
    min_coverage: float,
    max_coverage: float,
    top_n_per_side: int = 12,
) -> pd.DataFrame:
    results: list[PairRuleResult] = []
    if single_rules_df.empty:
        return pd.DataFrame()

    for side in ("long", "short"):
        top_side = single_rules_df[single_rules_df["side"] == side].head(top_n_per_side).copy()
        if top_side.empty:
            continue
        top_side = top_side.reset_index(drop=True)
        for i in range(len(top_side)):
            row_a = top_side.iloc[i]
            signal_a = build_rule_signal(df, row_a)
            for j in range(i + 1, len(top_side)):
                row_b = top_side.iloc[j]
                if int(row_a["horizon"]) != int(row_b["horizon"]):
                    continue
                signal_b = build_rule_signal(df, row_b)
                signal = signal_a & signal_b
                if str(row_a["context"]) == "all":
                    context_mask = pd.Series(True, index=df.index)
                else:
                    context_mask = df[f"session_{row_a['context']}"] >= 1.0
                train_coverage = signal_coverage_within_context(signal, context_mask, train_mask)
                test_coverage = signal_coverage_within_context(signal, context_mask, test_mask)
                if (
                    train_coverage < min_coverage
                    or train_coverage > max_coverage
                    or test_coverage < min_coverage
                    or test_coverage > max_coverage
                ):
                    continue
                horizon = int(row_a["horizon"])
                future_return = df[f"future_return_atr_{horizon}"]
                train_stats = evaluate_rule(df.loc[train_mask], signal.loc[train_mask], future_return.loc[train_mask], side, min_samples)
                test_stats = evaluate_rule(df.loc[test_mask], signal.loc[test_mask], future_return.loc[test_mask], side, min_samples)
                if not train_stats or not test_stats:
                    continue
                if (
                    train_stats["expectancy"] <= 0.0
                    or test_stats["expectancy"] <= 0.0
                    or train_stats["tpd"] < min_trades_per_day
                    or test_stats["tpd"] < min_trades_per_day
                ):
                    continue
                results.append(
                    PairRuleResult(
                        side=side,
                        context=str(row_a["context"]),
                        horizon=horizon,
                        rule_a=rule_label(row_a),
                        rule_b=rule_label(row_b),
                        train_trades=int(train_stats["trades"]),
                        train_tpd=float(train_stats["tpd"]),
                        train_expectancy=float(train_stats["expectancy"]),
                        train_hit_rate=float(train_stats["hit_rate"]),
                        test_trades=int(test_stats["trades"]),
                        test_tpd=float(test_stats["tpd"]),
                        test_expectancy=float(test_stats["expectancy"]),
                        test_hit_rate=float(test_stats["hit_rate"]),
                        score=score_rule(train_stats, test_stats, min_trades_per_day),
                    )
                )
    return pd.DataFrame([row.__dict__ for row in results]).sort_values(
        ["score", "test_expectancy", "test_hit_rate"],
        ascending=[False, False, False],
    ).reset_index(drop=True)


def summarize_pair_rules(rules_df: pd.DataFrame, side: str) -> list[dict[str, Any]]:
    if rules_df.empty:
        return []
    subset = rules_df[rules_df["side"] == side].head(10).copy()
    return subset.to_dict(orient="records")


def default_output_dir(symbol: str, timeframe: str) -> Path:
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-{timeframe.lower()}-feature-lab"


def render_summary(
    metadata: dict[str, Any],
    correlations_df: pd.DataFrame,
    rules_df: pd.DataFrame,
    pair_rules_df: pd.DataFrame,
) -> tuple[dict[str, Any], str]:
    top_corr = correlations_df.head(12).to_dict(orient="records")
    top_long = summarize_rules(rules_df, "long")
    top_short = summarize_rules(rules_df, "short")
    top_pair_long = summarize_pair_rules(pair_rules_df, "long")
    top_pair_short = summarize_pair_rules(pair_rules_df, "short")
    payload = {
        "metadata": metadata,
        "top_correlations": top_corr,
        "top_long_rules": top_long,
        "top_short_rules": top_short,
        "top_pair_long_rules": top_pair_long,
        "top_pair_short_rules": top_pair_short,
    }

    lines = [
        "# BTCUSD Feature Lab",
        "",
        f"- Symbol: `{metadata['symbol']}`",
        f"- Timeframe: `{metadata['timeframe']}`",
        f"- Analysis window: `{metadata['history_start']}` -> `{metadata['history_end']}`",
        f"- Train / OOS split: `{metadata['train_start']}` -> `{metadata['train_end']}` / `{metadata['test_start']}` -> `{metadata['test_end']}`",
        f"- Full feature count: `{metadata['feature_count']}`",
        f"- Single-feature rule count: `{metadata['rule_count']}`",
        f"- Pair-rule count: `{metadata['pair_rule_count']}`",
        "",
        "## Top Correlations",
        "",
    ]
    for row in top_corr[:8]:
        lines.append(
                f"- `{row['feature']}` horizon `{row['horizon']}`: "
            f"train spearman `{(row['train_spearman'] or 0.0):.4f}`, "
            f"test spearman `{(row['test_spearman'] or 0.0):.4f}`"
        )

    lines.extend(["", "## Top Long Rules", ""])
    if top_long:
        for row in top_long[:5]:
            lines.append(
                f"- `{row['feature']} {row['operator']} {row['threshold']:.4f}` horizon `{int(row['horizon'])}`: "
                f"context `{row['context']}`, "
                f"train `{row['train_tpd']:.2f}/day PF-like exp {row['train_expectancy']:.4f}`, "
                f"test `{row['test_tpd']:.2f}/day exp {row['test_expectancy']:.4f}`, "
                f"hit `{row['test_hit_rate']:.2%}`"
            )
    else:
        lines.append("- No long single-feature rule cleared the turnover and expectancy filters.")

    lines.extend(["", "## Top Short Rules", ""])
    if top_short:
        for row in top_short[:5]:
            lines.append(
                f"- `{row['feature']} {row['operator']} {row['threshold']:.4f}` horizon `{int(row['horizon'])}`: "
                f"context `{row['context']}`, "
                f"train `{row['train_tpd']:.2f}/day exp {row['train_expectancy']:.4f}`, "
                f"test `{row['test_tpd']:.2f}/day exp {row['test_expectancy']:.4f}`, "
                f"hit `{row['test_hit_rate']:.2%}`"
            )
    else:
        lines.append("- No short single-feature rule cleared the turnover and expectancy filters.")

    lines.extend(["", "## Top Long Pair Rules", ""])
    if top_pair_long:
        for row in top_pair_long[:5]:
            lines.append(
                f"- `{row['rule_a']}` + `{row['rule_b']}` horizon `{int(row['horizon'])}`: "
                f"train `{row['train_tpd']:.2f}/day exp {row['train_expectancy']:.4f}`, "
                f"test `{row['test_tpd']:.2f}/day exp {row['test_expectancy']:.4f}`, "
                f"hit `{row['test_hit_rate']:.2%}`"
            )
    else:
        lines.append("- No long pair rule cleared the turnover and expectancy filters.")

    lines.extend(["", "## Top Short Pair Rules", ""])
    if top_pair_short:
        for row in top_pair_short[:5]:
            lines.append(
                f"- `{row['rule_a']}` + `{row['rule_b']}` horizon `{int(row['horizon'])}`: "
                f"train `{row['train_tpd']:.2f}/day exp {row['train_expectancy']:.4f}`, "
                f"test `{row['test_tpd']:.2f}/day exp {row['test_expectancy']:.4f}`, "
                f"hit `{row['test_hit_rate']:.2%}`"
            )
    else:
        lines.append("- No short pair rule cleared the turnover and expectancy filters.")

    lines.extend(["", "## Next Step", ""])
    if top_pair_long or top_pair_short:
        lines.append("- Use the best pair rules as the first entry masks for a new mainline prototype.")
        lines.append("- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.")
    elif top_long or top_short:
        lines.append("- Convert the strongest repeated feature zones into a small set of entry masks for a new mainline family.")
        lines.append("- Prefer pairwise combinations from the top single-feature rules before any large parameter sweep.")
    else:
        lines.append("- Expand the feature set or change timeframe because no single-feature rule cleared the high-turnover filter.")
    return payload, "\n".join(lines) + "\n"


def write_outputs(
    output_dir: Path,
    analysis_df: pd.DataFrame,
    correlations_df: pd.DataFrame,
    rules_df: pd.DataFrame,
    pair_rules_df: pd.DataFrame,
    summary_payload: dict[str, Any],
    summary_md: str,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    analysis_df.to_csv(output_dir / "analysis_window_features.csv.gz", index=False, compression="gzip")
    correlations_df.to_csv(output_dir / "feature_correlations.csv", index=False)
    correlations_df.to_csv(output_dir / "feature_correlations.csv.gz", index=False, compression="gzip")
    rules_df.to_csv(output_dir / "single_feature_rules.csv", index=False)
    rules_df.to_csv(output_dir / "single_feature_rules.csv.gz", index=False, compression="gzip")
    pair_rules_df.to_csv(output_dir / "pair_feature_rules.csv", index=False)
    pair_rules_df.to_csv(output_dir / "pair_feature_rules.csv.gz", index=False, compression="gzip")
    (output_dir / "summary.json").write_text(json.dumps(summary_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output_dir / "summary.md").write_text(summary_md, encoding="utf-8")


def main() -> int:
    args = parse_args()
    terminal_path = load_terminal_path(args.terminal_path)
    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol, args.timeframe)

    initialize_mt5(terminal_path)
    try:
        rates = load_rates_by_range(args.symbol, args.timeframe, args.analysis_days + 120, args.bars)
    finally:
        mt5.shutdown()

    enriched, feature_columns = enrich_features(rates)
    analysis_df = trim_latest_window(enriched, args.analysis_days)
    train_mask, test_mask, split_date = split_masks(analysis_df, args.oos_days)
    correlations_df = correlations_by_split(analysis_df, feature_columns, train_mask, test_mask)
    rules_df = mine_single_feature_rules(
        analysis_df,
        feature_columns,
        train_mask,
        test_mask,
        min_samples=args.min_samples,
        min_trades_per_day=args.min_trades_per_day,
        min_coverage=args.min_coverage,
        max_coverage=args.max_coverage,
    )
    pair_rules_df = mine_pair_rules(
        analysis_df,
        rules_df,
        train_mask,
        test_mask,
        min_samples=args.min_samples,
        min_trades_per_day=args.min_trades_per_day,
        min_coverage=args.min_coverage,
        max_coverage=args.max_coverage,
    )

    metadata = {
        "symbol": args.symbol,
        "timeframe": args.timeframe,
        "bars_requested": args.bars,
        "analysis_days": args.analysis_days,
        "oos_days": args.oos_days,
        "min_coverage": args.min_coverage,
        "max_coverage": args.max_coverage,
        "history_start": analysis_df["time"].iloc[0].isoformat(),
        "history_end": analysis_df["time"].iloc[-1].isoformat(),
        "train_start": analysis_df.loc[train_mask, "time"].iloc[0].isoformat(),
        "train_end": analysis_df.loc[train_mask, "time"].iloc[-1].isoformat(),
        "test_start": analysis_df.loc[test_mask, "time"].iloc[0].isoformat(),
        "test_end": analysis_df.loc[test_mask, "time"].iloc[-1].isoformat(),
        "split_date": split_date.isoformat(),
        "feature_count": len(feature_columns),
        "rule_count": int(len(rules_df)),
        "pair_rule_count": int(len(pair_rules_df)),
    }
    summary_payload, summary_md = render_summary(metadata, correlations_df, rules_df, pair_rules_df)
    write_outputs(output_dir, analysis_df, correlations_df, rules_df, pair_rules_df, summary_payload, summary_md)

    print(f"Output dir: {output_dir}")
    print(f"Split date: {split_date.isoformat()}")
    print(f"Feature count: {len(feature_columns)}")
    print(f"Rule count: {len(rules_df)}")
    print(f"Pair rule count: {len(pair_rules_df)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
