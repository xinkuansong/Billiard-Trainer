import SwiftUI
import SceneKit
import Combine

@MainActor
final class SpatialPracticeViewModel: TeachingTableHost {
    typealias Record = SpatialPracticeRecord
    enum Phase { case ready, calculating, playing, replaying }
    let scene=AngleTrainingScene(trajectoryWidths: .interactiveTable)
    @Published var cameraMode: AngleTrainingScene.CameraMode = .perspective3D
    @Published var cameraTransitionBusy=false
    @Published var temporaryTopDownActive=false
    @Published var topDownContentRevision=0
    var topDownSelectionChanged=false
    @Published private(set) var phase:Phase = .ready {
        didSet {
            scene.cameraRig?.p01ShotFrozen = busy
            if !busy { scene.cameraRig?.endP01RollingShot() }
        }
    }
    @Published private(set) var isDragging=false
    @Published var input=Record.Input()
    @Published private(set) var record=Record(board:[:],input:.init())
    @Published var message:String?
    @Published private(set) var archiveMessage:String?
    @Published private(set) var activeShot:Record.Shot?
    var displayedInput:Record.Input { activeShot?.input ?? input }
    @Published var playbackSpeed:Float=1
    @Published var showsLastRoute=false
    private var routeNodes:[SCNNode]=[]
    private var landingMarker:SCNNode?
    @Published var hidesAssists=false { didSet { syncBreakAssist();renderRoutes() } }
    private var trajectoryDetail:TrajectoryDetail = .full
    private var breakRunner:BreakFlowRunner?
    var isBreakMode:Bool { record.breakContext != nil }
    var breakGameBallCount:Int { record.breakGameBallCount ?? 15 }
    var canPrepareBreak:Bool { canTune && phase == .ready }
    var velocityRange:ClosedRange<Double> { (activeShot.map { $0.breakContext != nil } ?? isBreakMode) ? BreakFlowRunner.breakVelocityRange : 0.1...8 }
    private var validInput:Bool { input.valid(maximumSpeed:isBreakMode ? 10 : 8) }
    private struct RequestKey:Equatable {
        let owner:String,instance:UUID,geometry:String,solver:String
        let input:Record.Input
        let board:[String:Record.Pose]
        let breakContext:Record.BreakContext?
        var eventBudget:Int { breakContext == nil ? 3000 : 8000 }
    }
    private struct Request { let key:RequestKey;let generation:UUID;let immediate:Bool }
    private let instance=UUID()
    private var pending:Request?
    private var worker:Task<Void,Never>?
    private var preview:(key:RequestKey,shot:Record.Shot)?
    private var submitted:RequestKey?
    private var saveTask:Task<Void,Never>?
    #if DEBUG
    @Published private(set) var completedSolves=0
    private(set) var startedSolves=0
    var hasActiveCurrentPrediction:Bool { activeKey==currentKey && cancellation?.isCancelled == false }
    private let lifetime=SpatialRuntimeProbe.Token("freeVM")
    private var timingInputStart:Double?
    var timingProbeJSON:String { scene.interactionTimingProbe?.json ?? "[]" }
    var inputTimingJSON:String { scene.inputPresentationTimingProbe?.json ?? "[]" }
    var previewShot:Record.Shot? { preview?.shot }
    var previewProbeJSON:String {
        let value:[String:Any] = ["ready":preview?.key==currentKey,"solves":completedSolves,
            "id":preview?.shot.id.uuidString ?? "", "routes":routeNodes.count,"detail":trajectoryDetail.rawValue,
            "hidden":hidesAssists,"yaw":input.yaw,"speed":input.speed,"spinX":input.spinX,"spinY":input.spinY,
            "elevation":input.elevation,"height":preview?.shot.maximumHeight ?? 0,
            "displayedElevation":displayedInput.elevation,"historyID":record.lastShot?.id.uuidString ?? "",
            "historyCueOutcome":record.lastShot?.after[PositionPlayBall.cueKey]?.disposition ?? "",
            "recoveryCount":record.lastShot?.recoveries?.count ?? 0,
            "cueWorld":record.board[PositionPlayBall.cueKey].map { [$0.position.x,$0.position.z] } ?? [],
            "archivePending":archive.pendingHistory,
            "archiveCommitted":archive.committedHistoryID?.uuidString ?? "",
            "archiveWriter":archive.isActiveWriter,"archiveEncodes":archive.historyEncodeCount,
            "archiveTrace":archive.diagnosticTrace,"archiveError":archiveMessage ?? "",
            "breakMode":isBreakMode,"breakCount":breakGameBallCount,"phase":String(describing:phase),
            "temporaryTopDown":temporaryTopDownActive,"mode3D":cameraMode == .perspective3D,"onTable":onTableKeys.count,
            "camera":[scene.cameraNode?.position.x ?? 0,scene.cameraNode?.position.y ?? 0,scene.cameraNode?.position.z ?? 0],
            "view":scene.cameraRig?.twoViewMode.rawValue ?? "", "overview":scene.cameraRig?.overviewControlSelected ?? false]
        return (try? JSONSerialization.data(withJSONObject:value)).map { String(decoding:$0,as:UTF8.self) } ?? "{}"
    }
    #endif
    private var setup=false
    private var cancellation:PredictionCancellation?
    private var generation=UUID()
    private var ownerKey=""
    private let archive:SpatialPracticeArchive
    #if DEBUG
    var archiveForTesting:SpatialPracticeArchive { archive }
    #endif
    private let defaults:UserDefaults
    private let ownerContext:CurrentOwnerContext
    private var replayReturn:[String:Record.Pose]?
    private var replayCamera=ShotReplayCamera()
    private var shotView: CameraRig.PerspectiveState?
    private var shotViewID: UUID?
    private var submittedView: CameraRig.PerspectiveState?
    private var submittedViewID: UUID?
    private var audioItems:[DispatchWorkItem]=[]
    private var initialDrag:SCNVector3?
    #if DEBUG
    private let motionProbe=SpatialPracticeMotionProbe()
    var motionProbeJSON:String { busy ? "active" : motionProbe.json }
    #endif
    var busy:Bool { phase == .playing || phase == .replaying }
    var canEdit:Bool { !busy && !cameraTransitionBusy }
    var canTune:Bool { canEdit && !temporaryTopDownActive && !isDragging }
    var permitsTemporaryTopDown:Bool { submitted == nil }
    var permitsFirstPersonAddress:Bool { currentPlayerAim != nil && cueAccessible }
    var selectedTargetKey:String? { isBreakMode ? nil : record.selectedTargetKey }
    var selectedPocketIndex:Int { -1 }
    var targetNode:SCNNode? { selectedTargetKey.flatMap { scene.allBallNodes[$0] } }
    var currentPlayerAim:SCNVector3? {
        (activeShot?.before ?? record.board)[PositionPlayBall.cueKey]?.disposition == "bed" ? displayedInput.aim:nil
    }
    var onTableKeys:[String] { PositionPlayBall.allKeys.filter { record.board[$0]?.disposition == "bed" } }
    var draggableBalls:[SCNNode] { canEdit ? (breakRunner?.draggableCue ?? onTableKeys.compactMap { scene.allBallNodes[$0] }) : [] }
    var selectableBalls:[SCNNode] { draggableBalls }
    var outsideKeys:[String] { record.board.keys.filter { ["outside","escaped"].contains(record.board[$0]?.disposition ?? "") }.sorted() }
    var canStrike:Bool { canTune && validInput && input.elevation<=Record.Input.maximumPracticeElevation && currentPlayerAim != nil && cueAccessible }
    init(defaults:UserDefaults = .standard,ownerContext:CurrentOwnerContext = .shared,archiveRoot:URL? = nil) {
        self.defaults=defaults;self.ownerContext=ownerContext
        self.archive=SpatialPracticeArchive(defaults:defaults,root:archiveRoot)
        archive.onError={ [weak self] in self?.archiveMessage=$0 }
    }

    func setupScene() {
        guard !setup else { return };setup=true
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-masseJump.timing") {
            scene.interactionTimingProbe=TableInteractionTimingProbe()
        }
        if SpatialRuntimeProbe.enabled { scene.inputPresentationTimingProbe=TableInteractionTimingProbe() }
        #endif
        scene.isolatesTemporaryTopDownMaterials = true
        scene.configureReferenceTableRendering();scene.configureShotAwareCamera()
        scene.setupScene();scene.setupVisualizationNodes();configureTeachingCamera(policy: .p01Replayable)
        ownerChanged()
    }
    func ownerChanged() {
        suspendTeachingActivity()
        breakRunner?.cancel();breakRunner=nil
        clearRoute();showsLastRoute=false
        ownerKey=ownerContext.ownerKey
        if let saved=archive.begin(owner:ownerKey) {
            record=saved;input=saved.input.limitingPracticeElevation();record.input=input;apply(saved.board)
            restorePreparedBreak()
            if !isBreakMode, record.selectedTargetKey == nil { recommendTarget(preserveAim:true) }
            resolveElevation()
            save()
        } else {
            record=Record(board:[:],input:.init());loadExample(0)
            input = .init();recommendTarget();save()
        }
        #if DEBUG
        if let raw=ProcessInfo.processInfo.environment["SPATIAL_BENCHMARK_MODE"],
           let mode=SpatialQuizMode(rawValue:raw), let question=try? SpatialQuizBank.load(mode).questions.first {
            input=question.reference.spatialInput
            record=Record(selectedTargetKey:question.board.targetName,board:SpatialQuizInstance(question).board,input:input)
            apply(record.board);resolveElevation()
        }
        #endif
        scene.isPaused=false;refreshAim()
    }
    func save() {
        guard setup,!ownerKey.isEmpty else { return }
        record.input=input
        archive.save(record)
    }
    func updateInput(_ update:(inout Record.Input)->Void) {
        guard canTune else { return }
        var next=input;update(&next);next=next.limitingPracticeElevation()
        guard next != input else { return }
        #if DEBUG
        timingInputStart=TableInteractionTimingProbe.now
        let inputFrameID=UUID()
        scene.inputPresentationTimingProbe?.beginPreview(id:inputFrameID,start:timingInputStart!,balls:record.board.count)
        #endif
        if let runner=breakRunner {
            if next.yaw != input.yaw { runner.nudgeAim(byDegrees:Float((next.yaw-input.yaw)*180 / .pi)) }
            runner.velocity=next.speed;runner.spinX=next.spinX;runner.spinY=next.spinY
        }
        let angleChanged = next.elevation != input.elevation
        let geometryChanged = angleChanged || next.yaw != input.yaw || next.spinX != input.spinX || next.spinY != input.spinY
        if angleChanged { next.preferredElevation = nil }
        input=next;message=nil
        if geometryChanged { resolveElevation() }
        syncPreparedBreak()
        showsLastRoute=false;cancelCalculation();refreshAim()
        #if DEBUG
        scene.inputPresentationTimingProbe?.routesReady(id:inputFrameID)
        #endif
        saveTask?.cancel()
        saveTask=Task { [weak self] in
            try? await Task.sleep(for:.milliseconds(300))
            guard !Task.isCancelled else { return };self?.save()
        }
    }
    func nudgeElevation(_ delta: Float) {
        updateInput { value in
            let preferred = value.preferredElevation ?? value.elevation
            // Moving beyond the clearance stop accumulates the requested setting.
            // Turning back into the free range starts at the visible angle.
            let base = delta < 0 ? min(preferred, value.elevation) : max(preferred, value.elevation)
            value.elevation = base + Double(delta)
        }
    }
    func nudgeAim(_ degrees:Float) {
        guard canTune else { return }
        let update = { self.updateInput { $0.yaw += Double(degrees) * .pi / 180 } }
        guard let rig=scene.cameraRig,rig.usesP01Camera else { update();return }
        if rig.overviewControlSelected, let cue = scene.cueBallNode {
            rig.followP01TableAim(cue:cue.position,
                aim:SpatialQuizPhysics.Input(yaw:input.yaw + Double(degrees) * .pi / 180,
                    speed:input.speed,spinX:input.spinX,spinY:input.spinY,elevation:input.elevation).aim,
                fallbackStrike:{ cue.position },updateCue:update)
            return
        }
        _ = rig.updateP01TargetCue(resolved:true,align:true,
            preservePose:rig.twoViewOwnerIsManual && rig.playerView == .thirdPerson,
            animated:false,update:update)
    }
    /// Reuse preparation only. This host never calls the runner's planar breakNow.
    func prepareBreak(ballCount:Int? = nil,seed:UInt64? = nil) {
        guard canPrepareBreak else { return }
        let count=ballCount ?? breakGameBallCount
        guard [15,9,6,5,4].contains(count) else { return }
        // Selecting the checked gameplay keeps its tuned rack; the separate
        // rerack action (no explicit count) deliberately advances the seed.
        if seed == nil,ballCount != nil,isBreakMode,count == breakGameBallCount { return }
        #if DEBUG
        timingInputStart=TableInteractionTimingProbe.now
        #endif
        let ordinary=record.breakContext?.ordinaryInput ?? input
        cancelCalculation();message=nil
        let game=BreakFlowRunner.game(forBallCount:count)
        if let runner=breakRunner,seed == nil {
            if runner.game != game { runner.selectGame(game) } else { runner.reRack() }
        } else {
            breakRunner?.cancel()
            let runner=makePreparationRunner(count:count,seed:seed)
            breakRunner=runner;runner.rackUp()
        }
        guard let runner=breakRunner,let aim=runner.aimDir else { return }
        runner.velocity=BreakFlowRunner.defaultBreakVelocity;runner.spinX=0;runner.spinY=0
        input = .init(yaw:Double(atan2f(aim.z,aim.x)),speed:runner.velocity,
            spinX:0,spinY:0,elevation:Double(CueStick.minElevationRadians)*180 / .pi)
        guard let prepared=runner.savedInput else { return }
        record.breakContext = .init(ordinaryInput:ordinary,prepared:prepared)
        record.breakGameBallCount=count;record.lastShot=nil;shotView=nil;shotViewID=nil
        capturePreparedBoard();resolveElevation();save();refreshAim()
        requestPlayerView(.thirdPerson)
    }
    private func makePreparationRunner(count:Int,seed:UInt64?)->BreakFlowRunner {
        let runner=BreakFlowRunner(scene:scene,game:BreakFlowRunner.game(forBallCount:count),seed:seed)
        runner.managesCuePresentation=false;runner.managesPlaybackAudio=false;runner.showsAimAssist = !hidesAssists
        return runner
    }
    private func restorePreparedBreak() {
        guard let context=record.breakContext else { return }
        let runner=makePreparationRunner(count:context.prepared.count,seed:context.prepared.seed)
        breakRunner=runner;runner.restoreInput(context.prepared)
        runner.velocity=input.speed;runner.spinX=input.spinX;runner.spinY=input.spinY
        syncPreparedBreak()
    }
    private func syncPreparedBreak() {
        guard let prepared=breakRunner?.savedInput else { return }
        record.breakContext?.prepared=prepared
    }
    private func capturePreparedBoard() {
        record.board=Dictionary(uniqueKeysWithValues:PositionPlayBall.allKeys.compactMap { key in
            guard let node=scene.allBallNodes[key],!node.isHidden else { return nil }
            let q=node.simdOrientation.vector
            return (key,Record.Pose(position:.init(node.position),rotation:[q.x,q.y,q.z,q.w],disposition:"bed"))
        })
        topDownContentRevision += 1
    }
    private func finishBreakInput() {
        guard let context=record.breakContext else { return }
        input=context.ordinaryInput.limitingPracticeElevation()
        breakRunner?.cancel();breakRunner=nil;record.breakContext=nil
    }
    func setSpin(_ x:Double,_ y:Double) {
        updateInput { value in
            let limit=Double(CuePhysics.miscueLimitFraction)
            let length=hypot(x,y), scale=length>limit ? limit/length : 1
            value.spinX=x*scale;value.spinY=y*scale
        }
    }
    private var access:CueStrikeAccess? { scene.cueStrikeAccess(aim:input.aim) }
    private var strikePose:CueStrikeAccess.Pose? { access?.resolvedPose(spinX:input.spinX,spinY:input.spinY) }
    var cueAccessible:Bool { access?.isAvailable(spinX:input.spinX,spinY:input.spinY) == true }
    func applyPreferences(_ preferences:TablePreferenceSnapshot) {
        trajectoryDetail=preferences.trajectoryDetail
        hidesAssists = !preferences.enabled(.shows3DTrajectory)
        renderRoutes()
    }
    private func syncBreakAssist() {
        breakRunner?.showsAimAssist = !hidesAssists && !busy && !showsLastRoute
    }
    func refreshAim() {
        guard setup,!busy else { return }
        syncBreakAssist()
        updateCuePresentation()
        schedulePrediction()
    }
    private func updateCuePresentation(updatesCamera: Bool = true) {
        scene.explicitCueElevation=input.radians
        scene.refreshCueAccess(aim:input.aim)
        scene.setFreeAimPreviewLine(nil)
        if let pose=strikePose {
            scene.updateCueStick(cueBallPosition:pose.pivot,aimDirection:input.aim,
                elevationOverride:pose.elevation,tipInsetOverride:pose.inset,updatesCamera:updatesCamera)
        } else { scene.hideCueStick(preservingStrikeAccess:true) }
    }
    private var currentKey:RequestKey {
        .init(owner:ownerKey,instance:instance,geometry:SpatialPracticeGeometry.version,
            solver:"spatial-v2-handoff-resolution",input:input,board:record.board,breakContext:record.breakContext)
    }
    private func cancelCalculation() {
        cancellation?.cancel();pending=nil;submitted=nil;generation=UUID();preview=nil;showsLastRoute=false
        clearRoute()
        if phase == .calculating { phase = .ready }
    }
    private func schedulePrediction(immediate:Bool=false) {
        guard setup,!busy,validInput,cueAccessible,currentPlayerAim != nil else { return }
        let key=currentKey
        if let preview,preview.key==key {
            if submitted==key { startShot(preview.shot) } else { renderRoutes() }
            return
        }
        preview=nil;clearRoute()
        // Strike can consume a preview already being solved for this exact key.
        // Cancelling and restarting here repeats the most expensive part of a rack.
        if activeKey==key,cancellation?.isCancelled == false { return }
        if !immediate,pending?.key==key { return }
        cancellation?.cancel()
        generation=UUID()
        pending=Request(key:key,generation:generation,immediate:immediate)
        #if DEBUG
        scene.interactionTimingProbe?.beginPreview(id:generation,
            start:timingInputStart ?? TableInteractionTimingProbe.now,balls:key.board.count)
        timingInputStart=nil
        #endif
        guard worker == nil else { return }
        worker=Task { [weak self] in await self?.drainPredictions() }
    }
    private var activeKey:RequestKey?
    private func drainPredictions() async {
        while let next=pending {
            pending=nil
            if !next.immediate { try? await Task.sleep(for:.milliseconds(55)) }
            guard next.generation==generation else { continue }
            let token=PredictionCancellation();cancellation=token;activeKey=next.key
            let key=next.key
            #if DEBUG
            startedSolves += 1
            let timing=scene.interactionTimingProbe
            timing?.mark("solveStart",id:next.generation)
            #endif
            let outcome=await Task.detached(priority:.userInitiated) {
                #if DEBUG
                let observation=SpatialRuntimeProbe.Token("freeWorker")
                defer { observation.finish() }
                #endif
                let before=key.board,frozen=key.input
                guard let cue=before[PositionPlayBall.cueKey]?.position.scene else { return (nil as Record.Shot?,nil as String?) }
                let balls=before.keys.sorted().filter { !PositionPlayBall.isCue($0) && before[$0]?.disposition != "pocket" && before[$0]?.disposition != "escaped" }.compactMap { name in
                    before[name].map { ObstacleBall(name:name,position:$0.position.scene) }
                }
                let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:frozen.aim,velocity:Float(frozen.speed),
                    spinX:Float(frozen.spinX),spinY:Float(frozen.spinY),surfaceY:BTTablePhysics.surfaceY,
                    balls:balls,maxEvents:key.eventBudget,maxTime:40,simulationModel:.spatialPractice,cancellation:token,elevation:frozen.radians,
                    initialSpatialPositions:before.mapValues { $0.position.scene },buildPolylines:false)
                #if DEBUG
                timing?.mark("solved",id:next.generation)
                #endif
                guard var shot=Record.freeze(prediction:p,input:frozen,before:before,cancellation:token) else {
                    return (nil as Record.Shot?,"本杆接触计算未完成，请调整参数后重试")
                }
                shot.breakContext=key.breakContext
                #if DEBUG
                timing?.mark("frozen",id:next.generation)
                #endif
                if let recorder=p.recorder,!token.isCancelled {
                    let contactSounds=await MainActor.run {
                        ShotAudioScheduler.timeline(recorder:recorder,legacyEvents:p.events).map {
                            Record.Sound(time:$0.time,kind:$0.kind.rawValue,speed:$0.speed)
                        }
                    }
                    guard !token.isCancelled else { return (nil as Record.Shot?,nil as String?) }
                    shot.sounds=(contactSounds + Record.spatialSounds(recorder)).sorted { $0.time<$1.time }
                }
                #if DEBUG
                timing?.mark("soundsReady",id:next.generation)
                #endif
                return (shot,nil as String?)
            }.value
            cancellation=nil;activeKey=nil
            guard !token.isCancelled,next.generation==generation,key==currentKey,key.owner==ownerContext.ownerKey else { continue }
            #if DEBUG
            completedSolves += 1
            #endif
            guard let shot=outcome.0 else {
                if submitted==key { phase = .ready;submitted=nil;message=outcome.1 }
                continue
            }
            preview=(key,shot)
            if submitted==key { startShot(shot) } else { renderRoutes() }
        }
        worker=nil
    }
    func strike() {
        guard canStrike,submitted==nil else { return }
        #if DEBUG
        scene.interactionTimingProbe?.beginStroke(cached:preview?.key==currentKey,node:scene.cueStick?.timingMotionNode)
        #endif
        message=nil;showsLastRoute=false;submitted=currentKey;phase = .calculating
        schedulePrediction(immediate:true)
    }
    private func startShot(_ predicted:Record.Shot) {
        var shot=predicted
        guard submitted==currentKey,let pose=strikePose else { phase = .ready;submitted=nil;return }
        let recovery=SpatialPracticeRecovery.recover(shot.after,before:shot.before)
        shot.recovered=recovery.board;shot.recoveries=recovery.events
        shot.camera=scene.cameraRig?.trainingBookmark()
        shot.selectedTargetKey=selectedTargetKey
        activeShot=shot;archive.prepare(shot)
        submittedView=ShotReplayCamera.capture(in:scene);submittedViewID=shot.id
        submitted=nil;phase = .playing;syncBreakAssist();clearRoute()
        let request=generation
        scene.runCueStroke(strikePosition:pose.pivot,aim:shot.input.aim,velocity:Float(shot.input.speed),
            elevationOverride:pose.elevation,tipInsetOverride:pose.inset) { [weak self] in
            guard let self,self.generation==request else { return }
            self.play(shot,replay:false)
        }
    }
    private func apply(_ board:[String:Record.Pose]) {
        // Seating/recovery is a discrete board change, never a flight back to the bed.
        SCNTransaction.begin();SCNTransaction.disableActions=true
        defer { SCNTransaction.commit() }
        scene.hideAllBalls()
        for (key,pose) in board {
            guard let node=scene.allBallNodes[key] else { continue }
            node.removeAllActions();node.opacity=1;node.isHidden=pose.disposition == "pocket" || pose.disposition == "escaped"
            node.position=pose.position.scene
            if pose.rotation.count==4 { node.simdOrientation=simd_quatf(vector:SIMD4(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3])) }
        }
        topDownContentRevision += 1
    }
    private func play(_ shot:Record.Shot,replay:Bool) {
        clearRoute()
        activeShot=shot
        phase = replay ? .replaying : .playing
        let request=UUID();generation=request
        apply(shot.before)
        if replay {
            // Ordinary strokes already own their frozen cue pose and follow-through.
            // Updating it at contact would cancel runCueStroke's remaining actions.
            scene.explicitCueElevation=shot.input.radians
            scene.refreshCueAccess(aim:shot.input.aim)
            if let pose=scene.cueStrikeAccess(aim:shot.input.aim)?.resolvedPose(spinX:shot.input.spinX,spinY:shot.input.spinY) {
                scene.updateCueStick(cueBallPosition:pose.pivot,aimDirection:shot.input.aim,elevationOverride:pose.elevation,tipInsetOverride:pose.inset)
            }
            replayCamera.showShot(shotViewID == shot.id ? shotView : nil,in:scene,aim:shot.input.aim)
            if (shotViewID != shot.id || shotView == nil),let bookmark=shot.camera,let cue=scene.cueBallNode {
                scene.cameraRig?.restoreTrainingBookmark(bookmark,cue:cue.position,aim:shot.input.aim)
            }
            scene.hideCueStick()
        }
        beginTeachingRollingCamera(aim: shot.input.aim, replaying: replay, allowsReplayObservation: true)
        scene.setFreeAimPreviewLine(nil)
        let speed=replay ? playbackSpeed : 1
        #if DEBUG
        let probe=motionProbe
        probe.reset(enabled:ProcessInfo.processInfo.arguments.contains("-masseJump.probe"),speed:speed)
        #endif
        audioItems.forEach { $0.cancel() };audioItems=[]
        if UserPreferences.shared.soundEffectsEnabled {
            ShotSoundBank.shared.prepare()
            for sound in shot.sounds ?? [] {
                let item=DispatchWorkItem { [weak self] in
                    guard let self,self.generation==request,let kind=ShotSoundKind(rawValue:sound.kind) else { return }
                    ShotSoundBank.shared.play(kind:kind,speed:sound.speed)
                }
                audioItems.append(item);DispatchQueue.main.asyncAfter(deadline:.now()+Double(sound.time/speed),execute:item)
            }
        }
        let keys=shot.paths.keys.sorted().filter { key in
            guard let samples=shot.paths[key],let first=samples.first else { return false }
            return samples.contains { !Record.samePresentation(first,$0) }
        }
        if keys.isEmpty { finishPlayback(shot,replay:replay,request:request);return }
        guard keys.allSatisfy({scene.allBallNodes[$0] != nil}) else {
            stopPlayback();message="无法播放本杆，请重试";return
        }
        var pending=Set(keys)
        for key in keys {
            guard let node=scene.allBallNodes[key],let samples=shot.paths[key],!samples.isEmpty else { pending.remove(key);continue }
            let action=SCNAction.customAction(duration:TimeInterval(shot.duration/speed)) { node,elapsed in
                let time=min(shot.duration,Float(elapsed)*speed)
                var low=0,high=samples.count-1
                while low<high { let mid=(low+high+1)/2;if samples[mid].time<=time { low=mid } else { high=mid-1 } }
                let a=samples[low],b=samples[min(low+1,samples.count-1)]
                let t=b.time>a.time ? min(1,max(0,(time-a.time)/(b.time-a.time))) : 0
                node.position=a.position.scene+(b.position.scene-a.position.scene)*t
                let qa=simd_quatf(vector:SIMD4(a.rotation[0],a.rotation[1],a.rotation[2],a.rotation[3]))
                let qb=simd_quatf(vector:SIMD4(b.rotation[0],b.rotation[1],b.rotation[2],b.rotation[3]))
                node.simdOrientation=simd_slerp(qa,qb,t);node.isHidden=a.hidden
                #if DEBUG
                if PositionPlayBall.isCue(key) {
                    probe.append(shotTime:time,model:node.position,presentation:node.presentation.position)
                }
                #endif
            }
            node.runAction(action) { [weak self] in
                Task { @MainActor in
                    guard let self,self.generation==request else { return }
                    pending.remove(key)
                    guard pending.isEmpty else { return }
                    self.finishPlayback(shot,replay:replay,request:request)
                }
            }
        }
    }
    private func finishPlayback(_ shot:Record.Shot,replay:Bool,request:UUID) {
        guard generation==request,busy else { return }
        generation=UUID();audioItems.forEach { $0.cancel() };audioItems=[]
        if replay { restoreReplay();return }
        let recovery=shot.recovered ?? SpatialPracticeRecovery.recover(shot.after,before:shot.before).board
        record.board=recovery;record.lastShot=shot;activeShot=nil
        finishBreakInput()
        shotView=submittedViewID == shot.id ? submittedView:nil
        shotViewID=shot.id;submittedView=nil;submittedViewID=nil
        if shot.recoveries?.contains(where: { PositionPlayBall.isCue($0.key) && $0.destination == nil }) == true {
            message="没有可用的母球位置，请调整球形后放回母球"
        }
        apply(recovery);phase = .ready
        input.speed=ShotTuning.defaultVelocity;input.spinX=0;input.spinY=0
        recommendTarget()
        save()
        if selectedTargetKey != nil, cameraMode == .perspective3D, let rig = scene.cameraRig, rig.p01AnchoredTransitions {
            // Publish the new shaft geometry without jumping the eye ahead of its turn.
            _ = rig.updateP01TargetCue(resolved: true, align: false, preservePose: true, animated: false) { refreshAim() }
        } else {
            refreshAim()
        }
        settleTeachingCamera(frameRecommendedTarget: selectedTargetKey != nil)
    }
    func replay() {
        guard canTune,let shot=record.lastShot else { return }
        cancelCalculation();replayReturn=record.board
        replayCamera.begin(in:scene)
        play(shot,replay:true)
    }
    private func restoreReplay() {
        activeShot=nil
        if let replayReturn { apply(replayReturn) };replayReturn=nil
        phase = .ready;refreshAim();renderRoutes()
        replayCamera.finish(in:scene)
    }
    func stopPlayback() {
        #if DEBUG
        scene.interactionTimingProbe?.cancelStroke()
        #endif
        submittedView=nil;submittedViewID=nil
        generation=UUID();audioItems.forEach { $0.cancel() };audioItems=[];scene.cueStick?.cancelAnimations();scene.hideCueStick()
        for node in scene.allBallNodes.values { node.removeAllActions() }
        if phase == .replaying { restoreReplay() }
        else { activeShot=nil;apply(record.board);phase = .ready;refreshAim() }
    }
    func retry() {
        guard canTune,let shot=record.lastShot else { return };cancelCalculation()
        breakRunner?.cancel();breakRunner=nil
        record.selectedTargetKey=shot.selectedTargetKey
        record.breakContext=shot.breakContext
        record.board=shot.before;input=shot.input.limitingPracticeElevation();apply(record.board)
        restorePreparedBreak();save();refreshAim()
        if input.elevation != shot.input.elevation { message="本页抬杆上限为75°，重打已调整角度" }
    }
    func clear() {
        guard canEdit else { return };cancelCalculation();finishBreakInput();record.selectedTargetKey=nil;record.board=[:]
        if temporaryTopDownActive { topDownSelectionChanged=true }
        apply([:]);save();refreshAim()
    }
    func resetInputs() {
        guard canTune else { return }
        if isBreakMode { record.breakContext?.ordinaryInput = .init();cancelCalculation();save();refreshAim() }
        else { updateInput { $0 = .init() } }
    }
    func teachingTopDownDidEnd(contentChanged:Bool) {
        guard contentChanged else { return }
        refreshAim()
        if currentPlayerAim != nil { requestPlayerView(scene.cameraRig?.twoViewMode ?? .thirdPerson) }
        else { requestSurfaceOverview() }
    }
    func loadExample(_ index:Int) {
        guard !busy else { return };cancelCalculation();finishBreakInput()
        let y=BTTablePhysics.surfaceY+BallPhysics.radius
        func pose(_ x:Float,_ z:Float)->Record.Pose { .init(position:.init(SCNVector3(x,y,z)),rotation:[0,0,0,1],disposition:"bed") }
        record.board=[PositionPlayBall.cueKey:pose(-0.65,0),"_1":pose(-0.25,0),"_2":pose(0.6,0)]
        input = .init(yaw:0,speed:index==0 ? 4 : 2,spinX:index==0 ? 0 : (index==1 ? 0.45 : -0.45),spinY:0,elevation:index==0 ? 45 : Record.Input.maximumPracticeElevation)
        apply(record.board);save();refreshAim()
    }
    func showLandingMarker(_ visible:Bool) {
        landingMarker?.removeFromParentNode();landingMarker=nil
        guard visible,let landing=record.lastShot?.landing else { return }
        let ring=SCNTorus(ringRadius:CGFloat(BallPhysics.radius*1.3),pipeRadius:0.002)
        let material=SCNMaterial();material.diffuse.contents=UIColor.white;material.lightingModel = .constant
        ring.materials=[material]
        let node=SCNNode(geometry:ring);node.position=SCNVector3(landing.x,scene.surfaceY+0.003,landing.z)
        node.castsShadow=false;node.name="spatialFirstLanding";scene.rootNode.addChildNode(node);landingMarker=node
    }
    func toggleLastRoute() { showsLastRoute.toggle();syncBreakAssist();renderRoutes() }
    private func clearRoute() { routeNodes.forEach { $0.removeFromParentNode() };routeNodes=[] }
    private func renderRoutes() {
        clearRoute()
        let current=preview.flatMap { $0.key==currentKey ? $0.shot : nil }
        guard !busy,!hidesAssists,(!isBreakMode || showsLastRoute),let shot=showsLastRoute ? record.lastShot : current else { return }
        #if DEBUG
        scene.interactionTimingProbe?.mark("routesStart",id:generation)
        defer { scene.interactionTimingProbe?.routesReady(id:generation) }
        #endif
        for key in shot.paths.keys.sorted() {
            let node=SCNNode();node.name=showsLastRoute ? "spatialLastShotRoute" : "spatialPreviewRoute"
            guard SpatialShotRendering.appendBallRoute(shot,key:key,detail:showsLastRoute ? .full : trajectoryDetail,
                to:node,scene:scene,presentation:showsLastRoute ? .historical : .current) else { continue }
            scene.rootNode.addChildNode(node);routeNodes.append(node)
        }
    }
    /// Choose a free-practice starting target from the settled table. No pocket is committed.
    private func recommendTarget(preserveAim:Bool = false) {
        record.selectedTargetKey=nil
        guard let cue=record.board[PositionPlayBall.cueKey], cue.disposition == "bed" else { return }
        let keys=onTableKeys.filter { !PositionPlayBall.isCue($0) }
        var assessment=DefenseAttackAssessment()
        assessment.usePrecomputedWindows=true
        var candidates:[DailyShotRecommendation.Candidate]=[]
        for key in keys {
            guard let target=record.board[key]?.position.scene else { continue }
            let obstacles=keys.filter { $0 != key }.compactMap { record.board[$0]?.position.scene }
            do {
                candidates += try DailyShotRecommendation.attackCandidates(cue:cue.position.scene,
                    target:target,targetKey:key,obstacles:obstacles,surfaceY:scene.surfaceY,assessment:&assessment)
            } catch {
                message="本次未能推荐目标球，可点选桌上的球继续"
                resolveElevation()
                return
            }
        }
        if let best=DailyShotRecommendation.best(candidates) {
            record.selectedTargetKey=best.targetKey
            if !preserveAim, let point=record.board[best.targetKey]?.position {
                input.yaw=Double(atan2f(point.z-cue.position.z,point.x-cue.position.x))
            }
        }
        if !preserveAim { resolveElevation(forNewTarget: record.selectedTargetKey != nil) }
    }

    private func resolveElevation(forNewTarget: Bool = false) {
        let resolved = SpatialCueElevation.resolve(input,access:access,forNewTarget:forNewTarget)
        if resolved != input { input = resolved }
    }
    func selectPocket(at index:Int) {}
    func selectTarget(key:String) {
        guard canEdit,!isBreakMode,!PositionPlayBall.isCue(key),
              let cue=record.board[PositionPlayBall.cueKey]?.position.scene,let target=record.board[key]?.position.scene else { return }
        record.selectedTargetKey=key
        input.yaw=Double(atan2f(target.z-cue.z,target.x-cue.x))
        resolveElevation(forNewTarget: true)
        if temporaryTopDownActive { topDownSelectionChanged=true }
        cancelCalculation();save();refreshAim()
    }
    func palettePlacement(_ key:String,atWorld world:SCNVector3)->SCNVector3? {
        guard canEdit,!isBreakMode,PositionPlayBall.allKeys.contains(key) else { return nil }
        let r=BallPhysics.radius
        guard abs(world.x)<TablePhysics.innerLength/2-r,abs(world.z)<TablePhysics.innerWidth/2-r else { return nil }
        let p=AngleSceneCalculator.clampAwayFromPockets(world,surfaceY:scene.surfaceY)
        guard onTableKeys.filter({ $0 != key }).allSatisfy({ k in
            guard let q=record.board[k]?.position.scene else { return true }
            return hypotf(p.x-q.x,p.z-q.z)>2*r+0.0001
        }) else { return nil }
        return SCNVector3(p.x,scene.surfaceY+r,p.z)
    }
    private func reconcileEditedBoard() {
        if let key=selectedTargetKey, record.board[key]?.disposition == "bed" {
            resolveElevation()
        } else if onTableKeys.contains(where:{ !PositionPlayBall.isCue($0) }) {
            recommendTarget()
        } else {
            record.selectedTargetKey=nil
            resolveElevation()
        }
    }
    func place(_ key:String,at world:SCNVector3) {
        guard let p=palettePlacement(key,atWorld:world) else { return };cancelCalculation()
        record.board[key] = .init(position:.init(p),rotation:[0,0,0,1],disposition:"bed")
        if temporaryTopDownActive { topDownSelectionChanged=true }
        apply(record.board)
        reconcileEditedBoard()
        save();refreshAim()
    }
    func placeFromPalette(_ key:String) {
        guard canEdit else { return }
        for ix in 0..<25 { for iz in 0..<11 {
            let p=SCNVector3(-1.1+Float(ix)*0.09,scene.surfaceY+BallPhysics.radius,-0.45+Float(iz)*0.09)
            if palettePlacement(key,atWorld:p) != nil { place(key,at:p);return }
        } }
    }
    func removeFromTable(_ key:String) {
        guard canEdit,!isBreakMode else { return };cancelCalculation();record.board.removeValue(forKey:key)
        if temporaryTopDownActive { topDownSelectionChanged=true }
        apply(record.board)
        reconcileEditedBoard()
        save();refreshAim()
    }
    func dragBegan(node:SCNNode) {
        guard canEdit,draggableBalls.contains(where:{$0 === node}) else { return }
        cancelCalculation();initialDrag=node.position;isDragging=true;breakRunner?.dragBegan(node:node)
    }
    func dragMoved(node:SCNNode,worldPosition:SCNVector3) {
        if isDragging,let runner=breakRunner {
            runner.dragMoved(node:node,worldPosition:worldPosition)
            if let aim=runner.aimDir { input.yaw=Double(atan2f(aim.z,aim.x)) }
            updateDraggedCuePose()
            return
        }
        guard isDragging,let key=scene.ballKey(for:node),let p=palettePlacement(key,atWorld:worldPosition) else { return }
        guard node.position.x != p.x || node.position.z != p.z else { return }
        node.position=p
        updateDraggedCuePose()
    }
    private func updateDraggedCuePose() {
        resolveElevation()
        updateCuePresentation(updatesCamera: false)
    }
    func dragEnded(node:SCNNode) {
        guard isDragging else { return };isDragging=false
        if let runner=breakRunner {
            runner.dragEnded(node:node);syncPreparedBreak();capturePreparedBoard()
            if temporaryTopDownActive { topDownSelectionChanged=true }
            initialDrag=nil;resolveElevation();save();refreshAim();return
        }
        if let key=scene.ballKey(for:node) { place(key,at:node.position) };initialDrag=nil
    }
    func suspendTeachingActivity() {
        showLandingMarker(false)
        if isDragging {
            if let node=scene.cueBallNode { breakRunner?.dragEnded(node:node) }
            apply(record.board);isDragging=false;initialDrag=nil
            if isBreakMode {
                restorePreparedBreak()
                if let aim=breakRunner?.aimDir { input.yaw=Double(atan2f(aim.z,aim.x)) }
            }
            resolveElevation()
        }
        saveTask?.cancel();if busy { stopPlayback() };cancelCalculation();save();archive.end();scene.cameraRig?.suspendP01Motion();scene.isPaused=true
    }
    func resumeTeachingActivity() {
        guard setup else { return }
        if !archive.isActiveWriter { ownerChanged() }
        else { scene.isPaused=false;refreshAim() }
    }
}

#if DEBUG
/// Action evaluation cadence, not a replacement for display/GPU frame profiling.
/// Enabled only in the diagnostic launch; no SwiftUI publishes during playback.
private final class SpatialPracticeMotionProbe: @unchecked Sendable {
    private let lock=NSLock()
    private var enabled=false
    private var speed:Float=1
    private var rows:[[Double]]=[]
    func reset(enabled:Bool,speed:Float) {
        lock.lock();defer { lock.unlock() }
        self.enabled=enabled;self.speed=speed;rows=[]
    }
    func append(shotTime:Float,model:SCNVector3,presentation:SCNVector3) {
        lock.lock();defer { lock.unlock() }
        guard enabled,rows.count<12000 else { return }
        rows.append([ProcessInfo.processInfo.systemUptime,Double(shotTime),
            Double(model.x),Double(model.y),Double(model.z),
            Double(presentation.x),Double(presentation.y),Double(presentation.z)])
    }
    var json:String {
        lock.lock();defer { lock.unlock() }
        guard enabled,let data=try? JSONSerialization.data(withJSONObject:["speed":speed,
            "columns":["wall","shotTime","modelX","modelY","modelZ","presentationX","presentationY","presentationZ"],
            "rows":rows]) else { return "{}" }
        return String(decoding:data,as:UTF8.self)
    }
}
#endif
