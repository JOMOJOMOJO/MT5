import unittest

from conftest import raw_observations


class CausalExecutionTests(unittest.TestCase):
    def test_production_clock_observations_match_independent_expected_files(self):
        rows = raw_observations()
        for test_id in ("TS-TIME-001", "TS-DETECT-001", "TS-REV-001", "TS-MERGE-001", "TS-MERGE-002"):
            self.assertIn(test_id, rows)
            self.assertEqual("MATCH", rows[test_id]["observed"], f"{test_id}: {rows[test_id].get('difference')}")


if __name__ == "__main__":
    unittest.main()
