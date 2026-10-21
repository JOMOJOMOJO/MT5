import numpy as np
import pandas as pd
import pytest

from tools.entry_research.diagnostics.paths import classify_paths, iter_path_curves, path_curve


def fixture():
    bars = pd.DataFrame({"time": np.arange(52) * 300, "open": 100., "high": 100.1,
                         "low": 99.9, "close": 100., "atr14": 1000.})
    bars["source_available_at"] = bars.time + 300
    candidates = pd.DataFrame({"candidate_id": ["original-L"], "side": ["LONG"], "method": ["fixture"],
                               "signal_index": [0], "entry_index": [1], "signal_time": [300],
                               "nominal_close_time": [300], "entry_time": [300], "atr14": [1.],
                               "eligible": [True], "week": ["1970-01-01"], "year": [1970]})
    return bars, candidates, {"base_config": {"pip_size": .01, "timeframe_seconds": 300,
                                             "end_exclusive": 16000}, "classification": {}}


def classify(bars, candidates, config):
    return classify_paths(bars, candidates, config).iloc[0]


@pytest.mark.parametrize("kind,expected", [
    ("favorable_then_reversal", "favorable_then_reversal"),
    ("adverse_then_favorable", "adverse_then_favorable"),
    ("immediate_adverse", "immediate_adverse"),
    ("favorable_continuation", "favorable_continuation"),
    ("no_direction", "no_direction"),
    ("other", "unclassified_other"),
])
def test_fixed_class_definitions(kind, expected):
    bars, candidates, config = fixture()
    if kind == "favorable_then_reversal":
        bars.loc[2, "high"] = 100.6
        bars.loc[5, "low"] = 99.4
    elif kind == "adverse_then_favorable":
        bars.loc[2, "low"] = 99.4
        bars.loc[5, "high"] = 100.6
    elif kind == "immediate_adverse":
        bars.loc[3, "low"] = 99.4
        bars.loc[50, ["low", "close"]] = [99.7, 99.75]
    elif kind == "favorable_continuation":
        bars.loc[2, "high"] = 100.6
        bars.loc[43:50, ["high", "close"]] = [100.6, 100.3]
        bars.loc[50, "close"] = 100.5
    elif kind == "other":
        bars.loc[4, "low"] = 99.4
    row = classify(bars, candidates, config)
    assert row.complete
    assert row.class_label == expected


@pytest.mark.parametrize("opening,expected,resolution", [
    (100., "ambiguous_order", "same_bar_unknown"),
    (100.5, "favorable_then_reversal", "same_bar_open_resolved"),
    (99.5, "adverse_then_favorable", "same_bar_open_resolved"),
])
def test_double_touch_unknown_and_open_known(opening, expected, resolution):
    bars, candidates, config = fixture()
    bars.loc[2, ["open", "high", "low", "close"]] = [opening, 100.7, 99.3, 100.]
    row = classify(bars, candidates, config)
    assert row.class_label == expected
    assert row.order_resolution == resolution
    assert row.first_favorable_bar == row.first_adverse_bar == 2


def test_ambiguous_first_bar_overrides_later_path():
    bars, candidates, config = fixture()
    bars.loc[1, ["high", "low"]] = [100.6, 99.4]
    bars.loc[45:50, ["high", "close"]] = [101., 100.8]
    assert classify(bars, candidates, config).class_label == "ambiguous_order"


def test_tail_count_and_terminal_must_both_pass():
    bars, candidates, config = fixture()
    bars.loc[2, "high"] = 100.6
    bars.loc[44:50, ["high", "close"]] = [100.6, 100.3]
    bars.loc[50, "close"] = 100.5
    row = classify(bars, candidates, config)
    assert row.tail_closes_above_floor == 7
    assert row.class_label == "unclassified_other"
    bars.loc[43, ["high", "close"]] = [100.6, 100.3]
    assert classify(bars, candidates, config).class_label == "favorable_continuation"
    bars.loc[50, "close"] = 100.4
    assert classify(bars, candidates, config).class_label == "unclassified_other"


def test_atr_and_entry_price_remain_frozen_and_cost_once():
    bars, candidates, config = fixture()
    bars.loc[1, ["high", "close"]] = [100.4, 100.2]
    bars.loc[2, ["open", "high", "low", "close"]] = [100.2, 100.8, 100.1, 100.6]
    curve = path_curve(bars, candidates, config)
    assert len(curve) == 50
    assert curve.iloc[0].gross_atr == pytest.approx(.2)
    assert curve.iloc[1].gross_atr == pytest.approx(.6)
    assert curve.iloc[1].mfe_atr == pytest.approx(.8)
    assert curve.iloc[1].mae_atr == pytest.approx(.1)
    assert curve.iloc[1].net_pips == pytest.approx(60 - 1.9)
    assert curve.iloc[1].net_atr == pytest.approx(.6 - .019)
    assert (curve.gross_pips - curve.net_pips).to_numpy() == pytest.approx(np.full(50, 1.9))
    # A different observed bar ATR never changes the signal-frozen denominator.
    bars["atr14"] *= 10
    pd.testing.assert_frame_equal(curve, path_curve(bars, candidates, config))


def test_long_short_price_mirror():
    bars, candidates, config = fixture()
    bars.loc[2, ["high", "close"]] = [100.8, 100.6]
    bars.loc[6, ["low", "close"]] = [99.2, 99.4]
    original = classify(bars, candidates, config)
    original_curve = path_curve(bars, candidates, config)
    mirror = bars.copy()
    mirror["open"], mirror["close"] = 200 - bars.open, 200 - bars.close
    mirror["high"], mirror["low"] = 200 - bars.low, 200 - bars.high
    candidates["side"] = "SHORT"
    mirrored = classify(mirror, candidates, config)
    mirrored_curve = path_curve(mirror, candidates, config)
    for column in ["class_label", "first_favorable_bar", "first_adverse_bar", "mfe_atr", "mae_atr", "terminal_atr"]:
        assert original[column] == mirrored[column]
    np.testing.assert_allclose(original_curve[["gross_pips", "net_pips", "mfe_atr", "mae_atr"]],
                               mirrored_curve[["gross_pips", "net_pips", "mfe_atr", "mae_atr"]])


@pytest.mark.parametrize("case", ["gap", "short", "end", "entry_mismatch", "source_unavailable", "invalid_atr", "invalid_ohlc"])
def test_unclassifiable_data_and_no_partial_curve(case):
    bars, candidates, config = fixture()
    if case == "gap":
        bars.loc[20:, "time"] += 300
    elif case == "short":
        bars = bars.iloc[:40]
    elif case == "end":
        config["base_config"]["end_exclusive"] = 15299
    elif case == "entry_mismatch":
        candidates["entry_time"] = 600
    elif case == "source_unavailable":
        bars.loc[0, "source_available_at"] = 301
    elif case == "invalid_atr":
        candidates["atr14"] = 0
    else:
        bars.loc[20, "high"] = 99
    row = classify(bars, candidates, config)
    assert row.class_label == "unclassifiable_data"
    assert not row.complete
    assert not row.common_pool
    assert np.isnan(row.terminal_atr)
    assert np.isnan(row.first_favorable_bar)
    assert path_curve(bars, candidates, config).empty


def test_original_eligible_cohort_and_metadata_preserved():
    bars, candidates, config = fixture()
    second = candidates.copy()
    second["candidate_id"], second["eligible"] = "excluded", False
    candidates = pd.concat([candidates, second], ignore_index=True)
    candidates["origin_candidate_id"] = ["origin-one", "origin-two"]
    candidates["replicate"] = 2
    classes = classify_paths(bars, candidates, config)
    assert classes.complete.all()
    assert classes.common_pool.tolist() == [True, False]
    assert classes.origin_candidate_id.tolist() == ["origin-one", "origin-two"]
    chunks = list(iter_path_curves(bars, candidates, config, chunk_size=1))
    assert len(chunks) == 1
    assert set(chunks[0].candidate_id) == {"original-L"}
    assert set(chunks[0].origin_candidate_id) == {"origin-one"}
    assert set(chunks[0].replicate) == {2}
    assert chunks[0].horizon.tolist() == list(range(1, 51))


def test_no_mutation_of_inputs():
    bars, candidates, config = fixture()
    old_bars, old_candidates = bars.copy(deep=True), candidates.copy(deep=True)
    classify_paths(bars, candidates, config)
    path_curve(bars, candidates, config)
    pd.testing.assert_frame_equal(bars, old_bars)
    pd.testing.assert_frame_equal(candidates, old_candidates)


def test_holdout_lock_and_empty_input():
    bars, candidates, config = fixture()
    assert classify_paths(bars, candidates.iloc[:0], config).empty
    assert path_curve(bars, candidates.iloc[:0], config).empty
    config["base_config"]["end_exclusive"] = 1767225601
    with pytest.raises(ValueError, match="holdout"):
        classify_paths(bars, candidates, config)
    config["base_config"]["end_exclusive"] = 1767225600
    bars.loc[51, "time"] = 1767225600
    with pytest.raises(ValueError, match="holdout"):
        classify_paths(bars, candidates, config)
