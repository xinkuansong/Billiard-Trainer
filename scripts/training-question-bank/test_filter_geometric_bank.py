import unittest
from filter_geometric_bank import PocketMetrics, rank_alternatives, retain_target, score


class GeometricBankTests(unittest.TestCase):
    def test_inclusive_threshold(self):
        a = PocketMetrics(0, 0, 1)
        self.assertEqual(len(rank_alternatives([a, PocketMetrics(1, 0, .7)], 0)[2]), 1)
        self.assertEqual(len(rank_alternatives([a, PocketMetrics(1, 0, .700000001)], 0)[2]), 0)

    def test_non_forward_and_original_excluded(self):
        self.assertIsNone(score(PocketMetrics(1, 90, .01)))
        self.assertIsNone(score(PocketMetrics(1, 120, .01)))
        _, ranked, better = rank_alternatives([PocketMetrics(0, 20, 1), PocketMetrics(1, 90, .01)], 0)
        self.assertEqual((ranked, better), ([], []))

    def test_distance_angle_compensation_and_tie(self):
        metrics = [PocketMetrics(0, 60, 1), PocketMetrics(1, 0, 1.3), PocketMetrics(2, 0, 1.3)]
        self.assertEqual([item[1] for item in rank_alternatives(metrics, 0)[2]], [1, 2])

    def test_sparse_masks_preserve_code_alignment(self):
        target = dict(inventoryTargetIndex=8, masks=[5, 2, 0, 1024],
                      combinationIndices=[7, 9, 2, 12], pocket=4, object={"x": 1, "z": 2})
        result = retain_target(target, {"grid-v3:8:0:2", "grid-v3:8:3:10"})
        self.assertEqual(result["masks"], [4, 0, 0, 1024])
        self.assertEqual(result["combinationIndices"], [9, 12])
        self.assertEqual(result["object"], target["object"])
        self.assertEqual(target["masks"], [5, 2, 0, 1024])
        self.assertEqual(retain_target(target, set())["combinationIndices"], [])


if __name__ == "__main__":
    unittest.main()
