import unittest

from conftest import ROOT, read_csv


class FixtureIntegrityTests(unittest.TestCase):
    def test_registry_has_one_fixture_config_and_expected_per_test(self):
        cases = read_csv(ROOT / "tests/tick_shock/spec/test_cases.csv")
        self.assertEqual(len(cases), len({row["test_id"] for row in cases}))
        for row in cases:
            test_id = row["test_id"]
            self.assertTrue((ROOT / f"tests/tick_shock/fixtures/{test_id}_ticks.csv").is_file())
            self.assertTrue((ROOT / f"tests/tick_shock/fixtures/{test_id}_config.csv").is_file())
            self.assertTrue((ROOT / f"tests/tick_shock/expected/{test_id}_expected.csv").is_file())

    def test_oracle_provenance_disallows_production_generated_expected(self):
        for path in sorted((ROOT / "tests/tick_shock/fixtures").glob("*_config.csv")):
            config = {row["key"]: row["value"] for row in read_csv(path)}
            if path.name.startswith("TS15A-"):
                # Step 15A freezes oracle provenance at the suite level so the
                # calculation config remains a literal input-only fixture.
                oracle = ROOT / "tools/tick_shock/step15a_independent_oracle.py"
                spec = ROOT / "docs/research/tick_shock/15a_detector_test_spec.md"
                self.assertTrue(oracle.is_file(), path.name)
                self.assertTrue(spec.is_file(), path.name)
                self.assertNotIn("TickShockStatisticalDetector", oracle.read_text(encoding="utf-8"), path.name)
                continue
            if path.name.startswith("TS15C-"):
                # Step 15C also freezes provenance at suite level. Its literal
                # fixture configs contain only event-response inputs.
                oracle = ROOT / "tools/tick_shock/step15c_independent_oracle.py"
                spec = ROOT / "docs/research/tick_shock/15c_event_response_spec.md"
                self.assertTrue(oracle.is_file(), path.name)
                self.assertTrue(spec.is_file(), path.name)
                self.assertNotIn("TickShockEventResponse", oracle.read_text(encoding="utf-8"), path.name)
                continue
            self.assertEqual("false", config.get("production_function_used_for_expected"), path.name)
            self.assertIn(config.get("oracle_source"), {
                "docs/research/tick_shock/03_test_oracle_calculation.md",
                "docs/research/tick_shock/11_test_oracle_addendum.md",
                "docs/research/tick_shock/15b_control_funnel_test_spec.md",
                "docs/research/tick_shock/15d_state_conditioned_response_spec.md",
                "docs/research/tick_shock/15e_shock_episode_spec.md",
                "docs/research/tick_shock/15f_context_feature_spec.md",
            }, path.name)


if __name__ == "__main__":
    unittest.main()
