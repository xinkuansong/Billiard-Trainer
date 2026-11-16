from pathlib import Path
import sys
root = Path(sys.argv[1]); here = Path(__file__).resolve().parent
def edit(path, old, new, count=1):
    p = root/path; text = p.read_text()
    assert text.count(old) == count, (path, old, text.count(old))
    p.write_text(text.replace(old, new))
scene='QiuJi/Core/Scene/AngleTrainingScene.swift'
view='QiuJi/Core/Scene/AngleSceneView.swift'
edit(scene, '        if resourceGeneration == nil { resourceGeneration = TableResourceCache.acquireScene() }',
     '        TableLifeProbe.track(self, kind: "scene", scene: self)\n        if resourceGeneration == nil { resourceGeneration = TableResourceCache.acquireScene() }')
edit(view, '        let scnView = LayoutAwareSceneView()',
     '        let scnView = LayoutAwareSceneView()\n        TableLifeProbe.track(scnView, kind: "renderer", scene: scene)')
edit(view, '        coordinator.stopRenderLoop()', '        TableLifeProbe.event(uiView, "dismantled")\n        coordinator.stopRenderLoop()')
edit(view, '        func startRenderLoop() {', '        func startRenderLoop() {\n            TableLifeProbe.track(self, kind: "coordinator", scene: scene)')
edit(view, '            displayLinkCallbackCount += 1', '            TableLifeProbe.frame(self, tick: true)\n            displayLinkCallbackCount += 1')
edit(view, '        (scene as? AngleTrainingScene)?.frameReceipt.didRender()',
     '        TableLifeProbe.frame(renderer as AnyObject)\n        (scene as? AngleTrainingScene)?.frameReceipt.didRender()')
vm='QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift'
edit(vm, '        let entryStart = CACurrentMediaTime()', '        TableLifeProbe.bind(self, owner: "composer", scene: scene)\n        let entryStart = CACurrentMediaTime()')
for method,state in [('suspendAuthoringActivity','suspend'),('resumeAuthoringActivity','resume')]:
    edit(vm, f'    func {method}() {{', f'    func {method}() {{\n        TableLifeProbe.event(self, "{state}")')
for owner in ['Two','Three']:
    path=f'QiuJi/Features/{owner}BallPractice/{owner}BallPracticeViewModel.swift'
    edit(path, '    func setupScene() {', f'    func setupScene() {{\n        TableLifeProbe.bind(self, owner: "{owner.lower()}", scene: scene)')
    for method,state in [('suspendTeachingActivity','suspend'),('resumeTeachingActivity','resume')]:
        edit(path, f'    func {method}() {{', f'    func {method}() {{\n        TableLifeProbe.event(self, "{state}")')
    path=f'QiuJi/Features/{owner}BallPractice/{owner}BallQuestionPreparer.swift'
    anchor='        try Task.checkCancellation()\n        guard input.isValid' if owner=='Two' else '        let board = question.board\n        let aim = try SeparationQuestionGenerator.solve'
    edit(path, anchor, f'        let lifeJob = TableLifeProbe.beginJob("{owner.lower()}.solve")\n        defer {{ TableLifeProbe.endJob(lifeJob) }}\n'+anchor)
edit(vm, '            let solveStart = CACurrentMediaTime()',
     '            let lifeJob = TableLifeProbe.beginJob("composer.solve")\n            defer { TableLifeProbe.endJob(lifeJob) }\n            let solveStart = CACurrentMediaTime()')
edit('QiuJi/App/MainTabView.swift', '        .task { TableResourceCache.shared.warmForEntry() }',
     '        .overlay(alignment: .topLeading) { TableLifeProbePanel() }\n        .task { TableResourceCache.shared.warmForEntry() }')
edit('QiuJi/Data/Services/TablePreferencesStore.swift', '        return result\n    }\n\n    /// Explicit user action:',
     '        if TableLifeProbe.enabled { result.values[.view3D] = 0 }\n        return result\n    }\n\n    /// Explicit user action:')
p=root/scene; p.write_text(p.read_text()+'\nimport SwiftUI\n'+(here/'probe.swift').read_text())
p=root/'QiuJiUITests/AdaptiveShotControlsUITests.swift'; p.write_text(p.read_text()+(here/'ui_test.swift').read_text())
