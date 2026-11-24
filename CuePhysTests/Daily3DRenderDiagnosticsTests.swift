import XCTest
import SceneKit
@testable import CuePhys

@MainActor
final class Daily3DRenderDiagnosticsTests: XCTestCase {
    private typealias Diagnostics = Daily3DRenderDiagnostics
    private typealias Event = Diagnostics.Event

    func testViewportTracksAncestorMovementReadableFrameAndFullWindowToggle() throws {
        let vm = SeparationAngleAtlasViewModel(); vm.setupScene()
        let scene = vm.scene
        scene.tablePreferencePage = TrainingProject.accuracy.page2D
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        let parent = UIView(frame: window.bounds)
        let view = SCNView(frame: parent.bounds)
        window.addSubview(parent); parent.addSubview(view)
        let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .topDown2D,
                                                     interactionMode: .cameraControl)
        coordinator.scnView = view
        coordinator.twoViewReadableFrameInWindow = CGRect(x: 24, y: 30, width: 800, height: 340)
        let rig = try XCTUnwrap(scene.cameraRig)
        coordinator.updateViewport(view.bounds.size)
        XCTAssertEqual(rig.topDownPresentationRect, CGRect(x: 24, y: 30, width: 800, height: 340))
        for _ in 0..<60 { coordinator.updateViewport(view.bounds.size) }
        parent.frame.origin.x = 10
        coordinator.updateViewport(view.bounds.size)
        XCTAssertEqual(rig.topDownPresentationRect, CGRect(x: 14, y: 30, width: 800, height: 340))
        coordinator.twoViewReadableFrameInWindow = CGRect(x: 30, y: 40, width: 780, height: 320)
        coordinator.updateViewport(view.bounds.size)
        XCTAssertEqual(rig.topDownPresentationRect, CGRect(x: 20, y: 40, width: 780, height: 320))
        scene.tablePreferencePage = nil
        coordinator.updateViewport(view.bounds.size)
        XCTAssertNil(rig.topDownPresentationRect)
        scene.tablePreferencePage = TrainingProject.accuracy.page2D
        view.removeFromSuperview()
        coordinator.updateViewport(view.bounds.size)
        XCTAssertNil(rig.topDownPresentationRect)
    }

    private func assertBalancedExclusiveStages(_ events: [Event],
                                               file: StaticString = #filePath, line: UInt = #line) {
        var page: UInt64?
        var stage: Event?
        var intervalIDs = Set<UInt64>()
        for event in events where event.kind != .event {
            if event.kind == .begin {
                XCTAssertTrue(intervalIDs.insert(event.id.rawValue).inserted, file: file, line: line)
            }
            if event.name == .page {
                if event.kind == .begin {
                    XCTAssertNil(page, file: file, line: line)
                    page = event.pageID
                } else {
                    XCTAssertNil(stage, file: file, line: line)
                    XCTAssertEqual(page, event.pageID, file: file, line: line)
                    page = nil
                }
            } else {
                XCTAssertEqual(page, event.pageID, file: file, line: line)
                if event.kind == .begin {
                    XCTAssertNil(stage, "Stage intervals must never overlap", file: file, line: line)
                    stage = event
                } else {
                    XCTAssertEqual(stage?.name, event.name, file: file, line: line)
                    XCTAssertEqual(stage?.id.rawValue, event.id.rawValue, file: file, line: line)
                    stage = nil
                }
            }
        }
        XCTAssertNil(stage, file: file, line: line)
        XCTAssertNil(page, file: file, line: line)
    }

    func testPageRequiresVisibleForeground3DAndBalancesEveryExit() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        diagnostics.setPage(visible: true, foreground: false, perspective: true)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.input(.tableTap)
        XCTAssertTrue(events.isEmpty)

        diagnostics.setPage(foreground: true)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.setPage(perspective: false)
        diagnostics.setPage(perspective: true)
        diagnostics.rendererState(active: true, cameraMoving: true)
        diagnostics.setPage(foreground: false)
        diagnostics.setPage(foreground: true)
        diagnostics.setPlayback(breaking: true, shooting: false)
        diagnostics.setPage(visible: false)
        diagnostics.setPage(visible: false)

        XCTAssertEqual(events.filter { $0.name == .page && $0.kind == .begin }.count, 3)
        assertBalancedExclusiveStages(events)
    }

    func testReplacing2DSceneBefore3DActivationKeepsPageEligible() {
        assertSceneReplacementKeepsPageVisible(activateBeforeDismantle: false)
    }

    func testReplacing2DSceneAfter3DActivationDoesNotEndNewPage() {
        assertSceneReplacementKeepsPageVisible(activateBeforeDismantle: true)
    }

    private func assertSceneReplacementKeepsPageVisible(activateBeforeDismantle: Bool,
                                                       file: StaticString = #filePath, line: UInt = #line) {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        let scene = AngleTrainingScene()
        let oldView = SCNView(), replacementView = SCNView()
        let old = AngleSceneView.Coordinator(scene: scene, cameraMode: .topDown2D,
                                            interactionMode: .cameraControl)
        let replacement = AngleSceneView.Coordinator(scene: scene, cameraMode: .perspective3D,
                                                    interactionMode: .cameraControl)
        old.scnView = oldView
        oldView.scene = scene
        oldView.delegate = old.frameDelegate
        old.setDaily3DDiagnostics(diagnostics)
        replacement.scnView = replacementView
        replacementView.scene = scene
        replacementView.delegate = replacement.frameDelegate
        replacement.setDaily3DDiagnostics(diagnostics)
        diagnostics.setPage(visible: true, foreground: true, perspective: false)

        // SwiftUI may deliver the page's mode change on either side of dismantling
        // the old conditional sceneContainer. Exercise the production teardown.
        if activateBeforeDismantle { diagnostics.setPage(perspective: true) }
        AngleSceneView.dismantleUIView(oldView, coordinator: old)
        if !activateBeforeDismantle { diagnostics.setPage(perspective: true) }

        XCTAssertNil(old.daily3DDiagnostics, file: file, line: line)
        XCTAssertNil(oldView.scene, file: file, line: line)
        XCTAssertTrue(replacement.daily3DDiagnostics === diagnostics, file: file, line: line)
        replacement.daily3DDiagnostics?.input(.tablePan, intent: .orbit)
        replacement.daily3DDiagnostics?.displayLinkCallback()
        XCTAssertEqual(events.filter { $0.name == .page && $0.kind == .begin }.count, 1,
                       file: file, line: line)
        XCTAssertFalse(events.contains { $0.name == .page && $0.kind == .end }, file: file, line: line)
        XCTAssertEqual(events.filter { $0.name == .wake }.count, 1, file: file, line: line)

        AngleSceneView.dismantleUIView(replacementView, coordinator: replacement)
        XCTAssertNil(replacement.daily3DDiagnostics, file: file, line: line)
        XCTAssertFalse(events.contains { $0.name == .page && $0.kind == .end }, file: file, line: line)
        // FreePlayView.onDisappear remains responsible for the actual page exit.
        diagnostics.setPage(visible: false)
        assertBalancedExclusiveStages(events, file: file, line: line)
    }

    func testIdleRequiresAnActualInactiveSchedulerDecision() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        diagnostics.rendererState(active: true, cameraMoving: false)
        XCTAssertFalse(events.contains { $0.name == .idle })
        diagnostics.rendererState(active: true, cameraMoving: true)
        XCTAssertFalse(events.contains { $0.name == .idle })
        diagnostics.rendererState(active: false, cameraMoving: false)
        XCTAssertEqual(events.last?.name, .idle)
        XCTAssertEqual(events.last?.kind, .begin)
        diagnostics.rendererState(active: true, cameraMoving: false)
        XCTAssertEqual(events.last?.name, .idle)
        XCTAssertEqual(events.last?.kind, .end)
        diagnostics.setPage(visible: false)
        assertBalancedExclusiveStages(events)
    }

    func testAimRemainsOneIntervalWhileItsCameraMovesAndSettles() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.input(.aimWheel, intent: .aim)
        diagnostics.setInteraction(.aimWheel, stage: .aim, active: true)
        for frame in 0..<120 {
            diagnostics.rendererState(active: true, cameraMoving: frame.isMultiple(of: 2))
        }
        diagnostics.setInteraction(.aimWheel, stage: .aim, active: false)
        diagnostics.rendererState(active: true, cameraMoving: true)
        diagnostics.rendererState(active: true, cameraMoving: false)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.setPage(visible: false)
        XCTAssertEqual(events.filter { $0.name == .aim && $0.kind == .begin }.count, 1)
        XCTAssertFalse(events.contains { $0.name == .orbit })
        assertBalancedExclusiveStages(events)
    }

    func testPlaybackAndExplicitOrbitTakePriorityWithoutOverlappingStages() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.setInteraction(.aimWheel, stage: .aim, active: true)
        diagnostics.setInteraction(.tablePan, stage: .orbit, active: true)
        diagnostics.setPlayback(breaking: true, shooting: true)
        diagnostics.setPlayback(breaking: false, shooting: true)
        diagnostics.setPlayback(breaking: false, shooting: false)
        diagnostics.setInteraction(.tablePan, stage: .orbit, active: false)
        diagnostics.setInteraction(.aimWheel, stage: .aim, active: false)
        diagnostics.setPage(visible: false)
        let stages = events.filter { $0.kind == .begin && $0.name != .page }.map(\.name)
        XCTAssertEqual(stages, [.idle, .aim, .orbit, .breaking, .shot, .orbit, .aim, .idle])
        assertBalancedExclusiveStages(events)
    }

    func testFirstWakeAndRenderRetainInputIdentityAndExitClearsPendingInput() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.input(.tablePan, intent: .orbit)
        diagnostics.input(.tablePinch, intent: .orbit)
        diagnostics.displayLinkCallback()
        diagnostics.displayLinkCallback()
        let renderer = SCNRenderer(device: nil, options: nil)
        diagnostics.willRender(renderer)
        diagnostics.willRender(renderer)
        let firstInput = events.first { $0.name == .input }
        let wake = events.filter { $0.name == .wake }
        let render = events.filter { $0.name == .firstRender }
        XCTAssertEqual(wake.count, 1)
        XCTAssertEqual(render.count, 1)
        for event in wake + render {
            XCTAssertEqual(event.id.rawValue, firstInput?.id.rawValue)
            XCTAssertEqual(event.sequence, firstInput?.sequence)
            XCTAssertTrue(event.wasIdle)
        }
        diagnostics.input(.strike)
        diagnostics.setPage(foreground: false)
        diagnostics.setPage(foreground: true)
        diagnostics.displayLinkCallback()
        diagnostics.willRender(renderer)
        XCTAssertEqual(events.filter { $0.name == .wake }.count, 1)
        XCTAssertEqual(events.filter { $0.name == .firstRender }.count, 1)
        diagnostics.setPage(visible: false)
        assertBalancedExclusiveStages(events)
    }

    func testConfigurationIsAttachedToPageAndOnlyChangesEmitEvents() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        let configuration = Diagnostics.RenderConfiguration(selectedFPS: 60, scheduledFPS: 60,
            antialiasingSamples: Diagnostics.sampleCount(for: .multisampling4X), contentScale: 3)
        diagnostics.setRenderConfiguration(configuration)
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        XCTAssertTrue(events.first?.configuration.contains("selectedFPS=60") == true)
        XCTAssertTrue(events.first?.configuration.contains("antialiasingSamples=4") == true)
        XCTAssertTrue(events.first?.configuration.contains("cameraReference=") == true)
        for _ in 0..<120 { diagnostics.setRenderConfiguration(configuration) }
        XCTAssertFalse(events.contains { $0.name == .configuration })
        diagnostics.setRenderConfiguration(.init(selectedFPS: 60, scheduledFPS: 30,
                                                 antialiasingSamples: 4, contentScale: 3))
        XCTAssertEqual(events.filter { $0.name == .configuration }.count, 1)
        diagnostics.setPage(visible: false)
        assertBalancedExclusiveStages(events)
    }

    func testInstalledClothRecipeReportsFallbackAndDeduplicatesUnchangedState() {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: true) { events.append($0) }
        var configuration = Diagnostics.RenderConfiguration(selectedFPS: 60, scheduledFPS: 60,
            antialiasingSamples: 4, contentScale: 3)
        configuration.clothSupport = .init(requested: true, effective: true,
            variant: "height-safe-test", fallbackReason: nil, capacity: 16,
            profile: "R", sampling: "reference", requestedVariant: "guard-combo")
        diagnostics.setRenderConfiguration(configuration)
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        XCTAssertTrue(events.first?.configuration.contains("safeClothSupportEffective=true") == true)
        XCTAssertTrue(events.first?.configuration.contains("safeClothSupportVariant=height-safe-test") == true)
        XCTAssertTrue(events.first?.configuration.contains("clothSupportRequest=guard-combo") == true)
        for _ in 0..<120 { diagnostics.setRenderConfiguration(configuration) }
        XCTAssertFalse(events.contains { $0.name == .configuration })

        configuration.clothSupport = .init(requested: true, effective: false,
            variant: "off", fallbackReason: "unsupported-capacity", capacity: 32,
            profile: "R", sampling: "reference", requestedVariant: "guard-combo")
        diagnostics.setRenderConfiguration(configuration)
        let changed = events.filter { $0.name == .configuration }
        XCTAssertEqual(changed.count, 1)
        XCTAssertTrue(changed.first?.configuration.contains("safeClothSupportRequested=true") == true)
        XCTAssertTrue(changed.first?.configuration.contains("safeClothSupportEffective=false") == true)
        XCTAssertTrue(changed.first?.configuration.contains("safeClothSupportFallback=unsupported-capacity") == true)
        XCTAssertTrue(changed.first?.configuration.contains("clothCapacity=32") == true)
        diagnostics.setPage(visible: false)
        assertBalancedExclusiveStages(events)
    }

    func testDisabledDiagnosticsStaySilentAndDelegatesPreserveFrameReceipt() async {
        var events: [Event] = []
        let diagnostics = Diagnostics(enabled: false) { events.append($0) }
        diagnostics.setRenderConfiguration(.init(selectedFPS: 60, scheduledFPS: 60,
            antialiasingSamples: 4, contentScale: 3,
            clothSupport: .init(requested: true, effective: true, variant: "test",
                fallbackReason: nil, capacity: 16, profile: "R", sampling: "reference")))
        diagnostics.setPage(visible: true, foreground: true, perspective: true)
        diagnostics.input(.tablePan)
        diagnostics.setInteraction(.tablePan, stage: .orbit, active: true)
        diagnostics.setPlayback(breaking: true, shooting: true)
        diagnostics.rendererState(active: false, cameraMoving: false)
        diagnostics.displayLinkCallback()
        diagnostics.setPage(visible: false)
        XCTAssertTrue(events.isEmpty)
        let scene = AngleTrainingScene()
        let renderer = SCNRenderer(device: nil, options: nil)
        let sampled = Daily3DFrameDelegate()
        sampled.setDiagnostics(diagnostics)
        for delegate in [FrameDelegate(), sampled] {
            let receipt = expectation(description: "Frame receipt survives disabled diagnostics")
            scene.frameReceipt.arm { receipt.fulfill() }
            delegate.renderer(renderer, willRenderScene: scene, atTime: 0)
            delegate.renderer(renderer, didRenderScene: scene, atTime: 0)
            await fulfillment(of: [receipt], timeout: 1)
            XCTAssertEqual(delegate.completedFrameNumber, 1)
        }
        XCTAssertTrue(events.isEmpty, "Disabled diagnostics must remain silent through actual delegate forwarding")
    }
}
