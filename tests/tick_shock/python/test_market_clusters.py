import unittest

from conftest import raw_observations


class MarketClusterTests(unittest.TestCase):
    def test_cross_symbol_boundary_fixture_uses_production_clusterer(self):
        row = raw_observations()["TS-CLUSTER-001"]
        self.assertEqual("MATCH", row["observed"], row.get("difference"))


if __name__ == "__main__":
    unittest.main()
