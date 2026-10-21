"""Read-only price acquisition and provenance-preserving archive import.

All timestamp columns are int64 seconds in the source clock. Archived MQL5
timestamps are broker-server wall-clock values, not verified UTC instants.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd


TIMEFRAMES = {"M1": 60, "M5": 300, "M15": 900, "H1": 3600}
HOLDOUT_START = int(pd.Timestamp("2026-01-01", tz="UTC").timestamp())
REQUIRED = ["time", "available_at", "open", "high", "low", "close", "tick_volume", "spread"]
PRICE_COLUMNS = ["open", "high", "low", "close"]


def _epoch(value: Any) -> int:
    stamp = pd.Timestamp(value)
    stamp = stamp.tz_localize("UTC") if stamp.tzinfo is None else stamp.tz_convert("UTC")
    return int(stamp.timestamp())


def _bounds(start: str, end: str) -> tuple[int, int]:
    left, right = _epoch(start), _epoch(end)
    if left >= right:
        raise ValueError("start must precede end")
    if right > HOLDOUT_START or left >= HOLDOUT_START:
        raise ValueError("2026 holdout is locked: acquisition/import must end by 2026-01-01 exclusive")
    return left, right


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _validate_bars(frame: pd.DataFrame, seconds: int, label: str) -> pd.DataFrame:
    missing = set(REQUIRED) - set(frame.columns)
    if missing:
        raise ValueError(f"{label}: missing columns {sorted(missing)}")
    if frame.empty:
        raise ValueError(f"{label}: no bars")
    data = frame[REQUIRED].copy()
    for column in REQUIRED:
        data[column] = pd.to_numeric(data[column], errors="raise")
    if not np.isfinite(data.to_numpy(dtype=float)).all():
        raise ValueError(f"{label}: nonfinite/missing numeric value")
    for column in ["time", "available_at", "tick_volume", "spread"]:
        if (data[column] != np.floor(data[column])).any():
            raise ValueError(f"{label}: noninteger {column}")
        data[column] = data[column].astype("int64")
    if data.time.duplicated().any() or not data.time.is_monotonic_increasing:
        raise ValueError(f"{label}: duplicate or unordered timestamps")
    if (data.time % seconds != 0).any():
        raise ValueError(f"{label}: timestamps not aligned to timeframe")
    if (data[PRICE_COLUMNS] <= 0).any().any():
        raise ValueError(f"{label}: nonpositive OHLC")
    if ((data.high < data[["open", "close", "low"]].max(axis=1)) |
            (data.low > data[["open", "close", "high"]].min(axis=1))).any():
        raise ValueError(f"{label}: invalid OHLC ordering")
    if (data[["spread", "tick_volume"]] < 0).any().any():
        raise ValueError(f"{label}: negative spread or volume")
    if (data.available_at < data.time + seconds).any():
        raise ValueError(f"{label}: source claims availability before bar close")
    if not data.available_at.is_monotonic_increasing:
        raise ValueError(f"{label}: availability timestamps move backwards; indicators would read unreleased history")
    return data


def _output_paths(out: Path, timeframes: dict[str, int]) -> list[Path]:
    return [out / f"{tf}.parquet" for tf in timeframes] + [
        out / "dataset_manifest.json", out / "coverage.csv", out / "gaps.csv"]


def _check_outputs(out: Path, timeframes: dict[str, int]) -> None:
    present = [str(path) for path in _output_paths(out, timeframes) if path.exists()]
    if present:
        raise FileExistsError(f"Dataset outputs already exist; use a new directory: {present}")


def _coverage(bars: dict[str, pd.DataFrame], timeframes: dict[str, int],
              left: int, right: int) -> tuple[pd.DataFrame, pd.DataFrame]:
    coverage, gaps = [], []
    first_year = pd.to_datetime(left, unit="s").year
    last_year = pd.to_datetime(right - 1, unit="s").year
    for tf, data in bars.items():
        seconds = timeframes[tf]
        study = data.loc[data.time.between(left, right - 1)]
        for previous, current in zip(study.time.iloc[:-1], study.time.iloc[1:]):
            if current - previous > seconds:
                gaps.append({"timeframe": tf, "previous_bar_time": int(previous),
                             "next_bar_time": int(current), "gap_seconds": int(current - previous),
                             "absent_nominal_slots": int((current - previous) // seconds - 1),
                             "classification": "unclassified_market_closure_or_missing_data"})
        for year in range(first_year, last_year + 1):
            a, b = max(left, _epoch(f"{year}-01-01")), min(right, _epoch(f"{year + 1}-01-01"))
            yearly = study.loc[study.time.between(a, b - 1)]
            dates = pd.to_datetime(yearly.time, unit="s")
            expected = np.arange(a + (-a % seconds), b, seconds, dtype=np.int64)
            expected = expected[pd.to_datetime(expected, unit="s").dayofweek < 5]
            absent = np.setdiff1d(expected, yearly.time.to_numpy(), assume_unique=True)
            row = {"timeframe": tf, "year": year, "rows": len(yearly),
                   "first_time": int(yearly.time.min()) if len(yearly) else None,
                   "last_time": int(yearly.time.max()) if len(yearly) else None,
                   "max_gap_seconds": int(yearly.time.diff().max()) if len(yearly) > 1 else None,
                   "missing_weekday_slots_unclassified": len(absent),
                   "missing_slots_include_holidays_and_session_closures": True,
                   "months_present": ",".join(map(str, sorted(dates.dt.month.unique())))}
            row.update({f"month_{month:02d}_rows": int((dates.dt.month == month).sum())
                        for month in range(1, 13)})
            coverage.append(row)
    return pd.DataFrame(coverage), pd.DataFrame(gaps, columns=[
        "timeframe", "previous_bar_time", "next_bar_time", "gap_seconds",
        "absent_nominal_slots", "classification"])


def _write_dataset(out: Path, bars: dict[str, pd.DataFrame], manifest: dict,
                   timeframes: dict[str, int], left: int, right: int) -> None:
    _check_outputs(out, timeframes)
    out.mkdir(parents=True, exist_ok=True)
    coverage, gaps = _coverage(bars, timeframes, left, right)
    for tf, data in bars.items():
        # Exclusive file creation protects previously produced artifacts.
        with (out / f"{tf}.parquet").open("xb") as handle:
            data.to_parquet(handle, index=False)
    with (out / "coverage.csv").open("x", encoding="utf-8", newline="") as handle:
        coverage.to_csv(handle, index=False)
    with (out / "gaps.csv").open("x", encoding="utf-8", newline="") as handle:
        gaps.to_csv(handle, index=False)
    manifest["outputs_sha256"] = {p.name: _sha256(p) for p in _output_paths(out, timeframes)
                                  if p.name != "dataset_manifest.json"}
    with (out / "dataset_manifest.json").open("x", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False, allow_nan=False)


def import_archives(repo: Path, out: Path, config: dict) -> dict[str, pd.DataFrame]:
    """Import original collector OHLC without revising past years using later files.

    The earliest source supplies its own year plus initialization history. Later
    sources supply only their own year. Overlapping history is audited, never
    used to revise earlier source rows. End is exclusive and 2026 is locked.
    """
    repo, out = Path(repo), Path(out)
    left, right = _bounds(config["start"], config["end"])
    timeframes = dict(config.get("timeframes", TIMEFRAMES))
    if not timeframes or any(tf not in TIMEFRAMES or sec != TIMEFRAMES[tf]
                             for tf, sec in timeframes.items()):
        raise ValueError("Unsupported timeframe or timeframe duration")
    _check_outputs(out, timeframes)
    sources = sorted(config["archive_sources"], key=lambda s: int(s["year"]))
    years = [int(source["year"]) for source in sources]
    if not years or len(set(years)) != len(years) or any(year >= 2026 for year in years):
        raise ValueError("Archive sources must have distinct years before locked 2026")
    known_initial_sources = {
        (2024, "reports/qa/three_wave/ready_2024_ml/annual_2024"),
        (2025, "reports/qa/three_wave/ready_multiyear_ml/annual_2025"),
    }
    initial_provenance_verified = all(
        (int(source["year"]), str(source["root"]).replace("\\", "/").rstrip("/")) in known_initial_sources
        for source in sources)
    bars, provenance, overlaps = {}, [], []
    for tf, seconds in timeframes.items():
        parts, previously_read = [], []
        for position, source in enumerate(sources):
            year = int(source["year"])
            path = repo / source["root"] / f"TW_ml_bars_PERIOD_{tf}.csv"
            raw = pd.read_csv(path)
            # Reject holdout or out-of-request future rows before feature processing.
            if "time" not in raw or (pd.to_numeric(raw.time, errors="raise") >= right).any():
                raise ValueError(f"{path}: row at/after exclusive research end; refuse future data")
            data = _validate_bars(raw, seconds, str(path))
            for earlier_path, earlier in previously_read:
                common = earlier.merge(data, on="time", suffixes=("_earlier", "_later"))
                if len(common):
                    a = common[[f"{c}_earlier" for c in PRICE_COLUMNS]].to_numpy()
                    b = common[[f"{c}_later" for c in PRICE_COLUMNS]].to_numpy()
                    overlaps.append({"timeframe": tf, "earlier_source": earlier_path,
                                     "later_source": str(path), "overlap_rows": len(common),
                                     "ohlc_conflicting_rows": int((a != b).any(axis=1).sum()),
                                     "spread_conflicting_rows": int((common.spread_earlier != common.spread_later).sum()),
                                     "resolution": "keep_original_year_source_never_revise_with_later_warmup"})
            previously_read.append((str(path), data))
            lower = -np.inf if position == 0 else _epoch(f"{year}-01-01")
            upper = min(right, _epoch(f"{year + 1}-01-01"))
            selected = data.loc[(data.time >= lower) & (data.time < upper)].copy()
            selected = selected.rename(columns={"available_at": "source_available_at"})
            selected["close_time"] = selected.time + seconds
            selected["available_time"] = selected[["close_time", "source_available_at"]].max(axis=1).astype("int64")
            selected["source_file"] = str(path.relative_to(repo)) if path.is_relative_to(repo) else str(path)
            parts.append(selected)
            provenance.append({"timeframe": tf, "year": year, "path": str(path),
                               "sha256": _sha256(path), "raw_rows": len(data), "selected_rows": len(selected),
                               "first_raw_time": int(data.time.min()), "last_raw_time": int(data.time.max()),
                               "spread_zero_rows": int((selected.spread == 0).sum())})
        joined = pd.concat(parts, ignore_index=True).sort_values("time").reset_index(drop=True)
        if joined.time.duplicated().any():
            raise ValueError(f"{tf}: duplicate time after applying source precedence")
        if not joined.available_time.is_monotonic_increasing:
            raise ValueError(f"{tf}: source boundary creates nonmonotonic availability")
        if joined.empty or not joined.time.between(left, right - 1).any():
            raise ValueError(f"{tf}: no data in requested research period")
        bars[tf] = joined
    manifest = {"schema_version": 1, "mode": "archived_mt5_collector",
                "symbol": config["symbol"], "point": config["point"], "pip_size": config["pip_size"],
                "requested_start": config["start"], "requested_end_exclusive": config["end"],
                "timeframes": timeframes, "clock_basis": config.get("clock_basis", "broker_server_unverified"),
                "geographic_sessions_status": "UNKNOWN_historical_server_UTC_mapping_unverified",
                "timestamp_unit": "integer_seconds_in_source_clock", "holdout_2026_locked": True,
                "source_broker_server": config.get("source_broker_server", "Bybit-Live" if initial_provenance_verified else "unknown"),
                "source_precedence": "original_year_source; earliest source supplies warmup; later warmup audit only",
                "availability_semantics": "max(nominal_bar_close, collector_first_observed_time)",
                "price_basis": "MT5_bid_OHLC", "spread_basis": "archived_bar_proxy_not_execution_quote",
                "real_tick_start": config.get("real_tick_start", "2024-06-06" if initial_provenance_verified else None),
                "tick_sequence_available": False,
                "limitations": (["2024 data before June 6 has no verified real tick provenance",
                                  "Existing collection_quality.json records warning days including 2025-03-27"]
                                 if initial_provenance_verified else ["Archive broker and real-tick provenance require independent verification"]) + [
                                "Model=4 does not guarantee every interval used actual ticks",
                                "Missing nominal weekday slots include closures/holidays; no exchange calendar verified",
                                "Source bar spread may be zero or revised and is not actual round-trip execution cost",
                                "Annual collector shutdown omits some final-year closing bars"],
                "sources": provenance, "overlap_audit": overlaps}
    _write_dataset(out, bars, manifest, timeframes, left, right)
    return bars


def fetch_mt5(terminal: str, symbol: str, start: str, end: str, out: Path,
              timeframes: dict[str, int] | None = None) -> dict[str, pd.DataFrame]:
    """Fetch monthly UTC API ranges, validating every returned timestamp.

    Read-only market-data API use: no orders, credentials, restarts or terminal
    settings are changed. A malformed/out-of-range response fails closed.
    Historical source availability is unknown, so this path labels nominal-close
    availability as an assumption rather than a collector observation.
    """
    left, right = _bounds(start, end)
    timeframes = dict(TIMEFRAMES if timeframes is None else timeframes)
    if not timeframes or any(tf not in TIMEFRAMES or sec != TIMEFRAMES[tf]
                             for tf, sec in timeframes.items()):
        raise ValueError("Unsupported timeframe or timeframe duration")
    out = Path(out)
    _check_outputs(out, timeframes)
    import MetaTrader5 as mt5

    if not mt5.initialize(path=str(terminal)):
        raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")
    bars, requests = {}, []
    try:
        terminal_info = mt5.terminal_info()
        info = mt5.symbol_info(symbol)
        if info is None:
            raise ValueError(f"MT5 symbol unavailable: {symbol}")
        account = mt5.account_info()
        server = getattr(account, "server", "unknown")
        for tf, seconds in timeframes.items():
            chunks = []
            cursor = pd.Timestamp(left, unit="s", tz="UTC")
            stop = pd.Timestamp(right, unit="s", tz="UTC")
            while cursor < stop:
                next_month = (cursor.normalize().replace(day=1) + pd.offsets.MonthBegin(1))
                finish = min(next_month, stop)
                utc_start = cursor.to_pydatetime()
                utc_end = (finish - pd.Timedelta(seconds=1)).to_pydatetime()
                rates = mt5.copy_rates_range(symbol, getattr(mt5, f"TIMEFRAME_{tf}"), utc_start, utc_end)
                if rates is None:
                    raise RuntimeError(f"MT5 rates failed {tf} {cursor}: {mt5.last_error()}")
                frame = pd.DataFrame(rates)
                if len(frame):
                    if "time" not in frame or ((frame.time < int(cursor.timestamp())) |
                                               (frame.time >= int(finish.timestamp()))).any():
                        raise ValueError(f"MT5 {tf}: out-of-range timestamps returned; refusing wrong-period history")
                    frame["available_at"] = frame.time + seconds
                    chunks.append(_validate_bars(frame, seconds, f"MT5 {tf} {cursor}"))
                requests.append({"timeframe": tf, "start_utc": utc_start.isoformat(),
                                 "end_exclusive_utc": finish.isoformat(), "returned_rows": len(frame)})
                cursor = finish
            if not chunks:
                raise ValueError(f"MT5 {tf}: no data in requested range")
            data = pd.concat(chunks, ignore_index=True)
            if data.time.duplicated().any() or not data.time.is_monotonic_increasing:
                raise ValueError(f"MT5 {tf}: duplicate/unordered chunk boundary")
            data = data.rename(columns={"available_at": "source_available_at"})
            data["close_time"] = data.time + seconds
            data["available_time"] = data.close_time
            data["source_file"] = f"mt5:{server}:{symbol}:{tf}"
            bars[tf] = data
        manifest = {"schema_version": 1, "mode": "mt5_api_monthly_UTC_requests", "symbol": symbol,
                    "requested_start": start, "requested_end_exclusive": end,
                    "holdout_2026_locked": True, "timeframes": timeframes,
                    "clock_basis": "MT5_API_UTC_contract_unverified_against_broker_chart",
                    "source_broker_server": server,
                    "terminal_maxbars": getattr(terminal_info, "maxbars", None),
                    "point": float(info.point), "digits": int(info.digits),
                    "pip_size": float(info.point) * (10 if int(info.digits) in (3, 5) else 1),
                    "availability_semantics": "ASSUMED_nominal_close_not_observed_historical_availability",
                    "spread_basis": "MT5_bar_proxy_not_execution_quote", "tick_sequence_available": False,
                    "requests": requests,
                    "limitations": ["API chart-history limit may truncate available data; see coverage.csv",
                                    "No historical order fills, tick sequence or commission/slippage history acquired"]}
    finally:
        mt5.shutdown()
    _write_dataset(out, bars, manifest, timeframes, left, right)
    return bars
