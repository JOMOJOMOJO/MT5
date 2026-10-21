import json
import sys
from types import SimpleNamespace

import pandas as pd
import pytest

from tools.entry_research.data import fetch_mt5, import_archives


def epoch(text):
    return int(pd.Timestamp(text, tz="UTC").timestamp())


def frame(times, spread=10):
    times = [epoch(t) for t in times]
    return pd.DataFrame({"time": times, "available_at": [t + 300 for t in times],
                         "open": 140., "high": 141., "low": 139., "close": 140.5,
                         "tick_volume": 10, "spread": spread})


@pytest.fixture
def archives(tmp_path):
    old = frame(["2023-12-29 23:55", "2024-01-02 00:00", "2024-12-31 23:50"])
    new = frame(["2024-12-31 23:50", "2025-01-02 00:00", "2025-12-31 23:50"], spread=1)
    for year, data in [(2024, old), (2025, new)]:
        directory = tmp_path / str(year)
        directory.mkdir()
        data.to_csv(directory / "TW_ml_bars_PERIOD_M5.csv", index=False)
    config = {"archive_sources": [{"year": 2024, "root": "2024"}, {"year": 2025, "root": "2025"}],
              "symbol": "USDJPY", "point": .001, "pip_size": .01,
              "start": "2024-01-01", "end": "2026-01-01", "timeframes": {"M5": 300}}
    return tmp_path, config


def test_original_year_source_and_warmup_preserved(archives):
    repo, config = archives
    output = repo / "output"
    bars = import_archives(repo, output, config)["M5"]
    assert len(bars) == 5
    assert bars.iloc[0].time == epoch("2023-12-29 23:55")
    assert bars.loc[bars.time == epoch("2024-12-31 23:50"), "spread"].item() == 10
    assert (bars.available_time >= bars.close_time).all()
    assert str(bars.time.dtype) == "int64"
    assert bars.equals(pd.read_parquet(output / "M5.parquet"))
    manifest = json.loads((output / "dataset_manifest.json").read_text())
    assert manifest["overlap_audit"][0]["spread_conflicting_rows"] == 1
    assert manifest["source_broker_server"] == "unknown"
    assert manifest["real_tick_start"] is None
    assert manifest["holdout_2026_locked"]
    assert len(manifest["outputs_sha256"]) == 3
    coverage = pd.read_csv(output / "coverage.csv")
    assert coverage.rows.tolist() == [2, 2]
    assert (coverage.missing_weekday_slots_unclassified > 0).all()


def test_collector_delayed_availability_survives(archives):
    repo, config = archives
    path = repo / "2024/TW_ml_bars_PERIOD_M5.csv"
    data = pd.read_csv(path)
    data.loc[1, "available_at"] += 7
    data.to_csv(path, index=False)
    bars = import_archives(repo, repo / "output", config)["M5"]
    assert bars.iloc[1].available_time == bars.iloc[1].close_time + 7


@pytest.mark.parametrize("corruption", ["duplicate", "unordered", "ohlc", "nan", "negative_spread", "early_availability", "nonmonotonic_availability", "unaligned"])
def test_invalid_contract_rejected_without_output(archives, corruption):
    repo, config = archives
    path = repo / "2024/TW_ml_bars_PERIOD_M5.csv"
    data = pd.read_csv(path)
    if corruption == "duplicate":
        data.loc[1, "time"] = data.loc[0, "time"]
    elif corruption == "unordered":
        data = data.iloc[::-1]
    elif corruption == "ohlc":
        data.loc[0, "high"] = 138
    elif corruption == "nan":
        data.loc[0, "close"] = float("nan")
    elif corruption == "negative_spread":
        data.loc[0, "spread"] = -1
    elif corruption == "early_availability":
        data.loc[0, "available_at"] = data.loc[0, "time"]
    elif corruption == "nonmonotonic_availability":
        data.loc[0, "available_at"] = data.loc[1, "available_at"] + 1
    else:
        data.loc[0, "time"] += 1
    data.to_csv(path, index=False)
    with pytest.raises(ValueError):
        import_archives(repo, repo / "output", config)
    assert not (repo / "output").exists()


def test_holdout_end_and_source_year_locked(archives):
    repo, config = archives
    with pytest.raises(ValueError, match="holdout is locked"):
        import_archives(repo, repo / "output", dict(config, end="2026-01-02"))
    bad = dict(config, archive_sources=[{"year": 2026, "root": "never-read"}])
    with pytest.raises(ValueError, match="locked 2026"):
        import_archives(repo, repo / "output", bad)
    path = repo / "2025/TW_ml_bars_PERIOD_M5.csv"
    frame(["2026-01-01 00:00"]).to_csv(path, index=False)
    with pytest.raises(ValueError, match="exclusive research end"):
        import_archives(repo, repo / "output", config)


def test_no_output_overwrite(archives):
    repo, config = archives
    output = repo / "output"
    import_archives(repo, output, config)
    original = (output / "M5.parquet").read_bytes()
    with pytest.raises(FileExistsError):
        import_archives(repo, output, config)
    assert (output / "M5.parquet").read_bytes() == original


def test_mt5_outside_requested_range_is_rejected(tmp_path, monkeypatch):
    calls = []
    def copy(symbol, tf, start, end):
        assert start.utcoffset().total_seconds() == 0
        assert end.utcoffset().total_seconds() == 0
        calls.append((start, end))
        return frame(["2025-06-01 00:00"]).drop(columns="available_at").to_records(index=False)
    fake = SimpleNamespace(initialize=lambda **kwargs: True,
                           terminal_info=lambda: SimpleNamespace(maxbars=100000),
                           symbol_info=lambda symbol: SimpleNamespace(point=.001, digits=3),
                           account_info=lambda: SimpleNamespace(server="test"),
                           copy_rates_range=copy, TIMEFRAME_M5=5,
                           shutdown=lambda: calls.append("shutdown"))
    monkeypatch.setitem(sys.modules, "MetaTrader5", fake)
    with pytest.raises(ValueError, match="out-of-range timestamps"):
        fetch_mt5("unused.exe", "USDJPY", "2025-01-01", "2025-02-01", tmp_path / "out", {"M5": 300})
    assert calls[-1] == "shutdown"
    assert not (tmp_path / "out").exists()


def test_mt5_holdout_rejected_before_initialization(tmp_path, monkeypatch):
    fake = SimpleNamespace(initialize=lambda **kwargs: pytest.fail("must not initialize"))
    monkeypatch.setitem(sys.modules, "MetaTrader5", fake)
    with pytest.raises(ValueError, match="holdout is locked"):
        fetch_mt5("unused.exe", "USDJPY", "2026-01-01", "2027-01-01", tmp_path / "out")
