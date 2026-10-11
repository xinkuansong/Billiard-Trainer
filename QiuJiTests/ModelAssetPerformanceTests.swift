import XCTest
import SceneKit
import Darwin
@testable import QiuJi

private final class ModelPerfFrames: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Double] = []
    func record() { lock.lock(); times.append(CACurrentMediaTime()); lock.unlock() }
    func snapshot() -> [Double] { lock.lock(); defer { lock.unlock() }; return times }
}

/// Opt-in scene-host A/B using the production VM, solver, SCNActions and scheduler.
/// Device runs retain native scale; full SwiftUI-page performance is a separate measurement.
@MainActor final class ModelAssetPerformanceTests: XCTestCase {
    func testLiveScenePerformance() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["MODEL_PERF_OUTPUT"] else { throw XCTSkip("Explicit model performance run required") }
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        let output = URL(fileURLWithPath: path)
        #else
        let output = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("model-asset-performance").appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
        #endif
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let oldIdleTimer = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = oldIdleTimer }
        func conditions() -> [String: Any] {
            ["thermal": ProcessInfo.processInfo.thermalState.rawValue,
             "batteryState": UIDevice.current.batteryState.rawValue, "batteryLevel": UIDevice.current.batteryLevel,
             "brightness": UIScreen.main.brightness, "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled,
             "uptime": ProcessInfo.processInfo.systemUptime, "unix": Date().timeIntervalSince1970]
        }
        let oldBrightness = UIScreen.main.brightness
        if let brightness = env["MODEL_PERF_BRIGHTNESS"].flatMap(Double.init) {
            XCTAssertTrue((0.1...0.8).contains(brightness))
            UIScreen.main.brightness = CGFloat(brightness)
        }
        defer { if env["MODEL_PERF_BRIGHTNESS"] != nil { UIScreen.main.brightness = oldBrightness } }
        if env["MODEL_PERF_REQUIRE_UNPLUGGED"] == "1" {
            try await Task.sleep(for: .seconds(1))
            XCTAssertEqual(UIDevice.current.batteryState, .unplugged)
            let coolDeadline = CACurrentMediaTime() + 180
            while ProcessInfo.processInfo.thermalState != .nominal && CACurrentMediaTime() < coolDeadline {
                print("MODEL_PERF_COOLING thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
                fflush(stdout)
                try await Task.sleep(for: .seconds(10))
            }
        }
        let startConditions = conditions()
        try JSONSerialization.data(withJSONObject: startConditions, options: .sortedKeys).write(to: output.appendingPathComponent("start.json"))
        #if !targetEnvironment(simulator)
        let expectedThermal = Int(env["MODEL_PERF_THERMAL_BASELINE"] ?? "0") ?? 0
        XCTAssertTrue((0...1).contains(expectedThermal), "Only nominal/fair baselines are permitted")
        XCTAssertEqual(ProcessInfo.processInfo.thermalState.rawValue, expectedThermal, "Match the explicitly selected A/B thermal baseline")
        #endif
        print("MODEL_PERF_READY pid=\(getpid()) unix=\(Date().timeIntervalSince1970)")
        fflush(stdout)
        if let delay = env["MODEL_PERF_TRACE_DELAY"].flatMap(Double.init) {
            try await Task.sleep(for: .seconds(delay))
        }
        let original = UserDefaults.standard.bool(forKey: "modelAssetTrialUseOriginal")
        let tableURL = try XCTUnwrap(ModelAssetTrial.url("TaiQiuZhuo"))
        XCTAssertEqual(tableURL.lastPathComponent.hasPrefix("ModelTrial"), !original)
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        let orientation = DailyTableOrientation.Controller()
        orientation.landscape = true
        let rootController = try XCTUnwrap(window.rootViewController)
        rootController.addChild(orientation)
        rootController.view.addSubview(orientation.view)
        orientation.view.frame = .zero
        orientation.didMove(toParent: rootController)
        orientation.applyOrientation()
        defer { orientation.restorePortrait(); orientation.view.removeFromSuperview(); orientation.removeFromParent() }
        let rotationDeadline = CACurrentMediaTime() + 10
        while window.bounds.width <= window.bounds.height && CACurrentMediaTime() < rotationDeadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertGreaterThan(window.bounds.width, window.bounds.height)
        let oldFPS = UserPreferences.shared.renderFrameRate
        UserPreferences.shared.renderFrameRate = .fps60
        defer { UserPreferences.shared.renderFrameRate = oldFPS }
        func cpu() -> Double {
            var r = rusage(); XCTAssertEqual(getrusage(RUSAGE_SELF, &r), 0)
            return Double(r.ru_utime.tv_sec + r.ru_stime.tv_sec) + Double(r.ru_utime.tv_usec + r.ru_stime.tv_usec) / 1e6
        }
        func memory() -> [String: UInt64] {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
            let status = withUnsafeMutablePointer(to: &info) { p in
                p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
            }
            XCTAssertEqual(status, KERN_SUCCESS)
            return ["residentBytes": info.resident_size, "footprintBytes": info.phys_footprint]
        }
        let initialMemory = memory(), setupStart = CACurrentMediaTime(), setupCPU = cpu()
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering()
        vm.setupScene(mobileRendering: true, loadsDefaultLayout: false)
        vm.scene.setupCueStick()
        let setupMS = (CACurrentMediaTime() - setupStart) * 1000
        let setupCPUMS = (cpu() - setupCPU) * 1000
        let setupMemory = memory()
        var positions: [String: CanvasPoint] = [:]
        func place(_ key: String, _ x: Float, _ z: Float) {
            let p = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(x, vm.scene.surfaceY, z))
            positions[key] = CanvasPoint(x: Double(p.x), y: Double(p.y))
        }
        place(PositionPlayBall.cueKey, -0.7, 0.32)
        place("_1", -0.15, 0.32)
        for number in 2...15 {
            let i = number - 2
            place("_\(number)", -0.9 + Float(i % 7) * 0.28, -0.42 + Float(i / 7) * 0.15)
        }
        let board = BoardSnapshot(onTable: positions)
        vm.aimMode = .free; vm.loadBoard(board); vm.velocity = 1.5
        XCTAssertEqual(vm.onTableKeys.count, 16)
        vm.handleTableTap(world: try XCTUnwrap(vm.scene.allBallNodes["_1"]).position)
        let mode = AngleTrainingScene.CameraMode.perspective3D
        vm.cameraMode = mode; vm.scene.setCameraMode(mode, animated: false)
        let view = SCNView(frame: window.bounds)
        #if targetEnvironment(simulator)
        view.contentScaleFactor = 2
        #else
        view.contentScaleFactor = window.screen.scale
        #endif
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode
        view.antialiasingMode = .multisampling4X
        let frames = ModelPerfFrames()
        vm.scene.contactOcclusion?.didRenderFrame = { frames.record() }
        let coordinator = AngleSceneView.Coordinator(scene: vm.scene, cameraMode: mode, interactionMode: .cameraControl)
        coordinator.scnView = view; coordinator.contentIsAnimating = true
        window.addSubview(view); coordinator.startRenderLoop(); coordinator.requestInteractiveFrames()
        defer {
            AngleSceneView.dismantleUIView(view, coordinator: coordinator)
            view.removeFromSuperview(); vm.scene.contactOcclusion?.didRenderFrame = nil
        }
        vm.scene.cameraRig?.viewportSize = view.bounds.size
        vm.scene.cameraRig?.fitLandscapeTable(viewSize: view.bounds.size)
        XCTAssertTrue(vm.scene.cameraRig?.observeWholeTable(yaw: .pi / 2) == true)
        let readiness = CACurrentMediaTime() + 25
        while (vm.isComputing || frames.snapshot().count < 90) && CACurrentMediaTime() < readiness {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertFalse(vm.isComputing); XCTAssertGreaterThanOrEqual(frames.snapshot().count, 90)
        XCTAssertNotNil(vm.solvedShot)
        var phases: [[String: Any]] = []
        func begin() -> (Double, Double, Int) { (CACurrentMediaTime(), cpu(), frames.snapshot().count) }
        func end(_ label: String, _ start: (Double, Double, Int)) {
            XCTAssertLessThan(ProcessInfo.processInfo.thermalState.rawValue, 2, "Stop workload at serious thermal state")
            let times = Array(frames.snapshot().dropFirst(start.2))
            print("MODEL_PERF_PHASE \(label) start=\(start.0) end=\(CACurrentMediaTime())")
            phases.append(["phase": label, "conditions": conditions(), "startUptime": start.0, "endUptime": CACurrentMediaTime(), "wallSeconds": CACurrentMediaTime() - start.0,
                "cpuSeconds": cpu() - start.1, "frameTimes": times, "memory": memory(),
                "metalAllocatedBytes": view.device?.currentAllocatedSize ?? 0])
        }
        let steady = begin()
        try await Task.sleep(for: .seconds(4))
        end("continuous-static", steady)
        let orbit = begin()
        for _ in 0..<180 {
            vm.scene.cameraRig?.handleObservationPan(deltaX: 0.15)
            coordinator.requestInteractiveFrames()
            try await Task.sleep(for: .milliseconds(16))
        }
        end("orbit", orbit)
        let predict = begin(); vm.recompute()
        let predictDeadline = CACurrentMediaTime() + 25
        while vm.isComputing && CACurrentMediaTime() < predictDeadline { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(vm.isComputing); end("prediction", predict)
        let prediction = try XCTUnwrap(vm.solvedShot).prediction
        let before = vm.scene.allBallNodes.mapValues { [$0.position.x, $0.position.y, $0.position.z] }
        let play = begin(); vm.play(); XCTAssertTrue(vm.isPlaying)
        coordinator.contentIsAnimating = true; coordinator.requestInteractiveFrames()
        let playDeadline = CACurrentMediaTime() + 45
        var capturedMoving = false
        var firstBallMotionMS: Double?
        while vm.isPlaying && CACurrentMediaTime() < playDeadline {
            try await Task.sleep(for: .milliseconds(25))
            if firstBallMotionMS == nil {
                let moved = vm.scene.allBallNodes.contains { key, node in
                    guard let point = before[key] else { return false }
                    let p = node.presentation.position
                    return hypotf(p.x - point[0], p.z - point[2]) > 0.001
                }
                if moved { firstBallMotionMS = (CACurrentMediaTime() - play.0) * 1000; capturedMoving = true }
            }
        }
        XCTAssertFalse(vm.isPlaying); XCTAssertTrue(capturedMoving)
        end("shot-playback", play)
        coordinator.contentIsAnimating = false
        try await Task.sleep(for: .seconds(1))
        let idle = begin(); try await Task.sleep(for: .seconds(3)); end("settled-host", idle)
        // Snapshot only after every measured phase, to avoid observer allocation effects.
        try XCTUnwrap(view.snapshot().pngData()).write(to: output.appendingPathComponent("settled.png"))
        var parse: [Double] = []
        for _ in 0..<2 {
            try autoreleasepool {
                let t = CACurrentMediaTime()
                let raw = try SCNScene(url: tableURL, options: [.checkConsistency: true])
                parse.append((CACurrentMediaTime() - t) * 1000)
                XCTAssertFalse(raw.rootNode.childNodes.isEmpty)
            }
        }
        let report: [String: Any] = ["startConditions": startConditions, "endConditions": conditions(), "OS": UIDevice.current.systemVersion, "original": original, "table": tableURL.lastPathComponent,
            "process": getpid(), "setupMS": setupMS, "setupCPUMS": setupCPUMS,
            "memoryBefore": initialMemory, "memoryAfterSetup": setupMemory,
            "windowSize": [view.bounds.width, view.bounds.height], "scale": view.contentScaleFactor,
            "msaa": 4, "targetFPS": 60, "phases": phases, "parseMS": parse,
            "board": board.onTable.mapValues { [$0.x, $0.y] }, "before": before,
            "firstBallMotionMS": try XCTUnwrap(firstBallMotionMS), "predictionDuration": prediction.duration, "after": vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("metrics.json"))
        print("MODEL_PERF_DONE", original ? "original" : "optimized", setupMS)
        fflush(stdout)
        if let delay = env["MODEL_PERF_END_DELAY"].flatMap(Double.init) {
            try await Task.sleep(for: .seconds(delay))
        }
    }
}
