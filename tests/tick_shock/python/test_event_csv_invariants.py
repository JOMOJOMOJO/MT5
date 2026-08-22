import unittest

from conftest import ROOT, parse_scenario, read_csv


class EventCsvInvariantTests(unittest.TestCase):
    def test_realizable_candidate_has_no_entry_before_processing_or_eligibility(self):
        events = read_csv(ROOT / "reports/refactor/tick_shock/step04_candidate_events.csv")
        checked = 0
        violations = []
        for event in events:
            for encoded in filter(None, event.get("scenario_grid", "").split(";")):
                scenario = parse_scenario(encoded)
                quote = scenario.get("entry_quote")
                eligible = scenario.get("eligible")
                processing = scenario.get("signal_processing")
                if not quote or not eligible or not processing or int(quote) <= 0:
                    continue
                checked += 1
                if int(quote) < int(eligible) or int(quote) < int(processing):
                    violations.append(event["event_id"] + ":" + encoded)
        self.assertGreater(checked, 0)
        self.assertEqual([], violations)

    def test_candidate_event_ids_are_unique(self):
        events = read_csv(ROOT / "reports/refactor/tick_shock/step04_candidate_events.csv")
        ids = [row["event_id"] for row in events]
        self.assertEqual(len(ids), len(set(ids)))


if __name__ == "__main__":
    unittest.main()
