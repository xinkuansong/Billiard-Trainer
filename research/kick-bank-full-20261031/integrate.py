"""Publish an independently audited compact bank and update exact consumer fixtures.
No UI or judgement changes. Refuses to edit unexpected fixtures.
"""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-bank-full-20261031'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((OUT/'audit.json').read_text());candidate=OUT/'kick-practice-bank.json'
assert sha(candidate)==audit['bankSHA256'] and audit['processedSeeds']==103680 and not audit['sourceDrift']
resource=ROOT/'QiuJi/Resources/kick-practice-bank.json'
preparer=ROOT/'QiuJi/Features/KickPractice/KickQuestionPreparer.swift'
tests=ROOT/'QiuJiTests/KickPracticeTests.swift'
old={str(p.relative_to(ROOT)):sha(p) for p in [resource,preparer,tests]}
backup=OUT/'previous-app-bank.json'
if not backup.exists():backup.write_bytes(resource.read_bytes())
s=preparer.read_text();s,n=re.subn(r'static let fingerprint = "[0-9a-f]{64}"',f'static let fingerprint = "{audit["bankSHA256"]}"',s);assert n==1
text=tests.read_text()
method=text.index('func testAllBundledReferencesReplayUnderCurrentProductionPhysics()')
position=text.index('        let bank = try KickBankStore.load()',method)
line='        let bank = try KickBankStore.load()'
text=text[:position]+r'''        let loadStarted = Date()
        let bank = try KickBankStore.load()
        print("Kick full bank: \(bank.questions.count) questions, cold load \(Date().timeIntervalSince(loadStarted) * 1000) ms")'''+text[position+len(line):]
def replace(old,new):
    global text
    assert text.count(old)==1,old
    text=text.replace(old,new)
replace('XCTAssertEqual(bank.questions.count, 140)',f'XCTAssertEqual(bank.questions.count, {audit["bank"]["total"]})')
counts=', '.join(f'{k}: {v}' for k,v in sorted(audit['bank']['perRail'].items()))
replace('XCTAssertEqual(counts, [1: 40, 2: 40, 3: 40, 4: 20])',f'XCTAssertEqual(counts, [{counts}])')
replace(r'print("Kick reference audit: all 140 retained; without later cushion = \(referencesWithoutPostContactRail)")',f'XCTAssertEqual(referencesWithoutPostContactRail, {audit["referencesWithoutPostContactRail"]})')
replace('''        var seen = Set<String>()
        for _ in 0..<20 {''',r'''        let fourRailIDs = try KickBankStore.load().questions.filter { $0.walls.count == 4 }.map(\.id)
        // Exercise the last three unseen entries and exhaustion, independent of bank size.
        var seen = Set(fourRailIDs.dropLast(3))
        for _ in 0..<3 {''')
replace('let referenceWithoutLaterRail = "C13-A320-V1.5-S0.5-N1-P0"',f'let referenceWithoutLaterRail = "{audit["noLaterRailExample"]}"')
start=text.index('func testRealSubmissionUsesPlayerDirectionAndRetryFreezesFirstSuccess()')
end=text.index('@MainActor func testRepositoryHistoryAndAtomicOwnerRollback()',start)
part=text[start:end];oldline='let prepared = try KickQuestionPreparer.prepare(config, seed: 31)'
assert part.count(oldline)==1
part=part.replace(oldline,f'''let bank = try KickBankStore.load()
        let prepared = try KickQuestionPreparer.prepare(config,
            excluding: Set(bank.questions.map(\\.id)).subtracting(["{audit['successExample']}"]), seed: 31)''')
text=text[:start]+part+text[end:]
# Keep the complete production replay, but release Foundation/SceneKit temporaries
# after each question instead of accumulating an entire bank's autoreleased objects.
start=text.index('        for source in bank.questions {');end=text.index('        XCTAssertEqual(counts,',start)
part=text[start:end];assert part.endswith('        }\n')
body=part[len('        for source in bank.questions {\n'):-len('        }\n')]
part='        for source in bank.questions {\n            try autoreleasepool {\n'+''.join('    '+line+'\n' for line in body.splitlines())+'            }\n        }\n'
text=text[:start]+part+text[end:]
resource.write_bytes(candidate.read_bytes());preparer.write_text(s);tests.write_text(text)
report=dict(previous=old,current={str(p.relative_to(ROOT)):sha(p) for p in [resource,preparer,tests]},auditSHA256=sha(OUT/'audit.json'),bankSHA256=sha(resource))
(OUT/'integration.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
