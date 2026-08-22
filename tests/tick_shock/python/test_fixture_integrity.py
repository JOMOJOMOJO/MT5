import unittest

from conftest import ROOT, read_csv


class FixtureIntegrityTests(unittest.TestCase):
    def test_registry_has_one_fixture_config_and_expected_per_test(self):
        cases = read_csv(ROOT / "tests/tick_shock/spec/test_cases.csv")
        self.assertEqual(64, len(cases))
        self.assertEqual(64, len({row["test_id"] for row in cases}))
        for row in cases:
            test_id = row["test_id"]
            self.assertTrue((ROOT / f"tests/tick_shock/fixtures/{test_id}_ticks.csv").is_file())
            self.assertTrue((ROOT / f"tests/tick_shock/fixtures/{test_id}_config.csv").is_file())
            self.assertTrue((ROOT / f"tests/tick_shock/expected/{test_id}_expected.csv").is_file())

    def test_oracle_provenance_disallows_production_generated_expected(self):
        for path in sorted((ROOT / "tests/tick_shock/fixtures").glob("*_config.csv")):
            config = {row["key"]: row["value"] for row in read_csv(path)}
            self.assertEqual("false", config.get("production_function_used_for_expected"), path.name)
            self.assertEqual("docs/research/tick_shock/03_test_oracle_calculation.md", config.get("oracle_source"), path.name)


if __name__ == "__main__":
    unittest.main()
