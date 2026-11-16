from pathlib import Path
import sys

root = Path(sys.argv[1])
here = Path(__file__).resolve().parent
def edit(path, old, new, count=1):
    p = root/path
    s = p.read_text()
    assert s.count(old) == count, (path, old, s.count(old))
    p.write_text(s.replace(old, new))
def around(path, statement, name, count=1):
    edit(path, statement, 'TableEntryProbe.measure("'+name+'") { '+statement+' }', count)

scene = 'QiuJi/Core/Scene/AngleTrainingScene.swift'
view = 'QiuJi/Core/Scene/AngleSceneView.swift'
free = 'QiuJi/Features/PositionPlay/Views/FreePlayView.swift'
vm = 'QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift'
probe = 'QiuJi/Core/Scene/RoomReflectionProbe.swift'
edit('QiuJi/App/MainTabView.swift', '.task { TableResourceCache.shared.warmForEntry() }',
     '.task { TableEntryProbe.install(); TableResourceCache.shared.warmForEntry() }')
edit('QiuJi/Features/AngleTraining/Views/AngleHomeView.swift', '        router.anglePath.append(entry.route)',
     '        if entry.route == .positionPlayComposer { TableEntryProbe.begin("composer") }\n        router.anglePath.append(entry.route)')
edit('QiuJi/Features/Training/Views/TrainingHomeView.swift', '                    router.trainingPath.append(TrainingRoute.dailyClearance)',
     '                    TableEntryProbe.begin("daily")\n                    router.trainingPath.append(TrainingRoute.dailyClearance)')
edit(free, '        .onAppear {\n            if isDailyClearance,',
     '        .onAppear {\n            TableEntryProbe.event("onAppear.start")\n            defer { TableEntryProbe.pageReady(vm) }\n            if isDailyClearance,')
edit(free, '        .onDisappear {\n            if isMultiBall',
     '        .onDisappear {\n            TableEntryProbe.event("disappear"); TableEntryProbe.flush()\n            if isMultiBall')
edit(scene, '        // Explicit reconfiguration of the same scene must rebuild',
     '''        TableEntryProbe.event("sceneSetup.start", ["scene": String(describing: ObjectIdentifier(self)),
            "stack": ProcessInfo.processInfo.arguments.contains("-entry.stacks") ? Thread.callStackSymbols : []])
        defer { TableEntryProbe.event("sceneSetup.end", ["scene": String(describing: ObjectIdentifier(self)), "reusedTable": reusedPreparedTable]) }
        // Explicit reconfiguration of the same scene must rebuild''')
for statement, name in [('setupTable()', 'setupTable'), ('setupCamera()', 'setupCamera'),
                        ('setupLighting()', 'setupLighting'), ('MobileReferenceLighting.apply(to: self)', 'referenceLighting'),
                        ('contactOcclusion = MobileContactOcclusion(scene: self)', 'contactOcclusion'),
                        ('installReferenceRoom(style: roomStyle)', 'installRoom')]:
    # Match the call token plus newline, not a declaration with an opening brace.
    edit(scene, statement+'\n', 'TableEntryProbe.measure("'+name+'") { '+statement+' }\n')
edit(probe, '        guard let baked = bake(scene: scene, style: style) else { return neutral }',
     '        TableEntryProbe.event("probe.cacheMiss.sync")\n        guard let baked = TableEntryProbe.measure("probe.bake.sync", { bake(scene: scene, style: style) }) else { return neutral }')
edit(probe, '        if let cached = cache[inputs] {',
     '        if let cached = cache[inputs] {\n            TableEntryProbe.event("probe.cacheHit")', count=2)
edit(probe, '        guard let input = prepareBake(scene: scene, style: inputs.room) else { completion(nil); return }',
     '        TableEntryProbe.event("probe.cacheMiss.async")\n        guard let input = TableEntryProbe.measure("probe.prepareCopies", { prepareBake(scene: scene, style: inputs.room) }) else { completion(nil); return }')
edit(probe, '            let probe = autoreleasepool { cached(for: inputs) ?? bake(input: input) }',
     '            let probe = TableEntryProbe.measure("probe.bake.async") { autoreleasepool { cached(for: inputs) ?? bake(input: input) } }')
edit(scene, '        roomReflectionProbe = probe\n',
     '        TableEntryProbe.event("probe.install", ["async": preparesRoomReflectionAsynchronously])\n        roomReflectionProbe = probe\n')
edit(probe, 'let shot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)',
     'let shot = TableEntryProbe.measure("probe.snapshot") { renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none) }')
edit(probe, 'let floorShot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)',
     'let floorShot = TableEntryProbe.measure("probe.floorSnapshot") { renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none) }')
edit(view, '    func makeUIView(context: Context) -> SCNView {',
     '    func makeUIView(context: Context) -> SCNView {\n        TableEntryProbe.event("makeUIView.start")\n        defer { TableEntryProbe.event("makeUIView.end") }')
edit(view, '        (scene as? AngleTrainingScene)?.frameReceipt.willRender()',
     '        TableEntryProbe.frame(renderer, scene, will: true)\n        (scene as? AngleTrainingScene)?.frameReceipt.willRender()')
edit(view, '        (scene as? AngleTrainingScene)?.frameReceipt.didRender()',
     '        TableEntryProbe.frame(renderer, scene, will: false)\n        (scene as? AngleTrainingScene)?.frameReceipt.didRender()')
edit(view, '            displayLinkCallbackCount += 1',
     '            TableEntryProbe.display(scnView, scene)\n            displayLinkCallbackCount += 1')
edit(view, '            let action = entryFrameAction\n            entryFrameAction = nil',
     '            TableEntryProbe.event("entryFramePresented", limit: 2)\n            let action = entryFrameAction\n            entryFrameAction = nil')
edit(vm, '        scene.setupScene(mobileRendering: mobileRendering)',
     '        TableEntryProbe.bind(scene)\n        TableEntryProbe.event("vmSetup.start", ["scene": String(describing: ObjectIdentifier(scene))])\n        defer { TableEntryProbe.event("vmSetup.end", ["timing": entryTiming]) }\n        scene.setupScene(mobileRendering: mobileRendering)')
edit(vm, '    private func loadBoard(_ snapshot: BoardSnapshot, alreadyOnTable: Bool) {',
     '    private func loadBoard(_ snapshot: BoardSnapshot, alreadyOnTable: Bool) {\n        TableEntryProbe.event("loadBoard.start")\n        defer { TableEntryProbe.event("loadBoard.end") }')
edit(vm, '    private func selectBestPocket() {',
     '    private func selectBestPocket() {\n        TableEntryProbe.event("recommendation.start")\n        defer { TableEntryProbe.event("recommendation.end") }')
edit(vm, '            let solveStart = CACurrentMediaTime()',
     '            let solveStart = CACurrentMediaTime()\n            TableEntryProbe.event("solve.start")')
edit(vm, '            let solveEnd = CACurrentMediaTime()',
     '            let solveEnd = CACurrentMediaTime()\n            TableEntryProbe.event("solve.end")')
edit(vm, '                let delivery = CACurrentMediaTime()',
     '                let delivery = CACurrentMediaTime()\n                TableEntryProbe.event("solve.mainDelivery")')
edit(vm, '        cameraTransitionBusy = accepted && scene.cameraRig?.isTransitioning == true',
     '        cameraTransitionBusy = accepted && scene.cameraRig?.isTransitioning == true\n        TableEntryProbe.event("camera.request", ["accepted": accepted, "busy": cameraTransitionBusy])')
edit(vm, 'scene.cameraRig?.onPlayerTransitionEnded = { [weak self] in self?.cameraTransitionBusy = false }',
     'scene.cameraRig?.onPlayerTransitionEnded = { [weak self] in self?.cameraTransitionBusy = false; TableEntryProbe.event("camera.transitionEnded") }')
edit('QiuJi/Core/Scene/MobileReferenceLighting.swift',
     '    static func refreshClothLighting(in scene: AngleTrainingScene, ballCount: Int) {',
     '    static func refreshClothLighting(in scene: AngleTrainingScene, ballCount: Int) {\n        let entryStart = CACurrentMediaTime()\n        defer { TableEntryProbe.event("cloth.prepare", ["durationMS": (CACurrentMediaTime()-entryStart)*1000]) }')
edit('QiuJi/Core/Scene/TableModelLoader.swift', '        guard idleTable?.key == key else { record("tableMiss"); return nil }',
     '        guard idleTable?.key == key else { TableEntryProbe.event("tableCache.miss", ["active": activeScenes, "idle": idleTable != nil]); record("tableMiss"); return nil }\n        TableEntryProbe.event("tableCache.hit", ["active": activeScenes])')
edit('QiuJi/Core/Scene/TableFigureRenderer.swift', '    static func closeupFelt(clothColor: ClothColor, roomStyle: RoomStyle) -> UIImage? {\n        backdrop(',
     '    static func closeupFelt(clothColor: ClothColor, roomStyle: RoomStyle) -> UIImage? {\n        let entryStart = CACurrentMediaTime(); TableEntryProbe.event("closeupBackdrop.start")\n        defer { TableEntryProbe.event("closeupBackdrop.end", ["durationMS": (CACurrentMediaTime()-entryStart)*1000]) }\n        return backdrop(')
edit('QiuJi/Data/Services/TablePreferencesStore.swift', '        return result\n    }\n\n    /// Explicit user action:',
     '''        if TableEntryProbe.enabled, page == .composer || page == .dailyClearance {
            if ProcessInfo.processInfo.arguments.contains("-entry.3D") { result.values[.view3D] = 1 }
            if ProcessInfo.processInfo.arguments.contains("-entry.2D") { result.values[.view3D] = 0 }
        }
        return result
    }

    /// Explicit user action:''')
p = root/scene
probe_text=(here/'probe.swift').read_text()
if 'safeClothSupportState' not in p.read_text():
    probe_text=probe_text.replace('!vm.shotControlsBusy', '!vm.isComputing')
    probe_text=probe_text.replace('vm.shotControlsBusy', 'vm.isComputing')
    probe_text=probe_text.replace(', "cloth": vm.scene.safeClothSupportState.variant,\n              "staticField": vm.scene.staticClothIrradiance != nil, "ltc": vm.scene.clothLTCState', '')
p.write_text(p.read_text() + probe_text)
p = root/'QiuJiUITests/AdaptiveShotControlsUITests.swift'
p.write_text(p.read_text() + (here/'ui_test.swift').read_text())
