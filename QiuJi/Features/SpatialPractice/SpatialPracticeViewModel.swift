import SwiftUI
import SceneKit
import Combine

@MainActor
final class SpatialPracticeViewModel: TeachingTableHost {
    typealias Record = SpatialPracticeRecord
    enum Phase { case ready, calculating, playing, replaying }
    let scene=AngleTrainingScene()
    @Published var cameraMode: AngleTrainingScene.CameraMode = .perspective3D
    @Published var cameraTransitionBusy=false
    @Published var temporaryTopDownActive=false
    @Published var topDownContentRevision=0
    var topDownSelectionChanged=false
    @Published private(set) var phase:Phase = .ready
    @Published private(set) var isDragging=false
    @Published var input=Record.Input()
    @Published private(set) var record=Record(board:[:],input:.init())
    @Published var message:String?
    @Published var playbackSpeed:Float=1
    private var setup=false
    private var cancellation:PredictionCancellation?
    private var generation=UUID()
    private var ownerKey=""
    private let defaults:UserDefaults
    private var replayReturn:[String:Record.Pose]?
    private var replayCamera=ShotReplayCamera()
    private var audioItems:[DispatchWorkItem]=[]
    private var initialDrag:SCNVector3?
    var busy:Bool { phase == .playing || phase == .replaying }
    var canEdit:Bool { !busy && !temporaryTopDownActive && !cameraTransitionBusy }
    var selectedTargetKey:String? { nil }
    var selectedPocketIndex:Int { -1 }
    var targetNode:SCNNode? { nil }
    var currentPlayerAim:SCNVector3? { onTableKeys.contains(PositionPlayBall.cueKey) ? input.aim : nil }
    var onTableKeys:[String] { PositionPlayBall.allKeys.filter { record.board[$0]?.disposition == "bed" } }
    var draggableBalls:[SCNNode] { canEdit ? onTableKeys.compactMap { scene.allBallNodes[$0] } : [] }
    var selectableBalls:[SCNNode] { draggableBalls }
    var outsideKeys:[String] { record.board.keys.filter { record.board[$0]?.disposition == "outside" }.sorted() }
    var canStrike:Bool { canEdit && phase != .calculating && input.valid && currentPlayerAim != nil && cueAccessible }
    private var storageKey:String { "spatialPractice.v1." + ownerKey }
    init(defaults:UserDefaults = .standard) { self.defaults=defaults }

    func setupScene() {
        guard !setup else { return };setup=true
        scene.configureReferenceTableRendering();scene.configureShotAwareCamera()
        scene.setupScene();scene.setupVisualizationNodes();configureTeachingCamera()
        ownerChanged()
    }
    func ownerChanged() {
        suspendTeachingActivity()
        ownerKey=CurrentOwnerContext.shared.ownerKey
        if let data=defaults.data(forKey:storageKey), let saved=try? PropertyListDecoder().decode(Record.self,from:data), saved.valid {
            record=saved;input=saved.input;apply(saved.board)
        } else {
            if let data=defaults.data(forKey:storageKey) {
                defaults.set(data,forKey:storageKey+".unreadable")
                message="旧练习记录无法读取，已保留备份并载入示例"
            }
            record=Record(board:[:],input:.init());loadExample(0)
        }
        scene.isPaused=false;refreshAim()
    }
    func save() {
        guard setup else { return }
        record.input=input
        do { let encoder=PropertyListEncoder();encoder.outputFormat = .binary
            defaults.set(try encoder.encode(record),forKey:storageKey)
        } catch { message="保存失败，请重试" }
    }
    func updateInput(_ update:(inout Record.Input)->Void) {
        guard !busy else { return }
        update(&input)
        cancelCalculation();refreshAim();save()
    }
    func nudgeAim(_ degrees:Float) { updateInput { $0.yaw += Double(degrees) * .pi / 180 } }
    func setSpin(_ x:Double,_ y:Double) {
        updateInput { value in
            let length=hypot(x,y), scale=length>0.8 ? 0.8/length : 1
            value.spinX=x*scale;value.spinY=y*scale
        }
    }
    private var strikePoint:SCNVector3? {
        guard let cue=record.board[PositionPlayBall.cueKey],cue.disposition == "bed" else { return nil }
        let aim=input.aim,r=BallPhysics.radius,e=input.radians
        return cue.position.scene + SCNVector3(aim.z*Float(input.spinX)+aim.x*sinf(e)*Float(input.spinY),
            cosf(e)*Float(input.spinY),-aim.x*Float(input.spinX)+aim.z*sinf(e)*Float(input.spinY))*r
    }
    var cueAccessible:Bool {
        guard let strikePoint else { return false }
        let obstacles=onTableKeys.filter { !PositionPlayBall.isCue($0) }.compactMap { record.board[$0]?.position.scene }
        return CueStick.clearsAtElevation(strike:strikePoint,aim:input.aim,obstacles:obstacles,
            surfaceY:scene.surfaceY,elevation:input.radians)
    }
    func refreshAim() {
        guard setup,!busy,let strikePoint,let cue=record.board[PositionPlayBall.cueKey]?.position.scene else {
            scene.hideCueStick();scene.setFreeAimPreviewLine(nil);return
        }
        let end=AngleSceneCalculator.rayToInnerRail(from:cue,dir:input.aim)
        scene.setFreeAimPreviewLine(.init(start:CGPoint(x:CGFloat(cue.x),y:CGFloat(cue.z)),end:CGPoint(x:CGFloat(end.x),y:CGFloat(end.z))))
        if cueAccessible { scene.updateCueStick(cueBallPosition:strikePoint,aimDirection:input.aim,elevationOverride:input.radians) }
        else { scene.hideCueStick() }
    }
    private func cancelCalculation() { cancellation?.cancel();cancellation=nil;generation=UUID();if phase == .calculating { phase = .ready } }
    func strike() {
        guard canStrike,let cue=record.board[PositionPlayBall.cueKey]?.position.scene else { return }
        save();message=nil;phase = .calculating
        let request=UUID();generation=request
        let token=PredictionCancellation();cancellation=token
        let frozen=input,before=record.board
        let balls=before.keys.sorted().filter { !PositionPlayBall.isCue($0) && before[$0]?.disposition != "pocket" }.compactMap { key in
            before[key].map { ObstacleBall(name:key,position:$0.position.scene) }
        }
        Task { [weak self] in
            let shot=await Task.detached(priority:.userInitiated) {
                let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:frozen.aim,velocity:Float(frozen.speed),
                    spinX:Float(frozen.spinX),spinY:Float(frozen.spinY),surfaceY:BTTablePhysics.surfaceY,
                    balls:balls,maxEvents:3000,maxTime:40,simulationModel:.spatialPractice,cancellation:token,elevation:frozen.radians,
                    initialSpatialPositions:before.mapValues { $0.position.scene })
                return (Record.freeze(prediction:p,input:frozen,before:before),p)
            }.value
            guard let self,self.generation==request,!token.isCancelled else { return }
            self.cancellation=nil
            guard var result=shot.0 else {
                self.phase = .ready
                if case .failed(let reason)=shot.1.termination { self.message=reason.contains("超出练习空间") ? reason : "本杆接触计算未完成，请调整参数后重试" }
                else { self.message="本杆尚未完成计算，请调整参数后重试" }
                return
            }
            if let recorder=shot.1.recorder {
                result.sounds=ShotAudioScheduler.timeline(recorder:recorder,legacyEvents:shot.1.events).map { .init(time:$0.time,kind:$0.kind.rawValue,speed:$0.speed) }
            }
            guard let strikePoint=self.strikePoint else { self.phase = .ready;return }
            self.phase = .playing
            self.scene.runCueStroke(strikePosition:strikePoint,aim:frozen.aim,velocity:Float(frozen.speed),
                elevationOverride:frozen.radians) { [weak self] in
                guard let self,self.generation==request else { return }
                self.play(result,replay:false)
            }
        }
    }
    private func apply(_ board:[String:Record.Pose]) {
        scene.hideAllBalls()
        for (key,pose) in board {
            guard let node=scene.allBallNodes[key] else { continue }
            node.removeAllActions();node.opacity=1;node.isHidden=pose.disposition == "pocket"
            node.position=pose.position.scene
            if pose.rotation.count==4 { node.simdOrientation=simd_quatf(vector:SIMD4(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3])) }
        }
        topDownContentRevision += 1
    }
    private func play(_ shot:Record.Shot,replay:Bool) {
        phase = replay ? .replaying : .playing
        let request=UUID();generation=request
        apply(shot.before);if replay { scene.hideCueStick() };scene.setFreeAimPreviewLine(nil)
        let speed=replay ? playbackSpeed : 1
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
        let keys=shot.paths.keys.sorted()
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
            }
            node.runAction(action) { [weak self] in
                Task { @MainActor in
                    guard let self,self.generation==request else { return }
                    pending.remove(key)
                    guard pending.isEmpty else { return }
                    if replay { self.restoreReplay() }
                    else {
                        self.record.board=shot.after;self.record.lastShot=shot
                        self.apply(shot.after);self.phase = .ready;self.save();self.refreshAim()
                    }
                }
            }
        }
    }
    func replay() {
        guard !busy,let shot=record.lastShot else { return }
        cancelCalculation();replayReturn=record.board
        replayCamera.begin(in:scene)
        play(shot,replay:true)
    }
    private func restoreReplay() {
        if let replayReturn { apply(replayReturn) };replayReturn=nil
        replayCamera.finish(in:scene)
        phase = .ready;refreshAim()
    }
    func stopPlayback() {
        generation=UUID();audioItems.forEach { $0.cancel() };audioItems=[];scene.cueStick?.cancelAnimations();scene.hideCueStick()
        for node in scene.allBallNodes.values { node.removeAllActions() }
        if phase == .replaying { restoreReplay() }
        else { apply(record.board);phase = .ready;refreshAim() }
    }
    func retry() {
        guard !busy,let shot=record.lastShot else { return };cancelCalculation()
        record.board=shot.before;input=shot.input;apply(record.board);save();refreshAim()
    }
    func clear() { guard !busy else { return };cancelCalculation();record.board=[:];apply([:]);save();refreshAim() }
    func loadExample(_ index:Int) {
        guard !busy else { return };cancelCalculation()
        let y=BTTablePhysics.surfaceY+BallPhysics.radius
        func pose(_ x:Float,_ z:Float)->Record.Pose { .init(position:.init(SCNVector3(x,y,z)),rotation:[0,0,0,1],disposition:"bed") }
        record.board=[PositionPlayBall.cueKey:pose(-0.65,0),"_1":pose(-0.25,0),"_2":pose(0.6,0)]
        input = .init(yaw:0,speed:index==0 ? 4 : 2,spinX:index==0 ? 0 : (index==1 ? 0.55 : -0.55),spinY:0,elevation:index==0 ? 50 : 70)
        apply(record.board);save();refreshAim()
    }
    func selectPocket(at index:Int) {}
    func selectTarget(key:String) {
        guard let cue=record.board[PositionPlayBall.cueKey]?.position.scene,let target=record.board[key]?.position.scene else { return }
        updateInput { $0.yaw=Double(atan2f(target.z-cue.z,target.x-cue.x)) }
    }
    func palettePlacement(_ key:String,atWorld world:SCNVector3)->SCNVector3? {
        guard !busy,PositionPlayBall.allKeys.contains(key) else { return nil }
        let r=BallPhysics.radius
        guard abs(world.x)<TablePhysics.innerLength/2-r,abs(world.z)<TablePhysics.innerWidth/2-r else { return nil }
        let p=AngleSceneCalculator.clampAwayFromPockets(world,surfaceY:scene.surfaceY)
        guard onTableKeys.filter({ $0 != key }).allSatisfy({ k in
            guard let q=record.board[k]?.position.scene else { return true }
            return hypotf(p.x-q.x,p.z-q.z)>2*r+0.0001
        }) else { return nil }
        return SCNVector3(p.x,scene.surfaceY+r,p.z)
    }
    func place(_ key:String,at world:SCNVector3) {
        guard let p=palettePlacement(key,atWorld:world) else { return };cancelCalculation()
        record.board[key] = .init(position:.init(p),rotation:[0,0,0,1],disposition:"bed")
        apply(record.board);save();refreshAim()
    }
    func placeFromPalette(_ key:String) {
        guard !busy else { return }
        for ix in 0..<25 { for iz in 0..<11 {
            let p=SCNVector3(-1.1+Float(ix)*0.09,scene.surfaceY+BallPhysics.radius,-0.45+Float(iz)*0.09)
            if palettePlacement(key,atWorld:p) != nil { place(key,at:p);return }
        } }
    }
    func removeFromTable(_ key:String) {
        guard !busy else { return };cancelCalculation();record.board.removeValue(forKey:key)
        apply(record.board);save();refreshAim()
    }
    func retrieveOutside() { for key in outsideKeys { placeFromPalette(key) } }
    func dragBegan(node:SCNNode) { guard !busy else { return };cancelCalculation();initialDrag=node.position;isDragging=true }
    func dragMoved(node:SCNNode,worldPosition:SCNVector3) {
        guard isDragging,let key=scene.ballKey(for:node),let p=palettePlacement(key,atWorld:worldPosition) else { return }
        node.position=p
    }
    func dragEnded(node:SCNNode) {
        guard isDragging else { return };isDragging=false
        if let key=scene.ballKey(for:node) { place(key,at:node.position) };initialDrag=nil
    }
    func suspendTeachingActivity() { cancelCalculation();if busy { stopPlayback() };save();scene.isPaused=true }
    func resumeTeachingActivity() { scene.isPaused=false;refreshAim() }
}
