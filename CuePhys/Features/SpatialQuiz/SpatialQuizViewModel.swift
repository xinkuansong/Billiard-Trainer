import SwiftUI
import SceneKit
import SwiftData
import Combine

@MainActor
final class SpatialQuizViewModel: ObservableObject, TeachingTableHost {
    typealias Space = SpatialPracticeRecord
    let mode: SpatialQuizMode
    let scene = AngleTrainingScene(trajectoryWidths: .interactiveTable)
    let limiter: AngleUsageLimiter
    private let settingsDefaults: UserDefaults
    @Published private(set) var bank: SpatialQuizBank.Bank?
    @Published private(set) var session: SpatialQuizSession?
    @Published var showsSettings = true
    @Published var loading = true
    @Published var message: String?
    @Published var needsSubscription = false
    @Published private(set) var input = SpatialQuizPhysics.Input(yaw:0,speed:2,spinX:0,spinY:0,elevation:45)
    @Published private(set) var activeShot: Space.Shot?
    @Published var cameraMode: AngleTrainingScene.CameraMode = .perspective3D
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    var topDownSelectionChanged = false
    @Published var showsLastRoute = false
    @Published private(set) var closeupSnapshot: AimCloseupSnapshot?
    private var closeupWasNear = false
    private(set) var aimingLine: AimCloseupSegment?
    @Published var playbackSpeed: Float = 1
    @Published private(set) var layoutEditing = false
    #if DEBUG
    private let lifetime = SpatialRuntimeProbe.Token("quizVM")
    var timingJSON: String { scene.interactionTimingProbe?.json ?? "[]" }
    #endif
    private var built = false
    private var active = false
    private var context: ModelContext?
    private var subscription: AnyCancellable?
    private var work: Task<Void,Never>?
    private var draftSave: Task<Void,Never>?
    private var cancellation: PredictionCancellation?
    private var generation = UUID()
    private var routeNodes: [SCNNode] = []
    private var audioItems: [DispatchWorkItem] = []
    private var replayCamera = ShotReplayCamera()
    private var returnBoard: [String:Space.Pose]?
    private var shotView: CameraRig.PerspectiveState?
    private var activeSince: Date?
    var record: SpatialQuizRecord? { session?.record }
    var preferencePage: TablePreferencePage { mode == .masse ? .massePractice : .jumpPractice }
    var identifier: String { mode.kind }
    var displayedInput: Space.Input { activeShot?.input ?? input.spatialInput }
    var busy: Bool { session?.activity != .idle && session?.activity != .unconfirmed }
    var canAdjust: Bool { active && !showsSettings && !layoutEditing && !cameraTransitionBusy && !temporaryTopDownActive && session?.canAdjust == true }
    var cueAccessible: Bool { scene.cueStrikeAccess(aim:input.aim)?.isAvailable(spinX:input.spinX,spinY:input.spinY) == true }
    var currentPlayerAim: SCNVector3? {
        guard let cue = scene.cueBallNode, !cue.isHidden else { return nil }
        return displayedInput.aim
    }
    var selectedTargetKey: String? { record?.current.source.board.targetName }
    var targetNode: SCNNode? { selectedTargetKey.flatMap { scene.allBallNodes[$0] } }
    var selectedPocketIndex: Int { -1 }
    var onTableKeys: [String] { record.map { [$0.current.source.board.targetName,"_8"] } ?? [] }
    var draggableBalls: [SCNNode] { [] }
    var selectableBalls: [SCNNode] { [] }
    var isDragging: Bool { false }
    var canRetry: Bool { !busy && (record?.latestShot != nil || session?.activity == .unconfirmed) && !layoutEditing && !temporaryTopDownActive }
    var canReplay: Bool { canRetry && record?.latestShot != nil }
    var canDemonstrate: Bool { session?.canDemonstrate == true && !layoutEditing && !temporaryTopDownActive }
    var showsDemonstration: Bool { record?.phase == .result && record?.demonstrationProgress.unlocked == true }
    var canStop: Bool { [.calculating,.playing,.replaying,.demonstrating].contains(session?.activity ?? .idle) }
    var primaryTitle: String {
        if canStop { return "停止" }
        if session?.activity == .saveFailed { return "重试保存" }
        if session?.activity == .unconfirmed { return "重试计算" }
        if record?.phase == .result {
            return record?.status != .active || limiter.isLimitReached || (record?.configuration.freePractice == false && record?.cursor == 14) ? "查看总结" : "下一题"
        }
        return "击球"
    }
    var primaryEnabled: Bool {
        guard !layoutEditing, !cameraTransitionBusy, !temporaryTopDownActive else { return false }
        return canStop || session?.activity == .saveFailed || session?.activity == .unconfirmed ||
            (session?.activity == .idle && (record?.phase == .result || (canAdjust && cueAccessible)))
    }
    init(mode: SpatialQuizMode, limiter: AngleUsageLimiter? = nil, settingsDefaults: UserDefaults? = nil) {
        self.mode=mode;self.limiter=limiter ?? (mode == .masse ? .masseTraining : .jumpTraining)
        #if DEBUG
        let testDefaults=ProcessInfo.processInfo.environment["SPATIAL_TEST_SESSION"].flatMap { UserDefaults(suiteName:"spatialQuiz.tests."+$0) }
        self.settingsDefaults=settingsDefaults ?? testDefaults ?? .standard
        #else
        self.settingsDefaults=settingsDefaults ?? .standard
        #endif
    }
    var savedConfiguration: SpatialQuizConfiguration? {
        settingsDefaults.data(forKey:settingsKey).flatMap { try? JSONDecoder().decode(SpatialQuizConfiguration.self,from:$0) }
    }
    func attach(context: ModelContext) {
        guard self.context == nil else { return }; self.context=context; load()
    }
    private func load() {
        guard let context else { return }
        loading=true; let key=UUID();generation=key
        let owner=CurrentOwnerContext.shared.ownerKey, mode=mode
        work=Task { [weak self] in
            let outcome=await Task.detached(priority:.userInitiated) { Result { try SpatialQuizBank.load(mode) } }.value
            guard let self, self.generation==key, CurrentOwnerContext.shared.ownerKey==owner, !Task.isCancelled else { return }
            do {
                let bank=try outcome.get();self.bank=bank
                let session=SpatialQuizSession(mode:mode,repository:LocalSpatialQuizRepository(context:context),limiter:self.limiter)
                self.session=session
                self.subscription=session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
                try session.restore(bank:bank)
                self.message=session.message;self.showsSettings=session.record==nil
                if let record=session.record { self.input=record.draft;self.installQuestion() }
            } catch { self.message=error.localizedDescription;self.showsSettings=true }
            self.loading=false
        }
    }
    func start(_ configuration: SpatialQuizConfiguration) {
        guard let bank,let session else { load();return }
        guard limiter.isPremium || (!configuration.freePractice && !limiter.isLimitReached) else { needsSubscription=true;return }
        do {
            try session.start(configuration:configuration,bank:bank)
            guard let record=session.record else { return }
            settingsDefaults.set(try JSONEncoder().encode(configuration),forKey:settingsKey)
            input=record.draft;showsSettings=false;message=nil;showsLastRoute=false
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-spatialQuiz.referenceInput") { input=record.current.source.reference }
            #endif
            installQuestion()
        } catch { message=error.localizedDescription }
    }
    var settingsKey: String { mode.kind+".configuration."+CurrentOwnerContext.shared.ownerKey }
    func setupScene() {
        guard !built else { return };built=true;active=true
        #if DEBUG
        if SpatialRuntimeProbe.enabled { scene.interactionTimingProbe=TableInteractionTimingProbe() }
        #endif
        scene.isolatesTemporaryTopDownMaterials=true
        scene.configureReferenceTableRendering();scene.configureShotAwareCamera()
        scene.setupScene();scene.setupVisualizationNodes();configureTeachingCamera(policy:.p01Replayable)
        installQuestion()
    }
    private func installQuestion() {
        guard built,let record else { return }
        scene.isPaused=false;active=true
        scene.hideAllVisualization();clearRoutes();showsLastRoute=record.latestShot != nil
        closeupWasNear=false;closeupSnapshot=nil;aimingLine=nil
        let b=record.current.source.board
        scene.applyBallLayout(cueBallPosition:b.cue,targetBallNumber:b.targetNumber,targetPosition:b.target)
        scene.configureBallInstances([b.targetName,"_8"]);scene.railInventory.clear()
        scene.setPracticePocketRoles(current:nil,next:nil)
        apply(record.phase == .result ? record.latestShot?.physical.after ?? record.current.board : record.current.board)
        input=record.draft
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-spatialQuiz.referenceInput"), record.currentFirst == nil { input=record.current.source.reference }
        if ProcessInfo.processInfo.arguments.contains("-spatialQuiz.missInput"), record.currentFirst == nil {
            input.yaw += .pi;input.speed=0.1;input.elevation=10;input.spinX=0;input.spinY=0
        }
        #endif
        if record.phase != .result {
            resolveElevation();refreshAim();saveDraft()
        } else { scene.hideCueStick();scene.setFreeAimPreviewLine(nil) }
        refreshObservationCameraContext();scene.discardSavedPerspectiveView()
        // TP17: entry/re-entry starts at this shot's shared third-person pose.
        // Saved player viewpoints belong to replay/retry, not page entry.
        requestPlayerView(.thirdPerson,animated:false,resetThirdPerson:true)
        drawRoutes();activeSince=Date()
    }
    private func apply(_ board:[String:Space.Pose]) {
        SCNTransaction.begin();SCNTransaction.disableActions=true
        scene.hideAllBalls()
        for (key,pose) in board {
            guard let node=scene.allBallNodes[key] else { continue }
            node.removeAllActions();node.opacity=1;node.isHidden=["pocket","escaped"].contains(pose.disposition)
            node.position=pose.position.scene
            node.simdOrientation=simd_quatf(vector:SIMD4(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3]))
        }
        SCNTransaction.commit();topDownContentRevision += 1
    }
    func updateInput(_ change:(inout SpatialQuizPhysics.Input)->Void) {
        guard canAdjust else { return }
        #if DEBUG
        let timingID=UUID(),timingStart=TableInteractionTimingProbe.now
        #endif
        var next=input;change(&next)
        next.elevation=min(75,max(0,next.elevation));next.speed=min(8,max(0.1,next.speed))
        if next.elevation != input.elevation { next.preferredElevation=nil }
        guard next.valid else { return }
        #if DEBUG
        scene.interactionTimingProbe?.beginPreview(id:timingID,start:timingStart,balls:3)
        #endif
        input=next;resolveElevation();refreshAim();message=nil
        #if DEBUG
        scene.interactionTimingProbe?.routesReady(id:timingID)
        #endif
        draftSave?.cancel();let owner=record?.ownerKey,id=record?.current.id
        draftSave=Task { [weak self] in
            do { try await Task.sleep(for:.milliseconds(180)) } catch { return }
            guard let self,!Task.isCancelled,self.record?.ownerKey==owner,self.record?.current.id==id else { return }
            self.saveDraft()
        }
    }
    func setSpin(_ x:Double,_ y:Double) {
        let length=hypot(x,y),scale=length>0.8 ? 0.8/length : 1
        updateInput { $0.spinX=x*scale;$0.spinY=y*scale }
    }
    func nudgeAim(_ degrees:Float) {
        guard canAdjust else { return }
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

    func nudgeElevation(_ delta:Float) {
        updateInput { value in
            let desired=value.preferredElevation ?? value.elevation
            value.elevation=(delta<0 ? min(desired,value.elevation) : max(desired,value.elevation))+Double(delta)
        }
    }
    private func resolveElevation() {
        scene.explicitCueElevation=input.radians
        let resolved=SpatialCueElevation.resolve(input.spatialInput,access:scene.cueStrikeAccess(aim:input.aim))
        input.elevation=resolved.elevation;input.preferredElevation=resolved.preferredElevation
    }
    func refreshAim() {
        guard built, active, !busy else { return }
        scene.hideAllVisualization();scene.setIdealObjectLine(nil);scene.setFreeAimPreviewLine(nil)
        aimingLine=nil;closeupSnapshot=nil
        guard record?.phase == .aiming else { closeupWasNear=false;scene.hideCueStick();return }
        scene.explicitCueElevation=input.radians;scene.refreshCueAccess(aim:input.aim)
        if let pose=scene.cueStrikeAccess(aim:input.aim)?.resolvedPose(spinX:input.spinX,spinY:input.spinY) {
            scene.updateCueStick(cueBallPosition:pose.pivot,aimDirection:input.aim,elevationOverride:pose.elevation,tipInsetOverride:pose.inset)
            if let cue=scene.cueBallNode,let target=targetNode {
                // The current-direction guide uses shared XZ geometry, not the
                // spatial prediction or reference answer. Only target clips it.
                func point(_ p:SCNVector3)->CGPoint { .init(x:CGFloat(p.x),y:CGFloat(p.z)) }
                let rail=AngleSceneCalculator.rayToInnerRail(from:cue.position,dir:input.aim)
                let resolved=AimLineGeometry.resolve(cue:point(cue.position),dir:point(input.aim),
                    target:point(target.position),ballRadius:CGFloat(BallPhysics.radius),railEnd:point(rail))
                aimingLine = .init(start:point(cue.position),end:resolved.lineEnd)
                scene.setFreeAimPreviewLine(aimingLine)
                let closeup=AimCloseupBuilder.currentAim(cue:point(cue.position),direction:point(input.aim),
                    target:point(target.position),number:record?.current.source.targetNumber,
                    ballRadius:CGFloat(BallPhysics.radius),railEnd:point(rail),previouslyNear:closeupWasNear)
                closeupWasNear=closeup.isNear;closeupSnapshot=closeup.snapshot
            }
        } else { scene.hideCueStick(preservingStrikeAccess:true) }
    }
    private func saveDraft() {
        guard session?.canAdjust == true else { return }
        do { try session?.updateDraft(input) } catch { message=error.localizedDescription }
    }
    func primary() {
        if canStop { stopPlayback();return }
        if session?.activity == .saveFailed {
            if session?.retrySave() == true { deliverSavedResult() };return
        }
        if record?.phase == .result, session?.activity == .idle { next();return }
        strike()
    }
    func strike() {
        guard let session,let question=record?.current,
              (canAdjust && cueAccessible) || session.activity == .unconfirmed else { return }
        draftSave?.cancel();clearRoutes()
        do {
            if session.canAdjust { try session.updateDraft(input) }
            guard let pending=try session.freeze() else { return }
            checkpoint()
            let bookmark=scene.cameraRig?.trainingBookmark()
            let token=PredictionCancellation(),key=UUID(),owner=record?.ownerKey
            cancellation=token;generation=key;shotView=ShotReplayCamera.capture(in:scene)
            updateTeachingStrokeCamera(locked:true)
            work=Task { [weak self] in
                let result=await Task.detached(priority:.userInitiated) {
                    #if DEBUG
                    let observation=SpatialRuntimeProbe.Token("quizWorker")
                    defer { observation.finish() }
                    #endif
                    let solved=SpatialQuizPhysics.solve(board:question.source.board,input:pending.input,cancellation:token)
                    return Result { (try SpatialQuizShot.make(solved,pending:pending,question:question,cancellation:token),solved.prediction) }
                }.value
                guard let self,!token.isCancelled,!Task.isCancelled,self.generation==key,self.record?.ownerKey==owner,
                      owner==CurrentOwnerContext.shared.ownerKey else { return }
                self.cancellation=nil
                switch result {
                case .success(var value):
                    value.0.physical.camera=bookmark
                    self.addSounds(to:&value.0.physical,prediction:value.1)
                    if session.accept(value.0,pending:pending) { self.deliverSavedResult() }
                    else if session.activity == .calculating {
                        session.calculationUnconfirmed(pending,message:"本次击球数据未能确认，请重试计算")
                    }
                case .failure(let error): session.calculationUnconfirmed(pending,message:error.localizedDescription)
                }
                self.message=session.message;self.updateTeachingStrokeCamera(locked:self.busy)
            }
        } catch { message=error.localizedDescription }
    }
    private func deliverSavedResult() {
        guard let shot=record?.latestShot else { return }
        showsLastRoute=true
        if session?.activity == .playing { play(shot.physical,replay:false) }
        else { apply(shot.physical.after);scene.hideCueStick();updateTeachingStrokeCamera(locked:false);drawRoutes() }
    }
    func retry() {
        guard canRetry else { return }
        do { try session?.retry();guard let record else { return };input=record.draft;apply(record.current.board)
            resolveElevation();refreshAim();drawRoutes()
            if let shotView { scene.restorePerspectiveView(shotView) }
            else if let bookmark=record.latestShot?.physical.camera,let cue=scene.cueBallNode {
                scene.cameraRig?.restoreTrainingBookmark(bookmark,cue:cue.position,aim:input.aim)
            } else { requestPlayerView(.thirdPerson,animated:false,resetThirdPerson:true) }
        } catch { message=error.localizedDescription }
    }
    func next() {
        if record?.status == .active && record?.configuration.freePractice == true && !limiter.isPremium { needsSubscription=true;return }
        guard let bank else { return };checkpoint()
        do { try session?.next(bank:bank);if record?.phase != .summary { installQuestion() } }
        catch { message=error.localizedDescription }
    }
    func finish() { checkpoint();do { try session?.finish() } catch { message=error.localizedDescription } }
    func openSettings() { guard !busy else { return };saveDraft();showsSettings=true }
    func cancelSettings()->Bool { guard record != nil else { return false };showsSettings=false;return true }
    func replay() {
        guard canReplay,let shot=session?.beginReplay() else { return }
        returnBoard=captureBoard();replayCamera.begin(in:scene);play(shot.physical,replay:true)
    }
    func demonstrate() {
        guard canDemonstrate,let session,let question=session.beginDemonstration() else { return }
        returnBoard=captureBoard();replayCamera.begin(in:scene)
        let token=PredictionCancellation(),key=UUID(),owner=record?.ownerKey
        cancellation=token;generation=key
        work=Task { [weak self] in
            let output=await Task.detached(priority:.userInitiated) {
                #if DEBUG
                let observation=SpatialRuntimeProbe.Token("quizWorker")
                defer { observation.finish() }
                #endif
                let solved=SpatialQuizPhysics.solve(board:question.source.board,input:question.source.reference,cancellation:token)
                guard solved.outcome.succeeded,let shot=Space.freeze(prediction:solved.prediction,input:question.source.reference.spatialInput,before:question.board,cancellation:token) else { return nil as (Space.Shot,ShotPrediction)? }
                return (shot,solved.prediction)
            }.value
            guard let self,!token.isCancelled,self.generation==key,self.record?.ownerKey==owner,
                  owner==CurrentOwnerContext.shared.ownerKey else { return }
            self.cancellation=nil
            guard var value=output else { self.stopPlayback();self.message="示范暂时无法完成，请重试";return }
            self.addSounds(to:&value.0,prediction:value.1);self.play(value.0,replay:true)
        }
    }
    private func captureBoard()->[String:Space.Pose] {
        guard let record else { return [:] }
        if record.phase == .result { return record.latestShot?.physical.after ?? record.current.board }
        return record.current.board
    }
    private func play(_ shot:Space.Shot,replay:Bool) {
        clearRoutes();activeShot=shot;apply(shot.before);let key=UUID();generation=key
        scene.explicitCueElevation=shot.input.radians;scene.refreshCueAccess(aim:shot.input.aim)
        let pose=scene.cueStrikeAccess(aim:shot.input.aim)?.resolvedPose(spinX:shot.input.spinX,spinY:shot.input.spinY)
        if let pose {
            scene.updateCueStick(cueBallPosition:pose.pivot,aimDirection:shot.input.aim,elevationOverride:pose.elevation,tipInsetOverride:pose.inset)
        }
        if replay {
            if session?.activity == .demonstrating {
                // Seat the reference board and shaft before framing it. A synchronous
                // shared reset guarantees no old-view transition overlaps cue stroke.
                guard requestPlayerView(.thirdPerson,animated:false,resetThirdPerson:true),
                      scene.cameraRig?.isTransitioning == false,
                      scene.cameraRig?.thirdPersonEntryAwaitsLayout == false else {
                    stopPlayback();message="示范视角暂时无法准备，请重试";return
                }
            } else {
                replayCamera.showShot(shotView,in:scene,aim:shot.input.aim)
                if shotView == nil,let bookmark=shot.camera,let cue=scene.cueBallNode {
                    scene.cameraRig?.restoreTrainingBookmark(bookmark,cue:cue.position,aim:shot.input.aim)
                }
            }
        }
        // Reveal the committed shot before cue animation, including replay/demo.
        scene.setFreeAimPreviewLine(nil)
        drawRoutes(for:shot)
        updateTeachingStrokeCamera(locked:true)
        if let pose {
            scene.runCueStroke(strikePosition:pose.pivot,aim:shot.input.aim,velocity:Float(shot.input.speed),rehearsalEnabled:false,elevationOverride:pose.elevation,tipInsetOverride:pose.inset) { [weak self] in
                guard let self,self.generation==key else { return };self.animate(shot,replay:replay,key:key)
            }
        } else { animate(shot,replay:replay,key:key) }
    }
    private func animate(_ shot:Space.Shot,replay:Bool,key:UUID) {
        scene.hideCueStick();scene.setFreeAimPreviewLine(nil);beginTeachingRollingCamera(aim:shot.input.aim,replaying:replay,allowsReplayObservation:true)
        let speed=replay ? playbackSpeed : 1
        audioItems.forEach { $0.cancel() };audioItems=[]
        if UserPreferences.shared.soundEffectsEnabled {
            ShotSoundBank.shared.prepare()
            for sound in shot.sounds ?? [] {
                let item=DispatchWorkItem { [weak self] in
                    guard let self,self.generation==key,let kind=ShotSoundKind(rawValue:sound.kind) else { return }
                    ShotSoundBank.shared.play(kind:kind,speed:sound.speed)
                }
                audioItems.append(item);DispatchQueue.main.asyncAfter(deadline:.now()+Double(sound.time/speed),execute:item)
            }
        }
        var pending=Set(shot.paths.keys)
        for (name,samples) in shot.paths {
            guard let node=scene.allBallNodes[name],!samples.isEmpty else { pending.remove(name);continue }
            node.runAction(.customAction(duration:Double(shot.duration/speed)) { node,elapsed in
                let time=min(shot.duration,Float(elapsed)*speed)
                var low=0,high=samples.count-1
                while low<high { let mid=(low+high+1)/2;if samples[mid].time<=time { low=mid } else { high=mid-1 } }
                let a=samples[low],b=samples[min(low+1,samples.count-1)]
                let t=b.time>a.time ? min(1,max(0,(time-a.time)/(b.time-a.time))) : 0
                node.position=a.position.scene+(b.position.scene-a.position.scene)*t
                node.simdOrientation=simd_slerp(simd_quatf(vector:SIMD4(a.rotation[0],a.rotation[1],a.rotation[2],a.rotation[3])),
                    simd_quatf(vector:SIMD4(b.rotation[0],b.rotation[1],b.rotation[2],b.rotation[3])),t)
                node.isHidden=a.hidden
            }) { [weak self] in Task { @MainActor in
                guard let self,self.generation==key else { return };pending.remove(name)
                if pending.isEmpty { self.stopPlayback() }
            } }
        }
        if pending.isEmpty { stopPlayback() }
    }
    func stopPlayback() {
        let wasCalculating=session?.activity == .calculating
        generation=UUID();cancellation?.cancel();cancellation=nil;work?.cancel();work=nil
        audioItems.forEach { $0.cancel() };audioItems=[]
        scene.allBallNodes.values.forEach { $0.removeAllActions() };scene.hideCueStick()
        let restore=returnBoard;returnBoard=nil;activeShot=nil
        if let restore { apply(restore) }
        else if wasCalculating,let record { apply(record.current.board) }
        else if let shot=record?.latestShot { apply(shot.physical.after) }
        if wasCalculating { session?.suspend() }
        session?.playbackFinished();updateTeachingStrokeCamera(locked:false)
        if restore != nil { refreshAim();replayCamera.finish(in:scene) }
        drawRoutes()
    }
    func toggleLastRoute() { guard !busy else { return };showsLastRoute.toggle();drawRoutes() }
    private func clearRoutes() { routeNodes.forEach { $0.removeFromParentNode() };routeNodes=[] }
    private func drawRoutes(for playingShot:Space.Shot? = nil) {
        clearRoutes()
        guard let shot=playingShot ?? (showsLastRoute && !busy ? record?.latestShot?.physical : nil) else { return }
        let presentation:TrajectoryStyle.Presentation = playingShot == nil && record?.phase == .aiming ? .historical : .current
        for key in shot.paths.keys.sorted() {
            let node=SCNNode();node.name="spatialQuizActualRoute"
            guard SpatialShotRendering.appendBallRoute(shot,key:key,detail:.full,to:node,scene:scene,presentation:presentation) else { continue }
            scene.rootNode.addChildNode(node);routeNodes.append(node)
        }
    }
    func layoutEditingChanged(_ value:Bool) {
        if value { saveDraft();checkpoint();activeSince=nil } else { activeSince=Date() }
        layoutEditing=value
    }
    private func addSounds(to shot:inout Space.Shot,prediction:ShotPrediction) {
        guard let recorder=prediction.recorder else { return }
        shot.sounds=(ShotAudioScheduler.timeline(recorder:recorder,legacyEvents:prediction.events).map {
            Space.Sound(time:$0.time,kind:$0.kind.rawValue,speed:$0.speed)
        } + Space.spatialSounds(recorder)).sorted { $0.time<$1.time }
    }
    private func checkpoint() {
        let now=Date(),elapsed=activeSince.map { max(0,now.timeIntervalSince($0)) } ?? 0
        do { try session?.savePresentation(bookmark:scene.cameraRig?.trainingBookmark(),elapsed:elapsed);activeSince=now }
        catch { message=error.localizedDescription }
    }
    func reviewLast() { do { try session?.reviewLastQuestion() } catch { message=error.localizedDescription } }
    func ownerChanged() { suspendTeachingActivity();session?.invalidateOwner();session=nil;subscription=nil;bank=nil;showsSettings=true;load() }
    func suspendTeachingActivity() {
        draftSave?.cancel();saveDraft();checkpoint();active=false
        if canStop { stopPlayback() }
        cancellation?.cancel();generation=UUID();work?.cancel();work=nil;session?.suspend()
        audioItems.forEach { $0.cancel() };audioItems=[]
        scene.cameraRig?.suspendP01Motion();scene.isPaused=true;activeSince=nil
    }
    func resumeTeachingActivity() {
        guard built else { return };active=true;scene.isPaused=false;limiter.refreshDay();refreshAim();activeSince=Date()
    }
    func selectPocket(at index:Int) {}
    func selectTarget(key:String) {}
    func placeFromPalette(_ key:String) {}
    func palettePlacement(_ key:String,atWorld world:SCNVector3)->SCNVector3? { nil }
    func removeFromTable(_ key:String) {}
    func dragBegan(node:SCNNode) {}
    func dragMoved(node:SCNNode,worldPosition:SCNVector3) {}
    func dragEnded(node:SCNNode) {}
}

#if DEBUG
extension SpatialQuizViewModel {
    var diagnostic:String {
        let value:[String:Any] = ["mode":mode.rawValue,"phase":record?.phase.rawValue ?? "none",
            "activity":String(describing:session?.activity ?? .idle),"question":record?.current.id.uuidString ?? "",
            "content":record?.current.source.id ?? "","number":record?.current.source.targetNumber ?? 0,
            "attempts":record?.firstAnswers.count ?? 0,"successes":record?.successCount ?? 0,
            "unlocked":record?.demonstrationProgress.unlocked ?? false,"accessible":cueAccessible,
            "yaw":input.yaw,"speed":input.speed,"spinX":input.spinX,"spinY":input.spinY,"elevation":input.elevation,
            "displayedElevation":displayedInput.elevation,"profile":scene.renderingProfile.rawValue,
            "recipe":scene.declaredRenderRecipe?.rawValue ?? "none","p01":scene.cameraRig?.p01AnchoredTransitions ?? false,
            "topDown":temporaryTopDownActive,"locked":layoutEditing,"routeNodes":routeNodes.count,
            "routeSolidSegments":routeNodes.flatMap(\.childNodes).filter { $0.name == "spatialRoute.solid" }.count,
            "routeDashedSegments":routeNodes.flatMap(\.childNodes).filter { $0.name == "spatialRoute.dashed" }.count,
            "latest":record?.latestShot?.id.uuidString ?? "","lastSucceeded":record?.latestShot?.outcome.succeeded ?? false,
            "quotaUsed":limiter.questionsUsedToday,"premium":limiter.isPremium,
            "questionIndex":record?.questionNumber ?? 0,"playbackSpeed":playbackSpeed,
            "active":active,"paused":scene.isPaused,"message":message ?? ""]
        return (try? JSONSerialization.data(withJSONObject:value,options:.sortedKeys)).flatMap { String(data:$0,encoding:.utf8) } ?? "{}"
    }
}
#endif
