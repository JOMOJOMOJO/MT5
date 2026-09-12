"""Synthetic, independent checks for the technical ML discovery analysis.

No monthly outcome file is loaded.  Prices, profits and expected values below
are hand specified; this module never constructs expected values by fitting the
production analysis implementation.
"""
from __future__ import annotations

import unittest

import numpy as np
import pandas as pd

import technical_ml_discovery as ml


def action(episode_id="a", *, processing=1_000, entry=1_001,
           exit=2_000, status="TP", direction=1, score=.3,
           gross_r=1., gross_pips=10., month=202501, t0=None):
    """One complete quote-side result with a ten-pip initial risk."""
    return dict(episode_id=episode_id, symbol="EURUSD", direction=direction,
                market_cluster_id="cluster_" + episode_id, month=month,
                signal_processing_msc=processing,
                t0_msc=processing if t0 is None else t0,
                entry_msc=entry, exit_msc=exit, status=status, score=score,
                long_score=score if direction == 1 else -.1,
                short_score=score if direction == -1 else -.1,
                gross_r=gross_r, gross_pips=gross_pips, distance=.001,
                pip_size=.0001, entry_spread=.0002, calendar_segment=0,
                session="LONDON", distance_index=1, distance_atr=.5)


def outcome_rows(records):
    """Outcome CSV schema has no model scores; do not create merge suffixes."""
    return pd.DataFrame(records).drop(columns=["score", "long_score", "short_score"])


class FeatureUnitTests(unittest.TestCase):
    def test_raw_price_and_atr_units_are_removed(self):
        for name in ("quote_mid", "quote_spread", "m1_atr7", "m5_atr14",
                     "m15_atr28", "m1_ema20_value", "m5_sma50_value",
                     "m15_tick_volume"):
            with self.subTest(name=name):
                self.assertTrue(ml.raw_scale_feature(name))

    def test_normalized_market_information_is_retained(self):
        for name in ("shock_direction", "m1_atr7_atr28", "m5_atr14_price",
                     "m15_atr14_pct64", "m1_atr14_z64", "m5_spread_atr",
                     "m1_tick_volume_rel20", "m15_tick_volume_pct64",
                     "m5_ema20_price_gap_atr", "m5_ema20_slope1_atr"):
            with self.subTest(name=name):
                self.assertFalse(ml.raw_scale_feature(name))


class CausalActionTests(unittest.TestCase):
    def test_higher_score_invalid_side_never_switches_to_winning_side(self):
        episodes = pd.DataFrame([dict(episode_id="a")])
        outcomes = outcome_rows([
            action(direction=1, status="INVALID_BROKER_STOP", gross_r=np.nan),
            action(direction=-1, status="TP", gross_r=1.),
        ])
        chosen = ml.choose_actions(outcomes, episodes,
                                   np.array([.5]), np.array([.4]))
        self.assertEqual(chosen.direction.tolist(), [1])
        trades, skips = ml.simulate(chosen, .1)
        self.assertEqual(len(trades), 0)
        self.assertEqual(skips["entry_rejections"], 1)

    def test_exact_score_tie_is_no_trade(self):
        episodes = pd.DataFrame([dict(episode_id="a")])
        outcomes = outcome_rows([action(direction=1), action(direction=-1)])
        chosen = ml.choose_actions(outcomes, episodes,
                                   np.array([.4]), np.array([.4]))
        self.assertEqual(len(chosen), 0)

    def test_one_position_overlap_and_release_clock(self):
        actions = pd.DataFrame([
            action("a", processing=1_000, entry=1_001, exit=3_000),
            action("b", processing=2_000, entry=2_001, exit=4_000),
            action("c", processing=3_001, entry=3_002, exit=4_000),
        ])
        trades, skips = ml.simulate(actions, .1)
        self.assertEqual(trades.episode_id.tolist(), ["a", "c"])
        self.assertEqual(skips["overlap_skips"], 1)

    def test_timeout_rejection_reserves_pending_window(self):
        actions = pd.DataFrame([
            action("a", processing=1_000, entry=0, exit=0, status="NO_ENTRY"),
            action("b", processing=30_999, entry=31_000, exit=32_000),
            action("c", processing=31_001, entry=31_002, exit=32_000),
        ])
        trades, skips = ml.simulate(actions, .1)
        self.assertEqual(trades.episode_id.tolist(), ["c"])
        self.assertEqual(skips["entry_rejections"], 1)
        self.assertEqual(skips["overlap_skips"], 1)

    def test_entry_before_processing_is_rejected(self):
        actions = pd.DataFrame([action(processing=1_000, entry=999)])
        with self.assertRaises((AssertionError, ValueError)):
            ml.simulate(actions, .1)

    def test_exit_before_entry_is_rejected(self):
        actions = pd.DataFrame([action(entry=1_001, exit=1_000)])
        with self.assertRaises((AssertionError, ValueError)):
            ml.simulate(actions, .1)


class PayoffOracleTests(unittest.TestCase):
    def test_spread_is_not_charged_twice(self):
        # Ten-pip risk; quote-side TIME payoff = 3 pips = .3R already
        # includes the 2-pip spread. Extra cost .2 pip is exactly .02R.
        trades = pd.DataFrame([action(status="TIME", gross_r=.3,
                                      gross_pips=3.)])
        result = ml.stats(trades, cost=.2)
        self.assertAlmostEqual(result["expectancy_r"], .28, places=12)
        self.assertAlmostEqual(result["expectancy_pips"], 2.8, places=12)
        self.assertEqual(result["timeout"], 1)
        self.assertEqual(result["win_rate"], 1.)

    def test_time_payoffs_and_cost_are_preserved(self):
        # net R [.98, -1.02, .28, -.42] totals -.18, mean -.045.
        trades = pd.DataFrame([
            action("tp", gross_r=1., gross_pips=10.),
            action("sl", status="SL", gross_r=-1., gross_pips=-10.),
            action("time_win", status="TIME", gross_r=.3, gross_pips=3.),
            action("time_loss", status="TIME", gross_r=-.4, gross_pips=-4.),
        ])
        result = ml.stats(trades, cost=.2)
        self.assertAlmostEqual(result["total_r"], -.18, places=12)
        self.assertAlmostEqual(result["expectancy_r"], -.045, places=12)
        self.assertAlmostEqual(result["pf"], 1.26 / 1.44, places=12)
        self.assertEqual(result["tp"], 1)
        self.assertEqual(result["sl"], 1)
        self.assertEqual(result["timeout"], 2)


class ModelTests(unittest.TestCase):
    def test_small_tree_repeated_seed_is_deterministic(self):
        x = np.column_stack([np.linspace(-2., 2., 400),
                             np.tile([0., 1.], 200)])
        y = np.where(x[:, 0] < 0, -.6, .4)
        statuses = np.where(y > 0, "TP", "SL")
        first = ml.ActionModel("SHALLOW_TREE", "NET_R").fit(x, y, statuses)
        second = ml.ActionModel("SHALLOW_TREE", "NET_R").fit(x, y, statuses)
        np.testing.assert_array_equal(first.predict(x), second.predict(x))
        np.testing.assert_array_equal(first.raw_predict(x), second.raw_predict(x))

    def test_tp_probability_retains_time_conditional_payoffs(self):
        # All feature rows are identical. TP probability = 1/4, while
        # E[R|not TP] = (-1 + .4 - .2)/3. Thus E[R] = .05, not -.5.
        x = np.zeros((400, 2))
        y = np.tile([1., -1., .4, -.2], 100)
        statuses = np.tile(["TP", "SL", "TIME", "TIME"], 100)
        model = ml.ActionModel("SHALLOW_TREE", "TP_FIRST").fit(x, y, statuses)
        np.testing.assert_allclose(model.raw_predict(x[:3]), .25, atol=1e-12)
        np.testing.assert_allclose(model.predict(x[:3]), .05, atol=1e-12)


class ChronologicalSplitTests(unittest.TestCase):
    def synthetic_split(self):
        # Jan has 31 days. Its chronological 75% boundary is Jan 24 06:00.
        january = int(pd.Timestamp("2025-01-01").timestamp() * 1000)
        cut = int(pd.Timestamp("2025-01-24 06:00:00").timestamp() * 1000)
        boundary = int(pd.Timestamp("2025-02-01").timestamp() * 1000)
        definitions = [
            ("fit_ok", january + 86_400_000, "fit_ok"),
            ("fit_horizon_minus1", cut - 930_001, "fit_horizon_minus1"),
            ("fit_horizon_equal", cut - 930_000, "fit_horizon_equal"),
            ("fit_horizon_plus1", cut - 929_999, "fit_horizon_plus1"),
            ("late_observed_exit", january + 2 * 86_400_000, "late_observed_exit"),
            ("late_entry_horizon", january + 3 * 86_400_000, "late_entry_horizon"),
            ("cal_ok", cut + 1, "cal_shared"),
            ("fit_shares_cal", january + 4 * 86_400_000, "cal_shared"),
            ("cal_horizon_minus1", boundary - 930_001, "cal_horizon_minus1"),
            ("cal_horizon_equal", boundary - 930_000, "cal_horizon_equal"),
            ("cal_horizon_plus1", boundary - 929_999, "cal_horizon_plus1"),
            ("val_ok", boundary + 86_400_000, "val_shared"),
            ("fit_shares_val", january + 5 * 86_400_000, "val_shared"),
            ("cal_shares_val", cut + 2, "val_shared"),
            ("missing_outcome", january + 6 * 86_400_000, "missing_outcome"),
        ]
        features, outcomes = [], []
        for name, t0, cluster in definitions:
            features.append(dict(episode_id=name, t0_msc=t0,
                                 month=202502 if t0 >= boundary else 202501,
                                 market_cluster_id=cluster))
            if name == "missing_outcome":
                continue
            entry, exit = t0 + 1, t0 + 100
            if name == "late_observed_exit":
                exit = cut
            if name == "late_entry_horizon":
                entry, exit = cut - 900_000, cut - 899_999
            for side in (1, -1):
                outcomes.append(dict(episode_id=name, direction=side,
                                     entry_msc=entry, exit_msc=exit))
        return pd.DataFrame(features), pd.DataFrame(outcomes), cut, boundary

    def test_calendar_tail_and_full_label_horizon_boundaries(self):
        f, outcomes, cut, boundary = self.synthetic_split()
        split = ml.split_indices(f, outcomes, 202502)
        self.assertEqual(split["cut"], cut)
        self.assertEqual(split["boundary"], boundary)
        self.assertEqual(set(f.loc[split["fit"], "episode_id"]),
                         {"fit_ok", "fit_horizon_minus1"})
        self.assertEqual(set(f.loc[split["cal"], "episode_id"]),
                         {"cal_ok", "cal_horizon_minus1"})
        self.assertEqual(f.loc[split["val"], "episode_id"].tolist(), ["val_ok"])

    def test_market_clusters_never_span_fit_calibration_validation(self):
        f, outcomes, _, _ = self.synthetic_split()
        split = ml.split_indices(f, outcomes, 202502)
        clusters = {part: set(f.loc[split[part], "market_cluster_id"])
                    for part in ("fit", "cal", "val")}
        self.assertFalse(clusters["fit"] & clusters["cal"])
        self.assertFalse(clusters["fit"] & clusters["val"])
        self.assertFalse(clusters["cal"] & clusters["val"])

    def test_missing_outcome_cannot_enter_fitting_or_calibration(self):
        f, outcomes, _, _ = self.synthetic_split()
        split = ml.split_indices(f, outcomes, 202502)
        included = set(f.loc[np.r_[split["fit"], split["cal"]], "episode_id"])
        self.assertNotIn("missing_outcome", included)


class FrequencyCalibrationTests(unittest.TestCase):
    def calibration_actions(self):
        return pd.DataFrame([
            action(str(i), processing=1_000 + i * 10_000,
                   entry=1_001 + i * 10_000, exit=2_000 + i * 10_000,
                   score=score)
            for i, score in enumerate((.1, .2, .3, .4))
        ])

    def test_count_calibration_does_not_use_profit_columns(self):
        original = self.calibration_actions()
        changed = original.copy()
        changed["gross_r"] = [-100., 100., -1000., 1000.]
        changed["gross_pips"] = [1000., -1000., 10_000., -10_000.]
        first = ml.calibrate(original, months=1., target=2.)
        second = ml.calibrate(changed, months=1., target=2.)
        self.assertEqual(first, second)
        self.assertEqual(first[1], 2.)
        self.assertEqual(first[2], 4.)
        self.assertEqual(len(ml.simulate(original, first[0])[0]), 2)

    def test_unattainable_target_keeps_actual_capacity_visible(self):
        threshold, achieved, maximum = ml.calibrate(
            self.calibration_actions(), months=1., target=800.)
        self.assertEqual(achieved, 4.)
        self.assertEqual(maximum, 4.)
        self.assertLess(achieved, 800.)
        self.assertEqual(len(ml.simulate(self.calibration_actions(), threshold)[0]), 4)

    def test_month_exposure_scales_rate_not_outcomes(self):
        threshold, achieved, maximum = ml.calibrate(
            self.calibration_actions(), months=2., target=1.)
        self.assertEqual(achieved, 1.)
        self.assertEqual(maximum, 2.)
        self.assertEqual(len(ml.simulate(self.calibration_actions(), threshold)[0]), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
