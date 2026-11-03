"""Constructive corruption checks for the full-bank importer (read-only source)."""
import copy
from pathlib import Path
import tempfile
import unittest
import import_bank_practice as bank


class BankImportTests(unittest.TestCase):
    # Actual first audited reference; this small fixture keeps corruption tests independent
    # of the large offline research export. Full conversion is checked by --verify.
    row = {'complete': True,
     'cue': [-0.33279210329055786, 0.5120981931686401],
     'direction': [-0.9803689122200012, -0.1971721649169922],
     'events': [{'balls': ['cueBall', 'object'],
                 'cue': [-1.1339393854141235, 0.3509789705276489],
                 'index': 0,
                 'kind': 'ballBall',
                 'target': [-1.1757911443710327, 0.3120177090167999],
                 'time': 0.4287363290786743},
                {'ball': 'object',
                 'cue': [-1.178160309791565, 0.3882543444633484],
                 'index': 1,
                 'kind': 'cushion',
                 'rail': 4,
                 'target': [-1.2414239645004272, 0.2526549994945526],
                 'time': 0.4970804750919342},
                {'ball': 'cueBall',
                 'cue': [-1.2414239645004272, 0.42546290159225464],
                 'index': 2,
                 'kind': 'cushion',
                 'rail': 4,
                 'target': [-1.1844507455825806, 0.21012160181999207],
                 'time': 0.5805870294570923},
                {'ball': 'cueBall',
                 'cue': [-0.911317765712738, 0.6064239740371704],
                 'index': 3,
                 'kind': 'cushion',
                 'rail': 0,
                 'target': [-0.7739039063453674, -0.07840322703123093],
                 'time': 1.3370851278305054},
                {'ball': 'object',
                 'cue': [-0.49420008063316345, 0.47692427039146423],
                 'index': 4,
                 'kind': 'pocket',
                 'pocket': 'pocket_4',
                 'target': [0.009942346252501011, -0.6287320852279663],
                 'time': 3.121067762374878}],
     'id': 'M-W0-R18-1-T4-C126-S0',
     'n': 1,
     'pocket': 4,
     'speed': 1.5,
     'spinX': 0,
     'spinY': 0,
     'target': [-1.175780177116394, 0.3120279610157013],
     'type': 'middle',
     'walls': [0]}

    def testExactInputsAndEventRailsPreserved(self):
        result = bank.convert_row(self.row)
        self.assertEqual(list(result['cue'].values()), self.row['cue'])
        self.assertEqual(list(result['target'].values()), self.row['target'])
        self.assertEqual(list(result['direction'].values()), self.row['direction'])
        self.assertEqual(result['input'], {'spinX': self.row['spinX'], 'spinY': self.row['spinY'], 'velocity': self.row['speed']})
        self.assertEqual(result['railSegments'], [4])
        self.assertEqual(result['id'], 'bank-v1-' + self.row['id'])

    def testChangedSourceRejectedBeforeDecoding(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'changed.gz'; path.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'Audited input has changed'):
                bank.converted(path)

    def testCorruptReferenceEventsRejected(self):
        for change in ('incomplete', 'wrong-wall', 'wrong-pocket', 'scratch', 'early-rail', 'second-contact', 'no-pot'):
            with self.subTest(change=change):
                row = copy.deepcopy(self.row)
                if change == 'incomplete': row['complete'] = False
                if change == 'wrong-wall': row['walls'] = [1]
                if change == 'wrong-pocket': row['pocket'] = 5
                if change == 'scratch': row['events'].append({'kind': 'pocket', 'ball': 'cueBall'})
                if change == 'early-rail': row['events'].insert(0, {'kind': 'cushion', 'ball': 'cueBall'})
                if change == 'second-contact': row['events'].insert(1, copy.deepcopy(row['events'][0]))
                if change == 'no-pot': row['events'] = [e for e in row['events'] if e['kind'] != 'pocket']
                with self.assertRaises(ValueError): bank.convert_row(row)


if __name__ == '__main__':
    unittest.main()
