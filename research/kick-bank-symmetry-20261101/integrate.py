"""Install the frozen bank and its bounded production-replay fixtures."""
from pathlib import Path
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/kick-bank-symmetry-20261101'
audit = json.loads((OUT/'audit.json').read_text())
destination = ROOT/'QiuJi/Resources/kick-practice-bank.json'
assert hashlib.sha256(destination.read_bytes()).hexdigest() in [audit['sourceSHA256'], audit['bankSHA256']]
shutil.copyfile(OUT/'kick-practice-bank.json', destination)
source = ROOT/'QiuJi/Features/KickPractice/KickQuestionPreparer.swift'
text = source.read_text()
text, count = re.subn(r'static let fingerprint = "[0-9a-f]{64}"', 'static let fingerprint = "'+audit['bankSHA256']+'"', text)
assert count == 1
source.write_text(text)

rows = json.loads((OUT/'sample.json').read_text())
fixture = '\n'.join(r['id']+'|'+','.join(map(str,r['rails'])) for r in rows)
test = '''
    // SYMMETRY_SAMPLE_BEGIN: generated from the frozen pre-replay sample manifest.
    func testSymmetryBankCoversEveryCellInAllFourQuadrants() throws {
        let bank = try KickBankStore.load()
        var quadrants: [Int: Int] = [:]
        var cells: [String: Set<String>] = [:]
        var railCounts: [Int: Int] = [:]
        for q in bank.questions {
            let quadrant = (q.cue.x > 0 ? 1 : 0) + (q.cue.z > 0 ? 2 : 0)
            quadrants[quadrant, default: 0] += 1
            railCounts[q.walls.count, default: 0] += 1
            let cell = String(q.id.split(separator: "-")[0])
            cells["\\(q.walls.count)/\\(quadrant)", default: []].insert(cell)
        }
        XCTAssertEqual(bank.questions.count, 53928)
        XCTAssertEqual(quadrants, [0: 13482, 1: 13482, 2: 13482, 3: 13482])
        XCTAssertEqual(railCounts, [1: 15165, 2: 17974, 3: 13326, 4: 7463])
        XCTAssertEqual(cells.count, 16)
        for (key, value) in cells { XCTAssertEqual(value.count, 72, key) }
    }
    func testFrozenSymmetrySampleReplaysExpectedRailSegments() throws {
        let bank = try KickBankStore.load()
        let sources = Dictionary(uniqueKeysWithValues: bank.questions.map { ($0.id, $0) })
        let profile = AccuracyTipSelector.renderedProfile()
        let fixtures = Self.symmetrySample.split(separator: "\\n")
        XCTAssertEqual(fixtures.count, SAMPLE_COUNT)
        var actualCases = 0
        for line in fixtures {
            try autoreleasepool {
                let fields = line.split(separator: "|")
                let id = String(fields[0])
                let expected = try fields[1].split(separator: ",").map { try XCTUnwrap(Int($0)) }
                let source = try XCTUnwrap(sources[id], id)
                let question = KickQuestion(id: UUID(), source: source)
                let prediction = try KickQuestionPreparer.solve(question: question, input: source.input,
                    direction: source.direction.vector, surfaceY: BTTablePhysics.surfaceY, profile: profile)
                let shot = try KickShot(question: question, input: source.input, prediction: prediction,
                    surfaceY: BTTablePhysics.surfaceY)
                XCTAssertEqual(PracticeRailColors.beforeTarget(prediction.events), expected, id)
                XCTAssertEqual(expected.compactMap { KickWall.from(cushion: $0) }, source.walls, id)
                XCTAssertFalse(prediction.cuePocketed, id)
                // Reference qualification predates the player's later-cushion rule.
                // A missing later cushion must never filter this bank.
                if let failure = shot.failure { XCTAssertEqual(failure, .noRailAfterContact, id) }
                XCTAssertGreaterThan(shot.trajectory.count, 1, id)
                XCTAssertEqual(shot.trajectory.first?.position.x ?? 0, source.cue.x, accuracy: 0.00001, id)
                XCTAssertEqual(shot.trajectory.first?.position.z ?? 0, source.cue.z, accuracy: 0.00001, id)
                actualCases += 1
            }
        }
        print("Kick symmetry stratified references replayed: \\(actualCases)/SAMPLE_COUNT")
        XCTAssertEqual(actualCases, SAMPLE_COUNT)
    }
    private static let symmetrySample = """
FIXTURES
    """
    // SYMMETRY_SAMPLE_END
'''.replace('SAMPLE_COUNT', str(len(rows))).replace('FIXTURES', '\n'.join('    '+line for line in fixture.splitlines()))
path = ROOT/'QiuJiTests/KickPracticeTests.swift'
text = path.read_text()
if '    // SYMMETRY_SAMPLE_BEGIN:' in text:
    text = re.sub(r'\n    // SYMMETRY_SAMPLE_BEGIN:.*?    // SYMMETRY_SAMPLE_END\n', lambda _:test, text, flags=re.S)
else:
    marker = '    func testFilteringNonRepeatingSelectionAndExplicitExhaustion()'
    assert marker in text
    text = text.replace(marker, test+'\n'+marker, 1)
path.write_text(text)
print('Installed', audit['total'], 'questions and',len(rows),'bounded replay fixtures; SHA256',audit['bankSHA256'])
