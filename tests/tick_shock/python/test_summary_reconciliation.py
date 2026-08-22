import unittest

from conftest import ROOT, read_csv


class SummaryReconciliationTests(unittest.TestCase):
    def test_scenario_rows_reconcile_to_overall(self):
        rows = read_csv(ROOT / "reports/refactor/tick_shock/step04_candidate_summary.csv")
        overall = next(row for row in rows if row["record_type"] == "OVERALL" and row["key"] == "ALL")
        scenario_rows = [row for row in rows if row["record_type"] == "SCENARIO"]
        self.assertEqual(int(overall["scenario_valid"]), sum(int(row["scenario_valid"] or 0) for row in scenario_rows))
        self.assertEqual(int(overall["scenario_invalid"]), sum(int(row["scenario_invalid"] or 0) for row in scenario_rows))

    def test_synthetic_summary_fixture_matches_literal_expected(self):
        config = {row["key"]: row["value"] for row in read_csv(ROOT / "tests/tick_shock/fixtures/TS-CSV-002_config.csv")}
        expected = {row["field"]: row["expected_value"] for row in read_csv(ROOT / "tests/tick_shock/expected/TS-CSV-002_expected.csv")}
        outcomes = config["scenario_rows"].split("|")
        valid = [item for item in outcomes if not item.endswith(":blank")]
        self.assertEqual(int(expected["valid_count"]), len(valid))
        self.assertEqual(int(expected["invalid_count"]), len(outcomes) - len(valid))
        self.assertAlmostEqual(float(expected["sum_r"]), sum(float(item.split(":", 1)[1]) for item in valid), places=12)


if __name__ == "__main__":
    unittest.main()
