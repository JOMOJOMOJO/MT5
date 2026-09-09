#!/usr/bin/env python3
"""Deterministic independently specified tests; no MT5 or outcome refitting."""
from __future__ import annotations

import unittest
import contextlib
import io
import json
import math
import tempfile
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pandas as pd

from analyze_technical_discovery import (METHODS, Model, choose_actions,
    feature_matrix, forward_splits, mql_export, passes_gate, portfolio, profit_stats)
from analyze_technical_discovery import run as analyze
from technical_discovery_independent_recalculation import aggregate, score, run as recalculate


def action(episode, processing, entry, exit, gross=1.0, direction=1, status="TP", score_value=.2):
    # 10 pips risk: explicit 0.2 pip extra cost is .02R.
    return dict(episode_id=episode, t0_msc=processing-1, signal_processing_msc=processing,
                entry_msc=entry, exit_msc=exit, gross_r=gross, gross_pips=gross*10,
                direction=direction, status=status, score=score_value,
                distance=.001, pip_size=.0001, calendar_segment=0,
                entry_price=1.0, exit_price=1.0+direction*gross*.001)


class TestIndependentSpecification(unittest.TestCase):
    def test_cost_and_gap_oracle(self):
        rows = pd.DataFrame([action("a", 1, 2, 3, 1), action("b", 4, 5, 6, -1.5, -1, "SL")])
        got = profit_stats(rows, .2)
        # +.98R and -1.52R: total -.54, mean -.27, PF .98/1.52.
        self.assertAlmostEqual(got["total_r"], -.54)
        self.assertAlmostEqual(got["expectancy_r"], -.27)
        self.assertAlmostEqual(got["pf"], .98/1.52)
        self.assertAlmostEqual(got["maxdd_r"], 1.52)
        self.assertEqual(got["trades"], 2)
        independent = aggregate(rows.to_dict("records"), .2)
        for field in ("total_r", "expectancy_r", "pf", "maxdd_r"):
            self.assertAlmostEqual(got[field], independent[field])

    def test_pending_reservation_before_entry(self):
        rows = pd.DataFrame([action("first", 100, 600, 1000), action("later", 200, 300, 400)])
        accepted, rejected = portfolio(rows, .1)
        self.assertEqual(accepted.episode_id.tolist(), ["first"])
        self.assertEqual(rejected["overlap_skips"], 1)

    def test_equal_close_time_is_conservatively_busy(self):
        rows = pd.DataFrame([action("first", 100, 101, 200), action("equal", 200, 201, 250), action("after", 201, 202, 300)])
        accepted, _ = portfolio(rows, .1)
        self.assertEqual(accepted.episode_id.tolist(), ["first", "after"])

    def test_threshold_boundary(self):
        rows = pd.DataFrame([action("minus", 1, 2, 3, score_value=.099999),
                             action("equal", 4, 5, 6, score_value=.1),
                             action("plus", 7, 8, 9, score_value=.100001)])
        self.assertEqual(portfolio(rows, .1)[0].episode_id.tolist(), ["equal", "plus"])

    def test_no_entry_retains_pending_reservation(self):
        rows = pd.DataFrame([action("pending", 100, 0, 0, status="NO_ENTRY"),
                             action("inside", 200, 201, 250), action("after", 30100, 30101, 30200)])
        accepted, reasons = portfolio(rows, .1)
        self.assertEqual(accepted.episode_id.tolist(), ["after"])
        self.assertEqual(reasons["overlap_skips"], 1)

    def test_censored_position_not_released_at_entry(self):
        rows = pd.DataFrame([action("censored", 100, 101, 0, status="CENSORED"),
                             action("inside", 200, 201, 250), action("after", 900102, 900103, 900200)])
        self.assertEqual(portfolio(rows, .1)[0].episode_id.tolist(), ["after"])

    def test_preferred_invalid_direction_does_not_fallback(self):
        episodes = pd.DataFrame({"episode_id": ["a"]})
        outcomes = pd.DataFrame([action("a", 1, 2, 3, direction=1, status="BROKER_DISTANCE_REJECT"),
                                 action("a", 1, 2, 3, direction=-1)])
        outcomes = outcomes.drop(columns="score")
        choices = choose_actions(outcomes, episodes, np.array([.5]), np.array([.4]))
        self.assertEqual(choices.direction.tolist(), [1])
        self.assertEqual(len(portfolio(choices, .1)[0]), 0)

    def test_tie_is_no_trade(self):
        episodes = pd.DataFrame({"episode_id": ["a"]})
        outcomes = pd.DataFrame([action("a", 1, 2, 3), action("a", 1, 2, 3, direction=-1)]).drop(columns="score")
        self.assertEqual(len(choose_actions(outcomes, episodes, np.array([.5]), np.array([.5]))), 0)

    def test_reject_entry_before_processing(self):
        rows = pd.DataFrame([action("a", 100, 99, 200)])
        with self.assertRaises(ValueError):
            portfolio(rows, .1)

    def test_feature_metadata_excluded(self):
        features = pd.DataFrame({"episode_id": ["a"], "event_shock_direction": [1], "shock_direction": [1],
                                 "t0_msc": [1000], "m5_rsi14": [55]})
        x, catalog = feature_matrix(features)
        self.assertEqual(x.columns.tolist(), ["shock_direction", "m5_rsi14"])
        self.assertEqual(len(catalog), 2)

    def test_outcome_predictor_rejected(self):
        with self.assertRaises(ValueError):
            feature_matrix(pd.DataFrame({"mfe_900": [.5]}))

    def test_candidate_requires_frequency_and_concentration(self):
        stats = dict(trades=200, expectancy_r=.1, pf=1.2, max_day_profit_share=.2,
                     top5_removed_total_r=5, positive_segments=3, min_segment_trades=20)
        self.assertTrue(passes_gate(stats))
        for field, value in (("trades", 199), ("max_day_profit_share", .35),
                             ("top5_removed_total_r", 0), ("positive_segments", 2),
                             ("min_segment_trades", 19), ("expectancy_r", 0)):
            modified = dict(stats)
            modified[field] = value
            self.assertFalse(passes_gate(modified))

    def test_forward_purge_clusters_and_labels(self):
        episodes = pd.DataFrame({"episode_id": [str(i) for i in range(100)],
                                 "market_cluster_id": [i//2 for i in range(100)],
                                 "t0_msc": np.arange(100)*300000,
                                 "t0_processing_msc": np.arange(100)*300000+100})
        outcomes = pd.DataFrame({"episode_id": episodes.episode_id, "exit_msc": episodes.t0_msc+900000})
        for _, train, valid in forward_splits(episodes, outcomes):
            self.assertFalse(set(episodes.loc[train, "market_cluster_id"]) & set(episodes.loc[valid, "market_cluster_id"]))
            self.assertLess(outcomes.loc[train, "exit_msc"].max(), episodes.loc[valid, "t0_processing_msc"].min())

    def test_all_exported_models_independent_prediction(self):
        random = np.random.default_rng(73)
        x = random.normal(size=(600, 6))
        y = np.where(x[:, 0]+.4*x[:, 1] > .2, .98, -1.02)
        x[::31, 3] = np.nan
        for method in METHODS:
            with self.subTest(method=method):
                model = Model(method).fit(x, y)
                exported = model.export()
                got = np.array([score(exported, row) for row in x])
                np.testing.assert_allclose(got, model.predict(x), atol=1e-12, rtol=0)
                spec = dict(features=[f"f{i}" for i in range(6)], distance_index=1,
                            distance_atr=.5, threshold=.1, models={"long": exported, "short": exported})
                code = mql_export(spec)
                self.assertIn("TDModelDecision", code)
                self.assertNotIn("OrderSend", code)

    def test_synthetic_end_to_end_candidate_and_independent_replay(self):
        random = np.random.default_rng(392)
        features, outcomes = [], []
        base = 1743465600000
        for i in range(800):
            t0 = base+i*3000000
            value = random.normal()
            features.append(dict(episode_id=str(i), event_id=f"e{i}", market_cluster_id=i,
                                 symbol="EURUSD", event_shock_direction=1, t0_msc=t0,
                                 t0_processing_msc=t0+1, t0_quote_msc=t0-1,
                                 feature_max_close_msc=t0-1000, feature_future_count=0,
                                 feature_available_count=2, atr14_m1=.001, atr14_m5=.002,
                                 shock_direction=1, m5_rsi14=50+value*10))
            for direction in (1, -1):
                gross = 1.0 if (value >= 0) == (direction == 1) else -1.0
                row = action(str(i), t0+1, t0+2, t0+10002, gross, direction, "TP" if gross > 0 else "SL")
                entry = 1.0001 if direction == 1 else 1.0
                row.update(t0_msc=t0, symbol="EURUSD", market_cluster_id=i, distance_index=1,
                           distance_atr=.5, atr14_m5=.002, entry_eligible_msc=t0+1,
                           source_quote_msc=t0-1, entry_bid=1.0, entry_ask=1.0001,
                           entry_price=entry, entry_spread=.0001, tick_size=.00001,
                           stops_distance=0, sl=entry-direction*.001, tp=entry+direction*.001,
                           exit_price=entry+direction*gross*.001,
                           mfe_60=max(0, gross*.001), mae_60=max(0, -gross*.001),
                           mfe_300=max(0, gross*.001), mae_300=max(0, -gross*.001),
                           mfe_900=max(0, gross*.001), mae_900=max(0, -gross*.001),
                           tp_touch_seconds=10 if gross > 0 else math.nan,
                           sl_touch_seconds=10 if gross < 0 else math.nan)
                row.pop("score")
                row.pop("calendar_segment")
                outcomes.append(row)
        with tempfile.TemporaryDirectory(prefix="technical_discovery_oracle_") as directory:
            directory = Path(directory)
            feature_path, outcome_path = directory/"features.csv", directory/"outcomes.csv"
            pd.DataFrame(features).to_csv(feature_path, index=False)
            pd.DataFrame(outcomes).to_csv(outcome_path, index=False)
            args = SimpleNamespace(features=str(feature_path), outcomes=str(outcome_path), output=str(directory),
                                   period_start="2025-04-01", period_end="2025-05-01", skip_univariate=False)
            with contextlib.redirect_stdout(io.StringIO()):
                analyze(args)
                recalculate(args)
            summary = json.loads((directory/"analysis_summary.json").read_text())
            self.assertEqual(summary["verdict"], "DEVELOPMENT_EA_CANDIDATE_FOUND")
            self.assertGreaterEqual(summary["candidate"]["trades"], 200)
            checks = pd.read_csv(directory/"independent_qa_checks.csv")
            self.assertTrue(checks.status.eq("PASS").all())


if __name__ == "__main__":
    unittest.main(verbosity=2)
