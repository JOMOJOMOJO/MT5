import unittest

from conftest import raw_observations


class RrAndBrokerDistanceTests(unittest.TestCase):
    def test_outward_rr_fixture_matches_production(self):
        row = raw_observations()["TS-RR-001"]
        self.assertEqual("MATCH", row["observed"], row.get("difference"))

    def test_bid_ask_broker_distance_fixture_matches_production(self):
        row = raw_observations()["TS-BROKER-001"]
        self.assertEqual("MATCH", row["observed"], row.get("difference"))


if __name__ == "__main__":
    unittest.main()
